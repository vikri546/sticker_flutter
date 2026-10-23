import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_flutter/services/backup_restore_service.dart';
import 'package:sticker_flutter/services/sticker_pack_manager.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory stickersDir;
  late Directory backupsDir;
  final manager = StickerPackManager();
  final service = BackupRestoreService();
  const channel = MethodChannel('com.pkri.sticko/stickers');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_service_test_');
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
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    manager.resetForTesting();
  });

  group('BackupRestoreService Tests', () {
    test('Throws exception when exporting with no packs', () async {
      await manager.initialize(customStickersDir: stickersDir.path, force: true);

      expect(
        () => service.exportBackupZip(
          customBackupDir: backupsDir.path,
          customStickersDir: stickersDir.path,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Exports packs to a valid ZIP archive with manifest and assets', () async {
      // 1. Create a dummy pack on disk
      final packDir = Directory('${stickersDir.path}/pack_animals')..createSync(recursive: true);
      File('${packDir.path}/tray.png').writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
      File('${packDir.path}/cat.webp').writeAsBytesSync(Uint8List.fromList([4, 5, 6]));
      File('${packDir.path}/dog.webp').writeAsBytesSync(Uint8List.fromList([7, 8, 9]));

      final testPack = const StickerPack(
        identifier: 'pack_animals',
        name: 'Hewan Lucu',
        publisher: 'Studio Sticko',
        trayImageFile: 'tray.png',
        stickers: [
          StickerItem(imageFileName: 'cat.webp', emojis: ['🐱']),
          StickerItem(imageFileName: 'dog.webp', emojis: ['🐶']),
        ],
      );

      await WhatsAppStickersService.saveContentsJson(
        [testPack],
        directoryPath: stickersDir.path,
      );
      await manager.initialize(customStickersDir: stickersDir.path, force: true);

      // 2. Export to ZIP
      final metadata = await service.exportBackupZip(
        customBackupDir: backupsDir.path,
        customStickersDir: stickersDir.path,
      );

      expect(metadata.packCount, equals(1));
      expect(metadata.stickerCount, equals(2));
      expect(File(metadata.filePath).existsSync(), isTrue);
      expect(metadata.fileName.endsWith('.zip'), isTrue);
      expect(metadata.formattedFileSize, isNotEmpty);
      expect(metadata.formattedDate, isNotEmpty);

      // 3. Inspect ZIP
      final inspection = await service.inspectBackupZip(
        metadata.filePath,
        currentPacks: [testPack],
      );

      expect(inspection.isValid, isTrue);
      expect(inspection.packs.length, equals(1));
      expect(inspection.packs.first.name, equals('Hewan Lucu'));
      expect(inspection.totalStickers, equals(2));
      expect(inspection.existingConflicts, contains('Hewan Lucu'));
      expect(inspection.formattedFileSize, isNotEmpty);

      // 4. List local backups
      final list = await service.getLocalBackups(customBackupDir: backupsDir.path);
      expect(list.length, equals(1));
      expect(list.first.fileName, equals(metadata.fileName));

      // 5. Delete backup
      final deleted = await service.deleteBackup(metadata.filePath);
      expect(deleted, isTrue);
      expect(File(metadata.filePath).existsSync(), isFalse);
    });

    test('Restores packs from ZIP with conflict copy / rename option', () async {
      // 1. Prepare export in temp
      final packDir = Directory('${stickersDir.path}/pack_orig')..createSync(recursive: true);
      File('${packDir.path}/tray.png').writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
      File('${packDir.path}/s1.webp').writeAsBytesSync(Uint8List.fromList([4, 5, 6]));

      final origPack = const StickerPack(
        identifier: 'pack_orig',
        name: 'Paket Asli',
        publisher: 'Sticko Author',
        trayImageFile: 'tray.png',
        stickers: [
          StickerItem(imageFileName: 's1.webp', emojis: ['🌟']),
        ],
      );

      await WhatsAppStickersService.saveContentsJson(
        [origPack],
        directoryPath: stickersDir.path,
      );
      await manager.initialize(customStickersDir: stickersDir.path, force: true);

      final metadata = await service.exportBackupZip(
        customBackupDir: backupsDir.path,
        customStickersDir: stickersDir.path,
      );

      // 2. Restore with overwriteConflicts = false (Creates a copy)
      final result = await service.restoreFromZip(
        zipFilePath: metadata.filePath,
        overwriteConflicts: false,
        customStickersDir: stickersDir.path,
      );

      expect(result.success, isTrue);
      expect(result.restoredPacksCount, equals(1));
      expect(result.restoredStickersCount, equals(1));

      // Manager should now have 2 packs (original + restored copy)
      expect(manager.packs.length, equals(2));
      expect(manager.packs.any((p) => p.name.contains('(Pulihan)')), isTrue);
    });
  });
}
