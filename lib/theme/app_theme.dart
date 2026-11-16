import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// IntizomAI dizayn tizimi.
///
/// Logodagi ko'k rang — yagona brend rangi. Yuzalar sovuq-neytral: och kulrang
/// fon ustida chegarasiz oq yuzalar (qorong'ida — ingichka chiziqli grafit).
/// Rang faqat ma'no tashiydi: brend — amal va progress, yashil — bajarildi,
/// olov — seriya, qizil — xavf. Bezak uchun rang ishlatilmaydi.
abstract final class AppPalette {
  // ── Brend (logodan) ──────────────────────────────────
  static const brand = Color(0xFF0B7C9B); // tugma, belgi — oq matn bilan AA
  static const brandBright = Color(0xFF12B5D8); // halqa, progress, diagramma
  static const brandInk = Color(0xFF0A7592); // och fon ustidagi havola/matn
  static const brandDeep = Color(0xFF0A4F63);
  static const brandTint = Color(0xFFE2F4F9); // tanlangan holat foni
  static const brandOnDark = Color(0xFF2CC4E4); // qorong'i rejimdagi brend
  static const onBrandDark = Color(0xFF04222B);
  static const gold = Color(0xFFB7791F); // faqat Premium

  // ── Neytral (yorug') ─────────────────────────────────
  static const ink = Color(0xFF0B1720);
  static const ink2 = Color(0xFF56636F);
  static const ink3 = Color(0xFF8793A0);
  static const line = Color(0xFFE6EAEE);
  static const lineStrong = Color(0xFFCBD3DB);
  static const canvas = Color(0xFFF4F6F8);
  static const paper = Color(0xFFFFFFFF);
  static const paper2 = Color(0xFFEFF2F5);
  static const paper3 = Color(0xFFE5E9EE);

  // ── Neytral (qorong'i) ───────────────────────────────
  static const darkCanvas = Color(0xFF0A0F14);
  static const darkPaper = Color(0xFF121920);
  static const darkPaper2 = Color(0xFF19222B);
  static const darkPaper3 = Color(0xFF222D38);
  static const darkLine = Color(0xFF222C36);
  static const darkLineStrong = Color(0xFF364452);
  static const darkInk = Color(0xFFEEF3F7);
  static const darkInk2 = Color(0xFF9BA8B4);
  static const darkInk3 = Color(0xFF6B7884);

  // ── Ma'no ranglari ───────────────────────────────────
  static const success = Color(0xFF18794E);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFCF3F3A);
  static const info = brand;
  static const ember = Color(0xFFE8590C); // seriya (olov)
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

  /// Ekran chetidan gorizontal masofa (barcha sahifalarda bir xil).
  static const page = 20.0;

  /// Pastki navigatsiya va "+" tugmasi ostida qoladigan joy.
  static const bottomInset = 96.0;
}

abstract final class AppShadows {
  /// Faqat suzuvchi elementlar uchun ("+" tugmasi, xabar yozish maydoni).
  static const raised = [
    BoxShadow(color: Color(0x140B1720), blurRadius: 18, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A0B1720), blurRadius: 3, offset: Offset(0, 1)),
  ];
}

