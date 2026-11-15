import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/goal.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';
import '../forms.dart';

/// Maqsadlar: Yillik (yillar tasmasi) / Oylik (12 oy to'ri).
class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key, required this.state});

  final AppState state;

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  AppState get s => widget.state;

  String _type = 'yearly';
  late int _year = tashkentToday().year;
  late int _month = tashkentToday().month;

  String get _period => _type == 'yearly' ? '$_year' : '$_year-${_month.toString().padLeft(2, '0')}';

  String get _periodLabel => _type == 'yearly' ? '$_year-yil' : '${uzMonths[_month - 1]} $_year';

  List<Goal> _goalsFor(String type, String period) =>
      s.goals.where((g) => g.goalType == type && g.period == period).toList();

  Future<void> _add() async {
    if (await showGoalForm(context, api: s.api, goalType: _type, period: _period, periodLabel: _periodLabel)) {
      await s.refreshGoals();
    }
  }

  Future<void> _toggle(Goal g) async {
    try {
      await s.api.updateGoal(g.id, completed: !g.completed);
      await s.refreshGoals();
      if (!g.completed && mounted) toast(context, 'Maqsad bajarildi');
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _edit(Goal g) async {
    if (await showGoalForm(context, api: s.api, goal: g)) await s.refreshGoals();
  }

  Future<void> _delete(Goal g) async {
    if (!await confirmAction(context, title: "Maqsadni o'chirish", message: g.title)) return;
    try {
      await s.api.deleteGoal(g.id);
      await s.refreshGoals();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = _goalsFor(_type, _period);
    final done = list.where((g) => g.completed).length;
    return RefreshIndicator(
      onRefresh: s.refreshGoals,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          PageHeader(
            title: 'Maqsadlar',
            subtitle: 'Yil va oy uchun katta natijalar',
            actions: [HeaderIconButton(icon: LucideIcons.plus, tooltip: "Maqsad qo'shish", filled: true, onTap: _add)],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: SegmentTabs<String>(
              value: _type,
              items: const [('yearly', 'Yillik', null), ('monthly', 'Oylik', null)],
              onChanged: (v) => setState(() => _type = v),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: AppMotion.base,
            child: _type == 'yearly'
                ? KeyedSubtree(key: const ValueKey('y'), child: _yearStrip())
                : KeyedSubtree(key: const ValueKey('m'), child: _monthStrip()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 16, AppSpace.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              _periodLabel,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.6),
                            ),
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '$done', style: const TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: ' / ${list.length} bajarildi', style: TextStyle(color: scheme.onSurfaceVariant)),
                              ],
                            ),
                            style: const TextStyle(fontSize: 14, fontFeatures: tabularFigures),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppProgressBar(
                        value: list.isEmpty ? 0 : done / list.length,
                        height: 6,
                        color: null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: AppMotion.base,
                  child: list.isEmpty
                      ? EmptyView(
                          key: ValueKey('e$_period'),
                          icon: LucideIcons.target,
                          title: "Hali maqsad yo'q",
                          message: '$_periodLabel uchun eng muhim natijani yozing.',
                          actionLabel: "Maqsad qo'shish",
                          onAction: _add,
                        )
                      : GroupCard(
                          key: ValueKey('l$_period'),
                          indent: 52,
                          children: [
                            for (final g in list)
                              _GoalRow(
                                goal: g,
                                onToggle: () => _toggle(g),
                                onEdit: () => _edit(g),
                                onDelete: () => _delete(g),
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

  Widget _chip({required String label, required String? sub, required bool selected, required bool current, required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        tapFeedback();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.onSurface : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? scheme.onSurface : scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: tabularFigures,
                color: selected ? scheme.surface : (current ? scheme.tertiary : scheme.onSurface),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(width: 6),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 12,
                  fontFeatures: tabularFigures,
                  color: selected ? scheme.surface.withValues(alpha: .7) : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _yearStrip() {
    final cur = tashkentToday().year;
    final years = [for (var y = cur - 3; y <= cur + 3; y++) y];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        itemCount: years.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        controller: ScrollController(initialScrollOffset: 2 * 86.0),
        itemBuilder: (_, i) {
          final y = years[i];
          final n = _goalsFor('yearly', '$y').length;
          return _chip(
            label: '$y',
            sub: n == 0 ? null : '$n',
            selected: y == _year,
            current: y == cur,
            onTap: () => setState(() => _year = y),
          );
        },
      ),
    );
  }

  Widget _monthStrip() {
    final scheme = Theme.of(context).colorScheme;
    final today = tashkentToday();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(onPressed: () => setState(() => _year--), icon: const Icon(LucideIcons.chevronLeft, size: 20)),
              Expanded(
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tabularFigures,
                    color: _year == today.year ? scheme.tertiary : scheme.onSurface,
                  ),
                ),
              ),
              IconButton(onPressed: () => setState(() => _year++), icon: const Icon(LucideIcons.chevronRight, size: 20)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            itemCount: 12,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            controller: ScrollController(initialScrollOffset: ((_month - 3).clamp(0, 12)) * 74.0),
            itemBuilder: (_, i) {
              final m = i + 1;
              final n = _goalsFor('monthly', '$_year-${m.toString().padLeft(2, '0')}').length;
              return _chip(
                label: uzMonthsShort[i],
                sub: n == 0 ? null : '$n',
                selected: m == _month,
                current: m == today.month && _year == today.year,
                onTap: () => setState(() => _month = m),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.onToggle, required this.onEdit, required this.onDelete});

  final Goal goal;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckCircle(checked: goal.completed, color: scheme.primary, onTap: onToggle),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: -.15,
                        fontWeight: FontWeight.w500,
                        color: goal.completed ? scheme.onSurfaceVariant : scheme.onSurface,
                        decoration: goal.completed ? TextDecoration.lineThrough : null,
                        decorationColor: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (goal.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        goal.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Amallar',
              icon: Icon(LucideIcons.ellipsis, size: 18, color: scheme.outline),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Tahrirlash')),
                PopupMenuItem(value: 'delete', child: Text("O'chirish", style: TextStyle(color: AppPalette.danger))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
