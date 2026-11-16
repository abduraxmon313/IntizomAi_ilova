import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

const languageNames = {'ru': 'Русский', 'en': 'English', 'uz': 'O‘zbekcha'};

Future<void> showLanguagePicker(BuildContext context, ValueChanged<String> onSelected) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpace.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ctx.tr('Til'), style: AppType.title),
            const SizedBox(height: 16),
            LanguageChoices(
              selected: Localizations.localeOf(ctx).languageCode,
              onSelected: (code) {
                Navigator.pop(ctx);
                onSelected(code);
              },
            ),
          ],
        ),
      ),
    );

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key, required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.page),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 64)),
                const SizedBox(height: 28),
                const Text('IntizomAI', style: AppType.display),
                const SizedBox(height: 12),
                Text('Выберите язык\nChoose your language\nTilni tanlang',
                  style: AppType.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6)),
                const SizedBox(height: 28),
                LanguageChoices(onSelected: onSelected),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LanguageChoices extends StatelessWidget {
  const LanguageChoices({super.key, required this.onSelected, this.selected});
  final ValueChanged<String> onSelected;
  final String? selected;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final entry in languageNames.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            selected: selected == entry.key,
            child: OutlinedButton(
              key: ValueKey('language-${entry.key}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              onPressed: () => onSelected(entry.key),
              child: Row(
                children: [
                  SizedBox(width: 44, child: Text(entry.key.toUpperCase(), style: AppType.caption)),
                  Expanded(child: Text(entry.value, style: AppType.bodyStrong)),
                  Icon(selected == entry.key ? LucideIcons.check : LucideIcons.chevronRight, size: 18),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
