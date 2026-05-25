import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../bloc/gallery_bloc.dart';
import '../models/gallery_item.dart';
import '../models/gallery_theme.dart';
import 'gallery/dismissible_drag_area.dart';
import 'gallery/gallery_image_item.dart';
import 'gallery/zoom_aware_page_view.dart';
import 'media/gallery_audio_item.dart';
import 'media/gallery_video_item.dart';
import 'media/gallery_youtube_item.dart';

/// Thin orchestrator that hosts the swipable gallery page view.
///
/// Owns:
///   - The current item's zoom scale (so it can disable page swipe + drag dismiss).
///   - The background fade opacity during drag-to-dismiss.
///
/// Delegates rendering to type-specific widgets (image / video / audio /
/// youtube) and reusable building blocks ([GalleryImageItem],
/// [DismissibleDragArea], [ZoomAwarePageView]).
class GalleryImageViewer extends StatefulWidget {
  final PageController pageController;
  final Widget? progressWidget;
  final bool enableZoom;
  final bool enableSwipeToDismiss;
  final ValueNotifier<Player?> activePlayerNotifier;
  final ValueNotifier<YoutubePlayerController?> activeYoutubeNotifier;
  final void Function(int currentIndex)? onClose;
  final String? noInternetMessage;
  final GalleryTheme? theme;

  const GalleryImageViewer({
    super.key,
    required this.pageController,
    this.progressWidget,
    required this.enableZoom,
    required this.enableSwipeToDismiss,
    required this.activePlayerNotifier,
    required this.activeYoutubeNotifier,
    this.onClose,
    this.noInternetMessage,
    this.theme,
  });

  @override
  State<GalleryImageViewer> createState() => _GalleryImageViewerState();
}

class _GalleryImageViewerState extends State<GalleryImageViewer> {
  /// Scale of the currently visible item (1.0 = not zoomed).
  final ValueNotifier<double> _currentScale = ValueNotifier<double>(1.0);

  /// Background opacity for drag-to-dismiss visual feedback (1.0 = solid black).
  final ValueNotifier<double> _bgOpacity = ValueNotifier<double>(1.0);

  void _resetScale() {
    _currentScale.value = 1.0;
  }

  void _handleDismiss(BuildContext context) {
    final currentIndex = context.read<GalleryBloc>().state.currentIndex;
    if (widget.onClose != null) {
      widget.onClose!(currentIndex);
    } else {
      Navigator.of(context).maybePop(currentIndex);
    }
  }

  void _handleDragProgress(BuildContext context, double progress) {
    _bgOpacity.value = (1.0 - progress).clamp(0.0, 1.0);
    final bloc = context.read<GalleryBloc>();
    final shouldBeSliding = progress > 0.01;
    if (bloc.state.isSliding != shouldBeSliding) {
      bloc.add(GallerySetSliding(shouldBeSliding));
    }
  }

  void _handleDragEnded(BuildContext context) {
    _bgOpacity.value = 1.0;
    final bloc = context.read<GalleryBloc>();
    if (bloc.state.isSliding) {
      bloc.add(GallerySetSliding(false));
    }
  }

  void _toggleUI(BuildContext context) {
    context.read<GalleryBloc>().add(GalleryToggleUI());
  }

  void _setUIVisible(BuildContext context, bool visible) {
    final bloc = context.read<GalleryBloc>();
    if (bloc.state.isUIVisible != visible) {
      bloc.add(GalleryToggleUI(isVisible: visible));
    }
  }

  @override
  void dispose() {
    _currentScale.dispose();
    _bgOpacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background that fades with drag-to-dismiss progress.
        ValueListenableBuilder<double>(
          valueListenable: _bgOpacity,
          builder: (context, opacity, _) {
            return ColoredBox(
              color: (widget.theme?.backgroundColor ?? Colors.black)
                  .withValues(alpha: opacity),
            );
          },
        ),
        BlocBuilder<GalleryBloc, GalleryState>(
          buildWhen: (prev, curr) =>
              !identical(prev.items, curr.items) ||
              prev.items.length != curr.items.length,
          builder: (context, state) {
            return ZoomAwarePageView(
              controller: widget.pageController,
              itemCount: state.items.length,
              currentItemScale: _currentScale,
              onPageChanged: (index) {
                _resetScale();
                context.read<GalleryBloc>().add(GalleryIndexChanged(index));
              },
              itemBuilder: (context, index) {
                return _buildPage(context, state.items[index], index);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPage(BuildContext context, GalleryItem item, int index) {
    final bloc = context.read<GalleryBloc>();

    Widget content;
    switch (item.type) {
      case GalleryItemType.image:
        content = GalleryImageItem(
          item: item,
          scaleNotifier: _currentScale,
          enableZoom: widget.enableZoom,
          progressWidget: widget.progressWidget,
          onZoomIn: () => _setUIVisible(context, false),
          onZoomOut: () => _setUIVisible(context, true),
        );
        // Tap toggles UI on image pages only (media items have their own tap).
        content = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _toggleUI(context),
          child: content,
        );
      case GalleryItemType.video:
        content = GalleryVideoItem(
          item: item,
          index: index,
          activePlayerNotifier: widget.activePlayerNotifier,
          galleryBloc: bloc,
          noInternetMessage: widget.noInternetMessage,
          theme: widget.theme,
        );
      case GalleryItemType.audio:
        content = GalleryAudioItem(
          item: item,
          index: index,
          activePlayerNotifier: widget.activePlayerNotifier,
          galleryBloc: bloc,
          noInternetMessage: widget.noInternetMessage,
        );
      case GalleryItemType.youtube:
        content = GalleryYoutubeItem(
          item: item,
          index: index,
          activeYoutubeNotifier: widget.activeYoutubeNotifier,
          galleryBloc: bloc,
          noInternetMessage: widget.noInternetMessage,
          theme: widget.theme,
        );
    }

    final hero = Hero(tag: item.url, child: content);

    if (!widget.enableSwipeToDismiss) {
      return hero;
    }

    return DismissibleDragArea(
      enabled: true,
      scaleNotifier: _currentScale,
      onDismiss: () => _handleDismiss(context),
      onDragProgress: (progress) => _handleDragProgress(context, progress),
      onDragActiveChanged: (active) {
        if (!active) _handleDragEnded(context);
      },
      child: hero,
    );
  }
}
