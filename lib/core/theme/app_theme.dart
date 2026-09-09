import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ===========================================================================
  // LIGHT THEME
  // ===========================================================================

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.danger,
      onError: Colors.white,
    ),

    // -------------------------------------------------------------------------
    // FONT / TEXT
    // -------------------------------------------------------------------------

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      displayMedium: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),

    // -------------------------------------------------------------------------
    // APP BAR
    // -------------------------------------------------------------------------

    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightTextPrimary,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(
        color: AppColors.lightTextPrimary,
        size: 23,
      ),
    ),

    // -------------------------------------------------------------------------
    // CARD
    // -------------------------------------------------------------------------

    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.lightCard,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(18),
        ),
        side: BorderSide(
          color: AppColors.lightBorder,
          width: 1,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // INPUT
    // -------------------------------------------------------------------------

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),

      hintStyle: const TextStyle(
        color: AppColors.lightTextSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),

      labelStyle: const TextStyle(
        color: AppColors.lightTextSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),

      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),

      prefixIconColor: AppColors.lightTextSecondary,
      suffixIconColor: AppColors.lightTextSecondary,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.lightBorder,
          width: 1,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.lightBorder,
          width: 1,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.7,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 1,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 1.7,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // ELEVATED BUTTON
    // -------------------------------------------------------------------------

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.lightBorder,
        disabledForegroundColor: AppColors.lightTextSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // OUTLINED BUTTON
    // -------------------------------------------------------------------------

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        foregroundColor: AppColors.primary,
        side: const BorderSide(
          color: AppColors.lightBorder,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // TEXT BUTTON
    // -------------------------------------------------------------------------

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // ICON BUTTON
    // -------------------------------------------------------------------------

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.lightTextPrimary,
        minimumSize: const Size(42, 42),
        padding: const EdgeInsets.all(9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // FLOATING ACTION BUTTON
    // -------------------------------------------------------------------------

    floatingActionButtonTheme:
        const FloatingActionButtonThemeData(
      elevation: 3,
      highlightElevation: 5,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(17),
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // DIVIDER
    // -------------------------------------------------------------------------

    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
      space: 1,
    ),

    // -------------------------------------------------------------------------
    // CHIP
    // -------------------------------------------------------------------------

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightBackground,
      selectedColor: AppColors.primary.withValues(
        alpha: 0.12,
      ),
      disabledColor: AppColors.lightBorder,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.lightTextPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: AppColors.lightBorder,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // DROPDOWN
    // -------------------------------------------------------------------------

    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
          ),
        ),
      ),
      menuStyle: MenuStyle(
        elevation: const WidgetStatePropertyAll(8),
        surfaceTintColor:
            const WidgetStatePropertyAll(
          Colors.transparent,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // DIALOG
    // -------------------------------------------------------------------------

    dialogTheme: DialogThemeData(
      elevation: 8,
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      titleTextStyle: const TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.lightTextSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),

    // -------------------------------------------------------------------------
    // BOTTOM SHEET
    // -------------------------------------------------------------------------

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      showDragHandle: true,
      dragHandleColor: AppColors.lightBorder,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // SNACKBAR
    // -------------------------------------------------------------------------

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 5,
      backgroundColor: AppColors.lightTextPrimary,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
    ),

    // -------------------------------------------------------------------------
    // PROGRESS INDICATOR
    // -------------------------------------------------------------------------

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.lightBorder,
    ),

    // -------------------------------------------------------------------------
    // LIST TILE
    // -------------------------------------------------------------------------

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      minVerticalPadding: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(13),
        ),
      ),
      iconColor: AppColors.lightTextSecondary,
    ),
  );

  // ===========================================================================
  // DARK THEME
  // ===========================================================================

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryLight,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.danger,
      onError: Colors.white,
    ),

    // -------------------------------------------------------------------------
    // FONT / TEXT
    // -------------------------------------------------------------------------

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      displayMedium: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),

    // -------------------------------------------------------------------------
    // APP BAR
    // -------------------------------------------------------------------------

    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkTextPrimary,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(
        color: AppColors.darkTextPrimary,
        size: 23,
      ),
    ),

    // -------------------------------------------------------------------------
    // CARD
    // -------------------------------------------------------------------------

    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.darkCard,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(18),
        ),
        side: BorderSide(
          color: AppColors.darkBorder,
          width: 1,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // INPUT
    // -------------------------------------------------------------------------

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),

      hintStyle: const TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),

      labelStyle: const TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),

      floatingLabelStyle: const TextStyle(
        color: AppColors.primaryLight,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),

      prefixIconColor: AppColors.darkTextSecondary,
      suffixIconColor: AppColors.darkTextSecondary,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.darkBorder,
          width: 1,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.darkBorder,
          width: 1,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.primaryLight,
          width: 1.7,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 1,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 1.7,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // ELEVATED BUTTON
    // -------------------------------------------------------------------------

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.darkBorder,
        disabledForegroundColor: AppColors.darkTextSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // OUTLINED BUTTON
    // -------------------------------------------------------------------------

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        foregroundColor: AppColors.primaryLight,
        side: const BorderSide(
          color: AppColors.darkBorder,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // TEXT BUTTON
    // -------------------------------------------------------------------------

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        foregroundColor: AppColors.primaryLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // ICON BUTTON
    // -------------------------------------------------------------------------

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.darkTextPrimary,
        minimumSize: const Size(42, 42),
        padding: const EdgeInsets.all(9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // FLOATING ACTION BUTTON
    // -------------------------------------------------------------------------

    floatingActionButtonTheme:
        const FloatingActionButtonThemeData(
      elevation: 3,
      highlightElevation: 5,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(17),
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // DIVIDER
    // -------------------------------------------------------------------------

    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
      space: 1,
    ),

    // -------------------------------------------------------------------------
    // CHIP
    // -------------------------------------------------------------------------

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkBackground,
      selectedColor: AppColors.primary.withValues(
        alpha: 0.16,
      ),
      disabledColor: AppColors.darkBorder,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.darkTextPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: AppColors.darkBorder,
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // DROPDOWN
    // -------------------------------------------------------------------------

    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: AppColors.darkBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: AppColors.darkBorder,
          ),
        ),
      ),
      menuStyle: MenuStyle(
        elevation: const WidgetStatePropertyAll(8),
        surfaceTintColor:
            const WidgetStatePropertyAll(
          Colors.transparent,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // DIALOG
    // -------------------------------------------------------------------------

    dialogTheme: DialogThemeData(
      elevation: 8,
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      titleTextStyle: const TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),

    // -------------------------------------------------------------------------
    // BOTTOM SHEET
    // -------------------------------------------------------------------------

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      showDragHandle: true,
      dragHandleColor: AppColors.darkBorder,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
    ),

    // -------------------------------------------------------------------------
    // SNACKBAR
    // -------------------------------------------------------------------------

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 5,
      backgroundColor: AppColors.darkCard,
      contentTextStyle: const TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
    ),

    // -------------------------------------------------------------------------
    // PROGRESS INDICATOR
    // -------------------------------------------------------------------------

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryLight,
      linearTrackColor: AppColors.darkBorder,
    ),

    // -------------------------------------------------------------------------
    // LIST TILE
    // -------------------------------------------------------------------------

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      minVerticalPadding: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(13),
        ),
      ),
      iconColor: AppColors.darkTextSecondary,
    ),
  );
}