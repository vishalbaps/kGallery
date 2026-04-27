import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_gallery/k_gallery.dart';

void main() {
  testWidgets('KGallery displays the correct initial image', (WidgetTester tester) async {
    // Define dummy content
    final contentList = [
      const GalleryItem(
        url: 'https://example.com/image1.jpg',
        title: 'Image 1',
        description: 'Description 1',
      ),
      const GalleryItem(
        url: 'https://example.com/image2.jpg',
        title: 'Image 2',
        description: 'Description 2',
      ),
    ];

    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KGallery(
            contentList: contentList,
            initialIndex: 0,
          ),
        ),
      ),
    );

    // Verify initial state
    expect(find.text('Image 1'), findsOneWidget);
    expect(find.text('Description 1'), findsOneWidget);
    
    // Verify it doesn't show the second item yet
    expect(find.text('Image 2'), findsNothing);
  });

  testWidgets('KGallery throws assertion error on empty list', (WidgetTester tester) async {
    expect(
      () => KGallery(contentList: const [], initialIndex: 0),
      throwsAssertionError,
    );
  });
}
