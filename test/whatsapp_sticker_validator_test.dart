import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sticker_flutter/services/whatsapp_sticker_validator.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';

void main() {
  group('WhatsAppStickerValidator Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('validator_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Validates pack successfully when all WhatsApp requirements are met', () async {
      const packId = 'pack_valid';
      final packDir = Directory('${tempDir.path}/$packId');
      await packDir.create(recursive: true);

      // Create valid 96x96 tray icon
      final trayImage = img.Image(width: 96, height: 96);
      img.fill(trayImage, color: img.ColorRgb8(18, 140, 126));
      await File('${packDir.path}/tray.png').writeAsBytes(img.encodePng(trayImage));

      // Create 3 valid 512x512 WebP stickers
      final stickerItems = <StickerItem>[];
      for (int i = 1; i <= 3; i++) {
        final stickerImage = img.Image(width: 512, height: 512);
        img.fill(stickerImage, color: img.ColorRgb8(37, 211, 102));
        final fileName = 'sticker_$i.webp';
        await File('${packDir.path}/$fileName').writeAsBytes(img.encodeWebP(stickerImage));
        stickerItems.add(StickerItem(imageFileName: fileName, emojis: ['😀', '🔥']));
      }

      final pack = StickerPack(
        identifier: packId,
        name: 'Valid Pack',
        publisher: 'Test Author',
        trayImageFile: 'tray.png',
        stickers: stickerItems,
      );

      final result = await WhatsAppStickerValidator.validatePack(
        pack,
        stickersDirectoryPath: tempDir.path,
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('Fails validation if stickers count is less than 3', () async {
      final pack = const StickerPack(
        identifier: 'pack_insufficient',
        name: 'Insufficient Pack',
        stickers: [
          StickerItem(imageFileName: '1.webp'),
          StickerItem(imageFileName: '2.webp'),
        ],
      );

      final result = await WhatsAppStickerValidator.validatePack(
        pack,
        stickersDirectoryPath: tempDir.path,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('minimal 3 stiker')),
        isTrue,
      );
    });

    test('Fails validation if tray icon file is missing', () async {
      const packId = 'pack_no_tray';
      final packDir = Directory('${tempDir.path}/$packId');
      await packDir.create(recursive: true);

      final pack = const StickerPack(
        identifier: packId,
        name: 'No Tray Pack',
        trayImageFile: 'missing_tray.png',
        stickers: [
          StickerItem(imageFileName: '1.webp'),
          StickerItem(imageFileName: '2.webp'),
          StickerItem(imageFileName: '3.webp'),
        ],
      );

      final result = await WhatsAppStickerValidator.validatePack(
        pack,
        stickersDirectoryPath: tempDir.path,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('tray icon') && e.contains('tidak ditemukan')),
        isTrue,
      );
    });
  });
}
