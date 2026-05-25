import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps a child with vertical-drag-to-dismiss behavior.
///
/// Translates the child as the user drags vertically. If the drag passes
/// [dismissThreshold] (in pixels) or exceeds [velocityThreshold] (in px/s),
/// [onDismiss] is invoked. Otherwise the child snaps back to its origin.
///
/// Reports normalized drag progress (0.0–1.0) via [onDragProgress] so a
/// parent can fade a backdrop in sync with the gesture.
///
/// If [scaleNotifier] is provided and its value is > 1.0, drag is ignored —
/// useful when the child contains a zoomable image and pan should pass
/// through to the zoom controller instead.
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

class _DismissibleDragAreaState extends State<DismissibleDragArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snapBackController;
  Animation<Offset>? _snapBackAnimation;
  Offset _offset = Offset.zero;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _snapBackController = AnimationController(
      vsync: this,
      duration: widget.snapBackDuration,
    )..addListener(_onSnap);
  }

  @override
  void dispose() {
    _snapBackController
      ..removeListener(_onSnap)
      ..dispose();
    super.dispose();
  }

  bool get _isZoomed => (widget.scaleNotifier?.value ?? 1.0) > 1.01;

  void _onSnap() {
    if (_snapBackAnimation != null) {
      setState(() {
        _offset = _snapBackAnimation!.value;
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
    _snapBackController.stop();
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
    _setDragging(false);
    final dy = _offset.dy;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final shouldDismiss = widget.enabled &&
        (dy > widget.dismissThreshold || velocity > widget.velocityThreshold);

    if (shouldDismiss) {
      widget.onDismiss();
    } else {
      _snapBack();
    }
  }

  void _handleCancel() {
    if (!_dragging) return;
    _setDragging(false);
    _snapBack();
  }

  void _snapBack() {
    _snapBackAnimation = Tween<Offset>(begin: _offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.easeOut),
    );
    _snapBackController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _handleStart,
      onVerticalDragUpdate: _handleUpdate,
      onVerticalDragEnd: _handleEnd,
      onVerticalDragCancel: _handleCancel,
      child: Transform.translate(
        offset: _offset,
        child: widget.child,
      ),
    );
  }
}
