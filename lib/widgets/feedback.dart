import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';

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

/// Premium taklifi (Mini App'dagi paywall'ning ilova varianti).
Future<void> showPremiumDialog(BuildContext context, String message) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      Widget row(IconData icon, String title, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: scheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.15)),
                  Text(text, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 22),
            const Row(children: [BrandMark(size: 44)]),
            const SizedBox(height: 16),
            const Text(
              'IntizomAI Premium',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.8),
            ),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            row(LucideIcons.infinity, 'Cheklovsiz', "Reja, odat, maqsad va AI Coach — chegarasiz"),
            row(LucideIcons.chartColumn, 'Chuqur statistika', "Batafsil tahlil va reyting"),
            row(LucideIcons.users, "Do'stlar va jamoa", "Guruhlar va Telegram hisobotlari"),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                Navigator.pop(ctx);
                openPremiumInBot();
              },
              child: const Text('Tarifni tanlash'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
              child: const Text('Keyinroq'),
            ),
            Text(
              "To'lov IntizomAI Telegram boti orqali amalga oshiriladi.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    },
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: scheme.surfaceContainerLow, shape: BoxShape.circle),
              child: Icon(LucideIcons.cloudOff, size: 22, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            const Text("Ma'lumot yuklanmadi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.rotateCcw, size: 16),
              label: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }
}
