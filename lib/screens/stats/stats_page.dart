import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/extras.dart';
import '../../models/plan.dart';
import '../../services/api_client.dart';
import '../../services/intizom_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';

const _habitScore = 5;

/// Statistika: Mening / Reyting.
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
          const PageHeader(title: 'Statistika', subtitle: "Natijalaringiz va reyting"),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, 4),
            child: SegmentTabs<String>(
              value: _view,
              items: const [('mine', 'Mening', LucideIcons.chartColumn), ('rating', 'Reyting', LucideIcons.trophy)],
              onChanged: (v) {
                setState(() => _view = v);
                if (v == 'rating' && _lb == null && _lbPremium == null) _loadLb();
              },
            ),
          ),
          Expanded(child: _view == 'mine' ? _mine() : _rating()),
        ],
    );
  }

  // ── Mening statistikam ─────────────────────────────
  Widget _mine() {
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    final plans = _plans;
    if (plans == null) return const Center(child: CircularProgressIndicator());

    final st = s.stats;
    final habits = s.habits;
    final goals = s.goals;
    final today = tashkentToday();
    final d7 = today.subtract(const Duration(days: 6));
    final d30 = today.subtract(const Duration(days: 29));
    DateTime pd(Plan p) => parseYmd(p.planDate) ?? today;

    final p30 = plans.where((p) => !pd(p).isBefore(d30)).toList();
    final done30 = p30.where((p) => p.isDone).toList();

    // Kunlik ball: bajarilgan rejalar + bajarilgan odatlar.
    int dayScore(DateTime d) {
      final k = ymd(d);
      final ps = plans.where((p) => p.planDate == k && p.isDone).fold<int>(0, (a, p) => a + p.scoreValue);
      final hs = habits.where((h) => h.logDates.contains(k)).length * _habitScore;
      return ps + hs;
    }

    int dayCount(DateTime d) {
      final k = ymd(d);
      return plans.where((p) => p.planDate == k && p.isDone).length + habits.where((h) => h.logDates.contains(k)).length;
    }

    final weekScore = [for (var i = 0; i < 7; i++) dayScore(d7.add(Duration(days: i)))].fold<int>(0, (a, b) => a + b);
    final monthStart = DateTime(today.year, today.month);
    final doneThisMonth = plans.where((p) => p.isDone && !pd(p).isBefore(monthStart)).length +
        habits.fold<int>(0, (a, h) => a + h.logDates.where((k) => (parseYmd(k) ?? today).isAfter(monthStart.subtract(const Duration(days: 1)))).length);

    // 30 kunlik tahlil (Mini App: renderExtraStats).
    final rate = p30.isEmpty ? 0 : (done30.length * 100 / p30.length).round();
    final byDay = <String, int>{};
    for (final p in done30) {
      byDay[p.planDate] = (byDay[p.planDate] ?? 0) + p.scoreValue;
    }
    final avg = byDay.isEmpty ? 0 : (byDay.values.fold<int>(0, (a, b) => a + b) / byDay.length).round();
    final best = byDay.entries.fold<MapEntry<String, int>?>(null, (m, e) => m == null || e.value > m.value ? e : m);

    // Odatlar.
    final dueToday = habits.where((h) => h.dueToday && !h.finished).toList();
    final habitsDoneToday = dueToday.where((h) => h.doneToday).length;
    final bestStreak = habits.fold<int>(0, (m, h) => math.max(m, h.streak));
    final habitTotal = habits.fold<int>(0, (a, h) => a + h.totalDone);

    // Maqsadlar.
    final goalsDone = goals.where((g) => g.completed).length;
    final goalPct = goals.isEmpty ? 0 : (goalsDone * 100 / goals.length).round();

    final chart = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 40),
        children: [
          _Hero(
            discipline: st.disciplineScore,
            level: st.level,
            rank: st.rankTitle,
            xpInLevel: st.xpInLevel,
            xpNeeded: st.xpNeeded,
            xpPercent: st.xpPercent,
            perfectDays: st.perfectDays,
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            items: [
              _Metric(LucideIcons.flame, '${st.streak}', 'Joriy streak', 'Eng uzuni: ${st.longestStreak} kun', AppPalette.ember),
              _Metric(LucideIcons.star, '${st.totalScore}', 'Jami ball', '+$weekScore bu hafta', AppPalette.accentAmber),
              _Metric(LucideIcons.circleCheck, '$doneThisMonth', 'Bajarilgan', 'Bu oy', AppPalette.accentBlue),
              _Metric(LucideIcons.target, '${goals.where((g) => !g.completed).length}', 'Maqsadlar', 'Faol', AppPalette.accentTeal),
            ],
          ),
          const SectionBar(title: '30 kunlik tahlil'),
          _MetricGrid(
            items: [
              _Metric(LucideIcons.trendingUp, '$rate%', 'Bajarish', '${done30.length}/${p30.length} reja', AppPalette.accentBlue),
              _Metric(LucideIcons.zap, '$avg', "O'rtacha ball", 'Faol kunda', AppPalette.accentAmber),
              _Metric(
                LucideIcons.award,
                best == null ? '—' : shortDate(parseYmd(best.key) ?? today),
                'Eng yaxshi kun',
                best == null ? null : '+${best.value} ball',
                AppPalette.accentViolet,
              ),
              _Metric(LucideIcons.calendarDays, '${byDay.length}', 'Faol kunlar', '30 kun ichida', AppPalette.accentIndigo),
            ],
          ),
          if (habits.isNotEmpty) ...[
            const SectionBar(title: 'Odatlar'),
            _MetricGrid(
              items: [
                _Metric(LucideIcons.squareCheck, '$habitsDoneToday/${dueToday.length}', 'Bugun', 'bajarildi', AppPalette.accentBlue),
                _Metric(LucideIcons.flame, '$bestStreak', 'Eng uzun streak', 'kun', AppPalette.ember),
                _Metric(LucideIcons.repeat, '${habits.length}', 'Faol odatlar', 'ta', AppPalette.accentTeal),
                _Metric(LucideIcons.listChecks, '$habitTotal', 'Jami bajarilgan', 'marta', AppPalette.accentViolet),
              ],
            ),
          ],
          const SectionBar(title: 'Haftalik faollik', count: 'oxirgi 7 kun'),
          _ChartCard(
            child: _WeekBars(
              days: [for (var i = 0; i < 7; i++) d7.add(Duration(days: i))],
              values: [for (var i = 0; i < 7; i++) dayCount(d7.add(Duration(days: i)))],
              color: chart,
            ),
          ),
          const SectionBar(title: 'Ball trendi', count: '30 kun'),
          _ChartCard(
            child: SizedBox(
              height: 150,
              child: CustomPaint(
                size: Size.infinite,
                painter: _TrendPainter(
                  [for (var i = 0; i < 30; i++) dayScore(d30.add(Duration(days: i)))],
                  chart,
                  Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
          const SectionBar(title: 'Faollik xaritasi', count: '14 hafta'),
          _ChartCard(child: _Heatmap(today: today, count: dayCount, color: chart)),
          const SectionBar(title: 'Maqsadlar bajarilishi'),
          _ChartCard(
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CustomPaint(
                    painter: _DonutPainter(goalPct / 100, chart, Theme.of(context).colorScheme.surfaceContainerHigh),
                    child: Center(child: Text('$goalPct%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.6, fontFeatures: tabularFigures))),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      for (final (type, label) in const [('yearly', 'Yillik'), ('monthly', 'Oylik')])
                        Builder(
                          builder: (_) {
                            final all = goals.where((g) => g.goalType == type).length;
                            final dn = goals.where((g) => g.goalType == type && g.completed).length;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  SizedBox(width: 56, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                  Expanded(child: AppProgressBar(value: all == 0 ? 0 : dn / all, color: chart)),
                                  const SizedBox(width: 10),
                                  Text('$dn/$all', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFeatures: tabularFigures)),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reyting ────────────────────────────────────────
  Widget _rating() {
    final scheme = Theme.of(context).colorScheme;
    final unit = _lbPeriod == 'streak' ? 'kun' : 'ball';
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 40),
      children: [
        SegmentTabs<String>(
          value: _lbPeriod,
          items: const [('all', 'Umumiy', null), ('week', 'Haftalik', null), ('streak', 'Streak', null)],
          onChanged: (v) {
            setState(() => _lbPeriod = v);
            _loadLb();
          },
        ),
        const SizedBox(height: 16),
        if (_lbLoading && _lb == null)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_lbPremium != null)
          AppCard(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppPalette.gold.withValues(alpha: .5))),
                  child: const Icon(LucideIcons.trophy, size: 20, color: AppPalette.gold),
                ),
                const SizedBox(height: 14),
                const Text('Reyting Premium bilan ochiladi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -.3)),
                const SizedBox(height: 6),
                Text(
                  "Natijalaringizni boshqa foydalanuvchilar bilan solishtiring.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant, height: 1.45),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: openPremiumInBot,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  child: const Text('Premium olish'),
                ),
              ],
            ),
          )
        else if (_lb != null) ...[
          if (_lb!.top.isEmpty)
            const EmptyView(icon: LucideIcons.trophy, title: "Hali reyting yo'q")
          else
            GroupCard(indent: 90, children: [for (final r in _lb!.top) _LeaderTile(row: r, unit: unit)]),
          if (_lb!.me != null && !_lb!.meInTop) ...[
            const SizedBox(height: 14),
            const SectionBar(title: "Sizning o'rningiz", top: 14),
            GroupCard(indent: 90, children: [_LeaderTile(row: _lb!.me!, unit: unit)]),
          ],
        ],
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
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

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values, this.color, this.grid);

  final List<int> values;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    final mx = math.max(1, values.fold<int>(0, math.max)).toDouble();
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = pad + (size.height - pad * 2) * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (values.length < 2) return;
    final step = (size.width - pad * 2) / (values.length - 1);
    final pts = [
      for (var i = 0; i < values.length; i++)
        Offset(pad + i * step, size.height - pad - values[i] / mx * (size.height - pad * 2)),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final cx = (pts[i - 1].dx + pts[i].dx) / 2;
      line.cubicTo(cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .16), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(pts.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.values != values || old.color != color;
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

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.progress, this.color, this.track);
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = const Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress.clamp(0, 1), false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress || old.color != color;
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

/// Yuqori xulosa: intizom halqasi, daraja, XP.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.discipline,
    required this.level,
    required this.rank,
    required this.xpInLevel,
    required this.xpNeeded,
    required this.xpPercent,
    required this.perfectDays,
  });

  final int discipline;
  final int level;
  final String rank;
  final int xpInLevel;
  final int xpNeeded;
  final int xpPercent;
  final int perfectDays;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ScoreRing(value: discipline.clamp(0, 100), size: 92, label: 'intizom'),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$level-daraja', style: muted),
                const SizedBox(height: 2),
                Text(
                  rank,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -.5),
                ),
                const SizedBox(height: 12),
                AppProgressBar(value: xpPercent / 100, height: 5),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text('$xpInLevel / $xpNeeded XP', style: muted.copyWith(fontFeatures: tabularFigures)),
                    ),
                    Text('$perfectDays mukammal kun', style: muted.copyWith(fontFeatures: tabularFigures)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric {
  const _Metric(this.icon, this.value, this.label, this.hint, [this.accent]);
  final IconData icon;
  final String value;
  final String label;
  final String? hint;
  final Color? accent;
}

/// 2×2 ko'rsatkichlar bitta yuzada, ingichka ajratgichlar bilan.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(_Metric m) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(m.icon, size: 14, color: m.accent ?? scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            m.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.7, fontFeatures: tabularFigures),
          ),
          if (m.hint != null)
            Text(
              m.hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(children: rows),
    );
  }
}
