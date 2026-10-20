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

<p align="center">
  <img src="https://raw.githubusercontent.com/vishalbaps/kGallery/main/screenshots/demo.gif" alt="kGallery Demo Video" width="30%" />
</p>
  
## ✨ Features

- 🖼️ **Multi-Media Support**: Seamlessly view images, watch videos, listen to audio, and play YouTube links — all with unified controls.
- 📺 **YouTube Playback**: Play any YouTube URL (`youtu.be/...`, `youtube.com/watch?v=...`, `/shorts/...`, `/embed/...`) with play/pause, buffering indicator, and seekbar. Tap `⤢` for a landscape fullscreen view with timer and seekbar.
- 💬 **YouTube Captions**: Captions start off, even for videos whose uploader set them on by default. Opt in to a CC button that lets the viewer turn them on or off (inline and fullscreen) with `showYoutubeCaptionToggle: true`, or start with captions on via `youtubeCaptionsEnabled: true`.
- 🔍 **Pinch-to-Zoom**: Advanced image viewing with tap-centered double-tap zoom and smooth pinch gestures (up to 8×).
- 🧬 **Base64 Images**: Render inline `data:image/...;base64,...` URIs anywhere an image appears — no network request, no model changes.
- 🎞️ **Thumbnail Strip**: Animated, haptic-enabled thumbnail strip with a live seekbar for quick navigation.
- 🖐️ **Swipe-to-Dismiss**: Natural swipe gesture to exit the gallery — flick **up or down** — with an Apple Photos–style fly-away and dynamic background fading.
- 📝 **Draggable Info Panel**: Overlays for titles and descriptions that can be expanded or collapsed.
- 📱 **Adaptive Layout**: Optimized for both mobile phones and tablets.
- 🎬 **Video/Audio Controls**: Integrated seekbar and playback controls powered by `media_kit`.
- 🔆 **Screen Stays On During Playback**: While a video or YouTube item plays, the screen won't dim or auto-lock; it returns to normal as soon as playback pauses, ends, or the gallery closes. Opt out with `keepScreenOnWhilePlaying: false`.
- 🌐 **Connectivity Aware**: Checks for internet before playing remote media, and shows a theme-aware **offline placeholder** when a remote item can't load — auto-reloading when the user returns to it. Fully replaceable via `offlineBuilder`.
- 🎨 **Fully Customizable**: Inject your own progress widgets, action menus, and theme colors.

## 🚀 Getting Started

### 1. Add dependency

```yaml
dependencies:
  k_gallery: ^1.1.6
```

### 2. Platform Setup

#### Video / Audio (media_kit)

