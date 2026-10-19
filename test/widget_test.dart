import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_flutter/main.dart';

void main() {
  testWidgets('StickerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StickerApp());
    expect(find.text('Sticker Maker'), findsOneWidget);
  });
}
