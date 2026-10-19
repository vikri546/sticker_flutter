import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_flutter/services/sticker_pack_manager.dart';
import 'package:sticker_flutter/ui/screens/home_screen.dart';
import 'package:sticker_flutter/ui/screens/pack_detail_screen.dart';
import 'package:sticker_flutter/ui/widgets/create_pack_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  const channel = MethodChannel('com.example.sticker_flutter/stickers');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('flow_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getStickersDirectory':
          return tempDir.path;
        case 'checkWhatsAppInstalled':
          return {'whatsapp': true, 'whatsapp_business': false};
        case 'isStickerPackAdded':
          return false;
        case 'addStickerPack':
          return {'status': 'success', 'message': 'Pack added'};
        default:
          return null;
      }
    });

    final manager = StickerPackManager();
    manager.resetForTesting();
    await manager.initialize(customStickersDir: tempDir.path, force: true);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    StickerPackManager().resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('HomeScreen renders empty state and FAB', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    expect(find.text('Sticker Maker'), findsOneWidget);
    expect(find.text('Belum Ada Paket Stiker'), findsOneWidget);
    expect(find.text('Paket Baru'), findsOneWidget);
  });

  testWidgets('CreatePackDialog validates input and creates pack', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CreatePackDialog())));
    await tester.pump();

    expect(find.text('Buat Paket Stiker'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Stiker Test');
    await tester.pump();

    await tester.tap(find.text('Buat Paket'));
    await tester.pumpAndSettle();

    expect(StickerPackManager().packs.length, equals(1));
    expect(StickerPackManager().packs.first.name, equals('Stiker Test'));
  });

  testWidgets('PackDetailScreen correctly enforces WhatsApp min 3 rules in UI', (WidgetTester tester) async {
    final pack = await StickerPackManager().createPack(name: 'Paket Kucing', publisher: 'Budi');

    await tester.pumpWidget(MaterialApp(home: PackDetailScreen(packIdentifier: pack.identifier)));
    await tester.pump();

    // Verify header and disabled button
    expect(find.text('Paket Kucing'), findsOneWidget);
    expect(find.text('Oleh Budi'), findsOneWidget);
    expect(find.textContaining('minimal 3 stiker'), findsOneWidget);

    final buttonFinder = find.widgetWithText(
      ElevatedButton,
      'Butuh 3 Stiker Lagi untuk Simpan ke WA',
    );
    expect(buttonFinder, findsOneWidget);
    final button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNull); // Disabled!
  });
}
