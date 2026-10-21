import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_flutter/main.dart';
import 'package:sticker_flutter/services/sticker_pack_manager.dart';
import 'package:sticker_flutter/ui/screens/account_screen.dart';
import 'package:sticker_flutter/ui/screens/home_screen.dart';
import 'package:sticker_flutter/ui/screens/permissions_preferences_screen.dart';
import 'package:sticker_flutter/ui/widgets/floating_pill_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  const channel = MethodChannel('com.pkri.sticko/stickers');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('account_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getStickersDirectory':
          return tempDir.path;
        case 'checkWhatsAppInstalled':
          return {'whatsapp': true, 'whatsapp_business': false};
        case 'isStickerPackAdded':
          return false;
        default:
          return null;
      }
    });

    final manager = StickerPackManager();
    manager.resetForTesting();
    await manager.initialize(customStickersDir: tempDir.path, force: true);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    StickerPackManager().resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FloatingPillNavBar Tests', () {
    testWidgets('Renders Explore and Account tabs with correct styling', (
      WidgetTester tester,
    ) async {
      int selectedTab = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return FloatingPillNavBar(
                    selectedIndex: selectedTab,
                    onTabSelected: (index) {
                      setState(() {
                        selectedTab = index;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify both tab labels and icons exist
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);

      // Tap on 'Account'
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      expect(selectedTab, equals(1));

      // Tap on 'Explore'
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      expect(selectedTab, equals(0));
    });
  });

  group('AccountScreen UI Tests', () {
    testWidgets('Renders creator card, settings sections, and tutorial dialog', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const AccountScreen(showAppBar: true),
        ),
      );
      await tester.pump();

      // Check Creator Card & App Bar (Sticko text in header)
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Sticko')),
        findsOneWidget,
      );
      expect(find.text('Account & Settings'), findsNothing);
      expect(find.text('Kreator Stiker'), findsOneWidget);
      expect(find.text('Penyimpanan Lokal Aktif'), findsOneWidget);

      // Check Sections (Simplified layout with Permissions & Preferences)
      expect(find.text('PREFERENSI & PERIZINAN'), findsOneWidget);
      expect(find.text('Permissions & Preferences'), findsOneWidget);
      expect(find.text('PENGATURAN LAINNYA'), findsOneWidget);

      // Open Tutorial Dialog
      await tester.tap(find.text('Panduan Menambahkan ke WA'));
      await tester.pumpAndSettle();

      expect(find.text('Cara Menggunakan Stiker'), findsOneWidget);
      expect(find.text('Buat Paket Stiker'), findsOneWidget);
      expect(find.text('Kirim ke WhatsApp'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Mengerti'));
      await tester.pumpAndSettle();
      expect(find.text('Cara Menggunakan Stiker'), findsNothing);
    });
  });

  group('HomeScreen Tab Navigation Integration Tests', () {
    testWidgets('Switches smoothly between Explore and Account tabs via FloatingPillNavBar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const HomeScreen(),
        ),
      );
      await tester.pump();

      // 1. Initial State: Explore tab active
      expect(find.text('Sticko'), findsOneWidget);
      expect(find.byKey(const Key('add_pack_fab')), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      // Header has only Sticko, no shield or refresh action icons on Explore tab AppBar
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.security_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.refresh_rounded)),
        findsNothing,
      );

      // 2. Switch to Account tab
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      // Account tab is active: AppBar has Sticko text matching homepage, no action buttons, FAB is hidden
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Sticko')),
        findsOneWidget,
      );
      expect(find.text('Account & Settings'), findsNothing);
      expect(find.text('Kreator Stiker'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.security_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.refresh_rounded)),
        findsNothing,
      );
      expect(find.byKey(const Key('add_pack_fab')), findsNothing);

      // 3. Switch back to Explore tab
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Explore tab is active again: Sticko AppBar and FAB reappear, no actions in Explore AppBar
      expect(find.text('Sticko'), findsOneWidget);
      expect(find.byKey(const Key('add_pack_fab')), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.security_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.refresh_rounded)),
        findsNothing,
      );
    });
  });

  group('PermissionsPreferencesScreen Tests', () {
    testWidgets('Renders theme options and updates themeModeNotifier', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const PermissionsPreferencesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Permissions & Preferences'), findsOneWidget);

      // Check Sections
      expect(find.text('TEMA APLIKASI'), findsOneWidget);
      expect(find.text('Mode Terang'), findsOneWidget);
      expect(find.text('Mode Gelap'), findsOneWidget);
      expect(find.text('Mengikuti Sistem'), findsOneWidget);

      // Tap Mode Terang
      await tester.tap(find.text('Mode Terang'));
      await tester.pumpAndSettle();
      expect(StickerApp.themeModeNotifier.value, equals(ThemeMode.light));

      // Tap Mode Gelap
      await tester.tap(find.text('Mode Gelap'));
      await tester.pumpAndSettle();
      expect(StickerApp.themeModeNotifier.value, equals(ThemeMode.dark));

      // Tap Mengikuti Sistem
      await tester.tap(find.text('Mengikuti Sistem'));
      await tester.pumpAndSettle();
      expect(StickerApp.themeModeNotifier.value, equals(ThemeMode.system));

      // Check Permissions Section
      expect(find.text('PERIZINAN APLIKASI'), findsOneWidget);
      expect(find.text('Galeri & Foto'), findsOneWidget);
      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Notifikasi'), findsOneWidget);

      // Check System Settings
      expect(find.text('SETELAN SISTEM ANDROID'), findsOneWidget);
      expect(find.text('Buka Pengaturan Aplikasi'), findsOneWidget);
    });
  });
}
