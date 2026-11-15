import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Profil sahifasi — MyFit uslubidagi panel-row pattern.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.onLogout,
    this.onAppearanceChanged,
    this.onLanguageChanged,
    this.onNameChanged,
    this.onNotificationsChanged,
  });

  final UserProfile profile;
  final VoidCallback onLogout;
  final ValueChanged<String>? onAppearanceChanged;
  final ValueChanged<String>? onLanguageChanged;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<bool>? onNotificationsChanged;

  void _openPremiumBot() async {
    final uri = Uri.parse('$kBotUrl?start=premium');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Profil'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),

              // Avatar va ism
              _panel(
                scheme,
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: scheme.primaryContainer,
                      backgroundImage: profile.effectivePhotoUrl != null
                          ? NetworkImage(profile.effectivePhotoUrl!)
                          : null,
                      child: profile.effectivePhotoUrl == null
                          ? Text(
                              profile.avatarEmoji,
                              style: const TextStyle(fontSize: 28),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${profile.rankTitle ?? "Boshlovchi"} • ${context.tr("Daraja")} ${profile.level}',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (profile.isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppPalette.levelGold.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
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
                ),
              ),
              const SizedBox(height: 12),

              // Statistika
              _panel(
                scheme,
                child: Column(
                  children: [
                    _row(
                      scheme,
                      icon: LucideIcons.flame,
                      accent: AppPalette.streakOrange,
                      label: context.tr('Streak'),
                      value: '${profile.streak} ${context.tr("kun")}',
                    ),
                    const Divider(height: 1),
                    _row(
                      scheme,
                      icon: LucideIcons.trophy,
                      accent: AppPalette.levelGold,
                      label: 'XP',
                      value: '${profile.xp}',
                    ),
                    const Divider(height: 1),
                    _row(
                      scheme,
                      icon: LucideIcons.target,
                      accent: AppPalette.disciplineGreen,
                      label: context.tr('Intizom'),
                      value: '${profile.disciplineScore}/100',
                    ),
                    const Divider(height: 1),
                    _row(
                      scheme,
                      icon: LucideIcons.award,
                      accent: AppPalette.accentViolet,
                      label: context.tr('Eng uzun streak'),
                      value: '${profile.longestStreak} ${context.tr("kun")}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Premium
              if (!profile.isPremium) ...[
                AppCard(
                  onTap: _openPremiumBot,
                  padding: const EdgeInsets.all(16),
                  color: dark
                      ? AppPalette.levelGold.withValues(alpha: .08)
                      : AppPalette.levelGold.withValues(alpha: .06),
                  child: Row(
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
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
                            const SizedBox(height: 2),
                            Text(
                              context.tr('Bot orqali Premium'),
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Sozlamalar
              AppSectionHeader(context.tr('Sozlamalar')),
              const SizedBox(height: 10),
              _panel(
                scheme,
                child: Column(
                  children: [
                    // Ko'rinish
                    _settingRow(
                      scheme,
                      icon: LucideIcons.sun,
                      label: context.tr('Ko\'rinish'),
                      trailing: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'light', label: Text(context.tr('Yorug\''))),
                          ButtonSegment(value: 'dark', label: Text(context.tr('Qorong\'i'))),
                        ],
                        selected: {dark ? 'dark' : 'light'},
                        onSelectionChanged: (sel) =>
                            onAppearanceChanged?.call(sel.first),
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: scheme.primaryContainer,
                          textStyle: const TextStyle(fontSize: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const Divider(height: 1),

                    // Til
                    _settingRow(
                      scheme,
                      icon: LucideIcons.globe,
                      label: context.tr('Til'),
                      trailing: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'uz', label: Text('Uz')),
                          ButtonSegment(value: 'ru', label: Text('Ru')),
                          ButtonSegment(value: 'en', label: Text('En')),
                        ],
                        selected: {AppLocalizations.of(context).languageCode},
                        onSelectionChanged: (sel) =>
                            onLanguageChanged?.call(sel.first),
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: scheme.primaryContainer,
                          textStyle: const TextStyle(fontSize: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const Divider(height: 1),

                    // Bildirishnomalar
                    _settingRow(
                      scheme,
                      icon: LucideIcons.bell,
                      label: context.tr('Bildirishnomalar'),
                      trailing: Switch.adaptive(
                        value: profile.notificationsEnabled,
                        onChanged: (val) => onNotificationsChanged?.call(val),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Chiqish
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: Icon(
                    LucideIcons.logOut,
                    size: 18,
                    color: AppPalette.danger,
                  ),
                  label: Text(
                    context.tr('Chiqish'),
                    style: const TextStyle(color: AppPalette.danger),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppPalette.danger.withValues(alpha: .3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(ColorScheme scheme, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .7),
        ),
      ),
      child: child,
    );
  }

  Widget _row(
    ColorScheme scheme, {
    required IconData icon,
    required Color accent,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(
    ColorScheme scheme, {
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
