import '../../l10n/app_localizations.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/extras.dart';
import '../../models/habit.dart';
import '../../models/stats.dart';
import '../../services/api_client.dart';
import '../../services/intizom_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';
import '../achievements/achievements_page.dart';
import '../friends/friends_page.dart';

/// Natijalar — "qanday ketyapman?" savolining yagona joyi:
/// Shaxsiy (o'zimning tahlilim) · Do'stlar (guruhlar) · Reyting (hammaga nisbatan).
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.state});

  final AppState state;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  AppState get s => widget.state;

  static const _days = 98; // 14 hafta — issiqlik xaritasi uchun

  String _view = 'mine';

  /// Kunma-kun faollik (server hisoblaydi), kalit — YYYY-MM-DD.
  Map<String, DayActivity>? _activity;
  String? _error;
  List<Habit>? _seenHabits;

  String _lbPeriod = 'all';
  Leaderboard? _lb;
  String? _lbPremium;
  bool _lbLoading = false;

  int _seenVersion = 0;

  @override
  void initState() {
    super.initState();
    _seenVersion = s.plansVersion;
    s.addListener(_onState);
    _load();
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    super.dispose();
  }

  /// Reja yoki odat o'zgarsa (boshqa bo'limda) — faollik qayta yuklanadi.
  void _onState() {
    if (s.plansVersion != _seenVersion) {
      _seenVersion = s.plansVersion;
      _loadActivity();
    } else if (!identical(s.habits, _seenHabits)) {
      _seenHabits = s.habits;
      _loadActivity();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await Future.wait([_fetchActivity(), s.refreshHabits(), s.refreshStats()]);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _fetchActivity() async {
    final days = await s.api.activity(_days);
    _seenHabits = s.habits;
    if (mounted) setState(() => _activity = {for (final d in days) d.date: d});
  }

  Future<void> _loadActivity() async {
    try {
      await _fetchActivity();
    } catch (_) {
      // Tarmoq xatosi — eski ma'lumot qoladi, keyingi o'zgarishda qayta urinamiz.
    }
  }

  Future<void> _loadLb() async {
    setState(() {
      _lbLoading = true;
      _lbPremium = null;
    });
    try {
      final lb = await s.api.leaderboard(_lbPeriod);
      if (mounted) setState(() => _lb = lb);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.needsPremium) {
        setState(() => _lbPremium = e.message);
      } else {
        showApiError(context, e);
      }
    } finally {
      if (mounted) setState(() => _lbLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
         PageHeader(title: context.tr("Natijalar")),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 8),
          child: SegmentTabs<String>(
            value: _view,
            items:  [('mine', context.tr("Shaxsiy")), ('friends', context.tr("Do'stlar")), ('rating', context.tr("Reyting"))],
            onChanged: (v) {
              setState(() => _view = v);
              if (v == 'rating' && _lb == null && _lbPremium == null) _loadLb();
            },
          ),
        ),
        Expanded(
          child: switch (_view) {
            'friends' => FriendsPage(state: s),
            'rating' => _rating(),
            _ => _mine(),
          },
        ),
      ],
    );
  }

  // ── Shaxsiy ────────────────────────────────────────
  Widget _mine() {
    final activity = _activity;
    if (activity == null) {
      return _error != null ? ErrorRetry(message: _error!, onRetry: _load) : const LoadingView();
    }

    final scheme = Theme.of(context).colorScheme;
    final st = s.stats;
    final habits = s.habits;
    final goals = s.goals;
    final today = tashkentToday();
    final d7 = today.subtract(const Duration(days: 6));
    final d30 = today.subtract(const Duration(days: 29));
    final last30 = [for (var i = 0; i < 30; i++) activity[ymd(d30.add(Duration(days: i)))]].nonNulls.toList();

    // Bir kunda bajarilgan ishlar: rejalar + odatlar (o'chirilgan odatlar tarixi ham).
    int dayCount(DateTime d) => activity[ymd(d)]?.done ?? 0;

    final week = [for (var i = 0; i < 7; i++) dayCount(d7.add(Duration(days: i)))];
    final weekTotal = week.fold<int>(0, (a, b) => a + b);
    final prevTotal = [for (var i = 1; i <= 7; i++) dayCount(d7.subtract(Duration(days: i)))].fold<int>(0, (a, b) => a + b);
    final diff = weekTotal - prevTotal;
    final weekLine = weekTotal == 0
        ? context.tr("Oxirgi 7 kunda bajarilgan ish yo'q. Bugun bittasidan boshlang.")
        : diff > 0
        ? context.tr("Oxirgi 7 kunda {v0} ta ish — oldingi haftadan {v1} ta ko'p.", {'v0': weekTotal, 'v1': diff})
        : diff < 0
        ? context.tr("Oxirgi 7 kunda {v0} ta ish — oldingi haftadan {v1} ta kam.", {'v0': weekTotal, 'v1': -diff})
        : context.tr("Oxirgi 7 kunda {v0} ta ish — oldingi hafta bilan bir xil.", {'v0': weekTotal});

    // 30 kun: rejalar bajarilishi (faqat vaqti o'tgan yoki bajarilganlar) va faol kunlar.
    final done30 = last30.fold<int>(0, (a, d) => a + d.plansDone);
    final due30 = last30.fold<int>(0, (a, d) => a + d.plansDue);
    final rate = due30 == 0 ? null : (done30 * 100 / due30).round();
    final activeDays = last30.where((d) => d.done > 0).length;

    // Odatlar: 30 kunlik bajarilish — eng sustidan boshlab (e'tibor kerak joy).
    // Bugun hali belgilanmagan bo'lsa — bugun hisobga kirmaydi (kun tugamagan).
    final habitRates = <(Habit, int, int)>[];
    for (final h in habits.where((h) => !h.finished)) {
      var due = 0, did = 0;
      for (var i = 0; i < 30; i++) {
        final d = d30.add(Duration(days: i));
        final done = h.doneOn(d);
        if (!done && (!h.dueOn(d) || sameDay(d, today))) continue;
        due++;
        if (done) did++;
      }
      if (due > 0) habitRates.add((h, did, due));
    }
    habitRates.sort((a, b) => (a.$2 / a.$3).compareTo(b.$2 / b.$3));

    final milestones = achievementMilestones(st.longestStreak, st.totalScore, goals.where((g) => g.completed).length);
    final unlocked = milestones.where((a) => a.unlocked).length;
    final chart = Theme.of(context).brightness == Brightness.dark ? AppPalette.brandOnDark : AppPalette.brandBright;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, 40),
        children: [
          // ── Intizom va daraja ──────────────────────
          Container(
            decoration: surfaceDecoration(context, radius: AppRadius.xl),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                ProgressRing(
                  value: st.disciplineScore.clamp(0, 100) / 100,
                  size: 84,
                  stroke: 8,
                  color: chart,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${st.disciplineScore.clamp(0, 100)}',
                        style: AppType.title.copyWith(fontSize: 24, height: 1.05, fontFeatures: tabularFigures),
                      ),
                      Text(context.tr("intizom"), style: AppType.micro.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr(st.rankTitle), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.heading),
                      const SizedBox(height: 2),
                      Text(
                        context.tr("{v0}-daraja · {v1}/{v2} XP", {'v0': st.level, 'v1': st.xpInLevel, 'v2': st.xpNeeded}),
                        style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
                      ),
                      const SizedBox(height: 10),
                      AppProgressBar(value: st.xpPercent / 100),
                      const SizedBox(height: 6),
                      Text(
                        context.tr("Keyingi darajagacha {v0} XP", {'v0': (st.xpNeeded - st.xpInLevel).clamp(0, 1 << 30)}),
                        style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400, fontFeatures: tabularFigures),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _FactGrid(
            items: [
              (context.tr("{v0} kun", {'v0': st.streak}), context.tr("Joriy seriya"), context.tr("Rekord: {v0} kun", {'v0': st.longestStreak})),
              (rate == null ? '—' : '$rate%', context.tr("Rejalar bajarilishi"), rate == null ? context.tr("30 kunda reja yo'q") : context.tr("30 kunda {v0}/{v1}", {'v0': done30, 'v1': due30})),
              ('$activeDays/30', context.tr("Faol kunlar"), context.tr("Oxirgi 30 kun")),
              ('${st.perfectDays}', context.tr("Mukammal kunlar"), context.tr("Hammasi bajarilgan")),
            ],
          ),

          // ── Hafta ──────────────────────────────────
           SectionBar(title: context.tr("Shu hafta")),
          Container(
            decoration: surfaceDecoration(context),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(weekLine, style: AppType.body.copyWith(fontWeight: FontWeight.w500, height: 1.35)),
                const SizedBox(height: 14),
                _WeekBars(days: [for (var i = 0; i < 7; i++) d7.add(Duration(days: i))], values: week, color: chart),
              ],
            ),
          ),

          // ── Odatlar ────────────────────────────────
          if (habitRates.isNotEmpty) ...[
             SectionBar(title: context.tr("Odatlar"), count: context.tr("30 kun")),
            Container(
              decoration: surfaceDecoration(context),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Column(
                children: [
                  for (final (h, did, due) in habitRates)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  h.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.body.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(did * 100 / due).round()}%',
                                style: AppType.label.copyWith(fontWeight: FontWeight.w600, fontFeatures: tabularFigures),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AppProgressBar(value: did / due, color: chart),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── Barqarorlik ────────────────────────────
           SectionBar(title: context.tr("Barqarorlik"), count: context.tr("14 hafta")),
          Container(
            decoration: surfaceDecoration(context),
            padding: const EdgeInsets.all(16),
            child: _Heatmap(today: today, count: dayCount, color: chart),
          ),

          // ── Maqsad va yutuqlar ─────────────────────
           SectionBar(title: context.tr("Maqsad va yutuqlar")),
          GroupCard(
            children: [
              for (final (type, label) in  [('yearly', context.tr("Yillik maqsadlar")), ('monthly', context.tr("Oylik maqsadlar"))])
                Builder(
                  builder: (_) {
                    final all = goals.where((g) => g.goalType == type).length;
                    final dn = goals.where((g) => g.goalType == type && g.completed).length;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(width: 72, child: AppProgressBar(value: all == 0 ? 0 : dn / all, color: chart)),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '$dn/$all',
                              textAlign: TextAlign.end,
                              style: AppType.label.copyWith(fontWeight: FontWeight.w600, fontFeatures: tabularFigures),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              SettingTile(
                icon: LucideIcons.trophy,
                title: context.tr("Yutuqlar"),
                subtitle: context.tr("{v0} bosqichdan {v1} tasi ochilgan", {'v0': milestones.length, 'v1': unlocked}),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(body: SafeArea(child: AchievementsPage(state: s))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Reyting ────────────────────────────────────────
  Widget _rating() {
    final unit = _lbPeriod == 'streak' ? context.tr("kun") : context.tr("ball");
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, 40),
      children: [
        if (_lbPremium != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PremiumGate(
              icon: LucideIcons.trophy,
              title: context.tr("Reyting Premium bilan ochiladi"),
              message: context.tr("Natijalaringizni boshqa foydalanuvchilar bilan solishtiring."),
              onOpen: () => showPremiumDialog(context, _lbPremium!),
            ),
          )
        else ...[
          Row(
            children: [
              for (final (v, label) in  [('all', context.tr("Umumiy")), ('week', context.tr("Haftalik")), ('streak', context.tr("Seriya"))])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: label,
                    selected: _lbPeriod == v,
                    onTap: () {
                      setState(() => _lbPeriod = v);
                      _loadLb();
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const _PremiumMark(),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr("— Premium foydalanuvchi"),
                  style: AppType.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_lb == null)
            const LoadingView()
          else ...[
            AnimatedOpacity(
              opacity: _lbLoading ? .5 : 1,
              duration: AppMotion.fast,
              child: _lb!.top.isEmpty
                  ?  EmptyView(icon: LucideIcons.trophy, title: context.tr("Hali reyting yo'q"))
                  : GroupCard(indent: 94, children: [for (final r in _lb!.top) _LeaderTile(row: r, unit: unit)]),
            ),
            if (_lb!.me != null && !_lb!.meInTop) ...[
               SectionBar(title: context.tr("Sizning o'rningiz"), top: 20),
              GroupCard(children: [_LeaderTile(row: _lb!.me!, unit: unit)]),
            ],
          ],
        ],
      ],
    );
  }
}

/// Ikkinchi darajali filtr (segment ichidagi tanlov).
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          if (selected) return;
          tapFeedback();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.onSurface : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: AppType.label.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? scheme.surface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 2×2 raqamlar: qiymat, nom, izoh. Bitta yuzada, ingichka ajratgichlar bilan.
class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.items});
  final List<(String, String, String)> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell((String, String, String) m) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.caption.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(
            m.$1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.title.copyWith(fontFeatures: tabularFigures),
          ),
          const SizedBox(height: 2),
          Text(
            m.$3,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400, fontFeatures: tabularFigures),
          ),
        ],
      ),
    );

    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(Divider(height: 1, color: scheme.outlineVariant));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cell(items[i])),
              VerticalDivider(width: 1, color: scheme.outlineVariant),
              Expanded(child: i + 1 < items.length ? cell(items[i + 1]) : const SizedBox()),
            ],
          ),
        ),
      );
    }
    return Container(decoration: surfaceDecoration(context), child: Column(children: rows));
  }
}

