import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sticker_flutter/services/sticker_pack_manager.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';
import 'package:sticker_flutter/ui/screens/account_screen.dart';
import 'package:sticker_flutter/ui/screens/pack_detail_screen.dart';
import 'package:sticker_flutter/ui/widgets/create_pack_dialog.dart';
import 'package:sticker_flutter/ui/widgets/floating_pill_nav_bar.dart';

/// Main Home Screen displaying the list of sticker packs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _manager = StickerPackManager();
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _manager.initialize();
  }

  void _openCreatePackDialog() async {
    final newPack = await showDialog<StickerPack>(
      context: context,
      builder: (_) => const CreatePackDialog(),
    );

    if (newPack != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PackDetailScreen(packIdentifier: newPack.identifier),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        final packs = _manager.packs;

        return Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: _currentTabIndex == 0
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
          body: IndexedStack(
            index: _currentTabIndex,
            children: [
              Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'lib/images/homescreen.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  SafeArea(
                    top: true,
                    bottom: false,
                    child: _manager.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : packs.isEmpty
                            ? _buildEmptyState()
                            : _buildPacksList(packs),
                  ),
                ],
              ),
              const AccountScreen(showAppBar: true),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingPillNavBar(
                    selectedIndex: _currentTabIndex,
                    onTabSelected: (index) {
                      setState(() {
                        _currentTabIndex = index;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _currentTabIndex == 0
              ? FloatingActionButton(
                  key: const Key('add_pack_fab'),
                  onPressed: _openCreatePackDialog,
                  backgroundColor: const Color(0xFFF09A06),
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: const CircleBorder(),
                  tooltip: 'Buat Paket Stiker',
                  child: const Icon(Icons.add_rounded, size: 30, color: Colors.black),
                )
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFF09A06).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                size: 72,
                color: Color(0xFFF09A06),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Paket Stiker',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Buat stiker pertama Anda dari galeri foto pribadi, beri nama, dan kirimkan langsung ke keyboard WhatsApp Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            TextButton.icon(
              onPressed: _openCreatePackDialog,
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xFFF09A06),
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              icon: const Icon(Icons.add_rounded, color: Color(0xFFF09A06)),
              label: const Text(
                'Buat Paket Stiker Sekarang',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF09A06),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPacksList(List<StickerPack> packs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
      itemCount: packs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pack = packs[index];
        final isInstalled = _manager.isPackInstalled(pack.identifier);
        final canAdd = pack.canAddToWhatsApp;
        final totalStickers = pack.stickers.length;

        // Try getting the tray icon or first sticker file
        final trayPath = _manager.getTrayFilePath(pack.identifier, pack.trayImageFile);
        final trayFile = trayPath != null ? File(trayPath) : null;
        final hasTray = trayFile != null && trayFile.existsSync();

        return Card(
          elevation: 1,
          color: isDark ? const Color(0xFF1E2B32) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isInstalled
                  ? const Color(0xFF25D366).withAlpha(80)
                  : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PackDetailScreen(packIdentifier: pack.identifier),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  // Tray Icon / Thumbnail
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasTray
                        ? Image.file(trayFile, fit: BoxFit.cover)
                        : const Icon(
                            Icons.collections_rounded,
                            color: Color(0xFF128C7E),
                            size: 28,
                          ),
                  ),
                  const SizedBox(width: 14),

                  // Pack Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pack.stickers.length}/30 Stiker • Oleh ${pack.publisher}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 6),

                        // Status Badge
                        if (isInstalled)
                          _buildStatusChip(
                            icon: Icons.check_circle_rounded,
                            text: 'Terpasang di WhatsApp',
                            color: const Color(0xFF128C7E),
                          )
                        else if (canAdd)
                          _buildStatusChip(
                            icon: Icons.verified_rounded,
                            text: 'Siap Ditambahkan',
                            color: const Color(0xFF25D366),
                          )
                        else
                          _buildStatusChip(
                            icon: Icons.info_outline_rounded,
                            text: 'Kurang ${3 - totalStickers} stiker lagi',
                            color: Colors.orange.shade800,
                          ),
                      ],
                    ),
                  ),

                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
