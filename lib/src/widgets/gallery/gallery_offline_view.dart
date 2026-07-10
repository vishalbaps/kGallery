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

/// Stateless wrapper used at every load-failure site in the viewer.
///
/// - If the host supplied [offlineBuilder], it is used verbatim.
/// - Otherwise a [GalleryOfflineView] is rendered. The "offline vs. broken"
///   wording is decided by [knownOffline] when the caller already knows the
///   cause (media items, whose offline state lives in [GalleryBloc]), or by a
///   one-shot connectivity probe via [FutureBuilder] otherwise (images, whose
///   failure is surfaced by `CachedNetworkImage`). No local mutable state.
class GalleryLoadErrorView extends StatelessWidget {
  final GalleryItem item;
  final GalleryTheme? theme;
  final GalleryOfflineBuilder? offlineBuilder;

  /// When non-null, skips the connectivity probe: `true` → offline wording,
  /// `false` → generic failure wording.
  final bool? knownOffline;

  const GalleryLoadErrorView({
    super.key,
    required this.item,
    this.theme,
    this.offlineBuilder,
    this.knownOffline,
  });

  String get _typeLabel {
    switch (item.type) {
      case GalleryItemType.image:
        return 'image';
      case GalleryItemType.audio:
        return 'audio';
      case GalleryItemType.video:
      case GalleryItemType.youtube:
        return 'video';
    }
  }

  Widget _view({required bool offline}) {
    final brightness = ThemeData.estimateBrightnessForColor(
      theme?.backgroundColor ?? Colors.black,
    );

    final String title = offline
        ? (theme?.offlineTitle ?? "You're offline")
        : "Couldn't load this $_typeLabel";
    final String subtitle = offline
        ? "Couldn't load this $_typeLabel"
        : 'The $_typeLabel is unavailable right now.';

    return GalleryOfflineView(
      title: title,
      subtitle: subtitle,
      brightness: brightness,
      icon: offline ? Icons.wifi_off_rounded : Icons.broken_image_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (offlineBuilder != null) {
      return offlineBuilder!(context, item);
    }
    if (knownOffline != null) {
      return _view(offline: knownOffline!);
    }
    // Image path: probe connectivity once to pick the wording. While the probe
    // is in flight, assume offline (the common cause) to avoid a "broken" flash.
    return FutureBuilder<bool>(
      future: ConnectivityService.instance.isConnected(),
      builder: (context, snapshot) {
        final bool online = snapshot.connectionState == ConnectionState.done &&
            (snapshot.data ?? false);
        return _view(offline: !online);
      },
    );
  }
}
