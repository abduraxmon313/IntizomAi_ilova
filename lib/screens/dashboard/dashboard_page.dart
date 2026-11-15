import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/habit.dart';
import '../../models/plan.dart';
import '../../models/stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';
import '../forms.dart';
import '../profile/profile_page.dart';
import '../stats/stats_page.dart';

/// Asosiy: sarlavha, intizom kartasi, tavsiyalar, kun tasmasi, kunning rejalari.
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.state,
    required this.onLogout,
    required this.onAppearanceChanged,
    required this.onLanguageChanged,
  });

  final AppState state;
  final VoidCallback onLogout;
  final ValueChanged<String> onAppearanceChanged;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AppState get s => widget.state;

  DateTime _day = tashkentToday();
  List<Plan> _plans = const [];
  List<Plan> _week = const []; // oxirgi 7 kun (tavsiyalar uchun)
  bool _loadingPlans = true;
  int _seenVersion = -1;

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
    _loadPlans();
    _loadWeek();
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
      _loadWeek();
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

  Future<void> _loadWeek() async {
    try {
      final t = tashkentToday();
      final w = await s.api.plansBetween(t.subtract(const Duration(days: 7)), t);
      if (mounted) setState(() => _week = w);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    await Future.wait([s.loadAll(), _loadPlans(), _loadWeek()]);
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
      if (updated.isDone) toast(context, '+${updated.scoreValue} ball');
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
        toast(context, '${updated.streak} kunlik streak');
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

  void _openProfile() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProfilePage(
        state: s,
        onLogout: widget.onLogout,
        onAppearanceChanged: widget.onAppearanceChanged,
        onLanguageChanged: widget.onLanguageChanged,
      ),
    ),
  );

  void _openStats() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StatsPage(state: s)));

  @override
  Widget build(BuildContext context) {
    final profile = s.profile!;
    final dayHabits = s.habits.where((h) => !h.finished || h.doneOn(_day)).where((h) => h.dueOn(_day)).toList()
      ..sort((a, b) => (a.reminderTime ?? '99:99').compareTo(b.reminderTime ?? '99:99'));
    final plans = [..._plans]..sort((a, b) => (a.scheduledTime ?? '99:99').compareTo(b.scheduledTime ?? '99:99'));
    final doneCount = plans.where((p) => p.isDone).length + dayHabits.where((h) => h.doneOn(_day)).length;
    final total = plans.length + dayHabits.length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _Header(
            name: profile.fullName,
            avatar: profile.avatar,
            telegramId: profile.telegramId,
            onProfile: _openProfile,
            onStats: _openStats,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                _SummaryCard(stats: s.stats, onTap: _openStats),
                ..._insights(),
                const SizedBox(height: 18),
              ],
            ),
          ),
          _DayStrip(selected: _day, onSelect: _selectDay),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionBar(
                  title: _dayTitle(),
                  count: total > 0 ? '$doneCount/$total' : null,
                  actionLabel: "Reja qo'shish",
                  onAction: _addPlan,
                ),
                if (_loadingPlans)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                  )
                else if (total == 0)
                  EmptyView(
                    icon: LucideIcons.calendarCheck,
                    title: "Bu kunga reja yo'q",
                    message: "Reja qo'shing — vaqtida bot eslatadi.",
                    actionLabel: "Reja qo'shish",
                    onAction: _addPlan,
                  )
                else
                  GroupCard(
                    children: [
                      for (final p in plans)
                        _PlanRow(
                          plan: p,
                          onToggle: () => _togglePlan(p),
                          onEdit: () => _editPlan(p),
                          onDelete: () => _deletePlan(p),
                        ),
                      for (final h in dayHabits)
                        _HabitRow(
                          habit: h,
                          done: h.doneOn(_day) || (sameDay(_day, tashkentToday()) && h.doneToday),
                          onToggle: () => _toggleHabit(h),
                        ),
                    ],
                  ),
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

  /// Mini App'dagi "Smart insights" qoidalari.
  List<Widget> _insights() {
    final st = s.stats;
    final done7 = _week.where((p) => p.isDone).length;
    final total7 = _week.length;
    final rate = total7 == 0 ? 0 : (done7 * 100 / total7).round();
    final items = <(IconData, Color, String, String)>[];
    if (st.streak >= 7) {
      items.add((LucideIcons.flame, AppPalette.streakOrange, 'Zo\'r ketyapsiz', '${st.streak} kunlik streak — davom eting.'));
    }
    if (st.disciplineScore >= 75) {
      items.add((LucideIcons.gem, AppPalette.accentViolet, 'Intizom yuqori darajada', 'Siz rejani bajaradigan insonsiz.'));
    }
    if (rate >= 80 && total7 >= 5) {
      items.add((LucideIcons.trendingUp, AppPalette.disciplineGreen, 'Hafta yaxshi o\'tdi', '$done7/$total7 reja bajarildi.'));
    }
    if (rate < 40 && total7 >= 5) {
      items.add((LucideIcons.trendingDown, AppPalette.warning, 'Bu hafta sustroq', "Bitta yengil reja qo'shing — maromga qaytasiz."));
    }
    if (st.disciplineScore < 40) {
      items.add((LucideIcons.target, AppPalette.danger, 'Intizom pasaymoqda', 'Bugun bitta kichik ishni bajaring.'));
    }
    if (st.streak == 0 && total7 > 0) {
      items.add((LucideIcons.sprout, AppPalette.accentGreen, 'Yangi boshlanish', 'Birinchi qadam eng qiyini, lekin eng muhimi.'));
    }
    if (items.isEmpty) return const [];
    return [
      const SectionBar(title: 'Tavsiyalar'),
      GroupCard(
        children: [
          for (final (icon, color, title, text) in items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AppIconTile.tinted(icon: icon, accent: color, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(
                          text,
                          style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.avatar,
    required this.telegramId,
    required this.onProfile,
    required this.onStats,
  });

  final String name;
  final String? avatar;
  final int telegramId;
  final VoidCallback onProfile;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onProfile,
            child: ProfileAvatar(url: avatar, telegramId: telegramId, name: name, size: 42),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -.3),
                  ),
                  Text(longDate(tashkentToday()), style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          HeaderIconButton(icon: LucideIcons.chartColumn, tooltip: 'Statistika', onTap: onStats),
          HeaderIconButton(icon: LucideIcons.settings, tooltip: 'Sozlamalar', onTap: onProfile),
        ],
      ),
    );
  }
}

