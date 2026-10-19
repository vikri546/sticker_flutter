import 'package:flutter/material.dart';
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
    this.message = 'There are new features available, please update your app',
    this.isForceUpdate = false,
  });

  /// Check whether an update is available (current < latest).
  bool get hasUpdate => AppUpdateService.isVersionOlder(currentVersion, latestVersion);

  /// Check whether an update is strictly required (current < minRequired or explicitly forced).
  bool get requiresForceUpdate =>
      isForceUpdate || AppUpdateService.isVersionOlder(currentVersion, minRequiredVersion);
}

/// Service that handles app version comparison, remote check, and update launching.
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

  /// Show the non-dismissible Force Update dialog.
  static Future<void> showForceUpdateDialog(
    BuildContext context, {
    String title = 'New version available',
    String message = 'There are new features available, please update your app',
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
