import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';

void main() {
  group('StickerPack WhatsApp Rule Tests', () {
    test('Pack with less than 3 stickers cannot be added to WhatsApp', () {
      final pack0 = const StickerPack(
        identifier: 'pack_test',
        name: 'Test Pack',
        stickers: [],
      );
      expect(pack0.canAddToWhatsApp, isFalse);
      expect(pack0.remainingStickersNeeded, equals(3));

      final pack1 = pack0.copyWith(
        stickers: [
          const StickerItem(imageFileName: 's1.webp'),
        ],
      );
      expect(pack1.canAddToWhatsApp, isFalse);
      expect(pack1.remainingStickersNeeded, equals(2));

      final pack2 = pack0.copyWith(
        stickers: [
          const StickerItem(imageFileName: 's1.webp'),
          const StickerItem(imageFileName: 's2.webp'),
        ],
      );
      expect(pack2.canAddToWhatsApp, isFalse);
      expect(pack2.remainingStickersNeeded, equals(1));
    });

    test('Pack with 3 to 30 stickers can be added to WhatsApp', () {
      final stickers3 = List.generate(
        3,
        (i) => StickerItem(imageFileName: 's$i.webp', emojis: ['😀']),
      );
      final pack3 = StickerPack(
        identifier: 'pack_test',
        name: 'Test Pack',
        stickers: stickers3,
      );
      expect(pack3.canAddToWhatsApp, isTrue);
      expect(pack3.remainingStickersNeeded, equals(0));

      final stickers30 = List.generate(
        30,
        (i) => StickerItem(imageFileName: 's$i.webp'),
      );
      final pack30 = StickerPack(
        identifier: 'pack_test',
        name: 'Test Pack',
        stickers: stickers30,
      );
      expect(pack30.canAddToWhatsApp, isTrue);

      final stickers31 = List.generate(
        31,
        (i) => StickerItem(imageFileName: 's$i.webp'),
      );
      final pack31 = StickerPack(
        identifier: 'pack_test',
        name: 'Test Pack',
        stickers: stickers31,
      );
      expect(pack31.canAddToWhatsApp, isFalse);
    });

    test('StickerPack serializes and deserializes correctly matching WhatsApp schema', () {
      final pack = StickerPack(
        identifier: 'sample_pack',
        name: 'Sample Name',
        publisher: 'Sample Publisher',
        trayImageFile: 'tray.png',
        imageDataVersion: '2',
        stickers: [
          const StickerItem(imageFileName: '1.webp', emojis: ['🔥', '🎉']),
          const StickerItem(imageFileName: '2.webp', emojis: ['👍']),
          const StickerItem(imageFileName: '3.webp', emojis: ['❤️']),
        ],
      );

      final jsonMap = pack.toJson();
      final jsonString = jsonEncode(jsonMap);
      final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final restoredPack = StickerPack.fromJson(decodedMap);

      expect(restoredPack.identifier, equals('sample_pack'));
      expect(restoredPack.name, equals('Sample Name'));
      expect(restoredPack.publisher, equals('Sample Publisher'));
      expect(restoredPack.trayImageFile, equals('tray.png'));
      expect(restoredPack.imageDataVersion, equals('2'));
      expect(restoredPack.stickers.length, equals(3));
      expect(restoredPack.stickers[0].emojis, equals(['🔥', '🎉']));
      expect(restoredPack.canAddToWhatsApp, isTrue);
    });
  });
}
