import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../bloc/gallery_bloc.dart';
import '../../models/gallery_item.dart';
import '../../models/gallery_theme.dart';
import '../../utils/connectivity_service.dart';
import '../../utils/gallery_wakelock.dart';
import '../../utils/youtube_captions.dart';
import '../gallery/gallery_offline_view.dart';
import '../gallery_youtube_fullscreen_route.dart';
import 'gallery_media_internals.dart';

/// Whether a YouTube player in state [v] should keep the screen on.
///
/// youtube_player_flutter sets `isPlaying` only on the IFrame's "playing" and
/// "paused" states; ending the video or hitting a player error leaves it
/// `true`. Those are checked explicitly, and the player must be ready so the
/// loader never holds the screen on.
@visibleForTesting
bool youtubeIsActivelyPlaying(YoutubePlayerValue v) =>
    v.isReady &&
    v.isPlaying &&
    v.playerState != PlayerState.ended &&
    v.errorCode == 0;

/// Internal widget rendering a single YouTube item via
/// `youtube_player_flutter`. Owns the [YoutubePlayerController] lifecycle
/// and a thin side-effect listener for play-state transitions.
///
/// Performance: the controller's per-tick value changes drive only the
/// center play/pause button via [AnimatedBuilder] — the [YoutubePlayer]
/// subtree does not rebuild on every tick (it subscribes internally).
class GalleryYoutubeItem extends StatefulWidget {
  final GalleryItem item;
  final int index;
  final ValueNotifier<YoutubePlayerController?> activeYoutubeNotifier;
  final GalleryBloc galleryBloc;
  final GalleryOfflineBuilder? offlineBuilder;
  final GalleryTheme? theme;

  /// Whether to keep the screen on while this video is playing.
  final bool keepScreenOnWhilePlaying;

  /// Gallery-wide caption state, shared by every YouTube item so it carries
  /// over swipes and fullscreen. Toggled by the CC button.
  final ValueNotifier<bool> youtubeCaptionsNotifier;

  /// Preferred caption language (e.g. `en`) used when captions are on.
  final String youtubeCaptionLanguage;

  /// Whether to show the CC button inline and in fullscreen.
  final bool showYoutubeCaptionToggle;

  const GalleryYoutubeItem({
    super.key,
    required this.item,
    required this.index,
    required this.activeYoutubeNotifier,
    required this.galleryBloc,
    required this.youtubeCaptionsNotifier,
    this.offlineBuilder,
    this.theme,
    this.keepScreenOnWhilePlaying = true,
    this.youtubeCaptionLanguage = 'en',
    this.showYoutubeCaptionToggle = false,
  });

  @override
  State<GalleryYoutubeItem> createState() => _GalleryYoutubeItemState();
}

