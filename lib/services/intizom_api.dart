import '../config/app_config.dart';
import '../models/extras.dart';
import '../models/friends.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../models/stats.dart';
import 'api_client.dart';

/// Ilova backend'i endpointlari (/api/v1/*, IntizomAi_ilova_database). Premium
/// cheklovlari, ball/seriya hisob-kitobi va vaqt qoidalari server tomonda.
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
    return '$kApiBaseUrl$path';
  }

  // ── Profil, statistika, obuna ────────────────────────
  Future<Profile> profile() async => Profile.fromJson(_map(await _c.get('/profile')));

  /// Hisobni va barcha ma'lumotlarni serverdan butunlay o'chiradi.
  Future<void> deleteAccount() => _c.delete('/profile');

  Future<Profile> updateProfile({
    String? fullName,
    String? username,
    int? age,
    bool? notifications,
    bool? leaderboardVisible,
    String? customPhotoUrl,
    bool removeCustomPhoto = false,
  }) async => Profile.fromJson(
    _map(
      await _c.put(
        '/profile',
        body: {
          'full_name': ?fullName,
          'username': ?username,
          'age': ?age,
          'notifications_enabled': ?notifications,
          'leaderboard_visible': ?leaderboardVisible,
          'custom_photo_url': ?customPhotoUrl,
          if (removeCustomPhoto) 'remove_custom_photo': true,
        },
      ),
    ),
  );

  /// Birinchi kirishdan keyin: ism, yosh, username va (ixtiyoriy) taklif qilgan do'st.
  Future<Profile> completeOnboarding({
    required String fullName,
    required int age,
    required String username,
    String? referrerUsername,
  }) async => Profile.fromJson(
    _map(
      await _c.post(
        '/profile/onboarding',
        body: {
          'full_name': fullName,
          'age': age,
          'username': username,
          'referrer_username': ?referrerUsername,
        },
      ),
    ),
  );

  Future<UsernameCheck> checkUsername(String username) async =>
      UsernameCheck.fromJson(_map(await _c.get('/users/username-available', query: {'username': username})));

  /// Aniq username bo'yicha foydalanuvchi (taklif yuborishdan oldin ko'rsatish uchun).
  Future<UserCard> lookupUser(String username) async =>
      UserCard.fromJson(_map(await _c.get('/users/lookup', query: {'username': username})));

  Future<UserStats> stats() async => UserStats.fromJson(_map(await _c.get('/stats')));

  /// Admin e'lonlari (hammaga / tarif bo'yicha / shaxsan menga).
  Future<List<Announcement>> announcements() async {
    final r = _map(await _c.get('/announcements'));
    return _list(r['announcements']).map(Announcement.fromJson).toList();
  }

  /// E'lon ko'rildi (admin paneldagi hisob uchun). Xato bo'lsa jim o'tadi.
  Future<void> announcementSeen(int id) async {
    try {
      await _c.post('/announcements/$id/seen');
    } catch (_) {}
  }

  /// Oxirgi [days] kun bo'yicha kunma-kun faollik (bugun ham kiradi).
  Future<List<DayActivity>> activity(int days) async {
    final r = _map(await _c.get('/stats/activity', query: {'days': '$days'}));
    return _list(r['days']).map(DayActivity.fromJson).toList();
  }

  Future<Subscription> subscription({String? promoCode}) async => Subscription.fromJson(
    _map(await _c.get('/subscription', query: promoCode == null || promoCode.isEmpty ? null : {'promo_code': promoCode})),
  );

  Future<PaymentOrder> checkout({required String plan, required String provider, String? promoCode}) async =>
      PaymentOrder.fromJson(
        _map(
          await _c.post(
            '/payments/checkout',
            body: {'plan': plan, 'provider': provider, 'promo_code': ?promoCode},
          ),
        ),
      );

  Future<PaymentOrder> paymentStatus(String orderId) async =>
      PaymentOrder.fromJson(_map(await _c.get('/payments/$orderId')));

  /// Bepul Premium beruvchi promokod. Natija: qo'shilgan kunlar.
  Future<int> redeemPromo(String code) async =>
      (_map(await _c.post('/promo/redeem', body: {'code': code}))['days'] as int?) ?? 0;

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

  // ── Guruhlar ─────────────────────────────────────────
  Future<GroupList> groups() async => GroupList.fromJson(_map(await _c.get('/groups')));

  Future<void> createGroup(String name, String? description) =>
      _c.post('/groups', body: {'name': name, 'description': description});

  Future<GroupDetail> group(int id) async => GroupDetail.fromJson(_map(await _c.get('/groups/$id')));

  Future<void> updateGroup(int id, {required String name, String? description}) =>
      _c.patch('/groups/$id', body: {'name': name, 'description': description});

  Future<void> deleteGroup(int id) => _c.delete('/groups/$id');

  Future<void> leaveGroup(int id) => _c.post('/groups/$id/leave');

  Future<void> transferGroup(int id, int userId) => _c.post('/groups/$id/transfer', body: {'user_id': userId});

  Future<void> inviteToGroup(int groupId, String username) =>
      _c.post('/groups/$groupId/invites', body: {'username': username});

  Future<void> cancelInvite(int groupId, int inviteId) => _c.delete('/groups/$groupId/invites/$inviteId');

  Future<List<IncomingInvite>> invites() async =>
      _list(_map(await _c.get('/invites'))['invites']).map(IncomingInvite.fromJson).toList();

  Future<void> acceptInvite(int inviteId) => _c.post('/invites/$inviteId/accept');

  Future<void> declineInvite(int inviteId, {bool block = false}) =>
      _c.post('/invites/$inviteId/decline', body: {'block': block});

  Future<List<UserCard>> blockedUsers() async =>
      _list(_map(await _c.get('/blocks'))['users']).map(UserCard.fromJson).toList();

  Future<void> unblockUser(int userId) => _c.delete('/blocks/$userId');

  /// Shikoyat: `targetType` — `user` yoki `group`. Foydalanuvchi bloklangan bo'lsa true.
  Future<bool> report({
    required String targetType,
    required int targetId,
    required String reason,
    String? details,
    bool block = false,
  }) async {
    final r = _map(
      await _c.post(
        '/reports',
        body: {
          'target_type': targetType,
          'target_id': targetId,
          'reason': reason,
          if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
          'block': block,
        },
      ),
    );
    return r['blocked'] as bool? ?? false;
  }

  Future<MemberView> member(int groupId, int userId, DateTime day) async => MemberView.fromJson(
    _map(await _c.get('/groups/$groupId/members/$userId', query: {'date': ymd(day)})),
  );

  Future<Permissions> permissions(int groupId) async =>
      Permissions.fromJson(_map(await _c.get('/groups/$groupId/permissions')));

  Future<void> setPermission(int groupId, int granteeId, {required bool canManage}) =>
      _c.put('/groups/$groupId/permissions/$granteeId', body: {'can_manage': canManage});

  Future<void> removeMember(int groupId, int userId) => _c.delete('/groups/$groupId/members/$userId');

  Future<void> setMemberActive(int groupId, int userId, bool active) =>
      _c.put('/groups/$groupId/members/$userId/active', body: {'is_active': active});

  Future<void> createPlanForMember(
    int groupId,
    int userId, {
    required String title,
    String? description,
    String? scheduledTime,
    required String planDate,
  }) => _c.post(
    '/groups/$groupId/members/$userId/plans',
    body: {
      'title': title,
      'description': ?description,
      'scheduled_time': ?scheduledTime,
      'plan_date': planDate,
    },
  );

  Future<void> createHabitForMember(int groupId, int userId, HabitInput h) =>
      _c.post('/groups/$groupId/members/$userId/habits', body: _habitBody(h));
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
