import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sticker_flutter/services/sticker_image_processor.dart';
import 'package:sticker_flutter/services/whatsapp_sticker_validator.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';

/// Central state manager for sticker packs and local collection storage.
class StickerPackManager extends ChangeNotifier {
  static final StickerPackManager _instance = StickerPackManager._internal();
  factory StickerPackManager() => _instance;
  StickerPackManager._internal();

  List<StickerPack> _packs = [];
  bool _isLoading = false;
  String? _stickersDirectory;
  final Map<String, bool> _installedStatus = {};

  bool _isInitialized = false;

  List<StickerPack> get packs => List.unmodifiable(_packs);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get stickersDirectory => _stickersDirectory;

  /// Reset manager state for tests
  @visibleForTesting
  void resetForTesting() {
    _packs = [];
    _installedStatus.clear();
    _isInitialized = false;
    _isLoading = false;
    _stickersDirectory = null;
  }

  /// Check whether a pack is currently installed in WhatsApp.
  bool isPackInstalled(String packIdentifier) =>
      _installedStatus[packIdentifier] ?? false;

  /// Get the absolute file path for a sticker image in a pack.
  String? getStickerFilePath(String packIdentifier, String fileName) {
    if (_stickersDirectory == null) return null;
    return '$_stickersDirectory/$packIdentifier/$fileName';
  }

  /// Get the absolute file path for a pack's tray icon.
  String? getTrayFilePath(String packIdentifier, String trayFileName) {
    if (_stickersDirectory == null) return null;
    return '$_stickersDirectory/$packIdentifier/$trayFileName';
  }

