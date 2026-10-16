import 'package:flutter/material.dart';

/// Shared LEF_LEF visual system. Keep all global visual decisions here so
/// light and dark mode stay coherent instead of drifting screen by screen.
class LefTheme {
  static const gold = Color(0xFFD4AF37);
  static const goldDark = Color(0xFF96752F);
  static const green = Color(0xFF183F35);
  static const cream = Color(0xFFF8F5ED);
  static const ink = Color(0xFF171717);
  static const lightCanvas = Color(0xFFFCFBF8);
  static const darkCanvas = Color(0xFF11110F);
  static const darkSurface = Color(0xFF1B1B18);
  static const darkRaised = Color(0xFF23231F);
  static const line = Color(0x16000000);
  static const darkLine = Color(0x24FFFFFF);
  static const radiusCard = 18.0;
  // Luxury rectangular controls: softened corners, not pill-shaped buttons.
  static const radiusControl = 10.0;

  static RoundedRectangleBorder _cardShape(Color border) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCard),
        side: BorderSide(color: border, width: 1),
      );

  static InputDecorationTheme _inputs({required Color fill, required Color outline}) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: gold, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: Color(0xFFB3261E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.6),
        ),
      );

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      surface: darkSurface,
    ).copyWith(
      primary: gold,
      onPrimary: ink,
      secondary: const Color(0xFFE8CC72),
      onSecondary: ink,
      tertiary: green,
      onTertiary: Colors.white,
      surface: darkSurface,
      onSurface: const Color(0xFFF4F0E5),
      outline: darkLine,
      surfaceContainerHighest: darkRaised,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkCanvas,
      canvasColor: darkCanvas,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCanvas,
        foregroundColor: Color(0xFFF4F0E5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFFF4F0E5)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: _cardShape(darkLine),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: darkLine, thickness: 1, space: 1),
      inputDecorationTheme: _inputs(fill: darkRaised, outline: darkLine),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: ink,
          disabledBackgroundColor: gold.withAlpha(70),
          disabledForegroundColor: ink.withAlpha(130),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl), side: const BorderSide(color: goldDark, width: 0.7)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: const BorderSide(color: gold),
          minimumSize: const Size(48, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFE8CC72)),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFE8CC72)),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        minVerticalPadding: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: gold.withAlpha(45),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? gold : scheme.onSurfaceVariant,
        )),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkRaised,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? gold : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? gold.withAlpha(90) : null),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: gold),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.light,
      surface: Colors.white,
    ).copyWith(
      primary: goldDark,
      onPrimary: Colors.white,
      secondary: gold,
      onSecondary: ink,
      tertiary: green,
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      outline: const Color(0x1F171717),
      surfaceContainerHighest: cream,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightCanvas,
      canvasColor: lightCanvas,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightCanvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: _cardShape(line),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: _inputs(fill: cream, outline: const Color(0x14000000)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: ink,
          disabledBackgroundColor: gold.withAlpha(80),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl), side: const BorderSide(color: gold, width: 0.7)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: goldDark),
          minimumSize: const Size(48, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: goldDark),
      ),
      iconTheme: const IconThemeData(color: goldDark),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        minVerticalPadding: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: gold.withAlpha(38),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? goldDark : scheme.onSurfaceVariant,
        )),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? goldDark : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? gold.withAlpha(90) : null),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: goldDark),
    );
  }
}
