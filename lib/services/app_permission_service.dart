import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sticker_flutter/ui/widgets/permission_dialogs.dart';

/// Enum defining permission types handled by the application.
enum AppPermissionType {
  camera,
  gallery,
  notification,
  installPackages,
}

/// Model encapsulating information and status about a single permission.
class AppPermissionItem {
  final AppPermissionType type;
  final String title;
  final String description;
  final IconData icon;
  final PermissionStatus status;
  final bool isEssential;

  const AppPermissionItem({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    this.isEssential = false,
  });

  bool get isGrantedOrLimited => status.isGranted || status.isLimited;

  String get statusLabel {
    if (status.isGranted) return 'Diizinkan';
    if (status.isLimited) return 'Akses Terbatas (Android 14+)';
    if (status.isPermanentlyDenied) return 'Ditolak Permanen';
    if (status.isRestricted) return 'Dibatasi Sistem';
    return 'Belum Diizinkan';
  }

  Color get statusColor {
    if (status.isGranted) return const Color(0xFF25D366);
    if (status.isLimited) return const Color(0xFF0288D1);
    if (status.isPermanentlyDenied) return const Color(0xFFE53935);
    if (status.isRestricted) return const Color(0xFFFB8C00);
    return Colors.grey;
  }
}

/// Service managing Android permissions, rationale dialogs, and platform compatibility.
class AppPermissionService {
  static final AppPermissionService _instance = AppPermissionService._internal();
  factory AppPermissionService() => _instance;
  AppPermissionService._internal();

  /// Visible constructor for subclassing or mocking in tests.
  @visibleForTesting
  AppPermissionService.custom();

  /// Check whether the platform requires runtime permission management.
  bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Check status of camera permission.
  Future<PermissionStatus> checkCameraStatus() async {
    if (!isMobile) return PermissionStatus.granted;
    try {
      return await Permission.camera.status;
    } catch (_) {
      return PermissionStatus.granted;
    }
  }

  /// Request camera permission with rationale and permanently denied guidance.
  /// Returns `true` if permission is granted or limited, `false` otherwise.
  Future<bool> requestCameraPermission(
    BuildContext context, {
    bool showRationale = true,
  }) async {
    if (!isMobile) return true;

    final initialStatus = await Permission.camera.status;

    if (initialStatus.isGranted || initialStatus.isLimited) {
      return true;
    }

    if (initialStatus.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermanentlyDeniedDialog(
          context,
          title: 'Izin Kamera Diblokir',
          description:
              'Akses kamera dinonaktifkan secara permanen di setelan sistem. Aktifkan izin kamera untuk memotret objek stiker secara langsung.',
        );
      }
      return false;
    }

    // Show educational rationale if requested and denied
    if (showRationale && context.mounted) {
      final proceed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const PermissionRationaleSheet(
          title: 'Izin Kamera Diperlukan',
          description:
              'Sticker Maker membutuhkan izin kamera agar kamu bisa mengambil foto wajah atau objek secara langsung dan mengubahnya menjadi stiker WhatsApp.',
          icon: Icons.camera_alt_rounded,
          benefitItems: [
            'Memotret langsung ekspresi seru untuk dijadikan stiker',
            'Otomatis disesuaikan ke format stiker WhatsApp (512x512)',
            'Foto kamu tidak diunggah ke server pihak ketiga mana pun',
          ],
        ),
      );

