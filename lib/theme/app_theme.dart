import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// IntizomAI dizayn tizimi — "Lagoon".
///
/// Rang logodagi zangori-feruzadan olingan. Asosiy (primary) rang oq matn bilan
/// o'qiladigan chuqur tus; yorqin tus faqat halqa, grafik va urg'ularda.
/// Neytral ranglar sovuq-kulrang, bitta aksentdan boshqa rang faqat ma'no
/// tashiganda ishlatiladi (bajarildi, ogohlantirish, streak, Premium).
abstract final class AppPalette {
  // ── Brend ────────────────────────────────────────────
  static const brand = Color(0xFF0A7A9E); // tugma, havola, tanlangan holat
  static const brandBright = Color(0xFF14B4D8); // logo rangi: halqa, grafik
  static const brandDeep = Color(0xFF075A75);
  static const brandTint = Color(0xFFE5F4F8); // yengil fon
  static const brandOnDark = Color(0xFF4CCBE6);

  // ── Neytral (yorug') ─────────────────────────────────
  static const ink = Color(0xFF0E1216);
  static const ink2 = Color(0xFF4A535E);
  static const ink3 = Color(0xFF8A929C);
  static const line = Color(0xFFE7E9EC);
  static const lineStrong = Color(0xFFD3D8DD);
  static const canvas = Color(0xFFF6F7F8);
  static const paper = Color(0xFFFFFFFF);
  static const paper2 = Color(0xFFF0F2F4);
  static const paper3 = Color(0xFFE8EBEE);

  // ── Neytral (qorong'i) ───────────────────────────────
  static const darkCanvas = Color(0xFF0A0C0F);
  static const darkPaper = Color(0xFF121519);
  static const darkPaper2 = Color(0xFF191D22);
  static const darkPaper3 = Color(0xFF20252B);
  static const darkLine = Color(0xFF23282E);
  static const darkLineStrong = Color(0xFF323941);
  static const darkInk = Color(0xFFEDEFF2);
  static const darkInk2 = Color(0xFFA0A8B2);
  static const darkInk3 = Color(0xFF6C7580);

  // ── Ma'no ranglari ───────────────────────────────────
  static const success = Color(0xFF17915A);
  static const warning = Color(0xFFC47A0B);
  static const danger = Color(0xFFD23C3C);
  static const ember = Color(0xFFE0692B); // streak
  static const gold = Color(0xFFB8862B); // Premium

  // ── Ikonka plitalari uchun bosiq aksentlar ───────────
  static const accentBlue = Color(0xFF3B6FD6);
  static const accentTeal = Color(0xFF0F8C80);
  static const accentAmber = Color(0xFFB97A12);
  static const accentViolet = Color(0xFF6F5CC9);
  static const accentRose = Color(0xFFC2506A);
  static const accentGreen = Color(0xFF2E8B57);
  static const accentIndigo = Color(0xFF4F5BC4);

  // ── Eski nomlar (mavjud kod uchun) ───────────────────
  static const primary = brand;
  static const primarySoft = brandTint;
  static const primaryDark = brandOnDark;
  static const accent = brandBright;
  static const disciplineGreen = success;
  static const streakOrange = ember;
  static const levelGold = gold;
  static const xpBlue = brand;
  static const navy = ink;
  static const navySoft = ink2;
  static const text = ink;
  static const textSecondary = ink2;
  static const textTertiary = ink3;
  static const background = canvas;
  static const surface = paper;
  static const surfaceMuted = paper2;
  static const surfaceSunken = paper3;
  static const border = line;
  static const borderStrong = lineStrong;
  static const darkBackground = darkCanvas;
  static const darkSurface = darkPaper;
  static const darkSurfaceMuted = darkPaper2;
  static const darkSurfaceSunken = darkPaper3;
  static const darkBorder = darkLine;
  static const darkText = darkInk;
  static const darkTextSecondary = darkInk2;
}

abstract final class AppRadius {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
}

/// 4 pt panjara.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Ekran chetidan gorizontal masofa.
  static const page = 20.0;
}

abstract final class AppShadows {
  /// Deyarli sezilmaydigan ko'tarilish — faqat suzuvchi elementlar uchun.
  static const card = [
    BoxShadow(color: Color(0x0A0E1216), blurRadius: 1, offset: Offset(0, 1)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x0F0E1216), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x140E1216), blurRadius: 20, offset: Offset(0, 8)),
  ];
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 600);
  static const curve = Curves.easeOutCubic;
}

