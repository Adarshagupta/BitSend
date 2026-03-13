import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color canvas = Color(0xFFF6F0E7);
  static const Color canvasWarm = Color(0xFFFFFAF4);
  static const Color ink = Color(0xFF17171B);
  static const Color mutedInk = Color(0xFF54545E);
  static const Color line = Color(0xFFE4D8C7);
  static const Color heroStart = Color(0xFF123C31);
  static const Color heroEnd = Color(0xFF2C7560);
  static const Color emerald = Color(0xFF1F8A61);
  static const Color emeraldTint = Color(0xFFE5F4EE);
  static const Color amber = Color(0xFFF2A938);
  static const Color amberTint = Color(0xFFFFF4DE);
  static const Color blue = Color(0xFF3370E8);
  static const Color blueTint = Color(0xFFE8F0FF);
  static const Color slate = Color(0xFF67707D);
  static const Color slateTint = Color(0xFFE9ECF0);
  static const Color red = Color(0xFFBF4C43);
  static const Color redTint = Color(0xFFFBE8E5);
}

ThemeData buildBitsendTheme() {
  const ColorScheme colorScheme = ColorScheme.light(
    primary: AppColors.ink,
    onPrimary: Colors.white,
    secondary: AppColors.emerald,
    onSecondary: Colors.white,
    surface: AppColors.canvasWarm,
    onSurface: AppColors.ink,
    error: AppColors.red,
    onError: Colors.white,
  );

  final TextTheme textTheme = Typography.blackMountainView.apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
    fontFamily: 'Manrope',
  ).copyWith(
    displaySmall: const TextStyle(
      fontSize: 38,
      height: 1.05,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
    ),
    headlineSmall: const TextStyle(
      fontSize: 26,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.7,
    ),
    titleLarge: const TextStyle(
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: const TextStyle(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: AppColors.mutedInk,
    ),
    labelLarge: const TextStyle(
      fontSize: 14,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.canvasWarm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: AppColors.line),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerColor: AppColors.line,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.canvasWarm,
      hintStyle: textTheme.bodyMedium,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.red),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor:
            WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.ink;
          }
          return AppColors.canvasWarm;
        }),
        foregroundColor:
            WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.ink;
        }),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    ),
  );
}
