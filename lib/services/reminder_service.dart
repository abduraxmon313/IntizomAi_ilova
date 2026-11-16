import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import '../models/plan.dart';
import 'intizom_api.dart';

/// Telefonning o'zida rejalashtiriladigan eslatmalar.
/// Tizim ularni internet bo'lmasa ham, ilova yopiq bo'lsa ham ko'rsatadi.
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  static const _planDaysAhead = 7;
  static const _habitIdBase = 100000000;
  static const _planIdBase = 1000000000;

  final _plugin = FlutterLocalNotificationsPlugin();
  late final tz.Location _zone;
  bool _ready = false;
  bool _syncing = false;

  bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (_ready || !_supported) return;
    tzdata.initializeTimeZones();
    _zone = tz.getLocation('Asia/Tashkent');
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  /// Serverdagi odat va rejalardan telefon eslatmalarini qayta tuzadi.
  /// Internet yo'q bo'lsa, avval rejalashtirilganlari o'zgarishsiz qoladi.
  Future<void> sync({required IntizomApi api, required List<Habit> habits, required Locale locale}) async {
    if (!_supported || _syncing) return;
    _syncing = true;
    try {
      await init();
      final now = tz.TZDateTime.now(_zone);
      final today = DateTime(now.year, now.month, now.day);
      final List<Plan> plans;
      try {
        plans = await api.plansBetween(today, today.add(const Duration(days: _planDaysAhead - 1)));
      } catch (_) {
        return;
      }
      final t = AppLocalizations(locale);
      await _plugin.cancelAllPendingNotifications();
      for (final h in habits) {
        await _scheduleHabit(h, t);
      }
      for (final p in plans) {
        await _schedulePlan(p, now, t);
      }
    } catch (e) {
      debugPrint('Eslatmalarni rejalashtirib bo\'lmadi: $e');
    } finally {
      _syncing = false;
    }
  }

  NotificationDetails _details(AppLocalizations t) => NotificationDetails(
        android: AndroidNotificationDetails(
          'intizom_reminders',
          t.text('Eslatmalar'),
          channelDescription: t.text('Reja va odatlar vaqtida eslatadi'),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  static (int, int)? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h > 23 || m > 59) return null;
    return (h, m);
  }

  tz.TZDateTime _nextAt(int hour, int minute, {int? weekday}) {
    final now = tz.TZDateTime.now(_zone);
    var at = tz.TZDateTime(_zone, now.year, now.month, now.day, hour, minute);
    while (!at.isAfter(now) || (weekday != null && at.weekday != weekday)) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  Future<void> _scheduleHabit(Habit h, AppLocalizations t) async {
    final time = _parseTime(h.reminderTime);
    if (time == null || h.finished) return;
    final (hour, minute) = time;
    final title = '${h.icon} ${h.title}';
    final body = t.text('Odatni bajarish vaqti keldi');
    final slot = (h.id % 10000000) * 8;
    if (h.frequency == 'weekly' && h.weekdays.isNotEmpty) {
      for (final wd in h.weekdays.toSet()) {
        if (wd < 0 || wd > 6) continue;
        await _plugin.zonedSchedule(
          id: _habitIdBase + slot + wd,
          scheduledDate: _nextAt(hour, minute, weekday: wd + 1),
          notificationDetails: _details(t),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return;
    }
    await _plugin.zonedSchedule(
      id: _habitIdBase + slot + 7,
      scheduledDate: _nextAt(hour, minute),
      notificationDetails: _details(t),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _schedulePlan(Plan p, tz.TZDateTime now, AppLocalizations t) async {
    if (p.status != 'pending') return;
    final time = _parseTime(p.scheduledTime);
    final date = DateTime.tryParse(p.planDate);
    if (time == null || date == null) return;
    final at = tz.TZDateTime(_zone, date.year, date.month, date.day, time.$1, time.$2);
    if (!at.isAfter(now)) return;
    await _plugin.zonedSchedule(
      id: _planIdBase + p.id % 1000000000,
      scheduledDate: at,
      notificationDetails: _details(t),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: p.title,
      body: t.text('Rejangiz vaqti keldi'),
    );
  }
}
