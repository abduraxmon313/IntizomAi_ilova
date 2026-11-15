import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/habit.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Mini App uslubidagi Odatlar sahifasi: Bugun/Tracker toggle,
/// summary cards, habits list sorted by reminder time, tracker 7-day table.
class HabitsPage extends StatefulWidget {
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
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  String _view = 'today'; // today | tracker
  late DateTime _trackerWeekStart;

  @override
  void initState() {
    super.initState();
    _trackerWeekStart = _startOfWeek(DateTime.now());
  }

  static DateTime _startOfWeek(DateTime d) {
    final weekday = d.weekday; // 1=Mon .. 7=Sun
    final monday = d.subtract(Duration(days: weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  List<Habit> get _sortedByTime {
    final list = List<Habit>.of(widget.habits);
    list.sort((a, b) {
      final aKey = a.reminderTime ?? '99:99';
      final bKey = b.reminderTime ?? '99:99';
      return aKey.compareTo(bKey);
    });
    return list;
  }

  String _formatRange(DateTime start) {
    final end = start.add(const Duration(days: 6));
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${_monthShort(start.month)}';
    }
    return '${start.day} ${_monthShort(start.month)} – ${end.day} ${_monthShort(end.month)}';
  }

  static String _monthShort(int m) {
    const months = ['Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyn', 'Iyl', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek'];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = widget.habits.where((h) => h.dueToday && !h.finished).toList();
    final doneCount = due.where((h) => h.doneToday).length;
    final bestStreak = widget.habits.fold(0, (m, h) => h.streak > m ? h.streak : m);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Header
            Text(
              'Odatlar ✅',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              "Har kuni takrorla, streak yig'",
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),

            // Bugun / Tracker toggle
            _ViewToggle(
              selected: _view,
              onChanged: (v) => setState(() => _view = v),
            ),
            const SizedBox(height: 14),

            if (_view == 'today') ...[
              // Summary cards
              if (widget.habits.isNotEmpty) ...[
                Row(
                  children: [
                    _SummaryCard(
                      value: '$doneCount/${due.length}',
                      label: 'Bugun bajarildi',
                    ),
                    const SizedBox(width: 10),
                    _SummaryCard(
                      value: '$bestStreak',
                      label: 'Eng uzun streak',
                    ),
                    const SizedBox(width: 10),
                    _SummaryCard(
                      value: '${widget.habits.length}',
                      label: 'Jami odat',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Add button
              _GradientButton(
                label: "Odat qo'shish",
                onTap: widget.onAdd,
              ),
              const SizedBox(height: 14),

              // Habits list
              if (widget.habits.isEmpty)
                _EmptyHabits(onAdd: widget.onAdd)
              else
                for (final h in _sortedByTime) ...[
                  _HabitTile(
                    habit: h,
                    onToggle: () => widget.onToggle(h),
                    onDelete: () => widget.onDelete(h),
                  ),
                  const SizedBox(height: 8),
                ],
            ] else ...[
              // Tracker view
              _TrackerHeader(
                range: _formatRange(_trackerWeekStart),
                onPrev: () => setState(() =>
                    _trackerWeekStart = _trackerWeekStart.subtract(const Duration(days: 7))),
                onNext: () => setState(() =>
                    _trackerWeekStart = _trackerWeekStart.add(const Duration(days: 7))),
              ),
              const SizedBox(height: 14),
              if (widget.habits.isEmpty)
                _EmptyHabits(onAdd: widget.onAdd)
              else
                _TrackerTable(
                  habits: widget.habits,
                  weekStart: _trackerWeekStart,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          _ToggleItem(
            label: '📋 Bugun',
            active: selected == 'today',
            onTap: () => onChanged('today'),
          ),
          _ToggleItem(
            label: '🗓️ Tracker',
            active: selected == 'tracker',
            onTap: () => onChanged('tracker'),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(colors: [scheme.primary, AppPalette.accent])
                : null,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [scheme.primary, AppPalette.accent],
                  ).createShader(const Rect.fromLTWH(0, 0, 60, 22)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [scheme.primary, AppPalette.accent]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: .3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.plus, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit, required this.onToggle, required this.onDelete});
  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  String _freqLabel() {
    if (habit.frequency == 'weekly' && habit.weekdays.isNotEmpty && habit.weekdays.length < 7) {
      const wd = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];
      return habit.weekdays.map((i) => wd[i]).join(', ');
    }
    return 'Har kuni';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = habit.dueToday && !habit.finished;
    return Opacity(
      opacity: enabled ? 1 : .55,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        onTap: enabled ? onToggle : null,
        child: Row(
          children: [
            // Toggle check / icon
            GestureDetector(
              onTap: enabled ? onToggle : null,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: habit.doneToday
                      ? AppPalette.disciplineGreen.withValues(alpha: .1)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  habit.finished
                      ? '🏁'
                      : habit.doneToday
                          ? '✓'
                          : habit.icon,
                  style: TextStyle(
                    fontSize: habit.doneToday ? 18 : 20,
                    fontWeight: habit.doneToday ? FontWeight.w700 : null,
                    color: habit.doneToday ? AppPalette.disciplineGreen : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (habit.reminderTime != null)
                        _Badge('⏰ ${habit.reminderTime!}'),
                      _Badge('🔥 ${habit.streak} kun'),
                      _Badge('🔁 ${_freqLabel()}'),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 17, color: scheme.onSurfaceVariant),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            "Hozircha odat yo'q",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            "Har kuni takrorlanadigan odat qo'shing — streak yig'ing",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TrackerHeader extends StatelessWidget {
  const _TrackerHeader({required this.range, required this.onPrev, required this.onNext});
  final String range;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _NavBtn(label: '‹', onTap: onPrev),
        Text(
          range,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        _NavBtn(label: '›', onTap: onNext),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TrackerTable extends StatelessWidget {
  const _TrackerTable({required this.habits, required this.weekStart});
  final List<Habit> habits;
  final DateTime weekStart;

  static final List<String> _uzDow = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final todayStr = _ymd(DateTime.now());

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12,
        headingRowHeight: 44,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 40,
        columns: [
          const DataColumn(label: Text('Odat', style: TextStyle(fontWeight: FontWeight.w600))),
          for (final d in days)
            DataColumn(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _uzDow[(d.weekday - 1) % 7],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _ymd(d) == todayStr ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ymd(d) == todayStr ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
        ],
        rows: [
          for (final h in habits)
            DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(h.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          h.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final d in days)
                  DataCell(
                    Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: h.doneToday && _ymd(d) == todayStr
                              ? AppPalette.disciplineGreen
                              : scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: h.doneToday && _ymd(d) == todayStr
                            ? const Text('✓',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ))
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
