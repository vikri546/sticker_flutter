import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_flutter/services/backup_restore_service.dart';
import 'package:sticker_flutter/services/creator_profile_service.dart';
import 'package:sticker_flutter/services/sticker_pack_manager.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';
import 'package:sticker_flutter/ui/screens/account_screen.dart';
import 'package:sticker_flutter/ui/screens/cloud_backup_screen.dart';
import 'package:sticker_flutter/ui/widgets/app_notification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory stickersDir;
  late Directory backupsDir;
  final manager = StickerPackManager();
  const channel = MethodChannel('com.pkri.sticko/stickers');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cloud_backup_widget_test_');
    stickersDir = Directory('${tempDir.path}/stickers')..createSync(recursive: true);
    backupsDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getStickersDirectory':
          return stickersDir.path;
        case 'checkWhatsAppInstalled':
          return {'whatsapp': true, 'whatsapp_business': false};
        case 'isStickerPackAdded':
          return false;
        default:
          return null;
      }
    });

    manager.resetForTesting();
    CreatorProfileService().resetForTesting(customDir: tempDir.path);
    BackupRestoreService().resetForTesting(customDir: backupsDir.path);
  });

  tearDown(() async {
    AppNotification.dismiss();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    manager.resetForTesting();
    BackupRestoreService().resetForTesting();
  });

  group('CloudBackupScreen & Account Navigation Tests', () {
    test('CloudBackupScreen.route() provides zoom in/out ScaleTransition', () {
      final route = CloudBackupScreen.route();
      expect(route, isA<PageRouteBuilder<void>>());

      final pageRoute = route as PageRouteBuilder<void>;
      expect(pageRoute.transitionDuration, const Duration(milliseconds: 300));
      expect(pageRoute.reverseTransitionDuration, const Duration(milliseconds: 250));
    });

    testWidgets('Tapping Cadangan & Pemulihan Cloud navigates to CloudBackupScreen', (
      WidgetTester tester,
    ) async {
      await manager.initialize(customStickersDir: stickersDir.path, force: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const AccountScreen(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();

      // Check tile in PENGATURAN SISTEM
      expect(find.text('Cadangan & Pemulihan Cloud'), findsOneWidget);
      expect(find.text('Ekspor ZIP, simpan cadangan, & pulihkan stiker'), findsOneWidget);

      // Tap to navigate
      await tester.tap(find.text('Cadangan & Pemulihan Cloud'));
      await tester.pumpAndSettle();

      // Verify CloudBackupScreen is open
      expect(find.text('Cadangan & Cloud'), findsOneWidget);
      expect(find.text('Sticko Cloud & Export'), findsOneWidget);
      expect(find.text('Ekspor Seluruh Paket (.ZIP)'), findsOneWidget);
      expect(find.text('Impor & Pulihkan Stiker'), findsOneWidget);
      expect(find.text('Belum Ada File Cadangan'), findsOneWidget);
    });

    testWidgets('Exports packs and renders in local backups list', (
      WidgetTester tester,
    ) async {
      // Create a test pack
      final packDir = Directory('${stickersDir.path}/pack_fun')..createSync(recursive: true);
      File('${packDir.path}/tray.png').writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
      File('${packDir.path}/f1.webp').writeAsBytesSync(Uint8List.fromList([4, 5, 6]));

      final testPack = const StickerPack(
        identifier: 'pack_fun',
        name: 'Fun Stickers',
        publisher: 'Sticko Fun',
        trayImageFile: 'tray.png',
        stickers: [
          StickerItem(imageFileName: 'f1.webp', emojis: ['🎉']),
        ],
      );

      await WhatsAppStickersService.saveContentsJson(
        [testPack],
        directoryPath: stickersDir.path,
      );
      await manager.initialize(customStickersDir: stickersDir.path, force: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: CloudBackupScreen(
            customBackupDir: backupsDir.path,
            customStickersDir: stickersDir.path,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify stats
      expect(find.text('1 Paket • 1 Stiker siap dicadangkan'), findsOneWidget);

      // Tap export button
      await tester.tap(find.byKey(const Key('cloud_export_button')));
      await tester.pump();

      // Pump until export finishes and dialog appears
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.text('Ekspor Cadangan Berhasil!').evaluate().isNotEmpty) {
          break;
        }
      }

      // Export success dialog should appear
      expect(find.text('Ekspor Cadangan Berhasil!'), findsOneWidget);
      expect(find.text('Buka File'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();

      // Backup should now be listed
      expect(find.text('Pulihkan'), findsOneWidget);
      expect(find.byIcon(Icons.folder_zip_rounded), findsWidgets);

      AppNotification.dismiss();
      await tester.pump();
    });
  });
}
