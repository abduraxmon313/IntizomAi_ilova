import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../l10n/app_localizations.dart';
import '../../models/habit.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Odatlar sahifasi — odatlar ro'yxati, belgilash, yaratish.
class HabitsPage extends StatelessWidget {
  const HabitsPage({
    super.key,
    required this.habits,
    required this.onToggle,
    required this.onAdd,
    required this.onArchive,
    this.onRefresh,
  });

  final List<Habit> habits;
  final Future<void> Function(int habitId) onToggle;
  final VoidCallback onAdd;
  final Future<void> Function(int habitId) onArchive;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = habits.where((h) => !h.archived).toList();
    final done = active.where((h) => h.todayDone).length;

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // Progress
          if (active.isNotEmpty) ...[
            _HabitProgress(done: done, total: active.length),
            const SizedBox(height: 16),
          ],

          if (active.isEmpty)
            _EmptyState(onAdd: onAdd)
          else
            ...active.map((habit) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HabitTile(
                habit: habit,
                onToggle: () => onToggle(habit.id),
                onArchive: () => onArchive(habit.id),
              ),
            )),
        ],
      ),
    );
  }
}

class _HabitProgress extends StatelessWidget {
  const _HabitProgress({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total > 0 ? done / total : 0.0;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Bugun'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                '$done/$total',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppProgressBar(
            value: pct,
            color: pct >= 1.0 ? AppPalette.disciplineGreen : AppPalette.accentTeal,
            height: 8,
          ),
        ],
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({
    required this.habit,
    required this.onToggle,
    required this.onArchive,
  });

  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = habit.todayDone;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onToggle,
      child: Row(
        children: [
          // Emoji icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: done
                  ? AppPalette.disciplineGreen.withValues(alpha: .1)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(habit.icon, style: const TextStyle(fontSize: 20)),
            ),
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
                    color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                  ),
                ),
                if (habit.currentStreak > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(LucideIcons.flame, size: 12, color: AppPalette.streakOrange),
                      const SizedBox(width: 3),
                      Text(
                        '${habit.currentStreak} ${context.tr('kun')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.streakOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Done indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: done ? AppPalette.disciplineGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: done
                    ? AppPalette.disciplineGreen
                    : scheme.outlineVariant,
                width: 2,
              ),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : null,
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
            Icon(
              LucideIcons.repeat,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: .4),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('Hozircha odatlar yo\'q'),
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: Text(context.tr('Yangi odat')),
            ),
          ],
        ),
      ),
    );
  }
}
