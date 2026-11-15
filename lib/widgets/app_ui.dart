import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Yuza: oq fon + ingichka chegara. Bosilganda yengil kichrayadi.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = AppRadius.lg,
    this.color,
    this.elevated = false,
    this.border = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool elevated;
  final bool border;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = BorderRadius.circular(widget.radius);
    return AnimatedScale(
      scale: _down ? .985 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.color ?? scheme.surfaceContainerLowest,
          borderRadius: r,
          border: widget.border ? Border.all(color: scheme.outlineVariant) : null,
          boxShadow: dark ? null : (widget.elevated ? AppShadows.raised : AppShadows.card),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            onTap: widget.onTap,
            onHighlightChanged: widget.onTap == null ? null : (v) => setState(() => _down = v),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Ikonka plitasi. `tinted` — aksent rangning juda yengil foni.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.size = 40,
    this.iconSize,
  }) : _accent = null;

  const AppIconTile.tinted({
    super.key,
    required this.icon,
    required Color accent,
    this.size = 40,
    this.iconSize,
  }) : _accent = accent, // ignore: prefer_initializing_formals
       color = null,
       background = null;

  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;
  final double? iconSize;
  final Color? _accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent;
    final bg = accent != null ? accent.withValues(alpha: dark ? .16 : .09) : (background ?? scheme.surfaceContainerLow);
    final fg = accent != null
        ? (dark ? Color.lerp(accent, Colors.white, .35)! : accent)
        : (color ?? scheme.onSurfaceVariant);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size >= 44 ? AppRadius.md : AppRadius.sm),
        border: Border.all(
          color: accent != null ? accent.withValues(alpha: dark ? .22 : .14) : scheme.outlineVariant.withValues(alpha: .7),
        ),
      ),
      child: Icon(icon, size: iconSize ?? size * .48, color: fg),
    );
  }
}

/// Ingichka, animatsiyali chiziqli progress.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 4,
  });

  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: backgroundColor ?? scheme.surfaceContainerHigh)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
              duration: AppMotion.slow,
              curve: AppMotion.curve,
              builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    color: color ?? scheme.primary,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Halqali ko'rsatkich (0..100). Raqam o'rtada, ostida izoh.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.value,
    this.size = 80,
    this.label,
    this.color,
    this.stroke,
  });

  final int value;
  final double size;
  final String? label;
  final Color? color;
  final double? stroke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value / 100),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      builder: (_, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: RingPainter(v, c, scheme.surfaceContainerHigh, stroke ?? size * .075),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(v * 100).round()}',
                  style: TextStyle(
                    fontSize: size * .3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -size * .012,
                    fontFeatures: tabularFigures,
                    height: 1.05,
                  ),
                ),
                if (label != null)
                  Text(label!, style: TextStyle(fontSize: size * .12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  RingPainter(this.progress, this.color, this.track, this.stroke);

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track);
    if (progress <= 0) return;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress.clamp(0, 1), false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track || old.stroke != stroke;
}

/// IntizomAI logosi (yumaloq burchakli).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .26),
    child: Image.asset('assets/images/logo.png', width: size, height: size, fit: BoxFit.cover),
  );
}

/// Odat belgisi (serverda emoji saqlanadi) → ilovada bir xil uslubdagi ikonka.
const habitGlyphs = <String, IconData>{
  '🏃': LucideIcons.footprints,
  '💪': LucideIcons.dumbbell,
  '🌅': LucideIcons.sunrise,
  '🛏️': LucideIcons.bed,
  '🛏': LucideIcons.bed,
  '💧': LucideIcons.droplet,
  '🍽️': LucideIcons.utensils,
  '🍽': LucideIcons.utensils,
  '🙏': LucideIcons.handHeart,
  '📚': LucideIcons.library,
  '📖': LucideIcons.bookOpen,
  '💻': LucideIcons.laptop,
  '🧠': LucideIcons.brain,
  '✍️': LucideIcons.penLine,
  '✍': LucideIcons.penLine,
  '💼': LucideIcons.briefcase,
  '🎯': LucideIcons.target,
  '💸': LucideIcons.wallet,
  '🧹': LucideIcons.brush,
  '❤️': LucideIcons.heart,
  '❤': LucideIcons.heart,
  '🚭': LucideIcons.cigaretteOff,
  '🫂': LucideIcons.users,
  '🛒': LucideIcons.shoppingCart,
  '🚗': LucideIcons.car,
  '✅': LucideIcons.circleCheck,
};

/// Odat ikonkasi plitasi. Noma'lum emoji bo'lsa — emojining o'zi.
class HabitGlyph extends StatelessWidget {
  const HabitGlyph({super.key, required this.icon, this.size = 36, this.done = false});

  final String icon;
  final double size;
  final bool done;

  static const _accents = [
    AppPalette.accentBlue,
    AppPalette.accentTeal,
    AppPalette.accentViolet,
    AppPalette.accentAmber,
    AppPalette.accentRose,
    AppPalette.accentIndigo,
  ];

  /// Har bir belgi uchun doimiy rang (MyFit kategoriya aksentlari).
  static Color accentFor(String icon) {
    final k = icon.trim();
    var h = 0;
    for (final c in k.runes) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _accents[h % _accents.length];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glyph = habitGlyphs[icon.trim()];
    final accent = accentFor(icon);
    final fg = done ? scheme.onPrimary : (dark ? Color.lerp(accent, Colors.white, .35)! : accent);
    final radius = BorderRadius.circular(size >= 44 ? AppRadius.md : AppRadius.sm);
    return AnimatedContainer(
      duration: AppMotion.base,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? scheme.primary : accent.withValues(alpha: dark ? .16 : .09),
        borderRadius: radius,
        border: Border.all(color: done ? scheme.primary : accent.withValues(alpha: dark ? .22 : .14)),
      ),
      child: glyph != null
          ? Icon(glyph, size: size * .48, color: fg)
          : Text(icon, style: TextStyle(fontSize: size * .46)),
    );
  }
}

/// Yengil tebranish (Android/iOS).
void tapFeedback() => HapticFeedback.selectionClick();
void successFeedback() => HapticFeedback.lightImpact();
