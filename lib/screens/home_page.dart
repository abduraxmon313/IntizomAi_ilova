import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/intizom_api.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/feedback.dart';
import '../widgets/ui_kit.dart';
import 'coach/coach_page.dart';
import 'habits/habits_page.dart';
import 'plans/plans_page.dart';
import 'stats/stats_page.dart';
import 'today/today_page.dart';

/// Ilova qobig'i. Har bir imkoniyatning bitta aniq joyi bor:
///
/// * Bugun — bugungi ishlar (reja + odat), kun holati.
/// * Rejalar — rejalashtirish: kun rejalari, oy va yil maqsadlari.
/// * Odatlar — odatlar va haftalik jadval.
/// * Natijalar — shaxsiy tahlil, do'stlar, reyting.
/// * Murabbiy — AI suhbat.
///
/// Profil va sozlamalar — Bugun sahifasidagi avatar ortida.
/// Orqaga tugmasi: boshqa bo'lim → Bugun → ilovadan chiqish.
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
  final _todayKey = GlobalKey<TodayPageState>();
  final _plansKey = GlobalKey<PlansPageState>();
  final _habitsKey = GlobalKey<HabitsPageState>();

  int _tab = 0;

  /// Natijalar va Murabbiy birinchi ochilganda quriladi.
  final _opened = <int>{0, 1, 2};

  static const _tabs = [
    (LucideIcons.sun, 'Bugun'),
    (LucideIcons.calendarDays, 'Rejalar'),
    (LucideIcons.repeat, 'Odatlar'),
    (LucideIcons.chartNoAxesColumn, 'Natijalar'),
    (LucideIcons.sparkles, 'Murabbiy'),
  ];

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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = i;
      _opened.add(i);
    });
  }

  void _openGoals() {
    _plansKey.currentState?.showView(PlansView.month);
    _select(1);
  }

  /// Joriy bo'limning yagona "qo'shish" amali (Natijalar va Murabbiyda yo'q).
  (String, VoidCallback)? get _add => switch (_tab) {
    0 => ("Reja qo'shish", () => _todayKey.currentState?.addPlan()),
    1 => ("Qo'shish", () => _plansKey.currentState?.add()),
    2 => ("Odat qo'shish", () => _habitsKey.currentState?.add()),
    _ => null,
  };

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
                children: [BrandMark(size: 64), SizedBox(height: 28), LoadingView(padding: 0)],
              ),
            ),
          );
        }
        if (_state.profile == null) {
          return Scaffold(
            body: ErrorRetry(message: _state.error ?? 'Xatolik yuz berdi', onRetry: _state.loadAll),
          );
        }
        final add = _add;
        return PopScope(
          canPop: _tab == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _select(0);
          },
          child: Scaffold(
            // Murabbiyda klaviatura ochilganda yozish maydoni ko'tariladi.
            resizeToAvoidBottomInset: _tab == 4,
            body: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _tab,
                children: [
                  TabFade(
                    active: _tab == 0,
                    child: TodayPage(
                      key: _todayKey,
                      state: _state,
                      onLogout: widget.onLogout,
                      onAppearanceChanged: widget.onAppearanceChanged,
                      onOpenGoals: _openGoals,
                    ),
                  ),
                  TabFade(active: _tab == 1, child: PlansPage(key: _plansKey, state: _state)),
                  TabFade(active: _tab == 2, child: HabitsPage(key: _habitsKey, state: _state)),
                  TabFade(
                    active: _tab == 3,
                    child: _opened.contains(3) ? StatsPage(state: _state) : const SizedBox.shrink(),
                  ),
                  TabFade(
                    active: _tab == 4,
                    child: _opened.contains(4) ? CoachPage(state: _state) : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            floatingActionButton: AnimatedScale(
              scale: add == null ? 0 : 1,
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              child: add == null
                  ? const SizedBox(width: 56, height: 56)
                  : AddFab(heroTag: 'add', tooltip: add.$1, onTap: add.$2),
            ),
            bottomNavigationBar: _NavBar(index: _tab, items: _tabs, onSelect: _select),
          ),
        );
      },
    );
  }
}

/// Pastki navigatsiya: faqat ikonka va yorliq, tanlangani — brend rangda.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.items, required this.onSelect});

  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].$2,
                    excludeSemantics: true,
                    child: InkResponse(
                      radius: 40,
                      onTap: () {
                        if (i != index) tapFeedback();
                        onSelect(i);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(items[i].$1, size: 22, color: i == index ? scheme.tertiary : scheme.outline),
                          const SizedBox(height: 4),
                          Text(
                            items[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.micro.copyWith(
                              fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                              color: i == index ? scheme.tertiary : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
