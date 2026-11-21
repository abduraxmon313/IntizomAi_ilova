import 'package:shared_preferences/shared_preferences.dart';

/// Yopilgan va "ko'rildi" deb yuborilgan e'lonlar (qurilmada).
/// Yopilgan e'lon qayta chiqmaydi; ko'rilgani serverga bir marta yuboriladi.
class AnnouncementStore {
  static const _dismissedKey = 'intizom_ai.announcements.dismissed.v1';
  static const _seenKey = 'intizom_ai.announcements.seen.v1';
  static const _keep = 200;

  Future<Set<int>> _read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(key) ?? const []).map(int.tryParse).whereType<int>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _add(String key, int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key) ?? <String>[];
      if (list.contains('$id')) return;
      list.add('$id');
      await prefs.setStringList(key, list.length > _keep ? list.sublist(list.length - _keep) : list);
    } catch (_) {}
  }

  Future<Set<int>> dismissed() => _read(_dismissedKey);
  Future<void> dismiss(int id) => _add(_dismissedKey, id);

  /// true — bu e'lon birinchi marta ko'rilyapti (serverga xabar berish kerak).
  Future<bool> markSeen(int id) async {
    final seen = await _read(_seenKey);
    if (seen.contains(id)) return false;
    await _add(_seenKey, id);
    return true;
  }
}
