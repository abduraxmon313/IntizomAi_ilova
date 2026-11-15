import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/habit.dart';
import '../../models/plan.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';
import '../forms.dart';

/// Rejalar: kun tasmasi, tanlangan kunning rejalari va odatlari.
class PlansPage extends StatefulWidget {
  const PlansPage({super.key, required this.state});

  final AppState state;

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  AppState get s => widget.state;

  DateTime _day = tashkentToday();
  List<Plan> _plans = const [];
  bool _loadingPlans = true;
  int _seenVersion = -1;

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
    _loadPlans();
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (s.plansVersion != _seenVersion) {
      _seenVersion = s.plansVersion;
      _loadPlans();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadPlans() async {
    final day = _day;
    try {
      final p = await s.api.plansOn(day);
      if (!mounted || day != _day) return;
      setState(() {
        _plans = p;
        _loadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPlans = false);
      showApiError(context, e);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([s.refreshHabits(), s.refreshStats(), _loadPlans()]);
  }

  void _selectDay(DateTime d) {
    setState(() {
      _day = d;
      _loadingPlans = true;
    });
    _loadPlans();
  }

  Future<void> _togglePlan(Plan p) async {
    final today = tashkentToday();
    final pd = parseYmd(p.planDate) ?? today;
    if (pd.isBefore(today)) {
      toast(context, "O'tib ketgan kun rejasini o'zgartirib bo'lmaydi");
      return;
    }
    try {
      final updated = await s.api.setPlanStatus(p.id, p.isDone ? 'pending' : 'done');
      if (!mounted) return;
      setState(() => _plans = [for (final x in _plans) x.id == p.id ? updated : x]);
      if (updated.isDone) toast(context, 'Bajarildi · +${updated.scoreValue} ball');
      s.plansChanged();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _toggleHabit(Habit h) async {
    final today = tashkentToday();
    if (_day.isAfter(today)) {
      toast(context, "Kelajakdagi kunni belgilab bo'lmaydi");
      return;
    }
    try {
      final isToday = sameDay(_day, today);
      final updated = isToday
          ? await s.api.toggleHabit(h.id)
          : await s.api.toggleHabit(h.id, done: !h.doneOn(_day), day: _day);
      s.replaceHabit(updated);
      if (!mounted) return;
      if (updated.doneOn(_day) || (isToday && updated.doneToday)) {
        toast(context, 'Odat belgilandi · ${updated.streak} kunlik seriya');
      }
      s.refreshStats();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _editPlan(Plan p) async {
    if (await showPlanForm(context, api: s.api, plan: p)) s.plansChanged();
  }

  Future<void> _deletePlan(Plan p) async {
    if (!await confirmAction(context, title: "Rejani o'chirish", message: p.title)) return;
    try {
      await s.api.deletePlan(p.id);
      s.plansChanged();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _addPlan() async {
    if (await showPlanForm(context, api: s.api, initialDate: _day)) {
      final today = tashkentToday();
      if (_day.isBefore(today)) _selectDay(today);
      s.plansChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = tashkentToday();
    final isToday = sameDay(_day, today);
    final dayHabits = s.habits.where((h) => !h.finished || h.doneOn(_day)).where((h) => h.dueOn(_day)).toList()
      ..sort((a, b) => (a.reminderTime ?? '99:99').compareTo(b.reminderTime ?? '99:99'));
    final plans = [..._plans]..sort((a, b) => (a.scheduledTime ?? '99:99').compareTo(b.scheduledTime ?? '99:99'));
    bool habitDone(Habit h) => h.doneOn(_day) || (isToday && h.doneToday);
    final plansDone = plans.where((p) => p.isDone).length;
    final habitsDone = dayHabits.where(habitDone).length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          PageHeader(
            title: 'Rejalar',
            subtitle: longDate(today),
            actions: [HeaderIconButton(icon: LucideIcons.plus, tooltip: "Reja qo'shish", filled: true, onTap: _addPlan)],
          ),
          _WeekStrip(selected: _day, onSelect: _selectDay),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionBar(
                  title: _dayTitle(),
                  count: plans.isEmpty ? null : '$plansDone/${plans.length}',
                  actionLabel: 'Reja',
                  onAction: _addPlan,
                  top: 20,
                ),
                AnimatedSwitcher(
                  duration: AppMotion.base,
                  child: _loadingPlans
                      ? const Padding(
                          key: ValueKey('loading'),
                          padding: EdgeInsets.all(28),
                          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                        )
                      : plans.isEmpty
                          ? EmptyView(
                              key: ValueKey('empty${ymd(_day)}'),
                              icon: LucideIcons.calendarPlus,
                              title: isToday ? "Bugunga reja yo'q" : "Bu kunga reja yo'q",
                              message: 'Vaqtini belgilang — bot o\'z vaqtida eslatadi.',
                              actionLabel: "Reja qo'shish",
                              onAction: _addPlan,
                            )
                          : GroupCard(
                              key: ValueKey('plans${ymd(_day)}'),
                              indent: 92,
                              children: [
                                for (final p in plans)
                                  _PlanRow(
                                    plan: p,
                                    onToggle: () => _togglePlan(p),
                                    onEdit: () => _editPlan(p),
                                    onDelete: () => _deletePlan(p),
                                  ),
                              ],
                            ),
                ),
                if (dayHabits.isNotEmpty) ...[
                  SectionBar(title: 'Odatlar', count: '$habitsDone/${dayHabits.length}'),
                  GroupCard(
                    indent: 64,
                    children: [
                      for (final h in dayHabits)
                        _HabitRow(habit: h, done: habitDone(h), onToggle: () => _toggleHabit(h)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dayTitle() {
    final r = relativeDay(_day);
    if (r == 'Bugun') return 'Bugungi rejalar';
    if (r == 'Ertaga') return 'Ertangi rejalar';
    if (r == 'Kecha') return 'Kechagi rejalar';
    return '${shortDate(_day)} rejalari';
  }

}

/// Kun tanlagich: 14 kun oldin … bugun … 30 kun keyin. Kalendar uslubida.
class _WeekStrip extends StatefulWidget {
  const _WeekStrip({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  static const _before = 14;
  static const _after = 30;
  static const _itemW = 46.0;
  final _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(animate: false));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _center({bool animate = true}) {
    if (!_ctrl.hasClients) return;
    final idx = widget.selected.difference(tashkentToday()).inDays + _before;
    final w = _ctrl.position.viewportDimension;
    final target = (12 + idx * _itemW - w / 2 + _itemW / 2).clamp(0.0, _ctrl.position.maxScrollExtent);
    animate
        ? _ctrl.animateTo(target, duration: AppMotion.base, curve: AppMotion.curve)
        : _ctrl.jumpTo(target);
  }

  @override
  void didUpdateWidget(covariant _WeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!sameDay(oldWidget.selected, widget.selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _center());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = tashkentToday();
    final sel = widget.selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, 12, 4),
          child: Row(
            children: [
              Text(
                '${uzMonths[sel.month - 1]} ${sel.year}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.2),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: sameDay(sel, today) ? 0 : 1,
                duration: AppMotion.fast,
                child: TextButton(
                  onPressed: sameDay(sel, today) ? null : () => widget.onSelect(today),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Bugun'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 66,
          child: ListView.builder(
            controller: _ctrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemExtent: _itemW,
            itemCount: _before + _after + 1,
            itemBuilder: (context, i) {
              final d = today.add(Duration(days: i - _before));
              final isSel = sameDay(d, sel);
              final isToday = sameDay(d, today);
              final past = d.isBefore(today);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  tapFeedback();
                  widget.onSelect(d);
                },
                child: Column(
                  children: [
                    Text(
                      uzWeekdaysShort[d.weekday - 1],
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: AppMotion.fast,
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSel ? (isToday ? scheme.primary : scheme.onSurface) : Colors.transparent,
                      ),
                      child: Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: isSel || isToday ? FontWeight.w700 : FontWeight.w500,
                          fontFeatures: tabularFigures,
                          color: isSel
                              ? (isToday ? scheme.onPrimary : scheme.surface)
                              : isToday
                                  ? scheme.primary
                                  : past
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Reja qatori: chapda vaqt ustuni, keyin belgilash va matn.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, required this.onToggle, required this.onEdit, required this.onDelete});

  final Plan plan;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = plan.scheduledTime?.isNotEmpty == true ? plan.scheduledTime! : '—';
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: tabularFigures,
                  color: plan.isDone ? scheme.outline : scheme.onSurfaceVariant,
                ),
              ),
            ),
            CheckCircle(checked: plan.isDone, color: scheme.primary, onTap: onToggle),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: AppMotion.fast,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        letterSpacing: -.15,
                        fontWeight: FontWeight.w500,
                        color: plan.isDone ? scheme.onSurfaceVariant : scheme.onSurface,
                        decoration: plan.isDone ? TextDecoration.lineThrough : null,
                        decorationColor: scheme.onSurfaceVariant,
                      ),
                      child: Text(plan.title),
                    ),
                    if (plan.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        plan.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Amallar',
              icon: Icon(LucideIcons.ellipsis, size: 18, color: scheme.outline),
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

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.habit, required this.done, required this.onToggle});

  final Habit habit;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            HabitGlyph(icon: habit.icon, size: 36, done: done),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      fontSize: 15,
                      letterSpacing: -.15,
                      fontWeight: FontWeight.w500,
                      color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (habit.reminderTime != null) MetaTag(icon: LucideIcons.bell, text: habit.reminderTime!),
                      MetaTag(
                        icon: LucideIcons.flame,
                        text: '${habit.streak} kun',
                        color: habit.streak > 0 ? AppPalette.ember : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CheckCircle(checked: done, onTap: onToggle),
          ],
        ),
      ),
    );
  }
}
