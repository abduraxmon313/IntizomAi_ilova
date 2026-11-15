import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../models/goal.dart';
import '../../widgets/app_ui.dart';
import '../plans/plans_page.dart' show CheckMark, EmptyState;

/// Yillik va oylik maqsadlar.
class GoalsPage extends StatelessWidget {
  const GoalsPage({
    super.key,
    required this.goals,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
    required this.onRefresh,
  });

  final List<Goal> goals;
  final void Function(Goal goal) onToggle;
  final void Function(Goal goal) onDelete;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final yearly = goals.where((g) => g.goalType == 'yearly').toList();
    final monthly = goals.where((g) => g.goalType == 'monthly').toList();

    Widget section(String title, List<Goal> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title),
        const SizedBox(height: 10),
        for (final g in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GoalTile(goal: g, onToggle: () => onToggle(g), onDelete: () => onDelete(g)),
          ),
        const SizedBox(height: 10),
      ],
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (goals.isEmpty)
            EmptyState(
              icon: LucideIcons.target,
              text: context.tr('Hozircha maqsadlar yo\'q'),
              actionLabel: context.tr('Yangi maqsad'),
              onAction: onAdd,
            ),
          if (yearly.isNotEmpty) section(context.tr('Yillik'), yearly),
          if (monthly.isNotEmpty) section(context.tr('Oylik'), monthly),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.onToggle, required this.onDelete});

  final Goal goal;
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
          CheckMark(checked: goal.completed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: goal.completed ? scheme.onSurfaceVariant : scheme.onSurface,
                    decoration: goal.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(goal.period, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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
