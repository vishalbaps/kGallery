import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:extended_image/extended_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../bloc/gallery_bloc.dart';
import '../models/gallery_item.dart';

/// Internal widget for displaying an individual media item (Video or Audio).
///
/// Handles initialization of [Player], connectivity checks, and playback logic.
class GalleryMediaItemWidget extends StatefulWidget {
  /// The media item to display.
  final GalleryItem item;

  /// The index of this item in the gallery.
  final int index;

  /// Notifier to communicate the active [Player] to the parent gallery.
  /// Whether this item represents audio-only content.
  final bool isAudio;

  /// Custom message shown when no internet is detected.
  final String? noInternetMessage;

  const GalleryMediaItemWidget({
    super.key,
    required this.item,
    required this.index,
    required this.activePlayerNotifier,
    this.isAudio = false,
    this.noInternetMessage,
  });

  @override
  State<GalleryMediaItemWidget> createState() => _GalleryMediaItemWidgetState();
}

class _GalleryMediaItemWidgetState extends State<GalleryMediaItemWidget> {
  late final Player player;
  late final VideoController videoController;
  Timer? _hideUITimer;
  StreamSubscription? _playingSubscription;

  void _startHideUITimer() {
    _hideUITimer?.cancel();
    _hideUITimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final state = context.read<GalleryBloc>().state;
        if (state.isUIVisible && state.currentIndex == widget.index) {
          context.read<GalleryBloc>().add(GalleryToggleUI(isVisible: false));
        }
      }
    });
  }

  void _cancelHideUITimer() {
    _hideUITimer?.cancel();
  }

  @override
  void initState() {
    super.initState();
    player = Player();
    videoController = VideoController(player);

    player.open(Media(widget.item.url), play: false);

    _playingSubscription = player.stream.playing.listen((isPlaying) {
      if (mounted) {
        final state = context.read<GalleryBloc>().state;
        if (isPlaying &&
            state.isUIVisible &&
            state.currentIndex == widget.index) {
          _startHideUITimer();
        } else {
          _cancelHideUITimer();
        }
      }
    });

    // Check if we are initially the active item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = context.read<GalleryBloc>().state;
        if (state.currentIndex == widget.index) {
          widget.activePlayerNotifier.value = player;
          _playWithConnectivityCheck();
        }
      }
    });
  }

  Future<void> _playWithConnectivityCheck() async {
    if (!widget.item.url.startsWith('http')) {
      player.play();
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
          context.read<GalleryBloc>().state.currentIndex == widget.index) {
        player.play();
      }
    }
  }

  @override
  void dispose() {
    _hideUITimer?.cancel();
    _playingSubscription?.cancel();
    if (widget.activePlayerNotifier.value == player) {
      widget.activePlayerNotifier.value = null;
    }
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<GalleryBloc, GalleryState>(
          listenWhen: (previous, current) =>
              previous.currentIndex != current.currentIndex,
          listener: (context, state) {
            if (state.currentIndex == widget.index) {
              widget.activePlayerNotifier.value = player;
              _playWithConnectivityCheck();
            } else {
              player.pause();
              if (widget.activePlayerNotifier.value == player) {
                widget.activePlayerNotifier.value = null;
              }
            }
          },
        ),
        BlocListener<GalleryBloc, GalleryState>(
          listenWhen: (previous, current) =>
              previous.isUIVisible != current.isUIVisible,
          listener: (context, state) {
            if (state.currentIndex == widget.index) {
              if (state.isUIVisible && player.state.playing) {
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
            if (widget.item.thumbnailUrl != null)
              Center(
                child: ExtendedImage.network(
                  widget.item.thumbnailUrl!,
                  fit: BoxFit.contain,
                ),
              )
            else
              const Center(
                child: Icon(Icons.audiotrack, size: 100, color: Colors.white54),
              )
          else
            Center(
              child: Video(
                controller: videoController,
                controls: NoVideoControls,
                fit: BoxFit.contain,
              ),
            ),

          // Transparent overlay to catch taps for toggling UI (only for background, not play/pause)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final bloc = context.read<GalleryBloc>();
                bloc.add(GalleryToggleUI(isVisible: !bloc.state.isUIVisible));
              },
              child: const SizedBox.expand(),
            ),
          ),

          // Central Controls: Play/Pause button & Buffering indicator
          Center(
            child: StreamBuilder<bool>(
              initialData: player.state.playing,
              stream: player.stream.playing,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Buffering indicator (only when playing)
                    if (isPlaying)
                      StreamBuilder<bool>(
                        initialData: player.state.buffering,
                        stream: player.stream.buffering,
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
                      buildWhen: (previous, current) =>
                          previous.isUIVisible != current.isUIVisible,
                      builder: (context, galleryState) {
                        final isVisible = galleryState.isUIVisible;

                        return StreamBuilder<bool>(
                          initialData: player.state.buffering,
                          stream: player.stream.buffering,
                          builder: (context, bufferingSnapshot) {
                            final isBuffering = bufferingSnapshot.data ?? false;

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
                                      player.pause();
                                    } else {
                                      _playWithConnectivityCheck();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      40.0,
                                    ), // Expands the clickable area
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
        ],
      ),
    );
  }
}
