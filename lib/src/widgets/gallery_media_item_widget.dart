import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:extended_image/extended_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../bloc/gallery_bloc.dart';
import '../models/gallery_item.dart';
import '../models/gallery_theme.dart';

/// Internal widget for displaying an individual media item (Video or Audio).
///
/// Handles initialization of [Player], connectivity checks, and playback logic.
class GalleryMediaItemWidget extends StatefulWidget {
  /// The media item to display.
  final GalleryItem item;

  /// The index of this item in the gallery.
  final int index;

  /// Notifier to communicate the active [Player] to the parent gallery.
  final ValueNotifier<Player?> activePlayerNotifier;

  /// The bloc managing the gallery state.
  final GalleryBloc galleryBloc;

  /// Whether this item represents audio-only content.
  final bool isAudio;

  /// Custom message shown when no internet is detected.
  final String? noInternetMessage;

  /// Gallery theme used to color the fullscreen seek bar.
  final GalleryTheme? theme;

  const GalleryMediaItemWidget({
    super.key,
    required this.item,
    required this.index,
    required this.activePlayerNotifier,
    required this.galleryBloc,
    this.isAudio = false,
    this.noInternetMessage,
    this.theme,
  });

  @override
  State<GalleryMediaItemWidget> createState() => _GalleryMediaItemWidgetState();
}

class _GalleryMediaItemWidgetState extends State<GalleryMediaItemWidget> {
  // Only the widget that is the current gallery item owns a live Player.
  // This prevents multiple media_kit Players from competing for iOS's
  // global AVAudioSession, which would otherwise interrupt playback.
  Player? _player;
  VideoController? _videoController;
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();
  Timer? _hideUITimer;
  StreamSubscription? _playingSubscription;
  StreamSubscription? _completedSubscription;

