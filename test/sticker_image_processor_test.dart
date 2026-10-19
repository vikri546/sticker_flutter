import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sticker_flutter/services/sticker_image_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('StickerImageProcessor produces compliant 512x512 WebP under 100KB', () async {
    // 1. Create a dummy test image (800x600 RGB image)
    final testImage = img.Image(width: 800, height: 600);
    img.fill(testImage, color: img.ColorRgb8(255, 100, 50));
    final pngBytes = img.encodePng(testImage);

    // 2. Process to WhatsApp sticker
    final result = await StickerImageProcessor.processToStickerWebp(pngBytes);

    // 3. Verify WhatsApp specifications
    expect(result.width, equals(512));
    expect(result.height, equals(512));
    expect(result.byteSize, lessThanOrEqualTo(100 * 1024));
    expect(result.isValid, isTrue);

    // 4. Verify decoded WebP dimensions
    final decodedWebp = img.decodeWebP(result.webpBytes);
    expect(decodedWebp, isNotNull);
    expect(decodedWebp!.width, equals(512));
    expect(decodedWebp.height, equals(512));
  });

  test('StickerImageProcessor produces compliant 96x96 Tray Icon under 50KB', () async {
    final testImage = img.Image(width: 400, height: 400);
    img.fill(testImage, color: img.ColorRgb8(50, 150, 255));
    final pngBytes = img.encodePng(testImage);

    final trayBytes = await StickerImageProcessor.generateTrayIcon(pngBytes);

    expect(trayBytes.lengthInBytes, lessThanOrEqualTo(50 * 1024));
    final decodedTray = img.decodePng(trayBytes);
    expect(decodedTray, isNotNull);
    expect(decodedTray!.width, equals(96));
    expect(decodedTray.height, equals(96));
  });
}
