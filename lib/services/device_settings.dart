import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android tizim sozlamalari: batareya cheklovi, "Autostart" va boshqalar
/// (native tomoni: android/.../MainActivity.kt). iOS'da bularning keragi yo'q —
/// u yerda rejalashtirilgan eslatmalar ilova yopilsa ham, telefon qayta
/// yoqilsa ham tizim tomonidan saqlanadi.
class DeviceSettings {
  DeviceSettings._();

  static const _ch = MethodChannel('uz.intizomai/system');

  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String? _maker;

  /// Ishlab chiqaruvchi (kichik harflarda), masalan "xiaomi", "samsung".
  static Future<String> manufacturer() async {
    if (!isAndroid) return '';
    try {
      return _maker ??= (await _ch.invokeMethod<String>('manufacturer')) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Ilova batareya optimizatsiyasidan ozodmi (fonda cheklanmaganmi).
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!isAndroid) return true;
    try {
      return await _ch.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Tizim oynasini ochadi: "Ilova fonda doim ishlashiga ruxsat berilsinmi?"
  /// Natija: "granted" — allaqachon ozod, "oem" — tizim oynasi ochildi,
  /// "app" — ilova sozlamalari ochildi (zaxira), "none" — ochilmadi.
  static Future<String> requestIgnoreBatteryOptimizations() => _call('requestIgnoreBatteryOptimizations');

  /// Ishlab chiqaruvchining "Autostart" sahifasi. Natija: "oem" — maxsus sahifa,
  /// "app" — ilova sozlamalari (zaxira), "none" — ochilmadi.
  static Future<String> openAutostart() => _call('openAutostart');

  /// Xiaomi'ning o'z "Batareya tejash" sahifasi (Cheklovsiz tanlanadi).
  static Future<String> openOemBattery() => _call('openOemBattery');

  static Future<String> openAppSettings() => _call('openAppSettings');

  static Future<String> _call(String method) async {
    if (!isAndroid) return 'none';
    try {
      return await _ch.invokeMethod<String>(method) ?? 'none';
    } catch (_) {
      return 'none';
    }
  }

  static bool _any(String m, List<String> names) => names.any(m.contains);

  /// Bu telefonda alohida "Autostart"/fon ruxsati bormi. Bunday telefonlar
  /// (Xiaomi, Oppo, Vivo, Huawei, Tecno, Samsung...) qayta yoqilganda ilovaga
  /// xabar bermaydi — natijada eslatmalar tiklanmaydi.
  static bool hasAutostart(String m) => _any(m, const [
    'xiaomi', 'redmi', 'poco', 'huawei', 'honor', 'oppo', 'realme', 'oneplus',
    'vivo', 'iqoo', 'samsung', 'asus', 'tecno', 'infinix', 'itel', 'transsion',
  ]);

  static bool isXiaomi(String m) => _any(m, const ['xiaomi', 'redmi', 'poco']);
}
