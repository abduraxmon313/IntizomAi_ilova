import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import '../models/plan.dart';
import 'api_client.dart';
import 'intizom_api.dart';
import 'locale_store.dart';

/// Bildirishnomadagi "Bajarildi" tugmasi ilova yopiq bo'lganda shu yerda bajariladi.
@pragma('vm:entry-point')
Future<void> reminderActionInBackground(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  await ReminderService.completeFromNotification(response);
}

/// Telefonning o'zida rejalashtiriladigan eslatmalar.
/// Tizim ularni internet bo'lmasa ham, ilova yopiq bo'lsa ham ko'rsatadi.
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  static const _planDaysAhead = 7;
  static const _habitIdBase = 100000000;
  static const _planIdBase = 1000000000;

  static const _doneAction = 'done';
  static const _iosCategory = 'intizom_reminder';
  static const _enabledKey = 'intizom_ai.reminders.enabled.v1';
  static const _doneAtKey = 'intizom_ai.reminders.done_at.v1';
  static const _promptedKey = 'intizom_ai.reminders.prompted.v1';

  final _plugin = FlutterLocalNotificationsPlugin();
  late final tz.Location _zone;
  bool _ready = false;
  bool _syncing = false;
  AndroidScheduleMode _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
  int _seenDoneAt = 0;

  /// Ilova ochiq turganda bildirishnomadan "Bajarildi" bosilsa oshadi.
  final completions = ValueNotifier<int>(0);

  bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (_ready || !_supported) return;
    tzdata.initializeTimeZones();
    _zone = tz.getLocation('Asia/Tashkent');
    final t = AppLocalizations(Locale(await _savedLanguage()));
    await _plugin.initialize(
      settings: InitializationSettings(
        // Status-bar ikonkasi oq siluet bo'lishi shart (aks holda oq kvadrat chiqadi).
        android: const AndroidInitializationSettings('@drawable/ic_stat_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _iosCategory,
              actions: [DarwinNotificationAction.plain(_doneAction, t.text('Bajarildi'))],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: completeFromNotification,
      onDidReceiveBackgroundNotificationResponse: reminderActionInBackground,
    );
    _seenDoneAt = await _doneAt();
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  /// Bildirishnoma ruxsati va (Android) aniq vaqtda eslatish ruxsatini so'raydi.
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    final android = _android;
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      if (granted && !(await android.canScheduleExactNotifications() ?? true)) {
        await android.requestExactAlarmsPermission();
      }
      return granted;
    }
    return await _ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  Future<bool> hasPermission() async {
    await init();
    if (!_ready) return false;
    final android = _android;
    if (android != null) return await android.areNotificationsEnabled() ?? false;
    return (await _ios?.checkPermissions())?.isEnabled ?? false;
  }

  Future<bool> _hasFullAccess() async {
    if (!await hasPermission()) return false;
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  /// Ruxsat sahifasini ko'rsatish kerakmi: kirishdan so'ng har doim,
  /// aks holda faqat hali so'ralmagan bo'lsa (ruxsat to'liq berilmagan holda).
  Future<bool> needsPrompt({required bool afterLogin}) async {
    if (!_supported) return false;
    try {
      if (!afterLogin && ((await SharedPreferences.getInstance()).getBool(_promptedKey) ?? false)) return false;
      return !await _hasFullAccess();
    } catch (_) {
      return false;
    }
  }

  Future<void> markPrompted() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_promptedKey, true);
    } catch (_) {}
  }

  /// Profildagi "Eslatmalar" kaliti (faqat shu telefon uchun).
  Future<bool> isEnabled() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setEnabled(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, value);
    if (!value) await cancelAll();
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    await init();
    await _plugin.cancelAll();
  }

  /// Oxirgi tekshiruvdan beri bildirishnomadan "Bajarildi" bosilgan bo'lsa true.
  Future<bool> consumeCompletedFromNotification() async {
    if (!_supported) return false;
    final at = await _doneAt();
    if (at == _seenDoneAt) return false;
    _seenDoneAt = at;
    return true;
  }

  static Future<int> _doneAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getInt(_doneAtKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<String> _savedLanguage() async => await LocaleStore().load() ?? 'uz';

  /// "Bajarildi" tugmasi: reja yoki odatni serverda bajarilgan deb belgilaydi.
  static Future<void> completeFromNotification(NotificationResponse response) async {
    if (response.actionId != _doneAction) return;
    final parts = (response.payload ?? '').split(':');
    final id = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (id == null) return;
    final api = IntizomApi(client: ApiClient());
    try {
      switch (parts[0]) {
        case 'plan':
          await api.setPlanStatus(id, 'done');
        case 'habit':
          await api.toggleHabit(id, done: true);
        default:
          return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_doneAtKey, DateTime.now().millisecondsSinceEpoch);
      instance.completions.value++;
    } catch (e) {
      debugPrint('Bildirishnomadan belgilab bo\'lmadi: $e');
    }
  }

  /// Serverdagi odat va rejalardan telefon eslatmalarini qayta tuzadi.
  /// Internet yo'q bo'lsa, avval rejalashtirilganlari o'zgarishsiz qoladi.
  Future<void> sync({required IntizomApi api, required List<Habit> habits, required Locale locale}) async {
    if (!_supported || _syncing) return;
    _syncing = true;
    try {
      await init();
      if (!await isEnabled()) {
        await _plugin.cancelAllPendingNotifications();
        return;
      }
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      _scheduleMode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
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
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          actions: [AndroidNotificationAction(_doneAction, t.text('Bajarildi'))],
        ),
        iOS: const DarwinNotificationDetails(categoryIdentifier: _iosCategory),
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
          androidScheduleMode: _scheduleMode,
          title: title,
          body: body,
          payload: 'habit:${h.id}',
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return;
    }
    await _plugin.zonedSchedule(
      id: _habitIdBase + slot + 7,
      scheduledDate: _nextAt(hour, minute),
      notificationDetails: _details(t),
      androidScheduleMode: _scheduleMode,
      title: title,
      body: body,
      payload: 'habit:${h.id}',
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
      androidScheduleMode: _scheduleMode,
      title: p.title,
      body: t.text('Rejangiz vaqti keldi'),
      payload: 'plan:${p.id}',
    );
  }
}
