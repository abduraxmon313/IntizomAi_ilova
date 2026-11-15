import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../models/stats.dart';
import '../services/intizom_api.dart';
import '../widgets/feedback.dart';
import 'coach/coach_page.dart';
import 'dashboard/dashboard_page.dart';
import 'goals/goals_page.dart';
import 'habits/habits_page.dart';
import 'plans/plans_page.dart';
import 'profile/profile_page.dart';

/// Asosiy oyna: pastki navigatsiya + profil (avatar orqali).
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
  static const _profileTab = 5;

  int _tab = 0;
  final List<int> _history = [0];

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

  /// Toshkent sanasi (server ham shu sana bo'yicha ishlaydi).
  static DateTime _tashkentNow() => DateTime.now().toUtc().add(const Duration(hours: 5));

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
    // Ikkinchi darajali ma'lumotlar — xato bo'lsa ham asosiy oyna ishlaydi.
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

  /// Amalni bajaradi, xatoni ko'rsatadi, so'ng statistikani yangilaydi.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _refreshStats();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  void _go(int tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _history.add(tab);
    });
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
      setState(() => _habits = [for (final x in _habits) x.id == h.id ? updated : x]);
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
  void _add() {
    switch (_tab) {
      case 1:
        _addPlanSheet();
      case 2:
        _addHabitSheet();
      case 3:
        _addGoalSheet();
    }
  }

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
          decoration: InputDecoration(hintText: context.tr('Nima qilmoqchisiz?')),
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
                decoration: InputDecoration(hintText: context.tr('Odat nomi')),
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
          decoration: InputDecoration(hintText: context.tr('Maqsad nomi')),
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
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
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

  // ── UI ───────────────────────────────────────────────
  String _title(BuildContext context) => switch (_tab) {
    1 => context.tr('Rejalar'),
    2 => context.tr('Odatlar'),
    3 => context.tr('Maqsadlar'),
    4 => context.tr('AI Coach'),
    _profileTab => context.tr('Profil'),
    _ => 'IntizomAI',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        body: ErrorRetry(message: _loadError ?? context.tr('Xatolik yuz berdi'), onRetry: _loadAll),
      );
    }

    return PopScope(
      canPop: _history.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _history.length <= 1) return;
        setState(() {
          _history.removeLast();
          _tab = _history.last;
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title(context)),
          actions: [
            if (_tab != _profileTab)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () => _go(_profileTab),
                  child: ProfileAvatar(url: profile.avatar, size: 36),
                ),
              ),
          ],
        ),
        body: IndexedStack(
          index: _tab,
          children: [
            DashboardPage(
              profile: profile,
              stats: _stats,
              quest: _quest,
              coachMessage: _coach,
              onRefresh: _loadAll,
            ),
            PlansPage(
              plans: _plans,
              onToggle: _togglePlan,
              onDelete: _deletePlan,
              onAdd: _addPlanSheet,
              onRefresh: () => _run(_reloadPlans),
            ),
            HabitsPage(
              habits: _habits,
              onToggle: _toggleHabit,
              onDelete: _deleteHabit,
              onAdd: _addHabitSheet,
              onRefresh: () => _run(_reloadHabits),
            ),
            GoalsPage(
              goals: _goals,
              onToggle: _toggleGoal,
              onDelete: _deleteGoal,
              onAdd: _addGoalSheet,
              onRefresh: () => _run(_reloadGoals),
            ),
            CoachPage(api: _api),
            ProfilePage(
              profile: profile,
              stats: _stats,
              isDark: Theme.of(context).brightness == Brightness.dark,
              onLogout: widget.onLogout,
              onAppearanceChanged: widget.onAppearanceChanged,
              onLanguageChanged: widget.onLanguageChanged,
              onNotificationsChanged: _setNotifications,
            ),
          ],
        ),
        floatingActionButton: (_tab >= 1 && _tab <= 3)
            ? FloatingActionButton(
                onPressed: _add,
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: const Icon(LucideIcons.plus),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab == _profileTab ? 0 : _tab,
          onDestinationSelected: _go,
          destinations: [
            NavigationDestination(
              icon: const Icon(LucideIcons.house),
              label: context.tr('Bosh sahifa'),
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.clipboardCheck),
              label: context.tr('Rejalar'),
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.repeat),
              label: context.tr('Odatlar'),
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.target),
              label: context.tr('Maqsadlar'),
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.messageCircle),
              label: context.tr('Coach'),
            ),
          ],
        ),
      ),
    );
  }
}
