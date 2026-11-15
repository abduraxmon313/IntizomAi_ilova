import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Telegram orqali kirish sahifasi.
///
/// Foydalanuvchi "Telegram orqali kirish" tugmasini bosadi →
/// Telegram ochiladi → IntizomAi bot'ga o'tadi → bot token beradi →
/// Deep link orqali ilovaga qaytadi va avtorizatsiya bo'ladi.
class LoginPage extends StatelessWidget {
  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    this.onLanguageChanged,
  });

  final VoidCallback onLoginSuccess;
  final ValueChanged<String>? onLanguageChanged;

  Future<void> _launchTelegramLogin(BuildContext context) async {
    // Bot'ga deep-link yuboramiz — bot /login_app komandasi orqali
    // token generatsiya qiladi va ilovaga qaytaradi.
    final uri = Uri.parse('$kBotUrl?start=app_login');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Telegram topilmadi'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Logo / Ikon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: Text(
                        '🎯',
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sarlavha
                  Text(
                    'IntizomAI',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
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

                  // Telegram login tugmasi
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchTelegramLogin(context),
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: Text(context.tr('Telegram orqali kirish')),
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
                  const SizedBox(height: 16),

                  // Tushuntirish
                  Text(
                    context.tr('Bot orqali avtorizatsiya qilinadi. To\'lov ham bot ichida.'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 3),

                  // Til tanlash
                  _LanguageSelector(onChanged: onLanguageChanged),
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
        ButtonSegment(value: 'uz', label: Text('O\'zbekcha')),
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
