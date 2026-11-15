import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../../models/stats.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';

/// Bosh sahifa — streak, daraja, intizom balli, bugungi natija.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.profile,
    required this.stats,
    this.quest,
    this.coachMessage,
    required this.onRefresh,
  });

  final Profile profile;
  final UserStats stats;
  final DailyQuest? quest;
  final String? coachMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Greeting(profile: profile, stats: stats),
          const SizedBox(height: 18),
          if (coachMessage != null) ...[
            _CoachCard(message: coachMessage!),
            const SizedBox(height: 14),
          ],
          _StatsRow(stats: stats),
          const SizedBox(height: 14),
          _DisciplineCard(score: stats.disciplineScore),
          const SizedBox(height: 14),
          if (quest != null) ...[
            _QuestCard(quest: quest!),
            const SizedBox(height: 14),
          ],
          _TodayCard(done: stats.todayDone, total: stats.todayTotal),
          const SizedBox(height: 14),
          _XpCard(stats: stats),
          if (!stats.isPremium) ...[
            const SizedBox(height: 14),
            const _PremiumBanner(),
          ],
          if (stats.achievements.isNotEmpty) ...[
            const SizedBox(height: 22),
            AppSectionHeader(context.tr('Yutuqlar')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in stats.achievements) _AchievementChip(a: a),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile, required this.stats});
  final Profile profile;
  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Assalomu alaykum'),
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                profile.fullName,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (stats.isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppPalette.levelGold.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppPalette.levelGold.withValues(alpha: .3)),
            ),
            child: const Text(
              '💎 Premium',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppPalette.levelGold,
              ),
            ),
          ),
      ],
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.primaryContainer,
      child: Text(
        message,
        style: TextStyle(fontSize: 14, height: 1.5, color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: LucideIcons.flame,
            accent: AppPalette.streakOrange,
            value: '${stats.streak}',
            label: context.tr('Streak'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: LucideIcons.trophy,
            accent: AppPalette.levelGold,
            value: '${stats.level}',
            label: context.tr('Daraja'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: LucideIcons.star,
            accent: AppPalette.xpBlue,
            value: '${stats.totalScore}',
            label: context.tr('Ball'),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconTile.tinted(icon: icon, accent: accent, size: 34),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard({required this.score});
  final int score;

  String _text(BuildContext context) {
    if (score >= 80) return context.tr('Ajoyib natija! Siz haqiqiy intizomli insonsiz.');
    if (score >= 60) return context.tr('Yaxshi yo\'ldasiz. Davom eting!');
    if (score >= 40) return context.tr('O\'rta holat. Bugun bir qadam oldinga!');
    return context.tr('Har kuni kichik qadam katta natija beradi.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          DisciplineGauge(score: score, size: 76),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Intizom kuchi'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _text(context),
                  style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});
  final DailyQuest quest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = quest.target > 0 ? quest.progress / quest.target : 0.0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(quest.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppOverline(context.tr('Bugungi topshiriq')),
                    const SizedBox(height: 2),
                    Text(
                      quest.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(quest.subtitle, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          AppProgressBar(
            value: pct,
            color: quest.completed ? AppPalette.disciplineGreen : AppPalette.primary,
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total > 0 ? done / total : 0.0;
    return AppCard(
      child: Row(
        children: [
          const AppIconTile.tinted(
            icon: LucideIcons.clipboardCheck,
            accent: AppPalette.accentGreen,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Bugungi natijalar'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                AppProgressBar(
                  value: pct,
                  color: pct >= 1 ? AppPalette.disciplineGreen : AppPalette.accentTeal,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$done/$total',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _XpCard extends StatelessWidget {
  const _XpCard({required this.stats});
  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(stats.rankEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${stats.rankTitle} · ${stats.level}-${context.tr('daraja')}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(value: stats.xpPercent / 100, color: AppPalette.xpBlue, height: 8),
          const SizedBox(height: 6),
          Text(
            '${stats.xpInLevel} / ${stats.xpNeeded} XP',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: openPremiumInBot,
      color: AppPalette.levelGold.withValues(alpha: .07),
      child: Row(
        children: [
          const Text('💎', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Premium olish'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  context.tr('Cheksiz reja, odat, maqsad va AI Coach. To\'lov bot orqali.'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.a});
  final Achievement a;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text('${a.icon} ${a.title}', style: const TextStyle(fontSize: 13)),
    );
  }
}
