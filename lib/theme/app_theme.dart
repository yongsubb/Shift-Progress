import 'package:flutter/material.dart';

class AppColors {
  // Screenshot-inspired palette (dark UI with yellow + purple accents)
  static const Color backgroundDark = Color(0xFF161B22);
  static const Color surfaceDark = Color(0xFF1D232C);
  static const Color cardDark = Color(0xFF252C36);
  static const Color cardDarkAlt = Color(0xFF2B3440);

  static const Color textOnDark = Color(0xFFF1F5F9);
  static const Color textMutedOnDark = Color(0xFFC2CBD6);

  static const Color accentYellow = Color(0xFFF4C542);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPink = Color(0xFFFF5A7A);

  // Light counterparts (keeps the same accents but uses light surfaces)
  static const Color backgroundLight = Color(0xFFF6F7F9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF0F2F5);
  static const Color textOnLight = Color(0xFF101418);
  static const Color textMutedOnLight = Color(0xFF5A6470);
}

class AppGradients {
  static const LinearGradient baseBackground = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF162338), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient topGlow = RadialGradient(
    center: Alignment(0, -0.95),
    radius: 1.05,
    colors: [Color(0x3D526A92), Color(0x000F172A)],
    stops: [0.0, 1.0],
  );

  static const RadialGradient midGlow = RadialGradient(
    center: Alignment(-0.05, -0.20),
    radius: 1.1,
    colors: [Color(0x222A3A57), Color(0x000F172A)],
    stops: [0.0, 1.0],
  );
}

class AppTheme {
  static ThemeData light() => _theme(Brightness.dark);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final colorScheme = _colorScheme(brightness);

    final radius = BorderRadius.circular(24);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerHighest,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ColorScheme _colorScheme(Brightness brightness) {
    if (brightness == Brightness.light) {
      // Keep light theme aligned with the same dark visual language as reference.
      return _colorScheme(Brightness.dark);
    }

    return ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accentYellow,
      onPrimary: const Color(0xFF1B1F24),
      primaryContainer: AppColors.cardDarkAlt,
      onPrimaryContainer: AppColors.textOnDark,
      secondary: AppColors.accentPurple,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.cardDarkAlt,
      onSecondaryContainer: AppColors.textOnDark,
      tertiary: AppColors.accentPink,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.cardDarkAlt,
      onTertiaryContainer: AppColors.textOnDark,
      error: const Color(0xFFFF6B6B),
      onError: const Color(0xFF1B1F24),
      errorContainer: const Color(0xFF5C1A1A),
      onErrorContainer: const Color(0xFFFFDAD6),
      background: AppColors.backgroundDark,
      onBackground: AppColors.textOnDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textOnDark,
      surfaceVariant: AppColors.cardDark,
      onSurfaceVariant: AppColors.textMutedOnDark,
      outline: const Color(0xFF3A4350),
      outlineVariant: const Color(0xFF2D3541),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.surfaceLight,
      onInverseSurface: AppColors.textOnLight,
      inversePrimary: AppColors.accentYellow,
      surfaceTint: AppColors.accentYellow,
    );
  }
}
