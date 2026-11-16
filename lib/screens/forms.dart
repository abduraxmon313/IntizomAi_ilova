import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/goal.dart';
import '../models/habit.dart';
import '../models/plan.dart';
import '../services/intizom_api.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/app_ui.dart';
import '../widgets/feedback.dart';
import '../widgets/ui_kit.dart';

/// Odat uchun belgilar (Mini App'dagi ro'yxat bilan bir xil).
const habitIcons = [
  '🏃', '💪', '🌅', '🛏️', '💧', '🍽️', '🙏', '📚', '📖', '💻', '🧠',
  '✍️', '💼', '🎯', '💸', '🧹', '❤️', '🚭', '🫂', '🛒', '🚗',
];

String _hm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? _parseHm(String? s) {
  if (s == null || !s.contains(':')) return null;
  final p = s.split(':');
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1].substring(0, p[1].length.clamp(0, 2)));
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) => showTimePicker(
  context: context,
  initialTime: initial,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
    child: child!,
  ),
);

/// Reja qo'shish / tahrirlash. [onSubmit] null bo'lsa o'zimizning API ishlatiladi.
/// Saqlansa true qaytaradi.
Future<bool> showPlanForm(
  BuildContext context, {
  required IntizomApi api,
  Plan? plan,
  DateTime? initialDate,
  String? titleOverride,
  Future<void> Function(String title, String? desc, String? time, DateTime date)? onSubmit,
}) async {
  final title = TextEditingController(text: plan?.title ?? '');
  final desc = TextEditingController(text: plan?.description ?? '');
  TimeOfDay? time = _parseHm(plan?.scheduledTime);
  final today = tashkentToday();
  var date = plan != null ? (parseYmd(plan.planDate) ?? today) : dateOnly(initialDate ?? today);
  if (plan == null && date.isBefore(today)) date = today;
  var saved = false;

  await showFormSheet<void>(
    context,
    title: titleOverride ?? (plan == null ? 'Yangi reja' : 'Rejani tahrirlash'),
    builder: (ctx, setSheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: title,
          autofocus: plan == null,
          textCapitalization: TextCapitalization.sentences,
          style: AppType.heading.copyWith(fontWeight: FontWeight.w500),
          decoration: const InputDecoration(hintText: 'Nima qilasiz?'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: desc,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Izoh (ixtiyoriy)'),
        ),
        const FieldLabel('Qachon'),
        Row(
          children: [
            Expanded(
              child: PickerField(
                icon: LucideIcons.clock,
                text: time == null ? 'Vaqt' : _hm(time!),
                placeholder: time == null,
                onTap: () async {
                  final t = await pickTime(ctx, time ?? TimeOfDay.now());
                  if (t != null) setSheet(() => time = t);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PickerField(
                icon: LucideIcons.calendar,
                text: relativeDay(date),
                onTap: plan != null
                    ? null
                    : () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: today,
                          lastDate: today.add(const Duration(days: 365)),
                        );
                        if (d != null) setSheet(() => date = d);
                      },
              ),
            ),
          ],
        ),
      ],
    ),
    onDelete: plan == null || onSubmit != null
        ? null
        : () async {
            try {
              await api.deletePlan(plan.id);
              saved = true;
              return true;
            } catch (e) {
              if (context.mounted) showApiError(context, e);
              return false;
            }
          },
    onSave: () async {
      final t = title.text.trim();
      if (t.isEmpty) {
        toast(context, 'Reja nomini yozing');
        return false;
      }
      final d = desc.text.trim().isEmpty ? null : desc.text.trim();
      final tm = time == null ? null : _hm(time!);
      try {
        if (onSubmit != null) {
          await onSubmit(t, d, tm, date);
        } else if (plan == null) {
          await api.createPlan(title: t, description: d, scheduledTime: tm, planDate: ymd(date));
        } else {
          await api.updatePlan(plan.id, title: t, description: d ?? '', scheduledTime: tm);
        }
        saved = true;
        return true;
      } catch (e) {
        if (context.mounted) showApiError(context, e);
        return false;
      }
    },
  );
  return saved;
}

