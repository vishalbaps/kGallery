import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../bloc/gallery_bloc.dart';
import '../../models/gallery_item.dart';
import '../../models/gallery_theme.dart';
import '../../utils/connectivity_service.dart';
import '../gallery/gallery_offline_view.dart';
import 'gallery_media_internals.dart';

/// Internal widget rendering a single YouTube item via
/// `youtube_player_flutter`. Owns the [YoutubePlayerController] lifecycle
/// and a thin side-effect subscription for play-state transitions.
///
/// Layering note: on mobile the package renders the player WebView inside an
/// [OverlayPortal], which paints *above* this route's widget tree. Any control
/// that must sit on top of the video therefore has to be supplied through
/// [YoutubePlayer.builder] rather than as a sibling in the gallery's own
/// [Stack] — see [_GalleryYoutubeControls].
///
/// Performance: per-tick value changes drive only the controls subtree via
/// [YoutubeValueBuilder] — the [YoutubePlayer] subtree does not rebuild on
/// every tick (it subscribes internally).
class GalleryYoutubeItem extends StatefulWidget {
  final GalleryItem item;
  final int index;
  final ValueNotifier<YoutubePlayerController?> activeYoutubeNotifier;
  final GalleryBloc galleryBloc;
  final GalleryOfflineBuilder? offlineBuilder;
  final GalleryTheme? theme;

  const GalleryYoutubeItem({
    super.key,
    required this.item,
    required this.index,
    required this.activeYoutubeNotifier,
    required this.galleryBloc,
    this.offlineBuilder,
    this.theme,
  });

  @override
  State<GalleryYoutubeItem> createState() => _GalleryYoutubeItemState();
}

