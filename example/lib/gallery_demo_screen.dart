import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:k_gallery/k_gallery.dart';

/// A small (160×160) four-quadrant PNG embedded inline as a base64 data URI.
/// Demonstrates that kGallery renders base64 images in both the full-screen
/// viewer and the thumbnail strip — no network request is made for this item.
const String kBase64SampleImage =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAIAAADTED8xAAADMElEQVR4nOzVwQnAIBQFQYXff81RUkQCOyDj1YOPnbXWPmeTRef+/3O/OyBjzh3CD95BfqICMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMK0CMO0TAAD//2Anhf4QtqobAAAAAElFTkSuQmCC';

// dart format off
/// Nature photos for the image items, as [Picsum](https://picsum.photos) IDs
/// (photos from Unsplash). Each ID is a fixed photo, so the demo looks the same
/// on every run.
const List<int> _natureImageIds = [
  10, 11, 12, 13, 14, 15, 16, 17, 18, 25, 27, 29,
  33, 35, 37, 38, 46, 54, 55, 62, 66, 70, 82, 83,
  89, 92, 93, 95, 98, 107, 108, 110, 112, 116, 118, 125,
  126, 127, 128, 132, 136, 140, 141, 147, 152, 159, 162, 165,
  166, 167, 168, 170, 176, 179, 184, 185, 186, 187, 189, 190,
  196, 198, 202, 206, 213, 215, 216, 217, 218, 219, 222, 227,
  229, 231, 235, 243, 247, 251, 255, 256, 260, 261, 266, 277,
  278, 287, 289, 295, 296, 301, 306, 309, 313,
];
// dart format on

/// Picsum URL for a nature photo, at the size the demo uses everywhere.
String _natureImage(int id) => 'https://picsum.photos/id/$id/600/800';

/// Grid thumbnail for a YouTube video (the same image YouTube shows).
String _youtubeThumbnail(String videoId) =>
    'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

/// Items before the first nature photo in the demo list.
const int _mediaItemCount = 7;

class DemoGalleryScreen extends StatefulWidget {
  static const id = 'k_gallery_demo';
  static const path = '/$id';

  const DemoGalleryScreen({super.key});

  @override
  State<DemoGalleryScreen> createState() => _DemoGalleryScreenState();
}

