import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:extended_image/extended_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shimmer/shimmer.dart';
import 'bloc/gallery_bloc.dart';
import 'models/gallery_item.dart';
import 'models/gallery_theme.dart';
import 'widgets/gallery_image_viewer.dart';
import 'widgets/gallery_thumbnail_strip.dart';

/// A full-screen, Telegram-style media gallery viewer.
///
/// Supports images, videos, and audio with a thumbnail strip,
/// pinch-to-zoom, swipe-to-dismiss, and customizable controls.
///
/// ```dart
/// KGallery(
///   contentList: items,
///   initialIndex: 0,
///   onClose: (index) => Navigator.of(context).pop(index),
/// )
/// ```
class KGallery extends StatefulWidget {
  /// The list of media items to display in the gallery.
  final List<GalleryItem> contentList;

  /// The index of the initially displayed item.
  final int initialIndex;

  /// Custom widget shown while media items are loading.
  /// Defaults to a white [CircularProgressIndicator].
  final Widget? progressWidget;

  /// Custom widget shown while thumbnail images are loading.
  /// Defaults to a shimmer effect.
  final Widget? thumbProgressWidget;

  /// Whether pinch-to-zoom and double-tap zoom are enabled for images.
  /// Defaults to `true`.
  final bool enableZoom;

  /// Whether swiping down dismisses the gallery.
  /// Defaults to `true`.
  final bool enableSwipeToDismiss;

  /// Whether haptic feedback is triggered on thumbnail interactions.
  /// Defaults to `true`.
  final bool enableHapticFeedback;

  /// Custom leading widget for the top bar (e.g., a back button icon).
  /// Defaults to a white [Icons.arrow_back].
  final Widget? leading;

  /// Custom title displayed in the top bar.
  /// Defaults to `"currentIndex / totalCount"` format.
  final String? title;

  /// Custom message shown when no internet is detected for remote media.
  final String? noInternetMessage;

  /// Called when the currently displayed item changes.
  final void Function(int index)? onIndexChanged;

  /// Called when the gallery is closed (back button or swipe-to-dismiss).
  /// Receives the index of the last displayed item.
  ///
  /// If not provided, falls back to [Navigator.maybePop].
  final void Function(int currentIndex)? onClose;

  /// Custom theme for styling the gallery.
  /// Defaults to [GalleryTheme.dark].
  final GalleryTheme? theme;

  /// Builder for custom action widgets in the top bar.
  /// Receives the current context, index, and full items list.
  final Widget Function(
    BuildContext,
    int currentIndex,
    List<GalleryItem> items,
  )? actionMenuBuilder;

  /// Creates a [KGallery] widget.
  ///
  /// [contentList] must not be empty.
  /// [initialIndex] must be a valid index within [contentList].
  const KGallery({
    super.key,
    required this.contentList,
    required this.initialIndex,
    this.progressWidget,
    this.thumbProgressWidget,
    this.enableZoom = true,
    this.enableSwipeToDismiss = true,
    this.enableHapticFeedback = true,
    this.leading,
    this.title,
    this.noInternetMessage,
    this.onIndexChanged,
    this.onClose,
    this.theme,
    this.actionMenuBuilder,
  })  : assert(contentList.length > 0, 'contentList must not be empty'),
        assert(
          initialIndex >= 0 && initialIndex < contentList.length,
          'initialIndex must be within contentList bounds',
        );

  /// Initializes MediaKit for video/audio playback.
  ///
  /// Call this in your `main()` before `runApp()` if your gallery
  /// will display video or audio content:
  /// ```dart
  /// void main() {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   KGallery.ensureInitialized();
  ///   runApp(MyApp());
  /// }
  /// ```
  static void ensureInitialized() {
    MediaKit.ensureInitialized();
  }

  @override
  State<KGallery> createState() => _KGalleryState();
}

class _KGalleryState extends State<KGallery> with TickerProviderStateMixin {
  late ExtendedPageController _pageController;
  final GlobalKey<ExtendedImageSlidePageState> _slidePageKey =
      GlobalKey<ExtendedImageSlidePageState>();
  late GalleryBloc _galleryBloc;
  final GlobalKey _textContentKey = GlobalKey();
  final ValueNotifier<Player?> activePlayerNotifier = ValueNotifier(null);

