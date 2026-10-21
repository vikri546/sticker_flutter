import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sticker_flutter/services/app_permission_service.dart';
import 'package:sticker_flutter/ui/screens/system_status_screen.dart';
import 'package:sticker_flutter/ui/widgets/permission_dialogs.dart';

class FakePermissionService extends AppPermissionService {
  FakePermissionService() : super.custom();

  @override
  Future<List<AppPermissionItem>> getPermissionsSummary() async {
    return const [
      AppPermissionItem(
        type: AppPermissionType.camera,
        title: 'Kamera',
        description: 'Untuk mengambil foto objek secara langsung',
        icon: Icons.camera_alt_rounded,
        status: PermissionStatus.granted,
      ),
      AppPermissionItem(
        type: AppPermissionType.gallery,
        title: 'Foto & Galeri',
        description: 'Untuk memilih foto dan gambar stiker',
        icon: Icons.photo_library_rounded,
        status: PermissionStatus.granted,
        isEssential: true,
      ),
      AppPermissionItem(
        type: AppPermissionType.notification,
        title: 'Notifikasi',
        description: 'Untuk progres download update',
        icon: Icons.notifications_rounded,
        status: PermissionStatus.denied,
      ),
      AppPermissionItem(
        type: AppPermissionType.installPackages,
        title: 'Pemasangan Paket (APK)',
        description: 'Untuk pembaruan APK otomatis',
        icon: Icons.install_mobile_rounded,
        status: PermissionStatus.permanentlyDenied,
      ),
    ];
  }
}

void main() {
  group('AppPermissionItem Status & Model Tests', () {
    test('AppPermissionItem status attributes evaluate correctly for granted and limited', () {
      const itemGranted = AppPermissionItem(
        type: AppPermissionType.camera,
        title: 'Kamera',
        description: 'Ambil foto',
        icon: Icons.camera_alt,
        status: PermissionStatus.granted,
      );

      expect(itemGranted.isGrantedOrLimited, isTrue);
      expect(itemGranted.statusLabel, 'Diizinkan');
      expect(itemGranted.statusColor, const Color(0xFF25D366));

      const itemLimited = AppPermissionItem(
        type: AppPermissionType.gallery,
        title: 'Foto & Galeri',
        description: 'Pilih foto',
        icon: Icons.photo_library,
        status: PermissionStatus.limited,
      );

      expect(itemLimited.isGrantedOrLimited, isTrue);
      expect(itemLimited.statusLabel, 'Akses Terbatas (Android 14+)');
      expect(itemLimited.statusColor, const Color(0xFF0288D1));
    });

    test('AppPermissionItem status attributes evaluate correctly for denied states', () {
      const itemDenied = AppPermissionItem(
        type: AppPermissionType.notification,
        title: 'Notifikasi',
        description: 'Info update',
        icon: Icons.notifications,
        status: PermissionStatus.denied,
      );

      expect(itemDenied.isGrantedOrLimited, isFalse);
      expect(itemDenied.statusLabel, 'Belum Diizinkan');

      const itemPermDenied = AppPermissionItem(
        type: AppPermissionType.installPackages,
        title: 'Pasang APK',
        description: 'Auto update',
        icon: Icons.install_mobile,
        status: PermissionStatus.permanentlyDenied,
      );

      expect(itemPermDenied.isGrantedOrLimited, isFalse);
      expect(itemPermDenied.statusLabel, 'Ditolak Permanen');
      expect(itemPermDenied.statusColor, const Color(0xFFE53935));
    });
  });

  group('PermissionDialogs UI Rendering Tests', () {
    testWidgets('PermissionRationaleSheet renders details and benefit items correctly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const PermissionRationaleSheet(
                      title: 'Izin Kamera Diperlukan',
                      description: 'Sticker Maker butuh kamera untuk foto stiker.',
                      icon: Icons.camera_alt_rounded,
                      benefitItems: [
                        'Memotret langsung ekspresi seru',
                        'Disesuaikan ke format 512x512',
                      ],
                    ),
                  );
                },
                child: const Text('Buka Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Buka Sheet'));
      await tester.pumpAndSettle();

      // Check contents
      expect(find.text('Izin Kamera Diperlukan'), findsOneWidget);
      expect(find.text('Sticker Maker butuh kamera untuk foto stiker.'), findsOneWidget);
      expect(find.text('Memotret langsung ekspresi seru'), findsOneWidget);
      expect(find.text('Disesuaikan ke format 512x512'), findsOneWidget);
      expect(find.text('Nanti Saja'), findsOneWidget);
      expect(find.text('Lanjutkan & Izinkan'), findsOneWidget);

      // Tap 'Lanjutkan & Izinkan'
      await tester.tap(find.text('Lanjutkan & Izinkan'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('PermissionPermanentlyDeniedDialog renders and executes open settings callback', (
      WidgetTester tester,
    ) async {
      bool settingsOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionPermanentlyDeniedDialog(
              title: 'Izin Kamera Diblokir',
              description: 'Akses dinonaktifkan di setelan sistem.',
              onOpenSettings: () {
                settingsOpened = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Izin Kamera Diblokir'), findsOneWidget);
      expect(find.textContaining('Akses dinonaktifkan di setelan sistem.'), findsOneWidget);
      expect(find.text('Buka Pengaturan'), findsOneWidget);

      await tester.tap(find.text('Buka Pengaturan'));
      await tester.pump();

      expect(settingsOpened, isTrue);
    });
  });

  group('SystemStatusScreen UI Rendering Tests', () {
    testWidgets('SystemStatusScreen renders header, sections, and refresh button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SystemStatusScreen(
            permissionService: FakePermissionService(),
            whatsAppChecker: () async => {'whatsapp': true, 'whatsapp_business': false},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Check title and icons
      expect(find.text('Status Perizinan & Sistem'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.text('Privasi & Izin Sistem Aman'), findsOneWidget);
      expect(find.text('PERIZINAN APLIKASI (ANDROID)'), findsOneWidget);
      expect(find.text('KOMPATIBILITAS APLIKASI WHATSAPP'), findsOneWidget);
      expect(find.text('Buka Pengaturan Aplikasi Sistem'), findsOneWidget);
    });
  });
}
