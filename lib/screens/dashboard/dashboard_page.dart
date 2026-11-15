import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../models/habit.dart';
import '../../models/plan.dart';
import '../../models/profile.dart';
import '../../models/stats.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../profile/profile_page.dart';

/// Mini App bosh sahifa: header, hero card, quest, day strip, plans list.
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.profile,
    required this.stats,
    this.quest,
    this.coachMessage,
    required this.plans,
    required this.habits,
    required this.onRefresh,
    required this.onTogglePlan,
    required this.onDeletePlan,
    required this.onToggleHabit,
    required this.onAddPlan,
    required this.onOpenStats,
    required this.onOpenProfile,
    required this.onAppearanceChanged,
    required this.isDark,
  });

  final Profile profile;
  final UserStats stats;
  final DailyQuest? quest;
  final String? coachMessage;
  final List<Plan> plans;
  final List<Habit> habits;
  final Future<void> Function() onRefresh;
  final void Function(Plan) onTogglePlan;
  final void Function(Plan) onDeletePlan;
  final void Function(Habit) onToggleHabit;
  final VoidCallback onAddPlan;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenProfile;
  final ValueChanged<String> onAppearanceChanged;
  final bool isDark;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DateTime _selectedDate;
  late final ScrollController _dayStripController;

  static const _daysBefore = 14;
  static const _daysAfter = 30;
  static const _chipWidth = 64.0;
  static const _chipGap = 8.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = _tashkentToday();
    _dayStripController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _dayStripController.dispose();
    super.dispose();
  }

  static DateTime _tashkentToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5));
    return DateTime(now.year, now.month, now.day);
  }

  static final List<String> _uzDow = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];
  static final List<String> _uzMonths = [
    'Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyn',
    'Iyl', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek',
  ];
  static final List<String> _uzDowFull = [
    'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba',
    'Juma', 'Shanba', 'Yakshanba',
  ];

  String _formatDateLong(DateTime d) {
    final dow = (d.weekday - 1) % 7;
    return '${_uzDowFull[dow]}, ${d.day} ${_uzMonths[d.month - 1].toLowerCase()}';
  }

  void _scrollToSelected() {
    if (!_dayStripController.hasClients) return;
    final total = _chipWidth + _chipGap;
    final idx = _daysBefore; // "today" index
    final offset = (idx * total) - (_dayStripController.position.viewportDimension / 2) + (_chipWidth / 2);
    _dayStripController.jumpTo(offset.clamp(0, _dayStripController.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = _tashkentToday();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Header ──
            _Header(
              profile: widget.profile,
              dateLabel: _formatDateLong(today),
              isDark: widget.isDark,
              onToggleDark: () => widget.onAppearanceChanged(widget.isDark ? 'light' : 'dark'),
              onOpenStats: widget.onOpenStats,
              onOpenProfile: widget.onOpenProfile,
            ),
            const SizedBox(height: 16),

            // ── Hero card: Discipline Score ring + level/rank/XP ──
            _HeroCard(stats: widget.stats),
            const SizedBox(height: 14),

            // ── Quest card ──
            if (widget.quest != null) ...[
              _QuestCard(quest: widget.quest!),
              const SizedBox(height: 14),
            ],

            // ── Day strip ──
            SizedBox(
              height: 74,
              child: ListView.separated(
                controller: _dayStripController,
                scrollDirection: Axis.horizontal,
                itemCount: _daysBefore + 1 + _daysAfter,
                separatorBuilder: (_, __) => const SizedBox(width: _chipGap),
                itemBuilder: (_, i) {
                  final d = today.add(Duration(days: i - _daysBefore));
                  final isToday = d == today;
                  final isSel = d == _selectedDate;
                  final dow = (d.weekday - 1) % 7;
                  return _DayChip(
                    dow: isToday ? 'Bugun' : _uzDow[dow],
                    day: '${d.day}',
                    month: _uzMonths[d.month - 1],
                    isToday: isToday,
                    isSelected: isSel,
                    onTap: () => setState(() => _selectedDate = d),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // ── "Reja qo'shish" button ──
            _AddButton(onTap: widget.onAddPlan),
            const SizedBox(height: 14),

            // ── Plans list ──
            AppSectionHeader(_plansTitle(today)),
            const SizedBox(height: 10),
            if (widget.plans.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    context.tr('Hozircha rejalar yo\'q'),
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                  ),
                ),
              )
            else
              for (final p in widget.plans) ...[
                _PlanTile(
                  plan: p,
                  onToggle: () => widget.onTogglePlan(p),
                  onDelete: () => widget.onDeletePlan(p),
                ),
                const SizedBox(height: 8),
              ],

            // ── Today's habits (mixed in) ──
            if (widget.habits.where((h) => h.dueToday).isNotEmpty) ...[
              const SizedBox(height: 8),
              AppSectionHeader('Bugungi odatlar'),
              const SizedBox(height: 10),
              for (final h in widget.habits.where((h) => h.dueToday)) ...[
                _HabitMiniTile(
                  habit: h,
                  onToggle: () => widget.onToggleHabit(h),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _plansTitle(DateTime today) {
    final sel = _selectedDate;
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    if (sel == today) return 'Bugungi rejalar';
    if (sel == tomorrow) return 'Ertangi rejalar';
    if (sel == yesterday) return 'Kechagi rejalar';
    return '${sel.day} ${_uzMonths[sel.month - 1]} rejalari';
  }
}

// ── Header ──────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.dateLabel,
    required this.isDark,
    required this.onToggleDark,
    required this.onOpenStats,
    required this.onOpenProfile,
  });

  final Profile profile;
  final String dateLabel;
  final bool isDark;
  final VoidCallback onToggleDark;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ProfileAvatar(url: profile.avatar, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.fullName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                dateLabel,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        _HeaderButton(
          icon: isDark ? '🌙' : '☀️',
          onTap: onToggleDark,
        ),
        _HeaderButton(
          child: Icon(LucideIcons.barChart3, size: 20, color: scheme.primary),
          onTap: onOpenStats,
        ),
        _HeaderButton(
          child: Icon(LucideIcons.settings, size: 20, color: scheme.primary),
          onTap: onOpenProfile,
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({this.icon, this.child, required this.onTap});
  final String? icon;
  final Widget? child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: child ?? Text(icon!, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}

// ── Hero Card ───────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});
  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, AppPalette.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Discipline Score ring
              _DsRing(score: stats.disciplineScore),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rank chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${stats.rankEmoji} ${stats.rankTitle}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Daraja ${stats.level} · ${stats.xpInLevel}/${stats.xpNeeded} XP',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .9),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // XP bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (stats.xpPercent / 100).clamp(0, 1),
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: .2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${stats.xpPercent}%',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .8),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${stats.totalScore} XP',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroChip(emoji: '🔥', text: '${stats.streak} kun streak'),
              const SizedBox(width: 10),
              _HeroChip(
                emoji: '📋',
                text: '${stats.todayDone}/${stats.todayTotal} bugun',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DsRing extends StatelessWidget {
  const _DsRing({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _RingPainter(score / 100),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Discipline',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .8),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    final bg = Paint()
      ..color = Colors.white.withValues(alpha: .2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final fg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quest Card ──────────────────────────────────────────────────
class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});
  final DailyQuest quest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = quest.target > 0 ? quest.progress / quest.target : 0.0;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quest.icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quest.subtitle,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                AppProgressBar(
                  value: pct,
                  color:
                      quest.completed ? AppPalette.disciplineGreen : AppPalette.primary,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${quest.progress}/${quest.target}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    Text(
                      '+${quest.target * 10} XP',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
}

// ── Day Chip ────────────────────────────────────────────────────
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.dow,
    required this.day,
    required this.month,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final String dow;
  final String day;
  final String month;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary
              : isToday
                  ? scheme.primary.withValues(alpha: .1)
                  : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : isToday
                    ? scheme.primary
                    : scheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dow,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white.withValues(alpha: .85)
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              day,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : scheme.onSurface,
              ),
            ),
            Text(
              month,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.white.withValues(alpha: .8)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Button ──────────────────────────────────────────────────
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, AppPalette.accent],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: .3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              "Reja qo'shish",
              style: TextStyle(
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

// ── Plan Tile ───────────────────────────────────────────────────
class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.onToggle,
    required this.onDelete,
  });

  final Plan plan;
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
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: plan.isDone ? AppPalette.disciplineGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: plan.isDone
                    ? AppPalette.disciplineGreen
                    : plan.isFailed
                        ? AppPalette.danger
                        : scheme.outline,
                width: 2,
              ),
            ),
            child: plan.isDone
                ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: plan.isDone ? scheme.onSurfaceVariant : scheme.onSurface,
                    decoration: plan.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (plan.scheduledTime != null && plan.scheduledTime!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(LucideIcons.clock, size: 12, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          plan.scheduledTime!,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (plan.scoreValue > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+${plan.scoreValue}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
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

// ── Habit Mini Tile (for home page) ─────────────────────────────
class _HabitMiniTile extends StatelessWidget {
  const _HabitMiniTile({required this.habit, required this.onToggle});
  final Habit habit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      onTap: (habit.dueToday && !habit.finished) ? onToggle : null,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: habit.doneToday
                  ? AppPalette.disciplineGreen.withValues(alpha: .1)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(habit.icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              habit.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
          Text(
            '🔥 ${habit.streak}',
            style: const TextStyle(fontSize: 12, color: AppPalette.streakOrange),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: habit.doneToday ? AppPalette.disciplineGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: habit.doneToday ? AppPalette.disciplineGreen : scheme.outline,
                width: 2,
              ),
            ),
            child: habit.doneToday
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}