  late final Widget _effectiveProgressWidget;
  late final Widget _effectiveThumbProgressWidget;
  late final GalleryTheme _effectiveTheme;

  // Animation for smooth text panel height transitions
  AnimationController? _heightAnimController;

  @override
  void initState() {
    super.initState();
    try {
      KGallery.ensureInitialized();
    } catch (e) {
      debugPrint(
          'KGallery: MediaKit initialization failed or already initialized: $e');
    }

    _effectiveProgressWidget = widget.progressWidget ??
        const Center(child: CircularProgressIndicator(color: Colors.white));

    _effectiveTheme = widget.theme ?? GalleryTheme.dark();

    _effectiveThumbProgressWidget = widget.thumbProgressWidget ??
        Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[600]!,
          child: Container(color: Colors.white),
        );

    _pageController = ExtendedPageController(initialPage: widget.initialIndex);
    _galleryBloc = GalleryBloc(
      initialItems: widget.contentList,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _heightAnimController?.dispose();
    _pageController.dispose();
    _galleryBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
        final double thumbnailStripHeight = isTablet ? 110 : 90;
        final double topBarHeight = isTablet ? 80 : 56;
        final double horizontalPadding = isTablet ? 32 : 16;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              widget.onClose?.call(_galleryBloc.state.currentIndex);
            }
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: BlocProvider.value(
              value: _galleryBloc,
              child: BlocListener<GalleryBloc, GalleryState>(
                listenWhen: (previous, current) =>
                    previous.currentIndex != current.currentIndex,
                listener: (context, state) {
                  widget.onIndexChanged?.call(state.currentIndex);
                },
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      GalleryImageViewer(
                        pageController: _pageController,
                        progressWidget: _effectiveProgressWidget,
                        enableZoom: widget.enableZoom,
                        enableSwipeToDismiss: widget.enableSwipeToDismiss,
                        slidePageKey: _slidePageKey,
                        activePlayerNotifier: activePlayerNotifier,
                        onClose: widget.onClose,
                        noInternetMessage: widget.noInternetMessage ??
                            _effectiveTheme.noInternetMessage,
                      ),

                      _GalleryTopBar(
                        topBarHeight: topBarHeight,
                        horizontalPadding: horizontalPadding,
                        leading: widget.leading,
                        title: widget.title,
                        actionMenuBuilder: widget.actionMenuBuilder,
                        onClose: widget.onClose,
                        theme: _effectiveTheme,
                      ),

                      _GalleryOverlayLayer(
                        constraints: constraints,
                        pageController: _pageController,
                        thumbnailStripHeight: thumbnailStripHeight,
                        topBarHeight: topBarHeight,
                        horizontalPadding: horizontalPadding,
                        textContentKey: _textContentKey,
                        activePlayerNotifier: activePlayerNotifier,
                        theme: _effectiveTheme,
                        animateHeightTo: _animateHeightTo,
                      ),

                      // Adaptive Thumbnail Strip (Persistent on bottom)
                      GalleryThumbnailStrip(
                        enableHapticFeedback: widget.enableHapticFeedback,
                        pageController: _pageController,
                        thumbProgressWidget: _effectiveThumbProgressWidget,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _animateHeightTo(double start, double target) {
    _heightAnimController?.dispose();
    _heightAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    final animation = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(
        parent: _heightAnimController!,
        curve: Curves.easeOutQuad,
      ),
    );

    animation.addListener(() {
      if (mounted) {
        _galleryBloc.add(GalleryTextPanelHeightChanged(animation.value));
      }
    });

    _heightAnimController!.forward();
  }
}

class _GalleryTopBar extends StatelessWidget {
  final double topBarHeight;
  final double horizontalPadding;
  final Widget? leading;
  final String? title;
  final Widget Function(BuildContext, int, List<GalleryItem>)?
      actionMenuBuilder;
  final void Function(int)? onClose;
  final GalleryTheme theme;

  const _GalleryTopBar({
    required this.topBarHeight,
    required this.horizontalPadding,
    this.leading,
    this.title,
    this.actionMenuBuilder,
    this.onClose,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return BlocBuilder<GalleryBloc, GalleryState>(
      builder: (context, state) {
        final Widget leadingWidget = IconButton(
          icon: leading ?? const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).maybePop(state.currentIndex);
          },
        );

        final Widget titleWidget = Text(
          title ?? '${state.currentIndex + 1} / ${state.items.length}',
          textAlign: TextAlign.center,
          style: theme.counterTextStyle ??
              TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 20 : 16,
                fontWeight: FontWeight.w600,
              ),
        );

        final Widget? customActions = actionMenuBuilder?.call(
          context,
          state.currentIndex,
          state.items,
        );

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top:
              (state.isUIVisible && !state.isSliding) ? 0 : -topBarHeight - 100,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: topBarHeight + MediaQuery.of(context).padding.top,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: horizontalPadding,
                  right: horizontalPadding,
                ),
                decoration: BoxDecoration(color: theme.appBarColor),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    leadingWidget,
                    Expanded(child: Center(child: titleWidget)),
                    if (customActions != null)
                      customActions
                    else
                      SizedBox(width: isTablet ? 64 : 48),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GalleryOverlayLayer extends StatelessWidget {
  final BoxConstraints constraints;
  final ExtendedPageController pageController;
  final double thumbnailStripHeight;
  final double topBarHeight;
  final double horizontalPadding;
  final GlobalKey textContentKey;
  final ValueNotifier<Player?> activePlayerNotifier;
  final GalleryTheme theme;
  final void Function(double, double) animateHeightTo;

  const _GalleryOverlayLayer({
    required this.constraints,
    required this.pageController,
    required this.thumbnailStripHeight,
    required this.topBarHeight,
    required this.horizontalPadding,
    required this.textContentKey,
    required this.activePlayerNotifier,
    required this.theme,
    required this.animateHeightTo,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GalleryBloc, GalleryState>(
      builder: (context, state) {
        final currentItem =
            state.items.isNotEmpty ? state.items[state.currentIndex] : null;
        if (currentItem == null) return const SizedBox.shrink();

        final bool hasSeekbar = currentItem.type == GalleryItemType.video ||
            currentItem.type == GalleryItemType.audio;
        final bool hasText =
            currentItem.title != null || currentItem.description != null;

        if (!hasSeekbar && !hasText) return const SizedBox.shrink();

        final double textPanelHeight = state.textPanelHeight;
        const double seekbarHeight = 40.0;

        final double textBottomOffset = (state.isUIVisible && !state.isSliding)
            ? MediaQuery.of(context).padding.bottom +
                thumbnailStripHeight +
                (hasSeekbar ? seekbarHeight : 0.0)
            : -500;

        final double seekbarBottomOffset =
            (state.isUIVisible && !state.isSliding)
                ? MediaQuery.of(context).padding.bottom + thumbnailStripHeight
                : -500;

        return Stack(
          children: [
            if (hasSeekbar)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                bottom: seekbarBottomOffset,
                left: 0,
                right: 0,
                height: seekbarHeight,
                child: ValueListenableBuilder<Player?>(
                  valueListenable: activePlayerNotifier,
                  builder: (context, player, child) {
                    if (player == null) return const SizedBox.shrink();
                    return _GallerySeekBar(player: player, theme: theme);
                  },
                ),
              ),
            if (hasText)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                bottom: textBottomOffset,
                left: 0,
                right: 0,
                child: _GalleryTextPanel(
                  item: currentItem,
                  textPanelHeight: textPanelHeight,
                  horizontalPadding: horizontalPadding,
                  constraints: constraints,
                  topBarHeight: topBarHeight,
                  thumbnailStripHeight: thumbnailStripHeight,
                  textContentKey: textContentKey,
                  theme: theme,
                  animateHeightTo: animateHeightTo,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GalleryTextPanel extends StatelessWidget {
  final GalleryItem item;
  final double textPanelHeight;
  final double horizontalPadding;
  final BoxConstraints constraints;
  final double topBarHeight;
  final double thumbnailStripHeight;
  final GlobalKey textContentKey;
  final GalleryTheme theme;
  final void Function(double, double) animateHeightTo;

  const _GalleryTextPanel({
    required this.item,
    required this.textPanelHeight,
    required this.horizontalPadding,
    required this.constraints,
    required this.topBarHeight,
    required this.thumbnailStripHeight,
    required this.textContentKey,
    required this.theme,
    required this.animateHeightTo,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        double newHeight = textPanelHeight - (details.primaryDelta ?? 0);
        final double maxAvailableHeight = constraints.maxHeight -
            MediaQuery.of(context).padding.top -
            topBarHeight -
            MediaQuery.of(context).padding.bottom -
            thumbnailStripHeight;

        double contentHeight = maxAvailableHeight;
        final renderBox =
            textContentKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          contentHeight = renderBox.size.height + 10;
        }

        final double clampedMax = contentHeight.clamp(
          GalleryState.minTextPanelHeight,
          maxAvailableHeight,
        );
        newHeight = newHeight.clamp(
          GalleryState.minTextPanelHeight,
          clampedMax,
        );
        context.read<GalleryBloc>().add(
              GalleryTextPanelHeightChanged(newHeight),
            );
      },
      onVerticalDragEnd: (details) {
        final double velocity = details.primaryVelocity ?? 0;
        final double maxAvailableHeight = constraints.maxHeight -
            MediaQuery.of(context).padding.top -
            topBarHeight -
            MediaQuery.of(context).padding.bottom -
            thumbnailStripHeight;

        double contentHeight = maxAvailableHeight;
        final renderBox =
            textContentKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          contentHeight = renderBox.size.height + 10;
        }
        final double clampedMax = contentHeight.clamp(
          GalleryState.minTextPanelHeight,
          maxAvailableHeight,
        );

        double target;
        if (velocity > 300) {
          target = GalleryState.minTextPanelHeight;
        } else if (velocity < -300) {
          target = clampedMax;
        } else if (textPanelHeight < GalleryState.minTextPanelHeight + 40) {
          target = GalleryState.minTextPanelHeight;
        } else {
          return;
        }
        animateHeightTo(textPanelHeight, target);
      },
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            height: textPanelHeight,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent
                ],
                stops: const [0.0, 1.0],
              ),
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: KeyedSubtree(
                key: textContentKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.title != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          item.title!,
                          style: theme.titleTextStyle ??
                              TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 20 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    if (item.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          item.description!,
                          style: theme.descriptionTextStyle ??
                              TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 16 : 14,
                              ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GallerySeekBar extends StatelessWidget {
  final Player player;
  final GalleryTheme theme;

  const _GallerySeekBar({required this.player, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(player),
      color: Colors.black.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          StreamBuilder<Duration>(
            initialData: player.state.position,
            stream: player.stream.position,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              return Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<Duration>(
              initialData: player.state.position,
              stream: player.stream.position,
              builder: (context, posSnapshot) {
                return StreamBuilder<Duration>(
                  initialData: player.state.duration,
                  stream: player.stream.duration,
                  builder: (context, durSnapshot) {
                    final position = posSnapshot.data ?? Duration.zero;
                    final duration = durSnapshot.data ?? Duration.zero;

                    double max = duration.inMilliseconds.toDouble();
                    double val = position.inMilliseconds.toDouble();
                    if (max <= 0) max = 1.0;
                    if (val < 0) val = 0.0;
                    if (val > max) val = max;

                    return Slider(
                      value: val,
                      max: max,
                      activeColor: theme.seekbarActiveColor,
                      inactiveColor: theme.seekbarInactiveColor,
                      onChanged: (value) {
                        player.seek(Duration(milliseconds: value.toInt()));
                      },
                    );
                  },
                );
              },
            ),
          ),
          StreamBuilder<Duration>(
            initialData: player.state.duration,
            stream: player.stream.duration,
            builder: (context, snapshot) {
              final duration = snapshot.data ?? Duration.zero;
              return Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
