import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/goal.dart';
import '../../models/habit.dart';
import '../../models/plan.dart';
import '../../models/stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';
import '../achievements/achievements_page.dart';
import '../coach/coach_page.dart';
import '../forms.dart';
import '../friends/friends_page.dart';
import '../goals/goals_page.dart';
import '../profile/profile_page.dart';

/// Asosiy sahifa. Besh savolga javob beradi:
/// 1) Bugun qanchasi bajarildi va intizom qanday? — "Bugun" kartasi.
/// 2) Keyingi muhim ish nima? — "Keyingi vazifa".
/// 3) Odatlar holati? — bir bosishda belgilanadigan odatlar qatori.
/// 4) Nimaga e'tibor kerak? — bitta, faqat kerak bo'lganda chiqadigan tavsiya.
/// 5) Qolgan bo'limlar — ixcham "Tezkor kirish".
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.state,
    required this.onLogout,
    required this.onAppearanceChanged,
    required this.onLanguageChanged,
    required this.onOpenPlans,
    required this.onOpenHabits,
    required this.onOpenStats,
  });

  final AppState state;
  final VoidCallback onLogout;
  final ValueChanged<String> onAppearanceChanged;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenHabits;
  final VoidCallback onOpenStats;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AppState get s => widget.state;

  List<Plan> _today = const [];
  List<Plan> _week = const []; // oxirgi 7 kun (tavsiya uchun)
  bool _loaded = false;
  int _seenVersion = -1;

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
    _seenVersion = s.plansVersion;
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
      s.refreshStats();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadPlans() async {
    try {
      final t = tashkentToday();
      final w = await s.api.plansBetween(t.subtract(const Duration(days: 7)), t);
      if (!mounted) return;
      final k = ymd(t);
      setState(() {
        _week = w;
        _today = w.where((p) => p.planDate == k).toList()
          ..sort((a, b) => (a.scheduledTime ?? '99:99').compareTo(b.scheduledTime ?? '99:99'));
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _refresh() => Future.wait([s.loadAll(), _loadPlans()]);

  Future<void> _completePlan(Plan p) async {
    try {
      final updated = await s.api.setPlanStatus(p.id, p.isDone ? 'pending' : 'done');
      if (!mounted) return;
      setState(() => _today = [for (final x in _today) x.id == p.id ? updated : x]);
      if (updated.isDone) toast(context, 'Bajarildi · +${updated.scoreValue} ball');
      s.plansChanged();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _addPlan() async {
    if (await showPlanForm(context, api: s.api, initialDate: tashkentToday())) s.plansChanged();
  }

  Future<void> _toggleHabit(Habit h) async {
    try {
      final updated = await s.api.toggleHabit(h.id);
      s.replaceHabit(updated);
      if (!mounted) return;
      if (updated.doneToday) toast(context, '${updated.title} · ${updated.streak} kunlik seriya');
      s.refreshStats();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  void _push(Widget page) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => Scaffold(body: SafeArea(child: page))),
  );

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

  /// Keyingi bajarilmagan reja: vaqti kelgan/yaqinlashgan birinchisi.
  Plan? get _next {
    final pending = _today.where((p) => !p.isDone && !p.isFailed).toList();
    if (pending.isEmpty) return null;
    final now = tashkentHm();
    return pending.firstWhere(
      (p) => (p.scheduledTime ?? '').compareTo(now) >= 0,
      orElse: () => pending.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = s.profile!;
    final st = s.stats;
    final today = tashkentToday();
    final habits = s.habits.where((h) => !h.finished && h.dueOn(today)).toList()
      ..sort((a, b) => (a.reminderTime ?? '99:99').compareTo(b.reminderTime ?? '99:99'));
    final focusGoal = _focusGoal(s.goals, today);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 36),
        children: [
          _Header(
            name: profile.fullName,
            avatar: profile.avatar,
            telegramId: profile.telegramId,
            onProfile: _openProfile,
          ),
          const SizedBox(height: 20),
          _TodayCard(stats: st, onTap: widget.onOpenStats),

          // ── Keyingi vazifa ───────────────────────────
          _Section(
            title: 'Keyingi vazifa',
            action: _today.isEmpty ? null : 'Rejalar',
            onAction: widget.onOpenPlans,
          ),
          if (!_loaded)
            const _SkeletonRow()
          else
            _NextTask(
              next: _next,
              total: _today.length,
              done: _today.where((p) => p.isDone).length,
              onComplete: _completePlan,
              onAdd: _addPlan,
              onOpenAll: widget.onOpenPlans,
            ),

          // ── Bugungi odatlar ──────────────────────────
          if (habits.isNotEmpty) ...[
            _Section(
              title: 'Bugungi odatlar',
              count: '${habits.where((h) => h.doneToday).length}/${habits.length}',
              action: 'Odatlar',
              onAction: widget.onOpenHabits,
            ),
            _HabitStrip(habits: habits, onToggle: _toggleHabit),
          ],

          // ── E'tibor ──────────────────────────────────
          ?_insight(),

          // ── Tezkor kirish ────────────────────────────
          const _Section(title: 'Tezkor kirish'),
          _QuickAccess(
            items: [
              (LucideIcons.target, AppPalette.accentTeal, 'Maqsadlar', () => _push(GoalsPage(state: s))),
              (LucideIcons.users, AppPalette.accentIndigo, "Do'stlar", () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FriendsRoute(state: s)))),
              (LucideIcons.sparkles, AppPalette.accentViolet, 'AI murabbiy', () => _push(CoachPage(state: s))),
              (LucideIcons.trophy, AppPalette.accentAmber, 'Yutuqlar', () => _push(AchievementsPage(state: s))),
            ],
          ),
          if (focusGoal != null) ...[
            const SizedBox(height: 12),
            _GoalFocus(goal: focusGoal, onTap: () => _push(GoalsPage(state: s))),
          ],
        ],
      ),
    );
  }

  /// Oy uchun faol maqsad (bo'lmasa — yil uchun).
  static Goal? _focusGoal(List<Goal> goals, DateTime today) {
    final month = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final active = goals.where((g) => !g.completed);
    return active.where((g) => g.goalType == 'monthly' && g.period == month).firstOrNull ??
        active.where((g) => g.goalType == 'yearly' && g.period == '${today.year}').firstOrNull;
  }

  /// Mini App "Smart insights" qoidalari — eng muhimi bittasi.
  Widget? _insight() {
    final st = s.stats;
    final done7 = _week.where((p) => p.isDone).length;
    final total7 = _week.length;
    final rate = total7 == 0 ? 0 : (done7 * 100 / total7).round();
    final (IconData, Color, String, String)? item;
    if (st.streakAtRisk && st.streak >= 2) {
      item = (LucideIcons.triangleAlert, AppPalette.warning, 'Seriya xavf ostida', "Bugun bitta reja yoki odatni bajaring — ${st.streak} kunlik seriya saqlanadi.");
    } else if (rate < 40 && total7 >= 5) {
      item = (LucideIcons.trendingDown, AppPalette.warning, 'Hafta sustroq o\'tdi', "Bitta yengil reja qo'shing — ritm tiklanadi.");
    } else if (st.streak >= 7) {
      item = (LucideIcons.flame, AppPalette.ember, '${st.streak} kunlik seriya', 'Zo\'r ritm. Bugun ham davom eting.');
    } else if (rate >= 80 && total7 >= 5) {
      item = (LucideIcons.trendingUp, AppPalette.success, 'Kuchli hafta', '$done7 / $total7 reja bajarildi.');
    } else if (st.streak == 0 && total7 > 0) {
      item = (LucideIcons.sprout, AppPalette.success, 'Yangi boshlanish', 'Birinchi qadam eng qiyini, lekin eng muhimi.');
    } else {
      item = null;
    }
    if (item == null) return null;
    final (icon, color, title, text) = item;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .12 : .07),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -.15)),
                  const SizedBox(height: 2),
                  Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().toUtc().add(const Duration(hours: 5)).hour;
  if (h >= 5 && h < 11) return 'Xayrli tong';
  if (h >= 11 && h < 17) return 'Xayrli kun';
  if (h >= 17 && h < 23) return 'Xayrli kech';
  return 'Xayrli tun';
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.avatar, required this.telegramId, required this.onProfile});

  final String name;
  final String? avatar;
  final int telegramId;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = name.trim().isEmpty ? 'do\'stim' : name.trim().split(' ').first;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                longDate(tashkentToday()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 3),
              Text(
                '${_greeting()}, $first',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 24, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -.8),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Profil',
          child: InkResponse(
            radius: 26,
            onTap: () {
              tapFeedback();
              onProfile();
            },
            child: ProfileAvatar(url: avatar, telegramId: telegramId, name: name, size: 42),
          ),
        ),
      ],
    );
  }
}