class _GalleryYoutubeItemState extends State<GalleryYoutubeItem>
    with GalleryUIHideMixin<GalleryYoutubeItem> {
  YoutubePlayerController? _controller;

  /// Side-effect subscription on the controller's value stream. The v10
  /// controller is not a [Listenable], so state is observed via streams.
  StreamSubscription<YoutubePlayerValue>? _valueSub;

  bool _previousIsPlaying = false;

  /// Guards the one-shot "play once the cued video is ready" transition.
  bool _startedPlayback = false;

  /// Prevents re-entrant activation while the async connectivity check runs.
  bool _activating = false;

  bool get _currentlyPlaying =>
      _controller?.value.playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.galleryBloc.state.currentIndex == widget.index) {
        _activate();
      }
    });
  }

  void _activate() {
    if (_controller != null || _activating) return;
    _activating = true;
    _startActivation();
  }

  Future<void> _startActivation() async {
    try {
      // Gate on connectivity first: a YouTube IFrame never reaches a ready
      // state while offline, so without this it would spin on the loader
      // forever.
      final online = await ConnectivityService.instance.isConnected();
      if (!mounted || widget.galleryBloc.state.currentIndex != widget.index) {
        return;
      }
      // Publish offline state to the bloc instead of local setState.
      _setOffline(!online);
      if (!online) return;
      _createController();
    } finally {
      _activating = false;
    }
  }

  void _setOffline(bool offline) {
    widget.galleryBloc
        .add(GallerySetItemOffline(index: widget.index, offline: offline));
  }

  void _createController() {
    if (_controller != null) return;

    final id = YoutubePlayerController.convertUrlToId(widget.item.url);
    if (id == null) {
      developer.log(
        'Could not parse YouTube video id from "${widget.item.url}"',
        name: 'kGallery',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This YouTube video can't be played here."),
            duration: Duration(seconds: 2),
          ),
        );
      });
      return;
    }

    // autoPlay: false cues the video; playback starts from [_onValue] once the
    // player reports ready, so a video the user has already swiped past never
    // starts.
    final c = YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        enableCaption: false,
        mute: false,
      ),
    );
    _controller = c;
    _valueSub = c.listen(_onValue);
    // The package resizes its overlay to fill the screen but never touches
    // device orientation or system UI, so the gallery still owns that.
    c.setFullScreenListener(_onFullscreenChanged);
    widget.activeYoutubeNotifier.value = c;

    if (mounted) setState(() {});
  }

  /// Side-effect listener — handles first-play gating and hide-timer
  /// transitions. Crucially does NOT call setState; the controls subtree
  /// rebuilds via the [YoutubeValueBuilder] in [_GalleryYoutubeControls].
  void _onValue(YoutubePlayerValue v) {
    if (!mounted) return;

    // PlayerState.unknown is the pre-load state; anything else means the
    // IFrame has reported in and accepts commands.
    if (!_startedPlayback && v.playerState != PlayerState.unknown) {
      _startedPlayback = true;
      if (widget.galleryBloc.state.currentIndex == widget.index) {
        final c = _controller;
        if (c != null) ignorePlayerCommandError(c.playVideo());
      }
    }

    final isPlaying = v.playerState == PlayerState.playing;
    if (isPlaying != _previousIsPlaying) {
      _previousIsPlaying = isPlaying;
      final state = widget.galleryBloc.state;
      if (isPlaying &&
          state.isUIVisible &&
          state.currentIndex == widget.index) {
        startHideUITimer(widget.galleryBloc, widget.index);
      } else {
        cancelHideUITimer();
      }
    }
  }

  /// Applies landscape + immersive chrome while the player is fullscreen and
  /// restores the gallery's normal chrome on exit. Mirrors what the old
  /// dedicated fullscreen route did in `didPush`/`didPop`.
  void _onFullscreenChanged(bool isFullscreen) {
    if (isFullscreen) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _deactivate({bool fromDispose = false}) {
    cancelHideUITimer();
    final c = _controller;
    if (c == null) return;

    _valueSub?.cancel();
    _valueSub = null;
    _controller = null;
    _previousIsPlaying = false;
    _startedPlayback = false;

    // Leave fullscreen before teardown so the landscape lock and immersive
    // chrome don't outlive the player. Only touch system chrome when the
    // player actually held it — resetting unconditionally would stomp on a
    // host app that runs its own non-default orientation or UI mode.
    if (c.value.fullScreenOption.enabled) c.exitFullScreen();

    // Silence playback before disposing. The gallery's close path pauses while
    // the WebView is still mounted (see KGallery._dismissAfterSilencingYoutube);
    // this is a best-effort stop for the other teardown paths (e.g. swiping to
    // another item), since on iPadOS disposing the WKWebView alone does not
    // reliably halt its audio session.
    // Only meaningful once the player has reported in. A command issued before
    // then queues behind the JS bridge's readiness future and throws after 30s,
    // which is how swiping past a still-loading item produced an unhandled
    // TimeoutException.
    if (c.value.playerState != PlayerState.unknown) {
      ignorePlayerCommandError(c.pauseVideo());
    }
    ignorePlayerCommandError(c.close());

    final notifier = widget.activeYoutubeNotifier;
    if (fromDispose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (notifier.value == c) notifier.value = null;
      });
    } else {
      if (notifier.value == c) notifier.value = null;
      if (mounted) setState(() {});
    }
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    if (c.value.playerState == PlayerState.playing) {
      ignorePlayerCommandError(c.pauseVideo());
    } else {
      ignorePlayerCommandError(c.playVideo());
    }
  }

  @override
  void dispose() {
    _deactivate(fromDispose: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<GalleryBloc, GalleryState>(
          bloc: widget.galleryBloc,
          listenWhen: (prev, curr) => prev.currentIndex != curr.currentIndex,
          listener: (context, state) {
            if (state.currentIndex == widget.index) {
              _activate();
            } else {
              _deactivate();
            }
          },
        ),
        BlocListener<GalleryBloc, GalleryState>(
          bloc: widget.galleryBloc,
          listenWhen: (prev, curr) => prev.isUIVisible != curr.isUIVisible,
          listener: (context, state) {
            if (state.currentIndex != widget.index) return;
            if (state.isUIVisible && _currentlyPlaying) {
              startHideUITimer(widget.galleryBloc, widget.index);
            } else {
              cancelHideUITimer();
            }
          },
        ),
      ],
      child: BlocSelector<GalleryBloc, GalleryState, bool>(
        bloc: widget.galleryBloc,
        selector: (state) => state.offlineItems.contains(widget.index),
        builder: (context, isOffline) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Catches taps on the letterboxed area outside the player box.
              // Taps on the player itself are handled by the tap target inside
              // [_GalleryYoutubeControls], which sits in the player's overlay
              // and therefore receives those pointers first.
              GalleryMediaTapOverlay(galleryBloc: widget.galleryBloc),
              _buildPlayer(),
              if (isOffline)
                Positioned.fill(child: _buildOfflineView())
              else if (_controller == null)
                const GalleryMediaLoader(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOfflineView() {
    return ColoredBox(
      color: widget.theme?.backgroundColor ?? Colors.black,
      child: GalleryLoadErrorView(
        item: widget.item,
        theme: widget.theme,
        offlineBuilder: widget.offlineBuilder,
        knownOffline: true,
      ),
    );
  }

  /// Insets that keep the player clear of the gallery's own chrome.
  ///
  /// The package renders the player inside an [OverlayPortal] attached to the
  /// root [Overlay], so it paints above this route — anything the gallery draws
  /// in its own [Stack] that falls inside the player box is hidden behind the
  /// video. A 16:9 box on a landscape tablet spans almost the full height and
  /// swallows the top bar, text panel and thumbnail strip.
  ///
  /// Constraining the player's own rect is what fixes it: the overlay follows
  /// that rect, so reserving the chrome's bands keeps it out of them. The
  /// values mirror the breakpoints in `KGallery.build` and
  /// `GalleryThumbnailStrip`.
  EdgeInsets _chromeInsets(BuildContext context, double textPanelHeight) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.shortestSide >= 600;
    const seekbarHeight = 40.0;
    return EdgeInsets.only(
      top: (isTablet ? 80.0 : 56.0) + media.padding.top,
      bottom: (isTablet ? 110.0 : 90.0) +
          seekbarHeight +
          textPanelHeight +
          media.padding.bottom,
    );
  }

  /// Whether this item renders a title/description panel, which the insets
  /// have to clear as well.
  bool get _hasTextPanel =>
      widget.item.title != null || widget.item.description != null;

  Widget _buildPlayer() {
    final c = _controller;
    if (c == null) {
      return const SizedBox.expand(child: ColoredBox(color: Colors.black));
    }
    // Reserve the chrome bands only while the chrome is actually on screen, so
    // hiding the UI still gives the video the whole viewport.
    return BlocSelector<GalleryBloc, GalleryState, (bool, double)>(
      bloc: widget.galleryBloc,
      selector: (state) => (
        state.isUIVisible && !state.isSliding,
        _hasTextPanel ? state.textPanelHeight : 0.0,
      ),
      builder: (context, selection) {
        final (chromeVisible, textPanelHeight) = selection;
        return Padding(
          padding: chromeVisible
              ? _chromeInsets(context, textPanelHeight)
              : EdgeInsets.zero,
          child: _buildPlayerSurface(c),
        );
      },
    );
  }

  Widget _buildPlayerSurface(YoutubePlayerController c) {
    return Center(
      child: YoutubePlayer(
        controller: c,
        aspectRatio: 16 / 9,
        backgroundColor: Colors.black,
        // The gallery owns vertical drags (swipe-to-dismiss) and horizontal
        // ones (PageView paging), so the player must claim neither. An empty
        // set opts out of the package's default gesture claims.
        gestureRecognizers: const {},
        // Fullscreen is entered only through the gallery's own button; the
        // package's drag and auto-rotate triggers would fight swipe-to-dismiss.
        enableFullScreenOnVerticalDrag: false,
        autoFullScreen: false,
        builder: (context, player, ctrl) => _GalleryYoutubeControls(
          controller: ctrl,
          galleryBloc: widget.galleryBloc,
          theme: widget.theme,
          onTogglePlayPause: _togglePlayPause,
        ),
      ),
    );
  }
}

/// Gallery-styled controls rendered inside the player's overlay.
///
/// Supplied via [YoutubePlayer.builder] so it paints above the WebView on
/// mobile. One widget serves both layouts: inline shows the fullscreen
/// button (the seekbar lives in the thumbnail strip), fullscreen shows the
/// timer, exit button and seekbar.
class _GalleryYoutubeControls extends StatefulWidget {
  final YoutubePlayerController controller;
  final GalleryBloc galleryBloc;
  final GalleryTheme? theme;
  final VoidCallback onTogglePlayPause;

  const _GalleryYoutubeControls({
    required this.controller,
    required this.galleryBloc,
    required this.theme,
    required this.onTogglePlayPause,
  });

  @override
  State<_GalleryYoutubeControls> createState() =>
      _GalleryYoutubeControlsState();
}

class _GalleryYoutubeControlsState extends State<_GalleryYoutubeControls> {
  StreamSubscription<YoutubePlayerValue>? _valueSub;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isReady = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _readValue(widget.controller.value);
    _subscribe();
  }

  @override
  void didUpdateWidget(_GalleryYoutubeControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _valueSub?.cancel();
      _isPlaying = false;
      _readValue(widget.controller.value);
      _subscribe();
    }
  }

  void _subscribe() {
    _valueSub = widget.controller.listen((value) {
      if (!mounted) return;
      final playing = _isPlaying;
      final buffering = _isBuffering;
      final ready = _isReady;
      final fullscreen = _isFullscreen;
      _readValue(value);
      if (playing != _isPlaying ||
          buffering != _isBuffering ||
          ready != _isReady ||
          fullscreen != _isFullscreen) {
        setState(() {});
      }
    });
  }

  /// Derives control state from a player value.
  ///
  /// v10 folds buffering into the single [PlayerState] enum, so a mid-playback
  /// buffer would read as "not playing" and flash the play button over the
  /// spinner. v9 tracked `isPlaying` as a separate field that the buffering
  /// transition deliberately left untouched; carrying the last play/pause
  /// decision across buffering reproduces that.
  void _readValue(YoutubePlayerValue value) {
    final state = value.playerState;
    _isReady = state != PlayerState.unknown;
    _isBuffering = state == PlayerState.buffering;
    _isFullscreen = value.fullScreenOption.enabled;
    if (state == PlayerState.playing) {
      _isPlaying = true;
    } else if (state != PlayerState.buffering) {
      _isPlaying = false;
    }
  }

  @override
  void dispose() {
    _valueSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GalleryMediaTapOverlay(galleryBloc: widget.galleryBloc),
        Center(
          child: GalleryCenterControls(
            isPlaying: _isPlaying,
            isReady: _isReady,
            bufferingStream: null,
            initialBuffering: _isBuffering,
            galleryBloc: widget.galleryBloc,
            onTap: widget.onTogglePlayPause,
          ),
        ),
        if (_isFullscreen)
          _GalleryYoutubeFullscreenBar(
            controller: widget.controller,
            galleryBloc: widget.galleryBloc,
            theme: widget.theme,
          )
        else
          Positioned(
            right: 16,
            bottom: 16,
            child: _GalleryYoutubeOverlayButton(
              galleryBloc: widget.galleryBloc,
              icon: Icons.fullscreen,
              onTap: widget.controller.enterFullScreen,
            ),
          ),
      ],
    );
  }
}

