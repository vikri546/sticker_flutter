import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sticker_flutter/ui/widgets/force_update_dialog.dart';

/// Information regarding app versioning and update requirements.
class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String minRequiredVersion;
  final String updateUrl;
  final String title;
  final String message;
  final bool isForceUpdate;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.updateUrl,
    this.title = 'New version available',
    this.message = 'There are new features available,\nplease update your app',
    this.isForceUpdate = false,
  });

  /// Check whether an update is available (current < latest).
  bool get hasUpdate => AppUpdateService.isVersionOlder(currentVersion, latestVersion);

  /// Check whether an update is strictly required (current < minRequired or explicitly forced).
  bool get requiresForceUpdate =>
      isForceUpdate || AppUpdateService.isVersionOlder(currentVersion, minRequiredVersion);
}

/// Service that handles app version comparison, remote check, and APK download & installation.
class AppUpdateService {
  static const String defaultCurrentVersion = '1.0.0';
  static const String defaultStoreUrl =
      'https://play.google.com/store/apps/details?id=com.example.sticker_flutter';

  /// Compare two semantic version strings (e.g., '1.0.0' vs '1.1.0').
  /// Returns `true` if [current] is strictly older than [target].
  static bool isVersionOlder(String current, String target) {
    try {
      // Clean build numbers (+1, etc.)
      final cleanCurrent = current.split('+').first.trim();
      final cleanTarget = target.split('+').first.trim();

      final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final targetParts = cleanTarget.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = currentParts.length > targetParts.length ? currentParts.length : targetParts.length;

      for (int i = 0; i < maxLength; i++) {
        final cur = i < currentParts.length ? currentParts[i] : 0;
        final tar = i < targetParts.length ? targetParts[i] : 0;
        if (cur < tar) return true;
        if (cur > tar) return false;
      }

      // If semantic versions match, compare build numbers if available
      final curBuild = int.tryParse(current.contains('+') ? current.split('+').last : '0') ?? 0;
      final tarBuild = int.tryParse(target.contains('+') ? target.split('+').last : '0') ?? 0;
      return curBuild < tarBuild;
    } catch (_) {
      return false;
    }
  }

  /// Launch the update URL in the browser or Google Play Store.
  static Future<bool> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching update URL: $e');
    }
    return false;
  }

  /// Download the APK directly and trigger Android Package Installer on completion.
  /// Calls [onProgress] with values ranging from 0.0 to 1.0.
  static Future<void> downloadAndInstallApk({
    required String apkUrl,
    required void Function(double progress) onProgress,
  }) async {
    // If in demo/test mode with a non-direct URL, simulate download progress
    if (apkUrl.isEmpty ||
        apkUrl == defaultStoreUrl ||
        apkUrl.endsWith('.test') ||
        !apkUrl.endsWith('.apk')) {
      for (int i = 1; i <= 20; i++) {
        await Future.delayed(const Duration(milliseconds: 60));
        onProgress(i / 20.0);
      }
      return;
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final request = await client.getUrl(Uri.parse(apkUrl));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Server mengembalikan kode status ${response.statusCode}');
    }

    final contentLength = response.contentLength;
    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}/app_update.apk';
    final file = File(savePath);
    if (file.existsSync()) {
      file.deleteSync();
    }

    final sink = file.openWrite();
    int received = 0;

    await for (final chunk in response) {
      received += chunk.length;
      sink.add(chunk);
      if (contentLength > 0) {
        onProgress((received / contentLength).clamp(0.0, 1.0));
      }
    }

    await sink.flush();
    await sink.close();
    onProgress(1.0);

    // Trigger Android package installer prompt automatically
    final result = await OpenFilex.open(
      savePath,
      type: 'application/vnd.android.package-archive',
    );

    if (result.type != ResultType.done) {
      debugPrint('Hasil eksekusi installer: ${result.message}');
    }
  }

  /// Show the non-dismissible Force Update dialog.
  static Future<void> showForceUpdateDialog(
    BuildContext context, {
    String title = 'New version available',
    String message = 'There are new features available,\nplease update your app',
    String updateUrl = defaultStoreUrl,
    VoidCallback? onUpdatePressed,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(120),
      builder: (ctx) => ForceUpdateDialog(
        title: title,
        message: message,
        updateUrl: updateUrl,
        onUpdatePressed: onUpdatePressed,
      ),
    );
  }
}