/// Raqamlar bir xil kenglikda (statistika, vaqt, hisoblagich).
const tabularFigures = [FontFeature.tabularFigures()];

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
      systemNavigationBarColor: dark ? AppPalette.darkPaper : AppPalette.paper,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final canvas = dark ? AppPalette.darkCanvas : AppPalette.canvas;
    final paper = dark ? AppPalette.darkPaper : AppPalette.paper;
    final ink = dark ? AppPalette.darkInk : AppPalette.ink;
    final ink2 = dark ? AppPalette.darkInk2 : AppPalette.ink2;
    final line = dark ? AppPalette.darkLine : AppPalette.line;
    final brand = dark ? AppPalette.brandOnDark : AppPalette.brand;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: brand,
      onPrimary: dark ? const Color(0xFF04232E) : Colors.white,
      primaryContainer: dark ? const Color(0xFF0E2E39) : AppPalette.brandTint,
      onPrimaryContainer: dark ? const Color(0xFFB8EAF5) : AppPalette.brandDeep,
      secondary: ink2,
      onSecondary: paper,
      secondaryContainer: dark ? AppPalette.darkPaper2 : AppPalette.paper2,
      onSecondaryContainer: ink,
      tertiary: AppPalette.success,
      onTertiary: Colors.white,
      error: dark ? const Color(0xFFF07A7A) : AppPalette.danger,
      onError: Colors.white,
      errorContainer: dark ? const Color(0xFF3A1A1C) : const Color(0xFFFCEBEB),
      onErrorContainer: dark ? const Color(0xFFFFD6D6) : const Color(0xFF8A1F1F),
      surface: canvas,
      onSurface: ink,
      onSurfaceVariant: ink2,
      surfaceContainerLowest: paper,
      surfaceContainerLow: dark ? AppPalette.darkPaper2 : AppPalette.paper2,
      surfaceContainer: dark ? AppPalette.darkPaper2 : AppPalette.paper2,
      surfaceContainerHigh: dark ? AppPalette.darkPaper3 : AppPalette.paper3,
      surfaceContainerHighest: dark ? const Color(0xFF2A3037) : const Color(0xFFDFE3E7),
      outline: dark ? AppPalette.darkLineStrong : AppPalette.lineStrong,
      outlineVariant: line,
      inverseSurface: dark ? AppPalette.darkInk : AppPalette.ink,
      onInverseSurface: dark ? AppPalette.ink : Colors.white,
      inversePrimary: dark ? AppPalette.brand : AppPalette.brandOnDark,
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final base = ThemeData(useMaterial3: true, brightness: brightness, fontFamily: fontFamily);
    final t = base.textTheme.apply(fontFamily: fontFamily, bodyColor: ink, displayColor: ink);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md));
    const buttonText = TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.1);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      dividerColor: line,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: ink.withValues(alpha: .04),
      splashColor: brand.withValues(alpha: .06),
      hoverColor: ink.withValues(alpha: .03),
      iconTheme: IconThemeData(color: ink2, size: 20),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      textTheme: t.copyWith(
        displaySmall: t.displaySmall?.copyWith(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.2),
        headlineMedium: t.headlineMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.9),
        headlineSmall: t.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.6),
        titleLarge: t.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -.35),
        titleMedium: t.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -.2),
        titleSmall: t.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -.1),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.45, letterSpacing: -.15),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 14.5, height: 1.45, letterSpacing: -.1),
        bodySmall: t.bodySmall?.copyWith(fontSize: 13, color: ink2, height: 1.4),
        labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w500, color: ink2),
        labelSmall: t.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .4, color: ink2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.3, color: ink),
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppPalette.darkPaper2 : AppPalette.paper2,
        hintStyle: TextStyle(color: dark ? AppPalette.darkInk3 : AppPalette.ink3, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: brand, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: ink.withValues(alpha: .08),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: shape,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: shape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: dark ? AppPalette.darkLineStrong : AppPalette.lineStrong),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: shape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          shape: shape,
          textStyle: buttonText.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: ink2)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? brand : (dark ? AppPalette.darkPaper3 : AppPalette.lineStrong),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected) ? brand : (dark ? AppPalette.darkInk3 : AppPalette.ink3),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final sel = s.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
            color: sel ? ink : (dark ? AppPalette.darkInk3 : AppPalette.ink3),
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: dark ? AppPalette.darkLineStrong : AppPalette.lineStrong,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -.3, color: ink),
        contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 14.5, height: 1.45, color: ink2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: .2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: line),
        ),
        textStyle: TextStyle(fontFamily: fontFamily, fontSize: 14.5, color: ink),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppPalette.darkPaper3 : AppPalette.ink,
        contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 14, color: dark ? AppPalette.darkInk : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: brand, linearTrackColor: line),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      listTileTheme: ListTileThemeData(iconColor: ink2, textColor: ink),
    );
  }
}
