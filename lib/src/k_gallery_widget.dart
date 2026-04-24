import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:extended_image/extended_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'bloc/gallery_bloc.dart';
import 'models/gallery_item.dart';
import 'widgets/gallery_image_viewer.dart';
import 'widgets/gallery_thumbnail_strip.dart';

class KGallery extends StatefulWidget {
  final List<GalleryItem> contentList;
  final int initialIndex;
  final Widget? progressWidget;
  final Widget? thumbProgressWidget;
  final bool isZoomEnable;
  final bool isSwipeToDismiss;
  final bool isHapticEnable;
  final Widget? leading;
  final String? title;
  final void Function(int index)? onIndexChanged;
  final Widget Function(
    BuildContext,
    int currentIndex,
    List<GalleryItem> items,
  )?
  actionMenuBuilder;

  const KGallery({
    super.key,
    required this.contentList,
    required this.initialIndex,
    this.progressWidget,
    this.thumbProgressWidget,
    this.isZoomEnable = true,
    this.isSwipeToDismiss = true,
    this.isHapticEnable = true,
    this.leading,
    this.title,
    this.onIndexChanged,
    this.actionMenuBuilder,
  });

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

  // Animation for smooth text panel height transitions
  AnimationController? _heightAnimController;

  @override
  void initState() {
    super.initState();
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      debugPrint('MediaKit initialization failed or already initialized: $e');
    }

    _effectiveProgressWidget =
        widget.progressWidget ??
        const Center(child: CircularProgressIndicator(color: Colors.white));

    _effectiveThumbProgressWidget =
        widget.thumbProgressWidget ??
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

        return AnnotatedRegion<SystemUiOverlayStyle>(
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
                      isZoomEnable: widget.isZoomEnable,
                      isSwipeToDismiss: widget.isSwipeToDismiss,
                      slidePageKey: _slidePageKey,
                      activePlayerNotifier: activePlayerNotifier,
                    ),

                    BlocBuilder<GalleryBloc, GalleryState>(
                      builder: (context, state) {
                        final Widget leadingWidget = IconButton(
                          icon:
                              widget.leading ??
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop(state.currentIndex);
                            }
                          },
                        );

                        final Widget titleWidget = Text(
                          widget.title ??
                              '${state.currentIndex + 1} / ${state.items.length}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 20 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        );

                        final Widget? customActions = widget.actionMenuBuilder
                            ?.call(context, state.currentIndex, state.items);

                        return AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          top: (state.isUIVisible && !state.isSliding)
                              ? 0
                              : -topBarHeight - 100,
                          left: 0,
                          right: 0,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                height:
                                    topBarHeight +
                                    MediaQuery.of(context).padding.top,
                                padding: EdgeInsets.only(
                                  top: MediaQuery.of(context).padding.top,
                                  left: horizontalPadding,
                                  right: horizontalPadding,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                    ),

                    BlocBuilder<GalleryBloc, GalleryState>(
                      builder: (context, state) {
                        final currentItem = state.items.isNotEmpty
                            ? state.items[state.currentIndex]
                            : null;
                        if (currentItem == null ||
                            (currentItem.title == null &&
                                currentItem.description == null)) {
                          return const SizedBox.shrink();
                        }

                        final double textPanelHeight = state.textPanelHeight;

                        final bool hasSeekbar =
                            currentItem.type == GalleryItemType.video ||
                            currentItem.type == GalleryItemType.audio;
                        final double seekbarHeight = 40.0;

                        final double textBottomOffset =
                            (state.isUIVisible && !state.isSliding)
                            ? MediaQuery.of(context).padding.bottom +
                                  thumbnailStripHeight +
                                  (hasSeekbar ? seekbarHeight : 0.0)
                            : -500;

                        final double seekbarBottomOffset =
                            (state.isUIVisible && !state.isSliding)
                            ? MediaQuery.of(context).padding.bottom +
                                  thumbnailStripHeight
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
                                    if (player == null)
                                      return const SizedBox.shrink();
                                    return _buildSeekbar(player);
                                  },
                                ),
                              ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              bottom: textBottomOffset,
                              left: 0,
                              right: 0,
                              child: GestureDetector(
                                onVerticalDragUpdate: (details) {
                                  double newHeight =
                                      textPanelHeight -
                                      (details.primaryDelta ?? 0);

                                  final double maxAvailableHeight =
                                      constraints.maxHeight -
                                      MediaQuery.of(context).padding.top -
                                      topBarHeight -
                                      MediaQuery.of(context).padding.bottom -
                                      thumbnailStripHeight;

                                  double contentHeight = maxAvailableHeight;
                                  final renderBox =
                                      _textContentKey.currentContext
                                              ?.findRenderObject()
                                          as RenderBox?;
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
                                  final double velocity =
                                      details.primaryVelocity ?? 0;
                                  final double maxAvailableHeight =
                                      constraints.maxHeight -
                                      MediaQuery.of(context).padding.top -
                                      topBarHeight -
                                      MediaQuery.of(context).padding.bottom -
                                      thumbnailStripHeight;

                                  double contentHeight = maxAvailableHeight;
                                  final renderBox =
                                      _textContentKey.currentContext
                                              ?.findRenderObject()
                                          as RenderBox?;
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
                                  } else if (textPanelHeight <
                                      GalleryState.minTextPanelHeight + 40) {
                                    target = GalleryState.minTextPanelHeight;
                                  } else {
                                    return;
                                  }
                                  _animateHeightTo(textPanelHeight, target);
                                },
                                child: Stack(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 50,
                                      ),
                                      height: textPanelHeight,
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: horizontalPadding,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.8),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 1.0],
                                        ),
                                      ),
                                      child: SingleChildScrollView(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        child: KeyedSubtree(
                                          key: _textContentKey,
                                          child: _buildTextContent(
                                            currentItem,
                                            isTablet: isTablet,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Subtle gradient at the bottom for better text cut-off
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
                                              Colors.black.withValues(
                                                alpha: 0.7,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // Adaptive Thumbnail Strip (Persistent on bottom)
                    GalleryThumbnailStrip(
                      isHapticEnable: widget.isHapticEnable,
                      pageController: _pageController,
                      thumbProgressWidget: _effectiveThumbProgressWidget,
                    ),
                  ],
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

  Widget _buildSeekbar(Player player) {
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
                      activeColor: Colors.white,
                      inactiveColor: Colors.white30,
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

  Widget _buildTextContent(
    GalleryItem item, {
    int? maxLines,
    bool isTablet = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.title != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              item.title!,
              maxLines: maxLines != null ? 1 : null,
              overflow: maxLines != null ? TextOverflow.ellipsis : null,
              style: TextStyle(
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
              maxLines: maxLines,
              overflow: maxLines != null ? TextOverflow.ellipsis : null,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 16 : 14,
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