/// "Bugun" — siyoh rangli asosiy karta (Mini App'dagi intizom kartasi asosida):
/// intizom halqasi, unvon, daraja/XP, seriya va bugungi bajarilish.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.stats, required this.onTap});

  final UserStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const fg = Color(0xFFF5F2EB);
    final muted = fg.withValues(alpha: .62);
    final radius = BorderRadius.circular(AppRadius.xl + 4);
    final ratio = stats.todayTotal == 0 ? 0.0 : stats.todayDone / stats.todayTotal;
    return Material(
      color: dark ? AppPalette.darkPaper2 : AppPalette.ink,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: dark ? BoxDecoration(borderRadius: radius, border: Border.all(color: AppPalette.darkLine)) : null,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            children: [
              Row(
                children: [
                  _Ring(value: stats.disciplineScore.clamp(0, 100)),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.award, size: 14, color: AppPalette.brandBright),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                stats.rankTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppPalette.brandBright),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${stats.level}-daraja'),
                              TextSpan(
                                text: '  ${stats.xpInLevel}/${stats.xpNeeded} XP',
                                style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w500, fontFeatures: tabularFigures),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg, letterSpacing: -.4),
                        ),
                        const SizedBox(height: 10),
                        AppProgressBar(
                          value: stats.xpPercent / 100,
                          height: 5,
                          color: AppPalette.brandBright,
                          backgroundColor: fg.withValues(alpha: .12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Keyingi darajagacha ${(stats.xpNeeded - stats.xpInLevel).clamp(0, 1 << 30)} XP',
                          style: TextStyle(fontSize: 11.5, color: muted, fontFeatures: tabularFigures),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: fg.withValues(alpha: .1)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(LucideIcons.flame, size: 16, color: stats.streak > 0 ? AppPalette.ember : muted),
                  const SizedBox(width: 6),
                  Text(
                    '${stats.streak} kunlik seriya',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg, fontFeatures: tabularFigures),
                  ),
                  const Spacer(),
                  Text(
                    stats.todayTotal == 0
                        ? "Bugun ish yo'q"
                        : ratio >= 1
                        ? 'Bugun hammasi bajarildi'
                        : 'Bugun ${stats.todayDone}/${stats.todayTotal}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ratio >= 1 ? AppPalette.brandBright : fg,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFFF5F2EB);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value / 100),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      builder: (_, v, _) => SizedBox(
        width: 88,
        height: 88,
        child: CustomPaint(
          painter: RingPainter(v, AppPalette.brandBright, fg.withValues(alpha: .12), 7),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(v * 100).round()}',
                  style: const TextStyle(fontSize: 27, height: 1.05, fontWeight: FontWeight.w700, color: fg, letterSpacing: -.8, fontFeatures: tabularFigures),
                ),
                Text('intizom', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg.withValues(alpha: .62))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bo'lim sarlavhasi (Asosiy uchun): nom, hisob, o'ngda havola.
class _Section extends StatelessWidget {
  const _Section({required this.title, this.count, this.action, this.onAction});

  final String title;
  final String? count;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 0, 10),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -.25)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(count!, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant, fontFeatures: tabularFigures)),
          ],
          const Spacer(),
          if (action != null)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(action!, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: scheme.tertiary)),
                    Icon(LucideIcons.chevronRight, size: 16, color: scheme.tertiary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
  );
}

