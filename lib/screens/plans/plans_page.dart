import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/goal.dart';
import '../../models/plan.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';
import '../forms.dart';

/// Rejalashtirish ufqi: kun rejalari, oy maqsadlari, yil maqsadlari.
enum PlansView { day, month, year }

/// Rejalar — rejalashtirishning yagona joyi, katta maqsaddan kunlik ishgacha:
/// Kunlik (istalgan kunning rejalari) · Oylik · Yillik (maqsadlar).
class PlansPage extends StatefulWidget {
  const PlansPage({super.key, required this.state});

  final AppState state;

  @override
  State<PlansPage> createState() => PlansPageState();
}

class PlansPageState extends State<PlansPage> {
  AppState get s => widget.state;

  PlansView _view = PlansView.day;

  // Kunlik
  DateTime _day = tashkentToday();
  List<Plan> _plans = const [];
  bool _loadingPlans = true;
  int _seenVersion = -1;

  // Maqsadlar
  late int _year = tashkentToday().year;
  late DateTime _month = DateTime(tashkentToday().year, tashkentToday().month);

  @override
  void initState() {
    super.initState();
    _seenVersion = s.plansVersion;
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

  /// Boshqa bo'limdan kerakli ko'rinishni ochish (masalan, Bugun → oy maqsadlari).
  void showView(PlansView v) {
    final t = tashkentToday();
    setState(() {
      _view = v;
      if (v == PlansView.month) _month = DateTime(t.year, t.month);
      if (v == PlansView.year) _year = t.year;
    });
  }

  /// Pastdagi "+" tugmasi: ko'rinishga qarab reja yoki maqsad.
  Future<void> add() => _view == PlansView.day ? _addPlan() : _addGoal();

  // ── Kunlik rejalar ─────────────────────────────────
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

  void _selectDay(DateTime d) {
    if (sameDay(d, _day)) return;
    setState(() {
      _day = d;
      _loadingPlans = true;
    });
    _loadPlans();
  }

  Future<void> _setPlanDone(Plan p, bool done) async {
    try {
      final updated = await s.api.setPlanStatus(p.id, done ? 'done' : 'pending');
      if (!mounted) return;
      setState(() => _plans = [for (final x in _plans) x.id == p.id ? updated : x]);
      if (updated.isDone) {
        toast(
          context,
          context.tr("Bajarildi · +{v0} ball", {'v0': updated.scoreValue}),
          actionLabel: context.tr("Qaytarish"),
          onAction: () => _setPlanDone(updated, false),
        );
      }
      s.plansChanged();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _editPlan(Plan p) async {
    if (await showPlanForm(context, api: s.api, plan: p)) s.plansChanged();
  }

  Future<void> _addPlan() async {
    final today = tashkentToday();
    if (await showPlanForm(context, api: s.api, initialDate: _day)) {
      if (_day.isBefore(today)) _selectDay(today);
      s.plansChanged();
    }
  }

  // ── Maqsadlar ──────────────────────────────────────
  String get _goalType => _view == PlansView.year ? 'yearly' : 'monthly';

  String get _period =>
      _view == PlansView.year ? '$_year' : '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  String get _periodLabel =>
      _view == PlansView.year ? context.tr("{v0}-yil", {'v0': _year}) : '${uzMonths[_month.month - 1]} ${_month.year}';

  Future<void> _addGoal() async {
    if (await showGoalForm(context, api: s.api, goalType: _goalType, period: _period, periodLabel: _periodLabel)) {
      await s.refreshGoals();
    }
  }

  Future<void> _setGoalDone(Goal g, bool done) async {
    try {
      await s.api.updateGoal(g.id, completed: done);
      await s.refreshGoals();
      if (done && mounted) {
        toast(context, context.tr("Maqsad bajarildi"), actionLabel: context.tr("Qaytarish"), onAction: () => _setGoalDone(g, false));
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _editGoal(Goal g) async {
    if (await showGoalForm(context, api: s.api, goal: g, periodLabel: _periodLabel)) await s.refreshGoals();
  }

  Future<void> _refresh() => _view == PlansView.day ? _loadPlans() : s.refreshGoals();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.bottomInset),
        children: [
           PageHeader(title: context.tr("Rejalar")),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: SegmentTabs<PlansView>(
              value: _view,
              items:  [(PlansView.day, context.tr("Kunlik")), (PlansView.month, context.tr("Oylik")), (PlansView.year, context.tr("Yillik"))],
              onChanged: (v) => setState(() => _view = v),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: AppMotion.base,
            child: KeyedSubtree(
              key: ValueKey(_view),
              child: _view == PlansView.day ? _dayView() : _goalsView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayView() {
    final today = tashkentToday();
    final past = _day.isBefore(today);
    final plans = [..._plans]..sort((a, b) => (a.scheduledTime ?? '99:99').compareTo(b.scheduledTime ?? '99:99'));
    final done = plans.where((p) => p.isDone).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayStrip(selected: _day, onSelect: _selectDay),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionBar(title: _dayTitle(), count: plans.isEmpty ? null : '$done/${plans.length}', top: 16),
              AnimatedSwitcher(
                duration: AppMotion.base,
                child: _loadingPlans
                    ? const LoadingView(key: ValueKey('loading'))
                    : plans.isEmpty
                    ? EmptyView(
                        key: ValueKey('empty${ymd(_day)}'),
                        icon: LucideIcons.calendarPlus,
                        title: past ? context.tr("Bu kunda reja bo'lmagan") : context.tr("Bu kunga hali reja yo'q"),
                        message: past ? null : context.tr("Vaqtini belgilasangiz, bot o'z vaqtida eslatadi."),
                        actionLabel: context.tr("Reja qo'shish"),
                        onAction: past ? null : _addPlan,
                      )
                    : GroupCard(
                        key: ValueKey('plans${ymd(_day)}'),
                        indent: 52,
                        children: [
                          for (final p in plans)
                            TaskRow(
                              key: ValueKey(p.id),
                              title: p.title,
                              subtitle: p.description,
                              done: p.isDone,
                              locked: past,
                              trailing: p.scheduledTime?.isNotEmpty == true ? p.scheduledTime : null,
                              onToggle: () => _setPlanDone(p, !p.isDone),
                              onTap: () => _editPlan(p),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _dayTitle() {
    final r = relativeDay(context, _day);
    return r.isEmpty ? r : r[0].toUpperCase() + r.substring(1);
  }

  Widget _goalsView() {
    final scheme = Theme.of(context).colorScheme;
    final today = tashkentToday();
    final yearly = _view == PlansView.year;
    final goals = s.goals.where((g) => g.goalType == _goalType && g.period == _period).toList()
      ..sort((a, b) => a.completed == b.completed ? 0 : (a.completed ? 1 : -1));
    final done = goals.where((g) => g.completed).length;
    final isCurrent = yearly ? _year == today.year : (_month.year == today.year && _month.month == today.month);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PeriodStepper(
            label: _periodLabel,
            isCurrent: isCurrent,
            resetLabel: yearly ? context.tr("Joriy yilga qaytish") : context.tr("Joriy oyga qaytish"),
            onReset: () => setState(() {
              _year = today.year;
              _month = DateTime(today.year, today.month);
            }),
            onPrev: () => setState(() => yearly ? _year-- : _month = DateTime(_month.year, _month.month - 1)),
            onNext: () => setState(() => yearly ? _year++ : _month = DateTime(_month.year, _month.month + 1)),
          ),
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: AppProgressBar(value: done / goals.length)),
                const SizedBox(width: 12),
                Text(
                  '$done/${goals.length}',
                  style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: AppMotion.base,
            child: goals.isEmpty
                ? EmptyView(
                    key: ValueKey('e$_period'),
                    icon: LucideIcons.target,
                    title: context.tr("{v0} uchun maqsad yo'q", {'v0': _periodLabel}),
                    message: yearly
                        ? context.tr("Yil oxirida nimaga erishgan bo'lishni xohlaysiz? Bir-ikkita katta natijani yozing.")
                        : context.tr("Shu oyda erishmoqchi bo'lgan eng muhim natijani yozing."),
                    actionLabel: context.tr("Maqsad qo'shish"),
                    onAction: _addGoal,
                  )
                : GroupCard(
                    key: ValueKey('l$_period'),
                    indent: 52,
                    children: [
                      for (final g in goals)
                        TaskRow(
                          key: ValueKey(g.id),
                          title: g.title,
                          subtitle: g.description,
                          done: g.completed,
                          onToggle: () => _setGoalDone(g, !g.completed),
                          onTap: () => _editGoal(g),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Kun tanlagich: 14 kun oldin … bugun … 30 kun keyin.
class _DayStrip extends StatefulWidget {
  const _DayStrip({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  static const _before = 14;
  static const _after = 30;
  static const _itemW = 48.0;
  static const _pad = AppSpace.page - 6;
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
    final target = (_pad + idx * _itemW - w / 2 + _itemW / 2).clamp(0.0, _ctrl.position.maxScrollExtent);
    animate ? _ctrl.animateTo(target, duration: AppMotion.base, curve: AppMotion.curve) : _ctrl.jumpTo(target);
  }

  @override
  void didUpdateWidget(covariant _DayStrip oldWidget) {
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
    final onToday = sameDay(sel, today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.page + 4, 0, AppSpace.page - 8, 0),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Text('${uzMonths[sel.month - 1]} ${sel.year}', style: AppType.bodyStrong),
                const Spacer(),
                if (!onToday)
                  TextButton(
                    onPressed: () => widget.onSelect(today),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
                    child:  Text(context.tr("Bugun")),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 68,
          child: ListView.builder(
            controller: _ctrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _pad),
            itemExtent: _itemW,
            itemCount: _before + _after + 1,
            itemBuilder: (context, i) {
              final d = today.add(Duration(days: i - _before));
              final isSel = sameDay(d, sel);
              final isToday = sameDay(d, today);
              final past = d.isBefore(today);
              return Semantics(
                button: true,
                selected: isSel,
                label: longDate(context, d),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    tapFeedback();
                    widget.onSelect(d);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.tr(uzWeekdaysShort[d.weekday - 1]),
                        style: AppType.caption.copyWith(color: isToday ? scheme.tertiary : scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: AppMotion.fast,
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel ? scheme.primary : Colors.transparent,
                        ),
                        child: Text(
                          '${d.day}',
                          style: AppType.body.copyWith(
                            fontWeight: isSel || isToday ? FontWeight.w700 : FontWeight.w500,
                            fontFeatures: tabularFigures,
                            color: isSel
                                ? scheme.onPrimary
                                : isToday
                                ? scheme.tertiary
                                : past
                                ? scheme.outline
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
