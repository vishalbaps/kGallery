# kGallery 🖼️

[![Pub Version](https://img.shields.io/pub/v/k_gallery)](https://pub.dev/packages/k_gallery)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://github.com/vishalbaps/kGallery/blob/main/LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)

A high-performance, premium, and fully-featured media gallery viewer for Flutter. Inspired by the sleek experience of Telegram, `kGallery` supports images, videos, and audio content with smooth transitions and intuitive gestures.

![kGallery Banner](https://raw.githubusercontent.com/vishalbaps/kGallery/main/screenshots/kgallery_banner.png)

## 📸 Demo

<p align="center">
  <img src="https://raw.githubusercontent.com/vishalbaps/kGallery/main/screenshots/gallery_view.png" width="30%" alt="Gallery View" />
  <img src="https://raw.githubusercontent.com/vishalbaps/kGallery/main/screenshots/simulator_demo.png" width="30%" alt="Simulator Demo" />
</p>

### 📺 Video Preview

![kGallery Demo Video](https://raw.githubusercontent.com/vishalbaps/kGallery/main/screenshots/demo.mp4)

## ✨ Features

- 🖼️ **Multi-Media Support**: Seamlessly view images, watch videos, and listen to audio.
- 🔍 **Pinch-to-Zoom**: Advanced image viewing with double-tap zoom and smooth pinch gestures.
- 🎞️ **Thumbnail Strip**: Animated, haptic-enabled thumbnail strip for quick navigation.
- 🖐️ **Swipe-to-Dismiss**: Natural vertical swipe gesture to exit the gallery with dynamic background fading.
- 📝 **Draggable Info Panel**: Overlays for titles and descriptions that can be expanded or collapsed.
- 📱 **Adaptive Layout**: Optimized for both mobile phones and tablets.
- 🎬 **Video/Audio Controls**: Integrated seekbar and playback controls powered by `media_kit`.
- 🌐 **Connectivity Aware**: Automatically checks for internet before playing remote media.
- 🎨 **Fully Customizable**: Inject your own progress widgets, action menus, and styles.

## 🚀 Getting Started

### 1. Add dependency

Add `k_gallery` to your `pubspec.yaml`:

```yaml
dependencies:
  k_gallery: ^1.0.1
```

### 2. Platform Setup (Important!)

This package uses `media_kit` for video and audio playback. You **must** follow the native setup instructions for your target platforms:

- **Android**: Ensure `minSdkVersion` is 16 or higher.
- **iOS**: Add necessary permissions to `Info.plist`.
- **macOS/Windows/Linux**: Follow `media_kit`'s requirements for native libraries.

Refer to the [media_kit documentation](https://github.com/media-kit/media-kit) for detailed setup.

### 3. Initialize

In your `main.dart`, initialize the gallery:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  KGallery.ensureInitialized(); // Initializes MediaKit
  runApp(MyApp());
}
```

## 🛠️ Usage

```dart
import 'package:k_gallery/k_gallery.dart';

// ... inside your widget ...

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

## ⚙️ Customization

| Parameter | Type | Description |
|---|---|---|
| `contentList` | `List<GalleryItem>` | **Required**. The list of media items. |
| `initialIndex` | `int` | **Required**. Index to start from. |
| `progressWidget` | `Widget?` | Custom loader for media items. |
| `thumbProgressWidget` | `Widget?` | Custom loader for thumbnails. |
| `isZoomEnable` | `bool` | Enable/disable pinch zoom (Default: `true`). |
| `isSwipeToDismiss` | `bool` | Enable/disable swipe down to exit (Default: `true`). |
| `isHapticEnable` | `bool` | Enable/disable haptics on thumbnails (Default: `true`). |
| `actionMenuBuilder` | `Widget Function?` | Build a custom menu in the top bar. |
| `onClose` | `Function(int)?` | Custom callback for when the gallery exits. |

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.