  void _startHideUITimer() {
    _hideUITimer?.cancel();
    _hideUITimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final state = widget.galleryBloc.state;
        if (state.isUIVisible && state.currentIndex == widget.index) {
          widget.galleryBloc.add(GalleryToggleUI(isVisible: false));
        }
      }
    });
  }

  void _cancelHideUITimer() {
    _hideUITimer?.cancel();
  }

  Future<void> _enterFullscreen() async {
    _cancelHideUITimer();
    await _videoKey.currentState?.enterFullscreen();
    final p = _player;
    if (mounted && p != null && p.state.playing) _startHideUITimer();
  }

  @override
  void initState() {
    super.initState();
    // Always defer to post-frame: _activatePlayer sets activePlayerNotifier.value,
    // which would notify ValueListenableBuilder and call setState during the build
    // phase if invoked synchronously from initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.galleryBloc.state.currentIndex == widget.index) {
        _activatePlayer();
      }
    });
  }

  void _activatePlayer() {
    if (_player != null) return;
    final p = Player();
    _player = p;
    _videoController = VideoController(p);

    _playingSubscription = p.stream.playing.listen((isPlaying) {
      if (!mounted) return;
      final state = widget.galleryBloc.state;
      if (isPlaying &&
          state.isUIVisible &&
          state.currentIndex == widget.index) {
        _startHideUITimer();
      } else {
        _cancelHideUITimer();
      }
    });

    _completedSubscription = p.stream.completed.listen((completed) {
      if (!mounted || !completed) return;
      p.seek(Duration.zero);
      p.pause();
      _cancelHideUITimer();
      final state = widget.galleryBloc.state;
      if (!state.isUIVisible && state.currentIndex == widget.index) {
        widget.galleryBloc.add(GalleryToggleUI(isVisible: true));
      }
    });

    p.open(Media(widget.item.url), play: false);
    widget.activePlayerNotifier.value = p;
    _playWithConnectivityCheck();

    if (mounted) setState(() {});
  }

  void _deactivatePlayer({bool fromDispose = false}) {
    final p = _player;
    if (p == null) return;
    _hideUITimer?.cancel();
    _playingSubscription?.cancel();
    _playingSubscription = null;
    _completedSubscription?.cancel();
    _completedSubscription = null;
    _player = null;
    _videoController = null;
    p.dispose();

    final notifier = widget.activePlayerNotifier;
    if (fromDispose) {
      // During dispose the widget tree is locked — defer the notifier update
      // to avoid triggering setState on ValueListenableBuilder listeners.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (notifier.value == p) notifier.value = null;
      });
    } else {
      if (notifier.value == p) notifier.value = null;
      if (mounted) setState(() {});
    }
  }

  Future<void> _playWithConnectivityCheck() async {
    final p = _player;
    if (p == null) return;

    if (!widget.item.url.startsWith('http')) {
      p.play();
      return;
    }

    final List<ConnectivityResult> connectivityResult =
        await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.noInternetMessage ??
                  'No internet connection. Please check your network.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted &&
          _player == p &&
          widget.galleryBloc.state.currentIndex == widget.index) {
        p.play();
      }
    }
  }

  @override
  void dispose() {
    _deactivatePlayer(fromDispose: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<GalleryBloc, GalleryState>(
          bloc: widget.galleryBloc,
          listenWhen: (previous, current) =>
              previous.currentIndex != current.currentIndex,
          listener: (context, state) {
            if (state.currentIndex == widget.index) {
              _activatePlayer();
            } else {
              _deactivatePlayer();
            }
          },
        ),
        BlocListener<GalleryBloc, GalleryState>(
          bloc: widget.galleryBloc,
          listenWhen: (previous, current) =>
              previous.isUIVisible != current.isUIVisible,
          listener: (context, state) {
            final p = _player;
            if (p == null) return;
            if (state.currentIndex == widget.index) {
              if (state.isUIVisible && p.state.playing) {
                _startHideUITimer();
              } else {
                _cancelHideUITimer();
              }
            }
          },
        ),
      ],
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.isAudio)
            Center(
              child: widget.item.thumbnailUrl != null
                  ? ExtendedImage.network(
                      widget.item.thumbnailUrl!,
                      fit: BoxFit.contain,
                      loadStateChanged: (ExtendedImageState state) {
                        if (state.extendedImageLoadState == LoadState.failed) {
                          return const Icon(
                            Icons.audiotrack,
                            size: 100,
                            color: Colors.white54,
                          );
                        }
                        return null;
                      },
                    )
                  : const Icon(
                      Icons.audiotrack,
                      size: 100,
                      color: Colors.white54,
                    ),
            )
          else
            Center(
              child: _videoController != null
                  ? Video(
                      key: _videoKey,
                      controller: _videoController!,
                      controls: (state) {
                        bool inFullscreen;
                        try {
                          inFullscreen = state.isFullscreen();
                        } catch (_) {
                          inFullscreen = false;
                        }
                        if (!inFullscreen) return const SizedBox.shrink();

                        final activeColor =
                            widget.theme?.seekbarActiveColor ?? Colors.white;
                        final inactiveColor =
                            widget.theme?.seekbarInactiveColor ??
                                Colors.white30;
                        final themeData = MaterialVideoControlsThemeData(
                          seekBarPositionColor: activeColor,
                          seekBarThumbColor: activeColor,
                          seekBarColor: inactiveColor,
                          seekBarBufferColor: inactiveColor,
                          bottomButtonBarMargin:  const EdgeInsets.only(left: 16.0, right: 8.0, bottom: 16),
                          seekBarMargin: const EdgeInsets.only(
                            left: 16.0,
                            right: 16.0,
                            bottom: 16.0,
                          ),
                        );
                        return MaterialVideoControlsTheme(
                          normal: themeData,
                          fullscreen: themeData,
                          child: MaterialVideoControls(state),
                        );
                      },
                      fit: BoxFit.contain,
                    )
                  : const SizedBox.expand(
                      child: ColoredBox(color: Colors.black),
                    ),
            ),

          // Transparent overlay to catch taps for toggling UI (only for background, not play/pause)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final bloc = widget.galleryBloc;
                bloc.add(GalleryToggleUI(isVisible: !bloc.state.isUIVisible));
              },
              child: const SizedBox.expand(),
            ),
          ),

          // Central Controls: Play/Pause button & Buffering indicator (only when this is the active item)
          if (_player != null)
            Center(
              child: StreamBuilder<bool>(
                initialData: _player!.state.playing,
                stream: _player!.stream.playing,
                builder: (context, snapshot) {
                  final p = _player;
                  if (p == null) return const SizedBox.shrink();
                  final isPlaying = snapshot.data ?? false;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Buffering indicator (only when playing)
                      if (isPlaying)
                        StreamBuilder<bool>(
                          initialData: p.state.buffering,
                          stream: p.stream.buffering,
                          builder: (context, bufferingSnapshot) {
                            final isBuffering = bufferingSnapshot.data ?? false;
                            if (!isBuffering) return const SizedBox.shrink();

                            return const CircularProgressIndicator(
                              color: Colors.white,
                            );
                          },
                        ),

                      // Play/Pause button
                      BlocBuilder<GalleryBloc, GalleryState>(
                        bloc: widget.galleryBloc,
                        buildWhen: (previous, current) =>
                            previous.isUIVisible != current.isUIVisible,
                        builder: (context, galleryState) {
                          final isVisible = galleryState.isUIVisible;

                          return StreamBuilder<bool>(
                            initialData: p.state.buffering,
                            stream: p.stream.buffering,
                            builder: (context, bufferingSnapshot) {
                              final isBuffering =
                                  bufferingSnapshot.data ?? false;

                              // Hide the button if the UI is hidden, OR if it's currently buffering while playing
                              final bool hideButton =
                                  !isVisible || (isPlaying && isBuffering);

                              return IgnorePointer(
                                ignoring: hideButton,
                                child: AnimatedOpacity(
                                  opacity: hideButton ? 0.0 : 1.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (isPlaying) {
                                        p.pause();
                                      } else {
                                        _playWithConnectivityCheck();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(40.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

          // Fullscreen button — shown only for horizontal videos when UI is visible
          if (!widget.isAudio && _player != null)
            Positioned.fill(
              child: _FullscreenButtonOverlay(
                player: _player!,
                galleryBloc: widget.galleryBloc,
                onTap: _enterFullscreen,
              ),
            ),
        ],
      ),
    );
  }
}

class _FullscreenButtonOverlay extends StatelessWidget {
  final Player player;
  final GalleryBloc galleryBloc;
  final VoidCallback onTap;

  const _FullscreenButtonOverlay({
    required this.player,
    required this.galleryBloc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      initialData: player.state.width,
      stream: player.stream.width,
      builder: (context, widthSnapshot) {
        return StreamBuilder<int?>(
          initialData: player.state.height,
          stream: player.stream.height,
          builder: (context, heightSnapshot) {
            final videoW = widthSnapshot.data;
            final videoH = heightSnapshot.data;
            if (videoW == null || videoH == null || videoW <= videoH) {
              return const SizedBox.shrink();
            }

            // Compute where the video content sits when rendered with BoxFit.contain.
            final screenSize = MediaQuery.of(context).size;
            final double videoAspect = videoW / videoH;
            final double screenAspect = screenSize.width / screenSize.height;
            final double renderedH = videoAspect >= screenAspect
                ? screenSize.width / videoAspect
                : screenSize.height;
            final double renderedW = videoAspect >= screenAspect
                ? screenSize.width
                : screenSize.height * videoAspect;

            // Place button 16px inside the bottom-right corner of the video frame.
            final double buttonBottom =
                (screenSize.height - renderedH) / 2 + 16.0;
            final double buttonRight =
                (screenSize.width - renderedW) / 2 + 16.0;

            return BlocBuilder<GalleryBloc, GalleryState>(
              bloc: galleryBloc,
              buildWhen: (prev, curr) =>
                  prev.isUIVisible != curr.isUIVisible ||
                  prev.isSliding != curr.isSliding,
              builder: (context, state) {
                final visible = state.isUIVisible && !state.isSliding;
                return Stack(
                  children: [
                    Positioned(
                      bottom: buttonBottom,
                      right: buttonRight,
                      child: IgnorePointer(
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
                              child: const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

