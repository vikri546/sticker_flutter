import 'package:flutter/material.dart';
import 'package:sticker_flutter/services/app_permission_service.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';

/// Screen displaying the health, permissions, and system compatibility of the app.
class SystemStatusScreen extends StatefulWidget {
  final AppPermissionService? permissionService;
  final Future<Map<String, bool>> Function()? whatsAppChecker;

  const SystemStatusScreen({
    super.key,
    this.permissionService,
    this.whatsAppChecker,
  });

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen>
    with WidgetsBindingObserver {
  late final AppPermissionService _permissionService;
  bool _isLoading = true;
  List<AppPermissionItem> _permissionItems = [];
  bool _isWhatsAppInstalled = false;
  bool _isWhatsAppBusinessInstalled = false;

  @override
  void initState() {
    super.initState();
    _permissionService = widget.permissionService ?? AppPermissionService();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When returning from Settings back to the app, refresh permission states
    if (state == AppLifecycleState.resumed) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final items = await _permissionService.getPermissionsSummary();
      final checker = widget.whatsAppChecker ?? WhatsAppStickersService.checkWhatsAppInstalled;
      final waStatus = await checker();

      if (mounted) {
        setState(() {
          _permissionItems = items;
          _isWhatsAppInstalled = waStatus['whatsapp'] ?? false;
          _isWhatsAppBusinessInstalled = waStatus['whatsapp_business'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePermissionTap(AppPermissionItem item) async {
    switch (item.type) {
      case AppPermissionType.camera:
        await _permissionService.requestCameraPermission(context);
        break;
      case AppPermissionType.gallery:
        await _permissionService.requestGalleryPermission(context);
        break;
      case AppPermissionType.notification:
        await _permissionService.requestNotificationPermission(context, showRationale: true);
        break;
      case AppPermissionType.installPackages:
        await _permissionService.requestInstallPackagesPermission(context);
        break;
    }
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Status Perizinan & Sistem',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Status',
            onPressed: _loadStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatus,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildHeaderInfo(isDark),
                  const SizedBox(height: 20),
                  _buildSectionTitle('PERIZINAN APLIKASI (ANDROID)'),
                  const SizedBox(height: 8),
                  ..._permissionItems.map((item) => _buildPermissionCard(item, isDark)),
                  const SizedBox(height: 20),
                  _buildSectionTitle('KOMPATIBILITAS APLIKASI WHATSAPP'),
                  const SizedBox(height: 8),
                  _buildWhatsAppCard(
                    title: 'WhatsApp Resmi',
                    packageName: 'com.whatsapp',
                    isInstalled: _isWhatsAppInstalled,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildWhatsAppCard(
                    title: 'WhatsApp Business',
                    packageName: 'com.whatsapp.w4b',
                    isInstalled: _isWhatsAppBusinessInstalled,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 24),
                  _buildOpenSettingsButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF128C7E).withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF128C7E).withAlpha(50),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            color: Color(0xFF128C7E),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Privasi & Izin Sistem Aman',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aplikasi hanya mengakses foto atau kamera ketika Anda memilihnya secara sadar. Pemrosesan stiker dilakukan 100% lokal di HP Anda.',
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildPermissionCard(AppPermissionItem item, bool isDark) {
    final statusColor = item.statusColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handlePermissionTap(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (item.isEssential) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(40),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Penting',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                item.isGrantedOrLimited
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: item.isGrantedOrLimited ? const Color(0xFF25D366) : Colors.grey,
                size: item.isGrantedOrLimited ? 22 : 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppCard({
    required String title,
    required String packageName,
    required bool isInstalled,
    required bool isDark,
  }) {
    final statusColor = isInstalled ? const Color(0xFF25D366) : Colors.grey;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    packageName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isInstalled ? 'Terpasang & Siap' : 'Tidak Terpasang',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isInstalled ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: statusColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenSettingsButton() {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => _permissionService.openSettings(),
      icon: const Icon(Icons.settings_suggest_rounded, size: 20),
      label: const Text(
        'Buka Pengaturan Aplikasi Sistem',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
