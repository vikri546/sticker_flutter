import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sticker_flutter/services/app_permission_service.dart';

/// Screen displaying application permissions (gallery, camera, notification)
/// with liquid glass card styling, capsule toggle buttons, and zoom in/out route transition.
class PermissionsPreferencesScreen extends StatefulWidget {
  const PermissionsPreferencesScreen({super.key});

  /// Custom PageRoute with Zoom In (enter) and Zoom Out (exit) transition.
  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PermissionsPreferencesScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    );
  }

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

  /// Displays an informative modal dialog when the user attempts to deactivate a permission.
  void _showDeactivationDialog(String permissionName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2B32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: Text(
          'Nonaktifkan Izin $permissionName',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Izin aplikasi yang sudah aktif hanya dapat dinonaktifkan secara manual melalui menu Setelan Aplikasi perangkat demi keamanan sistem.\n\nBuka Setelan Aplikasi sekarang untuk mengubah izin?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            height: 1.45,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              foregroundColor: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF09A06),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _permissionService.openSettings();
            },
            child: Text(
              'Buka Setelan',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Perizinan & Preferensi',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Segarkan Status',
            onPressed: _isLoading ? null : _refreshPermissions,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/images/accountscreen.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          SafeArea(
            top: true,
            bottom: false,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // SECTION 1: PERIZINAN APLIKASI
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

                // SECTION 2: PENGATURAN SISTEM
                _buildSectionTitle('SETELAN SISTEM ANDROID'),
                const SizedBox(height: 6),
                _buildSystemSettingsCard(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.9,
          color: const Color(0xFFCFD8DC),
        ),
      ),
    );
  }

  Widget _buildPermissionsCard(bool isDark) {
    return _LiquidGlassCard(
      borderRadius: 5,
      child: Column(
        children: [
          // 1. Galeri Foto
          _buildPermissionTile(
            title: 'Galeri & Foto',
            subtitle: 'Memilih foto untuk dibuat paket stiker',
            status: _galleryStatus,
            onRequest: _requestGallery,
            isDark: isDark,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? const Color(0x24FFFFFF) : const Color(0x1F000000),
          ),

          // 2. Kamera
          _buildPermissionTile(
            title: 'Kamera',
            subtitle: 'Memotret langsung ekspresi untuk stiker baru',
            status: _cameraStatus,
            onRequest: _requestCamera,
            isDark: isDark,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? const Color(0x24FFFFFF) : const Color(0x1F000000),
          ),

          // 3. Notifikasi
          _buildPermissionTile(
            title: 'Notifikasi',
            subtitle: 'Update APK & status ekspor stiker WhatsApp',
            status: _notificationStatus,
            onRequest: _requestNotification,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required PermissionStatus status,
    required VoidCallback onRequest,
    required bool isDark,
  }) {
    final isGranted = status.isGranted || status.isLimited;
    final isPermanentlyDenied = status.isPermanentlyDenied;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildCapsuleButton(
            isGranted: isGranted,
            onTap: () {
              if (isGranted) {
                // User wants to deactivate -> show informational modal dialog
                _showDeactivationDialog(title);
              } else {
                // User wants to activate -> request permission directly
                if (isPermanentlyDenied) {
                  _permissionService.openSettings();
                } else {
                  onRequest();
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleButton({
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: isGranted ? const Color(0xFF25D366) : const Color(0x33FFFFFF),
          boxShadow: isGranted
              ? [
                  BoxShadow(
                    color: const Color(0xFF25D366).withAlpha(70),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          isGranted ? 'Aktif' : 'Non-aktif',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isGranted ? FontWeight.w700 : FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSystemSettingsCard(bool isDark) {
    return _LiquidGlassCard(
      borderRadius: 5,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Buka Pengaturan Aplikasi',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Kelola semua izin manual dari Setelan HP Android',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => _permissionService.openSettings(),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: const Color(0x33FFFFFF),
              ),
              child: Text(
                'Buka',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liquid Glass card with real-time backdrop blur, reflection gradient,
/// and soft ambient drop shadow without borders.
class _LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;

  const _LiquidGlassCard({
    required this.child,
    this.borderRadius = 5.0,
    this.padding,
    this.margin,
    this.blur = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFFF09A06).withAlpha(isDark ? 10 : 6),
            blurRadius: 16,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0x28FFFFFF),
                        Color(0x751E2B32),
                        Color(0xB0111B21),
                      ]
                    : const [
                        Color(0xD9FFFFFF),
                        Color(0xB3FFFFFF),
                        Color(0x80F4F6F8),
                      ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
