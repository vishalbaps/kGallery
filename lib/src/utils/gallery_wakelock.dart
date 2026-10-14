import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Internal, ref-counted owner of the screen wakelock that keeps the device
/// from dimming or auto-locking while a gallery video is playing.
///
/// Each playing video item (media_kit or YouTube) acquires it with itself as
/// the owner. The platform wakelock is enabled when the first owner acquires
/// and disabled when the last one releases.
///
/// This is the only place kGallery talks to [WakelockPlus]. media_kit's own
/// wakelock is turned off (`Video(wakelock: false)`) because it keeps a
/// separate static count and calls the global [WakelockPlus.disable] when that
/// count reaches zero, which would switch the screen back to auto-lock while a
/// YouTube item still needs it on.
///
/// A wakelock the host app already holds is never turned off: if the platform
/// wakelock is already on when kGallery's first owner acquires, kGallery leaves
/// it alone and does not disable it on release.
class GalleryWakelock {
  GalleryWakelock._();

  static final Set<Object> _owners = <Object>{};

  /// Whether kGallery itself turned the platform wakelock on, and so is the
  /// one allowed to turn it off.
  static bool _enabledByGallery = false;

  /// Platform calls run one at a time, each applying the owner set as it is
  /// when the call runs. A release immediately followed by an acquire (swiping
  /// from one playing video to the next) therefore can't land out of order.
  static Future<void> _queue = Future<void>.value();

  /// Marks [owner] as needing the screen kept on. Idempotent per owner.
  static void acquire(Object owner) {
    if (_owners.add(owner) && _owners.length == 1) _schedule();
  }

  /// Drops [owner]'s claim. Idempotent per owner.
  static void release(Object owner) {
    if (_owners.remove(owner) && _owners.isEmpty) _schedule();
  }

  /// Drops every claim. Safety net for gallery teardown, so a missed release
  /// can never leave the screen on after the gallery is gone.
  static void releaseAll() {
    if (_owners.isEmpty) return;
    _owners.clear();
    _schedule();
  }

  static void _schedule() => _queue = _queue.then((_) => _apply());

  static Future<void> _apply() async {
    final wanted = _owners.isNotEmpty;
    if (wanted == _enabledByGallery) return;
    // Platform errors (e.g. no foreground activity yet) are swallowed, as
    // media_kit does: a missing wakelock must never break playback.
    try {
      if (wanted) {
        // Already on means the host app holds it: leave it to the host.
        if (await WakelockPlus.enabled) return;
        await WakelockPlus.enable();
        _enabledByGallery = true;
      } else {
        await WakelockPlus.disable();
        _enabledByGallery = false;
      }
    } catch (_) {}
  }

  /// Whether any owner currently holds the wakelock.
  @visibleForTesting
  static bool get isHeld => _owners.isNotEmpty;

  /// Completes once every platform call queued so far has run.
  @visibleForTesting
  static Future<void> get idle => _queue;

  /// Clears all state between tests.
  @visibleForTesting
  static void debugReset() {
    _owners.clear();
    _enabledByGallery = false;
    _queue = Future<void>.value();
  }
}
