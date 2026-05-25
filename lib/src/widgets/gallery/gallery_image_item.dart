import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/gallery_item.dart';
import 'zoomable_image.dart';

/// Renders a single image gallery item using [CachedNetworkImage], optionally
/// wrapped in [ZoomableImage] for pinch + double-tap zoom.
///
/// This widget is purely visual — it does not handle page swiping or
/// dismiss gestures. Those are owned by parent widgets.
class GalleryImageItem extends StatelessWidget {
  final GalleryItem item;
  final ValueNotifier<double> scaleNotifier;
  final bool enableZoom;
  final Widget? progressWidget;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const GalleryImageItem({
    super.key,
    required this.item,
    required this.scaleNotifier,
    required this.enableZoom,
    this.progressWidget,
    this.onZoomIn,
    this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final Widget image = CachedNetworkImage(
      imageUrl: item.url,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, _) =>
          progressWidget ??
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorWidget: (context, _, __) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
      ),
    );

    if (!enableZoom) {
      return image;
    }

    return ZoomableImage(
      scaleNotifier: scaleNotifier,
      onZoomIn: onZoomIn,
      onZoomOut: onZoomOut,
      child: image,
    );
  }
}
