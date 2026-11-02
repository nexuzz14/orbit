import 'package:flutter/material.dart';

class AppTokens {
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;

  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;

  static const double minTouchTarget = 44.0;
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 200);
}

class AppColors {
  // Satu warna dasar biru tenang sesuai prinsip Material 3 Fase D
  static const Color seedBlue = Color(0xFF0284C7);
  static const Color primary = Color(0xFF0284C7);
  static const Color primaryDark = Color(0xFF38BDF8);

  // Alias kompatibilitas untuk layar lama sebelum Langkah 6
  static const Color brandCyan = Color(0xFF0284C7);
  static const Color brandIndigo = Color(0xFF0284C7);
  static const Color brandViolet = Color(0xFF0369A1);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Permukaan Mode Terang (Putih & Abu Slate)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSubtle = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);

  // Permukaan Mode Gelap (Slate Netral)
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSubtle = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);

  // Warna Semantik Keuangan
  static const Color income = Color(0xFF15803D);
  static const Color incomeDark = Color(0xFF4ADE80);
  static const Color incomeSubtleLight = Color(0xFFDCFCE7);
  static const Color incomeSubtleDark = Color(0xFF052E16);

  static const Color expense = Color(0xFFDC2626);
  static const Color expenseDark = Color(0xFFF87171);
  static const Color expenseSubtleLight = Color(0xFFFEE2E2);
  static const Color expenseSubtleDark = Color(0xFF450A0A);

  static const Color warning = Color(0xFFB45309);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color warningSubtleLight = Color(0xFFFEF3C7);
  static const Color warningSubtleDark = Color(0xFF451A03);

  // Warna Tetap per Jenis Kegiatan (Selalu Disertai Label Teks)
  static const Color kindIntern = Color(0xFF0369A1);
  static const Color kindFreelance = Color(0xFF6D28D9);
  static const Color kindKuliah = Color(0xFFB45309);
  static const Color kindPribadi = Color(0xFF334155);

  static Color getKindColor(String kind, {bool isDark = false}) {
    switch (kind.toLowerCase()) {
      case 'intern':
        return isDark ? const Color(0xFF7DD3FC) : kindIntern;
      case 'freelance':
        return isDark ? const Color(0xFFC4B5FD) : kindFreelance;
      case 'kuliah':
        return isDark ? const Color(0xFFFCD34D) : kindKuliah;
      case 'pribadi':
      case 'personal':
      default:
        return isDark ? const Color(0xFFCBD5E1) : kindPribadi;
    }
  }

  static Color getKindBgColor(String kind, {bool isDark = false}) {
    switch (kind.toLowerCase()) {
      case 'intern':
        return isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE);
      case 'freelance':
        return isDark ? const Color(0xFF2E1065) : const Color(0xFFEDE9FE);
      case 'kuliah':
        return isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      case 'pribadi':
      case 'personal':
      default:
        return isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    }
  }

  static String getKindLabel(String kind) {
    switch (kind.toLowerCase()) {
      case 'intern':
        return 'Intern';
      case 'freelance':
        return 'Freelance';
      case 'kuliah':
        return 'Kuliah';
      case 'pribadi':
      case 'personal':
      default:
        return 'Pribadi';
    }
  }

  static Color accentColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? primaryDark : primary;

  static Color incomeColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? incomeDark : income;

  static Color expenseColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? expenseDark : expense;

  static Color warningColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? warningDark : warning;
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seedBlue,
      brightness: Brightness.light,
      primary: AppColors.primary,
      surface: AppColors.lightSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      cardColor: AppColors.lightSurface,
      dividerColor: AppColors.lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFE0F2FE),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
          side: const BorderSide(color: AppColors.lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space3,
          vertical: AppTokens.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seedBlue,
      brightness: Brightness.dark,
      primary: AppColors.primaryDark,
      surface: AppColors.darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkSurface,
      dividerColor: AppColors.darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF0C4A6E),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.darkBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.darkBackground,
          minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
          side: const BorderSide(color: AppColors.darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space3,
          vertical: AppTokens.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
        ),
      ),
    );
  }
}
