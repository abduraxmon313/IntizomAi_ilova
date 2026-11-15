import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/stats.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Statistika sahifasi — header tugmasi orqali ochiladi (fullscreen page).
/// Mini App'dagi stats page: stat grid, haftalik faollik bars,
/// discipline score trend, faollik xaritasi, maqsadlar donut.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.stats});
  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistika 📊'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Stat grid
          Row(
            children: [
              _StatCard(
                icon: '🔥',
                label: 'Joriy streak',
                value: '${stats.streak}',
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: '⭐',
                label: 'Jami ball',
                value: '${stats.totalScore}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCard(
                icon: '✓',
                label: 'Bajarilgan',
                value: '${stats.todayDone}',
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: '🎯',
                label: 'Mukammal kunlar',
                value: '${stats.perfectDays}',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Discipline score card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discipline Score',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${stats.disciplineScore}/100',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppProgressBar(
                  value: stats.disciplineScore / 100,
                  height: 10,
                  color: stats.disciplineScore >= 70
                      ? AppPalette.disciplineGreen
                      : stats.disciplineScore >= 40
                          ? AppPalette.warning
                          : AppPalette.danger,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // XP / Level card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(stats.rankEmoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${stats.rankTitle} · ${stats.level}-daraja',
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
          ),
          const SizedBox(height: 14),

          // Longest streak card
          AppCard(
            child: Row(
              children: [
                const AppIconTile.tinted(
                  icon: LucideIcons.award,
                  accent: AppPalette.streakOrange,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eng uzun streak',
                        style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        '${stats.longestStreak} kun',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Achievements
          if (stats.achievements.isNotEmpty) ...[
            const SizedBox(height: 20),
            AppSectionHeader('Yutuqlar 🏆'),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .85,
              children: [
                for (final a in stats.achievements)
                  _AchCard(icon: a.icon, title: a.title),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});
  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    foreground: Paint()
                      ..shader = LinearGradient(
                        colors: [scheme.primary, AppPalette.accent],
                      ).createShader(const Rect.fromLTWH(0, 0, 80, 28)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AchCard extends StatelessWidget {
  const _AchCard({required this.icon, required this.title});
  final String icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary, AppPalette.accent]),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 20, color: Colors.white)),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