/// Haftalik ustunlar: bugungi kun — to'liq brend rangda, qolganlari och tonda.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days, required this.values, required this.color});
  final List<DateTime> days;
  final List<int> values;
  final Color color;

  static const _barMax = 88.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = tashkentToday();
    final mx = math.max(1, values.fold<int>(0, math.max));
    return Semantics(
      label: [
        for (var i = 0; i < days.length; i++) context.tr("{v0}: {v1} ta", {'v0': context.tr(uzWeekdays[days[i].weekday - 1]), 'v1': values[i]}),
      ].join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: _barMax + 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Builder(
                  builder: (_) {
                    final isToday = sameDay(days[i], today);
                    final v = values[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$v',
                          style: AppType.micro.copyWith(
                            fontFeatures: tabularFigures,
                            fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                            color: v == 0 ? scheme.outline : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: v / mx),
                          duration: AppMotion.slow,
                          curve: AppMotion.curve,
                          builder: (_, f, _) => Container(
                            width: 22,
                            height: math.max(4, f * _barMax),
                            decoration: BoxDecoration(
                              color: v == 0
                                  ? scheme.surfaceContainerHigh
                                  : isToday
                                  ? color
                                  : color.withValues(alpha: .38),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(uzWeekdaysShort[days[i].weekday - 1]),
                          style: AppType.micro.copyWith(
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            color: isToday ? scheme.tertiary : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 14 hafta × 7 kun. Katak o'lchami eniga moslashadi, chap ustunda — hafta kunlari.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.today, required this.count, required this.color});
  final DateTime today;
  final int Function(DateTime) count;
  final Color color;

  static const _weeks = 14;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = weekStart(today).subtract(const Duration(days: 7 * (_weeks - 1)));
    Color shade(int c) {
      if (c == 0) return scheme.surfaceContainerHigh;
      final level = c < 2 ? .28 : c < 4 ? .5 : c < 6 ? .75 : 1.0;
      return color.withValues(alpha: level);
    }

    final labelStyle = AppType.micro.copyWith(color: scheme.onSurfaceVariant);
    Widget swatch(int c) => Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(color: shade(c), borderRadius: BorderRadius.circular(2)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (_, box) {
            const labelW = 24.0;
            final cell = ((box.maxWidth - labelW - (_weeks - 1) * _gap) / _weeks).clamp(8.0, 22.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var r = 0; r < 7; r++)
                        SizedBox(
                          height: cell + (r < 6 ? _gap : 0),
                          child: r.isEven
                              ? Align(alignment: Alignment.topLeft, child: Text(context.tr(uzWeekdaysShort[r]), style: labelStyle))
                              : null,
                        ),
                    ],
                  ),
                ),
                for (var c = 0; c < _weeks; c++)
                  Padding(
                    padding: EdgeInsets.only(right: c < _weeks - 1 ? _gap : 0),
                    child: Column(
                      children: [
                        for (var r = 0; r < 7; r++)
                          Builder(
                            builder: (_) {
                              final d = start.add(Duration(days: c * 7 + r));
                              final future = d.isAfter(today);
                              return Container(
                                width: cell,
                                height: cell,
                                margin: EdgeInsets.only(bottom: r < 6 ? _gap : 0),
                                decoration: BoxDecoration(
                                  color: future ? Colors.transparent : shade(count(d)),
                                  borderRadius: BorderRadius.circular(3),
                                  border: sameDay(d, today) ? Border.all(color: scheme.tertiary, width: 1.2) : null,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(shortDate(context, start), style: labelStyle.copyWith(fontFeatures: tabularFigures)),
            const Spacer(),
            Text(context.tr("Kam"), style: labelStyle),
            const SizedBox(width: 6),
            for (final c in [0, 1, 3, 5, 6]) swatch(c),
            const SizedBox(width: 6),
            Text(context.tr("Ko'p"), style: labelStyle),
          ],
        ),
      ],
    );
  }
}

/// Reytingda Premium foydalanuvchi belgisi: binafsha doirachada toj.
class _PremiumMark extends StatelessWidget {
  const _PremiumMark();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Tooltip(
      message: 'Premium',
      child: Semantics(
        label: 'Premium',
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppPalette.premiumFill(b), shape: BoxShape.circle),
          child: Icon(LucideIcons.crown, size: 11, color: AppPalette.onPremium(b)),
        ),
      ),
    );
  }
}

/// Reyting qatori: o'rin, avatar, ism, natija. Birinchi uchtalik — chegarali avatar.
class _LeaderTile extends StatelessWidget {
  const _LeaderTile({required this.row, required this.unit});
  final LeaderRow row;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final podium = switch (row.rank) {
      1 => AppPalette.gold,
      2 => dark ? scheme.onSurfaceVariant : AppPalette.ink2,
      3 => AppPalette.bronze,
      _ => null,
    };
    final photo = IntizomApi.absoluteUrl(row.photoUrl);
    final initial = Text(
      row.name.isEmpty ? '?' : row.name.characters.first.toUpperCase(),
      style: AppType.label.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
    );
    return Container(
      color: row.isMe ? scheme.primaryContainer.withValues(alpha: dark ? .45 : .6) : null,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${row.rank}',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: AppType.label.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: tabularFigures,
                color: podium == null ? scheme.onSurfaceVariant : AppPalette.textTone(podium, theme.brightness),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHigh,
              border: podium == null ? null : Border.all(color: podium, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: photo == null
                ? initial
                : Image.network(photo, width: 34, height: 34, fit: BoxFit.cover, errorBuilder: (_, _, _) => initial),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(fontWeight: row.isMe ? FontWeight.w600 : FontWeight.w500),
                  ),
                ),
                if (row.isPremium) ...[const SizedBox(width: 6), const _PremiumMark()],
                if (row.isMe) ...[const SizedBox(width: 6),  Pill(context.tr("Siz"))],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${row.value}', style: AppType.bodyStrong.copyWith(fontFeatures: tabularFigures)),
                TextSpan(text: ' $unit', style: AppType.caption.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