/// Keyingi vazifa: bitta aniq ish + bir bosishda bajarish.
class _NextTask extends StatelessWidget {
  const _NextTask({
    required this.next,
    required this.total,
    required this.done,
    required this.onComplete,
    required this.onAdd,
    required this.onOpenAll,
  });

  final Plan? next;
  final int total;
  final int done;
  final ValueChanged<Plan> onComplete;
  final VoidCallback onAdd;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = next;
    if (p == null) {
      final allDone = total > 0;
      return AppCard(
        onTap: allDone ? onOpenAll : onAdd,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AppIconTile.tinted(
              icon: allDone ? LucideIcons.circleCheckBig : LucideIcons.calendarPlus,
              accent: allDone ? AppPalette.success : AppPalette.accentAmber,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allDone ? 'Bugungi rejalar bajarildi' : 'Bugunga reja yo\'q',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    allDone ? '$done ta reja yakunlandi. Ertangi kunni rejalashtiring.' : 'Birinchi rejani qo\'shing — bot vaqtida eslatadi.',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.35),
                  ),
                ],
              ),
            ),
            if (!allDone) ...[
              const SizedBox(width: 8),
              Icon(LucideIcons.plus, size: 20, color: scheme.tertiary),
            ],
          ],
        ),
      );
    }
    final left = total - done;
    return AppCard(
      onTap: onOpenAll,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Text(
                  p.scheduledTime?.isNotEmpty == true ? p.scheduledTime! : '—',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer, fontFeatures: tabularFigures),
                ),
                Text('vaqt', style: TextStyle(fontSize: 10.5, color: scheme.onPrimaryContainer.withValues(alpha: .7))),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -.25, height: 1.3),
                ),
                const SizedBox(height: 3),
                Text(
                  left > 1 ? 'Bugun yana ${left - 1} ta reja · $done/$total' : 'Bugungi oxirgi reja',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
                ),
              ],
            ),
          ),
          CheckCircle(checked: false, size: 26, onTap: () => onComplete(p)),
        ],
      ),
    );
  }
}

