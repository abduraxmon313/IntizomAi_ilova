import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Telegram orqali kirish — logo rasm bilan (emoji o'rniga).
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
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 56),
                      const BrandMark(size: 64),
                      const SizedBox(height: 28),
                      const Text(
                        'Intizom — natijaning\nboshlanishi.',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1.2, height: 1.12),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Rejalar, odatlar va maqsadlar bitta joyda. AI murabbiy esa har kuni to'g'ri yo'nalish beradi.",
                        style: TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurfaceVariant, letterSpacing: -.15),
                      ),
                      const SizedBox(height: 32),
                      const _Feature(icon: LucideIcons.calendarCheck, text: 'Kunlik reja va vaqtida eslatma'),
                      const _Feature(icon: LucideIcons.repeat, text: "Odatlar va uzluksiz seriya"),
                      const _Feature(icon: LucideIcons.sparkles, text: 'Shaxsiy AI murabbiy'),
                      const SizedBox(height: 40),
                      FilledButton.icon(
                        onPressed: _start,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                        icon: const Icon(LucideIcons.send, size: 18),
                        label: Text(waiting ? "Telegram'ni qayta ochish" : 'Telegram orqali kirish'),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: AppMotion.base,
                        child: waiting
                            ? _WaitingCard(key: const ValueKey('w'), scheme: scheme)
                            : Text(
                                key: const ValueKey('t'),
                                "Hisobingiz IntizomAI botidagi bilan bir xil — rejalar va Premium saqlanadi.",
                                style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
                              ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.circleAlert, size: 17, color: scheme.onErrorContainer),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_error!, style: TextStyle(fontSize: 13.5, color: scheme.onErrorContainer))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: scheme.tertiary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -.15))),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({super.key, required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Botda «Ilovaga kirishni tasdiqlash» tugmasini bosing va shu yerga qayting.",
              style: TextStyle(fontSize: 13.5, color: scheme.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
