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

/// Profil va sozlamalar (Asosiy sahifadagi avatar yoki ⚙ tugmasidan ochiladi).
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.state,
    required this.onLogout,
    required this.onAppearanceChanged,
    required this.onLanguageChanged,
  });

  final AppState state;
  final VoidCallback onLogout;
  final ValueChanged<String> onAppearanceChanged;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppState get s => widget.state;

  Subscription? _sub;
  Checkin _checkin = const Checkin();

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
    try {
      final c = await s.api.checkin();
      if (mounted && c != null) setState(() => _checkin = c);
    } catch (_) {}
  }

  Future<void> _saveCheckin({String? mood, int? energy}) async {
    final prev = _checkin;
    setState(() => _checkin = Checkin(mood: mood ?? _checkin.mood, energy: energy ?? _checkin.energy));
    try {
      await s.api.saveCheckin(mood: mood, energy: energy);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkin = prev);
      showApiError(context, e);
    }
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
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      appBar: AppBar(title: const Text('Profil')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([s.refreshProfile(), s.refreshStats(), _load()]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 4, AppSpace.lg, 40),
          children: [
            // ── Shaxs ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _changePhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ProfileAvatar(url: p.avatar, telegramId: p.telegramId, name: p.fullName, size: 72),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(5),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.7, height: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (p.username?.isNotEmpty == true) ...[
                              Text('@${p.username}', style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant)),
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
            AppCard(
              padding: EdgeInsets.zero,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _HeroStat(value: '${st.level}', label: st.rankTitle),
                    VerticalDivider(width: 1, color: scheme.outlineVariant),
                    _HeroStat(value: '${st.streak}', label: 'seriya'),
                    VerticalDivider(width: 1, color: scheme.outlineVariant),
                    _HeroStat(value: '${st.longestStreak}', label: 'rekord'),
                    VerticalDivider(width: 1, color: scheme.outlineVariant),
                    _HeroStat(value: '${st.totalScore}', label: 'ball'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SubscriptionCard(sub: _sub, isPremium: st.isPremium),

            // ── Bugungi holat ──────────────────────
            const SectionBar(title: 'Bugungi holat'),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kayfiyat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final (emoji, icon, label) in _moods)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ChoiceChipBox(
                              selected: _checkin.mood == emoji,
                              onTap: () => _saveCheckin(mood: emoji),
                              child: Column(
                                children: [
                                  Icon(icon, size: 20),
                                  const SizedBox(height: 6),
                                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('Energiya', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      Text(
                        _checkin.energy == null ? 'Tanlanmagan' : '${_checkin.energy} / 5',
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var e = 1; e <= 5; e++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              tapFeedback();
                              _saveCheckin(energy: e);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                height: 14.0 + e * 6,
                                decoration: BoxDecoration(
                                  color: (_checkin.energy ?? 0) >= e ? scheme.primary : scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "AI murabbiy holatingizni hisobga olib maslahat beradi.",
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // ── Yutuqlar ───────────────────────────
            const SectionBar(title: 'Yutuqlar'),
            _Achievements(streak: st.streak, score: st.totalScore, goalsDone: s.goals.where((g) => g.completed).length),

            // ── Hisob ──────────────────────────────
            const SectionBar(title: 'Hisob'),
            GroupCard(
              children: [
                SettingTile(icon: LucideIcons.userRound, title: 'Ism', subtitle: p.fullName, onTap: _editName),
                SettingTile(icon: LucideIcons.camera, title: 'Profil rasmi', subtitle: 'Galereya yoki kamera', onTap: _changePhoto),
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

            // ── Aloqa ──────────────────────────────
            const SectionBar(title: 'Yordam'),
            GroupCard(
              children: [
                SettingTile(
                  icon: LucideIcons.megaphone,
                  title: 'Telegram kanal',
                  subtitle: 'Yangiliklar va maslahatlar',
                  onTap: () => _open('https://t.me/Intizom_AI'),
                ),
                SettingTile(
                  icon: LucideIcons.messageCircle,
                  title: "Qo'llab-quvvatlash",
                  subtitle: 'Savol va takliflar',
                  onTap: () => _open('https://t.me/IntizomAI_Admin_bot'),
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
            const SizedBox(height: 24),
            const Center(child: BrandMark(size: 28)),
            const SizedBox(height: 8),
            Text(
              'IntizomAI · ID ${p.telegramId}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kayfiyat: serverga emoji yuboriladi (AI konteksti uchun), ilovada ikonka.
const _moods = [
  ('🔥', LucideIcons.flame, "A'lo"),
  ('💪', LucideIcons.zap, 'Kuchli'),
  ('😐', LucideIcons.meh, 'Oddiy'),
  ('😴', LucideIcons.moon, 'Charchoq'),
  ('😞', LucideIcons.frown, 'Past'),
];

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.5, fontFeatures: tabularFigures)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );
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
              AppIconTile.tinted(icon: premium ? LucideIcons.crown : LucideIcons.sparkles, accent: AppPalette.gold, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      premium ? 'Premium faol' : 'Bepul tarif',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      premium
                          ? [
                              if (sub?.planTitle != null) sub!.planTitle!,
                              '$days kun qoldi',
                              if (until != null) '${shortDate(until)} gacha',
                            ].join(' · ')
                          : "Cheklovsiz reja, AI va Do'stlar",
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                premium ? 'Uzaytirish' : 'Ochish',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.primary),
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

class _Achievements extends StatelessWidget {
  const _Achievements({required this.streak, required this.score, required this.goalsDone});

  final int streak;
  final int score;
  final int goalsDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = [
      (LucideIcons.flame, '3 kun', 'Seriya', streak >= 3, streak / 3),
      (LucideIcons.zap, '7 kun', 'Seriya', streak >= 7, streak / 7),
      (LucideIcons.gem, '30 kun', 'Seriya', streak >= 30, streak / 30),
      (LucideIcons.target, '10 ta', 'Maqsad', goalsDone >= 10, goalsDone / 10),
      (LucideIcons.trophy, '100', 'Ball', score >= 100, score / 100),
      (LucideIcons.crown, '500', 'Ball', score >= 500, score / 500),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1,
      children: [
        for (final (icon, value, label, unlocked, progress) in list)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: unlocked ? scheme.primary : scheme.outline),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                    color: unlocked ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
                Text(label, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                AppProgressBar(value: progress.clamp(0, 1).toDouble(), height: 3, color: unlocked ? AppPalette.success : null),
              ],
            ),
          ),
      ],
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
