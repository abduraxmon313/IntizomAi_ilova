import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// GET javoblarini qurilmada saqlaydi — internet bo'lmaganda yoki server
/// vaqtincha javob bermaganda ilova oxirgi ma'lumotni ko'rsatadi.
///
/// Oddiy, kichik JSON javoblar uchun (profil, statistika, rejalar, odatlar).
/// Katta ikonlar/rasmlar bu yerda saqlanmaydi — ular URL orqali yuklanadi.
/// Hisobdan chiqilganda (logout/401) butunlay tozalanadi — boshqa hisobga
/// ma'lumot o'tmasligi uchun.
class ResponseCache {
  ResponseCache._();

  static final ResponseCache instance = ResponseCache._();

  static const _prefix = 'rc_v1:';
  static const _cap = 80;

  Future<void> write(String key, dynamic body) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final entry = jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'b': body});
      // Juda katta javoblarni saqlamaymiz (shared_preferences kichik ma'lumot uchun).
      if (entry.length > 256 * 1024) return;
      await sp.setString('$_prefix$key', entry);
      await _prune(sp);
    } catch (_) {}
  }

  Future<dynamic> read(String key) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('$_prefix$key');
      if (raw == null) return null;
      final m = jsonDecode(raw);
      return (m is Map) ? m['b'] : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final sp = await SharedPreferences.getInstance();
      for (final k in sp.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
        await sp.remove(k);
      }
    } catch (_) {}
  }

  /// Eng eski yozuvlarni o'chirib, yozuvlar sonini cheklab turadi.
  Future<void> _prune(SharedPreferences sp) async {
    final keys = sp.getKeys().where((k) => k.startsWith(_prefix)).toList();
    if (keys.length <= _cap) return;
    final byTime = <MapEntry<String, int>>[];
    for (final k in keys) {
      var ts = 0;
      final raw = sp.getString(k);
      if (raw != null) {
        try {
          ts = (jsonDecode(raw) as Map)['t'] as int? ?? 0;
        } catch (_) {}
      }
      byTime.add(MapEntry(k, ts));
    }
    byTime.sort((a, b) => a.value.compareTo(b.value));
    for (var i = 0; i < byTime.length - _cap; i++) {
      await sp.remove(byTime[i].key);
    }
  }
}
