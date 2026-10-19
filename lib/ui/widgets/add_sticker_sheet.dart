import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sticker_flutter/services/sticker_image_processor.dart';
import 'package:sticker_flutter/services/sticker_pack_manager.dart';

/// Modal bottom sheet to pick, preview, tag with emojis, and add a new sticker.
class AddStickerSheet extends StatefulWidget {
  final String packIdentifier;

  const AddStickerSheet({
    super.key,
    required this.packIdentifier,
  });

  @override
  State<AddStickerSheet> createState() => _AddStickerSheetState();
}

class _AddStickerSheetState extends State<AddStickerSheet> {
  Uint8List? _selectedImageBytes;
  final List<String> _selectedEmojis = ['😀'];
  bool _isProcessing = false;

  final List<String> _commonEmojis = [
    '😀', '😂', '🔥', '❤️', '🎉', '👍', '😎', '🥳', '🙏', '😍', '🤩', '✨'
  ];

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await StickerImageProcessor.pickImage(source: source);
    if (xFile != null) {
      final bytes = await xFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
      });
    }
  }

  void _toggleEmoji(String emoji) {
    setState(() {
      if (_selectedEmojis.contains(emoji)) {
        if (_selectedEmojis.length > 1) {
          _selectedEmojis.remove(emoji);
        }
      } else {
        if (_selectedEmojis.length < 3) {
          _selectedEmojis.add(emoji);
        } else {
          _selectedEmojis[0] = emoji; // replace first if already 3
        }
      }
    });
  }

  Future<void> _saveSticker() async {
    if (_selectedImageBytes == null) return;

    setState(() => _isProcessing = true);
    try {
      await StickerPackManager().addStickerToPack(
        packIdentifier: widget.packIdentifier,
        imageBytes: _selectedImageBytes!,
        emojis: _selectedEmojis,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stiker berhasil dibuat dan ditambahkan ke paket!'),
            backgroundColor: Color(0xFF128C7E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat stiker: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Title
            const Text(
              'Tambah Stiker Baru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Pilih foto dari galeri atau kamera Anda untuk dijadikan stiker WhatsApp.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Image Preview or Picker Buttons
            if (_selectedImageBytes == null) ...[
              Row(
                children: [
                  Expanded(
                    child: _PickerOptionCard(
                      icon: Icons.photo_library_rounded,
                      label: 'Galeri Foto',
                      color: const Color(0xFF25D366),
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _PickerOptionCard(
                      icon: Icons.camera_alt_rounded,
                      label: 'Kamera',
                      color: const Color(0xFF128C7E),
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Image Selected Preview
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF25D366),
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(
                        _selectedImageBytes!,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withAlpha(160),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _selectedImageBytes = null),
                          child: const Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Emoji Selection Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Emoji Stiker (Maksimal 3)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    'Terpilih: ${_selectedEmojis.join(" ")}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Emoji Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonEmojis.map((emoji) {
                  final isSelected = _selectedEmojis.contains(emoji);
                  return ChoiceChip(
                    label: Text(emoji, style: const TextStyle(fontSize: 18)),
                    selected: isSelected,
                    onSelected: (_) => _toggleEmoji(emoji),
                    selectedColor: const Color(0xFF25D366).withAlpha(50),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF25D366)
                          : Colors.grey.withAlpha(60),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // Save Button
              FilledButton.icon(
                onPressed: _isProcessing ? null : _saveSticker,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _isProcessing
                      ? 'Mengompres ke Format WebP...'
                      : 'Simpan ke Koleksi Stiker',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickerOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickerOptionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
