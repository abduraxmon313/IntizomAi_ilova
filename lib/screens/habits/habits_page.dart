import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/habit.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';
import '../forms.dart';

/// Odatlar: Bugun (ro'yxat) / Tracker (haftalik jadval).
class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key, required this.state});

  final AppState state;

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  AppState get s => widget.state;

  String _view = 'today';
  DateTime _week = weekStart(tashkentToday());

  Future<void> _add() async {
    if (await showHabitForm(context, api: s.api)) await s.refreshHabits();
  }

  Future<void> _edit(Habit h) async {
    if (await showHabitForm(context, api: s.api, habit: h)) await s.refreshHabits();
  }

  Future<void> _delete(Habit h) async {
    if (!await confirmAction(
      context,
      title: "Odatni o'chirish",
      message: "«${h.title}» va uning tarixi o'chiriladi.",
    )) {
      return;
    }
    try {
      await s.api.deleteHabit(h.id);
      await s.refreshHabits();
      s.refreshStats();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _toggleToday(Habit h) async {
    if (h.finished) {
      toast(context, 'Bu odat muddati tugagan');
      return;
    }
    if (!h.dueToday) {
      toast(context, 'Bu odat bugun rejada yo\'q');
      return;
    }
    try {
      final u = await s.api.toggleHabit(h.id, done: !h.doneToday);
      s.replaceHabit(u);
      if (u.doneToday && mounted) toast(context, '${u.streak} kunlik streak');
      s.refreshStats();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _toggleOn(Habit h, DateTime day) async {
    try {
      final u = await s.api.toggleHabit(h.id, done: !h.doneOn(day), day: day);
      s.replaceHabit(u);
      s.refreshStats();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = [...s.habits]
      ..sort((a, b) => (a.reminderTime ?? '99:99').compareTo(b.reminderTime ?? '99:99'));
    return RefreshIndicator(
      onRefresh: s.refreshHabits,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          PageHeader(
            title: 'Odatlar',
            subtitle: "Har kuni takrorlang, streak yig'ing",
            actions: [HeaderIconButton(icon: LucideIcons.plus, tooltip: "Odat qo'shish", onTap: _add)],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SegmentTabs<String>(
              value: _view,
              items: const [('today', 'Bugun', LucideIcons.listChecks), ('tracker', 'Tracker', LucideIcons.calendarDays)],
              onChanged: (v) => setState(() => _view = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: habits.isEmpty
                ? EmptyView(
                    icon: LucideIcons.repeat,
                    title: "Hali odat yo'q",
                    message: "Har kuni takrorlanadigan odat qo'shing — streak yig'iladi.",
                    actionLabel: "Odat qo'shish",
                    onAction: _add,
                  )
                : _view == 'today'
                    ? _today(habits)
                    : _tracker(habits),
          ),
        ],
      ),
    );
  }

  Widget _today(List<Habit> habits) {
    final due = habits.where((h) => h.dueToday && !h.finished).toList();
    final done = due.where((h) => h.doneToday).length;
    final best = habits.fold<int>(0, (m, h) => h.streak > m ? h.streak : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _Summary(value: '$done/${due.length}', label: 'Bugun bajarildi')),
            const SizedBox(width: 8),
            Expanded(child: _Summary(value: '$best', label: 'Eng uzun streak')),
            const SizedBox(width: 8),
            Expanded(child: _Summary(value: '${habits.length}', label: 'Jami odat')),
          ],
        ),
        SectionBar(title: 'Odatlarim', actionLabel: "Qo'shish", onAction: _add),
        GroupCard(
          children: [
            for (final h in habits)
              _HabitTile(
                habit: h,
                onToggle: () => _toggleToday(h),
                onEdit: () => _edit(h),
                onDelete: () => _delete(h),
              ),
          ],
        ),
      ],
    );
  }

  Widget _tracker(List<Habit> habits) {
    final scheme = Theme.of(context).colorScheme;
    final today = tashkentToday();
    final days = [for (var i = 0; i < 7; i++) _week.add(Duration(days: i))];
    final end = days.last;
    final range = _week.month == end.month
        ? '${_week.day}–${end.day} ${uzMonthsShort[end.month - 1]}'
        : '${shortDate(_week)} – ${shortDate(end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _week = _week.subtract(const Duration(days: 7))),
              icon: const Icon(LucideIcons.chevronLeft, size: 20),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _week = weekStart(today)),
                child: Text(range, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _week = _week.add(const Duration(days: 7))),
              icon: const Icon(LucideIcons.chevronRight, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(flex: 3, child: SizedBox()),
                  for (final d in days)
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Text(
                            uzWeekdaysShort[d.weekday - 1],
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sameDay(d, today) ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (final h in habits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${h.icon} ${h.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      for (final d in days)
                        Expanded(
                          flex: 2,
                          child: _TrackerCell(
                            done: h.doneOn(d),
                            due: h.dueOn(d),
                            future: d.isAfter(today),
                            tooOld: today.difference(d).inDays > 44,
                            onTap: () => _toggleOn(h, d),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Katakni bosib o'tgan kunlarni ham belgilashingiz mumkin.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit, required this.onToggle, required this.onEdit, required this.onDelete});

  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = habit;
    final inactive = !h.dueToday || h.finished;
    final rep = h.isWeekly ? h.weekdays.map((i) => uzWeekdaysShort[i]).join(', ') : 'Har kuni';
    String dur = 'Doimiy';
    if (h.durationType == 'days' && h.targetDays != null) {
      dur = h.finished ? 'Tugadi' : (h.daysLeft != null ? '${h.daysLeft} kun qoldi' : '${h.targetDays} kun');
    }
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
        child: Row(
          children: [
            CheckCircle(checked: h.doneToday, disabled: inactive && !h.doneToday, onTap: onToggle),
            const SizedBox(width: 6),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(h.icon, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Opacity(
                opacity: inactive ? .6 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        decoration: h.doneToday ? TextDecoration.lineThrough : null,
                        color: h.doneToday ? scheme.onSurfaceVariant : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        if (h.reminderTime != null) MetaTag(icon: LucideIcons.bell, text: h.reminderTime!),
                        MetaTag(icon: LucideIcons.flame, text: '${h.streak} kun', color: AppPalette.streakOrange),
                        MetaTag(icon: LucideIcons.repeat, text: rep),
                        MetaTag(icon: LucideIcons.hourglass, text: dur),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: scheme.onSurfaceVariant),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Tahrirlash')),
                PopupMenuItem(value: 'delete', child: Text("O'chirish", style: TextStyle(color: AppPalette.danger))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerCell extends StatelessWidget {
  const _TrackerCell({
    required this.done,
    required this.due,
    required this.future,
    required this.tooOld,
    required this.onTap,
  });

  final bool done;
  final bool due;
  final bool future;
  final bool tooOld;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tappable = due && !future && !tooOld;
    Color bg;
    Widget? child;
    if (done) {
      bg = AppPalette.disciplineGreen;
      child = const Icon(LucideIcons.check, size: 14, color: Colors.white);
    } else if (!due) {
      bg = Colors.transparent;
      child = Container(width: 4, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, shape: BoxShape.circle));
    } else if (future) {
      bg = scheme.surfaceContainerLow;
    } else {
      bg = scheme.surfaceContainerHigh;
    }
    return GestureDetector(
      onTap: tappable ? onTap : null,
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: child,
        ),
      ),
    );
  }
}
