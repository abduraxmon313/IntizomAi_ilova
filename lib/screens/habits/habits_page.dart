import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../models/habit.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../plans/plans_page.dart' show CheckMark, EmptyState, ProgressCard;

/// Odatlar.
class HabitsPage extends StatelessWidget {
  const HabitsPage({
    super.key,
    required this.habits,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
    required this.onRefresh,
  });

  final List<Habit> habits;
  final void Function(Habit habit) onToggle;
  final void Function(Habit habit) onDelete;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final due = habits.where((h) => h.dueToday).toList();
    final done = due.where((h) => h.doneToday).length;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (habits.isEmpty)
            EmptyState(
              icon: LucideIcons.repeat,
              text: context.tr('Hozircha odatlar yo\'q'),
              actionLabel: context.tr('Yangi odat'),
              onAction: onAdd,
            )
          else ...[
            ProgressCard(label: context.tr('Bugun'), done: done, total: due.length),
            const SizedBox(height: 14),
            for (final h in habits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HabitTile(
                  habit: h,
                  onToggle: () => onToggle(h),
                  onDelete: () => onDelete(h),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit, required this.onToggle, required this.onDelete});

  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = habit.dueToday && !habit.finished;
    return Opacity(
      opacity: enabled ? 1 : .55,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        onTap: enabled ? onToggle : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: habit.doneToday
                    ? AppPalette.disciplineGreen.withValues(alpha: .1)
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(habit.icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(LucideIcons.flame, size: 12, color: AppPalette.streakOrange),
                      const SizedBox(width: 3),
                      Text(
                        '${habit.streak} ${context.tr('kun')}',
                        style: const TextStyle(fontSize: 12, color: AppPalette.streakOrange),
                      ),
                      if (!habit.dueToday) ...[
                        const SizedBox(width: 8),
                        Text(
                          context.tr('Bugun dam'),
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            CheckMark(checked: habit.doneToday),
            IconButton(
              tooltip: context.tr('O\'chirish'),
              icon: Icon(LucideIcons.trash2, size: 17, color: scheme.onSurfaceVariant),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
