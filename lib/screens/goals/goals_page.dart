import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../models/goal.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Mini App uslubidagi Maqsadlar sahifasi: Yillik/Oylik segment,
/// yillar uchun horizontal year chips, oylar uchun 3x4 grid.
class GoalsPage extends StatefulWidget {
  const GoalsPage({
    super.key,
    required this.goals,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
    required this.onRefresh,
  });

  final List<Goal> goals;
  final void Function(Goal goal) onToggle;
  final void Function(Goal goal) onDelete;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  String _period = 'yearly'; // yearly | monthly
  late int _selectedYear;
  late int _selectedMonth;

  static final List<String> _uzMonths = [
    'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
    'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  List<Goal> get _filteredGoals {
    if (_period == 'yearly') {
      return widget.goals
          .where((g) => g.goalType == 'yearly' && g.period == '$_selectedYear')
          .toList();
    }
    final key =
        '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
    return widget.goals
        .where((g) => g.goalType == 'monthly' && g.period == key)
        .toList();
  }

  int _monthGoalCount(int month) {
    final key =
        '$_selectedYear-${month.toString().padLeft(2, '0')}';
    return widget.goals
        .where((g) => g.goalType == 'monthly' && g.period == key)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Header
            Text(
              'Maqsadlar 🎯',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              "Yo'lingni rejalashtir",
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Segment control
            _SegmentControl(
              selected: _period,
              onChanged: (v) => setState(() => _period = v),
            ),
            const SizedBox(height: 14),

            // Yearly view: year chips
            if (_period == 'yearly') ...[
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final year = now.year - i;
                    final isActive = year == _selectedYear;
                    final count = widget.goals
                        .where((g) => g.goalType == 'yearly' && g.period == '$year')
                        .length;
                    return _YearChip(
                      year: year,
                      count: count,
                      isActive: isActive,
                      onTap: () => setState(() => _selectedYear = year),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Monthly view: month grid
            if (_period == 'monthly') ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.3,
                ),
                itemCount: 12,
                itemBuilder: (_, i) {
                  final month = i + 1;
                  final isCurrent =
                      month == now.month && _selectedYear == now.year;
                  final isSelected = month == _selectedMonth;
                  final count = _monthGoalCount(month);
                  return _MonthCell(
                    name: _uzMonths[i],
                    count: count,
                    isCurrent: isCurrent,
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedMonth = month),
                  );
                },
              ),
              const SizedBox(height: 14),
            ],

            // Add button
            _GradientButton(
              label: "Maqsad qo'shish",
              onTap: widget.onAdd,
            ),
            const SizedBox(height: 14),

            // Goals list
            if (_filteredGoals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('Hozircha maqsadlar yo\'q'),
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final g in _filteredGoals) ...[
                _GoalTile(
                  goal: g,
                  onToggle: () => widget.onToggle(g),
                  onDelete: () => widget.onDelete(g),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _SegmentControl extends StatelessWidget {
  const _SegmentControl({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          _SegItem(
            label: 'Yillik',
            active: selected == 'yearly',
            onTap: () => onChanged('yearly'),
          ),
          _SegItem(
            label: 'Oylik',
            active: selected == 'monthly',
            onTap: () => onChanged('monthly'),
          ),
        ],
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  const _SegItem({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(colors: [scheme.primary, AppPalette.accent])
                : null,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.year,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final int year;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 78,
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(colors: [scheme.primary, AppPalette.accent])
              : null,
          color: isActive ? null : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: isActive ? null : Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$year',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.white : scheme.onSurface,
              ),
            ),
            Text(
              '$count ta',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white.withValues(alpha: .85)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.name,
    required this.count,
    required this.isCurrent,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool isCurrent;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: .1)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? scheme.primary
                : isSelected
                    ? scheme.primary
                    : scheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count ta',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [scheme.primary, AppPalette.accent]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: .3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.plus, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.onToggle, required this.onDelete});
  final Goal goal;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      onTap: onToggle,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: goal.completed ? AppPalette.disciplineGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: goal.completed ? AppPalette.disciplineGreen : scheme.outline,
                width: 2,
              ),
            ),
            child: goal.completed
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              goal.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: goal.completed ? scheme.onSurfaceVariant : scheme.onSurface,
                decoration: goal.completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.trash2, size: 17, color: scheme.onSurfaceVariant),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
