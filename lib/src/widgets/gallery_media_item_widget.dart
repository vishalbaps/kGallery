import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:extended_image/extended_image.dart';
import '../bloc/gallery_bloc.dart';
import '../models/gallery_item.dart';

class GalleryMediaItemWidget extends StatefulWidget {
  final GalleryItem item;
  final int index;
  final ValueNotifier<Player?> activePlayerNotifier;
  final bool isAudio;

  const GalleryMediaItemWidget({
    super.key,
    required this.item,
    required this.index,
    required this.activePlayerNotifier,
    this.isAudio = false,
  });

  @override
  State<GalleryMediaItemWidget> createState() => _GalleryMediaItemWidgetState();
}

class _GalleryMediaItemWidgetState extends State<GalleryMediaItemWidget> {
  late final Player player;
  late final VideoController videoController;

  @override
  void initState() {
    super.initState();
    player = Player();
    videoController = VideoController(player);

    player.open(Media(widget.item.url), play: false);

    // Check if we are initially the active item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = context.read<GalleryBloc>().state;
        if (state.currentIndex == widget.index) {
          widget.activePlayerNotifier.value = player;
          player.play();
        }
      }
    });
  }

  @override
  void dispose() {
    if (widget.activePlayerNotifier.value == player) {
      widget.activePlayerNotifier.value = null;
    }
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GalleryBloc, GalleryState>(
      listenWhen: (previous, current) =>
          previous.currentIndex != current.currentIndex,
      listener: (context, state) {
        if (state.currentIndex == widget.index) {
          widget.activePlayerNotifier.value = player;
          player.play();
        } else {
          player.pause();
          if (widget.activePlayerNotifier.value == player) {
            widget.activePlayerNotifier.value = null;
          }
        }
      },
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
                    AnimatedOpacity(
                      opacity: isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (isPlaying) {
                            player.pause();
                          } else {
                            player.play();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(
                            40.0,
                          ), // Expands the clickable area
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
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
