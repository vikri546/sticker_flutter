import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_flutter/ui/widgets/app_notification.dart';

void main() {
  group('NotificationIconButton Show/Hide Tests', () {
    testWidgets('renders in collapsed state with check icon for success and reveals message on tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const Scaffold(
            body: Center(
              child: NotificationIconButton(
                message: 'Operasi berhasil!',
                isSuccess: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Check icon is visible (replacing green color)
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      // Message text is initially hidden
      expect(find.text('Operasi berhasil!'), findsNothing);

      // Tap the icon button to SHOW message
      await tester.tap(find.byType(NotificationIconButton));
      await tester.pumpAndSettle();

      // Message text is now visible
      expect(find.text('Operasi berhasil!'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_less_rounded), findsOneWidget);

      // Tap again to HIDE message
      await tester.tap(find.byType(NotificationIconButton));
      await tester.pumpAndSettle();

      // Message is collapsed back to hide
      expect(find.text('Operasi berhasil!'), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('renders in collapsed state with silang icon for error and toggles show/hide', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const Scaffold(
            body: Center(
              child: NotificationIconButton(
                message: 'Nama tidak boleh kosong',
                isSuccess: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Silang/close icon is visible (replacing red color)
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      // Message text is initially hidden
      expect(find.text('Nama tidak boleh kosong'), findsNothing);

      // Tap the icon button to SHOW message
      await tester.tap(find.byType(NotificationIconButton));
      await tester.pumpAndSettle();

      // Message text is now shown
      expect(find.text('Nama tidak boleh kosong'), findsOneWidget);

      // Tap again to HIDE message
      await tester.tap(find.byType(NotificationIconButton));
      await tester.pumpAndSettle();

      // Message is hidden again
      expect(find.text('Nama tidak boleh kosong'), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('AppNotification.show launches overlay and can be dismissed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppNotification.show(
                      ctx,
                      message: 'Notifikasi floating aktif',
                      isSuccess: true,
                    );
                  },
                  child: const Text('Tampilkan Notif'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show notification
      await tester.tap(find.text('Tampilkan Notif'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(NotificationIconButton), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Expand floating notification
      await tester.tap(find.byType(NotificationIconButton));
      await tester.pumpAndSettle();

      expect(find.text('Notifikasi floating aktif'), findsOneWidget);

      // Dismiss programmatically
      AppNotification.dismiss();
      await tester.pump();

      expect(find.byType(NotificationIconButton), findsNothing);
    });
  });
}
