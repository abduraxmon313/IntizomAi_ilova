import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../auth/language_page.dart';
import '../../config/app_config.dart';
import '../../config/store_policy.dart';
import '../../models/extras.dart';
import '../../services/ai_consent_store.dart';
import '../../services/intizom_api.dart';
import '../../services/reminder_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/reminder_setup.dart';
import '../../widgets/ui_kit.dart';

/// Profil va sozlamalar (Bugun sahifasidagi avatar ortida).
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
  bool _phoneReminders = false;
  bool _aiConsent = false;
  final _aiConsentStore = AiConsentStore();

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
    _load();
    _loadReminders();
    _aiConsentStore.load().then((v) {
      if (mounted) setState(() => _aiConsent = v);
    });
  }

  Future<void> _setAiConsent(bool v) async {
    await _aiConsentStore.save(v);
    if (mounted) setState(() => _aiConsent = v);
  }

  Future<void> _loadReminders() async {
    final reminders = ReminderService.instance;
    final on = await reminders.isEnabled() && await reminders.hasPermission();
    if (mounted) setState(() => _phoneReminders = on);
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
    await _open(Uri.https('t.me', '/share/url', {'url': link, 'text': context.tr('Birga intizomli bo‘laylik! IntizomAI bilan reja va odatlaringizni kuzating.')}).toString());
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: s.profile?.fullName ?? '');
    await showFormSheet<void>(
      context,
      title: context.tr("Ismni tahrirlash"),
      builder: (ctx, _) => TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration:  InputDecoration(hintText: context.tr("Ismingiz"), counterText: ''),
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
              title:  Text(context.tr("Galereyadan tanlash")),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title:  Text(context.tr("Suratga olish")),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (hasCustom)
              ListTile(
                leading: Icon(LucideIcons.trash2, color: Theme.of(ctx).colorScheme.error),
                title: Text(context.tr("Telegram rasmiga qaytish"), style: AppType.body.copyWith(color: Theme.of(ctx).colorScheme.error)),
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
        if (mounted) toast(context, context.tr("Rasm juda katta. Boshqasini tanlang."));
        return;
      }
      s.setProfile(await s.api.updateProfile(customPhotoUrl: dataUrl));
      if (mounted) toast(context, context.tr("Profil rasmi yangilandi"));
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _setPhoneReminders(bool v) async {
    final reminders = ReminderService.instance;
    if (v && !await reminders.requestPermission()) {
      if (mounted) toast(context, context.tr("Telefon sozlamalarida IntizomAI uchun bildirishnomalarga ruxsat bering"));
      return;
    }
    await reminders.setEnabled(v);
    if (!mounted) return;
    setState(() => _phoneReminders = v);
    if (v) await reminders.sync(api: s.api, habits: s.habits, locale: Localizations.localeOf(context));
  }

  Future<void> _logout() async {
    if (!await confirmAction(context, title: context.tr("Hisobdan chiqish"), message: context.tr("Qayta kirish uchun Telegram orqali tasdiqlaysiz."), confirmLabel: context.tr("Chiqish"))) {
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
               PageHeader(title: context.tr("Profil")),
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
                            label: context.tr("Profil rasmini o'zgartirish"),
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
                                    if (st.isPremium)  Pill(context.tr("Premium"), color: AppPalette.gold),
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
                     SectionBar(title: context.tr("Hisob")),
                    GroupCard(
                      indent: 50,
                      children: [
                        SettingTile(icon: LucideIcons.userRound, title: context.tr("Ism"), subtitle: p.fullName, onTap: _editName),
                        SettingTile(
                          icon: LucideIcons.gift,
                          title: context.tr("Do'stni taklif qilish"),
                          subtitle: p.referralCount > 0
                              ? context.tr("{v0} ta do'st qo'shildi", {'v0': p.referralCount})
                              : (StorePolicy.purchasesVisible
                                    ? context.tr("Har 5 faol do'st uchun 7 kun Premium")
                                    : context.tr("Do'stlaringizni ilovaga taklif qiling")),
                          onTap: _shareInvite,
                        ),
                      ],
                    ),

                    // ── Sozlamalar ─────────────────────────
                     SectionBar(title: context.tr("Sozlamalar")),
                    GroupCard(
                      indent: 50,
                      children: [
                        SettingTile(
                          icon: LucideIcons.languages,
                          title: context.tr('Til'),
                          subtitle: languageNames[Localizations.localeOf(context).languageCode],
                          onTap: () => showLanguagePicker(context, widget.onLanguageChanged),
                        ),
                        SettingTile(
                          icon: LucideIcons.moon,
                          title: context.tr("Tungi rejim"),
                          trailing: Switch(
                            value: dark,
                            onChanged: (v) => widget.onAppearanceChanged(v ? 'dark' : 'light'),
                          ),
                        ),
                        SettingTile(
                          icon: LucideIcons.bell,
                          title: context.tr("Eslatmalar"),
                          subtitle: context.tr("Reja va odat vaqtida telefonda bildirishnoma"),
                          trailing: Switch(value: _phoneReminders, onChanged: _setPhoneReminders),
                        ),
                        SettingTile(
                          icon: LucideIcons.sparkles,
                          title: context.tr("AI murabbiyga ruxsat"),
                          subtitle: context.tr("Xabarlar va rejalar javob uchun OpenAI'ga yuboriladi"),
                          trailing: Switch(value: _aiConsent, onChanged: _setAiConsent),
                        ),
                      ],
                    ),

                    // ── Eslatmalar ishonchliligi ───────────
                    if (_phoneReminders) ...[
                      SectionBar(title: context.tr("Eslatmalar o'z vaqtida kelishi uchun")),
                      const ReminderHealthCard(),
                    ],

                    // ── Yordam ─────────────────────────────
                     SectionBar(title: context.tr("Yordam va aloqa")),
                    GroupCard(
                      indent: 50,
                      children: [
                        SettingTile(
                          icon: LucideIcons.messageCircle,
                          title: context.tr("Qo'llab-quvvatlash"),
                          subtitle: context.tr("Savol va takliflar"),
                          onTap: () => _open('https://t.me/IntizomAI_Admin_bot'),
                        ),
                        SettingTile(
                          icon: LucideIcons.megaphone,
                          title: context.tr("Telegram kanal"),
                          subtitle: context.tr("Yangiliklar va maslahatlar"),
                          onTap: () => _open('https://t.me/Intizom_AI'),
                        ),
                        SettingTile(
                          icon: LucideIcons.atSign,
                          title: 'Instagram',
                          subtitle: '@intizomai.uz',
                          onTap: () => _open('https://www.instagram.com/intizomai.uz'),
                        ),
                        if (kApiBaseUrl.isNotEmpty)
                          SettingTile(
                            icon: LucideIcons.shield,
                            title: context.tr("Maxfiylik siyosati"),
                            onTap: () => _open('$kApiBaseUrl/privacy'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GroupCard(
                      children: [
                        SettingTile(icon: LucideIcons.logOut, title: context.tr("Hisobdan chiqish"), danger: true, onTap: _logout),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'IntizomAI · ID ${p.telegramId}',
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400, fontFeatures: tabularFigures),
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
    final canPurchase = StorePolicy.purchasesVisible;
    return AppCard(
      // iOS'da (App Store 3.1.1) botga yo'naltiruvchi "uzaytirish" bo'lmaydi;
      // bepul foydalanuvchi uchun neytral oyna chiqadi.
      onTap: premium
          ? (canPurchase ? openPremiumInBot : null)
          : () => showPremiumDialog(context, context.tr("Barcha imkoniyatlarni oching.")),
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
                      premium ? context.tr("Premium faol") : context.tr("Bepul tarif"),
                      style: AppType.bodyStrong,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      premium
                          ? [
                              if (sub?.planTitle != null) sub!.planTitle!,
                              context.tr("{v0} kun qoldi", {'v0': days}),
                              if (until != null) context.tr("{v0} gacha", {'v0': shortDate(context, until).replaceAll('-', '\u2011')}),
                            ].join(' · ')
                          : context.tr("Cheklovsiz reja, murabbiy va do'stlar"),
                      style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (canPurchase) ...[
                const SizedBox(width: 8),
                Text(
                  premium ? context.tr("Uzaytirish") : context.tr("Ochish"),
                  style: AppType.label.copyWith(fontWeight: FontWeight.w600, color: scheme.tertiary),
                ),
              ],
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
    style: AppType.bodyStrong.copyWith(fontSize: size * .42, height: 1, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
  );
}
