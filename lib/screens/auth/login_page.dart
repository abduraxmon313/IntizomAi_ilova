import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_store.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';

/// Telegram orqali kirish sahifasi.
///
/// Oqim:
/// 1) Foydalanuvchi "Telegram orqali kirish" tugmasini bosadi
/// 2) Telegram ochiladi → IntizomAi bot → bot JWT token beradi
/// 3) Foydalanuvchi tokenni ilovaga nusxalab kiritadi
/// 4) Ilova token bilan API'ga ulanadi
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    this.onLanguageChanged,
  });

  final VoidCallback onLoginSuccess;
  final ValueChanged<String>? onLanguageChanged;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _tokenController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _showTokenInput = false;

  Future<void> _launchTelegramLogin() async {
    final uri = Uri.parse('$kBotUrl?start=app_login');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Telegram ochilgandan keyin token kiritish bo'limini ko'rsatamiz
      if (mounted) {
        setState(() => _showTokenInput = true);
      }
    } else {
      if (mounted) {
        setState(() => _error = 'Telegram topilmadi');
      }
    }
  }

  Future<void> _verifyToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Tokenni kiriting');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // Token'ni saqlash
      final authStore = AuthStore();
      await authStore.saveToken(token);

      // API bilan tekshirish
      final api = ApiClient(authStore: authStore);
      final res = await api.get('/user/profile');

      if (res.isOk) {
        // Muvaffaqiyat — profil olindi
        final data = res.data as Map<String, dynamic>;
        await authStore.saveUserId(data['id'] as int);
        await authStore.saveTelegramId(data['telegram_id'] as int);
        if (mounted) widget.onLoginSuccess();
      } else if (res.isUnauthorized) {
        await authStore.clear();
        if (mounted) setState(() => _error = 'Token noto\'g\'ri yoki muddati o\'tgan');
      } else {
        await authStore.clear();
        if (mounted) setState(() => _error = res.error ?? 'Server bilan bog\'lanib bo\'lmadi');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Tarmoq xatosi. Internetni tekshiring.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _tokenController.text = data.text!;
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),

                  // Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Center(
                      child: Text('🎯', style: TextStyle(fontSize: 48)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sarlavha
                  Text(
                    'IntizomAI',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('O\'z intizomingizni nazorat qiling'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // 1-qadam: Telegram'ga o'tish
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _launchTelegramLogin,
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        _showTokenInput
                            ? 'Telegram\'ni qayta ochish'
                            : context.tr('Telegram orqali kirish'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2AABEE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),

                  // 2-qadam: Token kiritish (Telegram ochilgandan keyin)
                  if (_showTokenInput) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.key_rounded,
                                size: 18,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Bot bergan tokenni kiriting',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Token input
                          TextField(
                            controller: _tokenController,
                            decoration: InputDecoration(
                              hintText: 'Token...',
                              suffixIcon: IconButton(
                                icon: Icon(Icons.paste_rounded, size: 20, color: scheme.primary),
                                onPressed: _pasteFromClipboard,
                                tooltip: 'Nusxadan joylashtirish',
                              ),
                            ),
                            maxLines: 3,
                            minLines: 1,
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 12),

                          // Xatolik
                          if (_error != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppPalette.danger.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppPalette.danger,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Kirish tugmasi
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _verifyToken,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Kirish'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (!_showTokenInput) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Bot sizga token beradi — uni ilovaga kiritasiz',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Til tanlash
                  _LanguageSelector(onChanged: widget.onLanguageChanged),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({this.onChanged});
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final current = AppLocalizations.of(context).languageCode;
    final scheme = Theme.of(context).colorScheme;

    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'uz', label: Text("O'zbekcha")),
        ButtonSegment(value: 'ru', label: Text('Русский')),
        ButtonSegment(value: 'en', label: Text('English')),
      ],
      selected: {current},
      onSelectionChanged: (sel) => onChanged?.call(sel.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}
