import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:sticker_flutter/services/backup_restore_service.dart';
import 'package:sticker_flutter/services/sticker_pack_manager.dart';
import 'package:sticker_flutter/ui/widgets/app_notification.dart';

/// Screen providing Cloud & Local Backup/Restore (Export/Import) features
/// for WhatsApp sticker packs with system settings UI style matching
/// PermissionsPreferencesScreen and WhatsAppConnectionScreen.
class CloudBackupScreen extends StatefulWidget {
  final String? customBackupDir;
  final String? customStickersDir;

  const CloudBackupScreen({
    super.key,
    this.customBackupDir,
    this.customStickersDir,
  });

  /// Custom route providing scale and fade transition matching system settings pages.
  static Route<void> route({
    String? customBackupDir,
    String? customStickersDir,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => CloudBackupScreen(
        customBackupDir: customBackupDir,
        customStickersDir: customStickersDir,
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
    );
  }

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen>
    with WidgetsBindingObserver {
  final BackupRestoreService _backupService = BackupRestoreService();
  final StickerPackManager _packManager = StickerPackManager();

  bool _isLoading = false;
  bool _isExporting = false;
  bool _isRestoring = false;
  List<BackupMetadata> _localBackups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBackups();
  }

  @override
  void dispose() {
    AppNotification.dismiss();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadBackups();
    }
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final backups = await _backupService.getLocalBackups(
        customBackupDir: widget.customBackupDir,
      );
      if (mounted) {
        setState(() {
          _localBackups = backups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handle exporting all current sticker packs to a ZIP backup
  Future<void> _handleExportAll() async {
    if (_packManager.packs.isEmpty) {
      _showNotification(
        'Belum ada paket stiker yang dibuat untuk diekspor.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final metadata = await _backupService.exportBackupZip(
        customBackupDir: widget.customBackupDir,
        customStickersDir: widget.customStickersDir,
      );

      await _loadBackups();

      if (mounted) {
        setState(() => _isExporting = false);
        _showNotification(
          '${metadata.packCount} Paket (${metadata.stickerCount} stiker) berhasil diekspor!',
          isSuccess: true,
        );
        _showExportSuccessDialog(metadata);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _showNotification('Gagal mengekspor cadangan: $e', isSuccess: false);
      }
    }
  }

  /// Handle picking and inspecting a backup file from storage
  Future<void> _handlePickAndImportFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['zip', 'sticko'],
      );

      if (file == null) return;
      final filePath = file.path;
      if (filePath == null) {
        _showNotification('File tidak dapat diakses.', isSuccess: false);
        return;
      }

      await _inspectAndConfirmRestore(filePath);
    } catch (e) {
      _showNotification('Gagal memilih file: $e', isSuccess: false);
    }
  }

  /// Inspect a backup ZIP and show a bottom sheet modal for confirmation
  Future<void> _inspectAndConfirmRestore(String zipFilePath) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF09A06)),
      ),
    );

    final inspection = await _backupService.inspectBackupZip(zipFilePath);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss spinner

    if (!inspection.isValid) {
      _showNotification(
        inspection.error ?? 'File cadangan tidak valid.',
        isSuccess: false,
      );
      return;
    }

    bool overwriteConflicts = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141E24) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.restore_page_rounded,
                          color: Color(0xFF25D366),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Konfirmasi Pemulihan Stiker',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              '${inspection.packs.length} Paket • ${inspection.totalStickers} Stiker (${inspection.formattedFileSize})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  Text(
                    'Paket yang akan dipulihkan:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: inspection.packs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, index) {
                        final pack = inspection.packs[index];
                        final isConflict = inspection.existingConflicts.contains(pack.name);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isConflict
                                ? Colors.orange.withAlpha(isDark ? 40 : 25)
                                : (isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000)),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_zip_rounded, size: 20, color: Color(0xFFF09A06)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  pack.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${pack.stickers.length} stiker',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  if (inspection.existingConflicts.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(25),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ditemukan ${inspection.existingConflicts.length} paket bernama sama di galeri:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  overwriteConflicts
                                      ? 'Timpa paket stiker yang sudah ada'
                                      : 'Simpan sebagai salinan baru (nama paket diberi akhiran)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: overwriteConflicts,
                                activeTrackColor: const Color(0xFFF09A06),
                                onChanged: (val) {
                                  setModalState(() {
                                    overwriteConflicts = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(modalCtx).pop();
                            _performRestore(zipFilePath, overwriteConflicts);
                          },
                          icon: const Icon(Icons.download_done_rounded, size: 20),
                          label: Text(
                            'Pulihkan Stiker',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Execute the restoration process
  Future<void> _performRestore(String zipFilePath, bool overwriteConflicts) async {
    setState(() => _isRestoring = true);

    try {
      final result = await _backupService.restoreFromZip(
        zipFilePath: zipFilePath,
        overwriteConflicts: overwriteConflicts,
        customStickersDir: widget.customStickersDir,
      );

      if (mounted) {
        setState(() => _isRestoring = false);
      }

      if (result.success) {
        _showNotification(
          'Berhasil memulihkan ${result.restoredPacksCount} paket (${result.restoredStickersCount} stiker)!',
          isSuccess: true,
        );
        await _loadBackups();
      } else {
        _showNotification(
          result.error ?? 'Gagal memulihkan file cadangan.',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
      _showNotification('Gagal memulihkan: $e', isSuccess: false);
    }
  }

  /// Confirm deletion of a backup file
  Future<void> _confirmDeleteBackup(BackupMetadata metadata) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E2B32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: Text(
          'Hapus File Cadangan?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 16.5,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus file "${metadata.fileName}"?\nTindakan ini tidak menghapus stiker yang sudah terpasang di galeri saat ini.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              foregroundColor: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Hapus',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _backupService.deleteBackup(metadata.filePath);
      if (success) {
        _showNotification('File cadangan berhasil dihapus.', isSuccess: true);
        await _loadBackups();
      } else {
        _showNotification('Gagal menghapus file cadangan.', isSuccess: false);
      }
    }
  }

  void _showNotification(String message, {required bool isSuccess}) {
    if (!mounted) return;
    AppNotification.show(
      context,
      message: message,
      isSuccess: isSuccess,
    );
  }

  void _showExportSuccessDialog(BackupMetadata metadata) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return AlertDialog(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF1E2B32) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF09A06).withAlpha(40),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFFF09A06),
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Ekspor Cadangan Berhasil!',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '${metadata.packCount} Paket (${metadata.stickerCount} stiker) berhasil dikemas ke file ZIP berukuran ${metadata.formattedFileSize}.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  metadata.fileName,
                  style: GoogleFonts.robotoMono(
                    fontSize: 11.5,
                    color: const Color(0xFFF09A06),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Selesai'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF09A06),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        OpenFilex.open(metadata.filePath);
                      },
                      child: const Text('Buka File'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPacks = _packManager.packs.length;
    int totalStickers = 0;
    for (final p in _packManager.packs) {
      totalStickers += p.stickers.length;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Cadangan & Cloud',
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
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Aesthetic matching other settings pages
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
                // 1. Overall Status Summary Banner (Matching WhatsAppConnectionScreen banner)
                _buildOverallStatusBanner(isDark, totalPacks, totalStickers),
                const SizedBox(height: 20),

                // 2. Section: Aksi Cadangan & Pemulihan
                _buildSectionTitle('AKSI CADANGAN & PEMULIHAN'),
                const SizedBox(height: 6),
                _buildActionCards(isDark),
                const SizedBox(height: 20),

                // 3. Section: Riwayat File Cadangan Lokal
                Row(
                  children: [
                    _buildSectionTitle('RIWAYAT FILE CADANGAN LOKAL'),
                    const Spacer(),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(right: 8, bottom: 4),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFF09A06),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildLocalBackupsCard(isDark),
              ],
            ),
          ),

          // Loading overlay
          if (_isExporting || _isRestoring)
            Container(
              color: Colors.black54,
              child: Center(
                child: _LiquidGlassCard(
                  borderRadius: 5,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFF09A06),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _isExporting
                            ? 'Mengekspor & Mengompresi Paket...'
                            : 'Memulihkan Stiker ke Galeri...',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
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

  /// Overall Status Banner matching WhatsAppConnectionScreen pattern
  Widget _buildOverallStatusBanner(bool isDark, int totalPacks, int totalStickers) {
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
              color: const Color(0xFFF09A06).withAlpha(40),
            ),
            child: const Icon(
              Icons.cloud_sync_rounded,
              color: Color(0xFFF09A06),
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
                  'Sticko Cloud & Export',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalPacks Paket • $totalStickers Stiker siap dicadangkan',
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

  /// Action Cards for Export & Import using system settings card layout
  Widget _buildActionCards(bool isDark) {
    return _LiquidGlassCard(
      borderRadius: 5,
      child: Column(
        children: [
          // 1. Ekspor Tile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ekspor Seluruh Paket (.ZIP)',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kempa semua paket & stiker ke file ZIP portabel',
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
                  key: const Key('cloud_export_button'),
                  label: _isExporting ? 'Proses...' : 'Ekspor',
                  color: const Color(0xFFF09A06),
                  onTap: _isExporting ? null : _handleExportAll,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? const Color(0x24FFFFFF) : const Color(0x1F000000),
          ),

          // 2. Impor Tile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Impor & Pulihkan Stiker',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Pilih file ZIP cadangan untuk memulihkan paket stiker',
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
                  key: const Key('cloud_import_button'),
                  label: 'Impor',
                  color: const Color(0xFF25D366),
                  onTap: _isExporting || _isRestoring ? null : _handlePickAndImportFile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Local Backups List matching system settings list style
  Widget _buildLocalBackupsCard(bool isDark) {
    if (_localBackups.isEmpty) {
      return _LiquidGlassCard(
        borderRadius: 5,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF09A06).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_zip_outlined,
                color: Color(0xFFF09A06),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Belum Ada File Cadangan',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'File yang diekspor akan muncul di sini & dapat dipulihkan kapan saja.',
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

    return _LiquidGlassCard(
      borderRadius: 5,
      child: Column(
        children: _localBackups.asMap().entries.map((entry) {
          final idx = entry.key;
          final backup = entry.value;
          final isLast = idx == _localBackups.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF09A06).withAlpha(30),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(
                        Icons.folder_zip_rounded,
                        color: Color(0xFFF09A06),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            backup.fileName,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${backup.packCount} Paket • ${backup.stickerCount} Stiker • ${backup.formattedFileSize}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCapsuleButton(
                      label: 'Pulihkan',
                      color: const Color(0xFF25D366),
                      onTap: () => _inspectAndConfirmRestore(backup.filePath),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: 20,
                      ),
                      color: isDark ? const Color(0xFF1E2B32) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      onSelected: (val) {
                        if (val == 'open') {
                          OpenFilex.open(backup.filePath);
                        } else if (val == 'delete') {
                          _confirmDeleteBackup(backup);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              const Icon(Icons.share_outlined, size: 18),
                              const SizedBox(width: 10),
                              Text('Buka / Bagikan', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 10),
                              Text('Hapus File', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

  /// Capsule button without shadow
  Widget _buildCapsuleButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
    Key? key,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: onTap == null ? color.withAlpha(120) : color,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color == const Color(0xFFF09A06) ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass styled container without borders and without shadows
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

    return ClipRRect(
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
    );
  }
}