/// Odat qo'shish / tahrirlash.
Future<bool> showHabitForm(
  BuildContext context, {
  required IntizomApi api,
  Habit? habit,
  String? titleOverride,
  Future<void> Function(HabitInput input)? onSubmit,
}) async {
  final title = TextEditingController(text: habit?.title ?? '');
  final desc = TextEditingController(text: habit?.description ?? '');
  final days = TextEditingController(text: habit?.targetDays?.toString() ?? '');
  var icon = habit?.icon ?? habitIcons.first;
  var freq = habit?.frequency ?? 'daily';
  final weekdays = <int>{...?habit?.weekdays};
  var duration = habit?.durationType ?? 'permanent';
  TimeOfDay? reminder = _parseHm(habit?.reminderTime);
  var saved = false;

  await showFormSheet<void>(
    context,
    title: titleOverride ?? (habit == null ? 'Yangi odat' : 'Odatni tahrirlash'),
    builder: (ctx, setSheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: title,
          autofocus: habit == null,
          textCapitalization: TextCapitalization.sentences,
          style: AppType.heading.copyWith(fontWeight: FontWeight.w500),
          decoration: const InputDecoration(hintText: 'Odat nomi (masalan: Kitob o\'qish)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: desc,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Izoh (ixtiyoriy)'),
        ),
        const FieldLabel('Belgi'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in habitIcons)
              ChoiceChipBox(
                size: 44,
                selected: e == icon,
                onTap: () => setSheet(() => icon = e),
                child: habitGlyphs[e] != null
                    ? Icon(habitGlyphs[e], size: 19)
                    : Text(e, style: AppType.heading.copyWith(height: 1)),
              ),
          ],
        ),
        const FieldLabel('Takrorlanish'),
        SegmentTabs<String>(
          value: freq,
          items: const [('daily', 'Har kuni'), ('weekly', 'Tanlangan kunlar')],
          onChanged: (v) => setSheet(() => freq = v),
        ),
        if (freq == 'weekly') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                    child: ChoiceChipBox(
                      selected: weekdays.contains(i),
                      onTap: () => setSheet(() => weekdays.contains(i) ? weekdays.remove(i) : weekdays.add(i)),
                      child: Text(uzWeekdaysShort[i]),
                    ),
                  ),
                ),
            ],
          ),
        ],
        const FieldLabel('Davomiylik'),
        SegmentTabs<String>(
          value: duration,
          items: const [('permanent', 'Doimiy'), ('days', 'Muddatli')],
          onChanged: (v) => setSheet(() => duration = v),
        ),
        if (duration == 'days') ...[
          const SizedBox(height: 10),
          TextField(
            controller: days,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Necha kun? (masalan: 30)', suffixText: 'kun'),
          ),
        ],
        const FieldLabel('Eslatma'),
        Row(
          children: [
            Expanded(
              child: PickerField(
                icon: LucideIcons.bell,
                text: reminder == null ? 'Eslatmasiz' : 'Har kuni ${_hm(reminder!)} da',
                placeholder: reminder == null,
                onTap: () async {
                  final t = await pickTime(ctx, reminder ?? const TimeOfDay(hour: 20, minute: 0));
                  if (t != null) setSheet(() => reminder = t);
                },
              ),
            ),
            if (reminder != null)
              IconButton(
                tooltip: "Eslatmani o'chirish",
                onPressed: () => setSheet(() => reminder = null),
                icon: const Icon(LucideIcons.x, size: 18),
              ),
          ],
        ),
      ],
    ),
    onDelete: habit == null || onSubmit != null
        ? null
        : () async {
            final ok = await confirmAction(
              context,
              title: "Odatni o'chirish",
              message: "«${habit.title}» va uning butun tarixi o'chiriladi.",
            );
            if (!ok) return false;
            try {
              await api.deleteHabit(habit.id);
              saved = true;
              return true;
            } catch (e) {
              if (context.mounted) showApiError(context, e);
              return false;
            }
          },
    onSave: () async {
      final t = title.text.trim();
      if (t.isEmpty) {
        toast(context, 'Odat nomini yozing');
        return false;
      }
      if (freq == 'weekly' && weekdays.isEmpty) {
        toast(context, 'Kamida bitta kunni tanlang');
        return false;
      }
      final target = int.tryParse(days.text.trim());
      if (duration == 'days' && (target == null || target < 1)) {
        toast(context, 'Necha kun davom etishini yozing');
        return false;
      }
      final input = HabitInput(
        title: t,
        description: desc.text.trim().isEmpty ? null : desc.text.trim(),
        icon: icon,
        frequency: freq,
        weekdays: (weekdays.toList()..sort()),
        durationType: duration,
        targetDays: target,
        reminderTime: reminder == null ? null : _hm(reminder!),
      );
      try {
        if (onSubmit != null) {
          await onSubmit(input);
        } else if (habit == null) {
          await api.createHabit(input);
        } else {
          await api.updateHabit(habit.id, input);
        }
        saved = true;
        return true;
      } catch (e) {
        if (context.mounted) showApiError(context, e);
        return false;
      }
    },
  );
  return saved;
}

/// Maqsad qo'shish / tahrirlash. [goalType] va [period] yangi maqsad uchun.
Future<bool> showGoalForm(
  BuildContext context, {
  required IntizomApi api,
  Goal? goal,
  String goalType = 'yearly',
  String? period,
  String? periodLabel,
}) async {
  final title = TextEditingController(text: goal?.title ?? '');
  final desc = TextEditingController(text: goal?.description ?? '');
  var saved = false;

  await showFormSheet<void>(
    context,
    title: goal == null ? 'Yangi maqsad' : 'Maqsadni tahrirlash',
    subtitle: periodLabel,
    builder: (ctx, setSheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: title,
          autofocus: goal == null,
          textCapitalization: TextCapitalization.sentences,
          style: AppType.heading.copyWith(fontWeight: FontWeight.w500),
          decoration: const InputDecoration(hintText: 'Qanday natijaga erishmoqchisiz?'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: desc,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Tavsif (ixtiyoriy)'),
        ),
      ],
    ),
    onDelete: goal == null
        ? null
        : () async {
            try {
              await api.deleteGoal(goal.id);
              saved = true;
              return true;
            } catch (e) {
              if (context.mounted) showApiError(context, e);
              return false;
            }
          },
    onSave: () async {
      final t = title.text.trim();
      if (t.isEmpty) {
        toast(context, 'Maqsadni yozing');
        return false;
      }
      final d = desc.text.trim().isEmpty ? null : desc.text.trim();
      try {
        if (goal == null) {
          await api.createGoal(title: t, description: d, goalType: goalType, period: period!);
        } else {
          await api.updateGoal(goal.id, title: t, description: d ?? '');
        }
        saved = true;
        return true;
      } catch (e) {
        if (context.mounted) showApiError(context, e);
        return false;
      }
    },
  );
  return saved;
}
