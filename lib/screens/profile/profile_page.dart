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

/// Mini App uslubidagi Profil sahifasi (settings icon orqali ochiladi).
/// Hero card, subscription, achievements, theme selector, social links, settings.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil 👤'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Hero card ──
          Container(
            padding: const EdgeInsets.all(22),
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
                // Avatar
                _HeroAvatar(url: profile.avatar, size: 80),
                const SizedBox(height: 10),
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (profile.username != null)
                  Text(
                    '@${profile.username}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .85),
                      fontSize: 12.5,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _HeroStat(value: '${stats.streak}', label: 'Streak'),
                    _HeroStat(value: '${stats.totalScore}', label: 'Ball'),
                    _HeroStat(
                      value: '${stats.todayDone}',
                      label: 'Bajarilgan',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Subscription status ──
          AppCard(
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
                        stats.isPremium ? 'Premium faol' : 'Obuna holati',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        stats.isPremium
                            ? context.tr('Premium faol — uzaytirish bot orqali')
                            : context.tr('Premium olish (bot orqali)'),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ),

          // ── Achievements ──
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
                  _AchTile(icon: a.icon, title: a.title),
              ],
            ),
          ],

          // ── Theme selector ──
          const SizedBox(height: 20),
          AppSectionHeader('🎨 Tema'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              _ThemeTile(
                name: 'Default',
                colors: [const Color(0xFF14b8a6), const Color(0xFF06b6d4)],
                active: true,
              ),
              _ThemeTile(
                name: 'Sprout',
                colors: [const Color(0xFF22c55e), const Color(0xFF16a34a)],
              ),
              _ThemeTile(
                name: 'Spectrum',
                colors: [const Color(0xFFec4899), const Color(0xFF8b5cf6)],
              ),
              _ThemeTile(
                name: 'Gamma',
                colors: [const Color(0xFFa855f7), const Color(0xFF7c3aed)],
              ),
              _ThemeTile(
                name: 'Atmosphere',
                colors: [const Color(0xFF3b82f6), const Color(0xFF0ea5e9)],
              ),
              _ThemeTile(
                name: 'Gold',
                colors: [const Color(0xFFd4a017), const Color(0xFFb8860b)],
              ),
            ],
          ),

          // ── Invite friends ──
          if (profile.referralLink != null) ...[
            const SizedBox(height: 20),
            AppSectionHeader("Do'stlarni taklif qil 🎁"),
            const SizedBox(height: 10),
            AppCard(
              onTap: () {
                Clipboard.setData(ClipboardData(text: profile.referralLink!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('Taklif havolasi nusxalandi'))),
                );
              },
              child: Row(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Do'stni taklif qil",
                          style: TextStyle(
                            fontSize: 14,
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
                  Icon(LucideIcons.share, size: 18, color: scheme.primary),
                ],
              ),
            ),
          ],

          // ── Social links ──
          const SizedBox(height: 20),
          _SettingTile(
            icon: '📢',
            title: 'Telegram kanal',
            subtitle: 'Yangiliklar va maslahatlar',
          ),
          _SettingTile(
            icon: '💬',
            title: "Admin bilan bog'lanish",
            subtitle: 'Savol, taklif va yordam',
          ),
          _SettingTile(
            icon: '📸',
            title: 'Instagram',
            subtitle: '@intizomai.uz',
          ),

          // ── Settings ──
          const SizedBox(height: 20),
          AppSectionHeader('Sozlamalar'),
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

          // ── Version ──
          const SizedBox(height: 16),
          _SettingTile(
            icon: 'ℹ️',
            title: 'Versiya',
            subtitle: 'Intizom AI v2.1 Pro',
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
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({required this.url, this.size = 80});
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withValues(alpha: .2),
        border: Border.all(color: Colors.white.withValues(alpha: .4), width: 2),
        image: image != null
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
      ),
      child: image == null
          ? Center(
              child: Text(
                '🙂',
                style: TextStyle(fontSize: size * .4),
              ),
            )
          : null,
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .85),
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _AchTile extends StatelessWidget {
  const _AchTile({required this.icon, required this.title});
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
      padding: const EdgeInsets.all(8),
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
            child: Text(icon, style: const TextStyle(fontSize: 20)),
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

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.name,
    required this.colors,
    this.active = false,
  });

  final String name;
  final List<Color> colors;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
          width: active ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
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
      onBackgroundImageError: image == null ? null : (_, __) {},
      child: image == null ? Text('🙂', style: TextStyle(fontSize: size * .45)) : null,
    );
  }
}
