import 'package:flutter/material.dart';

import '../../models/gallery_item.dart';
import '../../models/gallery_theme.dart';
import '../../utils/connectivity_service.dart';

/// Signature for a host-supplied placeholder shown when a remote gallery item
/// cannot be loaded (offline or load failure).
///
/// Provide one via `KGallery.offlineBuilder` to fully replace kGallery's
/// default UI ([GalleryOfflineView]).
typedef GalleryOfflineBuilder = Widget Function(
  BuildContext context,
  GalleryItem item,
);

/// Default, purely-presentational placeholder: an icon, a title, and a
/// subtitle. No retry button — the item reloads on its own when the user
/// slides back to it.
///
/// Colors are derived from [brightness] (the brightness of the surface it is
/// drawn on) so it stays legible on both dark and light gallery backgrounds.
class GalleryOfflineView extends StatelessWidget {
  /// Headline (e.g. "You're offline").
  final String title;

  /// Supporting line (e.g. "Couldn't load this video").
  final String subtitle;

  /// Leading icon.
  final IconData icon;

  /// Brightness of the background this view is painted on. Drives the text /
  /// icon colors so the default UI supports both dark and light modes.
  final Brightness brightness;

  const GalleryOfflineView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.brightness,
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final bool onDark = brightness == Brightness.dark;
    final Color foreground = onDark ? Colors.white : const Color(0xE6000000);
    final Color muted = onDark ? Colors.white70 : Colors.black54;
    final Color iconColor = onDark ? Colors.white70 : Colors.black45;
    final Color iconBg =
        onDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 14, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Smart wrapper used at every load-failure site in the viewer.
///
/// - If the host supplied [offlineBuilder], it is used verbatim.
/// - Otherwise a [GalleryOfflineView] is rendered, and connectivity is checked
///   once to distinguish "You're offline" from a genuine load failure while
///   online ("offline ≠ broken").
class GalleryLoadErrorView extends StatefulWidget {
  final GalleryItem item;
  final GalleryTheme? theme;
  final GalleryOfflineBuilder? offlineBuilder;

  const GalleryLoadErrorView({
    super.key,
    required this.item,
    this.theme,
    this.offlineBuilder,
  });

  @override
  State<GalleryLoadErrorView> createState() => _GalleryLoadErrorViewState();
}

class _GalleryLoadErrorViewState extends State<GalleryLoadErrorView> {
  // Default to offline: the load already failed, and re-checking resolves the
  // exact wording a moment later. Avoids a "broken" flash before the check.
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final online = await ConnectivityService.instance.isConnected();
    if (!mounted || online == _online) return;
    setState(() => _online = online);
  }

  String get _typeLabel {
    switch (widget.item.type) {
      case GalleryItemType.image:
        return 'image';
      case GalleryItemType.audio:
        return 'audio';
      case GalleryItemType.video:
      case GalleryItemType.youtube:
        return 'video';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offlineBuilder != null) {
      return widget.offlineBuilder!(context, widget.item);
    }

    final brightness = ThemeData.estimateBrightnessForColor(
      widget.theme?.backgroundColor ?? Colors.black,
    );

    final String title = _online
        ? "Couldn't load this $_typeLabel"
        : (widget.theme?.offlineTitle ?? "You're offline");
    final String subtitle = _online
        ? 'The $_typeLabel is unavailable right now.'
        : "Couldn't load this $_typeLabel";

    return GalleryOfflineView(
      title: title,
      subtitle: subtitle,
      brightness: brightness,
      icon: _online ? Icons.broken_image_rounded : Icons.wifi_off_rounded,
    );
  }
}
