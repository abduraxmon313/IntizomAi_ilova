import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../services/device_settings.dart';
import '../../services/reminder_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/reminder_setup.dart';
import '../../widgets/ui_kit.dart';

/// Kirishdan keyin, Bugun sahifasidan oldin: telefon bildirishnomalariga ruxsat.
class NotificationPermissionPage extends StatefulWidget {
  const NotificationPermissionPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<NotificationPermissionPage> createState() => _NotificationPermissionPageState();
}

class _NotificationPermissionPageState extends State<NotificationPermissionPage> {
  bool _busy = false;

  /// Ketma-ket: bildirishnoma → aniq vaqt → batareya cheklovi → Autostart.
  /// Shularning hammasi bo'lsa eslatma ilova yopiq bo'lsa ham, telefon
  /// o'chirib-yoqilsa ham o'z vaqtida keladi.
  Future<void> _finish({required bool allow}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final reminders = ReminderService.instance;
    // requestPermission() aniq vaqt ruxsatini ham so'raydi (Android 12+).
    if (allow && await reminders.requestPermission()) {
      if (DeviceSettings.isAndroid && !await DeviceSettings.isIgnoringBatteryOptimizations()) {
        final r = await DeviceSettings.requestIgnoreBatteryOptimizations();
        // Tizim oynasi ochildi — foydalanuvchi qaytguncha kutamiz.
        if (r == 'oem' || r == 'app') await _waitForResume();
      }
      final maker = await DeviceSettings.manufacturer();
      if (mounted && DeviceSettings.hasAutostart(maker)) {
        await showAutostartGuide(context, maker);
      }
    }
    await reminders.markPrompted();
    if (mounted) widget.onDone();
  }

  Future<void> _waitForResume() async {
    final done = Completer<void>();
    final listener = AppLifecycleListener(onResume: () {
      if (!done.isCompleted) done.complete();
    });
    await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
    listener.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpace.xl),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppIconTile(icon: LucideIcons.bellRing, tone: scheme.primary, size: 56),
                            ),
                            const SizedBox(height: AppSpace.xl),
                            Text(context.tr("Eslatmalarni yoqing"), style: AppType.display),
                            const SizedBox(height: AppSpace.md),
                            Text(
                              context.tr("Reja va odat vaqti kelganda telefoningizga bildirishnoma keladi — ekran qulflangan bo'lsa ham."),
                              style: AppType.body.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                            ),
                            const SizedBox(height: AppSpace.xl),
                            GroupCard(
                              indent: 50,
                              children: [
                                SettingTile(icon: LucideIcons.alarmClock, title: context.tr("Aynan belgilangan vaqtda")),
                                SettingTile(icon: LucideIcons.power, title: context.tr("Ilova yopiq bo'lsa va telefon o'chirib-yoqilsa ham")),
                                SettingTile(icon: LucideIcons.smartphone, title: context.tr("Qulflangan ekranda ham ko'rinadi")),
                                SettingTile(icon: LucideIcons.circleCheck, title: context.tr("Bildirishnomaning o'zidan «Bajarildi» deb belgilash")),
                              ],
                            ),
                            const SizedBox(height: AppSpace.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _finish(allow: true),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        icon: const Icon(LucideIcons.bell, size: 18),
                        label: Text(context.tr("Ruxsat berish")),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      TextButton(
                        onPressed: _busy ? null : () => _finish(allow: false),
                        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        child: Text(context.tr("Keyinroq")),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
