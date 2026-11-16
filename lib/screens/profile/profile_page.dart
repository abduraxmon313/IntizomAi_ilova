import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/extras.dart';
import '../../services/intizom_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';

const _referralText = "Siz intizomlimisiz?\n\n"
    "Ko'pchilik maqsad qo'yadi, reja tuzadi, lekin oxirigacha yetib bormaydi.\n\n"
    "IntizomAI maqsad, reja va odatlaringizni kuzatib boradi, AI esa progressingizni "
    "tahlil qilib sizga mos tavsiyalar beradi.\n\n"
    "Bilim + Intizom = Natija";

/// Profil va sozlamalar (Bugun sahifasidagi avatar ortida).
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.state,
    required this.onLogout,
    required this.onAppearanceChanged,
  });

  final AppState state;
  final VoidCallback onLogout;
  final ValueChanged<String> onAppearanceChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppState get s => widget.state;

  Subscription? _sub;

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
    _load();
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final sub = await s.api.subscription();
      if (mounted) setState(() => _sub = sub);
    } catch (_) {}
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _shareInvite() async {
    final link = s.profile?.referralLink;
    if (link == null) return;
    await _open(Uri.https('t.me', '/share/url', {'url': link, 'text': _referralText}).toString());
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: s.profile?.fullName ?? '');
    await showFormSheet<void>(
      context,
      title: 'Ismni tahrirlash',
      builder: (ctx, _) => TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Ismingiz', counterText: ''),
      ),
      onSave: () async {
        final name = ctrl.text.trim();
        if (name.isEmpty) return false;
        try {
          s.setProfile(await s.api.updateProfile(fullName: name));
          return true;
        } catch (e) {
          if (mounted) showApiError(context, e);
          return false;
        }
      },
    );
  }

  Future<void> _changePhoto() async {
    final hasCustom = s.profile?.customPhotoUrl?.isNotEmpty == true;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Galereyadan tanlash'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Suratga olish'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (hasCustom)
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: AppPalette.danger),
                title: const Text('Telegram rasmiga qaytish', style: TextStyle(color: AppPalette.danger)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'remove') {
        s.setProfile(await s.api.updateProfile(removeCustomPhoto: true));
        return;
      }
      final file = await ImagePicker().pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (dataUrl.length > 1000000) {
        if (mounted) toast(context, 'Rasm juda katta. Boshqasini tanlang.');
        return;
      }
      s.setProfile(await s.api.updateProfile(customPhotoUrl: dataUrl));
      if (mounted) toast(context, 'Profil rasmi yangilandi');
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _setNotifications(bool v) async {
    try {
      s.setProfile(await s.api.updateProfile(notifications: v));
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _logout() async {
    if (!await confirmAction(context, title: 'Hisobdan chiqish', message: 'Qayta kirish uchun Telegram orqali tasdiqlaysiz.', confirmLabel: 'Chiqish')) {
      return;
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = s.profile!;
    final st = s.stats;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([s.refreshProfile(), s.refreshStats(), _load()]);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const PageHeader(title: 'Profil'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Shaxs ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 20),
                      child: Row(
                        children: [
                          Semantics(
                            button: true,
                            label: "Profil rasmini o'zgartirish",
                            child: GestureDetector(
                              onTap: _changePhoto,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ProfileAvatar(url: p.avatar, telegramId: p.telegramId, name: p.fullName, size: 72),
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerLowest,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: scheme.outlineVariant),
                                      ),
                                      child: Icon(LucideIcons.camera, size: 13, color: scheme.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.title),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (p.username?.isNotEmpty == true) ...[
                                      Flexible(
                                        child: Text(
                                          '@${p.username}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppType.label.copyWith(color: scheme.onSurfaceVariant),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (st.isPremium) const Pill('Premium', color: AppPalette.gold),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SubscriptionCard(sub: _sub, isPremium: st.isPremium),

                    // ── Hisob ──────────────────────────────
                    const SectionBar(title: 'Hisob'),
                    GroupCard(
                      indent: 50,
                      children: [
                        SettingTile(icon: LucideIcons.userRound, title: 'Ism', subtitle: p.fullName, onTap: _editName),
                        SettingTile(
                          icon: LucideIcons.gift,
                          title: "Do'stni taklif qilish",
                          subtitle: p.referralCount > 0
                              ? "${p.referralCount} ta do'st qo'shildi"
                              : "Har 5 faol do'st uchun 7 kun Premium",
                          onTap: _shareInvite,
                        ),
                      ],
                    ),

                    // ── Sozlamalar ─────────────────────────
                    const SectionBar(title: 'Sozlamalar'),
                    GroupCard(
                      indent: 50,
                      children: [
                        SettingTile(
                          icon: LucideIcons.moon,
                          title: 'Tungi rejim',
                          trailing: Switch(
                            value: dark,
                            onChanged: (v) => widget.onAppearanceChanged(v ? 'dark' : 'light'),
                          ),
                        ),
                        SettingTile(
                          icon: LucideIcons.bell,
                          title: 'Eslatmalar',
                          subtitle: 'Reja va odat vaqtida Telegram xabari',
                          trailing: Switch(value: p.notificationsEnabled, onChanged: _setNotifications),
                        ),
                      ],
                    ),

                    // ── Yordam ─────────────────────────────
                    const SectionBar(title: 'Yordam va aloqa'),
                    GroupCard(
                      indent: 50,
                      children: [
                        SettingTile(
                          icon: LucideIcons.messageCircle,
                          title: "Qo'llab-quvvatlash",
                          subtitle: 'Savol va takliflar',
                          onTap: () => _open('https://t.me/IntizomAI_Admin_bot'),
                        ),
                        SettingTile(
                          icon: LucideIcons.megaphone,
                          title: 'Telegram kanal',
                          subtitle: 'Yangiliklar va maslahatlar',
                          onTap: () => _open('https://t.me/Intizom_AI'),
                        ),
                        SettingTile(
                          icon: LucideIcons.atSign,
                          title: 'Instagram',
                          subtitle: '@intizomai.uz',
                          onTap: () => _open('https://www.instagram.com/intizomai.uz'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GroupCard(
                      children: [
                        SettingTile(icon: LucideIcons.logOut, title: 'Hisobdan chiqish', danger: true, onTap: _logout),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'IntizomAI · ID ${p.telegramId}',
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(color: scheme.outline, fontWeight: FontWeight.w400, fontFeatures: tabularFigures),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.sub, required this.isPremium});

  final Subscription? sub;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final premium = sub?.isPremium ?? isPremium;
    final until = parseYmd(sub?.premiumUntil);
    final days = sub?.daysLeft ?? 0;
    return AppCard(
      onTap: premium ? openPremiumInBot : () => showPremiumDialog(context, "Barcha imkoniyatlarni oching."),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(icon: LucideIcons.crown, tone: AppPalette.gold, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      premium ? 'Premium faol' : 'Bepul tarif',
                      style: AppType.bodyStrong,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      premium
                          ? [
                              if (sub?.planTitle != null) sub!.planTitle!,
                              '$days kun qoldi',
                              if (until != null) '${shortDate(until)} gacha',
                            ].join(' · ')
                          : "Cheklovsiz reja, murabbiy va do'stlar",
                      style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                premium ? 'Uzaytirish' : 'Ochish',
                style: AppType.label.copyWith(fontWeight: FontWeight.w600, color: scheme.tertiary),
              ),
            ],
          ),
          if (premium && days > 0) ...[
            const SizedBox(height: 14),
            AppProgressBar(value: (days / 30).clamp(0, 1).toDouble(), color: AppPalette.gold),
          ],
        ],
      ),
    );
  }
}

/// Profil rasmi: maxsus rasm (URL/base64) → Telegram rasmi (bot proksi) → bosh harf.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.url,
    required this.telegramId,
    required this.name,
    this.size = 36,
  });

  final String? url;
  final int telegramId;
  final String name;
  final double size;

  ImageProvider? _image() {
    final u = url;
    if (u != null && u.startsWith('data:')) {
      final comma = u.indexOf(',');
      if (comma > 0) {
        try {
          return MemoryImage(base64Decode(u.substring(comma + 1)));
        } catch (_) {}
      }
    }
    final abs = IntizomApi.absoluteUrl(u) ?? (telegramId > 0 ? IntizomApi.telegramAvatar(telegramId) : null);
    return abs == null ? null : NetworkImage(abs);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final image = _image();
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: scheme.primaryContainer,
        alignment: Alignment.center,
        child: image == null
            ? _initial(initial, scheme)
            : Image(
                image: image,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initial(initial, scheme),
              ),
      ),
    );
  }

  Widget _initial(String initial, ColorScheme scheme) => Text(
    initial,
    style: TextStyle(fontSize: size * .42, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
  );
}
