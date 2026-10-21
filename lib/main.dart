import 'package:flutter/material.dart';
import 'package:sticker_flutter/ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StickerApp());
}

class StickerApp extends StatelessWidget {
  const StickerApp({super.key});

  /// Global notifier for theme mode changes across the app.
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Sticko',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
        colorSchemeSeed: const Color(0xFF128C7E),
        scaffoldBackgroundColor: const Color(0xFFF9FBFB),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF9FBFB),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        splashFactory: InkRipple.splashFactory,
        colorSchemeSeed: const Color(0xFF25D366),
        scaffoldBackgroundColor: const Color(0xFF111B21),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF111B21),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF202C33),
          elevation: 0,
        ),
      ),
        home: const HomeScreen(),
        );
      },
    );
  }
}
