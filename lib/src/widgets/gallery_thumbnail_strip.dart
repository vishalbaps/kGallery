import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:extended_image/extended_image.dart';
import 'package:k_gallery/k_gallery.dart';
import '../bloc/gallery_bloc.dart';

/// Internal widget for displaying the scrollable thumbnail strip.
class GalleryThumbnailStrip extends StatefulWidget {
  /// Whether haptic feedback is enabled.
  final bool enableHapticFeedback;

  /// Controller for the main page view to sync scrolling.
  final ExtendedPageController pageController;

  /// Custom loading widget for thumbnails.
  final Widget? thumbProgressWidget;

  const GalleryThumbnailStrip({
    super.key,
    required this.enableHapticFeedback,
    required this.pageController,
    this.thumbProgressWidget,
  });

  @override
  State<GalleryThumbnailStrip> createState() => _GalleryThumbnailStripState();
}

class _GalleryThumbnailStripState extends State<GalleryThumbnailStrip> {
  final ScrollController _scrollController = ScrollController();
  int _lastHapticIndex = -1;
  bool _isUserDragging = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = context.read<GalleryBloc>().state;
        _scrollToThumbnail(state.currentIndex, animate: false);
      }
    });
  }

  _AdaptiveDimensions _getDimensions(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    if (isTablet) {
      return const _AdaptiveDimensions(
        height: 110,
        unselectedSize: 60,
        selectedSize: 86,
        spacing: 4,
      );
    }
    return const _AdaptiveDimensions(
      height: 90,
      unselectedSize: 48,
      selectedSize: 68,
      spacing: 6,
    );
  }

  void _scrollToThumbnail(int index, {bool animate = true}) {
    if (!_scrollController.hasClients || _isUserDragging) return;

    final dimensions = _getDimensions(context);
    final double itemFullWidth = dimensions.unselectedSize + dimensions.spacing;

    double position = index * itemFullWidth;

    position = position.clamp(0.0, _scrollController.position.maxScrollExtent);

    if ((_scrollController.offset - position).abs() < 1.0) return;

    if (animate) {
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GalleryBloc, GalleryState>(
      listenWhen: (previous, current) =>
          previous.currentIndex != current.currentIndex,
      listener: (context, state) {
        _scrollToThumbnail(state.currentIndex);
      },
      builder: (context, state) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dimensions = _getDimensions(context);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: (state.isUIVisible && !state.isSliding)
              ? 0
              : -(dimensions.height +
                  MediaQuery.of(context).padding.bottom +
                  20),
          left: 0,
          right: 0,
          height: dimensions.height + MediaQuery.of(context).padding.bottom,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification &&
                        notification.dragDetails != null) {
                      _isUserDragging = true;
                    } else if (notification is ScrollEndNotification) {
                      _isUserDragging = false;
                      _scrollToThumbnail(state.currentIndex, animate: true);
                    } else if (notification is ScrollUpdateNotification &&
                        _isUserDragging) {
                      final double itemFullWidth =
                          dimensions.unselectedSize + dimensions.spacing;

                      int centerIndex =
                          (notification.metrics.pixels / itemFullWidth).round();

                      if (centerIndex >= 0 &&
                          centerIndex < state.items.length) {
                        if (_lastHapticIndex != centerIndex) {
                          _lastHapticIndex = centerIndex;
                          if (widget.enableHapticFeedback) {
                            HapticFeedback.selectionClick();
                          }
                          widget.pageController.jumpToPage(centerIndex);
                          context.read<GalleryBloc>().add(
                                GalleryIndexChanged(centerIndex),
                              );
                        }
                      }
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: (screenWidth -
                              dimensions.unselectedSize -
                              dimensions.spacing) /
                          2,
                    ),
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == state.currentIndex;
                      return GestureDetector(
                        onTap: () {
                          if (widget.enableHapticFeedback) {
                            HapticFeedback.lightImpact();
                          }
                          widget.pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                          context.read<GalleryBloc>().add(
                                GalleryIndexChanged(index),
                              );
                        },
                        child: SizedBox(
                          width: dimensions.unselectedSize + dimensions.spacing,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              width: isSelected
                                  ? dimensions.selectedSize
                                  : dimensions.unselectedSize,
                              height: isSelected
                                  ? dimensions.selectedSize
                                  : dimensions.unselectedSize,
                              decoration: BoxDecoration(
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                borderRadius: BorderRadius.circular(
                                  dimensions.unselectedSize * 0.2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  dimensions.unselectedSize * 0.15,
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ExtendedImage.network(
                                      state.items[index].thumbnailUrl ??
                                          state.items[index].url,
                                      fit: BoxFit.cover,
                                      cache: true,
                                      loadStateChanged: (extendedImageState) {
                                        if (extendedImageState
                                                .extendedImageLoadState ==
                                            LoadState.loading) {
                                          return widget.thumbProgressWidget;
                                        }
                                        return null;
                                      },
                                    ),
                                    if (state.items[index].type !=
                                        GalleryItemType.image)
                                      Positioned(
                                        left: 4,
                                        bottom: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(1),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdaptiveDimensions {
  final double height;
  final double unselectedSize;
  final double selectedSize;
  final double spacing;

  const _AdaptiveDimensions({
    required this.height,
    required this.unselectedSize,
    required this.selectedSize,
    required this.spacing,
  });
}