Follow the [media_kit native setup](https://github.com/media-kit/media-kit#getting-started) for your target platforms:
- **Android**: `minSdkVersion` 19 or higher in `android/app/build.gradle` (required by the YouTube WebView, `flutter_inappwebview`).
- **iOS**: Deployment target 12.0 or higher (also required by `flutter_inappwebview`). No extra steps beyond media_kit's own requirements.
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

Use `KGallery.show(...)` — it presents the gallery on a **transparent route**, so
the screen behind stays visible through the background fade when the user swipes
down to dismiss. It returns the last-viewed index.

```dart
import 'package:k_gallery/k_gallery.dart';

Future<void> _openGallery(BuildContext context) async {
  final lastIndex = await KGallery.show(
    context,
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
  );
}
```

### Base64 images

Any image source — `url` or `thumbnailUrl` — may be an inline base64 data URI
instead of a network URL. kGallery detects the `;base64,` marker automatically
and renders it everywhere (full-screen viewer, thumbnail strip, media posters).
No network request is made and no model change is needed:

```dart
GalleryItem(
  url: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg...',
  type: GalleryItemType.image,
  title: 'Inline image',
);
```

### YouTube items

`GalleryItemType.youtube` accepts any standard YouTube URL form. The player uses the official YouTube IFrame Player API (via [`youtube_player_flutter`](https://pub.dev/packages/youtube_player_flutter)) and renders the same seekbar, center play/pause button, and fullscreen `⤢` button as regular video items.

> Your use of YouTube content is governed by the [YouTube Terms of Service](https://www.youtube.com/t/terms). Respect creators' embedding settings.

### YouTube captions

YouTube items start with captions **off**, including videos whose uploader set captions to show by default, and without a CC button. Both are opt-in:

```dart
KGallery.show(
  context,
  contentList: items,
  initialIndex: 0,
  youtubeCaptionsEnabled: false,   // starting state (default: false)
  youtubeCaptionLanguage: 'en',    // preferred track when captions are on
  showYoutubeCaptionToggle: true,  // show the CC button (default: false)
);
```

With `showYoutubeCaptionToggle: true`, a **CC** button next to the fullscreen button (and in the fullscreen controls) lets the viewer turn captions on or off; it follows the same auto-hide as the other controls. The viewer's choice carries over fullscreen and every other YouTube item until the gallery closes, and each new gallery starts from `youtubeCaptionsEnabled` again. Without the button, captions always follow `youtubeCaptionsEnabled`.

When captions are on, the gallery picks the `youtubeCaptionLanguage` track if the video has one, including a regional variant such as `en-GB` for `en`. Otherwise YouTube's own default track is shown, which may be auto-generated.

When enabled, the CC button appears on every YouTube video, including videos without captions, where turning them on shows nothing. YouTube's player API doesn't list auto-generated tracks, so it can't tell a video without captions from one that has only auto-generated captions.

### Keeping the screen on during playback

While a video or YouTube item is playing (inline or fullscreen), the gallery keeps the device screen from dimming or auto-locking. The screen returns to its normal auto-lock timeout as soon as playback pauses, ends, or fails, the item is swiped away, or the gallery closes. Images and audio never keep the screen on.

This uses [`wakelock_plus`](https://pub.dev/packages/wakelock_plus) and needs no extra platform setup. A wakelock your app already holds when the gallery starts playing is left untouched. To opt out and always use the device's normal auto-lock:

```dart
KGallery.show(
  context,
  contentList: items,
  initialIndex: 0,
  keepScreenOnWhilePlaying: false,
);
```

## ⬆️ Migrating to 1.1.0

1.1.0 introduces **no breaking API changes** — base64 image support, the
higher 8× zoom, and the zoom/pan/dismiss fixes are all additive, so existing
code keeps working. There is one recommended change:

- **Present the gallery with `KGallery.show(...)`.** If you were pushing
  `KGallery` on a `MaterialPageRoute` (or any opaque route), switch to
  `KGallery.show(context, contentList: ..., initialIndex: ...)`. On an opaque
  route Flutter stops painting the screen below, so the swipe-down dismiss fade
  reveals only black; `show()` uses a non-opaque route so the screen behind
  stays visible. It returns the last-viewed index.

The `KGallery` widget constructor is unchanged. If you must push it yourself,
push on a non-opaque route so the see-through dismiss still works:

```dart
Navigator.of(context).push(
  PageRouteBuilder(
    opaque: false,                       // screen below stays visible
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, _) => FadeTransition(
      opacity: animation,
      child: KGallery(contentList: items, initialIndex: 0),
    ),
  ),
);
```

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
| `offlineBuilder` | `Widget Function(BuildContext, GalleryItem)?` | Built-in view | Custom placeholder shown inside the viewer when a remote item can't load (e.g. offline). Defaults to a theme-aware icon/title/subtitle view; the item reloads automatically when the user slides back to it. |
| `onIndexChanged` | `void Function(int)?` | — | Called whenever the visible item changes. |
| `onClose` | `void Function(int)?` | `Navigator.pop` | Called when the gallery is closed; receives the last visible index. |
| `theme` | `GalleryTheme?` | `GalleryTheme.dark()` | Visual customization (colors, text styles, thumbnail sizes). |
| `actionMenuBuilder` | `Widget Function(BuildContext, int, List<GalleryItem>)?` | — | Builds a custom action menu in the top bar for the current item. |
| `cacheManager` | `BaseCacheManager?` | shared default | Cache manager for network images (full-screen, thumbnails, audio artwork). Pass your own `CacheManager(Config(...))` to share a cache with the rest of your app or control the disk-cache policy. Re-exported from `package:k_gallery`. |
| `memCacheWidth` | `int?` | — | Caps the in-memory bitmap width for full-screen network images (`CachedNetworkImage.memCacheWidth`) to reduce memory for very large sources. Thumbnails use their own small fixed decode size. |
| `keepScreenOnWhilePlaying` | `bool` | `true` | Keeps the screen from dimming or auto-locking while a video or YouTube item is playing (inline or fullscreen). Released on pause, end, failure, swipe away, and close. Set to `false` to always use the device's normal auto-lock. |
| `youtubeCaptionsEnabled` | `bool` | `false` | Whether YouTube items start with captions shown. Enforced even for videos whose uploader set captions on by default. With `showYoutubeCaptionToggle`, the viewer's choice lasts for the rest of the gallery session; each new gallery starts from this value. |
| `youtubeCaptionLanguage` | `String` | `'en'` | Preferred caption language (ISO 639-1, e.g. `es`; regional codes such as `pt-BR` also work) used when captions are on. Falls back to YouTube's default track when the video doesn't offer it. |
| `showYoutubeCaptionToggle` | `bool` | `false` | Shows a CC button on YouTube items, inline and in fullscreen, to turn captions on or off. While `false`, captions always follow `youtubeCaptionsEnabled`. |

### `GalleryTheme` fields

| Field | Default | Description |
|---|---|---|
| `backgroundColor` | `Colors.black` | Gallery background color. |
| `appBarColor` | `black 50%` | Top bar background. |
| `thumbnailStripColor` | `black 65%` | Bottom thumbnail strip background. Set to color the strip independently of the top bar. |
| `textPanelGradientStartColor` | `null` → `thumbnailStripColor` | Bottom (opaque) color of the title/description panel gradient — the end behind the text. |
| `textPanelGradientEndColor` | `null` → `Colors.transparent` | Top color of the title/description panel gradient — the end that fades out over the media. |
| `seekbarActiveColor` | `Colors.white` | Played portion and thumb color of the seekbar. |
| `seekbarInactiveColor` | `Colors.white30` | Buffered/unplayed portion color of the seekbar. |
| `mobileThumbnailHeight` | `90` | Thumbnail strip height on phones (dp). |
| `tabletThumbnailHeight` | `110` | Thumbnail strip height on tablets (dp). |
| `titleTextStyle` | — | Text style for item titles in the info panel. |
| `descriptionTextStyle` | — | Text style for item descriptions in the info panel. |
| `counterTextStyle` | — | Text style for the `1 / N` counter in the top bar. |

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
