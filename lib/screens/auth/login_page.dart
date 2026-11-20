import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import 'language_page.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/ui_kit.dart';

/// Telegram orqali kirish. Kirish mantig'i: bir martalik kod → bot → so'rov (poll).
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authService,
    required this.onLoginSuccess,
    this.onLanguageChanged,
  });

  final AuthService authService;
  final VoidCallback onLoginSuccess;
  final ValueChanged<String>? onLanguageChanged;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  static const _pollEvery = Duration(seconds: 2);
  static const _giveUpAfter = Duration(minutes: 10);

  String? _nonce;
  Timer? _timer;
  DateTime? _startedAt;
  bool _polling = false;
  bool _hasTelegramApp = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _nonce != null) _pollOnce();
  }

  /// Qayerda ochishni tanlaydi:
  /// - hech qanday Telegram ilovasi yo'q → Telegram Web;
  /// - faqat Telegram (muqobil klient aniqlanmadi) → to'g'ridan-to'g'ri Telegram;
  /// - muqobil klientlar bor (iOS) → tanlash oynasi.
  Future<void> _start() async {
    final apps = await widget.authService.telegramApps();
    if (!mounted) return;
    _hasTelegramApp = apps.anyApp;
    final TelegramTarget target;
    if (!apps.anyApp) {
      target = TelegramTarget.web;
    } else if (apps.otherApps.isEmpty) {
      target = TelegramTarget.telegram;
    } else {
      final picked = await _pickApp(apps);
      if (picked == null || !mounted) return;
      target = picked;
    }

    final nonce = widget.authService.newNonce();
    setState(() {
      _nonce = nonce;
      _error = null;
      _startedAt = DateTime.now();
    });
    if (!await _open(nonce, target)) return;
    _timer?.cancel();
    _timer = Timer.periodic(_pollEvery, (_) => _pollOnce());
  }

  /// Joriy kod bilan boshqa joyda qayta ochish (kutish paytida).
  Future<void> _reopen(TelegramTarget target) async {
    final nonce = _nonce;
    if (nonce != null) await _open(nonce, target);
  }

  Future<bool> _open(String nonce, TelegramTarget target) async {
    final opened = await widget.authService.openBot(nonce, target);
    if (!mounted) return false;
    if (!opened && _nonce == nonce) {
      _timer?.cancel();
      setState(() {
        _nonce = null;
        _error = context.tr("Telegram ochilmadi. Telegram ilovasi o'rnatilganini tekshiring.");
      });
    }
    return opened;
  }

  Future<TelegramTarget?> _pickApp(TelegramApps apps) => showModalBottomSheet<TelegramTarget>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.sm),
            child: Text(context.tr("Qaysi ilovada ochilsin?"), style: AppType.label.copyWith(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(LucideIcons.send),
            title: const Text('Telegram'),
            onTap: () => Navigator.pop(ctx, TelegramTarget.telegram),
          ),
          ListTile(
            leading: const Icon(LucideIcons.messageCircle),
            title: Text(apps.otherApps.join(', ')),
            subtitle: Text(context.tr("Telegram asosidagi boshqa ilova")),
            onTap: () => Navigator.pop(ctx, TelegramTarget.otherApp),
          ),
          ListTile(
            leading: const Icon(LucideIcons.globe),
            title: Text(context.tr("Brauzerda (Telegram Web)")),
            onTap: () => Navigator.pop(ctx, TelegramTarget.web),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  Future<void> _pollOnce() async {
    final nonce = _nonce;
    if (nonce == null || _polling) return;
    if (_startedAt != null &&
        DateTime.now().difference(_startedAt!) > _giveUpAfter) {
      _stop(context.tr("Vaqt tugadi. Qaytadan urinib ko'ring."));
      return;
    }
    _polling = true;
    try {
      final status = await widget.authService.poll(nonce);
      if (!mounted || _nonce != nonce) return;
      if (status == 'approved') {
        _timer?.cancel();
        widget.onLoginSuccess();
      }
    } on ApiException catch (e) {
      if (e.statusCode != 0 && e.statusCode != 429) _stop(e.message);
    } finally {
      _polling = false;
    }
  }

  void _stop(String message) {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _nonce = null;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final waiting = _nonce != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                if (widget.onLanguageChanged != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(LucideIcons.languages, size: 18),
                      label: Text(languageNames[Localizations.localeOf(context).languageCode] ?? context.tr("Til")),
                      onPressed: () => showLanguagePicker(context, widget.onLanguageChanged!),
                    ),
                  ),
                // ── Tanishtiruv (kichik ekranda aylantiriladi) ──
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpace.xl),
                            const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 56)),
                            const SizedBox(height: AppSpace.xl),
                             Text(context.tr("Intizom — natijaning boshlanishi."), style: AppType.display),
                            const SizedBox(height: AppSpace.md),
                            Text(
                              context.tr("Rejalar, odatlar va maqsadlar bitta joyda. AI murabbiy esa har kuni to'g'ri yo'nalish beradi."),
                              style: AppType.body.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                            ),
                            const SizedBox(height: AppSpace.xl),
                             GroupCard(
                              indent: 50,
                              children: [
                                SettingTile(icon: LucideIcons.calendarCheck, title: context.tr("Kunlik reja va vaqtida eslatma")),
                                SettingTile(icon: LucideIcons.repeat, title: context.tr("Odatlar va uzluksiz seriya")),
                                SettingTile(icon: LucideIcons.sparkles, title: context.tr("Shaxsiy AI murabbiy")),
                              ],
                            ),
                            const SizedBox(height: AppSpace.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Amal (bosh barmoq yetadigan joyda) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSize(
                        duration: AppMotion.base,
                        curve: AppMotion.curve,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null) ...[
                              _ErrorNote(message: _error!),
                              const SizedBox(height: AppSpace.md),
                            ],
                            if (waiting) ...[
                              const _WaitingCard(),
                              Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  // iOS'da Novagram kabi klientlarni alohida aniqlab bo'lmaydi —
                                  // ular uchun `tg://` orqali ochish.
                                  if (_hasTelegramApp && defaultTargetPlatform == TargetPlatform.iOS)
                                    TextButton(
                                      onPressed: () => _reopen(TelegramTarget.otherApp),
                                      child: Text(context.tr("Boshqa ilovada ochish")),
                                    ),
                                  TextButton(
                                    onPressed: () => _reopen(TelegramTarget.web),
                                    child: Text(context.tr("Brauzerda ochish")),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpace.sm),
                            ],
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _start,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        icon: const Icon(LucideIcons.send, size: 18),
                        label: Text(waiting ? context.tr("Telegram'ni qayta ochish") : context.tr("Telegram orqali kirish")),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        context.tr("Hisobingiz IntizomAI botidagi bilan bir xil — rejalar va Premium saqlanadi."),
                        textAlign: TextAlign.center,
                        style: AppType.caption.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kutish holati: uch qadam, joriysi — aylanuvchi belgi bilan.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget step(Widget lead, String text, {bool active = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 20, height: 20, child: Center(child: lead)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppType.label.copyWith(
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      liveRegion: true,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          children: [
            step(Icon(LucideIcons.circleCheck, size: 18, color: scheme.tertiary), context.tr("Telegram ochildi")),
            step(
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              context.tr("Botda «Ilovaga kirishni tasdiqlash» tugmasini bosing va shu yerga qayting."),
              active: true,
            ),
            step(Icon(LucideIcons.logIn, size: 17, color: scheme.outline), context.tr("Tasdiqlangach ilova o'zi kiradi.")),
          ],
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(LucideIcons.circleAlert, size: 17, color: scheme.onErrorContainer),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: AppType.label.copyWith(color: scheme.onErrorContainer, height: 1.4))),
          ],
        ),
      ),
    );
  }
}
