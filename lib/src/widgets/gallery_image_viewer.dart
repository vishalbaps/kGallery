import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:extended_image/extended_image.dart';
import 'package:media_kit/media_kit.dart';
import '../bloc/gallery_bloc.dart';
import '../models/gallery_item.dart';
import 'gallery_media_item_widget.dart';

/// Internal widget for displaying the main media content with gestures.
  /// Callback for when the viewer is closed.
  final void Function(int currentIndex)? onClose;

  /// Custom message shown when no internet is detected for remote media.
  final String? noInternetMessage;

  const GalleryImageViewer({
    super.key,
    required this.pageController,
    this.progressWidget,
    required this.enableZoom,
    required this.enableSwipeToDismiss,
    required this.slidePageKey,
    required this.activePlayerNotifier,
    this.onClose,
    this.noInternetMessage,
  });

  @override
  State<GalleryImageViewer> createState() => _GalleryImageViewerState();
}

class _GalleryImageViewerState extends State<GalleryImageViewer>
    with TickerProviderStateMixin {
  late AnimationController _doubleTapAnimationController;
  Animation<double>? _doubleTapAnimation;
  VoidCallback? _doubleTapAnimationListener;
  Timer? _singleTapTimer;

  int _pointersCount = 0;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  DateTime _dragStartTime = DateTime.now();
  DateTime? _lastTapEndTime;
  bool _isPinching = false;

  /// Track gesture states for each page to handle zoom levels accurately across the gallery.
  final Map<int, GlobalKey<ExtendedImageGestureState>> _gestureKeys = {};

  @override
  void initState() {
    super.initState();
    _doubleTapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _doubleTapAnimationController.dispose();
    _singleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GalleryBloc, GalleryState>(
      builder: (context, state) {
        return Listener(
          onPointerDown: (event) {
            _pointersCount++;
            if (_pointersCount > 1) {
              _isPinching = true;
              if (context.read<GalleryBloc>().state.isUIVisible) {
                context.read<GalleryBloc>().add(
                  GalleryToggleUI(isVisible: false),
                );
              }
            } else if (_pointersCount == 1) {
              _singleTapTimer?.cancel();
              _dragStartX = event.position.dx;
              _dragStartY = event.position.dy;
              _dragStartTime = DateTime.now();
            }
          },
          onPointerUp: (event) {
            _pointersCount--;
            if (_pointersCount == 0) {
              if (_isPinching) {
                _isPinching = false;
                // Re-evaluate UI visibility after a pinch gesture ends.
                final bloc = context.read<GalleryBloc>();
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) {
                    final currentIndex = bloc.state.currentIndex;
                    final gestureState =
                        _gestureKeys[currentIndex]?.currentState;
                    final scale =
                        gestureState?.gestureDetails?.totalScale ?? 1.0;
                    if (scale <= 1.0) {
                      bloc.add(
                        GalleryToggleUI(isVisible: true),
                      );
                    }
                  }
                });
                return;
              }

              final now = DateTime.now();
              final dx = (event.position.dx - _dragStartX).abs();
              final dyVertical = event.position.dy - _dragStartY;
              final dyAbs = dyVertical.abs();
              final time = now.difference(_dragStartTime).inMilliseconds;

              if (widget.slidePageKey.currentState?.isSliding ?? false) return;

              // Detect if this is a second tap for double-tap zoom handling.
              bool isSecondTap =
                  _lastTapEndTime != null &&
                  now.difference(_lastTapEndTime!).inMilliseconds < 300;
              _lastTapEndTime = now;

              // --- Handle UI Toggling ---
              if (dx < 10 && dyAbs < 10 && time < 300) {
                if (isSecondTap) {
                  _singleTapTimer?.cancel();
                } else {
                  final currentItem = state.items.isNotEmpty
                      ? state.items[state.currentIndex]
                      : null;
                  if (currentItem?.type == GalleryItemType.image) {
                    _singleTapTimer = Timer(
                      const Duration(milliseconds: 250),
                      () {
                        if (mounted) {
                          context.read<GalleryBloc>().add(GalleryToggleUI());
                        }
                      },
                    );
                  }
                }
                return;
              }

              if (widget.enableSwipeToDismiss &&
                  dyVertical > 150 &&
                  time < 400 &&
                  dyAbs > dx * 3.0 &&
                  dx < 50) {
                if (mounted) {
                  final currentIndex = context
                      .read<GalleryBloc>()
                      .state
                      .currentIndex;
                  if (widget.onClose != null) {
                    widget.onClose!(currentIndex);
                  } else {
                    Navigator.of(context).maybePop(currentIndex);
                  }
                }
              }
            }
          },
          onPointerCancel: (event) => _pointersCount--,
          child: ExtendedImageSlidePage(
            key: widget.slidePageKey,
            slideAxis: SlideAxis.both,
            onSlidingPage: (state) {
              final isSliding = state.isSliding;
              if (context.read<GalleryBloc>().state.isSliding != isSliding) {
                context.read<GalleryBloc>().add(GallerySetSliding(isSliding));
              }
            },
            slidePageBackgroundHandler: (Offset offset, Size pageSize) {
              double opacity = 0.0;
              if (pageSize.height > 0) {
                opacity =
                    1.0 - (offset.dy.abs() / pageSize.height).clamp(0.0, 1.0);
              }
              return Colors.black.withValues(alpha: opacity);
            },
            child: ExtendedImageGesturePageView.builder(
              itemCount: state.items.length,
              controller: widget.pageController,
              onPageChanged: (int index) {
                context.read<GalleryBloc>().add(GalleryIndexChanged(index));
              },
              itemBuilder: (BuildContext context, int index) {
                final item = state.items[index];

                if (item.type == GalleryItemType.video ||
                    item.type == GalleryItemType.audio) {
                  return GalleryMediaItemWidget(
                    item: item,
                    index: index,
                    activePlayerNotifier: widget.activePlayerNotifier,
                    isAudio: item.type == GalleryItemType.audio,
                    noInternetMessage: widget.noInternetMessage,
                  );
                }

                final gestureKey = _gestureKeys.putIfAbsent(
                  index,
                  () => GlobalKey<ExtendedImageGestureState>(),
                );

                return ExtendedImage.network(
                  item.url,
                  extendedImageGestureKey: gestureKey,
                  fit: BoxFit.contain,
                  mode: widget.enableZoom
                      ? ExtendedImageMode.gesture
                      : ExtendedImageMode.none,
                  enableSlideOutPage: widget.enableSwipeToDismiss,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.loading) {
                      return widget.progressWidget ??
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                    }
                    return null;
                  },
                  initGestureConfigHandler: (state) {
                    return GestureConfig(
                      minScale: 0.9,
                      animationMinScale: 0.7,
                      maxScale: 3.0,
                      animationMaxScale: 3.5,
                      speed: 1.0,
                      inertialSpeed: 100.0,
                      initialScale: 1.0,
                      inPageView: true,
                    );
                  },
                  onDoubleTap: (ExtendedImageGestureState state) {
                    if (!widget.enableZoom) return;

                    var pointerDownPosition = state.pointerDownPosition;
                    var begin = state.gestureDetails?.totalScale ?? 1.0;
                    double end = (begin == 1.0) ? 2.5 : 1.0;

                    _doubleTapAnimation?.removeListener(
                      _doubleTapAnimationListener!,
                    );
                    _doubleTapAnimationController.stop();
                    _doubleTapAnimationController.reset();

                    _doubleTapAnimationListener = () {
                      state.handleDoubleTap(
                        scale: _doubleTapAnimation!.value,
                        doubleTapPosition: pointerDownPosition,
                      );
                    };

                    _doubleTapAnimation = _doubleTapAnimationController.drive(
                      Tween<double>(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
                    );

                    _doubleTapAnimation!.addListener(
                      _doubleTapAnimationListener!,
                    );
                    _doubleTapAnimationController.forward();

                    if (end == 1.0) {
                      context.read<GalleryBloc>().add(
                        GalleryToggleUI(isVisible: true),
                      );
                    } else {
                      context.read<GalleryBloc>().add(
                        GalleryToggleUI(isVisible: false),
                      );
                    }
                  },
                  heroBuilderForSlidingPage: (Widget result) {
                    return Hero(tag: item.url, child: result);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
