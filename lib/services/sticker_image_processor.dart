import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Data class holding processed sticker details.
class ProcessedStickerResult {
  final Uint8List webpBytes;
  final int width;
  final int height;
  final int byteSize;

  const ProcessedStickerResult({
    required this.webpBytes,
    required this.width,
    required this.height,
    required this.byteSize,
  });

  /// Check if the result is valid according to WhatsApp sticker specifications.
  bool get isValid =>
      width == 512 && height == 512 && byteSize <= (100 * 1024);
}

/// Service that handles picking, resizing, padding, and WebP encoding for WhatsApp Stickers.
class StickerImageProcessor {
  static const int stickerDimension = 512;
  static const int maxFileSizeBytes = 100 * 1024; // 100 KB limit for static stickers
  static const int targetInnerBox = 480; // 512 - (16px margin * 2)

  static const int trayDimension = 96;
  static const int maxTrayFileSizeBytes = 50 * 1024; // 50 KB limit for tray icon

  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from device gallery or camera.
  static Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Process raw image bytes into compliant 512x512 WebP with transparent margins.
  /// Runs in background compute isolate to keep UI smooth and responsive.
  static Future<ProcessedStickerResult> processToStickerWebp(
    Uint8List sourceBytes,
  ) async {
    return await compute(_isolateProcessSticker, sourceBytes);
  }

  /// Background isolate processor function.
  static ProcessedStickerResult _isolateProcessSticker(Uint8List sourceBytes) {
    final original = img.decodeImage(sourceBytes);
    if (original == null) {
      throw Exception('Format gambar tidak dapat dibaca oleh sistem.');
    }

    // 1. Calculate proportional fit inside 480x480 box (leaving 16px transparent margin)
    int targetWidth;
    int targetHeight;
    if (original.width >= original.height) {
      targetWidth = targetInnerBox;
      targetHeight =
          (original.height * targetInnerBox / original.width).round();
    } else {
      targetHeight = targetInnerBox;
      targetWidth =
          (original.width * targetInnerBox / original.height).round();
    }

    if (targetWidth <= 0) targetWidth = 1;
    if (targetHeight <= 0) targetHeight = 1;

    final resized = img.copyResize(
      original,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // 2. Create 512x512 transparent canvas
    final canvas = img.Image(
      width: stickerDimension,
      height: stickerDimension,
      numChannels: 4,
    );

    // 3. Composite resized image centered inside the canvas
    final dstX = (stickerDimension - resized.width) ~/ 2;
    final dstY = (stickerDimension - resized.height) ~/ 2;
    img.compositeImage(canvas, resized, dstX: dstX, dstY: dstY);

    // 4. Encode to WebP under 100 KB
    int quality = 90;
    Uint8List webpBytes =
        Uint8List.fromList(img.encodeWebP(canvas, quality: quality));

    while (webpBytes.lengthInBytes >= maxFileSizeBytes && quality > 15) {
      quality -= 10;
      webpBytes =
          Uint8List.fromList(img.encodeWebP(canvas, quality: quality));
    }

    return ProcessedStickerResult(
      webpBytes: webpBytes,
      width: stickerDimension,
      height: stickerDimension,
      byteSize: webpBytes.lengthInBytes,
    );
  }

  /// Generate tray icon (96x96 PNG, under 50KB) from source image bytes.
  static Future<Uint8List> generateTrayIcon(Uint8List sourceBytes) async {
    return await compute(_isolateProcessTrayIcon, sourceBytes);
  }

  /// Background isolate tray icon generator.
  static Uint8List _isolateProcessTrayIcon(Uint8List sourceBytes) {
    final original = img.decodeImage(sourceBytes);
    if (original == null) {
      throw Exception('Format gambar tidak dapat dibaca.');
    }

    int targetWidth;
    int targetHeight;
    if (original.width >= original.height) {
      targetWidth = trayDimension;
      targetHeight =
          (original.height * trayDimension / original.width).round();
    } else {
      targetHeight = trayDimension;
      targetWidth =
          (original.width * trayDimension / original.height).round();
    }

    if (targetWidth <= 0) targetWidth = 1;
    if (targetHeight <= 0) targetHeight = 1;

    final resized = img.copyResize(
      original,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    final canvas = img.Image(
      width: trayDimension,
      height: trayDimension,
      numChannels: 4,
    );

    final dstX = (trayDimension - resized.width) ~/ 2;
    final dstY = (trayDimension - resized.height) ~/ 2;
    img.compositeImage(canvas, resized, dstX: dstX, dstY: dstY);

    return Uint8List.fromList(img.encodePng(canvas));
  }

  static Future<File> saveStickerFile({
    required String packDirectoryPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final packDir = Directory(packDirectoryPath);
    if (!packDir.existsSync()) {
      packDir.createSync(recursive: true);
    }

    final file = File('$packDirectoryPath/$fileName');
    file.writeAsBytesSync(bytes);
    return file;
  }
}
