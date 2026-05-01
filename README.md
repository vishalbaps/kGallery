# kGallery 🖼️

[![Pub Version](https://img.shields.io/pub/v/k_gallery)](https://pub.dev/packages/k_gallery)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://github.com/vishalbaps/kGallery/blob/main/LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)

A high-performance, premium, and fully-featured media gallery viewer for Flutter. Inspired by the sleek experience of Telegram, `kGallery` supports images, videos, audio, and YouTube content with smooth transitions and intuitive gestures.



## 📸 Demo

<p align="center">
  <img src="https://raw.githubusercontent.com/vishalbaps/kGallery/main/screenshots/gallery_view.png" width="30%" alt="Gallery View" />
  <img src="https://raw.githubusercontent.com/vishalbaps/kGallery/main/screenshots/video_view.png" width="30%" alt="Simulator Demo" />
</p>

### 📺 Preview

![kGallery Demo Video](https://raw.githubusercontent.com/vishalbaps/kGallery/main/screenshots/demo.gif)

## ✨ Features

- 🖼️ **Multi-Media Support**: Seamlessly view images, watch videos, listen to audio, and play YouTube links — all with unified controls.
- 📺 **YouTube Playback**: Play any YouTube URL (`youtu.be/...`, `youtube.com/watch?v=...`, `/shorts/...`, `/embed/...`) with play/pause, buffering indicator, and seekbar. Tap `⤢` for a landscape fullscreen view with timer and seekbar.
- 🔍 **Pinch-to-Zoom**: Advanced image viewing with double-tap zoom and smooth pinch gestures.
- 🎞️ **Thumbnail Strip**: Animated, haptic-enabled thumbnail strip with a live seekbar for quick navigation.
- 🖐️ **Swipe-to-Dismiss**: Natural vertical swipe gesture to exit the gallery with dynamic background fading.
- 📝 **Draggable Info Panel**: Overlays for titles and descriptions that can be expanded or collapsed.
- 📱 **Adaptive Layout**: Optimized for both mobile phones and tablets.
- 🎬 **Video/Audio Controls**: Integrated seekbar and playback controls powered by `media_kit`.
- 🌐 **Connectivity Aware**: Automatically checks for internet before playing remote media.
- 🎨 **Fully Customizable**: Inject your own progress widgets, action menus, and theme colors.

## 🚀 Getting Started

### 1. Add dependency

```yaml
dependencies:
  k_gallery: ^1.0.2
```

### 2. Platform Setup

#### Video / Audio (media_kit)

Follow the [media_kit native setup](https://github.com/media-kit/media-kit#getting-started) for your target platforms:
- **Android**: `minSdkVersion` 16 or higher in `android/app/build.gradle`.
- **iOS**: No extra steps beyond media_kit's own requirements.
- **macOS / Windows / Linux**: Link the native libraries as described in the media_kit docs.

#### YouTube (flutter_inappwebview)

YouTube playback is WebView-based via `youtube_player_flutter`. On **iOS**, add the following to `ios/Runner/Info.plist` to allow the WebView to load YouTube content:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

On **Android**, internet permission is required (typically already present in most apps):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```


## 🛠️ Usage

```dart
import 'package:k_gallery/k_gallery.dart';

void _openGallery(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => KGallery(
        contentList: [
          GalleryItem(
            url: 'https://example.com/video.mp4',
            type: GalleryItemType.video,
            title: 'Big Buck Bunny',
            description: 'A classic animation.',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ),
          GalleryItem(
            url: 'https://example.com/audio.mp3',
            type: GalleryItemType.audio,
            title: 'My Track',
            thumbnailUrl: 'https://example.com/album_art.jpg',
          ),
          GalleryItem(
            url: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
            type: GalleryItemType.youtube,
            title: 'Big Buck Bunny on YouTube',
          ),
          GalleryItem(
            url: 'https://example.com/photo.jpg',
            type: GalleryItemType.image,
            title: 'Sunset',
          ),
        ],
        initialIndex: 0,
        onClose: (index) => Navigator.of(context).pop(),
      ),
    ),
  );
}
```

### YouTube items

`GalleryItemType.youtube` accepts any standard YouTube URL form. The player uses the official YouTube IFrame Player API (via [`youtube_player_flutter`](https://pub.dev/packages/youtube_player_flutter)) and renders the same seekbar, center play/pause button, and fullscreen `⤢` button as regular video items.

> Your use of YouTube content is governed by the [YouTube Terms of Service](https://www.youtube.com/t/terms). Respect creators' embedding settings.

## ⚙️ Customization

### `KGallery` parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `contentList` | `List<GalleryItem>` | **required** | The list of media items to display. |
| `initialIndex` | `int` | **required** | Index of the item to open first. |
| `progressWidget` | `Widget?` | `CircularProgressIndicator` | Loading indicator for full-size media items. |
| `thumbProgressWidget` | `Widget?` | Shimmer effect | Loading indicator for thumbnails in the strip. |
| `enableZoom` | `bool` | `true` | Enable pinch-to-zoom and double-tap zoom on images. |
| `enableSwipeToDismiss` | `bool` | `true` | Enable swipe-down-to-exit gesture. |
| `enableHapticFeedback` | `bool` | `true` | Haptic feedback when tapping thumbnails. |
| `leading` | `Widget?` | Back arrow | Custom leading widget in the top bar. |
| `title` | `String?` | — | Custom title displayed in the top bar. |
| `noInternetMessage` | `String?` | Theme default | Message shown when media cannot load due to no connectivity. |
| `onIndexChanged` | `void Function(int)?` | — | Called whenever the visible item changes. |
| `onClose` | `void Function(int)?` | `Navigator.pop` | Called when the gallery is closed; receives the last visible index. |
| `theme` | `GalleryTheme?` | `GalleryTheme.dark()` | Visual customization (colors, text styles, thumbnail sizes). |
| `actionMenuBuilder` | `Widget Function(BuildContext, int, List<GalleryItem>)?` | — | Builds a custom action menu in the top bar for the current item. |

### `GalleryTheme` fields

| Field | Default | Description |
|---|---|---|
| `backgroundColor` | `Colors.black` | Gallery background color. |
| `appBarColor` | `black 50%` | Top bar and thumbnail strip background color. |
| `seekbarActiveColor` | `Colors.white` | Played portion and thumb color of the seekbar. |
| `seekbarInactiveColor` | `Colors.white30` | Buffered/unplayed portion color of the seekbar. |
| `mobileThumbnailHeight` | `90` | Thumbnail strip height on phones (dp). |
| `tabletThumbnailHeight` | `110` | Thumbnail strip height on tablets (dp). |
| `titleTextStyle` | — | Text style for item titles in the info panel. |
| `descriptionTextStyle` | — | Text style for item descriptions in the info panel. |
| `counterTextStyle` | — | Text style for the `1 / N` counter in the top bar. |
| `noInternetMessage` | `'No internet connection…'` | Default no-connectivity message. |

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
