import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Yuza: fon ustidagi oq blok. Yorug' rejimda chegarasiz, qorong'ida —
/// ingichka chiziq. Bosiladigan bo'lsa yengil kichrayadi.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = AppRadius.lg,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    return AnimatedScale(
      scale: _down ? .985 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: DecoratedBox(
        decoration: surfaceDecoration(context, radius: widget.radius, color: widget.color),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            onTap: widget.onTap == null
                ? null
                : () {
                    tapFeedback();
                    widget.onTap!();
                  },
            onHighlightChanged: widget.onTap == null ? null : (v) => setState(() => _down = v),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Barcha yuzalar uchun yagona bezak (karta, guruhlangan ro'yxat, diagramma).
BoxDecoration surfaceDecoration(BuildContext context, {double radius = AppRadius.lg, Color? color}) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: color ?? scheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(radius),
    border: dark ? Border.all(color: scheme.outlineVariant) : null,
  );
}

/// Neytral ikonka plitasi. [tone] berilsa — shu ma'no rangida (xavf, Premium).
class AppIconTile extends StatelessWidget {
  const AppIconTile({super.key, required this.icon, this.tone, this.size = 40});

  final IconData icon;
  final Color? tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = tone;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t == null ? scheme.surfaceContainerLow : t.withValues(alpha: dark ? .18 : .1),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(
        icon,
        size: size * .48,
        color: t == null ? scheme.onSurfaceVariant : (dark ? Color.lerp(t, Colors.white, .35) : t),
      ),
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
    this.height = 6,
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

/// Halqali progress (0..1). O'rtasiga istalgan mazmun qo'yiladi.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    this.stroke = 8,
    this.color,
    this.track,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      builder: (_, v, child) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: RingPainter(v, color ?? scheme.primary, track ?? scheme.surfaceContainerHigh, stroke),
          child: Center(child: child),
        ),
      ),
      child: child,
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

/// Odat belgisi: neytral plita, bajarilganda — brend rangda.
/// Noma'lum emoji bo'lsa — emojining o'zi.
class HabitGlyph extends StatelessWidget {
  const HabitGlyph({super.key, required this.icon, this.size = 40, this.done = false});

  final String icon;
  final double size;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glyph = habitGlyphs[icon.trim()];
    return AnimatedContainer(
      duration: AppMotion.base,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: glyph != null
          ? Icon(glyph, size: size * .48, color: done ? scheme.tertiary : scheme.onSurfaceVariant)
          : Text(icon, style: TextStyle(fontSize: size * .46)),
    );
  }
}

/// Yengil tebranish (Android/iOS).
void tapFeedback() => HapticFeedback.selectionClick();
void successFeedback() => HapticFeedback.lightImpact();
