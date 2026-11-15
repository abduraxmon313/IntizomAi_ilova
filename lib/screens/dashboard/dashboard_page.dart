import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Asosiy dashboard — streak, XP, discipline, bugungi natijalar.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.profile,
    this.todayDone = 0,
    this.todayTotal = 0,
    this.todayHabitsDone = 0,
    this.todayHabitsTotal = 0,
    this.smartMessage,
    this.onRefresh,
  });

  final UserProfile profile;
  final int todayDone;
  final int todayTotal;
  final int todayHabitsDone;
  final int todayHabitsTotal;
  final String? smartMessage;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Salom
          _GreetingHeader(profile: profile),
          const SizedBox(height: 20),

          // Smart coach xabari
          if (smartMessage != null) ...[
            _CoachMessageCard(message: smartMessage!),
            const SizedBox(height: 16),
          ],

          // Gamification kartalar
          _StatsRow(profile: profile),
          const SizedBox(height: 16),

          // Discipline score
          _DisciplineCard(score: profile.disciplineScore),
          const SizedBox(height: 16),

          // Bugungi natijalar
          AppSectionHeader(context.tr('Bugungi natijalar')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TodayStatCard(
                  icon: LucideIcons.clipboardCheck,
                  accent: AppPalette.accentBlue,
                  label: context.tr('Rejalar'),
                  value: '$todayDone/$todayTotal',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TodayStatCard(
                  icon: LucideIcons.repeat,
                  accent: AppPalette.accentGreen,
                  label: context.tr('Odatlar'),
                  value: '$todayHabitsDone/$todayHabitsTotal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // XP progress
          _XpProgressCard(profile: profile),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Greeting header
// ──────────────────────────────────────────────
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.profile});
  final UserProfile profile;

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.tr('Assalomu alaykum');
    if (hour < 18) return context.tr('Assalomu alaykum');
    return context.tr('Assalomu alaykum');
  }

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
                _greeting(context),
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${profile.avatarEmoji} ${profile.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        // Premium badge
        if (profile.isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.levelGold.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppPalette.levelGold.withValues(alpha: .3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('💎', style: TextStyle(fontSize: 14)),
                SizedBox(width: 4),
                Text(
                  'Premium',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.levelGold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Coach message card
// ──────────────────────────────────────────────
class _CoachMessageCard extends StatelessWidget {
  const _CoachMessageCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.primaryContainer,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤖', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Stats row: streak, level, weekly XP
// ──────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: LucideIcons.flame,
            accent: AppPalette.streakOrange,
            value: '${profile.streak}',
            label: context.tr('Streak'),
            suffix: context.tr('kun'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: LucideIcons.trophy,
            accent: AppPalette.levelGold,
            value: '${profile.level}',
            label: context.tr('Daraja'),
            suffix: profile.rankTitle ?? '',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: LucideIcons.zap,
            accent: AppPalette.xpBlue,
            value: '${profile.weeklyXp}',
            label: context.tr('Haftalik XP'),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
    this.suffix,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconTile.tinted(icon: icon, accent: accent, size: 36),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              if (suffix != null && suffix!.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  suffix!,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Discipline card
// ──────────────────────────────────────────────
class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          DisciplineGauge(score: score),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Intizom'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _motivationText(context, score),
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _motivationText(BuildContext context, int score) {
    if (score >= 80) return 'Ajoyib natija! Siz haqiqiy intizomli insonsiz 💎';
    if (score >= 60) return 'Yaxshi yo\'ldasiz! Davom eting 💪';
    if (score >= 40) return 'O\'rta holat. Bugun bir qadam oldinga! ⚡';
    return 'Boshlang! Har kuni kichik qadam katta natija beradi 🌱';
  }
}

// ──────────────────────────────────────────────
// Today stat card
// ──────────────────────────────────────────────
class _TodayStatCard extends StatelessWidget {
  const _TodayStatCard({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AppIconTile.tinted(icon: icon, accent: accent, size: 40),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// XP Progress card
// ──────────────────────────────────────────────
class _XpProgressCard extends StatelessWidget {
  const _XpProgressCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // XP progress hisoblash (bot'dagi formuladan)
    final level = profile.level;
    final xp = profile.xp;
    final base = 50 * (level - 1) * level;
    final next = 50 * level * (level + 1);
    final inLevel = xp - base;
    final needed = (next - base).clamp(1, 999999);
    final pct = (inLevel / needed).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile.tinted(
                icon: LucideIcons.star,
                accent: AppPalette.xpBlue,
                size: 36,
              ),
              const SizedBox(width: 12),
              Text(
                '${context.tr('Daraja')} ${profile.level} — ${profile.rankTitle ?? ""}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppProgressBar(
            value: pct,
            color: AppPalette.xpBlue,
            height: 8,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$inLevel XP',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$needed XP',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
