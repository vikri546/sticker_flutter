import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sticker_flutter/main.dart';
import 'package:sticker_flutter/services/app_permission_service.dart';

/// Screen displaying application permissions (gallery, camera, notification) and preferences (light/dark theme).
class PermissionsPreferencesScreen extends StatefulWidget {
  const PermissionsPreferencesScreen({super.key});

  @override
  State<PermissionsPreferencesScreen> createState() =>
      _PermissionsPreferencesScreenState();
}

class _PermissionsPreferencesScreenState
    extends State<PermissionsPreferencesScreen> {
  final _permissionService = AppPermissionService();

  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _galleryStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final cam = await _permissionService.checkCameraStatus();
      final gal = await _permissionService.checkGalleryStatus();
      final notif = await _permissionService.checkNotificationStatus();

      if (mounted) {
        setState(() {
          _cameraStatus = cam;
          _galleryStatus = gal;
          _notificationStatus = notif;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing permissions: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestCamera() async {
    await _permissionService.requestCameraPermission(context);
    await _refreshPermissions();
  }

  Future<void> _requestGallery() async {
    await _permissionService.requestGalleryPermission(context);
    await _refreshPermissions();
  }

  Future<void> _requestNotification() async {
    await _permissionService.requestNotificationPermission(context, showRationale: true);
    await _refreshPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Permissions & Preferences',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Status',
            onPressed: _isLoading ? null : _refreshPermissions,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // SECTION 1: TEMA APLIKASI
          _buildSectionTitle('TEMA APLIKASI'),
          const SizedBox(height: 6),
          _buildThemeCard(isDark),
          const SizedBox(height: 24),

          // SECTION 2: PERIZINAN APLIKASI
          Row(
            children: [
              _buildSectionTitle('PERIZINAN APLIKASI'),
              const Spacer(),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 8, bottom: 4),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _buildPermissionsCard(isDark),
          const SizedBox(height: 24),

          // SECTION 3: PENGATURAN SISTEM
          _buildSectionTitle('SETELAN SISTEM ANDROID'),
          const SizedBox(height: 6),
          _buildSystemSettingsCard(isDark),
          const SizedBox(height: 24),

          // INFO PRIVASI
          _buildPrivacyNote(isDark),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildThemeCard(bool isDark) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: StickerApp.themeModeNotifier,
      builder: (context, currentMode, _) {
        return Material(
          color: isDark ? const Color(0xFF1E2B32) : Colors.white,
          borderRadius: BorderRadius.circular(5),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              children: [
                _buildThemeOption(
                  title: 'Mode Terang',
                  subtitle: 'Tampilan cerah dengan latar putih bersih',
                  icon: Icons.light_mode_rounded,
                  iconColor: const Color(0xFFF09A06),
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () => StickerApp.themeModeNotifier.value = ThemeMode.light,
                ),
                const Divider(height: 1, indent: 56),
                _buildThemeOption(
                  title: 'Mode Gelap',
                  subtitle: 'Tampilan malam hemat daya & ramah mata',
                  icon: Icons.dark_mode_rounded,
                  iconColor: const Color(0xFF25D366),
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () => StickerApp.themeModeNotifier.value = ThemeMode.dark,
                ),
                const Divider(height: 1, indent: 56),
                _buildThemeOption(
                  title: 'Mengikuti Sistem',
                  subtitle: 'Otomatis berganti mengikuti tema HP Android',
                  icon: Icons.brightness_auto_rounded,
                  iconColor: Colors.blueAccent,
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () => StickerApp.themeModeNotifier.value = ThemeMode.system,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withAlpha(25),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFFF09A06), size: 22)
          : const Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey, size: 22),
    );
  }

  Widget _buildPermissionsCard(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1E2B32) : Colors.white,
      borderRadius: BorderRadius.circular(5),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          children: [
            // 1. Galeri Foto
            _buildPermissionTile(
              icon: Icons.photo_library_rounded,
              iconColor: const Color(0xFF0288D1),
              title: 'Galeri & Foto',
              subtitle: 'Memilih foto untuk dibuat paket stiker',
              status: _galleryStatus,
              onRequest: _requestGallery,
            ),
            const Divider(height: 1, indent: 56),

            // 2. Kamera
            _buildPermissionTile(
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xFFF09A06),
              title: 'Kamera',
              subtitle: 'Memotret langsung ekspresi untuk stiker baru',
              status: _cameraStatus,
              onRequest: _requestCamera,
            ),
            const Divider(height: 1, indent: 56),

            // 3. Notifikasi
            _buildPermissionTile(
              icon: Icons.notifications_active_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'Notifikasi',
              subtitle: 'Update APK & status ekspor stiker WhatsApp',
              status: _notificationStatus,
              onRequest: _requestNotification,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required PermissionStatus status,
    required VoidCallback onRequest,
  }) {
    final isGranted = status.isGranted || status.isLimited;
    final isPermanentlyDenied = status.isPermanentlyDenied;

    final badgeText = isGranted
        ? 'Diizinkan'
        : isPermanentlyDenied
            ? 'Setelan'
            : 'Izinkan';

    final badgeColor = isGranted
        ? const Color(0xFF25D366)
        : isPermanentlyDenied
            ? Colors.redAccent
            : const Color(0xFFF09A06);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withAlpha(25),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: isPermanentlyDenied
            ? () => _permissionService.openSettings()
            : onRequest,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withAlpha(25),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: badgeColor.withAlpha(80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGranted
                    ? Icons.check_circle_rounded
                    : isPermanentlyDenied
                        ? Icons.settings_rounded
                        : Icons.touch_app_rounded,
                size: 14,
                color: badgeColor,
              ),
              const SizedBox(width: 4),
              Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemSettingsCard(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1E2B32) : Colors.white,
      borderRadius: BorderRadius.circular(5),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(25),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Icon(Icons.settings_outlined, color: Colors.grey, size: 22),
          ),
          title: const Text(
            'Buka Pengaturan Aplikasi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: const Text(
            'Kelola semua izin manual dari Setelan HP Android',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
          onTap: () => _permissionService.openSettings(),
        ),
      ),
    );
  }

  Widget _buildPrivacyNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366).withAlpha(15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFF25D366).withAlpha(50),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF128C7E), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Privasi Terjaga: Seluruh proses foto, kamera, dan stiker berjalan 100% lokal di smartphone kamu. Tidak ada foto yang dikirim ke server luar.',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
