import 'package:flutter_test/flutter_test.dart';

import 'package:k_gallery/k_gallery.dart';

void main() {
  testWidgets('KGallery has a text', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: KGallery()));
    expect(find.text('KGallery Placeholder'), findsOneWidget);
  });
}
