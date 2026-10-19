import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sticker_flutter/services/app_update_service.dart';
import 'package:sticker_flutter/services/sticker_pack_manager.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';
import 'package:sticker_flutter/ui/screens/pack_detail_screen.dart';
import 'package:sticker_flutter/ui/widgets/create_pack_dialog.dart';

/// Main Home Screen displaying the list of sticker packs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _manager = StickerPackManager();

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
          appBar: AppBar(
            elevation: 0,
            title: const Row(
              children: [
                Icon(Icons.sentiment_very_satisfied_rounded, color: Color(0xFF25D366), size: 28),
                SizedBox(width: 10),
                Text(
                  'Sticker Maker',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Segarkan Status WhatsApp',
                onPressed: () => _manager.refreshInstalledStatuses(),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Menu',
                onSelected: (value) {
                  if (value == 'force_update') {
                    AppUpdateService.showForceUpdateDialog(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'force_update',
                    child: Row(
                      children: [
                        Icon(Icons.system_update_rounded, size: 20, color: Color(0xFF007AFF)),
                        SizedBox(width: 10),
                        Text('Tes Tampilan Force Update'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: _manager.isLoading
              ? const Center(child: CircularProgressIndicator())
              : packs.isEmpty
                  ? _buildEmptyState()
                  : _buildPacksList(packs),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openCreatePackDialog,
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Paket Baru',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
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
                color: const Color(0xFF25D366).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                size: 72,
                color: Color(0xFF128C7E),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Paket Stiker',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Buat stiker pertama Anda dari galeri foto pribadi, beri nama, dan kirimkan langsung ke keyboard WhatsApp Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _openCreatePackDialog,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Buat Paket Stiker Sekarang',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPacksList(List<StickerPack> packs) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isInstalled
                  ? const Color(0xFF25D366).withAlpha(80)
                  : Theme.of(context).dividerColor.withAlpha(40),
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
