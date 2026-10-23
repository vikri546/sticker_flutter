import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_flutter/services/whatsapp_stickers_service.dart';
import 'package:sticker_flutter/ui/screens/whatsapp_connection_screen.dart';

void main() {
  group('WhatsAppConnectionScreen Tests', () {
    testWidgets('Renders red Kaitkan buttons when no WhatsApp is installed and launches Play Store', (WidgetTester tester) async {
      String? launchedPackage;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: WhatsAppConnectionScreen(
            statusFetcher: () async => const WhatsAppDetailedStatus(
              isWhatsAppInstalled: false,
              isBusinessInstalled: false,
              clones: [],
            ),
            playStoreLauncher: (pkg) async {
              launchedPackage = pkg;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check AppBar
      expect(find.text('Integrasi WhatsApp'), findsOneWidget);

      // Check Overall Status Banner
      expect(find.text('WhatsApp Belum Terdeteksi'), findsOneWidget);

      // Check App Items
      expect(find.text('WhatsApp Messenger'), findsOneWidget);
      expect(find.text('WhatsApp Business'), findsOneWidget);

      // Both buttons should say 'Kaitkan'
      expect(find.text('Kaitkan'), findsNWidgets(2));
      expect(find.text('Aktif'), findsNothing);

      // Check Duplicate / Clone card
      expect(find.text('Tidak Ada WhatsApp Duplikat'), findsOneWidget);

      // Tap 'Kaitkan' on WhatsApp Messenger
      await tester.tap(find.text('Kaitkan').first);
      await tester.pump();

      expect(launchedPackage, 'com.whatsapp');
      expect(find.text('Membuka Google Play Store untuk WhatsApp...'), findsOneWidget);
    });

    testWidgets('Renders green Aktif button when WhatsApp is installed', (WidgetTester tester) async {
      String? openedPackage;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: WhatsAppConnectionScreen(
            statusFetcher: () async => const WhatsAppDetailedStatus(
              isWhatsAppInstalled: true,
              whatsAppVersion: '2.24.10.15',
              isBusinessInstalled: false,
              clones: [],
            ),
            appLauncher: (pkg) async {
              openedPackage = pkg;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Overall Status Banner
      expect(find.text('WhatsApp Terdeteksi & Siap'), findsOneWidget);
      expect(find.textContaining('1 aplikasi terhubung'), findsOneWidget);

      // Check installed version text
      expect(find.text('Versi Resmi Meta (2.24.10.15)'), findsOneWidget);

      // WhatsApp Messenger should have 'Aktif', Business has 'Kaitkan'
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Kaitkan'), findsOneWidget);

      // Tap 'Aktif'
      await tester.tap(find.text('Aktif'));
      await tester.pump();

      expect(openedPackage, 'com.whatsapp');
    });

    testWidgets('Renders detected duplicate/mod WhatsApp applications correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WhatsAppConnectionScreen(
            statusFetcher: () async => const WhatsAppDetailedStatus(
              isWhatsAppInstalled: true,
              isBusinessInstalled: true,
              clones: [
                WhatsAppCloneItem(
                  packageName: 'com.gbwhatsapp',
                  name: 'GBWhatsApp',
                  version: 'v17.50',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Total count should be 3
      expect(find.textContaining('3 aplikasi terhubung'), findsOneWidget);

      // Check clone detection
      expect(find.text('GBWhatsApp'), findsOneWidget);
      expect(find.text('Klon/Mod Terdeteksi (v17.50)'), findsOneWidget);

      // All 3 apps are installed and active
      expect(find.text('Aktif'), findsNWidgets(3));
      expect(find.text('Kaitkan'), findsNothing);
    });

    test('WhatsAppConnectionScreen.route() provides zoom in/out ScaleTransition', () {
      final route = WhatsAppConnectionScreen.route();
      expect(route, isA<PageRouteBuilder<void>>());

      final pageRoute = route as PageRouteBuilder<void>;
      expect(pageRoute.transitionDuration, const Duration(milliseconds: 300));
      expect(pageRoute.reverseTransitionDuration, const Duration(milliseconds: 250));
    });
  });
}
