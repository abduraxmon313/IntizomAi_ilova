import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../models/plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Bugungi rejalar.
class PlansPage extends StatelessWidget {
  const PlansPage({
    super.key,
    required this.plans,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
    required this.onRefresh,
  });

  final List<Plan> plans;
  final void Function(Plan plan) onToggle;
  final void Function(Plan plan) onDelete;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final done = plans.where((p) => p.isDone).length;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (plans.isEmpty)
            EmptyState(
              icon: LucideIcons.clipboardList,
              text: context.tr('Hozircha rejalar yo\'q'),
              actionLabel: context.tr('Yangi reja'),
              onAction: onAdd,
            )
          else ...[
            ProgressCard(label: context.tr('Bugun'), done: done, total: plans.length),
            const SizedBox(height: 14),
            for (final p in plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlanTile(
                  plan: p,
                  onToggle: () => onToggle(p),
                  onDelete: () => onDelete(p),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.onToggle, required this.onDelete});

  final Plan plan;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      onTap: onToggle,
      child: Row(
        children: [
          CheckMark(checked: plan.isDone, failed: plan.isFailed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: plan.isDone ? scheme.onSurfaceVariant : scheme.onSurface,
                    decoration: plan.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (plan.scheduledTime != null && plan.scheduledTime!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(LucideIcons.clock, size: 12, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        plan.scheduledTime!,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('O\'chirish'),
            icon: Icon(LucideIcons.trash2, size: 17, color: scheme.onSurfaceVariant),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Belgilash katakchasi (reja/odat/maqsad uchun umumiy).
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, required this.checked, this.failed = false});
  final bool checked;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = checked
        ? AppPalette.disciplineGreen
        : failed
            ? AppPalette.danger
            : null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color ?? scheme.outline, width: 2),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
          : failed
              ? const Icon(Icons.close_rounded, size: 17, color: Colors.white)
              : null,
    );
  }
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.label, required this.done, required this.total});
  final String label;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total > 0 ? done / total : 0.0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text('$done/$total', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          AppProgressBar(
            value: pct,
            color: pct >= 1 ? AppPalette.disciplineGreen : AppPalette.primary,
            height: 8,
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(icon, size: 46, color: scheme.onSurfaceVariant.withValues(alpha: .45)),
          const SizedBox(height: 14),
          Text(text, style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
