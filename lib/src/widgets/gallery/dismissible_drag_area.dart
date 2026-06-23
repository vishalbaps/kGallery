import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps a child with vertical-drag-to-dismiss behavior (Apple Photos style).
///
/// While dragging the child translates with the finger and subtly shrinks.
/// The background fade is driven via [onDragProgress] (0.0 = opaque, 1.0 = transparent).
///
/// On release past [dismissThreshold] / [velocityThreshold], the child
/// flies off the bottom of the screen and THEN [onDismiss] is called so the
/// route pop happens after the animation (no abrupt cut).
///
/// On release below the threshold, the child snaps back with a spring curve.
///
/// If [scaleNotifier] value is > 1.0, drag is suppressed so zoomed-in
/// images can still be panned without triggering a dismiss.
class DismissibleDragArea extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final bool enabled;
  final ValueListenable<double>? scaleNotifier;
  final double dismissThreshold;
  final double velocityThreshold;
  final double horizontalCancelRatio;
  final Duration snapBackDuration;
  final ValueChanged<double>? onDragProgress;
  final ValueChanged<bool>? onDragActiveChanged;

  const DismissibleDragArea({
    super.key,
    required this.child,
    required this.onDismiss,
    this.enabled = true,
    this.scaleNotifier,
    this.dismissThreshold = 150.0,
    this.velocityThreshold = 700.0,
    this.horizontalCancelRatio = 1.0,
    this.snapBackDuration = const Duration(milliseconds: 200),
    this.onDragProgress,
    this.onDragActiveChanged,
  });

  @override
  State<DismissibleDragArea> createState() => _DismissibleDragAreaState();
}

class _DismissibleDragAreaState extends State<DismissibleDragArea> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  Animation<Offset>? _offsetAnimation;
  Offset _offset = Offset.zero;
  bool _dragging = false;
  double _screenHeight = 800.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this)..addListener(_onAnimate);
  }

  @override
  void dispose() {
    _animController
      ..removeListener(_onAnimate)
      ..dispose();
    super.dispose();
  }

  bool get _isZoomed => (widget.scaleNotifier?.value ?? 1.0) > 1.01;

  void _onAnimate() {
    if (_offsetAnimation != null) {
      setState(() {
        _offset = _offsetAnimation!.value;
      });
      _emitProgress();
    }
  }

  void _emitProgress() {
    final progress = (_offset.dy.abs() / 400.0).clamp(0.0, 1.0);
    widget.onDragProgress?.call(progress);
  }

  void _setDragging(bool dragging) {
    if (_dragging == dragging) return;
    _dragging = dragging;
    widget.onDragActiveChanged?.call(dragging);
  }

  void _handleStart(DragStartDetails details) {
    if (!widget.enabled || _isZoomed) return;
    _animController.stop();
    _setDragging(true);
  }

  void _handleUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    setState(() {
      _offset += details.delta;
    });
    _emitProgress();
  }

  void _handleEnd(DragEndDetails details) {
    if (!_dragging) return;

    final dy = _offset.dy;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final shouldDismiss = widget.enabled && (dy > widget.dismissThreshold || velocity > widget.velocityThreshold);

    if (shouldDismiss) {
      // Keep _dragging=true so _handleDragEnded never fires (no opacity flash).
      // The fly-away animation handles everything; onDismiss fires at the end.
      _flyAway();
    } else {
      _setDragging(false);
      _snapBack();
    }
  }

  void _handleCancel() {
    if (!_dragging) return;
    _setDragging(false);
    _snapBack();
  }

  /// Animates the image off the bottom of the screen, then calls [onDismiss].
  void _flyAway() {
    final targetDy = _screenHeight + 200.0;
    _offsetAnimation = Tween<Offset>(
      begin: _offset,
      end: Offset(0, targetDy),
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.duration = const Duration(milliseconds: 280);
    _animController
      ..reset()
      ..forward().whenComplete(widget.onDismiss);
  }

  void _snapBack() {
    _offsetAnimation = Tween<Offset>(
      begin: _offset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.duration = widget.snapBackDuration;
    _animController
      ..reset()
      ..forward();
  }

  /// Subtle scale-down while dragging downward — gives the Apple Photos feel.
  double get _dragScale {
    if (_offset.dy <= 0) return 1.0;
    final progress = (_offset.dy / 400.0).clamp(0.0, 1.0);
    return 1.0 - progress * 0.12;
  }

  @override
  Widget build(BuildContext context) {
    _screenHeight = MediaQuery.of(context).size.height;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _handleStart,
      onVerticalDragUpdate: _handleUpdate,
      onVerticalDragEnd: _handleEnd,
      onVerticalDragCancel: _handleCancel,
      child: Transform.scale(
        scale: _dragScale,
        child: Transform.translate(
          offset: _offset,
          child: widget.child,
        ),
      ),
    );
  }
}
