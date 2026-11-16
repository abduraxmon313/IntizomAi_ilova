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

/// Odatlar — bitta ko'rinish: har bir odat va uning haftasi.
/// Katakni bosish — o'sha kunni belgilash (o'tgan kunlarni ham),
/// odatning o'zini bosish — tahrirlash. Bugungi bajarish Bugun sahifasida ham bor.
class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key, required this.state});

  final AppState state;

  @override
  State<HabitsPage> createState() => HabitsPageState();
}

class HabitsPageState extends State<HabitsPage> {
  AppState get s => widget.state;

  DateTime _week = weekStart(tashkentToday());

  /// Pastdagi "+" tugmasi.
  Future<void> add() async {
    if (await showHabitForm(context, api: s.api)) await s.refreshHabits();
  }

  Future<void> _edit(Habit h) async {
    if (await showHabitForm(context, api: s.api, habit: h)) {
      await s.refreshHabits();
      s.refreshStats();
    }
  }

  Future<void> _toggle(Habit h, DateTime day) async {
    final today = sameDay(day, tashkentToday());
    try {
      final u = await s.api.toggleHabit(h.id, done: !h.doneOn(day), day: day);
      s.replaceHabit(u);
      if (today && u.doneToday && u.streak > 1 && mounted) toast(context, '${u.title} · ${u.streak} kun ketma-ket');
      s.refreshStats();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = tashkentToday();
    final habits = [...s.habits]
      ..sort((a, b) => a.finished == b.finished
          ? (a.reminderTime ?? '99:99').compareTo(b.reminderTime ?? '99:99')
          : (a.finished ? 1 : -1));
    final days = [for (var i = 0; i < 7; i++) _week.add(Duration(days: i))];
    final end = days.last;
    final range = _week.month == end.month
        ? '${_week.day}–${end.day} ${uzMonths[end.month - 1].toLowerCase()}'
        : '${shortDate(_week)} – ${shortDate(end)}';
    final thisWeek = sameDay(_week, weekStart(today));

    return RefreshIndicator(
      onRefresh: s.refreshHabits,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.bottomInset),
        children: [
          const PageHeader(title: 'Odatlar'),
          if (habits.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyView(
                icon: LucideIcons.repeat,
                title: "Hali odat yo'q",
                message: "Kichik, har kuni takrorlanadigan bitta odatdan boshlang. Seriya shu yerda yig'iladi.",
                actionLabel: "Odat qo'shish",
                onAction: add,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PeriodStepper(
                    label: thisWeek ? 'Shu hafta · $range' : range,
                    isCurrent: thisWeek,
                    resetLabel: 'Joriy haftaga qaytish',
                    onReset: () => setState(() => _week = weekStart(today)),
                    onPrev: () => setState(() => _week = _week.subtract(const Duration(days: 7))),
                    onNext: () => setState(() => _week = _week.add(const Duration(days: 7))),
                  ),
                  const SizedBox(height: 6),
                  // Hafta kunlari — pastdagi kataklar bilan bir ustunda.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        for (final d in days)
                          Expanded(
                            child: Text(
                              uzWeekdaysShort[d.weekday - 1],
                              textAlign: TextAlign.center,
                              style: AppType.caption.copyWith(
                                fontWeight: sameDay(d, today) ? FontWeight.w700 : FontWeight.w500,
                                color: sameDay(d, today) ? scheme.tertiary : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final h in habits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HabitCard(
                        key: ValueKey(h.id),
                        habit: h,
                        days: days,
                        today: today,
                        onEdit: () => _edit(h),
                        onToggle: (d) => _toggle(h, d),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    "Katakni bosib o'tgan kunlarni ham belgilash mumkin.",
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(color: scheme.outline, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    super.key,
    required this.habit,
    required this.days,
    required this.today,
    required this.onEdit,
    required this.onToggle,
  });

  final Habit habit;
  final List<DateTime> days;
  final DateTime today;
  final VoidCallback onEdit;
  final ValueChanged<DateTime> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = habit;
    final rep = h.isWeekly ? h.weekdays.map((i) => uzWeekdaysShort[i]).join(', ') : 'Har kuni';
    String? dur;
    if (h.durationType == 'days' && h.targetDays != null && !h.finished) {
      dur = h.daysLeft != null ? '${h.daysLeft} kun qoldi' : '${h.targetDays} kun';
    }
    final meta = [rep, ?h.reminderTime, ?dur].join(' · ');
    return Container(
      decoration: surfaceDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            InkWell(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Opacity(
                  opacity: h.finished ? .55 : 1,
                  child: Row(
                    children: [
                      HabitGlyph(icon: h.icon, size: 40, done: h.doneToday),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.bodyStrong),
                            const SizedBox(height: 2),
                            Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (h.finished)
                        const Pill('Yakunlandi', muted: true)
                      else
                        MetaTag(
                          icon: LucideIcons.flame,
                          text: '${h.streak} kun',
                          color: h.streak > 0 ? AppPalette.ember : scheme.outline,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  for (final d in days)
                    Expanded(
                      child: _DayCell(
                        day: d,
                        done: h.doneOn(d),
                        due: h.dueOn(d) && !(h.finished && d.isAfter(today)),
                        isToday: sameDay(d, today),
                        future: d.isAfter(today),
                        tooOld: today.difference(d).inDays > 44,
                        onTap: () => onToggle(d),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bir kunlik katak: sana raqami bilan. Bajarilgan — brend rangda to'la.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.done,
    required this.due,
    required this.isToday,
    required this.future,
    required this.tooOld,
    required this.onTap,
  });

  final DateTime day;
  final bool done;
  final bool due;
  final bool isToday;
  final bool future;
  final bool tooOld;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tappable = due && !future && !tooOld;
    return Semantics(
      button: tappable,
      checked: done,
      label: longDate(day),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable
            ? () {
                done ? tapFeedback() : successFeedback();
                onTap();
              }
            : null,
        child: SizedBox(
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? scheme.primary
                    : !due || future
                    ? Colors.transparent
                    : scheme.surfaceContainerLow,
                border: isToday && !done && due ? Border.all(color: scheme.primary, width: 1.6) : null,
              ),
              child: done
                  ? Icon(LucideIcons.check, size: 17, color: scheme.onPrimary)
                  : Text(
                      '${day.day}',
                      style: AppType.label.copyWith(
                        fontFeatures: tabularFigures,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: !due
                            ? scheme.outlineVariant
                            : future
                            ? scheme.outline
                            : isToday
                            ? scheme.tertiary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
