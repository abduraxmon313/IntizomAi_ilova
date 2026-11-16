import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  Future<void> _start() async {
    final nonce = widget.authService.newNonce();
    setState(() {
      _nonce = nonce;
      _error = null;
      _startedAt = DateTime.now();
    });
    final opened = await widget.authService.openBot(nonce);
    if (!mounted) return;
    if (!opened) {
      setState(() {
        _nonce = null;
        _error = 'Telegram ochilmadi. Telegram ilovasi o\'rnatilganini tekshiring.';
      });
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(_pollEvery, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    final nonce = _nonce;
    if (nonce == null || _polling) return;
    if (_startedAt != null &&
        DateTime.now().difference(_startedAt!) > _giveUpAfter) {
      _stop('Vaqt tugadi. Qaytadan urinib ko\'ring.');
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
                            const Text('Intizom — natijaning boshlanishi.', style: AppType.display),
                            const SizedBox(height: AppSpace.md),
                            Text(
                              "Rejalar, odatlar va maqsadlar bitta joyda. AI murabbiy esa har kuni to'g'ri yo'nalish beradi.",
                              style: AppType.body.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                            ),
                            const SizedBox(height: AppSpace.xl),
                            const GroupCard(
                              indent: 50,
                              children: [
                                SettingTile(icon: LucideIcons.calendarCheck, title: 'Kunlik reja va vaqtida eslatma'),
                                SettingTile(icon: LucideIcons.repeat, title: 'Odatlar va uzluksiz seriya'),
                                SettingTile(icon: LucideIcons.sparkles, title: 'Shaxsiy AI murabbiy'),
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
                              const SizedBox(height: AppSpace.md),
                            ],
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _start,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        icon: const Icon(LucideIcons.send, size: 18),
                        label: Text(waiting ? "Telegram'ni qayta ochish" : 'Telegram orqali kirish'),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        "Hisobingiz IntizomAI botidagi bilan bir xil — rejalar va Premium saqlanadi.",
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
            step(Icon(LucideIcons.circleCheck, size: 18, color: scheme.tertiary), 'Telegram ochildi'),
            step(
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              "Botda «Ilovaga kirishni tasdiqlash» tugmasini bosing va shu yerga qayting.",
              active: true,
            ),
            step(Icon(LucideIcons.logIn, size: 17, color: scheme.outline), "Tasdiqlangach ilova o'zi kiradi."),
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
