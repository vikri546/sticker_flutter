import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_flutter/services/app_update_service.dart';
import 'package:sticker_flutter/ui/widgets/force_update_dialog.dart';

void main() {
  group('AppUpdateService Version Comparison Tests', () {
    test('isVersionOlder accurately compares versions', () {
      expect(AppUpdateService.isVersionOlder('1.0.0', '1.0.1'), isTrue);
      expect(AppUpdateService.isVersionOlder('1.0.0', '1.1.0'), isTrue);
      expect(AppUpdateService.isVersionOlder('1.0.0', '2.0.0'), isTrue);
      expect(AppUpdateService.isVersionOlder('1.0.0+1', '1.0.0+2'), isTrue);

      expect(AppUpdateService.isVersionOlder('1.1.0', '1.0.0'), isFalse);
      expect(AppUpdateService.isVersionOlder('2.0.0', '1.9.9'), isFalse);
      expect(AppUpdateService.isVersionOlder('1.0.0', '1.0.0'), isFalse);
    });

    test('AppUpdateInfo correctly calculates update requirement', () {
      const infoForce = AppUpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '1.2.0',
        minRequiredVersion: '1.1.0',
        updateUrl: 'https://example.com',
        isForceUpdate: false,
      );

      expect(infoForce.hasUpdate, isTrue);
      expect(infoForce.requiresForceUpdate, isTrue);

      const infoOptional = AppUpdateInfo(
        currentVersion: '1.1.0',
        latestVersion: '1.2.0',
        minRequiredVersion: '1.0.0',
        updateUrl: 'https://example.com',
        isForceUpdate: false,
      );

      expect(infoOptional.hasUpdate, isTrue);
      expect(infoOptional.requiresForceUpdate, isFalse);
    });
  });

  group('ForceUpdateDialog UI Rendering Tests', () {
    testWidgets('Renders iOS style force update popup matching user specifications', (
      WidgetTester tester,
    ) async {
      bool updatePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForceUpdateDialog(
              title: 'New version available',
              message: 'There are new features available,\nplease update your app',
              onUpdatePressed: () => updatePressed = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Title & Message
      expect(find.text('New version available'), findsOneWidget);
      expect(find.text('There are new features available,\nplease update your app'), findsOneWidget);

      // Verify Action Button
      expect(find.text('Update'), findsOneWidget);

      // Verify PopScope restricts back navigation (canPop is false)
      final popScopeFinder = find.byType(PopScope);
      expect(popScopeFinder, findsOneWidget);
      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);

      // Verify Update Button tap
      await tester.tap(find.text('Update'));
      await tester.pump();
      expect(updatePressed, isTrue);
    });

    testWidgets('Tapping Update switches to clean progress bar without percentage text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForceUpdateDialog(
              title: 'New version available',
              message: 'There are new features available,\nplease update your app',
              updateUrl: 'https://example.com/test.apk.test',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Update'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // Tap Update
      await tester.tap(find.text('Update'));
      await tester.pump();

      // Progress bar should now be visible!
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Ensure no percentage symbol is present on screen
      expect(find.textContaining('%'), findsNothing);

      // Advance time so all simulated download timers complete
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