/// Matn o'lchamlari — butun ilovada faqat shu shkala.
abstract final class AppType {
  static const display = TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -.8);
  static const title = TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -.5);
  static const heading = TextStyle(fontSize: 17, height: 1.25, fontWeight: FontWeight.w600, letterSpacing: -.3);
  static const body = TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w400, letterSpacing: -.1);
  static const bodyStrong = TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -.15);
  static const label = TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w500, letterSpacing: 0);
  static const caption = TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w500, letterSpacing: 0);

  /// Bo'lim ustidagi kichik sarlavha (BUGUN, REJALAR ...).
  static const overline = TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: .7);
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
    final paper2 = dark ? AppPalette.darkPaper2 : AppPalette.paper2;
    final paper3 = dark ? AppPalette.darkPaper3 : AppPalette.paper3;
    final ink = dark ? AppPalette.darkInk : AppPalette.ink;
    final ink2 = dark ? AppPalette.darkInk2 : AppPalette.ink2;
    final ink3 = dark ? AppPalette.darkInk3 : AppPalette.ink3;
    final line = dark ? AppPalette.darkLine : AppPalette.line;
    final lineStrong = dark ? AppPalette.darkLineStrong : AppPalette.lineStrong;
    final brand = dark ? AppPalette.brandOnDark : AppPalette.brand;
    final brandText = dark ? AppPalette.brandOnDark : AppPalette.brandInk;

    // Rollar: primary — to'ldirish (tugma, belgi), tertiary — matn/havola,
    // outline — nofaol ikonka va boshqaruv chegarasi, outlineVariant — ajratgich.
    final scheme = ColorScheme(
      brightness: brightness,
      primary: brand,
      onPrimary: dark ? AppPalette.onBrandDark : Colors.white,
      primaryContainer: dark ? const Color(0xFF0E2F3A) : AppPalette.brandTint,
      onPrimaryContainer: dark ? const Color(0xFFBFEFFA) : AppPalette.brandDeep,
      secondary: ink2,
      onSecondary: paper,
      secondaryContainer: paper2,
      onSecondaryContainer: ink,
      tertiary: brandText,
      onTertiary: dark ? AppPalette.onBrandDark : Colors.white,
      error: dark ? const Color(0xFFF2817B) : AppPalette.danger,
      onError: Colors.white,
      errorContainer: dark ? const Color(0xFF3A1B1B) : const Color(0xFFFBEBEA),
      onErrorContainer: dark ? const Color(0xFFFFD9D6) : const Color(0xFF8C2420),
      surface: canvas,
      onSurface: ink,
      onSurfaceVariant: ink2,
      surfaceContainerLowest: paper,
      surfaceContainerLow: paper2,
      surfaceContainer: paper2,
      surfaceContainerHigh: paper3,
      surfaceContainerHighest: dark ? const Color(0xFF2C3946) : const Color(0xFFD9DFE6),
      outline: ink3,
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
    OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      dividerColor: line,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: ink.withValues(alpha: .04),
      splashColor: ink.withValues(alpha: .05),
      hoverColor: ink.withValues(alpha: .03),
      iconTheme: IconThemeData(color: ink2, size: 20),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      textTheme: t.copyWith(
        displaySmall: t.displaySmall?.merge(AppType.display),
        headlineMedium: t.headlineMedium?.merge(AppType.display),
        headlineSmall: t.headlineSmall?.merge(AppType.title),
        titleLarge: t.titleLarge?.merge(AppType.title),
        titleMedium: t.titleMedium?.merge(AppType.heading),
        titleSmall: t.titleSmall?.merge(AppType.bodyStrong),
        bodyLarge: t.bodyLarge?.merge(AppType.body),
        bodyMedium: t.bodyMedium?.merge(AppType.body),
        bodySmall: t.bodySmall?.merge(AppType.label).copyWith(color: ink2),
        labelLarge: t.labelLarge?.merge(AppType.bodyStrong),
        labelMedium: t.labelMedium?.merge(AppType.label).copyWith(color: ink2),
        labelSmall: t.labelSmall?.merge(AppType.caption).copyWith(color: ink2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.heading.copyWith(fontFamily: fontFamily, color: ink),
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: dark ? BorderSide(color: line) : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper2,
        hintStyle: TextStyle(color: ink3, fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(brandText, 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: paper3,
          disabledForegroundColor: ink3,
          minimumSize: const Size(0, 50),
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
          minimumSize: const Size(0, 50),
          shape: shape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: lineStrong),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: shape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandText,
          minimumSize: const Size(0, 44),
          shape: shape,
          textStyle: buttonText.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ink2, minimumSize: const Size(44, 44)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg + 2)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? brand : (dark ? AppPalette.darkLineStrong : AppPalette.lineStrong),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paper,
        modalBackgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        modalBarrierColor: Colors.black.withValues(alpha: dark ? .6 : .32),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: AppType.heading.copyWith(fontFamily: fontFamily, color: ink),
        contentTextStyle: AppType.body.copyWith(fontFamily: fontFamily, color: ink2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: .18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: dark ? BorderSide(color: lineStrong) : BorderSide.none,
        ),
        textStyle: AppType.body.copyWith(fontFamily: fontFamily, color: ink),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: dark ? AppPalette.darkPaper3 : AppPalette.ink,
        contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppPalette.darkInk : Colors.white),
        actionTextColor: AppPalette.brandOnDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: brandText,
        selectionColor: brand.withValues(alpha: .25),
        selectionHandleColor: brandText,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brand,
        linearTrackColor: paper3,
        circularTrackColor: Colors.transparent,
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
    );
  }
}