  /// Initialize manager, resolve stickers directory, and load existing packs.
  Future<void> initialize({String? customStickersDir, bool force = false}) async {
    if (_isInitialized && !force) return;
    _isLoading = true;
    notifyListeners();

    try {
      _stickersDirectory = customStickersDir ??
          await WhatsAppStickersService.getStickersDirectory();
      _packs = await WhatsAppStickersService.loadContentsJson(
        directoryPath: _stickersDirectory,
      );
      await refreshInstalledStatuses();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing StickerPackManager: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh installation status for all packs from WhatsApp.
  Future<void> refreshInstalledStatuses() async {
    for (final pack in _packs) {
      try {
        final isAdded =
            await WhatsAppStickersService.isStickerPackAdded(pack.identifier);
        _installedStatus[pack.identifier] = isAdded;
      } catch (_) {
        _installedStatus[pack.identifier] = false;
      }
    }
    notifyListeners();
  }

  /// Create a new sticker pack.
  Future<StickerPack> createPack({
    required String name,
    String publisher = 'Sticker Maker',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final identifier = 'pack_$timestamp';

    final dirPath = _stickersDirectory ??
        await WhatsAppStickersService.getStickersDirectory();
    final packDir = Directory('$dirPath/$identifier');
    if (!packDir.existsSync()) {
      packDir.createSync(recursive: true);
    }

    final newPack = StickerPack(
      identifier: identifier,
      name: name.trim().isEmpty ? 'Koleksi Stiker Baru' : name.trim(),
      publisher: publisher.trim().isEmpty ? 'Sticker Maker' : publisher.trim(),
      trayImageFile: 'tray.png',
      imageDataVersion: '1',
      stickers: const [],
    );

    _packs = [..._packs, newPack];
    await _savePacks();
    notifyListeners();
    return newPack;
  }

  /// Add a sticker from raw image bytes into an existing pack.
  Future<StickerItem> addStickerToPack({
    required String packIdentifier,
    required Uint8List imageBytes,
    List<String> emojis = const ['😀'],
  }) async {
    final packIndex = _packs.indexWhere((p) => p.identifier == packIdentifier);
    if (packIndex == -1) {
      throw Exception('Paket stiker dengan ID $packIdentifier tidak ditemukan.');
    }

    final currentPack = _packs[packIndex];
    if (currentPack.stickers.length >= 30) {
      throw Exception('Paket stiker sudah mencapai batas maksimal 30 stiker.');
    }

    final dirPath = _stickersDirectory ??
        await WhatsAppStickersService.getStickersDirectory();
    final packDirPath = '$dirPath/$packIdentifier';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'sticker_$timestamp.webp';

    // 1. Process image to compliant 512x512 WebP (< 100 KB)
    final processed =
        await StickerImageProcessor.processToStickerWebp(imageBytes);
    await StickerImageProcessor.saveStickerFile(
      packDirectoryPath: packDirPath,
      fileName: fileName,
      bytes: processed.webpBytes,
    );

    // 2. Generate tray icon from this sticker if it doesn't exist yet
    final trayFile = File('$packDirPath/tray.png');
    if (!trayFile.existsSync()) {
      final trayBytes =
          await StickerImageProcessor.generateTrayIcon(imageBytes);
      trayFile.writeAsBytesSync(trayBytes);
    }

    // 3. Increment image_data_version for WhatsApp update sync
    final currentVersion = int.tryParse(currentPack.imageDataVersion) ?? 1;
    final newVersion = (currentVersion + 1).toString();

    final newSticker = StickerItem(imageFileName: fileName, emojis: emojis);
    final updatedPack = currentPack.copyWith(
      imageDataVersion: newVersion,
      stickers: [...currentPack.stickers, newSticker],
    );

    _packs[packIndex] = updatedPack;
    await _savePacks();
    notifyListeners();
    return newSticker;
  }

  /// Remove a sticker from a pack and delete its file.
  Future<void> removeStickerFromPack({
    required String packIdentifier,
    required String fileName,
  }) async {
    final packIndex = _packs.indexWhere((p) => p.identifier == packIdentifier);
    if (packIndex == -1) return;

    final currentPack = _packs[packIndex];
    final dirPath = _stickersDirectory ??
        await WhatsAppStickersService.getStickersDirectory();
    final file = File('$dirPath/$packIdentifier/$fileName');
    if (file.existsSync()) {
      file.deleteSync();
    }

    final currentVersion = int.tryParse(currentPack.imageDataVersion) ?? 1;
    final newVersion = (currentVersion + 1).toString();

    final updatedStickers = currentPack.stickers
        .where((s) => s.imageFileName != fileName)
        .toList();

    _packs[packIndex] = currentPack.copyWith(
      imageDataVersion: newVersion,
      stickers: updatedStickers,
    );

    await _savePacks();
    notifyListeners();
  }

  /// Delete an entire pack and all its associated files.
  Future<void> deletePack(String packIdentifier) async {
    final dirPath = _stickersDirectory ??
        await WhatsAppStickersService.getStickersDirectory();
    final packDir = Directory('$dirPath/$packIdentifier');
    if (packDir.existsSync()) {
      packDir.deleteSync(recursive: true);
    }

    _packs.removeWhere((p) => p.identifier == packIdentifier);
    _installedStatus.remove(packIdentifier);
    await _savePacks();
    notifyListeners();
  }

  /// Send or update the pack in WhatsApp.
  Future<Map<String, dynamic>> sendPackToWhatsApp(
    String packIdentifier, {
    bool isBusiness = false,
  }) async {
    final pack = getPack(packIdentifier);
    if (pack == null) {
      return {'status': 'error', 'message': 'Paket stiker tidak ditemukan'};
    }

    if (!pack.canAddToWhatsApp) {
      return {
        'status': 'error',
        'message':
            'Syarat minimal 3 stiker belum terpenuhi (kurang ${pack.remainingStickersNeeded} stiker lagi)',
      };
    }

    final dirPath = _stickersDirectory ??
        await WhatsAppStickersService.getStickersDirectory();

    // Pre-flight validation against official WhatsApp rules
    final validation = await WhatsAppStickerValidator.validatePack(
      pack,
      stickersDirectoryPath: dirPath,
    );
    if (!validation.isValid) {
      return {
        'status': 'error',
        'message': validation.errors.first,
      };
    }

    final result = await WhatsAppStickersService.addStickerPack(
      identifier: pack.identifier,
      name: pack.name,
      isBusiness: isBusiness,
    );

    if (result['status'] == 'success') {
      _installedStatus[pack.identifier] = true;
      notifyListeners();
    }

    return result;
  }

  /// Get pack by identifier.
  StickerPack? getPack(String identifier) {
    try {
      return _packs.firstWhere((p) => p.identifier == identifier);
    } catch (_) {
      return null;
    }
  }

  /// Save packs to contents.json.
  Future<void> _savePacks() async {
    await WhatsAppStickersService.saveContentsJson(
      _packs,
      directoryPath: _stickersDirectory,
    );
  }
}
