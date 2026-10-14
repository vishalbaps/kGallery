import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_gallery/k_gallery.dart';
import 'package:k_gallery/src/utils/gallery_wakelock.dart';
import 'package:k_gallery/src/widgets/media/gallery_youtube_item.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// A valid 1×1 PNG encoded as an inline base64 data URI.
const String _image =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mPQO1MIAAKXAWyCXhvQAAAAAElFTkSuQmCC';

/// Records every platform toggle and mirrors the platform's on/off state.
class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  _FakeWakelockPlatform({this.isOn = false});

  bool isOn;
  bool throwOnToggle = false;
  final List<bool> toggles = [];

  @override
  Future<void> toggle({required bool enable}) async {
    if (throwOnToggle) throw Exception('no activity');
    toggles.add(enable);
    isOn = enable;
  }

  @override
  Future<bool> get enabled async => isOn;
}

void main() {
  late _FakeWakelockPlatform platform;

  void install(_FakeWakelockPlatform fake) {
    platform = fake;
    WakelockPlusPlatformInterface.instance = fake;
    // wakelock_plus captures the platform instance on first use, so swap the
    // captured one as well for each test's fresh fake.
    wakelockPlusPlatformInstance = fake;
  }

  setUp(() {
    GalleryWakelock.debugReset();
    install(_FakeWakelockPlatform());
  });

  group('GalleryWakelock', () {
    test('a single owner enables on acquire and disables on release', () async {
      final owner = Object();

      GalleryWakelock.acquire(owner);
      await GalleryWakelock.idle;
      expect(platform.isOn, isTrue);

      GalleryWakelock.release(owner);
      await GalleryWakelock.idle;
      expect(platform.isOn, isFalse);
      expect(platform.toggles, [true, false]);
    });

    test('stays enabled until the last of two owners releases', () async {
      final youtube = Object();
      final video = Object();

      GalleryWakelock.acquire(youtube);
      GalleryWakelock.acquire(video);
      await GalleryWakelock.idle;

      GalleryWakelock.release(youtube);
      await GalleryWakelock.idle;
      expect(platform.isOn, isTrue);

      GalleryWakelock.release(video);
      await GalleryWakelock.idle;
      expect(platform.isOn, isFalse);
      expect(platform.toggles, [true, false]);
    });

    test('double acquire and double release are no-ops', () async {
      final owner = Object();

      GalleryWakelock.acquire(owner);
      GalleryWakelock.acquire(owner);
      await GalleryWakelock.idle;
      GalleryWakelock.release(owner);
      await GalleryWakelock.idle;
      GalleryWakelock.release(owner);
      await GalleryWakelock.idle;

      expect(platform.toggles, [true, false]);
    });

    test('releaseAll disables regardless of how many owners hold it', () async {
      final a = Object();
      final b = Object();
      GalleryWakelock.acquire(a);
      GalleryWakelock.acquire(b);
      await GalleryWakelock.idle;

      GalleryWakelock.releaseAll();
      await GalleryWakelock.idle;
      expect(platform.isOn, isFalse);
      expect(GalleryWakelock.isHeld, isFalse);

      // Owners releasing afterwards (e.g. from their own dispose) are no-ops.
      GalleryWakelock.release(a);
      GalleryWakelock.releaseAll();
      await GalleryWakelock.idle;
      expect(platform.toggles, [true, false]);
    });

    test('release then acquire in the same frame ends enabled', () async {
      // Swiping from one playing video straight to another.
      final previous = Object();
      final next = Object();
      GalleryWakelock.acquire(previous);
      await GalleryWakelock.idle;

      GalleryWakelock.release(previous);
      GalleryWakelock.acquire(next);
      await GalleryWakelock.idle;

      expect(platform.isOn, isTrue);
    });

    test('never turns off a wakelock the host app already holds', () async {
      install(_FakeWakelockPlatform(isOn: true));
      final owner = Object();

      GalleryWakelock.acquire(owner);
      await GalleryWakelock.idle;
      GalleryWakelock.release(owner);
      await GalleryWakelock.idle;
      GalleryWakelock.acquire(owner);
      GalleryWakelock.releaseAll();
      await GalleryWakelock.idle;

      expect(platform.isOn, isTrue);
      expect(platform.toggles, isEmpty);
    });

    test('swallows platform errors and keeps working afterwards', () async {
      final owner = Object();
      platform.throwOnToggle = true;

      GalleryWakelock.acquire(owner);
      await GalleryWakelock.idle;
      GalleryWakelock.release(owner);
      await GalleryWakelock.idle;
      expect(platform.isOn, isFalse);

      platform.throwOnToggle = false;
      GalleryWakelock.acquire(owner);
      await GalleryWakelock.idle;
      expect(platform.isOn, isTrue);
    });
  });

  group('youtubeIsActivelyPlaying', () {
    YoutubePlayerValue value({
      bool isReady = true,
      bool isPlaying = true,
      PlayerState playerState = PlayerState.playing,
      int errorCode = 0,
    }) =>
        YoutubePlayerValue(
          isReady: isReady,
          isPlaying: isPlaying,
          playerState: playerState,
          errorCode: errorCode,
        );

    test('holds while playing and while buffering mid-playback', () {
      expect(youtubeIsActivelyPlaying(value()), isTrue);
      expect(
        youtubeIsActivelyPlaying(value(playerState: PlayerState.buffering)),
        isTrue,
      );
    });

    test('releases when paused', () {
      expect(
        youtubeIsActivelyPlaying(
          value(isPlaying: false, playerState: PlayerState.paused),
        ),
        isFalse,
      );
    });

    test('releases when ended, although isPlaying stays true', () {
      expect(
        youtubeIsActivelyPlaying(value(playerState: PlayerState.ended)),
        isFalse,
      );
    });

    test('releases on a player error, although isPlaying stays true', () {
      expect(youtubeIsActivelyPlaying(value(errorCode: 150)), isFalse);
    });

    test('releases while the player is not ready (loader)', () {
      expect(youtubeIsActivelyPlaying(value(isReady: false)), isFalse);
    });
  });

  group('KGallery wakelock', () {
    // setUp runs outside testWidgets' fake-async zone; re-seed the platform
    // call queue inside it so `pump()` flushes the queued calls.
    void resetInFakeZone() => GalleryWakelock.debugReset();

    Widget gallery({bool keepScreenOnWhilePlaying = true}) => MaterialApp(
          home: Scaffold(
            body: KGallery(
              contentList: const [
                GalleryItem(url: _image, title: 'A'),
                GalleryItem(url: _image, title: 'B'),
              ],
              initialIndex: 0,
              keepScreenOnWhilePlaying: keepScreenOnWhilePlaying,
            ),
          ),
        );

    testWidgets('a gallery of images never enables the wakelock', (
      tester,
    ) async {
      resetInFakeZone();
      await tester.pumpWidget(gallery());
      await tester.pump(const Duration(milliseconds: 500));

      // Swipe to the second image as well.
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);

      expect(platform.toggles, isEmpty);
      expect(GalleryWakelock.isHeld, isFalse);
    });

    testWidgets('closing the gallery disables the wakelock', (tester) async {
      resetInFakeZone();
      await tester.pumpWidget(gallery());
      // Stands in for a playing video item whose own release was missed.
      GalleryWakelock.acquire(Object());
      await tester.pump();
      expect(platform.isOn, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(platform.isOn, isFalse);
      expect(GalleryWakelock.isHeld, isFalse);
    });

    testWidgets('KGallery.show forwards keepScreenOnWhilePlaying', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => KGallery.show(
                context,
                contentList: const [GalleryItem(url: _image)],
                initialIndex: 0,
                keepScreenOnWhilePlaying: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final kGallery = tester.widget<KGallery>(find.byType(KGallery));
      expect(kGallery.keepScreenOnWhilePlaying, isFalse);
    });
  });
}
