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

  @override
  void initState() {
    super.initState();
    _load();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Statistika')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
      ),
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          TwoColumnGrid(
            children: [
              StatTile(icon: LucideIcons.flame, accent: AppPalette.streakOrange, value: '${st.streak}', label: 'Joriy streak', hint: 'Eng uzuni: ${st.longestStreak} kun'),
              StatTile(icon: LucideIcons.star, accent: AppPalette.levelGold, value: '${st.totalScore}', label: 'Jami ball', hint: '+$weekScore bu hafta'),
              StatTile(icon: LucideIcons.circleCheck, accent: AppPalette.disciplineGreen, value: '$doneThisMonth', label: 'Bajarilgan', hint: 'Bu oy'),
              StatTile(icon: LucideIcons.target, accent: AppPalette.accentBlue, value: '${goals.where((g) => !g.completed).length}', label: 'Maqsadlar', hint: 'Faol'),
            ],
          ),
          const SectionBar(title: '30 kunlik tahlil'),
          TwoColumnGrid(
            children: [
              StatTile(icon: LucideIcons.trendingUp, accent: AppPalette.accentTeal, value: '$rate%', label: 'Bajarish', hint: '${done30.length}/${p30.length} reja'),
              StatTile(icon: LucideIcons.zap, accent: AppPalette.accentAmber, value: '$avg', label: "O'rtacha ball", hint: 'Faol kunda'),
              StatTile(
                icon: LucideIcons.award,
                accent: AppPalette.accentViolet,
                value: best == null ? '—' : shortDate(parseYmd(best.key) ?? today),
                label: 'Eng yaxshi kun',
                hint: best == null ? null : '+${best.value} ball',
              ),
              StatTile(icon: LucideIcons.calendarDays, accent: AppPalette.accentIndigo, value: '${byDay.length}', label: 'Faol kunlar', hint: '30 kun ichida'),
            ],
          ),
          if (habits.isNotEmpty) ...[
            const SectionBar(title: 'Odatlar statistikasi'),
            TwoColumnGrid(
              children: [
                StatTile(icon: LucideIcons.squareCheck, accent: AppPalette.disciplineGreen, value: '$habitsDoneToday/${dueToday.length}', label: 'Bugun', hint: 'bajarildi'),
                StatTile(icon: LucideIcons.flame, accent: AppPalette.streakOrange, value: '$bestStreak', label: 'Eng uzun streak', hint: 'kun'),
                StatTile(icon: LucideIcons.repeat, accent: AppPalette.accentBlue, value: '${habits.length}', label: 'Faol odatlar', hint: 'ta'),
                StatTile(icon: LucideIcons.listChecks, accent: AppPalette.accentTeal, value: '$habitTotal', label: 'Jami bajarilgan', hint: 'marta'),
              ],
            ),
          ],
          const SectionBar(title: 'Haftalik faollik', count: 'oxirgi 7 kun'),
          _ChartCard(
            child: _WeekBars(
              days: [for (var i = 0; i < 7; i++) d7.add(Duration(days: i))],
              values: [for (var i = 0; i < 7; i++) dayCount(d7.add(Duration(days: i)))],
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
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
          const SectionBar(title: 'Faollik xaritasi', count: '14 hafta'),
          _ChartCard(child: _Heatmap(today: today, count: dayCount)),
          const SectionBar(title: 'Maqsadlar bajarilishi'),
          _ChartCard(
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CustomPaint(
                    painter: _DonutPainter(goalPct / 100, Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.surfaceContainerHigh),
                    child: Center(child: Text('$goalPct%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
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
                                  Expanded(child: AppProgressBar(value: all == 0 ? 0 : dn / all)),
                                  const SizedBox(width: 10),
                                  Text('$dn/$all', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        SegmentTabs<String>(
          value: _lbPeriod,
          items: const [('all', 'Umumiy', null), ('week', 'Haftalik', null), ('streak', 'Streak', null)],
          onChanged: (v) {
            setState(() => _lbPeriod = v);
            _loadLb();
          },
        ),
        const SizedBox(height: 14),
        if (_lbLoading && _lb == null)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_lbPremium != null)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const AppIconTile.tinted(icon: LucideIcons.trophy, accent: AppPalette.levelGold, size: 48),
                const SizedBox(height: 12),
                const Text('Reyting — Premium imkoniyat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  "O'zingizni boshqa foydalanuvchilar bilan solishtiring.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                FilledButton(onPressed: openPremiumInBot, child: const Text('Bot orqali Premium olish')),
              ],
            ),
          )
        else if (_lb != null) ...[
          if (_lb!.top.isEmpty)
            const EmptyView(icon: LucideIcons.trophy, title: "Hali reyting yo'q")
          else
            GroupCard(children: [for (final r in _lb!.top) _LeaderTile(row: r, unit: unit)]),
          if (_lb!.me != null && !_lb!.meInTop) ...[
            const SizedBox(height: 14),
            Text("Sizning o'rningiz", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            GroupCard(children: [_LeaderTile(row: _lb!.me!, unit: unit)]),
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
  const _WeekBars({required this.days, required this.values});
  final List<DateTime> days;
  final List<int> values;

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
                  Text('${values[i]}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    width: 22,
                    height: math.max(4, values[i] / mx * 90),
                    decoration: BoxDecoration(
                      color: sameDay(days[i], tashkentToday()) ? scheme.primary : scheme.primary.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(uzWeekdaysShort[days[i].weekday - 1], style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
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
          colors: [color.withValues(alpha: .25), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(pts.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.values != values || old.color != color;
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.today, required this.count});
  final DateTime today;
  final int Function(DateTime) count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 14 ustun (hafta) × 7 qator (Du..Ya). Oxirgi ustun — joriy hafta.
    final start = weekStart(today).subtract(const Duration(days: 7 * 13));
    Color shade(int c) {
      if (c == 0) return scheme.surfaceContainerHigh;
      final level = c < 2 ? .3 : c < 4 ? .5 : c < 6 ? .75 : 1.0;
      return scheme.primary.withValues(alpha: level);
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
    final medal = switch (row.rank) {
      1 => AppPalette.levelGold,
      2 => const Color(0xFF9AA3B2),
      3 => const Color(0xFFB87333),
      _ => null,
    };
    final photo = IntizomApi.absoluteUrl(row.photoUrl);
    return Container(
      color: row.isMe ? scheme.primaryContainer.withValues(alpha: .5) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: medal != null
                ? Icon(LucideIcons.medal, size: 20, color: medal)
                : Text('${row.rank}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          ClipOval(
            child: Container(
              width: 34,
              height: 34,
              color: scheme.primaryContainer,
              alignment: Alignment.center,
              child: photo == null
                  ? Text(row.name.isEmpty ? '?' : row.name[0].toUpperCase())
                  : Image.network(
                      photo,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Text(row.name.isEmpty ? '?' : row.name[0].toUpperCase()),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.isMe ? '${row.name} (siz)' : row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.5, fontWeight: row.isMe ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          Text('${row.value} $unit', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
