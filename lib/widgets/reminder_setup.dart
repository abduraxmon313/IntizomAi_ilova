import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/device_settings.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// "Autostart" yo'riqnomasi. Xiaomi/Oppo/Vivo/Tecno/Samsung kabi telefonlar
/// qayta yoqilganda ilovaga xabar bermaydi — usiz eslatmalar tiklanmaydi.
Future<void> showAutostartGuide(BuildContext context, String maker) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr("Yana bitta qadam")),
      content: Text(
        [
          ctx.tr("Telefon o'chirib-yoqilganda va ilova yopiq bo'lganda ham eslatmalar kelishi uchun IntizomAI uchun «Autostart»ni yoqing."),
          if (DeviceSettings.isXiaomi(maker)) ctx.tr("Keyin «Batareya tejash» bo'limida «Cheklovsiz»ni tanlang."),
        ].join('\n\n'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr("Keyinroq"))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr("Sozlamani ochish"))),
      ],
    ),
  );
  if (open != true || !context.mounted) return;
  await openAutostart(context);
}

Future<void> openAutostart(BuildContext context) async {
  final r = await DeviceSettings.openAutostart();
  if (r != 'oem' && context.mounted) {
    toast(context, context.tr("Ilova sozlamalarida «Autostart» yoki «Fonda ishlash»ni yoqing"));
  }
}

/// Sinov eslatmasi: ilovani yopib (yoki telefonni o'chirib-yoqib) haqiqatan
/// kelishini tekshirish uchun.
Future<void> showTestReminderSheet(BuildContext context) async {
  final minutes = await showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => SheetScaffold(
      title: ctx.tr("Sinov eslatmasi"),
      child: GroupCard(
        indent: 50,
        children: [
          SettingTile(
            icon: LucideIcons.timer,
            title: ctx.tr("1 daqiqadan keyin"),
            subtitle: ctx.tr("Ilovani to'liq yopib kuting"),
            onTap: () => Navigator.pop(ctx, 1),
          ),
          SettingTile(
            icon: LucideIcons.power,
            title: ctx.tr("3 daqiqadan keyin"),
            subtitle: ctx.tr("Telefonni o'chirib-yoqib tekshirish uchun"),
            onTap: () => Navigator.pop(ctx, 3),
          ),
        ],
      ),
    ),
  );
  if (minutes == null || !context.mounted) return;
  final t = AppLocalizations.of(context);
  final ok = await ReminderService.instance.scheduleTest(t, Duration(minutes: minutes));
  if (!context.mounted) return;
  toast(
    context,
    ok
        ? context.tr("Sinov eslatmasi {v0} daqiqadan keyin keladi. Endi ilovani yoping.", {'v0': minutes})
        : context.tr("Avval bildirishnomalarga ruxsat bering"),
  );
}

/// Eslatmalar ilova yopiq bo'lsa va telefon qayta yoqilganda ham o'z vaqtida
/// kelishi uchun kerakli sozlamalar holati. Har bir qator — holat va tuzatish.
/// Sozlamalardan qaytilganda holat qayta tekshiriladi.
class ReminderHealthCard extends StatefulWidget {
  const ReminderHealthCard({super.key});

  @override
  State<ReminderHealthCard> createState() => _ReminderHealthCardState();
}

class _ReminderHealthCardState extends State<ReminderHealthCard> with WidgetsBindingObserver {
  bool? _notif;
  bool _exact = true;
  bool _battery = true;
  String _maker = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final r = ReminderService.instance;
    final notif = await r.hasPermission();
    final exact = await r.canScheduleExact();
    final battery = await DeviceSettings.isIgnoringBatteryOptimizations();
    final maker = await DeviceSettings.manufacturer();
    if (!mounted) return;
    setState(() {
      _notif = notif;
      _exact = exact;
      _battery = battery;
      _maker = maker;
    });
  }

  Future<void> _fixNotif() async {
    final granted = await ReminderService.instance.requestPermission();
    if (!granted) {
      // Avval rad etilgan bo'lsa tizim oynasi qayta chiqmaydi — sozlamalarni ochamiz.
      if (DeviceSettings.isAndroid) {
        await DeviceSettings.openAppSettings();
      } else {
        try {
          await launchUrl(Uri.parse('app-settings:'));
        } catch (_) {}
      }
    }
    await _check();
  }

  Future<void> _fixExact() async {
    await ReminderService.instance.requestExact();
    await _check();
  }

  Future<void> _fixBattery() async {
    await DeviceSettings.requestIgnoreBatteryOptimizations();
    // Natija sozlamadan qaytilganda (resume) tekshiriladi.
  }

  @override
  Widget build(BuildContext context) {
    final notif = _notif;
    if (notif == null) return const SizedBox.shrink();
    final android = DeviceSettings.isAndroid;
    final scheme = Theme.of(context).colorScheme;

    Widget status(bool ok) => ok
        ? const Icon(LucideIcons.circleCheck, size: 20, color: AppPalette.success)
        : Text(context.tr("Yoqish"), style: AppType.label.copyWith(fontWeight: FontWeight.w600, color: scheme.tertiary));
    final chevron = Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline);

    return GroupCard(
      indent: 50,
      children: [
        SettingTile(
          icon: notif ? LucideIcons.bell : LucideIcons.bellOff,
          title: context.tr("Bildirishnomalarga ruxsat"),
          subtitle: notif ? context.tr("Berilgan") : context.tr("Berilmagan — eslatmalar ko'rinmaydi"),
          trailing: status(notif),
          onTap: notif ? null : _fixNotif,
        ),
        if (android)
          SettingTile(
            icon: LucideIcons.alarmClock,
            title: context.tr("Aniq vaqtda eslatish"),
            subtitle: _exact ? context.tr("Yoqilgan") : context.tr("O'chiq — eslatma kechikishi mumkin"),
            trailing: status(_exact),
            onTap: _exact ? null : _fixExact,
          ),
        if (android)
          SettingTile(
            icon: _battery ? LucideIcons.batteryFull : LucideIcons.batteryWarning,
            title: context.tr("Batareya cheklovi"),
            subtitle: _battery
                ? context.tr("Cheklanmagan")
                : context.tr("Cheklangan — ilova yopilsa eslatma kelmasligi mumkin"),
            trailing: status(_battery),
            onTap: _battery ? null : _fixBattery,
          ),
        if (android && DeviceSettings.hasAutostart(_maker))
          SettingTile(
            icon: LucideIcons.power,
            title: context.tr("Autostart (fon rejimi)"),
            subtitle: context.tr("Telefon qayta yoqilganda eslatmalar tiklanishi uchun yoqing"),
            trailing: chevron,
            onTap: () => openAutostart(context),
          ),
        if (android && DeviceSettings.isXiaomi(_maker))
          SettingTile(
            icon: LucideIcons.batteryCharging,
            title: context.tr("Batareya tejash (Xiaomi)"),
            subtitle: context.tr("«Cheklovsiz»ni tanlang"),
            trailing: chevron,
            onTap: () async {
              final r = await DeviceSettings.openOemBattery();
              if (r != 'oem' && context.mounted) {
                toast(context, context.tr("Ilova sozlamalari → Batareya → «Cheklovsiz»ni tanlang"));
              }
            },
          ),
        SettingTile(
          icon: LucideIcons.flaskConical,
          title: context.tr("Sinov eslatmasi"),
          subtitle: context.tr("Haqiqatan kelishini tekshiring"),
          trailing: chevron,
          onTap: () => showTestReminderSheet(context),
        ),
      ],
    );
  }
}
