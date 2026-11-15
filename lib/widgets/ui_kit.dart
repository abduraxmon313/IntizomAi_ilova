import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'app_ui.dart';

/// Katta sarlavha (iOS large title uslubi) + izoh + o'ng tomonda amallar.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lead = leading ??
        (ModalRoute.of(context)?.canPop == true
            ? IconButton(
                tooltip: 'Orqaga',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(LucideIcons.chevronLeft, color: scheme.onSurface),
              )
            : null);
    return Padding(
      padding: EdgeInsets.fromLTRB(lead == null ? AppSpace.page : 8, 16, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ?lead,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.9, height: 1.15),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant, letterSpacing: -.1),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Sarlavhadagi yumaloq ikonka tugmasi.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  /// Asosiy amal (masalan "qo'shish") — brend rangda.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: filled ? scheme.primary : scheme.surfaceContainerLowest,
          shape: CircleBorder(side: filled ? BorderSide.none : BorderSide(color: scheme.outlineVariant)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              tapFeedback();
              onTap();
            },
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 19, color: filled ? scheme.onPrimary : scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmentli tanlagich. Tanlangan bo'lak siljib boradi.
class SegmentTabs<T> extends StatelessWidget {
  const SegmentTabs({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String, IconData?)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final index = items.indexWhere((e) => e.$1 == value).clamp(0, items.length - 1);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dark ? AppPalette.darkPaper2 : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: dark ? Border.all(color: AppPalette.darkLine) : null,
      ),
      child: LayoutBuilder(
        builder: (_, box) {
          final w = box.maxWidth / items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.base,
                curve: AppMotion.curve,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? scheme.surfaceContainerHighest : scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.sm + 1),
                    boxShadow: dark ? null : AppShadows.raised,
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                children: [
                  for (final (v, label, icon) in items)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (v == value) return;
                          tapFeedback();
                          onChanged(v);
                        },
                        child: AnimatedDefaultTextStyle(
                          duration: AppMotion.fast,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            letterSpacing: -.1,
                            fontWeight: v == value ? FontWeight.w600 : FontWeight.w500,
                            color: v == value ? scheme.onSurface : scheme.onSurfaceVariant,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (icon != null) ...[
                                Icon(icon, size: 15, color: v == value ? scheme.onSurface : scheme.onSurfaceVariant),
                                const SizedBox(width: 6),
                              ],
                              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bo'lim sarlavhasi: nom, hisob, o'ngda ixtiyoriy amal.
class SectionBar extends StatelessWidget {
  const SectionBar({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    this.top = 28,
    this.actionIcon = LucideIcons.plus,
  });

  final String title;
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double top;

  /// Amal ikonkasi; null — faqat matn.
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(2, top, 0, 10),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.35),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              count!,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
            ),
          ],
          const Spacer(),
          if (onAction != null)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () {
                tapFeedback();
                onAction!();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionIcon != null) Icon(actionIcon, size: 16, color: scheme.tertiary),
                    if (actionLabel != null) ...[
                      if (actionIcon != null) const SizedBox(width: 4),
                      Text(
                        actionLabel!,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.tertiary, letterSpacing: -.1),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Yumaloq belgilash katagi. Belgilanganda yumshoq "pop" va tebranish.
class CheckCircle extends StatelessWidget {
  const CheckCircle({
    super.key,
    required this.checked,
    this.onTap,
    this.color,
    this.size = 22,
    this.disabled = false,
  });

  final bool checked;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled || onTap == null
          ? null
          : () {
              if (!checked) successFeedback();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(checked),
          tween: Tween(begin: checked ? .7 : 1, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: checked ? c : Colors.transparent,
              border: Border.all(
                color: checked ? c : (disabled ? scheme.outlineVariant : scheme.outline),
                width: 1.6,
              ),
            ),
            child: checked ? Icon(LucideIcons.check, size: size * .6, color: scheme.onPrimary) : null,
          ),
        ),
      ),
    );
  }
}

/// Kichik metadata: ikonka + matn.
class MetaTag extends StatelessWidget {
  const MetaTag({super.key, required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12.5, color: c, fontFeatures: tabularFigures, letterSpacing: -.05)),
      ],
    );
  }
}

