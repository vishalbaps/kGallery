import 'package:flutter/material.dart';

/// Defines the visual appearance of the [KGallery] widget.
///
/// Use this class to customize colors, text styles, and layout dimensions
/// to match your app's design system.
class GalleryTheme {
  /// The background color of the gallery viewer.
  /// Defaults to [Colors.black].
  final Color backgroundColor;

  /// The background color of the top bar (and the thumbnail strip, unless
  /// [thumbnailStripColor] is set).
  /// Defaults to black with 50% opacity.
  final Color appBarColor;

  /// The background color of the bottom thumbnail strip.
  ///
  /// When `null`, the strip falls back to [appBarColor]. Set this to give the
  /// thumbnail strip a different background from the top bar.
  final Color thumbnailStripColor;

  /// The bottom (opaque) color of the title/description panel's background
  /// gradient — the end that sits behind the text, above the thumbnail strip.
  ///
  /// When `null`, falls back to [thumbnailStripColor] so the panel blends into
  /// the strip below it.
  final Color? textPanelGradientStartColor;

  /// The top color of the title/description panel's background gradient — the
  /// end that fades out over the media.
  ///
  /// When `null`, defaults to [Colors.transparent].
  final Color? textPanelGradientEndColor;

  /// The color of the active seekbar.
  /// Defaults to [Colors.white].
  final Color seekbarActiveColor;

  /// The color of the inactive seekbar.
  /// Defaults to [Colors.white30].
  final Color seekbarInactiveColor;

  /// The text style for titles in the description panel.
  final TextStyle? titleTextStyle;

  /// The text style for descriptions in the description panel.
  final TextStyle? descriptionTextStyle;

  /// The text style for the counter (e.g., "1 / 5") in the top bar.
  final TextStyle? counterTextStyle;

  /// The height of the thumbnail strip on mobile devices.
  /// Defaults to 90.
  final double mobileThumbnailHeight;

  /// The height of the thumbnail strip on tablet devices.
  /// Defaults to 110.
  final double tabletThumbnailHeight;

  /// Creates a [GalleryTheme].
  const GalleryTheme({
    this.backgroundColor = Colors.black,
    this.appBarColor = const Color(0x80000000),
    this.thumbnailStripColor = const Color(0xA6000000),
    this.textPanelGradientStartColor,
    this.textPanelGradientEndColor,
    this.seekbarActiveColor = Colors.white,
    this.seekbarInactiveColor = Colors.white30,
    this.titleTextStyle,
    this.descriptionTextStyle,
    this.counterTextStyle,
    this.mobileThumbnailHeight = 90,
    this.tabletThumbnailHeight = 110,
  });

  /// The resolved `[start, end]` colors for the text panel's background
  /// gradient, applying the fallbacks documented on
  /// [textPanelGradientStartColor] and [textPanelGradientEndColor].
  List<Color> get textPanelGradientColors => [
        textPanelGradientStartColor ?? thumbnailStripColor,
        textPanelGradientEndColor ?? Colors.transparent,
      ];

  /// Default dark theme for the gallery.
  factory GalleryTheme.dark() => const GalleryTheme();
}
