import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../l10n/app_localizations.dart';
import '../../models/plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Rejalar sahifasi — bugungi rejalar ro'yxati, yaratish, status o'zgartirish.
class PlansPage extends StatefulWidget {
  const PlansPage({
    super.key,
    required this.plans,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onAdd,
    required this.onMoveToTomorrow,
    this.onRefresh,
    this.isPremium = false,
  });

  final List<Plan> plans;
  final Future<void> Function(int planId, String status) onToggleStatus;
  final Future<void> Function(int planId) onDelete;
  final VoidCallback onAdd;
  final Future<void> Function(int planId) onMoveToTomorrow;
  final Future<void> Function()? onRefresh;
  final bool isPremium;

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = widget.plans.where((p) => p.isDone).length;
    final total = widget.plans.length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // Progress
          if (total > 0) ...[
            _ProgressHeader(done: done, total: total),
            const SizedBox(height: 16),
          ],

          // Rejalar
          if (widget.plans.isEmpty)
            _EmptyState(onAdd: widget.onAdd)
          else
            ...widget.plans.map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlanTile(
                plan: plan,
                onToggle: () => widget.onToggleStatus(
                  plan.id,
                  plan.isDone ? 'pending' : 'done',
                ),
                onDelete: () => widget.onDelete(plan.id),
                onMoveToTomorrow: () => widget.onMoveToTomorrow(plan.id),
              ),
            )),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total > 0 ? done / total : 0.0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Bugun'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                '$done/$total ${context.tr('Bajarildi').toLowerCase()}',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppProgressBar(
            value: pct,
            color: pct >= 1.0 ? AppPalette.disciplineGreen : AppPalette.primary,
            height: 8,
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.onToggle,
    required this.onDelete,
    required this.onMoveToTomorrow,
  });

  final Plan plan;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onMoveToTomorrow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = plan.isDone;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done ? AppPalette.disciplineGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: done
                      ? AppPalette.disciplineGreen
                      : scheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // Title va vaqt
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: done
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (plan.scheduledTime != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        plan.scheduledTime!,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Menu
          PopupMenuButton<String>(
            icon: Icon(
              LucideIcons.ellipsisVertical,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            onSelected: (val) {
              if (val == 'delete') onDelete();
              if (val == 'tomorrow') onMoveToTomorrow();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'tomorrow',
                child: Row(
                  children: [
                    Icon(LucideIcons.arrowRight, size: 16),
                    const SizedBox(width: 8),
                    Text(context.tr('Ertaga ko\'chirish')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(LucideIcons.trash2, size: 16, color: AppPalette.danger),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('O\'chirish'),
                      style: const TextStyle(color: AppPalette.danger),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              LucideIcons.clipboardList,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: .4),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('Hozircha rejalar yo\'q'),
              style: TextStyle(
                fontSize: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: Text(context.tr('Yangi reja')),
            ),
          ],
        ),
      ),
    );
  }
}
