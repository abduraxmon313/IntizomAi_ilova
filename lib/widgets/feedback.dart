import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

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
    isScrollControlled: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      Widget row(IconData icon, String title, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 19, color: scheme.tertiary)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.bodyStrong),
                  Text(text, style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
      );
      return SheetScaffold(
        title: context.tr("IntizomAI Premium"),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: AppType.body.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            row(LucideIcons.infinity, context.tr("Cheklovsiz"), context.tr("Reja, odat, maqsad va AI murabbiy — chegarasiz")),
            row(LucideIcons.chartColumn, context.tr("Chuqur tahlil"), context.tr("Batafsil statistika va umumiy reyting")),
            row(LucideIcons.users, context.tr("Do'stlar bilan"), context.tr("Guruhlar va Telegram hisobotlari")),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openPremiumInBot();
              },
              child:  Text(context.tr("Tarifni tanlash")),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr("To'lov IntizomAI Telegram boti orqali amalga oshiriladi."),
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
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
            Icon(LucideIcons.cloudOff, size: 30, color: scheme.outline),
            const SizedBox(height: 14),
             Text(context.tr("Ma'lumot yuklanmadi"), style: AppType.bodyStrong),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              child:  Text(context.tr("Qayta urinish")),
            ),
          ],
        ),
      ),
    );
  }
}
