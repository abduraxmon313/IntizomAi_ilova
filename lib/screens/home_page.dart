import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/intizom_api.dart';
import '../state/app_state.dart';
import '../widgets/app_ui.dart';
import '../widgets/feedback.dart';
import '../widgets/ui_kit.dart';
import 'coach/coach_page.dart';
import 'dashboard/dashboard_page.dart';
import 'friends/friends_page.dart';
import 'goals/goals_page.dart';
import 'habits/habits_page.dart';

/// Asosiy oyna: Asosiy | Maqsad | AI | Odat | Do'stlar.
///
/// Orqaga tugmasi: ichki ekran (masalan guruh ichi) → bo'limning boshi →
/// Asosiy bo'lim → ilovadan chiqish.
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
  late final AppState _state = AppState(widget.api);
  final _friendsKey = GlobalKey<FriendsPageState>();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _state.loadAll();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
  }

  bool get _canExit => _tab == 0;

  void _handleBack() {
    if (_tab == 4 && (_friendsKey.currentState?.handleBack() ?? false)) return;
    if (_tab != 0) setState(() => _tab = 0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        if (_state.loading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandMark(size: 56),
                  SizedBox(height: 24),
                  SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          );
        }
        if (_state.profile == null) {
          return Scaffold(
            body: ErrorRetry(message: _state.error ?? 'Xatolik yuz berdi', onRetry: _state.loadAll),
          );
        }
        return PopScope(
          canPop: _canExit,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBack();
          },
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _tab,
                children: [
                  TabFade(
                    active: _tab == 0,
                    child: DashboardPage(
                      state: _state,
                      onLogout: widget.onLogout,
                      onAppearanceChanged: widget.onAppearanceChanged,
                      onLanguageChanged: widget.onLanguageChanged,
                    ),
                  ),
                  TabFade(active: _tab == 1, child: GoalsPage(state: _state)),
                  TabFade(active: _tab == 2, child: CoachPage(state: _state)),
                  TabFade(active: _tab == 3, child: HabitsPage(state: _state)),
                  TabFade(
                    active: _tab == 4,
                    child: FriendsPage(key: _friendsKey, state: _state, active: _tab == 4),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
              ),
              child: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) {
                  tapFeedback();
                  _select(i);
                },
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(icon: Icon(LucideIcons.house), label: 'Bugun'),
                  NavigationDestination(icon: Icon(LucideIcons.target), label: 'Maqsadlar'),
                  NavigationDestination(icon: Icon(LucideIcons.sparkles), label: 'AI'),
                  NavigationDestination(icon: Icon(LucideIcons.repeat), label: 'Odatlar'),
                  NavigationDestination(icon: Icon(LucideIcons.users), label: "Do'stlar"),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
