import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/ui_kit.dart';

/// Mini App'dagi yutuq bosqichlari (seriya, maqsad, ball).
class AchievementMilestone {
  const AchievementMilestone(this.icon, this.title, this.current, this.target, this.unit);

  final IconData icon;
  final String title;
  final int current;
  final int target;
  final String unit;

  bool get unlocked => current >= target;
  double get progress => (current / target).clamp(0, 1).toDouble();
}

List<AchievementMilestone> achievementMilestones(int streak, int score, int goalsDone) => [
  AchievementMilestone(LucideIcons.flame, '3 kunlik seriya', streak, 3, 'kun'),
  AchievementMilestone(LucideIcons.flame, '7 kunlik seriya', streak, 7, 'kun'),
  AchievementMilestone(LucideIcons.flame, '30 kunlik seriya', streak, 30, 'kun'),
  AchievementMilestone(LucideIcons.target, '10 ta maqsad', goalsDone, 10, 'ta'),
  AchievementMilestone(LucideIcons.star, '100 ball', score, 100, 'ball'),
  AchievementMilestone(LucideIcons.star, '500 ball', score, 500, 'ball'),
];

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
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const PageHeader(title: 'Yutuqlar'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: surfaceDecoration(context),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${items.length} bosqichdan $unlocked tasi ochildi', style: AppType.heading),
                          const SizedBox(height: 12),
                          AppProgressBar(value: unlocked / items.length),
                          const SizedBox(height: 10),
                          Text(
                            _nextHint(items),
                            style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SectionBar(title: 'Bosqichlar'),
                    GroupCard(
                      indent: 68,
                      children: [
                        for (final a in items)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Row(
                              children: [
                                AppIconTile(icon: a.icon, tone: a.unlocked ? scheme.primary : null, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.title,
                                        style: AppType.body.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: a.unlocked ? scheme.onSurface : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (a.unlocked)
                                        Text('Ochildi', style: AppType.caption.copyWith(color: scheme.tertiary, fontWeight: FontWeight.w600))
                                      else
                                        Row(
                                          children: [
                                            Expanded(child: AppProgressBar(value: a.progress, height: 4)),
                                            const SizedBox(width: 10),
                                            Text(
                                              '${a.current}/${a.target} ${a.unit}',
                                              style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                if (a.unlocked) ...[
                                  const SizedBox(width: 10),
                                  Icon(LucideIcons.circleCheck, size: 20, color: scheme.tertiary),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (st.achievements.isNotEmpty) ...[
                      SectionBar(title: 'Nishonlar', count: '${st.achievements.length}'),
                      GroupCard(
                        children: [
                          for (final a in st.achievements)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                              child: Row(
                                children: [
                                  Text(a.icon, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 14),
                                  Expanded(child: Text(a.title, style: AppType.body.copyWith(fontWeight: FontWeight.w500))),
                                  Pill(_rarityLabel(a.rarity), muted: a.rarity == 'common', color: a.rarity == 'legendary' ? AppPalette.gold : null),
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

  /// Eng yaqin ochilmagan bosqich haqida izoh.
  static String _nextHint(List<AchievementMilestone> items) {
    final locked = items.where((a) => !a.unlocked).toList()..sort((a, b) => b.progress.compareTo(a.progress));
    if (locked.isEmpty) return 'Barcha bosqichlar ochildi. Ajoyib natija!';
    final n = locked.first;
    return 'Eng yaqini: ${n.title} — yana ${n.target - n.current} ${n.unit} qoldi.';
  }

  static String _rarityLabel(String r) => switch (r) {
    'legendary' => 'Afsonaviy',
    'epic' => 'Epik',
    'rare' => 'Noyob',
    _ => 'Oddiy',
  };
}
