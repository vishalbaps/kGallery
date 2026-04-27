import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k_gallery/k_gallery.dart';

class DemoGalleryScreen extends StatefulWidget {
  static const id = 'k_gallery_demo';
  static const path = '/$id';

  const DemoGalleryScreen({super.key});

  @override
  State<DemoGalleryScreen> createState() => _DemoGalleryScreenState();
}

class _DemoGalleryScreenState extends State<DemoGalleryScreen> {
  final ScrollController _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final List<GalleryItem> contentList = List.generate(100, (index) {
      if (index == 0) {
        return const GalleryItem(
          url:
              'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          type: GalleryItemType.video,
          title: 'Big Buck Bunny (Video)',
          description:
              'A large and lovable rabbit deals with three bullying rodents. This demonstrates the MediaKit integration.',
          thumbnailUrl:
              'https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg',
        );
      }
      if (index == 1) {
        return const GalleryItem(
          url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          type: GalleryItemType.audio,
          title: 'SoundHelix Song 1 (Audio)',
          description:
              'A long audio track to demonstrate the audio player interface.',
          thumbnailUrl: 'https://loremflickr.com/600/800/music?lock=999',
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
        url:
            'https://loremflickr.com/600/800/nature,landscape?lock=${index + 3}',
        type: GalleryItemType.image,
        title: title,
        description: description,
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Telegram Gallery Demo')),
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
            onTap: () async {
              final navigator = Navigator.of(context);
              final result = await context.push<int>(
                KGalleryDetailScreen.id,
                extra: {
                  'contentList': contentList,
                  'initialIndex': index,
                  'onIndexChanged': (int newIndex) {
                    _scrollToIndex(newIndex, _getCrossAxisCount(context));
                  },
                },
              );

              if (result != null && mounted) {
                _scrollToIndex(result, _getCrossAxisCount(context));
              }
            },
            child: Hero(
              tag: item.url,
              child:
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
                  : CachedNetworkImage(
                      imageUrl: item.thumbnailUrl ?? item.url,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[900],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
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
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class KGalleryDetailScreen extends StatelessWidget {
  static const id = '/k_gallery_detail';

  final List<GalleryItem> contentList;
  final int initialIndex;
  final void Function(int index)? onIndexChanged;

  const KGalleryDetailScreen({
    super.key,
    required this.contentList,
    required this.initialIndex,
    this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return KGallery(
      contentList: contentList,
      initialIndex: initialIndex,
      onIndexChanged: onIndexChanged,
      actionMenuBuilder: (context, currentIndex, items) {
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
                    content: Text(
                      'Downloading: ${currentItem.title ?? "Image"}',
                    ),
                  ),
                );
                break;
              case 'slideshow':
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'slideshow',
              child: Row(
                children: [
                  Icon(Icons.slideshow, size: 20, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Slideshow', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
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
      },
      progressWidget: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
