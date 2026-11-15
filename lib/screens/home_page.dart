import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../l10n/app_localizations.dart';
import '../models/plan.dart';
import '../models/habit.dart';
import '../models/goal.dart';
import '../models/user_profile.dart';
import '../services/plan_service.dart';
import '../services/habit_service.dart';
import '../services/goal_service.dart';
import '../services/user_service.dart';
import '../services/coach_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'dashboard/dashboard_page.dart';
import 'plans/plans_page.dart';
import 'habits/habits_page.dart';
import 'goals/goals_page.dart';
import 'coach/coach_page.dart';
import 'profile/profile_page.dart';

/// Asosiy sahifa — MyFit uslubidagi tab navigatsiya.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.profile,
    required this.onLogout,
    this.onAppearanceChanged,
    this.onLanguageChanged,
  });

  final UserProfile profile;
  final VoidCallback onLogout;
  final ValueChanged<String>? onAppearanceChanged;
  final ValueChanged<String>? onLanguageChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _navIndex = 0;
  final List<int> _navHistory = [0];

  // Services
  late final PlanService _planService;
  late final HabitService _habitService;
  late final GoalService _goalService;
  late final UserService _userService;
  late final CoachService _coachService;

  // Data
  UserProfile? _profile;
  List<Plan> _plans = [];
  List<Habit> _habits = [];
  List<Goal> _goals = [];
  String? _smartMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _planService = PlanService();
    _habitService = HabitService();
    _goalService = GoalService();
    _userService = UserService();
    _coachService = CoachService();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _planService.getToday(),
        _habitService.getAll(),
        _goalService.getAll(),
        _userService.getProfile(),
        _coachService.getSmartMessage(),
      ]);
      if (mounted) {
        setState(() {
          _plans = results[0] as List<Plan>;
          _habits = results[1] as List<Habit>;
          _goals = results[2] as List<Goal>;
          _profile = results[3] as UserProfile;
          _smartMessage = results[4] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshPlans() async {
    try {
      final plans = await _planService.getToday();
      final profile = await _userService.getProfile();
      if (mounted) setState(() { _plans = plans; _profile = profile; });
    } catch (_) {}
  }

  Future<void> _refreshHabits() async {
    try {
      final habits = await _habitService.getAll();
      final profile = await _userService.getProfile();
      if (mounted) setState(() { _habits = habits; _profile = profile; });
    } catch (_) {}
  }

  Future<void> _refreshGoals() async {
    try {
      final goals = await _goalService.getAll();
      if (mounted) setState(() => _goals = goals);
    } catch (_) {}
  }

  void _navigateTo(int index) {
    if (index == _navIndex) return;
    setState(() {
      _navHistory.add(index);
      _navIndex = index;
    });
  }

  // Tab indekslari: 0=Dashboard, 1=Plans, 2=Habits, 3=Goals, 4=Coach
  // Profile alohida (5)
  static const _pageForTab = [0, 1, 2, 3, 4]; // navBar index -> page index

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = _profile ?? widget.profile;

    return PopScope(
      canPop: _navIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_navHistory.length > 1) {
          _navHistory.removeLast();
          setState(() => _navIndex = _navHistory.last);
        }
      },
      child: Scaffold(
        appBar: _navIndex == 5
            ? null
            : AppBar(
                title: Text(_appBarTitle(context)),
                actions: [
                  // Profile avatar
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => _navigateTo(5),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: scheme.primaryContainer,
                        backgroundImage: profile.effectivePhotoUrl != null
                            ? NetworkImage(profile.effectivePhotoUrl!)
                            : null,
                        child: profile.effectivePhotoUrl == null
                            ? Text(
                                profile.avatarEmoji,
                                style: const TextStyle(fontSize: 18),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildPage(profile),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _navIndex < 5 ? _navIndex : 0,
          onDestinationSelected: (i) => _navigateTo(_pageForTab[i]),
          destinations: [
            NavigationDestination(
              icon: const Icon(LucideIcons.house),
              selectedIcon: Icon(LucideIcons.house, color: scheme.primary),
              label: context.tr('Bosh sahifa'),
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.clipboardCheck),
              selectedIcon: Icon(LucideIcons.clipboardCheck, color: scheme.primary),
              label: context.tr('Rejalar'),
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.repeat),
              selectedIcon: Icon(LucideIcons.repeat, color: scheme.primary),
              label: context.tr('Odatlar'),
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.target),
              selectedIcon: Icon(LucideIcons.target, color: scheme.primary),
              label: context.tr('Maqsadlar'),
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.messageCircle),
              selectedIcon: Icon(LucideIcons.messageCircle, color: scheme.primary),
              label: context.tr('Coach'),
            ),
          ],
        ),
        // FAB — yangi element qo'shish
        floatingActionButton: (_navIndex >= 1 && _navIndex <= 3)
            ? FloatingActionButton(
                onPressed: () => _showAddDialog(context),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: const Icon(LucideIcons.plus),
              )
            : null,
      ),
    );
  }

  Widget _buildPage(UserProfile profile) {
    switch (_navIndex) {
      case 0:
        final donePlans = _plans.where((p) => p.isDone).length;
        final activeHabits = _habits.where((h) => !h.archived).toList();
        final doneHabits = activeHabits.where((h) => h.todayDone).length;
        return DashboardPage(
          profile: profile,
          todayDone: donePlans,
          todayTotal: _plans.length,
          todayHabitsDone: doneHabits,
          todayHabitsTotal: activeHabits.length,
          smartMessage: _smartMessage,
          onRefresh: _loadAll,
        );
      case 1:
        return PlansPage(
          plans: _plans,
          isPremium: profile.isPremium,
          onToggleStatus: (id, status) async {
            await _planService.setStatus(id, status);
            await _refreshPlans();
          },
          onDelete: (id) async {
            await _planService.delete(id);
            await _refreshPlans();
          },
          onAdd: () => _showAddPlanDialog(context),
          onMoveToTomorrow: (id) async {
            await _planService.moveToTomorrow(id);
            await _refreshPlans();
          },
          onRefresh: _refreshPlans,
        );
      case 2:
        return HabitsPage(
          habits: _habits,
          onToggle: (id) async {
            await _habitService.toggleToday(id);
            await _refreshHabits();
          },
          onAdd: () => _showAddHabitDialog(context),
          onArchive: (id) async {
            await _habitService.archive(id);
            await _refreshHabits();
          },
          onRefresh: _refreshHabits,
        );
      case 3:
        return GoalsPage(
          goals: _goals,
          onToggle: (id) async {
            await _goalService.toggleCompleted(id);
            await _refreshGoals();
          },
          onAdd: () => _showAddGoalDialog(context),
          onDelete: (id) async {
            await _goalService.delete(id);
            await _refreshGoals();
          },
          onRefresh: _refreshGoals,
        );
      case 4:
        return CoachPage(coachService: _coachService);
      case 5:
        return ProfilePage(
          profile: profile,
          onLogout: widget.onLogout,
          onAppearanceChanged: widget.onAppearanceChanged,
          onLanguageChanged: widget.onLanguageChanged,
          onNotificationsChanged: (val) async {
            try {
              await _userService.setNotifications(val);
              final p = await _userService.getProfile();
              if (mounted) setState(() => _profile = p);
            } catch (_) {}
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _appBarTitle(BuildContext context) => switch (_navIndex) {
    0 => 'IntizomAI',
    1 => context.tr('Rejalar'),
    2 => context.tr('Odatlar'),
    3 => context.tr('Maqsadlar'),
    4 => context.tr('Coach'),
    _ => 'IntizomAI',
  };

  void _showAddDialog(BuildContext context) {
    switch (_navIndex) {
      case 1: _showAddPlanDialog(context);
      case 2: _showAddHabitDialog(context);
      case 3: _showAddGoalDialog(context);
    }
  }

  void _showAddPlanDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 24, 20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Yangi reja'),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nima qilmoqchisiz?',
                prefixIcon: Icon(LucideIcons.pencil, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timeCtrl,
              decoration: InputDecoration(
                hintText: 'Vaqt (masalan: 09:00)',
                prefixIcon: Icon(LucideIcons.clock, size: 18),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final date =
                      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                  try {
                    await _planService.create(
                      title: titleCtrl.text.trim(),
                      scheduledTime:
                          timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : null,
                      planDate: date,
                    );
                    await _refreshPlans();
                  } catch (_) {}
                },
                child: Text(context.tr('Saqlash')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHabitDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: '✅');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 24, 20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Yangi odat'),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: iconCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: const InputDecoration(hintText: '✅'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Odat nomi',
                      prefixIcon: Icon(LucideIcons.pencil, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await _habitService.create({
                      'title': titleCtrl.text.trim(),
                      'icon': iconCtrl.text.trim().isNotEmpty
                          ? iconCtrl.text.trim()
                          : '✅',
                      'frequency': 'daily',
                    });
                    await _refreshHabits();
                  } catch (_) {}
                },
                child: Text(context.tr('Saqlash')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    String goalType = 'yearly';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 24, 20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Yangi maqsad'),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Maqsad nomi',
                  prefixIcon: Icon(LucideIcons.pencil, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'yearly',
                    label: Text(context.tr('Yillik')),
                  ),
                  ButtonSegment(
                    value: 'monthly',
                    label: Text(context.tr('Oylik')),
                  ),
                ],
                selected: {goalType},
                onSelectionChanged: (sel) =>
                    setSheetState(() => goalType = sel.first),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    final now = DateTime.now();
                    final period = goalType == 'yearly'
                        ? '${now.year}'
                        : '${now.year}-${now.month.toString().padLeft(2, '0')}';
                    try {
                      await _goalService.create({
                        'title': titleCtrl.text.trim(),
                        'goal_type': goalType,
                        'period': period,
                      });
                      await _refreshGoals();
                    } catch (_) {}
                  },
                  child: Text(context.tr('Saqlash')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
