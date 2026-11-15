import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Premium to'lovi faqat bot ichida — botning Premium oynasini ochadi.
Future<void> openPremiumInBot() async {
  try {
    await launchUrl(botUri('premium'), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Xatoni foydalanuvchiga ko'rsatadi. 402 bo'lsa Premium oynasi chiqadi.
void showApiError(BuildContext context, Object error) {
  if (!context.mounted) return;
  if (error is ApiException && error.isUnauthorized) return; // login'ga qaytadi
  if (error is ApiException && error.needsPremium) {
    showPremiumDialog(context, error.message);
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.toString())));
}

Future<void> showPremiumDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Text('💎', style: TextStyle(fontSize: 32)),
      title: const Text('Premium kerak'),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keyinroq'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppPalette.levelGold),
          onPressed: () {
            Navigator.pop(ctx);
            openPremiumInBot();
          },
          child: const Text('Bot orqali olish'),
        ),
      ],
    ),
  );
}

/// Yuklashda xato bo'lsa ko'rsatiladigan blok.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Qayta urinish')),
          ],
        ),
      ),
    );
  }
}
