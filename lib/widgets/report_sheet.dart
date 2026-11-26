import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../services/intizom_api.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// Shikoyat natijasi: yuborildimi va foydalanuvchi bloklandimi.
class ReportResult {
  const ReportResult({required this.blocked});

  final bool blocked;
}

const _reasons = <(String, String)>[
  ('spam', "Spam yoki reklama"),
  ('abuse', "Haqorat, tahdid yoki ta'qib"),
  ('inappropriate', "Nomaqbul ism, rasm yoki matn"),
  ('other', "Boshqa sabab"),
];

/// Foydalanuvchi yoki guruh ustidan shikoyat (App Store Guideline 1.2).
///
/// `targetType`: `user` yoki `group`. Foydalanuvchi uchun "bloklash" ham taklif qilinadi.
/// Yuborilsa [ReportResult], bekor qilinsa null qaytadi.
Future<ReportResult?> showReportSheet(
  BuildContext context, {
  required IntizomApi api,
  required String targetType,
  required int targetId,
  required String targetName,
}) {
  return showModalBottomSheet<ReportResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _ReportSheet(api: api, targetType: targetType, targetId: targetId, targetName: targetName),
  ).then((r) {
    if (r != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              r.blocked
                  ? context.tr("Shikoyat yuborildi va foydalanuvchi bloklandi. 24 soat ichida ko'rib chiqamiz.")
                  : context.tr("Shikoyat yuborildi. 24 soat ichida ko'rib chiqamiz."),
            ),
          ),
        );
    }
    return r;
  });
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.api, required this.targetType, required this.targetId, required this.targetName});

  final IntizomApi api;
  final String targetType;
  final int targetId;
  final String targetName;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  String? _reason;
  bool _block = true;
  bool _busy = false;
  String? _error;

  bool get _isUser => widget.targetType == 'user';

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final blocked = await widget.api.report(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: reason,
        details: _details.text,
        block: _isUser && _block,
      );
      if (mounted) Navigator.pop(context, ReportResult(blocked: blocked));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SheetScaffold(
      title: _isUser ? context.tr("Foydalanuvchi ustidan shikoyat") : context.tr("Guruh ustidan shikoyat"),
      subtitle: widget.targetName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr("Sababni tanlang"), style: AppType.bodyStrong),
          const SizedBox(height: 6),
          for (final (key, label) in _reasons)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(context.tr(label), style: AppType.body),
              trailing: Icon(
                _reason == key ? LucideIcons.circleCheck : LucideIcons.circle,
                color: _reason == key ? scheme.primary : scheme.outline,
                size: 22,
              ),
              onTap: _busy ? null : () => setState(() => _reason = key),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _details,
            enabled: !_busy,
            maxLength: 500,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(hintText: context.tr("Qo'shimcha izoh (ixtiyoriy)")),
          ),
          if (_isUser)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _block,
              onChanged: _busy ? null : (v) => setState(() => _block = v),
              title: Text(context.tr("Bu foydalanuvchini bloklash"), style: AppType.body),
              subtitle: Text(context.tr("U sizga boshqa taklif yubora olmaydi")),
            ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: AppType.label.copyWith(color: scheme.error)),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _reason == null || _busy ? null : _send,
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.tr("Shikoyat yuborish")),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(context.tr('Bekor qilish')),
          ),
        ],
      ),
    );
  }
}
