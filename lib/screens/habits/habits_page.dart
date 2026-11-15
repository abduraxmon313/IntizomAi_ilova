import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/habit.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
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
      if (u.doneToday && mounted) toast(context, 'Belgilandi · ${u.streak} kunlik seriya');
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
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          PageHeader(
            title: 'Odatlar',
            subtitle: 'Har kuni kichik qadam',
            actions: [HeaderIconButton(icon: LucideIcons.plus, tooltip: "Odat qo'shish", filled: true, onTap: _add)],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: SegmentTabs<String>(
              value: _view,
              items: const [('today', 'Bugun', null), ('tracker', 'Hafta', null)],
              onChanged: (v) => setState(() => _view = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 16, AppSpace.lg, 0),
            child: habits.isEmpty
                ? EmptyView(
                    icon: LucideIcons.repeat,
                    title: "Hali odat yo'q",
                    message: "Har kuni takrorlanadigan bitta odatdan boshlang — seriya shu yerda yig'iladi.",
                    actionLabel: "Odat qo'shish",
                    onAction: _add,
                  )
                : AnimatedSwitcher(
                    duration: AppMotion.base,
                    child: _view == 'today'
                        ? KeyedSubtree(key: const ValueKey('t'), child: _today(habits))
                        : KeyedSubtree(key: ValueKey('w${ymd(_week)}'), child: _tracker(habits)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _today(List<Habit> habits) {
    final scheme = Theme.of(context).colorScheme;
    final due = habits.where((h) => h.dueToday && !h.finished).toList();
    final done = due.where((h) => h.doneToday).length;
    final best = habits.fold<int>(0, (m, h) => h.streak > m ? h.streak : m);
    Widget metric(String value, String label) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.6, fontFeatures: tabularFigures)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  children: [
                    metric('$done/${due.length}', 'bugun bajarildi'),
                    VerticalDivider(width: 1, color: scheme.outlineVariant),
                    metric('$best', 'eng uzun seriya'),
                    VerticalDivider(width: 1, color: scheme.outlineVariant),
                    metric('${habits.length}', 'faol odat'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: AppProgressBar(
                  value: due.isEmpty ? 0 : done / due.length,
                  color: null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GroupCard(
          indent: 64,
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
        const SizedBox(height: 10),
        Text(
          "Nuqtalar — oxirgi 7 kun. Bosib ushlab turing: tahrirlash yoki o'chirish.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
        ? '${_week.day}–${end.day} ${uzMonths[end.month - 1].toLowerCase()}'
        : '${shortDate(_week)} – ${shortDate(end)}';
    final thisWeek = sameDay(_week, weekStart(today));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _week = _week.subtract(const Duration(days: 7))),
              icon: const Icon(LucideIcons.chevronLeft, size: 20),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(range, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.2)),
                  if (!thisWeek)
                    GestureDetector(
                      onTap: () => setState(() => _week = weekStart(today)),
                      child: Text('Joriy haftaga qaytish', style: TextStyle(fontSize: 12, color: scheme.primary)),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _week = _week.add(const Duration(days: 7))),
              icon: const Icon(LucideIcons.chevronRight, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
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
                          Text(uzWeekdaysShort[d.weekday - 1], style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFeatures: tabularFigures,
                              color: sameDay(d, today) ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (final h in habits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            HabitGlyph(icon: h.icon, size: 26),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                h.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
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
          "O'tgan kunlarni ham katakni bosib belgilash mumkin.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit, required this.onToggle, required this.onEdit, required this.onDelete});

  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _menu(BuildContext context) async {
    tapFeedback();
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(habit.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(leading: const Icon(LucideIcons.pencil), title: const Text('Tahrirlash'), onTap: () => Navigator.pop(ctx, 'edit')),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: AppPalette.danger),
              title: const Text("O'chirish", style: TextStyle(color: AppPalette.danger)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (v == 'edit') onEdit();
    if (v == 'delete') onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = habit;
    final inactive = !h.dueToday || h.finished;
    final rep = h.isWeekly ? h.weekdays.map((i) => uzWeekdaysShort[i]).join(' ') : 'Har kuni';
    String? dur;
    if (h.durationType == 'days' && h.targetDays != null) {
      dur = h.finished ? 'Yakunlandi' : (h.daysLeft != null ? '${h.daysLeft} kun qoldi' : '${h.targetDays} kun');
    }
    final today = tashkentToday();
    return InkWell(
      onTap: onEdit,
      onLongPress: () => _menu(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            HabitGlyph(icon: h.icon, size: 38, done: h.doneToday),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: inactive && !h.doneToday ? .55 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -.15),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        MetaTag(icon: LucideIcons.flame, text: '${h.streak}', color: h.streak > 0 ? AppPalette.ember : null),
                        if (h.reminderTime != null) MetaTag(icon: LucideIcons.bell, text: h.reminderTime!),
                        MetaTag(icon: LucideIcons.repeat, text: rep),
                        if (dur != null) MetaTag(icon: LucideIcons.hourglass, text: dur),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 6; i >= 0; i--)
                          Builder(
                            builder: (_) {
                              final d = today.subtract(Duration(days: i));
                              final done = h.doneOn(d);
                              final due = h.dueOn(d);
                              return Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done ? scheme.primary : (due ? scheme.surfaceContainerHighest : Colors.transparent),
                                  border: !done && !due ? Border.all(color: scheme.outlineVariant) : null,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            CheckCircle(checked: h.doneToday, disabled: inactive && !h.doneToday, onTap: onToggle, size: 24),
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
    return GestureDetector(
      onTap: tappable
          ? () {
              if (!done) successFeedback();
              onTap();
            }
          : null,
      child: Center(
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? scheme.primary
                : !due
                    ? Colors.transparent
                    : future
                        ? scheme.surfaceContainerLow
                        : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: done
              ? Icon(LucideIcons.check, size: 14, color: scheme.onPrimary)
              : !due
                  ? Container(width: 4, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, shape: BoxShape.circle))
                  : null,
        ),
      ),
    );
  }
}