/// Bottom bar shown while fullscreen: `00:00 / 10:00` on the left, exit-
/// fullscreen on the right, seekbar underneath — mirroring the media_kit
/// fullscreen layout.
class _GalleryYoutubeFullscreenBar extends StatelessWidget {
  final YoutubePlayerController controller;
  final GalleryBloc galleryBloc;
  final GalleryTheme? theme;

  const _GalleryYoutubeFullscreenBar({
    required this.controller,
    required this.galleryBloc,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = theme?.seekbarActiveColor ?? Colors.white;
    final inactiveColor = theme?.seekbarInactiveColor ?? Colors.white30;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: BlocBuilder<GalleryBloc, GalleryState>(
          bloc: galleryBloc,
          buildWhen: (prev, curr) => prev.isUIVisible != curr.isUIVisible,
          builder: (context, state) {
            final visible = state.isUIVisible;
            return IgnorePointer(
              ignoring: !visible,
              child: AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GalleryYoutubeSeekbar(
                    controller: controller,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    layout: (context, position, duration, slider) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Text(
                                '${formatGalleryDuration(position)} / '
                                '${formatGalleryDuration(duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                // Opaque, and padded out to a full touch
                                // target: this sits inside the player's
                                // overlay, under the package's own opaque tap
                                // handler, so a glyph-sized deferToChild hit
                                // box is too easy to miss.
                                behavior: HitTestBehavior.opaque,
                                onTap: controller.exitFullScreen,
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.fullscreen_exit,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: slider,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Small rounded translucent icon button that follows the gallery's UI
/// visibility state.
class _GalleryYoutubeOverlayButton extends StatelessWidget {
  final GalleryBloc galleryBloc;
  final IconData icon;
  final VoidCallback onTap;

  const _GalleryYoutubeOverlayButton({
    required this.galleryBloc,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GalleryBloc, GalleryState>(
      bloc: galleryBloc,
      buildWhen: (prev, curr) =>
          prev.isUIVisible != curr.isUIVisible ||
          prev.isSliding != curr.isSliding,
      builder: (context, state) {
        final visible = state.isUIVisible && !state.isSliding;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        );
      },
    );
  }
}
