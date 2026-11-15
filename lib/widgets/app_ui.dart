import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Universal karta — MyFit uslubidagi hover/press animatsiyali.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.lg,
    this.color,
    this.elevated = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool elevated;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.color ?? scheme.surfaceContainerLowest;
    final raised = widget.elevated || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: _hovered ? scheme.outline : scheme.outlineVariant,
          ),
          boxShadow: dark
              ? null
              : raised
                  ? AppShadows.raised
                  : AppShadows.card,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.radius),
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ikonka uchun rangli yoki neytral fon.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.size = 40,
    this.iconSize,
  }) : _tinted = false,
       _accent = null;

  const AppIconTile.tinted({
    super.key,
    required this.icon,
    required Color accent,
    this.size = 40,
    this.iconSize,
  }) : _tinted = true,
       _accent = accent,
       color = null,
       background = null;

  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;
  final double? iconSize;
  final bool _tinted;
  final Color? _accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iSize = iconSize ?? size * .46;
    final radius = size >= 44 ? AppRadius.md : AppRadius.sm;

    Color bg;
    Color fg;
    if (_tinted && _accent != null) {
      bg = _accent!.withValues(alpha: dark ? .16 : .09);
      fg = dark ? Color.lerp(_accent!, Colors.white, .35)! : _accent!;
    } else {
      bg = background ?? scheme.surfaceContainerLow;
      fg = color ?? scheme.onSurfaceVariant;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: _tinted
              ? (_accent ?? scheme.outlineVariant).withValues(alpha: dark ? .2 : .15)
              : scheme.outlineVariant,
        ),
      ),
      child: Icon(icon, size: iSize, color: fg),
    );
  }
}

/// Bo'lim sarlavhasi.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.2,
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Metrika uchun kichik sarlavha.
class AppOverline extends StatelessWidget {
  const AppOverline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: .6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Streak, XP, Level ko'rsatgichlari uchun progress bar.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 6,
  });

  final double value; // 0.0 - 1.0
  final Color? color;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: backgroundColor ?? scheme.surfaceContainerHigh,
        valueColor: AlwaysStoppedAnimation(color ?? scheme.primary),
      ),
    );
  }
}

/// Discipline Score ko'rsatgichi (0-100).
class DisciplineGauge extends StatelessWidget {
  const DisciplineGauge({
    super.key,
    required this.score,
    this.size = 80,
  });

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = score >= 70
        ? AppPalette.disciplineGreen
        : score >= 40
            ? AppPalette.warning
            : AppPalette.danger;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 6,
              backgroundColor: scheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: size * .28,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                'ball',
                style: TextStyle(
                  fontSize: size * .13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
