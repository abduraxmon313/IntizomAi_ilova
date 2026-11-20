import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/store_policy.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'paywall.dart';
import 'ui_kit.dart';

/// Premium oynasini ochadi (ilova ichida sotib olish).
Future<void> openPremium(BuildContext context) => showPremiumDialog(context, '');

/// Sotuv o'chirilgan build uchun (HIDE_PURCHASES) neytral oyna.
Future<void> _showFeatureUnavailable(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SheetScaffold(
        title: context.tr("Imkoniyat mavjud emas"),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr("Bu imkoniyat hozircha hisobingizda faol emas."),
              style: AppType.body.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr("Tushunarli")),
            ),
          ],
        ),
      );
    },
  );
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

/// Premium taklifi: tariflar, to'lov usuli va promokod — ilova ichida.
Future<void> showPremiumDialog(BuildContext context, String message) {
  if (!StorePolicy.purchasesVisible) return _showFeatureUnavailable(context);
  return showPaywall(context, message: message.isEmpty ? null : message);
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
