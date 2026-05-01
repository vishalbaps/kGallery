import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/gallery_theme.dart';

/// Landscape fullscreen route that hosts an existing [YoutubePlayerController]
/// without recreating it — playback continues seamlessly.
///
/// Built as a [PageRoute] so the gallery can call `Navigator.of(context).push`
/// directly. Forces landscape on push and restores portrait on pop.
class GalleryYoutubeFullscreenRoute<T> extends PageRoute<T> {
  final YoutubePlayerController ytController;
  final GalleryTheme? theme;

  GalleryYoutubeFullscreenRoute({
    required this.ytController,
    this.theme,
  });

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => Colors.black;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  TickerFuture didPush() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return super.didPop(result);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _FullscreenContent(controller: ytController, theme: theme);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}

class _FullscreenContent extends StatelessWidget {
  final YoutubePlayerController controller;
  final GalleryTheme? theme;

  const _FullscreenContent({required this.controller, this.theme});

  @override
  Widget build(BuildContext context) {
    final activeColor = theme?.seekbarActiveColor ?? Colors.white;
    final inactiveColor = theme?.seekbarInactiveColor ?? Colors.white30;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(
                  controller: controller,
                  showVideoProgressIndicator: false,
                  bottomActions: const [],
                  topActions: const [],
                  bufferIndicator: const SizedBox.shrink(),
                ),
              ),
            ),
            // Center play/pause + buffering indicator.
            Center(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final v = controller.value;
                  if (!v.isReady) {
                    return const CircularProgressIndicator(
                      color: Colors.white,
                    );
                  }
                  if (v.playerState == PlayerState.buffering) {
                    return const CircularProgressIndicator(
                      color: Colors.white,
                    );
                  }
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        v.isPlaying ? controller.pause() : controller.play(),
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          v.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Bottom controls: "00:00 / 10:00" timer on the left, exit-
            // fullscreen button on the right (mirroring media_kit's
            // fullscreen layout), with the seekbar directly underneath.
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final position = controller.value.position;
                    final duration = controller.metadata.duration;
                    double max = duration.inMilliseconds.toDouble();
                    double val = position.inMilliseconds.toDouble();
                    if (max <= 0) max = 1.0;
                    if (val < 0) val = 0.0;
                    if (val > max) val = max;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => Navigator.of(context).maybePop(),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
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
                          child: Slider(
                            value: val,
                            max: max,
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            onChanged: (value) => controller.seekTo(
                              Duration(milliseconds: value.toInt()),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}
