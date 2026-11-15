import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// IntizomAI dizayn tokenlari. MyFit uslubidagi professional,
/// toza ranglar — multfilm emas, jiddiy va zamonaviy.
abstract final class AppPalette {
  // Brend / aksent — IntizomAI uchun chuqur ko'k va yashil
  static const navy = Color(0xFF0B1324);
  static const navySoft = Color(0xFF1E293B);
  static const primary = Color(0xFF1A73E8);       // professional ko'k
  static const primarySoft = Color(0xFFE8F0FE);
  static const primaryDark = Color(0xFF7AAFFF);
  static const accent = Color(0xFF16A34A);         // intizom yashili
  static const accentSoft = Color(0xFFE8F8EE);

  // Neytral (yorug')
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F4F6);
  static const surfaceSunken = Color(0xFFEDEFF3);
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);
  static const text = Color(0xFF0B1324);
  static const textSecondary = Color(0xFF5B6475);
  static const textTertiary = Color(0xFF8A93A3);

  // Neytral (qorong'i)
  static const darkBackground = Color(0xFF0A0D14);
  static const darkSurface = Color(0xFF11151E);
  static const darkSurfaceMuted = Color(0xFF171C27);
  static const darkSurfaceSunken = Color(0xFF1D2330);
  static const darkBorder = Color(0xFF242B38);
  static const darkText = Color(0xFFEEF1F6);
  static const darkTextSecondary = Color(0xFF9AA3B2);

  // Gamification ranglar
  static const xpBlue = Color(0xFF3B6FE0);
  static const streakOrange = Color(0xFFE87C1A);
  static const disciplineGreen = Color(0xFF16A34A);
  static const levelGold = Color(0xFFC9892B);

  // Aksent ranglar (ikonkalar uchun)
  static const accentBlue = Color(0xFF2F5BEA);
  static const accentTeal = Color(0xFF0F8A7E);
  static const accentAmber = Color(0xFFC07A12);
  static const accentViolet = Color(0xFF6D5BD0);
  static const accentRose = Color(0xFFC94B65);
  static const accentGreen = Color(0xFF2E8B57);
  static const accentIndigo = Color(0xFF4A5BC9);

  // Semantik
  static const success = Color(0xFF16804B);
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFD14343);
}

abstract final class AppRadius {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
  static const xl = 16.0;
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x080B1324), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x050B1324), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x0F0B1324), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x140B1324), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

abstract final class AppTheme {
  static const fontFamily = 'Inter';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static SystemUiOverlayStyle systemOverlay(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background =
        dark ? AppPalette.darkBackground : AppPalette.background;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: brightness,
      surface: background,
    ).copyWith(
      primary: dark ? AppPalette.primaryDark : AppPalette.primary,
      onPrimary: dark ? AppPalette.navy : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF1A2440) : AppPalette.primarySoft,
      onPrimaryContainer:
          dark ? const Color(0xFFC9D7FF) : const Color(0xFF1B3A9A),
      secondary: dark ? const Color(0xFFB4BDCC) : AppPalette.navySoft,
      onSecondary: dark ? AppPalette.navy : Colors.white,
      secondaryContainer:
          dark ? AppPalette.darkSurfaceSunken : AppPalette.surfaceMuted,
      onSecondaryContainer: dark ? AppPalette.darkText : AppPalette.text,
      tertiary: dark ? const Color(0xFF7CC4A8) : AppPalette.accent,
      onSurface: dark ? AppPalette.darkText : AppPalette.text,
      onSurfaceVariant:
          dark ? AppPalette.darkTextSecondary : AppPalette.textSecondary,
      surfaceContainerLowest:
          dark ? AppPalette.darkSurface : AppPalette.surface,
      surfaceContainerLow:
          dark ? AppPalette.darkSurfaceMuted : AppPalette.surfaceMuted,
      surfaceContainer:
          dark ? AppPalette.darkSurfaceMuted : AppPalette.surfaceMuted,
      surfaceContainerHigh:
          dark ? AppPalette.darkSurfaceSunken : AppPalette.surfaceSunken,
      outline: dark ? const Color(0xFF3A4253) : AppPalette.borderStrong,
      outlineVariant: dark ? AppPalette.darkBorder : AppPalette.border,
      surfaceTint: Colors.transparent,
      error: dark ? const Color(0xFFF08A8A) : AppPalette.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
    );
    final text = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return base.copyWith(
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: scheme.outlineVariant,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 20),
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -.4,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -.1,
        ),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        bodySmall: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.4,
        ),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        labelMedium: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
            color: sel ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
    );
  }
}
