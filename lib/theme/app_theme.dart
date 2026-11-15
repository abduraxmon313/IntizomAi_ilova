import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// IntizomAI dizayn tizimi — "Quyosh" (Sun).
///
/// Oq va iliq krem yuzalar, deyarli qora siyoh matn, bitta brend rangi —
/// quyosh sarig'i. Sariq faqat to'ldirish uchun (tugma, belgi, halqa,
/// progress); matn va havolalar uchun o'qiladigan chuqur oltin tus.
/// Ma'no ranglari (muvaffaqiyat, ogohlantirish, xato) faqat ma'no tashiganda.
abstract final class AppPalette {
  // ── Brend ────────────────────────────────────────────
  static const brand = Color(0xFFF5B800); // asosiy to'ldirish: tugma, belgi, halqa
  static const brandBright = Color(0xFFFFC933); // qorong'i rejimdagi brend
  static const brandInk = Color(0xFF8A6100); // sariq ustidagi emas — krem ustidagi matn/havola
  static const brandDeep = Color(0xFF5C4100);
  static const brandTint = Color(0xFFFFF3C4); // tanlangan holat foni
  static const brandOnDark = Color(0xFFFFC933);
  static const gold = Color(0xFFB8860B); // Premium, nishonlar

  // ── Neytral (yorug') — iliq krem ─────────────────────
  static const ink = Color(0xFF1A1814);
  static const ink2 = Color(0xFF68625A);
  static const ink3 = Color(0xFF9A948A);
  static const line = Color(0xFFEDE7DB);
  static const lineStrong = Color(0xFFDAD2C2);
  static const canvas = Color(0xFFFAF7F0);
  static const paper = Color(0xFFFFFFFF);
  static const paper2 = Color(0xFFF5F1E8);
  static const paper3 = Color(0xFFEEE8DC);

  // ── Neytral (qorong'i) — iliq grafit ─────────────────
  static const darkCanvas = Color(0xFF0E0E0C);
  static const darkPaper = Color(0xFF171614);
  static const darkPaper2 = Color(0xFF1F1E1B);
  static const darkPaper3 = Color(0xFF282623);
  static const darkLine = Color(0xFF2B2926);
  static const darkLineStrong = Color(0xFF3D3A35);
  static const darkInk = Color(0xFFF5F2EB);
  static const darkInk2 = Color(0xFFAAA498);
  static const darkInk3 = Color(0xFF77726A);

  // ── Ma'no ranglari ───────────────────────────────────
  static const success = Color(0xFF1E8A4C);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFD14343);
  static const info = Color(0xFF2F6FDB);
  static const ember = Color(0xFFE8590C); // seriya (olov)

  /// "Bugun" kartasi — siyoh yuza (yorug' rejimda ham).
  static const heroStart = Color(0xFF1A1814);
  static const heroEnd = Color(0xFF26231D);

  // ── Ikonka plitalari uchun bosiq aksentlar ───────────
  static const accentBlue = Color(0xFF2F6FDB);
  static const accentTeal = Color(0xFF0F8A7E);
  static const accentAmber = Color(0xFFC98A00);
  static const accentViolet = Color(0xFF6D5BD0);
  static const accentRose = Color(0xFFC94B65);
  static const accentGreen = Color(0xFF2E8B57);
  static const accentIndigo = Color(0xFF4A5BC9);
  static const accentSlate = Color(0xFF68625A);

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
  static const md = 10.0;
  static const lg = 12.0;
  static const xl = 16.0;
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
    BoxShadow(color: Color(0x080B1324), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x050B1324), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x0F0B1324), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x140B1324), blurRadius: 24, offset: Offset(0, 10)),
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
    final brand = dark ? AppPalette.brandBright : AppPalette.brand;
    final brandText = dark ? AppPalette.brandBright : AppPalette.brandInk;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: brand,
      onPrimary: AppPalette.ink,
      primaryContainer: dark ? const Color(0xFF3A3018) : AppPalette.brandTint,
      onPrimaryContainer: dark ? const Color(0xFFFFE7A3) : AppPalette.brandDeep,
      secondary: ink2,
      onSecondary: paper,
      secondaryContainer: dark ? AppPalette.darkPaper2 : AppPalette.paper2,
      onSecondaryContainer: ink,
      tertiary: brandText,
      onTertiary: dark ? AppPalette.ink : Colors.white,
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
      surfaceContainerHighest: dark ? const Color(0xFF33302B) : const Color(0xFFE6DFD0),
      outline: dark ? AppPalette.darkLineStrong : AppPalette.lineStrong,
      outlineVariant: line,
      inverseSurface: dark ? AppPalette.darkInk : AppPalette.ink,
      onInverseSurface: dark ? AppPalette.ink : Colors.white,
      inversePrimary: AppPalette.brandInk,
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
      splashColor: brand.withValues(alpha: .10),
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
        fillColor: paper,
        hintStyle: TextStyle(color: dark ? AppPalette.darkInk2 : AppPalette.ink3, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: brandText, width: 1.5),
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
          foregroundColor: brandText,
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
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 21, color: s.contains(WidgetState.selected) ? (dark ? brand : ink) : ink2),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final sel = s.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
            color: sel ? ink : ink2,
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
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: brandText,
        selectionColor: brand.withValues(alpha: .35),
        selectionHandleColor: brandText,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brand,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
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
      chipTheme: ChipThemeData(
        backgroundColor: paper,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }
}
