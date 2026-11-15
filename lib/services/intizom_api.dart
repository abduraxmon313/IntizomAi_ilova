import '../models/goal.dart';
import '../models/habit.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../models/stats.dart';
import 'api_client.dart';

/// Mini App bilan bir xil endpointlar (webapp/routes/*). Premium cheklovlari,
/// ball/streak hisob-kitobi va vaqt qoidalari server tomonda — bot bilan bir xil.
class IntizomApi {
  IntizomApi({ApiClient? client}) : _c = client ?? ApiClient();

  final ApiClient _c;

  static Map<String, dynamic> _map(dynamic v) =>
      Map<String, dynamic>.from(v as Map);

  static List<Map<String, dynamic>> _list(dynamic v) =>
      (v as List).whereType<Map>().map(Map<String, dynamic>.from).toList();

  // ── Profil va statistika ─────────────────────────────
  Future<Profile> profile() async => Profile.fromJson(_map(await _c.get('/profile')));

  Future<Profile> updateProfile({String? fullName, bool? notifications}) async =>
      Profile.fromJson(
        _map(
          await _c.put(
            '/profile',
            body: {
              'full_name': ?fullName,
              'notifications_enabled': ?notifications,
            },
          ),
        ),
      );

  Future<UserStats> stats() async => UserStats.fromJson(_map(await _c.get('/stats')));

  Future<DailyQuest> quest() async => DailyQuest.fromJson(_map(await _c.get('/quest')));

  /// Smart coach xabari (faqat Premium; aks holda null).
  Future<String?> coachMessage() async {
    try {
      final r = _map(await _c.get('/coach'));
      final icon = r['icon'] as String? ?? '';
      final text = r['text'] as String? ?? '';
      return text.isEmpty ? null : '$icon $text'.trim();
    } on ApiException catch (e) {
      if (e.needsPremium) return null;
      rethrow;
    }
  }

  // ── Rejalar ──────────────────────────────────────────
  Future<List<Plan>> todayPlans() async {
    final r = _map(await _c.get('/plans'));
    return _list(r['plans']).map(Plan.fromJson).toList();
  }

  Future<Plan> createPlan({
    required String title,
    String? scheduledTime,
    required String planDate,
  }) async => Plan.fromJson(
    _map(
      await _c.post(
        '/plans',
        body: {
          'title': title,
          'scheduled_time': ?scheduledTime,
          'plan_date': planDate,
        },
      ),
    ),
  );

  Future<Plan> setPlanStatus(int id, String status) async =>
      Plan.fromJson(_map(await _c.put('/plans/$id', body: {'status': status})));

  Future<void> deletePlan(int id) => _c.delete('/plans/$id');

  // ── Odatlar ──────────────────────────────────────────
  Future<List<Habit>> habits() async =>
      _list(await _c.get('/habits')).map(Habit.fromJson).toList();

  Future<Habit> createHabit({
    required String title,
    String? icon,
    String? reminderTime,
  }) async => Habit.fromJson(
    _map(
      await _c.post(
        '/habits',
        body: {
          'title': title,
          'icon': ?icon,
          'reminder_time': ?reminderTime,
          'frequency': 'daily',
        },
      ),
    ),
  );

  Future<Habit> toggleHabit(int id) async =>
      Habit.fromJson(_map(await _c.post('/habits/$id/toggle', body: {})));

  Future<void> deleteHabit(int id) => _c.delete('/habits/$id');

  // ── Maqsadlar ────────────────────────────────────────
  Future<List<Goal>> goals() async =>
      _list(await _c.get('/goals')).map(Goal.fromJson).toList();

  Future<Goal> createGoal({
    required String title,
    required String goalType,
    required String period,
  }) async => Goal.fromJson(
    _map(
      await _c.post(
        '/goals',
        body: {'title': title, 'goal_type': goalType, 'period': period},
      ),
    ),
  );

  Future<Goal> setGoalCompleted(int id, bool completed) async => Goal.fromJson(
    _map(await _c.put('/goals/$id', body: {'completed': completed})),
  );

  Future<void> deleteGoal(int id) => _c.delete('/goals/$id');

  // ── AI Coach ─────────────────────────────────────────
  /// [history] — butun suhbat (oxirgisi foydalanuvchi xabari).
  Future<CoachReply> chat(List<ChatMessage> history) async {
    final r = _map(
      await _c.post(
        '/ai/chat',
        body: {
          'messages': [
            for (final m in history) {'role': m.role, 'content': m.content},
          ],
        },
      ),
    );
    return CoachReply(
      reply: r['reply'] as String? ?? '',
      remaining: r['remaining'] as int? ?? -1,
    );
  }
}

class ChatMessage {
  const ChatMessage(this.role, this.content);
  final String role; // user | assistant
  final String content;
}

class CoachReply {
  const CoachReply({required this.reply, this.remaining = -1});
  final String reply;

  /// Bugun qolgan bepul xabarlar; -1 = cheksiz (Premium).
  final int remaining;
}
