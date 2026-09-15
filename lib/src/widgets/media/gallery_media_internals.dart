import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../bloc/gallery_bloc.dart';

/// Shared internals for the per-type media item widgets
/// (video / audio / youtube). None of these are exported from the
/// public API; they live here to keep each per-type widget focused.

/// Mixin providing the 3s "auto-hide UI while playing" timer.
///
/// The timer is owned by the State so that it cancels automatically when
/// the widget is disposed via the explicit [cancelHideUITimer] call from
/// the using widget's [State.dispose].
mixin GalleryUIHideMixin<T extends StatefulWidget> on State<T> {
  Timer? _hideUITimer;

  void startHideUITimer(GalleryBloc bloc, int index) {
    _hideUITimer?.cancel();
    _hideUITimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final state = bloc.state;
      if (state.isUIVisible && state.currentIndex == index) {
        bloc.add(GalleryToggleUI(isVisible: false));
      }
    });
  }

  void cancelHideUITimer() {
    _hideUITimer?.cancel();
    _hideUITimer = null;
  }
}

/// Center play/pause button + buffering indicator.
///
/// Two driving modes:
/// - `bufferingStream != null`: media_kit path — buffering live-updates
///   via [StreamBuilder].
/// - `bufferingStream == null`: synchronous mode used by callers that
///   already drive rebuilds themselves (e.g. youtube via
///   [YoutubeValueBuilder]).
class GalleryCenterControls extends StatelessWidget {
  final bool isPlaying;
  final bool isReady;
  final Stream<bool>? bufferingStream;
  final bool initialBuffering;
  final GalleryBloc galleryBloc;
  final VoidCallback onTap;

