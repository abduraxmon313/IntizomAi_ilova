import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/ui_kit.dart';

/// Mini App'dagi yutuq bosqichlari (streak, maqsad, ball).
class AchievementMilestone {
  const AchievementMilestone(this.icon, this.accent, this.value, this.label, this.current, this.target);

  final IconData icon;
  final Color accent;
  final String value;
  final String label;
  final int current;
  final int target;

  bool get unlocked => current >= target;
  double get progress => (current / target).clamp(0, 1).toDouble();
}

const kAchievementCount = 6;

List<AchievementMilestone> achievementMilestones(int streak, int score, int goalsDone) => [
  AchievementMilestone(LucideIcons.flame, AppPalette.ember, '3 kun', 'Streak', streak, 3),
  AchievementMilestone(LucideIcons.zap, AppPalette.accentAmber, '7 kun', 'Streak', streak, 7),
  AchievementMilestone(LucideIcons.gem, AppPalette.accentViolet, '30 kun', 'Streak', streak, 30),
  AchievementMilestone(LucideIcons.target, AppPalette.accentTeal, '10 ta', 'Maqsad', goalsDone, 10),
  AchievementMilestone(LucideIcons.trophy, AppPalette.accentBlue, '100', 'Ball', score, 100),
  AchievementMilestone(LucideIcons.crown, AppPalette.accentRose, '500', 'Ball', score, 500),
];

/// 3 ustunli yutuqlar panjarasi (Yutuqlar sahifasi va Profil).
class AchievementGrid extends StatelessWidget {
  const AchievementGrid({super.key, required this.items});

  final List<AchievementMilestone> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: .95,
      children: [
        for (final a in items)
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: a.unlocked ? 1 : .45,
                  child: AppIconTile.tinted(icon: a.icon, accent: a.unlocked ? a.accent : AppPalette.accentSlate, size: 34),
                ),
                const Spacer(),
                Text(
                  a.value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                    color: a.unlocked ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
                Text(a.label, maxLines: 1, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                AppProgressBar(value: a.progress, height: 3, color: a.unlocked ? a.accent : null),
              ],
            ),
          ),
      ],
    );
  }
}

/// Yutuqlar: daraja, bosqichlar, serverdan kelgan qo'lga kiritilgan nishonlar.
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final st = state.stats;
        final items = achievementMilestones(st.streak, st.totalScore, state.goals.where((g) => g.completed).length);
        final unlocked = items.where((a) => a.unlocked).length;
        return RefreshIndicator(
          onRefresh: state.refreshStats,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PageHeader(title: 'Yutuqlar', subtitle: '$unlocked / ${items.length} bosqich ochildi'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const AppIconTile.tinted(icon: LucideIcons.award, accent: AppPalette.accentBlue, size: 46),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${st.level}-daraja · ${st.rankTitle}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -.2),
                                ),
                                const SizedBox(height: 8),
                                AppProgressBar(value: st.xpPercent / 100, height: 6),
                                const SizedBox(height: 6),
                                Text(
                                  '${st.xpInLevel} / ${st.xpNeeded} XP · ${st.perfectDays} mukammal kun',
                                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionBar(title: 'Bosqichlar', top: 24),
                    AchievementGrid(items: items),
                    if (st.achievements.isNotEmpty) ...[
                      SectionBar(title: "Qo'lga kiritilgan", count: '${st.achievements.length}', top: 24),
                      GroupCard(
                        indent: 64,
                        children: [
                          for (final a in st.achievements)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Row(
                                children: [
                                  AppIconTile.tinted(
                                    icon: habitGlyphs[a.icon.trim()] ?? LucideIcons.medal,
                                    accent: _rarityColor(a.rarity),
                                    size: 34,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      a.title,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -.15),
                                    ),
                                  ),
                                  Pill(_rarityLabel(a.rarity), color: _rarityColor(a.rarity)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Color _rarityColor(String r) => switch (r) {
    'legendary' => AppPalette.accentAmber,
    'epic' => AppPalette.accentViolet,
    'rare' => AppPalette.accentBlue,
    _ => AppPalette.accentTeal,
  };

  static String _rarityLabel(String r) => switch (r) {
    'legendary' => 'Afsonaviy',
    'epic' => 'Epik',
    'rare' => 'Noyob',
    _ => 'Oddiy',
  };
}
