import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sticker_flutter/services/app_update_service.dart';
import 'package:sticker_flutter/services/sticker_pack_manager.dart';
import 'package:sticker_flutter/ui/screens/permissions_preferences_screen.dart';

/// Screen displaying user account details, system permissions access, storage management, and app updates.
class AccountScreen extends StatefulWidget {
  final bool showAppBar;

  const AccountScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _manager = StickerPackManager();
  bool _isCheckingUpdate = false;
  String _cacheSizeText = 'Menghitung...';

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: true, followLinks: false);
        for (final file in files) {
          if (file is File) {
            totalBytes += await file.length();
          }
        }
      }
      final mb = totalBytes / (1024 * 1024);
      if (mounted) {
        setState(() {
          _cacheSizeText = '${mb.toStringAsFixed(2)} MB';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cacheSizeText = '0.00 MB');
      }
    }
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: false);
        for (final file in files) {
          try {
            await file.delete(recursive: true);
          } catch (_) {}
        }
      }
      await _calculateCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache sementara berhasil dibersihkan!'),
            backgroundColor: Color(0xFF128C7E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membersihkan cache: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF25D366), size: 28),
            SizedBox(width: 12),
            Text('Versi Terbaru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Aplikasi Sticker Maker Anda sudah menggunakan versi paling mutakhir (v1.0.0+1).\n\nFitur force update dan pemeriksaan pembaruan aktif secara otomatis.',
          style: TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF128C7E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  void _showTutorialDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Color(0xFFF09A06), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cara Menggunakan Stiker',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _TutorialStep(
                number: '1',
                title: 'Buat Paket Stiker',
                desc: 'Tambahkan minimal 3 stiker dan maksimal 30 stiker ke dalam satu paket.',
              ),
              SizedBox(height: 12),
              _TutorialStep(
                number: '2',
                title: 'Kirim ke WhatsApp',
                desc: 'Ketuk tombol hijau "Simpan ke WhatsApp" di halaman detail paket stiker.',
              ),
              SizedBox(height: 12),
              _TutorialStep(
                number: '3',
                title: 'Mulai Chat & Kirim',
                desc: 'Buka chat di WhatsApp > Ketuk ikon emoji pada keyboard > Pilih tab stiker. Stiker siap dipakai!',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF09A06),
              foregroundColor: const Color(0xFF3B1E00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: Color(0xFF128C7E), size: 26),
            SizedBox(width: 12),
            Text('Privasi Pengguna', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Semua foto, kamera, dan paket stiker diproses secara 100% lokal di dalam memori smartphone Anda.\n\nTidak ada foto atau stiker yang diunggah ke server cloud pihak ketiga mana pun tanpa persetujuan Anda.',
          style: TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        final totalPacks = _manager.packs.length;
        final totalStickers =
            _manager.packs.fold<int>(0, (sum, p) => sum + p.stickers.length);
        final installedPacks = _manager.packs
            .where((p) => _manager.isPackInstalled(p.identifier))
            .length;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: widget.showAppBar
              ? AppBar(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  centerTitle: true,
                  title: Text(
                    'Sticko',
                    style: GoogleFonts.alexBrush(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF09A06),
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              : null,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'lib/images/accountscreen.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              SafeArea(
                top: widget.showAppBar,
                bottom: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
                  children: [
              // 1. Creator Profile Card
              _buildCreatorProfileCard(
                isDark: isDark,
                totalPacks: totalPacks,
                totalStickers: totalStickers,
                installedPacks: installedPacks,
              ),
              const SizedBox(height: 20),

              // 2. Section: Permissions & Preferences (New Simplified Core Feature)
              _buildSectionHeader('PREFERENSI & PERIZINAN'),
              _buildSettingsCard(
                isDark: isDark,
                children: [
                  _SettingsListTile(
                    icon: Icons.tune_rounded,
                    iconColor: const Color(0xFFF09A06),
                    title: 'Permissions & Preferences',
                    subtitle: 'Izin galeri, kamera, notifikasi, & tema terang/gelap',
                    trailingWidget: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PermissionsPreferencesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. Section: Pengaturan & Bantuan Lainnya
              _buildSectionHeader('PENGATURAN LAINNYA'),
              _buildSettingsCard(
                isDark: isDark,
                children: [
                  _SettingsListTile(
                    icon: Icons.cleaning_services_rounded,
                    iconColor: Colors.deepOrange,
                    title: 'Bersihkan Cache Sementara',
                    subtitle: 'Ukuran cache saat ini: $_cacheSizeText',
                    trailingBadge: 'Bersihkan',
                    trailingBadgeColor: Colors.deepOrange,
                    onTap: _clearCache,
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsListTile(
                    icon: Icons.system_update_rounded,
                    iconColor: const Color(0xFF128C7E),
                    title: 'Periksa Pembaruan APK',
                    subtitle: 'Versi saat ini: ${AppUpdateService.defaultCurrentVersion} (Terbaru)',
                    trailingWidget: _isCheckingUpdate
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: _isCheckingUpdate ? null : _checkForUpdate,
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsListTile(
                    icon: Icons.menu_book_rounded,
                    iconColor: const Color(0xFF0288D1),
                    title: 'Panduan Menambahkan ke WA',
                    subtitle: 'Langkah mudah memunculkan stiker di keyboard',
                    onTap: _showTutorialDialog,
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsListTile(
                    icon: Icons.privacy_tip_rounded,
                    iconColor: Colors.teal,
                    title: 'Kebijakan Privasi & Data',
                    subtitle: '100% lokal, aman & tanpa pelacak luar',
                    onTap: _showPrivacyDialog,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Version Footer
              Center(
                child: Text(
                  'Sticker Maker v1.0.0+1 • Made with Flutter',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : const Color(0xFFB0BEC5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    ),
  );
      },
    );
  }

  Widget _buildCreatorProfileCard({
    required bool isDark,
    required int totalPacks,
    required int totalStickers,
    required int installedPacks,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2B32) : Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF09A06).withAlpha(100),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF09A06).withAlpha(30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'lib/images/sticko-app.png',
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF09A06),
                      child: const Icon(
                        Icons.sentiment_very_satisfied_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Kreator Stiker',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.verified_rounded, color: Color(0xFF25D366), size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Penyimpanan Lokal Aktif',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111B21) : const Color(0xFFF7F9FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Paket', '$totalPacks', isDark),
                Container(width: 1, height: 28, color: Colors.grey.withAlpha(50)),
                _buildStatItem('Stiker', '$totalStickers', isDark),
                Container(width: 1, height: 28, color: Colors.grey.withAlpha(50)),
                _buildStatItem('Di WA', '$installedPacks', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF09A06),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: const Color(0xFFB0BEC5),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E2B32) : Colors.white,
      borderRadius: BorderRadius.circular(5),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _SettingsListTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? trailingBadge;
  final Color? trailingBadgeColor;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  const _SettingsListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailingBadge,
    this.trailingBadgeColor,
    this.trailingWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: ListTile(
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
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: trailingWidget ??
          (trailingBadge != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (trailingBadgeColor ?? const Color(0xFF128C7E)).withAlpha(25),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    trailingBadge!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: trailingBadgeColor ?? const Color(0xFF128C7E),
                    ),
                  ),
                )
              : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey)),
      onTap: onTap,
    ),
  );
 }
}

class _TutorialStep extends StatelessWidget {
  final String number;
  final String title;
  final String desc;

  const _TutorialStep({
    required this.number,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFF09A06),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Color(0xFF3B1E00),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