  const GalleryCenterControls({
    super.key,
    required this.isPlaying,
    required this.isReady,
    required this.bufferingStream,
    required this.initialBuffering,
    required this.galleryBloc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bufferingWidget = bufferingStream != null
        ? StreamBuilder<bool>(
            initialData: initialBuffering,
            stream: bufferingStream,
            builder: (context, s) {
              final b = s.data ?? false;
              if (!b || !isPlaying) return const SizedBox.shrink();
              return const CircularProgressIndicator(color: Colors.white);
            },
          )
        : (initialBuffering ? const CircularProgressIndicator(color: Colors.white) : const SizedBox.shrink());

    return Stack(
      alignment: Alignment.center,
      children: [
        bufferingWidget,
        BlocBuilder<GalleryBloc, GalleryState>(
          bloc: galleryBloc,
          buildWhen: (prev, curr) => prev.isUIVisible != curr.isUIVisible,
          builder: (context, state) {
            final isVisible = state.isUIVisible;
            final hideButton = !isVisible || (isPlaying && initialBuffering) || !isReady;
            return IgnorePointer(
              ignoring: hideButton,
              child: AnimatedOpacity(
                opacity: hideButton ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
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
            );
          },
        ),
      ],
    );
  }
}

class GalleryMediaLoader extends StatelessWidget {
  const GalleryMediaLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

/// Shared rendering for the fullscreen button — positions itself inside
/// the visible video frame computed from [videoAspect] and screen aspect.
class GalleryFullscreenButton extends StatelessWidget {
  final double videoAspect;
  final GalleryBloc galleryBloc;
  final VoidCallback onTap;

  const GalleryFullscreenButton({
    super.key,
    required this.videoAspect,
    required this.galleryBloc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double screenAspect = screenSize.width / screenSize.height;
    final double renderedH = videoAspect >= screenAspect ? screenSize.width / videoAspect : screenSize.height;
    final double renderedW = videoAspect >= screenAspect ? screenSize.width : screenSize.height * videoAspect;

    final double buttonBottom = (screenSize.height - renderedH) / 2 + 16.0;
    final double buttonRight = (screenSize.width - renderedW) / 2 + 16.0;

    return BlocBuilder<GalleryBloc, GalleryState>(
      bloc: galleryBloc,
      buildWhen: (prev, curr) => prev.isUIVisible != curr.isUIVisible || prev.isSliding != curr.isSliding,
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
  }
}

/// Fullscreen button for media_kit video. Hidden for vertical videos.
///
/// Subscribes once to the player's width/height streams and stores the
/// values in state — replaces the previous nested `StreamBuilder<int?>`
/// pair that rebuilt twice per dimension change.
class GalleryMediaKitFullscreenButton extends StatefulWidget {
  final Player player;
  final GalleryBloc galleryBloc;
  final VoidCallback onTap;

  const GalleryMediaKitFullscreenButton({
    super.key,
    required this.player,
    required this.galleryBloc,
    required this.onTap,
  });

  @override
  State<GalleryMediaKitFullscreenButton> createState() => _GalleryMediaKitFullscreenButtonState();
}

class _GalleryMediaKitFullscreenButtonState extends State<GalleryMediaKitFullscreenButton> {
  int? _width;
  int? _height;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;

  @override
  void initState() {
    super.initState();
    _width = widget.player.state.width;
    _height = widget.player.state.height;
    _widthSub = widget.player.stream.width.listen((w) {
      if (!mounted || w == _width) return;
      setState(() => _width = w);
    });
    _heightSub = widget.player.stream.height.listen((h) {
      if (!mounted || h == _height) return;
      setState(() => _height = h);
    });
  }

  @override
  void dispose() {
    _widthSub?.cancel();
    _heightSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = _width;
    final h = _height;
    if (w == null || h == null || w <= h) return const SizedBox.shrink();
    return GalleryFullscreenButton(
      videoAspect: w / h,
      galleryBloc: widget.galleryBloc,
      onTap: widget.onTap,
    );
  }
}

/// Transparent overlay that toggles UI on tap. Shared across all media
/// item types.
class GalleryMediaTapOverlay extends StatelessWidget {
  final GalleryBloc galleryBloc;

  const GalleryMediaTapOverlay({super.key, required this.galleryBloc});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          galleryBloc.add(GalleryToggleUI(isVisible: !galleryBloc.state.isUIVisible));
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}


/// Signature for laying out a [GalleryYoutubeSeekbar]. Receives the current
/// [position], the video [duration], and the ready-made [slider] so each
/// caller can arrange them to suit its own chrome.
typedef GalleryYoutubeSeekbarLayout = Widget Function(
  BuildContext context,
  Duration position,
  Duration duration,
  Widget slider,
);

/// Seekbar for YouTube items.
///
/// The v10 controller no longer carries playback position on its value —
/// position arrives on [YoutubePlayerController.videoStateStream] — so this
/// widget owns that subscription. While the user is dragging, stream updates
/// are ignored and the thumb follows the finger; the seek is issued once on
/// release. Without that latch the ~10 Hz position feed fights the drag.
class GalleryYoutubeSeekbar extends StatefulWidget {
  final YoutubePlayerController controller;
  final Color activeColor;
  final Color inactiveColor;
  final GalleryYoutubeSeekbarLayout layout;

  const GalleryYoutubeSeekbar({
    super.key,
    required this.controller,
    required this.activeColor,
    required this.inactiveColor,
    required this.layout,
  });

  @override
  State<GalleryYoutubeSeekbar> createState() => _GalleryYoutubeSeekbarState();
}

class _GalleryYoutubeSeekbarState extends State<GalleryYoutubeSeekbar> {
  StreamSubscription<YoutubeVideoState>? _stateSub;
  Duration _position = Duration.zero;

  /// Non-null while a drag is in flight; holds the pending position in ms.
  double? _dragMilliseconds;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(GalleryYoutubeSeekbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _stateSub?.cancel();
      _position = Duration.zero;
      _dragMilliseconds = null;
      _subscribe();
    }
  }

  void _subscribe() {
    _stateSub = widget.controller.videoStateStream.listen((state) {
      if (!mounted || _dragMilliseconds != null) return;
      if (state.position == _position) return;
      setState(() => _position = state.position);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.metadata.duration;
    double max = duration.inMilliseconds.toDouble();
    if (max <= 0) max = 1.0;

    final raw = _dragMilliseconds ?? _position.inMilliseconds.toDouble();
    final value = raw.clamp(0.0, max);

    final slider = Slider(
      value: value,
      max: max,
      activeColor: widget.activeColor,
      inactiveColor: widget.inactiveColor,
      onChangeStart: (v) => setState(() => _dragMilliseconds = v),
      onChanged: (v) => setState(() => _dragMilliseconds = v),
      onChangeEnd: (v) {
        ignorePlayerCommandError(
          widget.controller.seekTo(seconds: v / 1000, allowSeekAhead: true),
        );
        setState(() {
          _position = Duration(milliseconds: v.round());
          _dragMilliseconds = null;
        });
      },
    );

    return widget.layout(
      context,
      Duration(milliseconds: value.round()),
      duration,
      slider,
    );
  }
}

/// Fire-and-forget a YouTube player command, swallowing any failure.
///
/// Commands travel through the IFrame JS bridge, which queues them behind a
/// readiness future and throws a `TimeoutException` if the player never
/// reports in — e.g. the viewer swiped past the item while it was still
/// loading. Nothing awaits these calls, so an unguarded one surfaces as an
/// unhandled exception long after the widget is gone. The package guards its
/// own teardown command the same way.
void ignorePlayerCommandError(Future<void> command) {
  unawaited(command.catchError((Object _, StackTrace __) {}));
}

/// Formats a duration as `m:ss`, or `h:mm:ss` past the hour.
String formatGalleryDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) return '${d.inHours}:$minutes:$seconds';
  return '$minutes:$seconds';
}