      if (proceed != true) return false;
    }

    final newStatus = await Permission.camera.request();

    if (newStatus.isGranted || newStatus.isLimited) {
      return true;
    }

    if (newStatus.isPermanentlyDenied && context.mounted) {
      await _showPermanentlyDeniedDialog(
        context,
        title: 'Izin Kamera Diblokir',
        description:
            'Akses kamera dinonaktifkan di setelan sistem. Buka Pengaturan untuk mengaktifkan izin kamera.',
      );
    }

    return false;
  }

  /// Check status of photos/gallery permission.
  /// Handles Android 13+ [Permission.photos] and Android 12- [Permission.storage].
  Future<PermissionStatus> checkGalleryStatus() async {
    if (!isMobile) return PermissionStatus.granted;

    try {
      // First check photos (Android 13+ & iOS)
      final photosStatus = await Permission.photos.status;
      if (photosStatus.isGranted || photosStatus.isLimited) {
        return photosStatus;
      }

      // Fallback check storage for Android 12 and below
      if (isAndroid) {
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted || storageStatus.isLimited) {
          return storageStatus;
        }
        if (photosStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
          return PermissionStatus.permanentlyDenied;
        }
      }

      return photosStatus;
    } catch (_) {
      return PermissionStatus.granted;
    }
  }

  /// Request gallery/photos permission with rationale.
  Future<bool> requestGalleryPermission(
    BuildContext context, {
    bool showRationale = true,
  }) async {
    if (!isMobile) return true;

    final currentStatus = await checkGalleryStatus();
    if (currentStatus.isGranted || currentStatus.isLimited) {
      return true;
    }

    if (currentStatus.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermanentlyDeniedDialog(
          context,
          title: 'Izin Galeri Foto Diblokir',
          description:
              'Akses galeri dinonaktifkan secara permanen di setelan sistem. Aktifkan izin media/foto agar kamu dapat memilih foto untuk stiker.',
        );
      }
      return false;
    }

    if (showRationale && context.mounted) {
      final proceed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const PermissionRationaleSheet(
          title: 'Akses Foto & Galeri',
          description:
              'Sticker Maker membutuhkan izin akses foto untuk membuka galeri perangkat kamu dan memilih gambar yang ingin diubah menjadi stiker.',
          icon: Icons.photo_library_rounded,
          benefitItems: [
            'Pilih foto kenangan atau meme langsung dari galeri HP',
            'Mendukung akses foto penuh atau foto pilihan (Android 14+)',
            'Privasi terjaga, hanya foto pilihanmu yang diproses lokal di HP',
          ],
        ),
      );

      if (proceed != true) return false;
    }

    // Request photos first
    var newStatus = await Permission.photos.request();

    // If denied on Android, also try requesting storage (for Android <= 12 compatibility)
    if (isAndroid && !newStatus.isGranted && !newStatus.isLimited) {
      newStatus = await Permission.storage.request();
    }

    if (newStatus.isGranted || newStatus.isLimited) {
      return true;
    }

    if (newStatus.isPermanentlyDenied && context.mounted) {
      await _showPermanentlyDeniedDialog(
        context,
        title: 'Izin Galeri Diblokir',
        description:
            'Akses galeri dinonaktifkan di setelan sistem. Buka Pengaturan untuk mengaktifkannya.',
      );
    }

    return false;
  }

  /// Check status of notification permission (Android 13+).
  Future<PermissionStatus> checkNotificationStatus() async {
    if (!isMobile) return PermissionStatus.granted;
    try {
      return await Permission.notification.status;
    } catch (_) {
      return PermissionStatus.granted;
    }
  }

  /// Request notification permission for APK update and progress alerts.
  Future<bool> requestNotificationPermission(
    BuildContext context, {
    bool showRationale = false,
  }) async {
    if (!isMobile) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    if (showRationale && context.mounted) {
      final proceed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const PermissionRationaleSheet(
          title: 'Izin Notifikasi',
          description:
              'Izinkan notifikasi agar Sticker Maker dapat memberitahukan progres download APK pembaruan dan rilis fitur baru.',
          icon: Icons.notifications_active_rounded,
          benefitItems: [
            'Pantau progres download update APK di latar belakang',
            'Pemberitahuan stiker berhasil diekspor ke WhatsApp',
          ],
        ),
      );
      if (proceed != true) return false;
    }

    final newStatus = await Permission.notification.request();
    return newStatus.isGranted;
  }

  /// Check status of package install permission (Android unknown sources).
  Future<PermissionStatus> checkInstallPackagesStatus() async {
    if (!isAndroid) return PermissionStatus.granted;
    try {
      return await Permission.requestInstallPackages.status;
    } catch (_) {
      return PermissionStatus.granted;
    }
  }

  /// Request package install permission (redirects to Android system settings).
  Future<bool> requestInstallPackagesPermission(BuildContext context) async {
    if (!isAndroid) return true;

    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;

    if (context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: Color(0xFF128C7E), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text('Izin Pasang Pembaruan', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: const Text(
            'Untuk menginstal pembaruan APK secara otomatis tanpa lewat Play Store, Android memerlukan izin "Install unknown apps" (Pasang aplikasi tidak dikenal).\n\nKamu akan diarahkan ke pengaturan sistem Android untuk mengaktifkan izin ini untuk Sticker Maker.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF128C7E),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );

      if (proceed != true) return false;
    }

    final result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }

  /// Retrieve summary of all app permissions for status dashboard.
  Future<List<AppPermissionItem>> getPermissionsSummary() async {
    final cameraStatus = await checkCameraStatus();
    final galleryStatus = await checkGalleryStatus();
    final notifStatus = await checkNotificationStatus();
    final installStatus = await checkInstallPackagesStatus();

    return [
      AppPermissionItem(
        type: AppPermissionType.camera,
        title: 'Kamera',
        description: 'Untuk mengambil foto objek secara langsung menjadi stiker',
        icon: Icons.camera_alt_rounded,
        status: cameraStatus,
        isEssential: false,
      ),
      AppPermissionItem(
        type: AppPermissionType.gallery,
        title: 'Foto & Galeri',
        description: 'Untuk memilih foto dan gambar stiker dari memori perangkat',
        icon: Icons.photo_library_rounded,
        status: galleryStatus,
        isEssential: true,
      ),
      AppPermissionItem(
        type: AppPermissionType.notification,
        title: 'Notifikasi',
        description: 'Untuk progres download update dan konfirmasi ekspor stiker',
        icon: Icons.notifications_rounded,
        status: notifStatus,
        isEssential: false,
      ),
      AppPermissionItem(
        type: AppPermissionType.installPackages,
        title: 'Pemasangan Paket (APK)',
        description: 'Untuk pembaruan APK otomatis lewat fitur in-app update',
        icon: Icons.install_mobile_rounded,
        status: installStatus,
        isEssential: false,
      ),
    ];
  }

  /// Open application settings page in device settings.
  Future<bool> openSettings() async {
    if (!isMobile) return false;
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  Future<void> _showPermanentlyDeniedDialog(
    BuildContext context, {
    required String title,
    required String description,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => PermissionPermanentlyDeniedDialog(
        title: title,
        description: description,
        onOpenSettings: () {
          Navigator.of(ctx).pop();
          openSettings();
        },
      ),
    );
  }
}
