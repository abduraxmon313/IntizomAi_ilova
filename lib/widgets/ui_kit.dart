import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/store_policy.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';

/// Sahifa sarlavhasi: katta nom, ixtiyoriy izoh va o'ngda amallar.
/// Ichki (push qilingan) sahifalarda chapda "orqaga" tugmasi chiqadi.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Berilsa — shu chaqiriladi; aks holda Navigator orqaga qaytadi.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canPop = onBack != null || (ModalRoute.of(context)?.canPop ?? false);
    return Padding(
      padding: EdgeInsets.fromLTRB(canPop ? 8 : AppSpace.page, 12, 10, 12),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: context.tr("Orqaga"),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Icon(LucideIcons.arrowLeft, size: 22, color: scheme.onSurface),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: canPop ? AppType.title : AppType.display,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
          if (actions.isEmpty) const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Sarlavhadagi ikonka tugmasi (44 pt bosish maydoni).
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: () {
      tapFeedback();
      onTap();
    },
    icon: Icon(icon, size: 21, color: Theme.of(context).colorScheme.onSurface),
  );
}

/// Har bir bo'limdagi yagona asosiy amal — "+" (bosh barmoq yetadigan joyda).
class AddFab extends StatelessWidget {
  const AddFab({super.key, required this.tooltip, required this.onTap, this.heroTag});

  final String tooltip;
  final VoidCallback onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) => FloatingActionButton(
    heroTag: heroTag ?? tooltip,
    tooltip: tooltip,
    onPressed: () {
      tapFeedback();
      onTap();
    },
    child: const Icon(LucideIcons.plus, size: 26),
  );
}

/// Segmentli tanlagich. Tanlangan bo'lak siljib boradi.
class SegmentTabs<T> extends StatelessWidget {
  const SegmentTabs({super.key, required this.value, required this.items, required this.onChanged});

