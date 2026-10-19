import 'package:flutter/material.dart';
import 'package:sticker_flutter/services/sticker_pack_manager.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';

/// Dialog to create a new sticker pack.
class CreatePackDialog extends StatefulWidget {
  const CreatePackDialog({super.key});

  @override
  State<CreatePackDialog> createState() => _CreatePackDialogState();
}

class _CreatePackDialogState extends State<CreatePackDialog> {
  final _nameController = TextEditingController();
  final _publisherController = TextEditingController(text: 'Sticker Maker');
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _publisherController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama paket stiker tidak boleh kosong'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final newPack = await StickerPackManager().createPack(
        name: name,
        publisher: _publisherController.text.trim().isEmpty
            ? 'Sticker Maker'
            : _publisherController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop<StickerPack>(newPack);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat paket: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.collections_bookmark_rounded, color: Color(0xFF128C7E)),
          SizedBox(width: 10),
          Text(
            'Buat Paket Stiker',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Beri nama paket untuk mengelompokkan stiker Anda.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nama Paket Stiker *',
                hintText: 'Contoh: Stiker Keren, Stiker Meme',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _publisherController,
              decoration: InputDecoration(
                labelText: 'Nama Pembuat / Author',
                hintText: 'Nama Anda atau Komunitas',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _isCreating ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_isCreating ? 'Menyimpan...' : 'Buat Paket'),
        ),
      ],
    );
  }
}
