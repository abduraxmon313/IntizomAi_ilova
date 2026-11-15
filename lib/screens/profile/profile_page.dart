import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../../models/stats.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';

/// Profil va sozlamalar (MyFit'dagi panel/qator uslubi).
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.stats,
    required this.isDark,
    required this.onLogout,
    required this.onAppearanceChanged,
    required this.onLanguageChanged,
    required this.onNotificationsChanged,
  });

  final Profile profile;
  final UserStats stats;
  final bool isDark;
  final VoidCallback onLogout;
  final ValueChanged<String> onAppearanceChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<bool> onNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _Panel(
          child: Row(
            children: [
              ProfileAvatar(url: profile.avatar, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${stats.rankEmoji} ${stats.rankTitle} · ${stats.level}-${context.tr('daraja')}',
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            children: [
              _Row(
                icon: LucideIcons.flame,
                accent: AppPalette.streakOrange,
                label: context.tr('Streak'),
                value: '${stats.streak} ${context.tr('kun')}',
              ),
              const Divider(height: 1),
              _Row(
                icon: LucideIcons.award,
                accent: AppPalette.accentViolet,
                label: context.tr('Eng uzun streak'),
                value: '${stats.longestStreak} ${context.tr('kun')}',
              ),
              const Divider(height: 1),
              _Row(
                icon: LucideIcons.star,
                accent: AppPalette.xpBlue,
                label: context.tr('Ball'),
                value: '${stats.totalScore}',
              ),
              const Divider(height: 1),
              _Row(
                icon: LucideIcons.sparkles,
                accent: AppPalette.disciplineGreen,
                label: context.tr('Mukammal kunlar'),
                value: '${stats.perfectDays}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          onTap: openPremiumInBot,
          color: AppPalette.levelGold.withValues(alpha: .07),
          child: Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stats.isPremium
                      ? context.tr('Premium faol — uzaytirish bot orqali')
                      : context.tr('Premium olish (bot orqali)'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
        if (profile.referralLink != null) ...[
          const SizedBox(height: 12),
          AppCard(
            onTap: () {
              Clipboard.setData(ClipboardData(text: profile.referralLink!));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('Taklif havolasi nusxalandi'))),
              );
            },
            child: Row(
              children: [
                const AppIconTile.tinted(icon: LucideIcons.userPlus, accent: AppPalette.accentTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Do\'stlarni taklif qilish'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        context.tr('Taklif qilinganlar: {n}', {'n': profile.referralCount}),
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.copy, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        AppSectionHeader(context.tr('Sozlamalar')),
        const SizedBox(height: 10),
        _Panel(
          child: Column(
            children: [
              _SettingRow(
                icon: LucideIcons.sun,
                label: context.tr('Ko\'rinish'),
                trailing: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'light', label: Text(context.tr('Yorug\''))),
                    ButtonSegment(value: 'dark', label: Text(context.tr('Qorong\'i'))),
                  ],
                  selected: {isDark ? 'dark' : 'light'},
                  onSelectionChanged: (s) => onAppearanceChanged(s.first),
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ),
              const Divider(height: 1),
              _SettingRow(
                icon: LucideIcons.globe,
                label: context.tr('Til'),
                trailing: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'uz', label: Text('Uz')),
                    ButtonSegment(value: 'ru', label: Text('Ru')),
                    ButtonSegment(value: 'en', label: Text('En')),
                  ],
                  selected: {AppLocalizations.of(context).languageCode},
                  onSelectionChanged: (s) => onLanguageChanged(s.first),
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ),
              const Divider(height: 1),
              _SettingRow(
                icon: LucideIcons.bell,
                label: context.tr('Bot eslatmalari'),
                trailing: Switch.adaptive(
                  value: profile.notificationsEnabled,
                  onChanged: onNotificationsChanged,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(LucideIcons.logOut, size: 18, color: AppPalette.danger),
          label: Text(context.tr('Chiqish'), style: const TextStyle(color: AppPalette.danger)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppPalette.danger.withValues(alpha: .3)),
          ),
        ),
      ],
    );
  }
}

/// Telegram rasmi (URL) yoki Mini App'da yuklangan rasm (data:base64).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.url, this.size = 36});
  final String? url;
  final double size;

  ImageProvider? _image() {
    final u = url;
    if (u == null || u.isEmpty) return null;
    if (u.startsWith('data:')) {
      final comma = u.indexOf(',');
      if (comma < 0) return null;
      try {
        return MemoryImage(base64Decode(u.substring(comma + 1)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(u);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: image,
      onBackgroundImageError: image == null ? null : (_, _) {},
      child: image == null ? Text('🙂', style: TextStyle(fontSize: size * .45)) : null,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .7)),
      ),
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.accent, required this.label, required this.value});
  final IconData icon;
  final Color accent;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          AppIconTile.tinted(icon: icon, accent: accent, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label, required this.trailing});
  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: scheme.onSurface))),
          trailing,
        ],
      ),
    );
  }
}
