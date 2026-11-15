import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../models/stats.dart';
import '../services/intizom_api.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback.dart';
import 'coach/coach_page.dart';
import 'dashboard/dashboard_page.dart';
import 'friends/friends_page.dart';
import 'goals/goals_page.dart';
import 'habits/habits_page.dart';
import 'profile/profile_page.dart';
import 'stats/stats_page.dart';

/// Asosiy oyna: 5-tabli pastki navigatsiya (Asosiy | Maqsad | AI FAB | Odat | Do'stlar).
/// Statistika va Profil header tugmalari orqali ochiladi.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.onLogout,
    required this.onAppearanceChanged,
    required this.onLanguageChanged,
  });

  final IntizomApi api;
  final VoidCallback onLogout;
  final ValueChanged<String> onAppearanceChanged;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Tab indices: 0=Asosiy, 1=Maqsad, 2=AI, 3=Odat, 4=Do'stlar
  int _tab = 0;

  Profile? _profile;
  UserStats _stats = const UserStats();
  DailyQuest? _quest;
  String? _coach;
  List<Plan> _plans = const [];
  List<Habit> _habits = const [];
  List<Goal> _goals = const [];

  bool _loading = true;
  String? _loadError;

  IntizomApi get _api => widget.api;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  static DateTime _tashkentNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 5));

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadAll() async {
    setState(() {
      _loading = _profile == null;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _api.profile(),
        _api.stats(),
        _api.todayPlans(),
        _api.habits(),
        _api.goals(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile;
        _stats = results[1] as UserStats;
        _plans = results[2] as List<Plan>;
        _habits = results[3] as List<Habit>;
        _goals = results[4] as List<Goal>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
      return;
    }
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    try {
      final quest = await _api.quest();
      final coach = _stats.isPremium ? await _api.coachMessage() : null;
      if (mounted) {
        setState(() {
          _quest = quest;
          _coach = coach;
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshStats() async {
    try {
      final s = await _api.stats();
      if (mounted) setState(() => _stats = s);
      _loadExtras();
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _refreshStats();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  // ── Rejalar ──────────────────────────────────────────
  Future<void> _reloadPlans() async {
    final p = await _api.todayPlans();
    if (mounted) setState(() => _plans = p);
  }

  void _togglePlan(Plan p) => _run(() async {
        await _api.setPlanStatus(p.id, p.isDone ? 'pending' : 'done');
        await _reloadPlans();
      });

  void _deletePlan(Plan p) async {
    if (!await _confirmDelete(p.title)) return;
    _run(() async {
      await _api.deletePlan(p.id);
      await _reloadPlans();
    });
  }

  // ── Odatlar ──────────────────────────────────────────
  Future<void> _reloadHabits() async {
    final h = await _api.habits();
    if (mounted) setState(() => _habits = h);
  }

  void _toggleHabit(Habit h) => _run(() async {
        final updated = await _api.toggleHabit(h.id);
        if (mounted) {
          setState(() =>
              _habits = [for (final x in _habits) x.id == h.id ? updated : x]);
        }
      });

  void _deleteHabit(Habit h) async {
    if (!await _confirmDelete(h.title)) return;
    _run(() async {
      await _api.deleteHabit(h.id);
      await _reloadHabits();
    });
  }

  // ── Maqsadlar ────────────────────────────────────────
  Future<void> _reloadGoals() async {
    final g = await _api.goals();
    if (mounted) setState(() => _goals = g);
  }

  void _toggleGoal(Goal g) => _run(() async {
        await _api.setGoalCompleted(g.id, !g.completed);
        await _reloadGoals();
      });

  void _deleteGoal(Goal g) async {
    if (!await _confirmDelete(g.title)) return;
    _run(() async {
      await _api.deleteGoal(g.id);
      await _reloadGoals();
    });
  }

  Future<bool> _confirmDelete(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('O\'chirilsinmi?')),
        content: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Bekor qilish')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('O\'chirish')),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // ── Profil ───────────────────────────────────────────
  void _setNotifications(bool on) => _run(() async {
        final p = await _api.updateProfile(notifications: on);
        if (mounted) setState(() => _profile = p);
      });

  // ── Qo'shish oynalari ────────────────────────────────
  Future<String?> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _addPlanSheet() {
    final title = TextEditingController();
    String? time;
    _sheet(
      title: context.tr('Yangi reja'),
      builder: (setSheet) => [
        TextField(
          controller: title,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              InputDecoration(hintText: context.tr('Nima qilmoqchisiz?')),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final t = await _pickTime();
            if (t != null) setSheet(() => time = t);
          },
          icon: const Icon(LucideIcons.clock, size: 18),
          label: Text(time ?? context.tr('Vaqt (ixtiyoriy)')),
        ),
      ],
      onSave: () async {
        final text = title.text.trim();
        if (text.isEmpty) return false;
        await _run(() async {
          await _api.createPlan(
            title: text,
            scheduledTime: time,
            planDate: _isoDate(_tashkentNow()),
          );
          await _reloadPlans();
        });
        return true;
      },
    );
  }

  void _addHabitSheet() {
    final title = TextEditingController();
    final icon = TextEditingController(text: '✅');
    String? time;
    _sheet(
      title: context.tr('Yangi odat'),
      builder: (setSheet) => [
        Row(
          children: [
            SizedBox(
              width: 64,
              child: TextField(
                controller: icon,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22),
                maxLength: 2,
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    InputDecoration(hintText: context.tr('Odat nomi')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final t = await _pickTime();
            if (t != null) setSheet(() => time = t);
          },
          icon: const Icon(LucideIcons.bell, size: 18),
          label: Text(time ?? context.tr('Eslatma vaqti (ixtiyoriy)')),
        ),
      ],
      onSave: () async {
        final text = title.text.trim();
        if (text.isEmpty) return false;
        await _run(() async {
          await _api.createHabit(
            title: text,
            icon: icon.text.trim().isEmpty ? null : icon.text.trim(),
            reminderTime: time,
          );
          await _reloadHabits();
        });
        return true;
      },
    );
  }

  void _addGoalSheet() {
    final title = TextEditingController();
    var type = 'yearly';
    _sheet(
      title: context.tr('Yangi maqsad'),
      builder: (setSheet) => [
        TextField(
          controller: title,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              InputDecoration(hintText: context.tr('Maqsad nomi')),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'yearly', label: Text(context.tr('Yillik'))),
            ButtonSegment(value: 'monthly', label: Text(context.tr('Oylik'))),
          ],
          selected: {type},
          onSelectionChanged: (s) => setSheet(() => type = s.first),
        ),
      ],
      onSave: () async {
        final text = title.text.trim();
        if (text.isEmpty) return false;
        final now = _tashkentNow();
        final period = type == 'yearly'
            ? '${now.year}'
            : '${now.year}-${now.month.toString().padLeft(2, '0')}';
        await _run(() async {
          await _api.createGoal(title: text, goalType: type, period: period);
          await _reloadGoals();
        });
        return true;
      },
    );
  }

  void _sheet({
    required String title,
    required List<Widget> Function(StateSetter setSheet) builder,
    required Future<bool> Function() onSave,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...builder(setSheet),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  final nav = Navigator.of(ctx);
                  final ok = await onSave();
                  if (ok && nav.mounted) nav.pop();
                },
                child: Text(context.tr('Saqlash')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStats() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatsPage(stats: _stats),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          profile: _profile!,
          stats: _stats,
          isDark: Theme.of(context).brightness == Brightness.dark,
          onLogout: widget.onLogout,
          onAppearanceChanged: widget.onAppearanceChanged,
          onLanguageChanged: widget.onLanguageChanged,
          onNotificationsChanged: _setNotifications,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        body: ErrorRetry(
            message: _loadError ?? context.tr('Xatolik yuz berdi'),
            onRetry: _loadAll),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardPage(
            profile: profile,
            stats: _stats,
            quest: _quest,
            coachMessage: _coach,
            plans: _plans,
            habits: _habits,
            onRefresh: _loadAll,
            onTogglePlan: _togglePlan,
            onDeletePlan: _deletePlan,
            onToggleHabit: _toggleHabit,
            onAddPlan: _addPlanSheet,
            onOpenStats: _openStats,
            onOpenProfile: _openProfile,
            onAppearanceChanged: widget.onAppearanceChanged,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
          GoalsPage(
            goals: _goals,
            onToggle: _toggleGoal,
            onDelete: _deleteGoal,
            onAdd: _addGoalSheet,
            onRefresh: () => _run(_reloadGoals),
          ),
          CoachPage(api: _api),
          HabitsPage(
            habits: _habits,
            onToggle: _toggleHabit,
            onDelete: _deleteHabit,
            onAdd: _addHabitSheet,
            onRefresh: () => _run(_reloadHabits),
          ),
          const FriendsPage(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        scheme: scheme,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// Mini App uslubidagi pastki navigatsiya: 5 tab + markazda ko'tarilgan AI FAB.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.scheme,
    required this.onTap,
  });

  final int currentIndex;
  final ColorScheme scheme;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: const [
          BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: LucideIcons.house,
                label: 'Asosiy',
                active: currentIndex == 0,
                onTap: () => onTap(0),
                scheme: scheme,
              ),
              _NavItem(
                icon: LucideIcons.target,
                label: 'Maqsad',
                active: currentIndex == 1,
                onTap: () => onTap(1),
                scheme: scheme,
              ),
              // Center raised AI FAB
              _AiFab(
                active: currentIndex == 2,
                onTap: () => onTap(2),
                scheme: scheme,
              ),
              _NavItem(
                icon: LucideIcons.squareCheck,
                label: 'Odat',
                active: currentIndex == 3,
                onTap: () => onTap(3),
                scheme: scheme,
              ),
              _NavItem(
                icon: LucideIcons.users,
                label: "Do'stlar",
                active: currentIndex == 4,
                onTap: () => onTap(4),
                scheme: scheme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? scheme.primary.withValues(alpha: .1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiFab extends StatelessWidget {
  const _AiFab({
    required this.active,
    required this.onTap,
    required this.scheme,
  });

  final bool active;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -14),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    AppPalette.accent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: .35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: scheme.surfaceContainerLowest,
                  width: 3,
                ),
              ),
              child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 26),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -10),
            child: Text(
              'AI',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
