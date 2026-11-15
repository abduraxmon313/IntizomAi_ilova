import '../models/habit.dart';
import 'api_client.dart';

/// Odat boshqaruvi — Railway API orqali.
class HabitService {
  HabitService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Barcha odatlarni olish.
  Future<List<Habit>> getAll() async {
    final res = await _api.get('/habits');
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
    final list = res.data as List;
    return list.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Yangi odat yaratish.
  Future<Habit> create(Map<String, dynamic> data) async {
    final res = await _api.post('/habits', body: data);
    if (!res.isOk) throw ApiException(res.error ?? 'Yaratishda xato', statusCode: res.statusCode);
    return Habit.fromJson(res.data as Map<String, dynamic>);
  }

  /// Odatni bugungi kunda belgilash/bekor qilish.
  Future<Habit> toggleToday(int habitId) async {
    final res = await _api.post('/habits/$habitId/toggle');
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
    return Habit.fromJson(res.data as Map<String, dynamic>);
  }

  /// Odatni arxivlash.
  Future<void> archive(int habitId) async {
    final res = await _api.patch('/habits/$habitId', body: {'archived': true});
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
  }

  /// Odatni o'chirish.
  Future<void> delete(int habitId) async {
    final res = await _api.delete('/habits/$habitId');
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
  }
}
