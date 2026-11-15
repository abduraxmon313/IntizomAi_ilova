import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Telegram orqali kirish.
///
/// Tugma bosilganda bot ochiladi; foydalanuvchi botda "Tasdiqlash"ni bosadi,
/// ilova esa tasdiqni o'zi kutib oladi (token nusxalash shart emas).
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

  // Telegram'dan qaytganda darhol tekshiramiz.
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
    if (_startedAt != null && DateTime.now().difference(_startedAt!) > _giveUpAfter) {
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
      // 'pending' va 'expired' (bot hali so'rovni yozmagan bo'lishi mumkin) —
      // kutishda davom etamiz; 10 daqiqadan keyin to'xtaydi.
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎯', style: TextStyle(fontSize: 42)),
                  ),
                  const SizedBox(height: 28),
                  Text('IntizomAI', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('O\'z intizomingizni nazorat qiling'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        waiting
                            ? context.tr('Telegram\'ni qayta ochish')
                            : context.tr('Telegram orqali kirish'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2AABEE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (waiting)
                    _WaitingCard(scheme: scheme)
                  else
                    Text(
                      context.tr('Botda «Tasdiqlash» tugmasini bosasiz — ilova o\'zi ochiladi.'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.danger.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 13, color: AppPalette.danger),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'uz', label: Text("O'zbekcha")),
                      ButtonSegment(value: 'ru', label: Text('Русский')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {AppLocalizations.of(context).languageCode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => widget.onLanguageChanged?.call(s.first),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.tr('Botda «✅ Ilovaga kirishni tasdiqlash» tugmasini bosing, so\'ng shu yerga qayting.'),
              style: TextStyle(fontSize: 13, color: scheme.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
