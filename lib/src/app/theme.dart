import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color canvas = Color(0xFFFFFFFF);
  static const Color canvasWarm = Color(0xFFFFFFFF);
  static const Color canvasTint = Color(0xFFFBFCFD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF17171B);
  static const Color mutedInk = Color(0xFF484C55);
  static const Color line = Color(0xFFE8ECF1);
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

  final TextTheme textTheme = Typography.blackMountainView
      .apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
        fontFamily: 'Manrope',
      )
      .copyWith(
        displaySmall: const TextStyle(
          fontSize: 40,
          height: 1.02,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        headlineSmall: const TextStyle(
          fontSize: 28,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: const TextStyle(
          fontSize: 15,
          height: 1.55,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedInk,
        ),
        bodySmall: const TextStyle(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedInk,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          height: 1.1,
          fontWeight: FontWeight.w600,
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
      surfaceTintColor: Colors.transparent,
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
      shadowColor: AppColors.ink.withValues(alpha: 0.06),
      color: AppColors.surface.withValues(alpha: 0.88),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
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
      fillColor: Colors.white.withValues(alpha: 0.72),
      hintStyle: textTheme.bodyMedium,
      labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.ink),
      floatingLabelStyle: textTheme.bodySmall?.copyWith(color: AppColors.ink),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: AppColors.line.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: AppColors.line.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.red),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white.withValues(alpha: 0.48),
        side: BorderSide(color: AppColors.line.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white.withValues(alpha: 0.68),
        minimumSize: const Size(42, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.ink;
          }
          return Colors.white.withValues(alpha: 0.58);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.ink;
        }),
        side: WidgetStatePropertyAll(
          BorderSide(color: AppColors.line.withValues(alpha: 0.7)),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
  );
}