/// Kichik yorliq (Ega, Premium, Pauza ...).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.muted = false});
  final String text;
  final Color? color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? scheme.surfaceContainerHigh : c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: .1,
          color: muted ? scheme.onSurfaceVariant : c,
        ),
      ),
    );
  }
}

/// Bo'sh holat: ingichka chegarali ikonka, sarlavha, izoh, amal.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          AppIconTile.tinted(icon: icon, accent: AppPalette.accentBlue, size: 46),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -.2),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant, height: 1.45),
            ),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              icon: const Icon(LucideIcons.plus, size: 17),
              label: Text(actionLabel ?? ''),
            ),
          ],
        ],
      ),
    );
  }
}

/// Qatorlarni bitta chegarali yuzaga birlashtiradi (guruhlangan ro'yxat).
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children, this.padding, this.indent = 52});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  /// Ajratuvchi chiziq chapdan qancha ichkarida boshlanadi.
  final double indent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, indent: indent, color: scheme.outlineVariant));
      items.add(children[i]);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(type: MaterialType.transparency, child: Column(children: items)),
    );
  }
}

/// Sozlamalar qatori: bir rangli ikonka, nom, izoh, o'ngda boshqaruv.
class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.accent,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Ikonka rangi (ixtiyoriy). Berilmasa — neytral.
  final Color? accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = danger ? AppPalette.danger : accent;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              if (tint != null)
                AppIconTile.tinted(icon: icon, accent: tint, size: 34)
              else
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              SizedBox(width: tint != null ? 14 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: -.15,
                        color: danger ? AppPalette.danger : scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.35)),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raqamli ko'rsatkich (statistika).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
    this.hint,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.8, fontFeatures: tabularFigures),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// 2 ustunli panjara.
class TwoColumnGrid extends StatelessWidget {
  const TwoColumnGrid({super.key, required this.children, this.gap = 10});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              SizedBox(width: gap),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
            ],
          ),
        ),
      );
      if (i + 2 < children.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}

/// Pastdan chiqadigan forma: sarlavha + yopish, maydonlar, bitta asosiy tugma.
Future<T?> showFormSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext ctx, StateSetter setSheet) builder,
  String saveLabel = 'Saqlash',
  required Future<bool> Function() onSave,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      var saving = false;
      return StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: IconButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerLow),
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                builder(ctx, setSheet),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final nav = Navigator.of(ctx);
                          setSheet(() => saving = true);
                          final ok = await onSave();
                          if (ok) {
                            successFeedback();
                            if (nav.mounted) nav.pop();
                          } else if (ctx.mounted) {
                            setSheet(() => saving = false);
                          }
                        },
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(saveLabel),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Forma maydoni yorlig'i.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 18),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

/// Formadagi tanlash maydoni (vaqt, sana).
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.placeholder = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: placeholder ? scheme.onSurfaceVariant : scheme.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontFeatures: tabularFigures,
                    color: placeholder ? scheme.onSurfaceVariant : scheme.onSurface,
                    fontWeight: placeholder ? FontWeight.w400 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tanlanadigan katak (hafta kuni, belgi, kayfiyat ...).
class ChoiceChipBox extends StatelessWidget {
  const ChoiceChipBox({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.size,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        tapFeedback();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: size,
        height: size,
        padding: size == null ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10) : null,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 1.4),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: selected ? scheme.tertiary : scheme.onSurfaceVariant),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Bo'lim faol bo'lganda yumshoq paydo bo'lish (IndexedStack ichida).
class TabFade extends StatelessWidget {
  const TabFade({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: active ? 1 : 0,
    duration: AppMotion.base,
    curve: AppMotion.curve,
    child: AnimatedSlide(
      offset: active ? Offset.zero : const Offset(0, .012),
      duration: AppMotion.base,
      curve: AppMotion.curve,
      child: child,
    ),
  );
}

/// Tasdiqlash oynasi.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = "O'chirish",
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.onSurfaceVariant),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? AppPalette.danger : null,
            minimumSize: const Size(0, 40),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Qisqa xabar.
void toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 1800)));
}
