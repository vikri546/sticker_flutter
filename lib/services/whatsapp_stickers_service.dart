import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Model representing a single sticker item in a pack.
class StickerItem {
  final String imageFileName;
  final List<String> emojis;

  const StickerItem({
    required this.imageFileName,
    this.emojis = const ['😀'],
  });

  Map<String, dynamic> toJson() => {
        'image_file': imageFileName,
        'emojis': emojis,
      };

  factory StickerItem.fromJson(Map<String, dynamic> json) {
    return StickerItem(
      imageFileName: json['image_file'] as String,
      emojis: (json['emojis'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['😀'],
    );
  }
}

/// Model representing a WhatsApp sticker pack.
class StickerPack {
  final String identifier;
  final String name;
  final String publisher;
  final String trayImageFile;
  final String imageDataVersion;
  final bool avoidCache;
  final bool animatedStickerPack;
  final List<StickerItem> stickers;

  const StickerPack({
    required this.identifier,
    required this.name,
    this.publisher = 'Sticker Maker',
    this.trayImageFile = 'tray.png',
    this.imageDataVersion = '1',
    this.avoidCache = false,
    this.animatedStickerPack = false,
    this.stickers = const [],
  });

  bool get canAddToWhatsApp => stickers.length >= 3 && stickers.length <= 30;

  int get remainingStickersNeeded =>
      stickers.length < 3 ? 3 - stickers.length : 0;

  StickerPack copyWith({
    String? identifier,
    String? name,
    String? publisher,
    String? trayImageFile,
    String? imageDataVersion,
    bool? avoidCache,
    bool? animatedStickerPack,
    List<StickerItem>? stickers,
  }) {
    return StickerPack(
      identifier: identifier ?? this.identifier,
      name: name ?? this.name,
      publisher: publisher ?? this.publisher,
      trayImageFile: trayImageFile ?? this.trayImageFile,
      imageDataVersion: imageDataVersion ?? this.imageDataVersion,
      avoidCache: avoidCache ?? this.avoidCache,
      animatedStickerPack: animatedStickerPack ?? this.animatedStickerPack,
      stickers: stickers ?? this.stickers,
    );
  }

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'name': name,
        'publisher': publisher,
        'tray_image_file': trayImageFile,
        'image_data_version': imageDataVersion,
        'avoid_cache': avoidCache,
        'animated_sticker_pack': animatedStickerPack,
        'stickers': stickers.map((s) => s.toJson()).toList(),
      };

  factory StickerPack.fromJson(Map<String, dynamic> json) {
    return StickerPack(
      identifier: json['identifier'] as String,
      name: json['name'] as String,
      publisher: json['publisher'] as String? ?? 'Sticker Maker',
      trayImageFile: json['tray_image_file'] as String? ?? 'tray.png',
      imageDataVersion: json['image_data_version'] as String? ?? '1',
      avoidCache: json['avoid_cache'] as bool? ?? false,
      animatedStickerPack: json['animated_sticker_pack'] as bool? ?? false,
      stickers: (json['stickers'] as List<dynamic>?)
              ?.map((s) => StickerItem.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Service that communicates directly with Android native WhatsApp Sticker Protocol via MethodChannel.
class WhatsAppStickersService {
  static const MethodChannel _channel =
      MethodChannel('com.example.sticker_flutter/stickers');

  /// Get the directory path where sticker packs and files must be saved.
  static Future<String> getStickersDirectory() async {
    final String? path =
        await _channel.invokeMethod<String>('getStickersDirectory');
    if (path == null) {
      throw Exception('Failed to resolve stickers directory path');
    }
    return path;
  }

  /// Check whether standard WhatsApp and/or WhatsApp Business are installed on the device.
  static Future<Map<String, bool>> checkWhatsAppInstalled() async {
    final Map<dynamic, dynamic>? result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('checkWhatsAppInstalled');
    return {
      'whatsapp': result?['whatsapp'] == true,
      'whatsapp_business': result?['whatsapp_business'] == true,
    };
  }

  /// Check if a specific sticker pack is already added/whitelisted in WhatsApp.
  static Future<bool> isStickerPackAdded(
    String identifier, {
    bool isBusiness = false,
  }) async {
    final bool? isAdded = await _channel.invokeMethod<bool>(
      'isStickerPackAdded',
      {
        'identifier': identifier,
        'isBusiness': isBusiness,
      },
    );
    return isAdded ?? false;
  }

  /// Launch intent to add the sticker pack to WhatsApp.
  /// Returns a map with 'status' ('success', 'error', 'cancelled') and 'message'.
  static Future<Map<String, dynamic>> addStickerPack({
    required String identifier,
    required String name,
    bool isBusiness = false,
  }) async {
    final Map<dynamic, dynamic>? result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'addStickerPack',
      {
        'identifier': identifier,
        'name': name,
        'isBusiness': isBusiness,
      },
    );

    return {
      'status': result?['status'] ?? 'error',
      'message': result?['message'] ?? 'Unknown error occurred',
    };
  }

  /// Save or update the `contents.json` metadata file in the stickers directory.
  /// This file is read by [StickerContentProvider] whenever WhatsApp queries the app.
  static Future<void> saveContentsJson(
    List<StickerPack> packs, {
    String? directoryPath,
  }) async {
    final stickersDirPath = directoryPath ?? await getStickersDirectory();
    final file = File('$stickersDirPath/contents.json');
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final data = {
      'android_play_store_link': '',
      'ios_app_store_link': '',
      'sticker_packs': packs.map((p) => p.toJson()).toList(),
    };

    file.writeAsStringSync(jsonEncode(data));
  }

  /// Read the `contents.json` file if it exists, returning the list of saved packs.
  static Future<List<StickerPack>> loadContentsJson({
    String? directoryPath,
  }) async {
    try {
      final stickersDirPath = directoryPath ?? await getStickersDirectory();
      final file = File('$stickersDirPath/contents.json');
      if (!file.existsSync()) {
        return [];
      }
      final content = file.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final packsJson = data['sticker_packs'] as List<dynamic>? ?? [];
      return packsJson
          .map((p) => StickerPack.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