class _DemoGalleryScreenState extends State<DemoGalleryScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Caption settings for YouTube items, changed from the app bar menu. Each
  /// gallery opens with [_youtubeCaptionsEnabled]; the viewer can then flip
  /// captions with the CC button for the rest of that gallery session.
  bool _youtubeCaptionsEnabled = false;
  // Both default to false in kGallery; the demo opts in to the CC button.
  bool _showYoutubeCaptionToggle = true;

  /// A custom cache manager shared between this grid and the gallery. Passing
  /// the same instance to both the grid thumbnails and [KGallery.show] means an
  /// image fetched for the grid is reused full-screen (and vice-versa), and the
  /// host app — not the package — owns the disk-cache policy (key, stale
  /// period, max object count). [CacheManager], [Config], and [BaseCacheManager]
  /// are re-exported by `package:k_gallery`.
  final BaseCacheManager _cacheManager = CacheManager(
    Config(
      'kGalleryDemoCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );

  int _getCrossAxisCount(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    if (shortestSide >= 800) return 6;
    if (shortestSide >= 600) return 5;
    return 3;
  }

  void _scrollToIndex(int index, int crossAxisCount) {
    if (!_scrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 8 - 8;
    final itemWidth = availableWidth / crossAxisCount;
    final rowHeight = itemWidth + 4;

    final row = index ~/ crossAxisCount;
    double offset = row * rowHeight;

    // Ensure we don't scroll beyond limits
    if (offset > _scrollController.position.maxScrollExtent) {
      offset = _scrollController.position.maxScrollExtent;
    }

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Grid thumbnail for an image-bearing item. Branches on the source the same
  /// way kGallery does internally: an inline base64 data URI is decoded and
  /// drawn with [Image.memory]; anything else is fetched via
  /// [CachedNetworkImage]. Mirrors how a host app builds its own grid.
  Widget _buildGridThumbnail(GalleryItem item) {
    final source = item.thumbnailUrl ?? item.url;

    Widget typeIconFallback() => Container(
      color: Colors.grey[900],
      alignment: Alignment.center,
      child: Icon(
        item.type == GalleryItemType.video
            ? Icons.videocam
            : item.type == GalleryItemType.audio
            ? Icons.audiotrack
            : Icons.image_not_supported,
        size: 32,
        color: Colors.white54,
      ),
    );

    if (source.contains(';base64,')) {
      try {
        return Image.memory(
          base64Decode(source.split(';base64,').last),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => typeIconFallback(),
        );
      } catch (_) {
        return typeIconFallback();
      }
    }

    return CachedNetworkImage(
      imageUrl: source,
      fit: BoxFit.cover,
      cacheManager: _cacheManager,
      placeholder: (context, url) => Container(
        color: Colors.grey[900],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => typeIconFallback(),
    );
  }

  /// Opens the gallery via [KGallery.show], which presents it on a transparent
  /// (non-opaque) route so this grid stays visible through the background fade
  /// when the user swipes down to dismiss. The returned index scrolls the grid
  /// to the last-viewed item on close.
  Future<void> _openGallery(List<GalleryItem> contentList, int index) async {
    final result = await KGallery.show(
      context,
      contentList: contentList,
      initialIndex: index,
      onIndexChanged: (newIndex) =>
          _scrollToIndex(newIndex, _getCrossAxisCount(context)),
      actionMenuBuilder: _buildActionMenu,
      // Reuse the grid's cache so images already fetched for the thumbnails
      // load instantly full-screen.
      cacheManager: _cacheManager,
      // YouTube captions: start state, preferred track, and the CC button.
      youtubeCaptionsEnabled: _youtubeCaptionsEnabled,
      youtubeCaptionLanguage: 'en',
      showYoutubeCaptionToggle: _showYoutubeCaptionToggle,
      progressWidget: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );

    if (result != null && mounted) {
      _scrollToIndex(result, _getCrossAxisCount(context));
    }
  }

  /// App bar menu for the YouTube caption options passed to [KGallery.show].
  Widget _buildCaptionsMenu() {
    return PopupMenuButton<String>(
      tooltip: 'YouTube captions',
      icon: Icon(
        _youtubeCaptionsEnabled
            ? Icons.closed_caption
            : Icons.closed_caption_off,
      ),
      onSelected: (value) => setState(() {
        switch (value) {
          case 'start_on':
            _youtubeCaptionsEnabled = !_youtubeCaptionsEnabled;
          case 'show_toggle':
            _showYoutubeCaptionToggle = !_showYoutubeCaptionToggle;
        }
      }),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'start_on',
          checked: _youtubeCaptionsEnabled,
          child: const Text('Start with captions on'),
        ),
        CheckedPopupMenuItem(
          value: 'show_toggle',
          checked: _showYoutubeCaptionToggle,
          child: const Text('Show CC button'),
        ),
      ],
    );
  }

  Widget _buildActionMenu(
    BuildContext context,
    int currentIndex,
    List<GalleryItem> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final currentItem = items[currentIndex];
    return PopupMenuButton<String>(
      color: Colors.black,
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) {
        switch (value) {
          case 'download':
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloading: ${currentItem.title ?? "Image"}'),
              ),
            );
            break;
          case 'slideshow':
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'slideshow',
          child: Row(
            children: [
              Icon(Icons.slideshow, size: 20, color: Colors.white),
              SizedBox(width: 12),
              Text('Slideshow', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'download',
          child: Row(
            children: [
              Icon(Icons.download, size: 20, color: Colors.white),
              SizedBox(width: 12),
              Text('Download Image', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<GalleryItem>
    contentList = List.generate(_mediaItemCount + _natureImageIds.length, (
      index,
    ) {
      if (index == 0) {
        return GalleryItem(
          url:
              'https://videos.pexels.com/video-files/6896062/6896062-hd_720_1280_30fps.mp4',
          type: GalleryItemType.video,
          title: 'Forest Stream (Vertical)',
          description:
              'A beautiful vertical video of a forest stream to test gallery behavior.',
          thumbnailUrl: _natureImage(28),
        );
      }
      if (index == 1) {
        return GalleryItem(
          url:
              'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          type: GalleryItemType.video,
          title: 'Honey Bee (Video)',
          description:
              'A bee at work among the flowers, played by media_kit with the '
              'same controls as the rest of the gallery.',
          thumbnailUrl: _natureImage(106),
        );
      }
      if (index == 2) {
        return const GalleryItem(
          url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          type: GalleryItemType.audio,
          title: 'SoundHelix Song 1 (Audio)',
          description:
              'A long audio track to demonstrate the audio player interface.',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&h=800&fit=crop',
        );
      }
      if (index == 3) {
        return GalleryItem(
          url: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
          type: GalleryItemType.youtube,
          title: 'Big Buck Bunny (YouTube)',
          description:
              'Played by the YouTube player with the same seekbar and '
              'play/pause controls as the rest of the gallery. This video has '
              'no captions.',
          thumbnailUrl: _youtubeThumbnail('aqz-KE-bpKQ'),
        );
      }
      if (index == 4) {
        return const GalleryItem(
          url: kBase64SampleImage,
          type: GalleryItemType.image,
          title: 'Base64 Image (local)',
          description:
              'This image is passed as an inline base64 data URI — no network '
              'request is made. It renders in both the grid thumbnail and the '
              'full-screen viewer.',
        );
      }
      if (index == 5) {
        return GalleryItem(
          url: 'https://www.youtube.com/watch?v=a3ICNMQW7Ok',
          type: GalleryItemType.youtube,
          thumbnailUrl: _youtubeThumbnail('a3ICNMQW7Ok'),
          title: 'YouTube (Fullscreen Controls)',
          description:
              'A second YouTube item. Enter fullscreen and confirm the '
              'controls auto-hide after 3 seconds and reappear on tap, '
              'matching the media_kit video controls.',
        );
      }
      if (index == 6) {
        return GalleryItem(
          url: 'https://www.youtube.com/watch?v=oI3ADcDH0Uc',
          type: GalleryItemType.youtube,
          title: 'Koalas 101 (YouTube, Captions)',
          description:
              'A narrated nature video with English captions. Tap the CC '
              'button next to fullscreen to turn captions on or off; the '
              'choice carries over fullscreen and the other YouTube items '
              'until the gallery closes. The CC menu in the app bar sets '
              'whether captions start on and whether the button is shown.',
          thumbnailUrl: _youtubeThumbnail('oI3ADcDH0Uc'),
        );
      }

      String? title;
      String? description;

      if (index % 4 == 0) {
        title = 'Short Title ${index + 1}';
        description = 'This is a brief caption for image ${index + 1}.';
      } else if (index % 4 == 1) {
        title = null;
        description = null;
      } else if (index % 4 == 2) {
        title = 'Epic Description ${index + 1}';
        description =
            'This is an enormous description for photo number ${index + 1}. ' *
                8 +
            'It features a huge amount of text to demonstrate scrolling. ' * 8;
      } else {
        title = 'Gallery Item ${index + 1}';
        description =
            'A moderately sized description that spans two or three lines but definitely does not hit the maximum height bound. Ideal for normal photos.';
      }

      return GalleryItem(
        url: _natureImage(_natureImageIds[index - _mediaItemCount]),
        type: GalleryItemType.image,
        title: title,
        description: description,
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram Gallery Demo'),
        actions: [_buildCaptionsMenu()],
      ),
      body: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(4),
        itemCount: contentList.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(context),
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          final item = contentList[index];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openGallery(contentList, index),
            child: Hero(
              tag: item.url,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (item.type != GalleryItemType.image &&
                          item.thumbnailUrl == null)
                      ? Container(
                          color: Colors.grey[900],
                          alignment: Alignment.center,
                          child: Icon(
                            item.type == GalleryItemType.video
                                ? Icons.videocam
                                : Icons.audiotrack,
                            size: 32,
                            color: Colors.white54,
                          ),
                        )
                      : _buildGridThumbnail(item),
                  if (item.type != GalleryItemType.image &&
                      item.thumbnailUrl != null)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