/// Bugungi odatlar — gorizontal qator, bosilsa belgilanadi.
class _HabitStrip extends StatelessWidget {
  const _HabitStrip({required this.habits, required this.onToggle});

  final List<Habit> habits;
  final ValueChanged<Habit> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: habits.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final h = habits[i];
          return SizedBox(
            width: 104,
            child: AppCard(
              onTap: () {
                if (!h.doneToday) successFeedback();
                onToggle(h);
              },
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              color: h.doneToday ? scheme.primaryContainer : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HabitGlyph(icon: h.icon, size: 32, done: h.doneToday),
                  const Spacer(),
                  Text(
                    h.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.1,
                      color: h.doneToday ? scheme.onPrimaryContainer : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    h.doneToday ? 'Bajarildi' : (h.reminderTime ?? 'Bugun'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: h.doneToday ? scheme.onPrimaryContainer.withValues(alpha: .75) : scheme.onSurfaceVariant,
                      fontFeatures: tabularFigures,
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

/// Ikkinchi darajali bo'limlar — bitta ixcham qatorda.
class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.items});

  final List<(IconData, Color, String, VoidCallback)> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        children: [
          for (final (icon, accent, label, onTap) in items)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () {
                  tapFeedback();
                  onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      AppIconTile.tinted(icon: icon, accent: accent, size: 44),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: -.1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalFocus extends StatelessWidget {
  const _GoalFocus({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      child: Row(
        children: [
          Icon(LucideIcons.target, size: 18, color: AppPalette.accentTeal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.goalType == 'monthly' ? 'Shu oy maqsadi' : 'Shu yil maqsadi',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant, letterSpacing: .2),
                ),
                const SizedBox(height: 2),
                Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, letterSpacing: -.15),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
        ],
      ),
    );
  }
}