/// Intizom balli halqasi + daraja + XP + streak.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats, required this.onTap});

  final UserStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final risk = stats.streakAtRisk && stats.streak > 0;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              ScoreRing(value: stats.disciplineScore, size: 84, label: 'Intizom'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.rankTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${stats.level}-daraja · ${stats.xpInLevel}/${stats.xpNeeded} XP',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    AppProgressBar(value: stats.xpPercent / 100, height: 6),
                    const SizedBox(height: 6),
                    Text(
                      'Jami ${stats.xp} XP',
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: LucideIcons.flame,
                  color: AppPalette.streakOrange,
                  value: '${stats.streak} kun',
                  label: 'Streak',
                ),
              ),
              Expanded(
                child: _Metric(
                  icon: risk ? LucideIcons.triangleAlert : LucideIcons.circleCheck,
                  color: risk ? AppPalette.warning : AppPalette.disciplineGreen,
                  value: '${stats.todayDone}/${stats.todayTotal}',
                  label: risk ? 'Streak xavf ostida' : 'Bugun',
                ),
              ),
              Expanded(
                child: _Metric(
                  icon: LucideIcons.star,
                  color: AppPalette.levelGold,
                  value: '${stats.totalScore}',
                  label: 'Ball',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, maxLines: 1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ingichka halqali ko'rsatkich (0..100).
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.value, this.size = 80, this.label, this.color});

  final int value;
  final double size;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ??
        (value >= 70
            ? AppPalette.disciplineGreen
            : value >= 40
                ? scheme.primary
                : AppPalette.warning);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value / 100, c, scheme.surfaceContainerHigh),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value', style: TextStyle(fontSize: size * .28, fontWeight: FontWeight.w700, letterSpacing: -.5)),
              if (label != null)
                Text(label!, style: TextStyle(fontSize: size * .125, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track);

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .08;
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress.clamp(0, 1), false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color || old.track != track;
}

/// Gorizontal kun tasmasi: 14 kun oldin … bugun … 30 kun keyin.
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
  static const _itemW = 52.0;
  static const _gap = 6.0;
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
    final target = (16 + idx * (_itemW + _gap) - w / 2 + _itemW / 2).clamp(0.0, _ctrl.position.maxScrollExtent);
    if (animate) {
      _ctrl.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _ctrl.jumpTo(target);
    }
  }

  @override
  void didUpdateWidget(covariant _DayStrip old) {
    super.didUpdateWidget(old);
    if (!sameDay(old.selected, widget.selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _center());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = tashkentToday();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _before + _after + 1,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, i) {
          final d = today.add(Duration(days: i - _before));
          final sel = sameDay(d, widget.selected);
          final isToday = sameDay(d, today);
          return GestureDetector(
            onTap: () => widget.onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: _itemW,
              decoration: BoxDecoration(
                color: sel ? scheme.primary : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: sel ? scheme.primary : scheme.outlineVariant),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? 'Bugun' : uzWeekdaysShort[d.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: sel ? scheme.onPrimary.withValues(alpha: .85) : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: sel ? scheme.onPrimary : (isToday ? scheme.primary : scheme.onSurface),
                    ),
                  ),
                  Text(
                    uzMonthsShort[d.month - 1],
                    style: TextStyle(
                      fontSize: 10,
                      color: sel ? scheme.onPrimary.withValues(alpha: .85) : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, required this.onToggle, required this.onEdit, required this.onDelete});

  final Plan plan;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: Row(
          children: [
            CheckCircle(checked: plan.isDone, color: scheme.primary, onTap: onToggle),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: plan.isDone ? scheme.onSurfaceVariant : scheme.onSurface,
                      decoration: plan.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      MetaTag(
                        icon: LucideIcons.clock,
                        text: plan.scheduledTime?.isNotEmpty == true ? plan.scheduledTime! : 'Vaqtsiz',
                      ),
                      if (plan.description?.isNotEmpty == true)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            plan.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '+${plan.scoreValue}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
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
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: Row(
          children: [
            CheckCircle(checked: done, onTap: onToggle),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${habit.icon}  ${habit.title}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 10,
                    children: [
                      const MetaTag(icon: LucideIcons.repeat, text: 'Odat'),
                      if (habit.reminderTime != null) MetaTag(icon: LucideIcons.bell, text: habit.reminderTime!),
                      MetaTag(icon: LucideIcons.flame, text: '${habit.streak} kun', color: AppPalette.streakOrange),
                    ],
                  ),
                ],
              ),
            ),
            Text('+5', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
