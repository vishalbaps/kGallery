## 1.0.2

- **New**: `GalleryItemType.youtube` — play any YouTube URL (`youtu.be/...`, `youtube.com/watch?v=...`, `/shorts/...`, `/embed/...`) directly in the gallery with the same play/pause button, buffering indicator, and themed seekbar as regular video items.
- **New**: YouTube fullscreen — tap the `⤢` button to open a landscape fullscreen route with a position/duration timer (`00:42 / 10:23`), seekbar (colors from `GalleryTheme`), and exit button — matching the media_kit video fullscreen layout.
- **New**: Seekbar shown above the thumbnail strip for video, audio, and YouTube items while controls are visible.
- **Fix (iOS)**: Video playback stopped ~1 s after swiping past an adjacent audio item. Each item now lazily creates and disposes its `media_kit` `Player` — only one `Player` is alive at a time, eliminating AVAudioSession conflicts.
- **Fix**: YouTube fullscreen playback — video now auto-plays correctly when entering and exiting fullscreen. Root cause: a stale `isReady` flag on the shared `YoutubePlayerController` caused the seek-to-resume command to fire before the new WebView's IFrame API was ready; fixed by resetting `isReady` before each WebView swap.
- **Perf**: Narrowed `BlocBuilder.buildWhen` on the page view so it rebuilds only when the items list changes — previously, every UI tap, swipe gesture, or text-panel drag triggered a full page-view rebuild.
- **Perf**: YouTube play/pause controls now update via a scoped `AnimatedBuilder` instead of full-widget `setState` on every controller tick.
- **Deps**: `flutter_bloc` → ^9.1.1, `freezed_annotation` → ^3.1.0, `extended_image` → ^10.0.1, `json_annotation` → ^4.11.0.

## 1.0.1

- Documentation: Updated README with demo video and screenshots for better project visibility.
- Fix: Use absolute URLs for documentation assets to ensure cross-platform compatibility.

## 1.0.0

### Features
- Full-screen image viewing with pinch-to-zoom and double-tap zoom
- Video playback with seekbar controls (powered by MediaKit)
- Audio playback with album art display
- Animated thumbnail strip with haptic feedback
- Swipe-to-dismiss with dynamic background fade
- Draggable text panel for title/description overlays
- Adaptive layout for phones and tablets
- Connectivity-aware media playback with user feedback
- Customizable progress/placeholder widgets
- Action menu builder for custom toolbar actions
- Hero animation support for smooth transitions
- Configurable zoom, haptics, and swipe-to-dismiss
