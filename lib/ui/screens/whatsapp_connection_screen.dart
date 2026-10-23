import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';

/// Screen displaying WhatsApp integration status (Official WhatsApp, Business, and Duplicate/Clones).
/// Features automatic detection, auto-refresh on app resume from Play Store,
/// red 'Kaitkan' button for uninstalled WhatsApp linking to Play Store,
/// and green 'Aktif' status for installed WhatsApp applications.
class WhatsAppConnectionScreen extends StatefulWidget {
  final Future<WhatsAppDetailedStatus> Function()? statusFetcher;
  final Future<bool> Function(String packageName)? playStoreLauncher;
  final Future<bool> Function(String packageName)? appLauncher;

  const WhatsAppConnectionScreen({
    super.key,
    this.statusFetcher,
    this.playStoreLauncher,
    this.appLauncher,
  });

  /// Custom PageRoute with Zoom In (enter) and Zoom Out (exit) transition.
  static Route<void> route({
    Future<WhatsAppDetailedStatus> Function()? statusFetcher,
    Future<bool> Function(String packageName)? playStoreLauncher,
    Future<bool> Function(String packageName)? appLauncher,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          WhatsAppConnectionScreen(
        statusFetcher: statusFetcher,
        playStoreLauncher: playStoreLauncher,
        appLauncher: appLauncher,
      ),
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
  State<WhatsAppConnectionScreen> createState() =>
      _WhatsAppConnectionScreenState();
}

class _WhatsAppConnectionScreenState extends State<WhatsAppConnectionScreen>
    with WidgetsBindingObserver {
  WhatsAppDetailedStatus _status = const WhatsAppDetailedStatus();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Automatically re-check when the user returns to the app from Google Play Store
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final fetcher = widget.statusFetcher ??
          WhatsAppStickersService.checkDetailedWhatsAppStatus;
      final status = await fetcher();
      if (mounted) {
        setState(() {
          _status = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openPlayStore(String packageName, String appName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Membuka Google Play Store untuk $appName...',
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E2B32),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final launcher = widget.playStoreLauncher ?? WhatsAppStickersService.openPlayStore;
    await launcher(packageName);
  }

  Future<void> _openApp(String packageName, String appName) async {
    final launcher = widget.appLauncher ?? WhatsAppStickersService.openWhatsAppApp;
    final opened = await launcher(packageName);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$appName sudah aktif dan siap menerima stiker!',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF25D366),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          'Integrasi WhatsApp',
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
            tooltip: 'Periksa Ulang Status',
            onPressed: _isLoading ? null : _refreshStatus,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/images/accountscreen.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          SafeArea(
            top: true,
            bottom: false,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // 1. Overall Status Summary Banner
                _buildOverallStatusBanner(isDark),
                const SizedBox(height: 20),

                // 2. Section: WhatsApp Resmi & Bisnis
                _buildSectionTitle('WHATSAPP RESMI & BISNIS'),
                const SizedBox(height: 6),
                _buildOfficialWhatsAppCard(isDark),
                const SizedBox(height: 20),

                // 3. Section: WhatsApp Duplikat & Klon
                _buildSectionTitle('WHATSAPP DUPLIKAT & KLON'),
                const SizedBox(height: 6),
                _buildClonesCard(isDark),
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

  Widget _buildOverallStatusBanner(bool isDark) {
    final isConnected = _status.hasAnyWhatsAppInstalled;

    return _LiquidGlassCard(
      borderRadius: 5,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected
                  ? const Color(0xFF25D366).withAlpha(40)
                  : const Color(0xFFE53935).withAlpha(40),
            ),
            child: Icon(
              isConnected ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: isConnected ? const Color(0xFF25D366) : const Color(0xFFE53935),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isConnected
                      ? 'WhatsApp Terdeteksi & Siap'
                      : 'WhatsApp Belum Terdeteksi',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isConnected
                      ? '${_status.totalInstalledCount} aplikasi terhubung. Stiker siap diekspor ke WhatsApp!'
                      : 'Silakan kaitkan WhatsApp original di bawah untuk mengaktifkan stiker.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialWhatsAppCard(bool isDark) {
    return _LiquidGlassCard(
      borderRadius: 5,
      child: Column(
        children: [
          // 1. WhatsApp Messenger (Original)
          _buildAppTile(
            title: 'WhatsApp Messenger',
            subtitle: _status.isWhatsAppInstalled
                ? (_status.whatsAppVersion.isNotEmpty
                    ? 'Versi Resmi Meta (${_status.whatsAppVersion})'
                    : 'Versi Resmi Meta • Terpasang')
                : 'Aplikasi utama WhatsApp resmi dari Meta',
            isInstalled: _status.isWhatsAppInstalled,
            packageName: 'com.whatsapp',
            appName: 'WhatsApp',
            isDark: isDark,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? const Color(0x24FFFFFF) : const Color(0x1F000000),
          ),

          // 2. WhatsApp Business
          _buildAppTile(
            title: 'WhatsApp Business',
            subtitle: _status.isBusinessInstalled
                ? (_status.businessVersion.isNotEmpty
                    ? 'Versi Bisnis Resmi Meta (${_status.businessVersion})'
                    : 'Versi Bisnis Resmi Meta • Terpasang')
                : 'Untuk akun bisnis & komunikasi profesional',
            isInstalled: _status.isBusinessInstalled,
            packageName: 'com.whatsapp.w4b',
            appName: 'WhatsApp Business',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildClonesCard(bool isDark) {
    final clones = _status.clones;

    if (clones.isNotEmpty) {
      return _LiquidGlassCard(
        borderRadius: 5,
        child: Column(
          children: clones.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isLast = idx == clones.length - 1;

            return Column(
              children: [
                _buildAppTile(
                  title: item.name,
                  subtitle: item.version.isNotEmpty
                      ? 'Klon/Mod Terdeteksi (${item.version})'
                      : 'Klon/Mod Terdeteksi • Siap menerima stiker',
                  isInstalled: true,
                  packageName: item.packageName,
                  appName: item.name,
                  isDark: isDark,
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: isDark ? const Color(0x24FFFFFF) : const Color(0x1F000000),
                  ),
              ],
            );
          }).toList(),
        ),
      );
    }

    return _LiquidGlassCard(
      borderRadius: 5,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(20),
            ),
            child: const Icon(
              Icons.layers_outlined,
              size: 20,
              color: Color(0xFFCFD8DC),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tidak Ada WhatsApp Duplikat',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Deteksi otomatis mendukung Dual Messenger & varian klon lainnya jika terpasang.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAppTile({
    required String title,
    required String subtitle,
    required bool isInstalled,
    required String packageName,
    required String appName,
    required bool isDark,
  }) {
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
            isInstalled: isInstalled,
            onTap: () {
              if (isInstalled) {
                _openApp(packageName, appName);
              } else {
                _openPlayStore(packageName, appName);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleButton({
    required bool isInstalled,
    required VoidCallback onTap,
  }) {
    final color = isInstalled
        ? const Color(0xFF25D366) // Green for installed/active
        : const Color(0xFFE53935); // Red for uninstalled/link

    final text = isInstalled ? 'Aktif' : 'Kaitkan';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(isInstalled ? 90 : 120),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInstalled ? Icons.check_rounded : Icons.link_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liquid Glass card with real-time backdrop blur, reflection gradient,
/// and frosted border styling, matching the app design system.
class _LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const _LiquidGlassCard({
    required this.child,
    this.borderRadius = 5,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    return Container(
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
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
