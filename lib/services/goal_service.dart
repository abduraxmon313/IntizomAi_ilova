import '../models/goal.dart';
import 'api_client.dart';

/// Maqsad boshqaruvi — Railway API orqali.
class GoalService {
  GoalService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Barcha maqsadlarni olish.
  Future<List<Goal>> getAll() async {
    final res = await _api.get('/goals');
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
    final list = res.data as List;
    return list.map((e) => Goal.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Yangi maqsad yaratish.
  Future<Goal> create(Map<String, dynamic> data) async {
    final res = await _api.post('/goals', body: data);
    if (!res.isOk) throw ApiException(res.error ?? 'Yaratishda xato', statusCode: res.statusCode);
    return Goal.fromJson(res.data as Map<String, dynamic>);
  }

  /// Maqsadni bajarilgan/bajarilmagan deb belgilash.
  Future<Goal> toggleCompleted(int goalId) async {
    final res = await _api.post('/goals/$goalId/toggle');
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
    return Goal.fromJson(res.data as Map<String, dynamic>);
  }

  /// Maqsadni o'chirish.
  Future<void> delete(int goalId) async {
    final res = await _api.delete('/goals/$goalId');
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
  }
}
