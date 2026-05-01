## 1.0.2

- Feature: YouTube video support via the new `GalleryItemType.youtube` value. Pass any standard YouTube link (`youtu.be/...`, `youtube.com/watch?v=...`, `/shorts/...`, `/embed/...`) and it plays inside the gallery with the same seekbar, fullscreen, theme, and play/pause controls. Powered by `youtube_player_flutter` (official YouTube IFrame Player API).
- Fix (iOS): Video playback would stop ~1 second after swiping past an adjacent audio item. Caused by multiple coexisting `media_kit` `Player` instances competing for the global AVAudioSession. The video/audio item widget now lazily creates its `Player` only while it is the current item and disposes it as soon as it stops being current, guaranteeing a single live `Player` at any time.

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
