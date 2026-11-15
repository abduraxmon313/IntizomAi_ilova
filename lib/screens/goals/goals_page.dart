import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../l10n/app_localizations.dart';
import '../../models/goal.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Maqsadlar sahifasi — yillik va oylik maqsadlar.
class GoalsPage extends StatelessWidget {
  const GoalsPage({
    super.key,
    required this.goals,
    required this.onToggle,
    required this.onAdd,
    required this.onDelete,
    this.onRefresh,
  });

  final List<Goal> goals;
  final Future<void> Function(int goalId) onToggle;
  final VoidCallback onAdd;
  final Future<void> Function(int goalId) onDelete;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final yearly = goals.where((g) => g.goalType == 'yearly').toList();
    final monthly = goals.where((g) => g.goalType == 'monthly').toList();

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          if (goals.isEmpty)
            _EmptyState(onAdd: onAdd)
          else ...[
            if (yearly.isNotEmpty) ...[
              AppSectionHeader(context.tr('Yillik')),
              const SizedBox(height: 10),
              ...yearly.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GoalTile(
                  goal: g,
                  onToggle: () => onToggle(g.id),
                  onDelete: () => onDelete(g.id),
                ),
              )),
              const SizedBox(height: 16),
            ],
            if (monthly.isNotEmpty) ...[
              AppSectionHeader(context.tr('Oylik')),
              const SizedBox(height: 10),
              ...monthly.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GoalTile(
                  goal: g,
                  onToggle: () => onToggle(g.id),
                  onDelete: () => onDelete(g.id),
                ),
              )),
            ],
          ],
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.onToggle,
    required this.onDelete,
  });

  final Goal goal;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: goal.completed ? AppPalette.disciplineGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: goal.completed ? AppPalette.disciplineGreen : scheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: goal.completed
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : null,
            ),
          ),
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
                if (goal.description != null && goal.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    goal.description!,
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.trash2, size: 16, color: scheme.onSurfaceVariant),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(LucideIcons.target, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: .4)),
            const SizedBox(height: 16),
            Text(
              context.tr('Hozircha maqsadlar yo\'q'),
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: Text(context.tr('Yangi maqsad')),
            ),
          ],
        ),
      ),
    );
  }
}
