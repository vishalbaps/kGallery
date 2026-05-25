import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A [PageView] whose horizontal swipe is disabled while a child reports
/// itself as zoomed (scale > 1.0 on the supplied [currentItemScale]
/// listenable).
class ZoomAwarePageView extends StatelessWidget {
  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueListenable<double> currentItemScale;
  final ValueChanged<int>? onPageChanged;

  const ZoomAwarePageView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    required this.currentItemScale,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: currentItemScale,
      builder: (context, scale, _) {
        final isZoomed = scale > 1.01;
        return PageView.builder(
          controller: controller,
          itemCount: itemCount,
          onPageChanged: onPageChanged,
          physics: isZoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