class _GalleryYoutubeItemState extends State<GalleryYoutubeItem>
    with GalleryUIHideMixin<GalleryYoutubeItem> {
  YoutubePlayerController? _controller;
  bool _previousIsReady = false;
  bool _previousIsPlaying = false;

  /// Position saved just before a WebView swap (enter/exit fullscreen) so the
  /// new WebView can seek there once it is ready.
  Duration? _resumePosition;

  /// True while the fullscreen route is on top. The inline [YoutubePlayer]
  /// is suppressed during this window so only one WebView is bound to the
  /// controller — otherwise the inline widget would steal the WebView and
  /// the fullscreen route would render only the static thumbnail.
  final ValueNotifier<bool> _isFullscreen = ValueNotifier<bool>(false);

  /// Prevents re-entrant activation while the async connectivity check runs.
  bool _activating = false;

  /// Upper bound on how long a fullscreen WebView swap may hold the wakelock
  /// while the new WebView loads.
  static const Duration _swapWakelockTimeout = Duration(seconds: 15);

  /// Non-null while the wakelock is held across a WebView swap (see
  /// [_holdWakelockThroughSwap]).
  Timer? _swapWakelockHold;

  /// The WebView controller [youtubeCaptionsScript] was last installed in.
  /// Each fullscreen enter/exit binds a new WebView, which starts without the
  /// caption state and needs it installed again once it is ready.
  Object? _captionsWebView;

  bool get _currentlyPlaying => _controller?.value.isPlaying == true;

  @override
  void initState() {
    super.initState();
    widget.youtubeCaptionsNotifier.addListener(_applyCaptions);
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
      // Gate on connectivity first: a YouTube WebView never reaches "ready"
      // while offline, so without this it would spin on the loader forever.
      final online = await ConnectivityService.instance.isConnected();
      if (!mounted ||
          widget.galleryBloc.state.currentIndex != widget.index) {
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

    final id = YoutubePlayer.convertUrlToId(widget.item.url);
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

    final c = YoutubePlayerController(
      initialVideoId: id,
      flags: YoutubePlayerFlags(
        hideControls: true,
        autoPlay: false,
        hideThumbnail: true,
        mute: false,
        // Only the starting hint: the flags are fixed per controller, and
        // cc_load_policy can't force captions off. _applyCaptions enforces
        // the current state in every WebView this controller binds.
        enableCaption: widget.youtubeCaptionsNotifier.value,
        captionLanguage: widget.youtubeCaptionLanguage,
      ),
    );
    _controller = c;
    c.addListener(_listener);
    widget.activeYoutubeNotifier.value = c;

    if (mounted) setState(() {});
  }

  /// Side-effect listener — handles readiness gating and timer transitions.
  /// Crucially does NOT call setState; the controls subtree rebuilds via
  /// the [AnimatedBuilder] in [build].
  void _listener() {
    final c = _controller;
    if (c == null || !mounted) return;
    final v = c.value;

    // Before the resume/play below, so the caption state is in place when
    // playback starts.
    _installCaptions(v);

    if (!_previousIsReady && v.isReady) {
      _previousIsReady = true;
      if (widget.galleryBloc.state.currentIndex == widget.index) {
        final pos = _resumePosition;
        _resumePosition = null;

        if (pos != null) {
          // WebView was swapped (fullscreen enter/exit). A fresh IFrame ignores
          // playVideo() alone because the video is in "unstarted" state — it
          // hasn't been cued yet. seekTo(pos, allowSeekAhead: true) forces the
          // IFrame to load/buffer from that position, and since the controller's
          // playerState is still "playing" from the previous context, seekTo()
          // also calls play() internally. That combination is what works.
          c.seekTo(pos);
        } else {
          // First activation: initialVideoId already cued the video, so
          // playVideo() works directly.
          c.play();
        }
      }
    }

    if (v.isPlaying != _previousIsPlaying) {
      _previousIsPlaying = v.isPlaying;
      final state = widget.galleryBloc.state;
      if (v.isPlaying &&
          state.isUIVisible &&
          state.currentIndex == widget.index) {
        startHideUITimer(widget.galleryBloc, widget.index);
      } else {
        cancelHideUITimer();
      }
    }

    // Re-evaluated on every tick rather than only when isPlaying flips:
    // ending and errors don't flip isPlaying (see youtubeIsActivelyPlaying),
    // and acquire/release are no-ops when nothing changed.
    _syncWakelock();
  }

  void _syncWakelock() {
    final v = _controller?.value;
    // A ready player means the new WebView (if one was swapped in) is now
    // reporting its own play state, so it takes over from the swap hold.
    if (v != null && v.isReady) _endSwapHold();
    final keepOn = widget.keepScreenOnWhilePlaying &&
        v != null &&
        (_swapWakelockHold != null || youtubeIsActivelyPlaying(v));
    if (keepOn) {
      GalleryWakelock.acquire(this);
    } else {
      GalleryWakelock.release(this);
    }
  }

  /// Keeps the wakelock held while the WebView is swapped for fullscreen
  /// enter or exit. The player reports not-ready until the new WebView loads,
  /// which on its own would drop the wakelock for that gap and could let the
  /// screen sleep mid-video. The hold carries over if a swap starts while
  /// another is still loading, ends as soon as the new WebView is ready, and
  /// expires after [_swapWakelockTimeout] so a WebView that never loads can't
  /// keep the screen on behind the loader.
  ///
  /// Must be called before the controller is marked not-ready.
  void _holdWakelockThroughSwap(YoutubePlayerController c) {
    final wasHolding = _swapWakelockHold != null;
    _endSwapHold();
    if (!wasHolding && !youtubeIsActivelyPlaying(c.value)) return;
    _swapWakelockHold = Timer(_swapWakelockTimeout, () {
      _swapWakelockHold = null;
      if (mounted) _syncWakelock();
    });
  }

  void _endSwapHold() {
    _swapWakelockHold?.cancel();
    _swapWakelockHold = null;
  }

  /// Installs the caption state in the WebView the controller is bound to,
  /// once per WebView. `isReady` is reset on every fullscreen swap and set
  /// again only after the new WebView's player is ready, so the new
  /// controller identity seen here is the WebView now showing the video.
  void _installCaptions(YoutubePlayerValue v) {
    final webView = v.webViewController;
    if (!v.isReady || webView == null || identical(webView, _captionsWebView)) {
      return;
    }
    _captionsWebView = webView;
    _applyCaptions();
  }

  /// Applies the gallery's caption state to the current WebView. Runs on
  /// install and whenever the state is toggled; the script re-applies it
  /// itself on the first play and whenever YouTube loads the captions module.
  void _applyCaptions() {
    final c = _controller;
    final webView = c?.value.webViewController;
    // While a swap is in progress the old WebView is going away; the new one
    // picks up the state in _installCaptions once it is ready.
    if (c == null || webView == null || !c.value.isReady) return;
    webView
        .evaluateJavascript(
          source: youtubeCaptionsScript(
            enabled: widget.youtubeCaptionsNotifier.value,
            languageCode: widget.youtubeCaptionLanguage,
          ),
        )
        .catchError((Object e) {
      developer.log('Could not apply YouTube captions: $e', name: 'kGallery');
      return null;
    });
  }

  void _toggleCaptions() {
    final captions = widget.youtubeCaptionsNotifier;
    captions.value = !captions.value;
    // Keep the controls up long enough to see the change.
    final state = widget.galleryBloc.state;
    if (_currentlyPlaying &&
        state.isUIVisible &&
        state.currentIndex == widget.index) {
      startHideUITimer(widget.galleryBloc, widget.index);
    }
  }

  void _deactivate({bool fromDispose = false}) {
    cancelHideUITimer();
    _endSwapHold();
    GalleryWakelock.release(this);
    final c = _controller;
    if (c == null) return;

    c.removeListener(_listener);
    _controller = null;
    _captionsWebView = null;
    _previousIsReady = false;
    _previousIsPlaying = false;
    // Silence playback before disposing. The gallery's close path pauses while
    // the WebView is still mounted (see KGallery._dismissAfterSilencingYoutube);
    // this is a best-effort stop for the other teardown paths (e.g. swiping to
    // another item), since on iPadOS disposing the WKWebView alone does not
    // reliably halt its audio session.
    c.pause();
    c.dispose();

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
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  Future<void> _enterFullscreen() async {
    final c = _controller;
    if (c == null) return;
    cancelHideUITimer();

    // Save position then reset isReady + gate so the fullscreen WebView's own
    // isReady event (not the stale flag from the old WebView) triggers seekTo.
    _resumePosition = c.value.position;
    _previousIsReady = false;
    _previousIsPlaying = false;
    _holdWakelockThroughSwap(c);
    c.updateValue(c.value.copyWith(isReady: false));
    _isFullscreen.value = true;

    try {
      await Navigator.of(context).push(
        GalleryYoutubeFullscreenRoute(
          ytController: c,
          theme: widget.theme,
          youtubeCaptionsNotifier: widget.youtubeCaptionsNotifier,
          showYoutubeCaptionToggle: widget.showYoutubeCaptionToggle,
        ),
      );
    } finally {
      if (mounted) {
        // Save position from fullscreen then reset isReady + gate so the inline
        // WebView's own isReady event (not the stale flag) triggers seekTo.
        _resumePosition = c.value.position;
        _previousIsReady = false;
        _previousIsPlaying = false;
        _holdWakelockThroughSwap(c);
        c.updateValue(c.value.copyWith(isReady: false));
        _isFullscreen.value = false;
      }
    }
  }

  @override
  void didUpdateWidget(GalleryYoutubeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepScreenOnWhilePlaying != widget.keepScreenOnWhilePlaying) {
      _syncWakelock();
    }
    if (oldWidget.youtubeCaptionsNotifier != widget.youtubeCaptionsNotifier) {
      oldWidget.youtubeCaptionsNotifier.removeListener(_applyCaptions);
      widget.youtubeCaptionsNotifier.addListener(_applyCaptions);
      _applyCaptions();
    } else if (oldWidget.youtubeCaptionLanguage !=
        widget.youtubeCaptionLanguage) {
      _applyCaptions();
    }
  }

  @override
  void dispose() {
    widget.youtubeCaptionsNotifier.removeListener(_applyCaptions);
    _isFullscreen.dispose();
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
              _buildPlayer(),
              GalleryMediaTapOverlay(galleryBloc: widget.galleryBloc),
              if (isOffline)
                Positioned.fill(child: _buildOfflineView())
              else
                ...[
                  // Until the controller exists / the player reports ready, the
                  // WebView paints black — cover it with the loader so a swipe
                  // between videos shows progress instead of a black screen.
                  if (_controller == null)
                    const GalleryMediaLoader()
                  else
                    AnimatedBuilder(
                      animation: _controller!,
                      builder: (context, _) {
                        final c = _controller;
                        if (c == null) return const SizedBox.shrink();
                        final v = c.value;
                        if (!v.isReady) return const GalleryMediaLoader();
                        return Center(
                          child: GalleryCenterControls(
                            isPlaying: v.isPlaying,
                            isReady: v.isReady,
                            bufferingStream: null,
                            initialBuffering:
                            v.playerState == PlayerState.buffering,
                            galleryBloc: widget.galleryBloc,
                            onTap: _togglePlayPause,
                          ),
                        );
                      },
                    ),
                  if (_controller != null)
                    Positioned.fill(
                      child: GalleryYoutubeFullscreenButton(
                        galleryBloc: widget.galleryBloc,
                        onTap: _enterFullscreen,
                        leading: widget.showYoutubeCaptionToggle
                            ? GalleryYoutubeCaptionsButton(
                                captionsEnabled: widget.youtubeCaptionsNotifier,
                                onTap: _toggleCaptions,
                              )
                            : null,
                      ),
                    ),
                ],
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

  Widget _buildPlayer() {
    final c = _controller;
    if (c == null) {
      return const SizedBox.expand(child: ColoredBox(color: Colors.black));
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _isFullscreen,
      builder: (context, fullscreen, _) {
        if (fullscreen) {
          // Fullscreen route owns the WebView; render a placeholder here
          // so two YoutubePlayer widgets aren't bound to one controller.
          return const SizedBox.expand(child: ColoredBox(color: Colors.black));
        }
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              controller: c,
              showVideoProgressIndicator: false,
              bottomActions: const [],
              topActions: const [],
              bufferIndicator: const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
