import 'package:flutter/material.dart';

/// Wraps a child widget (typically an image) with pinch + double-tap zoom.
///
/// Built on Flutter's [InteractiveViewer]. Exposes the current scale via
/// [scaleNotifier] so parent widgets can react (e.g. disable a parent
/// [PageView] while zoomed, or hide overlay UI on pinch-in).
class ZoomableImage extends StatefulWidget {
  final Widget child;
  final ValueNotifier<double> scaleNotifier;
  final double minScale;
  final double maxScale;
  final double doubleTapScale;
  final Duration animationDuration;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const ZoomableImage({
    super.key,
    required this.child,
    required this.scaleNotifier,
    this.minScale = 0.9,
    this.maxScale = 3.0,
    this.doubleTapScale = 2.5,
    this.animationDuration = const Duration(milliseconds: 250),
    this.onZoomIn,
    this.onZoomOut,
  });

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage>
    with SingleTickerProviderStateMixin {
  late final TransformationController _controller;
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;
  Offset _doubleTapPosition = Offset.zero;
  bool _wasZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addListener(_onAnimate);
  }

  @override
  void dispose() {
    _animController
      ..removeListener(_onAnimate)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onAnimate() {
    if (_animation != null) {
      _controller.value = _animation!.value;
    }
  }

  void _emitScale() {
    final scale = _controller.value.getMaxScaleOnAxis();
    widget.scaleNotifier.value = scale;
    final isZoomed = scale > 1.01;
    if (isZoomed != _wasZoomed) {
      _wasZoomed = isZoomed;
      if (isZoomed) {
        widget.onZoomIn?.call();
      } else {
        widget.onZoomOut?.call();
      }
    }
  }

  void _handleDoubleTap() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final isZoomed = currentScale > 1.01;

    final Matrix4 end;
    if (isZoomed) {
      end = Matrix4.identity();
    } else {
      final s = widget.doubleTapScale;
      end = Matrix4.identity()
        ..translateByDouble(
          -_doubleTapPosition.dx * (s - 1),
          -_doubleTapPosition.dy * (s - 1),
          0,
          1,
        )
        ..scaleByDouble(s, s, 1, 1);
    }

    _animation = Matrix4Tween(begin: _controller.value, end: end).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );
    _animController
      ..reset()
      ..forward().whenComplete(_emitScale);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTapDown: (details) {
        _doubleTapPosition = details.localPosition;
      },
      onDoubleTap: _handleDoubleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final scale = _controller.value.getMaxScaleOnAxis();
          // Disable single-finger pan while at base scale so parent
          // drag-to-dismiss recognizers can claim vertical drags.
          final canPan = scale > 1.01;
          return InteractiveViewer(
            transformationController: _controller,
            minScale: widget.minScale,
            maxScale: widget.maxScale,
            clipBehavior: Clip.none,
            panEnabled: canPan,
            onInteractionEnd: (_) => _emitScale(),
            child: widget.child,
          );
        },
      ),
    );
  }
}
