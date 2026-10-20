import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_gallery/k_gallery.dart';
import 'package:k_gallery/src/utils/youtube_captions.dart';
import 'package:k_gallery/src/widgets/gallery_image_viewer.dart';
import 'package:k_gallery/src/widgets/media/gallery_media_internals.dart';
import 'package:k_gallery/src/widgets/media/gallery_youtube_item.dart';

const _youtubeA = GalleryItem(
  url: 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
  type: GalleryItemType.youtube,
);
const _youtubeB = GalleryItem(
  url: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
  type: GalleryItemType.youtube,
);

/// Reports the device as offline, so YouTube items render their offline view
/// instead of a WebView, which widget tests can't host.
void _mockOffline() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => call.method == 'check' ? <String>['none'] : null,
  );
}

void main() {
  group('KGallery caption params', () {
    test('default to captions off and no CC button', () {
      final gallery = KGallery(contentList: const [_youtubeA], initialIndex: 0);
      expect(gallery.youtubeCaptionsEnabled, isFalse);
      expect(gallery.youtubeCaptionLanguage, 'en');
      expect(gallery.showYoutubeCaptionToggle, isFalse);
    });

    testWidgets('KGallery.show forwards them', (tester) async {
      _mockOffline();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => KGallery.show(
                context,
                contentList: const [_youtubeA],
                initialIndex: 0,
                youtubeCaptionsEnabled: true,
                youtubeCaptionLanguage: 'es',
                showYoutubeCaptionToggle: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // A YouTube item's loader never settles, so pump past the transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final gallery = tester.widget<KGallery>(find.byType(KGallery));
      expect(gallery.youtubeCaptionsEnabled, isTrue);
      expect(gallery.youtubeCaptionLanguage, 'es');
      expect(gallery.showYoutubeCaptionToggle, isTrue);
    });
  });

  group('caption state threading', () {
    setUp(_mockOffline);

    Widget gallery({
      Key? key,
      bool enabled = false,
      String language = 'en',
      bool showToggle = false,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: KGallery(
              key: key,
              contentList: const [_youtubeA, _youtubeB],
              initialIndex: 0,
              youtubeCaptionsEnabled: enabled,
              youtubeCaptionLanguage: language,
              showYoutubeCaptionToggle: showToggle,
            ),
          ),
        );

    GalleryYoutubeItem youtubeItem(WidgetTester tester, int index) =>
        tester.widget<GalleryYoutubeItem>(
          find.byWidgetPredicate(
            (w) => w is GalleryYoutubeItem && w.index == index,
          ),
        );

    testWidgets('reaches the YouTube item', (tester) async {
      await tester.pumpWidget(
        gallery(enabled: true, language: 'pt-BR', showToggle: true),
      );
      // DeferredInit builds media items after 150 ms.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      final item = youtubeItem(tester, 0);
      expect(item.youtubeCaptionsNotifier.value, isTrue);
      expect(item.youtubeCaptionLanguage, 'pt-BR');
      expect(item.showYoutubeCaptionToggle, isTrue);
    });

    testWidgets('is shared across items and survives a swipe', (tester) async {
      await tester.pumpWidget(gallery());
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      final captions = youtubeItem(tester, 0).youtubeCaptionsNotifier;
      expect(captions.value, isFalse);
      // What the CC button does.
      captions.value = true;

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      // Page animation, then DeferredInit for the second item.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('2 / 2'), findsOneWidget);

      final second = youtubeItem(tester, 1).youtubeCaptionsNotifier;
      expect(second, same(captions));
      expect(second.value, isTrue);
    });

    testWidgets('a new gallery starts from youtubeCaptionsEnabled again', (
      tester,
    ) async {
      await tester.pumpWidget(gallery(key: const ValueKey(1)));
      await tester.pump(const Duration(milliseconds: 200));
      youtubeItem(tester, 0).youtubeCaptionsNotifier.value = true;

      await tester.pumpWidget(gallery(key: const ValueKey(2)));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(youtubeItem(tester, 0).youtubeCaptionsNotifier.value, isFalse);
    });

    testWidgets('follows a changed youtubeCaptionsEnabled on rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(gallery());
      final viewer = find.byType(GalleryImageViewer);
      final captions =
          tester.widget<GalleryImageViewer>(viewer).youtubeCaptionsNotifier;
      expect(captions.value, isFalse);

      await tester.pumpWidget(gallery(enabled: true));
      expect(captions.value, isTrue);
    });
  });

  group('GalleryYoutubeCaptionsButton', () {
    Widget button(ValueNotifier<bool> captions, VoidCallback onTap) =>
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GalleryYoutubeCaptionsButton(
                captionsEnabled: captions,
                onTap: onTap,
              ),
            ),
          ),
        );

    testWidgets('shows the state with icon and label, and reports taps', (
      tester,
    ) async {
      final captions = ValueNotifier(false);
      addTearDown(captions.dispose);
      var taps = 0;
      await tester.pumpWidget(button(captions, () => taps++));

      expect(find.byIcon(Icons.closed_caption_off), findsOneWidget);
      expect(find.bySemanticsLabel('Captions off'), findsOneWidget);

      await tester.tap(find.byType(GalleryYoutubeCaptionsButton));
      expect(taps, 1);

      captions.value = true;
      await tester.pump();
      expect(find.byIcon(Icons.closed_caption), findsOneWidget);
      expect(find.bySemanticsLabel('Captions on'), findsOneWidget);
    });
  });

  group('youtubeCaptionsScript', () {
    test('passes the state and language as JavaScript literals', () {
      expect(
        youtubeCaptionsScript(enabled: false, languageCode: 'en'),
        endsWith('})(false, "en");'),
      );
      expect(
        youtubeCaptionsScript(enabled: true, languageCode: 'pt-BR'),
        endsWith('})(true, "pt-BR");'),
      );
    });

    test('escapes the language code', () {
      final script = youtubeCaptionsScript(
        enabled: true,
        languageCode: 'x"); alert(1); ("',
      );
      expect(script, endsWith(r'})(true, "x\"); alert(1); (\"");'));
    });

    test('drives the IFrame captions module', () {
      final script = youtubeCaptionsScript(enabled: true, languageCode: 'en');
      expect(script, contains("player.loadModule('captions')"));
      expect(script, contains("player.unloadModule(cur || 'captions')"));
      expect(script, contains("player.setOption(m, 'track', track)"));
      expect(script, contains("addEventListener('onApiChange'"));
      expect(script, contains("addEventListener('onStateChange'"));
    });
  });
}
