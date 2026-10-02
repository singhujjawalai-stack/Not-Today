import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const NotTodayApp());
}

class NotTodayApp extends StatelessWidget {
  const NotTodayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Not Today',
      themeMode: ThemeMode.system,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: const HomeScreen(),
    );
  }
}

// Premium white on light, AMOLED true black on dark — one sky-blue accent.
// The whole app is one accent and a lot of air: pure-white grounds with
// hairline borders on light, pure #000000 grounds on OLED dark, and a
// sky-blue accent re-tuned to contrast on each (deeper on white, brighter
// on black).
const _inkLight = Color(0xFF111111);
const _mutedLight = Color(0xFF6E6E73);
const _hairlineLight = Color(0xFFECECEC);

const _inkDark = Color(0xFFF5F5F5);
const _mutedDark = Color(0xFF9E9EA7);
const _hairlineDark = Color(0xFF1F1F22);

ThemeData _lightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A90DA),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF2E7BC4),
      primaryContainer: const Color(0xFFD9EAFB),
      onPrimaryContainer: const Color(0xFF143A5C),
      surface: const Color(0xFFFFFFFF),
      onSurface: _inkLight,
      onSurfaceVariant: _mutedLight,
      outline: _hairlineLight,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFFFFFFF),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _hairlineLight, width: 1),
      ),
    ),
    textTheme: _baseTextTheme(_inkLight),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _inkLight,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF2E7BC4),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}

ThemeData _darkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    // True OLED black — background pixels are off (battery-friendly) and
    // text sits on the sharpest possible contrast.
    scaffoldBackgroundColor: const Color(0xFF000000),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7FBDF5),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF7FBDF5),
      primaryContainer: const Color(0xFF1E3A57),
      onPrimaryContainer: const Color(0xFFD6E9FB),
      surface: const Color(0xFF0A0A0A),
      onSurface: _inkDark,
      onSurfaceVariant: _mutedDark,
      outline: _hairlineDark,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF0A0A0A),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _hairlineDark, width: 1),
      ),
    ),
    textTheme: _baseTextTheme(_inkDark),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _inkDark,
      contentTextStyle: const TextStyle(color: Color(0xFF000000), fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF7FBDF5),
      foregroundColor: Color(0xFF000000),
      elevation: 0,
    ),
  );
}

TextTheme _baseTextTheme(Color ink) {
  return TextTheme(
    // Soft, roomy headings with a subtly tight tracking.
    headlineSmall: TextStyle(
      color: ink,
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    bodyLarge: TextStyle(color: ink, fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(color: ink, fontSize: 15, height: 1.45),
    labelLarge: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w600),
  );
}