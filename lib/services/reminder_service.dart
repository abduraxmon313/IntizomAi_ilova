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
import 'device_settings.dart';
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

  // Telefon 2 hafta oldinga rejalashtiradi — ilova uzoq ochilmasa ham eslatadi.
  static const _planDaysAhead = 14;
  static const _habitIdBase = 100000000;
  static const _planIdBase = 1000000000;

  // iOS bir vaqtda ko'pi bilan 64 ta kutilayotgan bildirishnoma saqlaydi;
  // ortig'ini jimgina tashlab yuboradi. Shuning uchun byudjet qo'yamiz.
  static const _iosBudget = 60;

  static const _brandColor = Color(0xFF2563EB);

  static const _doneAction = 'done';
  static const _iosCategory = 'intizom_reminder';
  static const _enabledKey = 'intizom_ai.reminders.enabled.v1';
  static const _doneAtKey = 'intizom_ai.reminders.done_at.v1';
  // v2: sozlash sahifasiga batareya/Autostart qadamlari qo'shildi — mavjud
  // foydalanuvchilarga ham bir marta qayta ko'rsatiladi (sozlama to'liq bo'lmasa).
  static const _promptedKey = 'intizom_ai.reminders.prompted.v2';
  static const _testId = 2100000001;
  // Internet yo'q bo'lsa "Bajarildi" shu yerda navbatga qo'yiladi (keyin yuboriladi).
  static const _pendingKey = 'intizom_ai.reminders.pending_done.v1';

  final _plugin = FlutterLocalNotificationsPlugin();
  late final tz.Location _zone;
  bool _ready = false;
  bool _syncing = false;
  AndroidScheduleMode _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
  bool? _syncedExact; // oxirgi sync qaysi rejimda rejalashtirgan (null — hali sync bo'lmagan)
  int _seenDoneAt = 0;
  int _scheduled = 0; // joriy sync'da rejalashtirilgan bildirishnomalar soni (budjet uchun)

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

  /// Eslatmalar ilova yopiq bo'lsa ham o'z vaqtida kelishi uchun hammasi
  /// sozlanganmi: ruxsat + aniq vaqt + (Android) batareya cheklovisiz.
  Future<bool> _hasFullAccess() async {
    if (!await hasPermission()) return false;
    if (!await canScheduleExact()) return false;
    return DeviceSettings.isIgnoringBatteryOptimizations();
  }

  /// Android 12+: "Signallar va eslatmalar" (aniq vaqt) ruxsati. Usiz tizim
  /// eslatmani telefon uxlayotganda kechiktiradi. iOS'da har doim true.
  Future<bool> canScheduleExact() async {
    await init();
    if (!_ready) return true;
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  /// Aniq vaqt ruxsati sahifasini ochadi; qaytgach natijani beradi.
  Future<bool> requestExact() async {
    await init();
    final android = _android;
    if (!_ready || android == null) return true;
    if (await android.canScheduleExactNotifications() ?? true) return true;
    await android.requestExactAlarmsPermission();
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Ruxsat holati oxirgi sync'dan beri o'zgarganmi (masalan foydalanuvchi
  /// sozlamalarda aniq vaqtni yoqib qaytdi) — unda qayta rejalashtirish kerak.
  Future<bool> scheduleModeStale() async {
    final synced = _syncedExact;
    if (synced == null) return false;
    return (await canScheduleExact()) != synced;
  }

  /// Sinov eslatmasi: [delay]dan keyin keladi. Ilovani yopib (yoki telefonni
  /// o'chirib-yoqib) haqiqatan kelishini tekshirish uchun.
  Future<bool> scheduleTest(AppLocalizations t, Duration delay) async {
    await init();
    if (!_ready || !await hasPermission()) return false;
    final exact = await canScheduleExact();
    final at = tz.TZDateTime.now(_zone).add(delay);
    final body = t.text("Eslatmalar ishlayapti. Reja va odatlaringiz ham shu tarzda o'z vaqtida keladi.");
    await _plugin.zonedSchedule(
      id: _testId,
      scheduledDate: at,
      notificationDetails: _details(t, body: body),
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      title: t.text('Sinov eslatmasi'),
      body: body,
      payload: 'test:0',
    );
    return true;
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
    // Navbatdagi oflayn "Bajarildi"larni ham tozalaymiz (hisob almashishi mumkin).
    try {
      await (await SharedPreferences.getInstance()).remove(_pendingKey);
    } catch (_) {}
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
  /// Internet yo'q bo'lsa — navbatga qo'yiladi va keyingi sinxronda yuboriladi.
  static Future<void> completeFromNotification(NotificationResponse response) async {
    if (response.actionId != _doneAction) return;
    final payload = response.payload ?? '';
    final parts = payload.split(':');
    final id = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (id == null) return;
    final api = IntizomApi(client: ApiClient());
    final result = await _applyDone(api, parts[0], id);
    if (result == 'ok') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_doneAtKey, DateTime.now().millisecondsSinceEpoch);
      instance.completions.value++;
    } else if (result == 'retry') {
      await _enqueuePending(payload); // internet yo'q — keyinroq yuboriladi
    }
  }

  /// 'ok' — saqlandi; 'terminal' — qayta urinishning keragi yo'q (404/409/401);
  /// 'retry' — tarmoq xatosi, keyinroq qayta urinish kerak.
  static Future<String> _applyDone(IntizomApi api, String kind, int id) async {
    try {
      switch (kind) {
        case 'plan':
          await api.setPlanStatus(id, 'done');
          return 'ok';
        case 'habit':
          await api.toggleHabit(id, done: true);
          return 'ok';
        default:
          return 'terminal';
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 409 || e.statusCode == 401) return 'terminal';
      return 'retry';
    } catch (_) {
      return 'retry';
    }
  }

  static Future<void> _enqueuePending(String payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final list = prefs.getStringList(_pendingKey) ?? <String>[];
      if (!list.contains(payload)) {
        list.add(payload);
        await prefs.setStringList(_pendingKey, list);
      }
    } catch (_) {}
  }

  /// Oflaynda navbatga tushgan "Bajarildi"larni serverga yuboradi.
  Future<void> _flushPendingDone(IntizomApi api) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final list = prefs.getStringList(_pendingKey) ?? <String>[];
      if (list.isEmpty) return;
      final remaining = <String>[];
      var applied = false;
      for (final payload in list) {
        final parts = payload.split(':');
        final id = parts.length == 2 ? int.tryParse(parts[1]) : null;
        if (id == null) continue;
        final res = await _applyDone(api, parts[0], id);
        if (res == 'retry') {
          remaining.add(payload); // internet hali yo'q — navbatda qoldiramiz
        } else if (res == 'ok') {
          applied = true;
        }
      }
      await prefs.setStringList(_pendingKey, remaining);
      if (applied) {
        await prefs.setInt(_doneAtKey, DateTime.now().millisecondsSinceEpoch);
        completions.value++;
      }
    } catch (_) {}
  }

  /// Serverdagi odat va rejalardan telefon eslatmalarini qayta tuzadi.
  /// Internet yo'q bo'lsa, avval rejalashtirilganlari o'zgarishsiz qoladi.
  Future<void> sync({required IntizomApi api, required List<Habit> habits, required Locale locale}) async {
    if (!_supported) return;
    if (_syncing) {
      // Sync davomida kelgan so'rovni tashlab yubormaymiz — oxirgisini keyin bajaramiz.
      _again = () => sync(api: api, habits: habits, locale: locale);
      return;
    }
    _syncing = true;
    try {
      await init();
      if (!await isEnabled()) {
        await _cancelPendingExceptTest();
        return;
      }
      // Internet bor bo'lsa — oflaynda navbatga tushgan "Bajarildi"larni yuboramiz.
      await _flushPendingDone(api);

      final exact = await canScheduleExact();
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
      await _cancelPendingExceptTest();
      _syncedExact = exact;

      _scheduled = 0;
      final budget = defaultTargetPlatform == TargetPlatform.iOS ? _iosBudget : 480;

      // Odatlar — takrorlanadigan va muhim; avval ularni rejalashtiramiz.
      for (final h in habits) {
        if (_scheduled >= budget) break;
        await _scheduleHabit(h, t, budget);
      }
      // Rejalar — eng yaqin vaqt birinchi (iOS 64 limiti to'lsa, uzoqlari tushib qoladi).
      final pending = plans.where((p) => p.status == 'pending').toList()
        ..sort((a, b) => '${a.planDate} ${a.scheduledTime ?? '99:99'}'.compareTo('${b.planDate} ${b.scheduledTime ?? '99:99'}'));
      for (final p in pending) {
        if (_scheduled >= budget) break;
        await _schedulePlan(p, now, t);
      }
    } catch (e) {
      debugPrint('Eslatmalarni rejalashtirib bo\'lmadi: $e');
    } finally {
      _syncing = false;
      final again = _again;
      _again = null;
      if (again != null) await again();
    }
  }

  Future<void> Function()? _again;

  /// Barcha kutilayotgan eslatmalarni bekor qiladi, faqat sinov eslatmasi qoladi
  /// (foydalanuvchi uni kutayotgan bo'lishi mumkin).
  Future<void> _cancelPendingExceptTest() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final r in pending) {
      if (r.id != _testId) await _plugin.cancel(id: r.id);
    }
  }

  NotificationDetails _details(AppLocalizations t, {required String body, String? subText}) => NotificationDetails(
        android: AndroidNotificationDetails(
          'intizom_reminders',
          t.text('Eslatmalar'),
          channelDescription: t.text('Reja va odatlar vaqtida eslatadi'),
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          color: _brandColor,
          subText: subText,
          // Uzun matn to'liq ko'rinishi uchun (yoyilganda).
          styleInformation: BigTextStyleInformation(body),
          actions: [AndroidNotificationAction(_doneAction, t.text('Bajarildi'))],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: _iosCategory, subtitle: subText),
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

  Future<void> _scheduleHabit(Habit h, AppLocalizations t, int budget) async {
    final time = _parseTime(h.reminderTime);
    if (time == null || h.finished) return;
    final (hour, minute) = time;
    final title = '${h.icon} ${h.title}';
    final body = h.streak > 1
        ? t.text("{v0} kunlik seriya — bugun ham davom eting.", {'v0': h.streak})
        : t.text('Odatni bajarish vaqti keldi — belgilash uchun bosing.');
    final details = _details(t, body: body);
    final slot = (h.id % 10000000) * 8;
    if (h.frequency == 'weekly' && h.weekdays.isNotEmpty) {
      for (final wd in h.weekdays.toSet()) {
        if (wd < 0 || wd > 6) continue;
        if (_scheduled >= budget) return;
        await _plugin.zonedSchedule(
          id: _habitIdBase + slot + wd,
          scheduledDate: _nextAt(hour, minute, weekday: wd + 1),
          notificationDetails: details,
          androidScheduleMode: _scheduleMode,
          title: title,
          body: body,
          payload: 'habit:${h.id}',
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        _scheduled++;
      }
      return;
    }
    if (_scheduled >= budget) return;
    await _plugin.zonedSchedule(
      id: _habitIdBase + slot + 7,
      scheduledDate: _nextAt(hour, minute),
      notificationDetails: details,
      androidScheduleMode: _scheduleMode,
      title: title,
      body: body,
      payload: 'habit:${h.id}',
      matchDateTimeComponents: DateTimeComponents.time,
    );
    _scheduled++;
  }

  Future<void> _schedulePlan(Plan p, tz.TZDateTime now, AppLocalizations t) async {
    if (p.status != 'pending') return;
    final time = _parseTime(p.scheduledTime);
    final date = DateTime.tryParse(p.planDate);
    if (time == null || date == null) return;
    final at = tz.TZDateTime(_zone, date.year, date.month, date.day, time.$1, time.$2);
    if (!at.isAfter(now)) return;
    final hasDesc = p.description?.trim().isNotEmpty == true;
    final body = hasDesc ? p.description!.trim() : t.text("Rejangiz vaqti keldi — bajarib, belgilab qo'ying.");
    final subText = '${p.scheduledTime} · +${p.scoreValue} ${t.text('ball')}';
    await _plugin.zonedSchedule(
      id: _planIdBase + p.id % 1000000000,
      scheduledDate: at,
      notificationDetails: _details(t, body: body, subText: subText),
      androidScheduleMode: _scheduleMode,
      title: p.title,
      body: body,
      payload: 'plan:${p.id}',
    );
    _scheduled++;
  }
}
