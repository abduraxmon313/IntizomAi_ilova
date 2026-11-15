import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
import '../friends/friends_page.dart';
import '../goals/goals_page.dart';
import '../profile/profile_page.dart';

/// Asosiy: salomlashish, intizom kartasi, tavsiyalar, tezkor kirish, bugungi rejalar.
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.state,
    required this.onLogout,
    required this.onAppearanceChanged,
    required this.onLanguageChanged,
    required this.onOpenPlans,
    required this.onOpenStats,
  });

  final AppState state;
  final VoidCallback onLogout;
  final ValueChanged<String> onAppearanceChanged;
  final ValueChanged<String> onLanguageChanged;

  /// Pastki menyudagi "Rejalar" bo'limiga o'tish.
  final VoidCallback onOpenPlans;

  /// Pastki menyudagi "Statistika" bo'limiga o'tish.
  final VoidCallback onOpenStats;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AppState get s => widget.state;

  List<Plan> _today = const [];
  List<Plan> _week = const []; // oxirgi 7 kun (tavsiyalar uchun)
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
      });
    } catch (_) {}
  }

  Future<void> _refresh() async {
    await Future.wait([s.loadAll(), _loadPlans()]);
  }

  Future<void> _togglePlan(Plan p) async {
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

  void _openFriends() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FriendsRoute(state: s)),
  );

  @override
  Widget build(BuildContext context) {
    final profile = s.profile!;
    final st = s.stats;
    final activeGoals = s.goals.where((g) => !g.completed).length;
    final unlocked = achievementMilestones(st.streak, st.totalScore, s.goals.where((g) => g.completed).length)
        .where((a) => a.unlocked)
        .length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 16, AppSpace.page, 32),
        children: [
          _Header(
            name: profile.fullName,
            avatar: profile.avatar,
            telegramId: profile.telegramId,
            onProfile: _openProfile,
          ),
          const SizedBox(height: 20),
          _DisciplineHero(stats: st, onTap: widget.onOpenStats),
          ..._insights(),
          const SizedBox(height: 28),
          const _SectionTitle('Tezkor kirish'),
          const SizedBox(height: 12),
          TwoColumnGrid(
            gap: 12,
            children: [
              _QuickCard(
                icon: LucideIcons.target,
                accent: AppPalette.accentTeal,
                title: 'Maqsadlar',
                caption: activeGoals == 0 ? "Hali qo'shilmagan" : '$activeGoals ta faol',
                onTap: () => _push(GoalsPage(state: s)),
              ),
              _QuickCard(
                icon: LucideIcons.users,
                accent: AppPalette.accentIndigo,
                title: "Do'stlar",
                caption: 'Guruh va reyting',
                onTap: _openFriends,
              ),
              _QuickCard(
                icon: LucideIcons.sparkles,
                accent: AppPalette.accentViolet,
                title: 'AI chat',
                caption: 'Shaxsiy murabbiy',
                onTap: () => _push(CoachPage(state: s)),
              ),
              _QuickCard(
                icon: LucideIcons.trophy,
                accent: AppPalette.accentAmber,
                title: 'Yutuqlar',
                caption: '$unlocked / $kAchievementCount ochildi',
                onTap: () => _push(AchievementsPage(state: s)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _SectionTitle(
            'Bugungi rejalar',
            trailing: TextButton(
              onPressed: widget.onOpenPlans,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Barchasi'),
            ),
          ),
          const SizedBox(height: 10),
          if (_today.isEmpty)
            AppCard(
              onTap: widget.onOpenPlans,
              child: Row(
                children: [
                  const AppIconTile.tinted(icon: LucideIcons.calendarPlus, accent: AppPalette.accentBlue, size: 38),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Bugunga reja yo'q", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.2)),
                        const SizedBox(height: 2),
                        Text(
                          "Rejalar bo'limida qo'shing",
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 18, color: Theme.of(context).colorScheme.outline),
                ],
              ),
            )
          else
            GroupCard(
              indent: 58,
              children: [
                for (final p in _today.take(4)) _PlanPreviewRow(plan: p, onToggle: () => _togglePlan(p)),
                if (_today.length > 4)
                  InkWell(
                    onTap: widget.onOpenPlans,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          'Yana ${_today.length - 4} ta reja',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Mini App'dagi "Smart insights" qoidalari — ixcham ko'rinishda.
  List<Widget> _insights() {
    final st = s.stats;
    final done7 = _week.where((p) => p.isDone).length;
    final total7 = _week.length;
    final rate = total7 == 0 ? 0 : (done7 * 100 / total7).round();
    final items = <(IconData, Color, String, String)>[];
    if (st.streak >= 7) {
      items.add((LucideIcons.flame, AppPalette.ember, '${st.streak} kunlik streak', "Ritmni saqlang — bugun ham bitta ishni yoping."));
    }
    if (st.disciplineScore >= 75) {
      items.add((LucideIcons.badgeCheck, AppPalette.accentBlue, 'Intizom yuqori', "Reja tuzasiz va bajarasiz. Shu sur'atda davom eting."));
    }
    if (rate >= 80 && total7 >= 5) {
      items.add((LucideIcons.trendingUp, AppPalette.accentTeal, 'Kuchli hafta', '$done7/$total7 reja bajarildi.'));
    }
    if (rate < 40 && total7 >= 5) {
      items.add((LucideIcons.trendingDown, AppPalette.warning, 'Hafta sustroq', "Bitta yengil reja qo'shing — ritm tiklanadi."));
    }
    if (st.disciplineScore < 40) {
      items.add((LucideIcons.target, AppPalette.warning, 'Kichik qadamdan boshlang', 'Bugun bitta ishni bajarish kifoya.'));
    }
    if (st.streak == 0 && total7 > 0) {
      items.add((LucideIcons.sprout, AppPalette.accentTeal, 'Yangi boshlanish', 'Birinchi qadam eng qiyini, lekin eng muhimi.'));
    }
    if (items.isEmpty) return const [];
    final scheme = Theme.of(context).colorScheme;
    return [
      const SizedBox(height: 12),
      for (final (icon, color, title, text) in items.take(2))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                AppIconTile.tinted(icon: icon, accent: color, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -.15)),
                      const SizedBox(height: 2),
                      Text(text, style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

String _greeting() {
  final h = DateTime.now().toUtc().add(const Duration(hours: 5)).hour;
  if (h >= 5 && h < 12) return 'Xayrli tong';
  if (h >= 12 && h < 18) return 'Xayrli kun';
  if (h >= 18 && h < 23) return 'Xayrli kech';
  return 'Xayrli tun';
}

/// MyFit uslubidagi sarlavha: kichik salom, katta ism, o'ngda avatar (profil).
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.avatar, required this.telegramId, required this.onProfile});

  final String name;
  final String? avatar;
  final int telegramId;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = name.trim().isEmpty ? 'Foydalanuvchi' : name.trim().split(' ').first;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_greeting()} · ${longDate(tashkentToday())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, height: 1.15, fontWeight: FontWeight.w600, letterSpacing: -.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Profil',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                tapFeedback();
                onProfile();
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.outlineVariant)),
                child: ProfileAvatar(url: avatar, telegramId: telegramId, name: name, size: 40),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mini App'dagi intizom kartasi: halqa, unvon, daraja/XP, streak va bugungi holat.
class _DisciplineHero extends StatelessWidget {
  const _DisciplineHero({required this.stats, required this.onTap});

  final UserStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final risk = stats.streakAtRisk && stats.streak >= 2;
    const white = Colors.white;
    final soft = white.withValues(alpha: .78);
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF2448C4), Color(0xFF3A63E0)]
              : const [AppPalette.heroStart, AppPalette.heroEnd],
        ),
        boxShadow: dark
            ? null
            : [BoxShadow(color: AppPalette.brand.withValues(alpha: .22), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    _HeroRing(value: stats.disciplineScore.clamp(0, 100)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                            decoration: BoxDecoration(
                              color: white.withValues(alpha: .2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.award, size: 13, color: white),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    stats.rankTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: white, letterSpacing: .2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Daraja '),
                                TextSpan(
                                  text: '${stats.level}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                TextSpan(text: ' · ${stats.xpInLevel}/${stats.xpNeeded} XP'),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: white.withValues(alpha: .95), fontFeatures: tabularFigures),
                          ),
                          const SizedBox(height: 8),
                          AppProgressBar(
                            value: stats.xpPercent / 100,
                            height: 7,
                            color: white,
                            backgroundColor: white.withValues(alpha: .22),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text('${stats.xpPercent}%', style: TextStyle(fontSize: 11, color: soft, fontFeatures: tabularFigures)),
                              const Spacer(),
                              Text('${stats.xp} XP', style: TextStyle(fontSize: 11, color: soft, fontFeatures: tabularFigures)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: white.withValues(alpha: .18)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(LucideIcons.flame, size: 16, color: white),
                    const SizedBox(width: 6),
                    Text(
                      '${stats.streak} kun streak',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: white, fontFeatures: tabularFigures),
                    ),
                    const Spacer(),
                    if (risk)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.triangleAlert, size: 13, color: white),
                            SizedBox(width: 5),
                            Text('Streak xavf ostida', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: white)),
                          ],
                        ),
                      )
                    else ...[
                      const Icon(LucideIcons.listChecks, size: 15, color: white),
                      const SizedBox(width: 6),
                      Text(
                        '${stats.todayDone}/${stats.todayTotal} bugun',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: white, fontFeatures: tabularFigures),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroRing extends StatelessWidget {
  const _HeroRing({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value / 100),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      builder: (_, v, _) => SizedBox(
        width: 92,
        height: 92,
        child: CustomPaint(
          painter: RingPainter(v, Colors.white, Colors.white.withValues(alpha: .22), 8),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(v * 100).round()}',
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -.8,
                    fontFeatures: tabularFigures,
                  ),
                ),
                Text(
                  'Intizom',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .85)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -.2),
        ),
      ),
      ?trailing,
    ],
  );
}

/// MyFit "Tezkor amallar" kartasi: rangli ikonka plitasi, o'q, nom va izoh.
class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () {
        tapFeedback();
        onTap();
      },
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconTile.tinted(icon: icon, accent: accent, size: 38),
              const Spacer(),
              Icon(LucideIcons.arrowUpRight, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, height: 1.25, fontWeight: FontWeight.w600, letterSpacing: -.1),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
          ),
        ],
      ),
    );
  }
}

class _PlanPreviewRow extends StatelessWidget {
  const _PlanPreviewRow({required this.plan, required this.onToggle});

  final Plan plan;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          CheckCircle(checked: plan.isDone, onTap: onToggle),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                plan.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  letterSpacing: -.15,
                  fontWeight: FontWeight.w500,
                  color: plan.isDone ? scheme.onSurfaceVariant : scheme.onSurface,
                  decoration: plan.isDone ? TextDecoration.lineThrough : null,
                  decorationColor: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (plan.scheduledTime?.isNotEmpty == true) ...[
            const SizedBox(width: 8),
            MetaTag(icon: LucideIcons.clock, text: plan.scheduledTime!),
          ],
        ],
      ),
    );
  }
}
