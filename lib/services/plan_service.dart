import '../models/plan.dart';
import 'api_client.dart';

/// Reja (plan) boshqaruvi — Railway API orqali.
class PlanService {
  PlanService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Bugungi rejalarni olish.
  Future<List<Plan>> getToday() async {
    final res = await _api.get('/plans/today');
    if (!res.isOk) throw ApiException(res.error ?? 'Rejalarni yuklashda xato', statusCode: res.statusCode);
    final list = res.data as List;
    return list.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Ma'lum sanadagi rejalar.
  Future<List<Plan>> getByDate(String date) async {
    final res = await _api.get('/plans', query: {'date': date});
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
    final list = res.data as List;
    return list.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Yangi reja yaratish.
  Future<Plan> create({
    required String title,
    String? description,
    String? scheduledTime,
    required String planDate,
  }) async {
    final res = await _api.post('/plans', body: {
      'title': title,
      'description': description,
      'scheduled_time': scheduledTime,
      'plan_date': planDate,
    });
    if (!res.isOk) throw ApiException(res.error ?? 'Reja yaratishda xato', statusCode: res.statusCode);
    return Plan.fromJson(res.data as Map<String, dynamic>);
  }

  /// Reja statusini o'zgartirish (done/pending/failed).
  Future<Plan> setStatus(int planId, String status) async {
    final res = await _api.patch('/plans/$planId/status', body: {'status': status});
    if (!res.isOk) throw ApiException(res.error ?? 'Status o\'zgartishda xato', statusCode: res.statusCode);
    return Plan.fromJson(res.data as Map<String, dynamic>);
  }

  /// Rejani o'chirish.
  Future<void> delete(int planId) async {
    final res = await _api.delete('/plans/$planId');
    if (!res.isOk) throw ApiException(res.error ?? 'O\'chirishda xato', statusCode: res.statusCode);
  }

  /// Rejani ertaga ko'chirish.
  Future<Plan> moveToTomorrow(int planId) async {
    final res = await _api.post('/plans/$planId/move-tomorrow');
    if (!res.isOk) throw ApiException(res.error ?? 'Ko\'chirishda xato', statusCode: res.statusCode);
    return Plan.fromJson(res.data as Map<String, dynamic>);
  }

  /// AI orqali reja yaratish (matn yuborish).
  Future<List<Plan>> createFromAi(String text, String planDate) async {
    final res = await _api.post('/plans/ai', body: {
      'text': text,
      'plan_date': planDate,
    });
    if (!res.isOk) throw ApiException(res.error ?? 'AI xato', statusCode: res.statusCode);
    final list = res.data as List;
    return list.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
  }
}