  final T value;
  final List<(T, String)> items;
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
        color: dark ? scheme.surfaceContainerLow : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark ? scheme.surfaceContainerHighest : scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.md - 3),
                    boxShadow: dark ? null : AppShadows.thumb,
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    for (final (v, label) in items)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: v == value,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (v == value) return;
                              tapFeedback();
                              onChanged(v);
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: AppMotion.fast,
                                style: AppType.label.copyWith(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: v == value ? FontWeight.w600 : FontWeight.w500,
                                  color: v == value ? scheme.onSurface : scheme.onSurfaceVariant,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(context.tr(label), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ),
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

/// Bo'lim yorlig'i: sokin nom, yonida hisob, o'ngda ixtiyoriy matnli amal.
class SectionBar extends StatelessWidget {
  const SectionBar({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    this.top = 28,
  });

  final String title;
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double top;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Text(count!, style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabularFigures)),
                ],
              ],
            ),
          ),
          if (onAction != null && actionLabel != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                tapFeedback();
                onAction!();
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6, right: 4),
                child: Text(
                  actionLabel!,
                  style: AppType.label.copyWith(fontWeight: FontWeight.w600, color: scheme.tertiary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Yumaloq belgilash katagi (44 pt bosish maydoni). Belgilanganda yumshoq "pop".
class CheckCircle extends StatelessWidget {
  const CheckCircle({
    super.key,
    required this.checked,
    this.onTap,
    this.size = 24,
    this.disabled = false,
    this.semanticLabel,
  });

  final bool checked;
  final VoidCallback? onTap;
  final double size;
  final bool disabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pad = ((44 - size) / 2).clamp(6.0, 12.0);
    return Semantics(
      checked: checked,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled || onTap == null
            ? null
            : () {
                if (!checked) successFeedback();
                onTap!();
              },
        child: Padding(
          padding: EdgeInsets.all(pad),
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
                color: checked ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: checked
                      ? scheme.primary
                      : disabled
                      ? scheme.outlineVariant
                      : (dark ? AppPalette.darkLineStrong : AppPalette.lineStrong),
                  width: 1.8,
                ),
              ),
              child: checked ? Icon(LucideIcons.check, size: size * .62, color: scheme.onPrimary) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bajariladigan ish qatori — reja ham, odat ham bir xil ko'rinishda:
/// doiracha — bajarish, qatorning o'zi — ochish (tahrirlash).
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.title,
    required this.done,
    required this.onToggle,
    this.onTap,
    this.subtitle,
    this.trailing,
    this.streak,
    this.highlight = false,
    this.locked = false,
  });

  final String title;
  final String? subtitle;
  final bool done;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  /// O'ngdagi vaqt ("09:30").
  final String? trailing;

  /// Odat seriyasi (kun). 0 yoki null — ko'rsatilmaydi.
  final int? streak;

  /// Keyingi bajariladigan ish — vaqt brend rangda.
  final bool highlight;

  /// Belgilab bo'lmaydi (o'tgan kun, rejada yo'q).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
          child: Row(
            children: [
              CheckCircle(checked: done, disabled: locked, onTap: onToggle, semanticLabel: title),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: AppMotion.fast,
                        style: AppType.body.copyWith(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w500,
                          color: done ? scheme.outline : scheme.onSurface,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: scheme.outline,
                        ),
                        child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      if (subtitle?.isNotEmpty == true) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if ((streak ?? 0) > 0) ...[
                const SizedBox(width: 10),
                MetaTag(icon: LucideIcons.flame, text: '$streak', color: done ? scheme.outline : AppPalette.ember),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 10),
                Text(
                  trailing!,
                  style: AppType.label.copyWith(
                    fontFeatures: tabularFigures,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                    color: done
                        ? scheme.outline
                        : highlight
                        ? scheme.tertiary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Davr tanlagich: ‹ nom ›. Nom bosilsa — joriy davrga qaytadi.
class PeriodStepper extends StatelessWidget {
  const PeriodStepper({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.isCurrent = true,
    this.onReset,
    this.resetLabel = 'Bugunga qaytish',
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool isCurrent;
  final VoidCallback? onReset;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(tooltip: context.tr("Oldingi"), onPressed: onPrev, icon: const Icon(LucideIcons.chevronLeft, size: 20)),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isCurrent ? null : onReset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyStrong.copyWith(fontFeatures: tabularFigures),
                ),
                if (!isCurrent && onReset != null)
                  Text(context.tr(resetLabel), style: AppType.caption.copyWith(color: scheme.tertiary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        IconButton(tooltip: context.tr("Keyingi"), onPressed: onNext, icon: const Icon(LucideIcons.chevronRight, size: 20)),
      ],
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
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(text, style: AppType.caption.copyWith(color: AppPalette.textTone(c, theme.brightness), fontFeatures: tabularFigures)),
      ],
    );
  }
}

/// Kichik yorliq (Siz, Ega, Premium, Pauza ...).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.muted = false});
  final String text;
  final Color? color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = color ?? scheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: muted ? scheme.surfaceContainerHigh : c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: AppType.micro.copyWith(
          fontWeight: FontWeight.w600,
          color: muted ? scheme.onSurfaceVariant : AppPalette.textTone(c, theme.brightness),
        ),
      ),
    );
  }
}

/// Bo'sh holat: sokin ikonka, sarlavha, izoh va bitta amal.
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 30, color: scheme.outline),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: AppType.bodyStrong),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400, height: 1.45),
            ),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                minimumSize: const Size(0, 44),
              ),
              child: Text(actionLabel ?? ''),
            ),
          ],
        ],
      ),
    );
  }
}

/// Premium bilan ochiladigan bo'lim uchun yagona blok.
class PremiumGate extends StatelessWidget {
  const PremiumGate({super.key, required this.icon, required this.title, required this.message, required this.onOpen});

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          AppIconTile(icon: icon, tone: AppPalette.gold, size: 48),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: AppType.heading),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400, height: 1.45),
          ),
          // iOS'da (App Store 3.1.1) tashqi to'lovga yo'naltiruvchi tugma
          // ko'rsatilmaydi — qulflangan imkoniyat faqat tushuntiriladi.
          if (StorePolicy.purchasesVisible) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(context.tr("Premium haqida")),
            ),
          ],
        ],
      ),
    );
  }
}

