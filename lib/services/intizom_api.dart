import '../config/app_config.dart';
import '../models/extras.dart';
import '../models/friends.dart';
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

  static Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);

  static List<Map<String, dynamic>> _list(dynamic v) =>
      (v as List).whereType<Map>().map(Map<String, dynamic>.from).toList();

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Serverdagi nisbiy rasm yo'lini to'liq URL'ga aylantiradi.
  static String? absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http') || path.startsWith('data:')) return path;
    final base = kApiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base$path';
  }

  /// Telegram profil rasmi (bot orqali proksi, autentifikatsiya talab qilmaydi).
  static String telegramAvatar(int telegramId) => absoluteUrl('/api/webapp/avatar/$telegramId')!;

  // ── Profil, statistika, obuna ────────────────────────
  Future<Profile> profile() async => Profile.fromJson(_map(await _c.get('/profile')));

  /// Hisobni va barcha ma'lumotlarni serverdan butunlay o'chiradi.
  Future<void> deleteAccount() => _c.delete('/profile');

  Future<Profile> updateProfile({
    String? fullName,
    bool? notifications,
    String? customPhotoUrl,
    bool removeCustomPhoto = false,
  }) async => Profile.fromJson(
    _map(
      await _c.put(
        '/profile',
        body: {
          'full_name': ?fullName,
          'notifications_enabled': ?notifications,
          'custom_photo_url': ?customPhotoUrl,
          if (removeCustomPhoto) 'remove_custom_photo': true,
        },
      ),
    ),
  );

  Future<UserStats> stats() async => UserStats.fromJson(_map(await _c.get('/stats')));

  Future<Subscription> subscription() async =>
      Subscription.fromJson(_map(await _c.get('/subscription')));

  Future<Leaderboard> leaderboard(String period) async =>
      Leaderboard.fromJson(_map(await _c.get('/leaderboard', query: {'period': period})));

  Future<Checkin?> checkin() async {
    final r = await _c.get('/checkin');
    return r is Map ? Checkin.fromJson(Map<String, dynamic>.from(r)) : null;
  }

  Future<void> saveCheckin({String? mood, int? energy}) =>
      _c.post('/checkin', body: {'mood': ?mood, 'energy': ?energy});

  // ── Rejalar ──────────────────────────────────────────
  Future<List<Plan>> plansBetween(DateTime from, DateTime to) async {
    final r = _map(await _c.get('/plans', query: {'date_from': ymd(from), 'date_to': ymd(to)}));
    return _list(r['plans']).map(Plan.fromJson).toList();
  }

  Future<List<Plan>> plansOn(DateTime day) => plansBetween(day, day);

  Future<Plan> createPlan({
    required String title,
    String? description,
    String? scheduledTime,
    required String planDate,
  }) async => Plan.fromJson(
    _map(
      await _c.post(
        '/plans',
        body: {
          'title': title,
          'description': ?description,
          'scheduled_time': ?scheduledTime,
          'plan_date': planDate,
        },
      ),
    ),
  );

  Future<Plan> updatePlan(int id, {String? title, String? description, String? scheduledTime}) async =>
      Plan.fromJson(
        _map(
          await _c.put(
            '/plans/$id',
            body: {
              'title': ?title,
              'description': ?description,
              'scheduled_time': ?scheduledTime,
            },
          ),
        ),
      );

  Future<Plan> setPlanStatus(int id, String status) async =>
      Plan.fromJson(_map(await _c.put('/plans/$id', body: {'status': status})));

  Future<void> deletePlan(int id) => _c.delete('/plans/$id');

  // ── Odatlar ──────────────────────────────────────────
  Future<List<Habit>> habits() async => _list(await _c.get('/habits')).map(Habit.fromJson).toList();

  Map<String, dynamic> _habitBody(HabitInput h) => {
    'title': h.title,
    'description': h.description,
    'icon': h.icon,
    'frequency': h.frequency,
    'weekdays': h.frequency == 'weekly' ? h.weekdays : null,
    'duration_type': h.durationType,
    'target_days': h.durationType == 'days' ? h.targetDays : null,
    'reminder_time': h.reminderTime,
  };

  Future<Habit> createHabit(HabitInput h) async =>
      Habit.fromJson(_map(await _c.post('/habits', body: _habitBody(h))));

  Future<Habit> updateHabit(int id, HabitInput h) async => Habit.fromJson(
    _map(
      await _c.put(
        '/habits/$id',
        body: {..._habitBody(h), if (h.reminderTime == null) 'clear_reminder': true},
      ),
    ),
  );

  /// [day] berilmasa — bugun. [done] berilmasa — teskarisiga almashtiradi.
  Future<Habit> toggleHabit(int id, {bool? done, DateTime? day}) async => Habit.fromJson(
    _map(
      await _c.post(
        '/habits/$id/toggle',
        body: {'done': ?done, if (day != null) 'date': ymd(day)},
      ),
    ),
  );

  Future<void> deleteHabit(int id) => _c.delete('/habits/$id');

  // ── Maqsadlar ────────────────────────────────────────
  Future<List<Goal>> goals() async => _list(await _c.get('/goals')).map(Goal.fromJson).toList();

  Future<Goal> createGoal({
    required String title,
    String? description,
    required String goalType,
    required String period,
  }) async => Goal.fromJson(
    _map(
      await _c.post(
        '/goals',
        body: {
          'title': title,
          'description': ?description,
          'goal_type': goalType,
          'period': period,
        },
      ),
    ),
  );

  Future<Goal> updateGoal(int id, {String? title, String? description, bool? completed}) async =>
      Goal.fromJson(
        _map(
          await _c.put(
            '/goals/$id',
            body: {'title': ?title, 'description': ?description, 'completed': ?completed},
          ),
        ),
      );

  Future<void> deleteGoal(int id) => _c.delete('/goals/$id');

  // ── AI Coach ─────────────────────────────────────────
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
      limit: r['limit'] as int? ?? -1,
    );
  }

  // ── Do'stlar ─────────────────────────────────────────
  Future<List<GroupSummary>> groups() async {
    final r = _map(await _c.get('/friends/groups'));
    return _list(r['groups']).map(GroupSummary.fromJson).toList();
  }

  Future<void> createGroup(String name, String? description) =>
      _c.post('/friends/groups', body: {'name': name, 'description': description});

  Future<GroupDetail> group(int id) async => GroupDetail.fromJson(_map(await _c.get('/friends/groups/$id')));

  Future<void> updateGroup(int id, {required String name, String? description}) =>
      _c.patch('/friends/groups/$id', body: {'name': name, 'description': description});

  Future<void> deleteGroup(int id) => _c.delete('/friends/groups/$id');

  Future<void> leaveGroup(int id) => _c.post('/friends/groups/$id/leave');

  Future<MemberView> member(int groupId, int userId, DateTime day) async => MemberView.fromJson(
    _map(await _c.get('/friends/groups/$groupId/members/$userId', query: {'date': ymd(day)})),
  );

  Future<Permissions> permissions(int groupId) async =>
      Permissions.fromJson(_map(await _c.get('/friends/groups/$groupId/permissions')));

  Future<void> setPermission(int groupId, int granteeId, {required bool canManage}) =>
      _c.put('/friends/groups/$groupId/permissions/$granteeId', body: {'can_manage': canManage});

  Future<void> removeMember(int groupId, int userId) =>
      _c.delete('/friends/groups/$groupId/members/$userId');

  Future<void> setMemberActive(int groupId, int userId, bool active) =>
      _c.put('/friends/groups/$groupId/members/$userId/active', body: {'is_active': active});

  Future<void> createPlanForMember(
    int groupId,
    int userId, {
    required String title,
    String? description,
    String? scheduledTime,
    required String planDate,
  }) => _c.post(
    '/friends/groups/$groupId/members/$userId/plans',
    body: {
      'title': title,
      'description': ?description,
      'scheduled_time': ?scheduledTime,
      'plan_date': planDate,
    },
  );

  Future<void> createHabitForMember(int groupId, int userId, HabitInput h) =>
      _c.post('/friends/groups/$groupId/members/$userId/habits', body: _habitBody(h));

  Future<DigestSettings> digestSettings(int groupId) async =>
      DigestSettings.fromJson(_map(await _c.get('/friends/groups/$groupId/telegram/settings')));

  Future<DigestSettings> updateDigest(int groupId, Map<String, dynamic> body) async =>
      DigestSettings.fromJson(_map(await _c.put('/friends/groups/$groupId/telegram/settings', body: body)));

  Future<List<TelegramChat>> digestCandidates(int groupId) async {
    final r = _map(await _c.get('/friends/groups/$groupId/telegram/candidates'));
    return _list(r['candidates']).map(TelegramChat.fromJson).toList();
  }

  Future<void> linkTelegram(int groupId, TelegramChat chat) => _c.post(
    '/friends/groups/$groupId/telegram/link',
    body: {'telegram_chat_id': chat.chatId, 'telegram_chat_title': chat.title},
  );

  Future<void> unlinkTelegram(int groupId) => _c.post('/friends/groups/$groupId/telegram/unlink');

  /// [kind]: 'plans' — kunlik reja, 'report' — kunlik hisobot. Natija: (ok, sabab).
  Future<(bool, String?)> testDigest(int groupId, String kind) async {
    final r = _map(await _c.post('/friends/groups/$groupId/telegram/$kind-test'));
    return (r['ok'] == true, r['reason'] as String?);
  }
}

/// Odat yaratish/tahrirlash formasi.
class HabitInput {
  const HabitInput({
    required this.title,
    this.description,
    this.icon = '🏃',
    this.frequency = 'daily',
    this.weekdays = const [],
    this.durationType = 'permanent',
    this.targetDays,
    this.reminderTime,
  });

  final String title;
  final String? description;
  final String icon;
  final String frequency;
  final List<int> weekdays;
  final String durationType;
  final int? targetDays;
  final String? reminderTime;
}

class ChatMessage {
  const ChatMessage(this.role, this.content);
  final String role; // user | assistant
  final String content;
}

class CoachReply {
  const CoachReply({required this.reply, this.remaining = -1, this.limit = -1});
  final String reply;

  /// Bugun qolgan bepul xabarlar; -1 = cheksiz (Premium).
  final int remaining;
  final int limit;
}
