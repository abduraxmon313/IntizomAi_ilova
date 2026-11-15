import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/goal.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
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
    final list = _goalsFor(_type, _period);
    final done = list.where((g) => g.completed).length;
    return RefreshIndicator(
      onRefresh: s.refreshGoals,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const PageHeader(title: 'Maqsadlar', subtitle: "Yo'lingizni rejalashtiring"),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SegmentTabs<String>(
              value: _type,
              items: const [
                ('yearly', 'Yillik', LucideIcons.calendarRange),
                ('monthly', 'Oylik', LucideIcons.calendarDays),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
          ),
          const SizedBox(height: 14),
          if (_type == 'yearly') _yearStrip() else _monthGrid(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionBar(
                  title: '$_periodLabel maqsadlari',
                  count: list.isEmpty ? null : '$done/${list.length}',
                  actionLabel: "Qo'shish",
                  onAction: _add,
                ),
                if (list.isEmpty)
                  EmptyView(
                    icon: LucideIcons.target,
                    title: "Hali maqsad yo'q",
                    message: '$_periodLabel uchun nimaga erishmoqchisiz?',
                    actionLabel: "Maqsad qo'shish",
                    onAction: _add,
                  )
                else
                  GroupCard(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _yearStrip() {
    final scheme = Theme.of(context).colorScheme;
    final cur = tashkentToday().year;
    final years = [for (var y = cur - 3; y <= cur + 3; y++) y];
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: years.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        controller: ScrollController(initialScrollOffset: 2 * 88.0),
        itemBuilder: (_, i) {
          final y = years[i];
          final sel = y == _year;
          final count = _goalsFor('yearly', '$y').length;
          return GestureDetector(
            onTap: () => setState(() => _year = y),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 80,
              decoration: BoxDecoration(
                color: sel ? scheme.primary : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: sel ? scheme.primary : scheme.outlineVariant),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$y',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: sel ? scheme.onPrimary : (y == cur ? scheme.primary : scheme.onSurface),
                    ),
                  ),
                  Text(
                    '$count maqsad',
                    style: TextStyle(
                      fontSize: 11,
                      color: sel ? scheme.onPrimary.withValues(alpha: .85) : scheme.onSurfaceVariant,
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

  Widget _monthGrid() {
    final scheme = Theme.of(context).colorScheme;
    final today = tashkentToday();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _year--),
                icon: const Icon(LucideIcons.chevronLeft, size: 20),
              ),
              Expanded(
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _year++),
                icon: const Icon(LucideIcons.chevronRight, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: [
              for (var m = 1; m <= 12; m++)
                Builder(
                  builder: (_) {
                    final sel = m == _month;
                    final isCur = m == today.month && _year == today.year;
                    final count = _goalsFor('monthly', '$_year-${m.toString().padLeft(2, '0')}').length;
                    return GestureDetector(
                      onTap: () => setState(() => _month = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        decoration: BoxDecoration(
                          color: sel ? scheme.primary : scheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: sel ? scheme.primary : (isCur ? scheme.primary.withValues(alpha: .5) : scheme.outlineVariant),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              uzMonthsShort[m - 1],
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: sel ? scheme.onPrimary : scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              count == 0 ? '—' : '$count',
                              style: TextStyle(
                                fontSize: 11,
                                color: sel ? scheme.onPrimary.withValues(alpha: .85) : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
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
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: Row(
          children: [
            CheckCircle(checked: goal.completed, color: scheme.primary, onTap: onToggle),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: goal.completed ? scheme.onSurfaceVariant : scheme.onSurface,
                      decoration: goal.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (goal.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      goal.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: scheme.onSurfaceVariant),
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