/// Qatorlarni bitta yuzaga birlashtiradi (guruhlangan ro'yxat).
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children, this.indent = 16});

  final List<Widget> children;

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
      decoration: surfaceDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(type: MaterialType.transparency, child: Column(children: items)),
    );
  }
}

/// Ro'yxat qatori: ikonka, nom, izoh, o'ngda boshqaruv yoki strelka.
class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = danger ? scheme.error : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: danger ? scheme.error : scheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppType.body.copyWith(color: fg, fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null && !danger)
                Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastdan chiqadigan varaq uchun umumiy qobiq: tutqich, sarlavha, yopish.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({super.key, required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 10, AppSpace.page, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.title.copyWith(fontSize: 20)),
                      if (subtitle != null)
                        Text(subtitle!, style: AppType.label.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.tr("Yopish"),
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(LucideIcons.x, size: 20, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Forma varag'i: maydonlar va bitta asosiy tugma. [onDelete] berilsa —
/// tahrirlash rejimi: pastda "O'chirish" ham chiqadi (o'chirishning yagona joyi).
Future<T?> showFormSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget Function(BuildContext ctx, StateSetter setSheet) builder,
  String saveLabel = 'Saqlash',
  required Future<bool> Function() onSave,
  Future<bool> Function()? onDelete,
  String deleteLabel = "O'chirish",
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      var busy = false;
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> run(Future<bool> Function() action) async {
            final nav = Navigator.of(ctx);
            setSheet(() => busy = true);
            final ok = await action();
            if (ok) {
              successFeedback();
              if (nav.mounted) nav.pop();
            } else if (ctx.mounted) {
              setSheet(() => busy = false);
            }
          }

          return SheetScaffold(
            title: title,
            subtitle: subtitle,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                builder(ctx, setSheet),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: busy ? null : () => run(onSave),
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(context.tr(saveLabel)),
                ),
                if (onDelete != null) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: busy ? null : () => run(onDelete),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
                    child: Text(context.tr(deleteLabel)),
                  ),
                ],
              ],
            ),
          );
        },
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
      style: AppType.label.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
  final VoidCallback? onTap;
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
              Icon(icon, size: 18, color: placeholder || onTap == null ? scheme.outline : scheme.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(
                    fontFeatures: tabularFigures,
                    color: placeholder || onTap == null ? scheme.onSurfaceVariant : scheme.onSurface,
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
    this.scaleToFit = true,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double? size;

  /// `false` bo'lsa, bola o'zi siqilishni boshqaradi (masalan, faqat matn kichrayadi).
  final bool scaleToFit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          tapFeedback();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: size,
          height: size,
          padding: size == null ? const EdgeInsets.symmetric(horizontal: 2, vertical: 11) : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 1.5),
          ),
          child: DefaultTextStyle.merge(
            style: AppType.label.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
            softWrap: false,
            maxLines: 1,
            child: IconTheme.merge(
              data: IconThemeData(color: selected ? scheme.tertiary : scheme.onSurfaceVariant),
              child: scaleToFit ? FittedBox(fit: BoxFit.scaleDown, child: child) : child,
            ),
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
    child: child,
  );
}

/// Yuklanmoqda (sahifa ichida).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.padding = 48});
  final double padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(padding),
    child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
  );
}

/// Tasdiqlash oynasi — faqat qaytarib bo'lmaydigan amallar uchun.
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
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.onSurfaceVariant),
          child:  Text(context.tr("Bekor qilish")),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? Theme.of(ctx).colorScheme.error : null,
            foregroundColor: danger ? Theme.of(ctx).colorScheme.onError : null,
            minimumSize: const Size(0, 44),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.tr(confirmLabel)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Qisqa xabar. [actionLabel] berilsa — bekor qilish kabi bitta amal.
void toast(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        actionOverflowThreshold: .4,
        persist: false,
        duration: Duration(milliseconds: actionLabel == null ? 1800 : 4000),
        action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}
