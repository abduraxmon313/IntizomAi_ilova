import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/extras.dart';
import '../../models/habit.dart';
import '../../models/plan.dart';
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

  String _view = 'mine';
  List<Plan>? _plans; // oxirgi 98 kun (14 hafta)
  String? _error;

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

  /// Rejalar o'zgarsa (boshqa bo'limda) — statistika qayta hisoblanadi.
  void _onState() {
    if (s.plansVersion != _seenVersion) {
      _seenVersion = s.plansVersion;
      _load();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final t = tashkentToday();
      final r = await Future.wait([
        s.api.plansBetween(t.subtract(const Duration(days: 97)), t),
        s.refreshHabits(),
        s.refreshStats(),
      ]);
      if (mounted) setState(() => _plans = r[0] as List<Plan>);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
        const PageHeader(title: 'Natijalar'),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 8),
          child: SegmentTabs<String>(
            value: _view,
            items: const [('mine', 'Shaxsiy'), ('friends', "Do'stlar"), ('rating', 'Reyting')],
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
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    final plans = _plans;
    if (plans == null) return const LoadingView();

    final scheme = Theme.of(context).colorScheme;
    final st = s.stats;
    final habits = s.habits;
    final goals = s.goals;
    final today = tashkentToday();
    final d7 = today.subtract(const Duration(days: 6));
    final d30 = today.subtract(const Duration(days: 29));
    DateTime pd(Plan p) => parseYmd(p.planDate) ?? today;

    // Bir kunda bajarilgan ishlar: rejalar + odatlar.
    int dayCount(DateTime d) {
      final k = ymd(d);
      return plans.where((p) => p.planDate == k && p.isDone).length + habits.where((h) => h.logDates.contains(k)).length;
    }

    final week = [for (var i = 0; i < 7; i++) dayCount(d7.add(Duration(days: i)))];
    final weekTotal = week.fold<int>(0, (a, b) => a + b);
    final prevTotal = [for (var i = 1; i <= 7; i++) dayCount(d7.subtract(Duration(days: i)))].fold<int>(0, (a, b) => a + b);
    final diff = weekTotal - prevTotal;
    final weekLine = weekTotal == 0
        ? "Oxirgi 7 kunda bajarilgan ish yo'q. Bugun bittasidan boshlang."
        : diff > 0
        ? "Oxirgi 7 kunda $weekTotal ta ish — oldingi haftadan $diff ta ko'p."
        : diff < 0
        ? "Oxirgi 7 kunda $weekTotal ta ish — oldingi haftadan ${-diff} ta kam."
        : "Oxirgi 7 kunda $weekTotal ta ish — oldingi hafta bilan bir xil.";

    // 30 kun: rejalar bajarilishi va faol kunlar.
    final p30 = plans.where((p) => !pd(p).isBefore(d30)).toList();
    final done30 = p30.where((p) => p.isDone).length;
    final rate = p30.isEmpty ? null : (done30 * 100 / p30.length).round();
    final activeDays = [for (var i = 0; i < 30; i++) dayCount(d30.add(Duration(days: i)))].where((c) => c > 0).length;

    // Odatlar: 30 kunlik bajarilish — eng sustidan boshlab (e'tibor kerak joy).
    final habitRates = <(Habit, int, int)>[];
    for (final h in habits.where((h) => !h.finished)) {
      var due = 0, did = 0;
      for (var i = 0; i < 30; i++) {
        final d = d30.add(Duration(days: i));
        if (!h.dueOn(d)) continue;
        due++;
        if (h.doneOn(d)) did++;
      }
      if (due > 0) habitRates.add((h, did, due));
    }
    habitRates.sort((a, b) => (a.$2 / a.$3).compareTo(b.$2 / b.$3));

    final milestones = achievementMilestones(st.streak, st.totalScore, goals.where((g) => g.completed).length);
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
                      Text('intizom', style: AppType.caption.copyWith(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st.rankTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.heading),
                      const SizedBox(height: 2),
                      Text(
                        '${st.level}-daraja · ${st.xpInLevel}/${st.xpNeeded} XP',
                        style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
                      ),
                      const SizedBox(height: 10),
                      AppProgressBar(value: st.xpPercent / 100),
                      const SizedBox(height: 6),
                      Text(
                        'Keyingi darajagacha ${(st.xpNeeded - st.xpInLevel).clamp(0, 1 << 30)} XP',
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
              ('${st.streak} kun', 'Joriy seriya', 'Rekord: ${st.longestStreak} kun'),
              (rate == null ? '—' : '$rate%', 'Rejalar bajarilishi', rate == null ? "30 kunda reja yo'q" : '30 kunda $done30/${p30.length}'),
              ('$activeDays/30', 'Faol kunlar', 'Oxirgi 30 kun'),
              ('${st.perfectDays}', 'Mukammal kunlar', 'Hammasi bajarilgan'),
            ],
          ),

          // ── Hafta ──────────────────────────────────
          const SectionBar(title: 'Shu hafta'),
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
            const SectionBar(title: 'Odatlar', count: '30 kun'),
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
          const SectionBar(title: 'Barqarorlik', count: '14 hafta'),
          Container(
            decoration: surfaceDecoration(context),
            padding: const EdgeInsets.all(16),
            child: _Heatmap(today: today, count: dayCount, color: chart),
          ),

          // ── Maqsad va yutuqlar ─────────────────────
          const SectionBar(title: 'Maqsad va yutuqlar'),
          GroupCard(
            children: [
              for (final (type, label) in const [('yearly', 'Yillik maqsadlar'), ('monthly', 'Oylik maqsadlar')])
                Builder(
                  builder: (_) {
                    final all = goals.where((g) => g.goalType == type).length;
                    final dn = goals.where((g) => g.goalType == type && g.completed).length;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: Text(label, style: AppType.body.copyWith(fontWeight: FontWeight.w500))),
                          Expanded(flex: 4, child: AppProgressBar(value: all == 0 ? 0 : dn / all, color: chart)),
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
                title: 'Yutuqlar',
                subtitle: '${milestones.length} bosqichdan $unlocked tasi ochilgan',
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
    final unit = _lbPeriod == 'streak' ? 'kun' : 'ball';
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, 40),
      children: [
        if (_lbPremium != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PremiumGate(
              icon: LucideIcons.trophy,
              title: 'Reyting Premium bilan ochiladi',
              message: "Natijalaringizni boshqa foydalanuvchilar bilan solishtiring.",
              onOpen: () => showPremiumDialog(context, _lbPremium!),
            ),
          )
        else ...[
          Row(
            children: [
              for (final (v, label) in const [('all', 'Umumiy'), ('week', 'Haftalik'), ('streak', 'Seriya')])
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
          const SizedBox(height: 14),
          if (_lb == null)
            const LoadingView()
          else ...[
            AnimatedOpacity(
              opacity: _lbLoading ? .5 : 1,
              duration: AppMotion.fast,
              child: _lb!.top.isEmpty
                  ? const EmptyView(icon: LucideIcons.trophy, title: "Hali reyting yo'q")
                  : GroupCard(indent: 96, children: [for (final r in _lb!.top) _LeaderTile(row: r, unit: unit)]),
            ),
            if (_lb!.me != null && !_lb!.meInTop) ...[
              const SectionBar(title: "Sizning o'rningiz", top: 20),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(color: scheme.outline, fontWeight: FontWeight.w400, fontFeatures: tabularFigures),
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

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days, required this.values, required this.color});
  final List<DateTime> days;
  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mx = math.max(1, values.fold<int>(0, math.max));
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${values[i]}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontFeatures: tabularFigures)),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    width: 20,
                    height: math.max(3, values[i] / mx * 90),
                    decoration: BoxDecoration(
                      color: values[i] == 0
                          ? scheme.surfaceContainerHigh
                          : sameDay(days[i], tashkentToday())
                          ? color
                          : color.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    uzWeekdaysShort[days[i].weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      color: sameDay(days[i], tashkentToday()) ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: sameDay(days[i], tashkentToday()) ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.today, required this.count, required this.color});
  final DateTime today;
  final int Function(DateTime) count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 14 ustun (hafta) × 7 qator (Du..Ya). Oxirgi ustun — joriy hafta.
    final start = weekStart(today).subtract(const Duration(days: 7 * 13));
    Color shade(int c) {
      if (c == 0) return scheme.surfaceContainerHigh;
      final level = c < 2 ? .28 : c < 4 ? .5 : c < 6 ? .75 : 1.0;
      return color.withValues(alpha: level);
    }

    return Column(
      children: [
        LayoutBuilder(
          builder: (_, box) {
            final cell = (box.maxWidth - 13 * 4) / 14;
            return Column(
              children: [
                for (var r = 0; r < 7; r++)
                  Padding(
                    padding: EdgeInsets.only(bottom: r < 6 ? 4 : 0),
                    child: Row(
                      children: [
                        for (var c = 0; c < 14; c++)
                          Builder(
                            builder: (_) {
                              final d = start.add(Duration(days: c * 7 + r));
                              final future = d.isAfter(today);
                              return Container(
                                width: cell,
                                height: cell,
                                margin: EdgeInsets.only(right: c < 13 ? 4 : 0),
                                decoration: BoxDecoration(
                                  color: future ? Colors.transparent : shade(count(d)),
                                  borderRadius: BorderRadius.circular(3),
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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Kam', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(width: 6),
            for (final c in [0, 1, 3, 5, 6])
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(color: shade(c), borderRadius: BorderRadius.circular(2)),
              ),
            const SizedBox(width: 3),
            Text("Ko'p", style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

class _LeaderTile extends StatelessWidget {
  const _LeaderTile({required this.row, required this.unit});
  final LeaderRow row;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final podium = switch (row.rank) {
      1 => AppPalette.gold,
      2 => const Color(0xFF8C96A3),
      3 => const Color(0xFFA9714B),
      _ => null,
    };
    final photo = IntizomApi.absoluteUrl(row.photoUrl);
    final initial = Text(
      row.name.isEmpty ? '?' : row.name[0].toUpperCase(),
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
    );
    return Container(
      color: row.isMe ? scheme.primary.withValues(alpha: .06) : null,
      padding: const EdgeInsets.fromLTRB(14, 11, 16, 11),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${row.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: tabularFigures,
                color: podium ?? scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHigh,
              border: podium == null ? null : Border.all(color: podium, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: photo == null
                ? initial
                : Image.network(photo, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, _, _) => initial),
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
                    style: TextStyle(fontSize: 15, letterSpacing: -.15, fontWeight: row.isMe ? FontWeight.w600 : FontWeight.w500),
                  ),
                ),
                if (row.isMe) ...[const SizedBox(width: 6), const Pill('Siz')],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${row.value}', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: ' $unit', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
              ],
            ),
            style: const TextStyle(fontSize: 14.5, fontFeatures: tabularFigures),
          ),
        ],
      ),
    );
  }
}

