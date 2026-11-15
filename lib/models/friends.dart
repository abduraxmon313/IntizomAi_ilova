/// Do'stlar (guruhlar) — server: webapp/routes/friends.py, bot/services/group_service.py.
class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    this.description,
    this.memberCount = 0,
    this.isOwner = false,
  });

  final int id;
  final String name;
  final String? description;
  final int memberCount;
  final bool isOwner;

  factory GroupSummary.fromJson(Map<String, dynamic> j) => GroupSummary(
    id: j['id'] as int,
    name: j['name'] as String? ?? '',
    description: j['description'] as String?,
    memberCount: j['member_count'] as int? ?? 0,
    isOwner: j['is_owner'] as bool? ?? false,
  );
}

class GroupDetail {
  const GroupDetail({
    required this.id,
    required this.name,
    this.description,
    required this.inviteCode,
    this.isOwner = false,
    this.members = const [],
  });

  final int id;
  final String name;
  final String? description;
  final String inviteCode;
  final bool isOwner;
  final List<GroupMember> members;

  factory GroupDetail.fromJson(Map<String, dynamic> j) => GroupDetail(
    id: j['id'] as int,
    name: j['name'] as String? ?? '',
    description: j['description'] as String?,
    inviteCode: j['invite_code'] as String? ?? '',
    isOwner: j['is_owner'] as bool? ?? false,
    members: (j['members'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => GroupMember.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.telegramId,
    required this.name,
    this.role = 'member',
    this.isMe = false,
    this.streak = 0,
    this.visible = true,
    this.isActive = true,
    this.plansTotal = 0,
    this.plansDone = 0,
    this.habitsTotal = 0,
    this.habitsDone = 0,
  });

  final int userId;
  final int telegramId;
  final String name;
  final String role; // owner | member
  final bool isMe;
  final int streak;
  final bool visible;
  final bool isActive;
  final int plansTotal;
  final int plansDone;
  final int habitsTotal;
  final int habitsDone;

  bool get isOwner => role == 'owner';

  factory GroupMember.fromJson(Map<String, dynamic> j) {
    final s = Map<String, dynamic>.from(j['summary'] as Map? ?? const {});
    return GroupMember(
      userId: j['user_id'] as int,
      telegramId: j['telegram_id'] as int? ?? 0,
      name: j['name'] as String? ?? 'Foydalanuvchi',
      role: j['role'] as String? ?? 'member',
      isMe: j['is_me'] as bool? ?? false,
      streak: j['streak'] as int? ?? 0,
      visible: j['visible'] as bool? ?? true,
      isActive: j['is_active'] as bool? ?? true,
      plansTotal: s['plans_total'] as int? ?? 0,
      plansDone: s['plans_done'] as int? ?? 0,
      habitsTotal: s['habits_total'] as int? ?? 0,
      habitsDone: s['habits_done_today'] as int? ?? 0,
    );
  }
}

class MemberView {
  const MemberView({
    required this.userId,
    required this.name,
    this.streak = 0,
    this.totalScore = 0,
    this.isMe = false,
    this.plans = const [],
    this.habits = const [],
    this.canManage = false,
    this.visible = true,
    required this.date,
    this.isToday = true,
    this.isPast = false,
    this.isFuture = false,
  });

  final int userId;
  final String name;
  final int streak;
  final int totalScore;
  final bool isMe;
  final List<MemberItem> plans;
  final List<MemberItem> habits;
  final bool canManage;
  final bool visible;
  final String date;
  final bool isToday;
  final bool isPast;
  final bool isFuture;

  factory MemberView.fromJson(Map<String, dynamic> j) {
    final m = Map<String, dynamic>.from(j['member'] as Map? ?? const {});
    List<MemberItem> items(String key, bool habit) => (j[key] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MemberItem.fromJson(Map<String, dynamic>.from(e), habit: habit))
        .toList();
    return MemberView(
      userId: m['user_id'] as int? ?? 0,
      name: m['name'] as String? ?? 'Foydalanuvchi',
      streak: m['streak'] as int? ?? 0,
      totalScore: m['total_score'] as int? ?? 0,
      isMe: m['is_me'] as bool? ?? false,
      plans: items('plans', false),
      habits: items('habits', true),
      canManage: j['can_manage'] as bool? ?? false,
      visible: j['visible'] as bool? ?? true,
      date: j['date'] as String? ?? '',
      isToday: j['is_today'] as bool? ?? true,
      isPast: j['is_past'] as bool? ?? false,
      isFuture: j['is_future'] as bool? ?? false,
    );
  }
}

/// A'zo ko'rinishidagi reja yoki odat qatori.
class MemberItem {
  const MemberItem({
    required this.title,
    this.icon,
    this.time,
    this.done = false,
    this.weekly = false,
  });

  final String title;
  final String? icon;
  final String? time;
  final bool done;
  final bool weekly;

  factory MemberItem.fromJson(Map<String, dynamic> j, {required bool habit}) => MemberItem(
    title: j['title'] as String? ?? '',
    icon: habit ? (j['icon'] as String? ?? '✅') : null,
    time: (habit ? j['reminder_time'] : j['scheduled_time']) as String?,
    done: habit ? (j['done_today'] as bool? ?? false) : j['status'] == 'done',
    weekly: habit && j['frequency'] == 'weekly',
  );
}

class Permissions {
  const Permissions({this.grantsOut = const [], this.grantsIn = const []});

  /// Men kimga ruxsat berganman (men uchun yarata oladi).
  final List<PermissionEntry> grantsOut;

  /// Kim menga ruxsat bergan.
  final List<PermissionEntry> grantsIn;

  factory Permissions.fromJson(Map<String, dynamic> j) {
    List<PermissionEntry> list(String k) => (j[k] as List? ?? const [])
        .whereType<Map>()
        .map((e) => PermissionEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return Permissions(grantsOut: list('grants_out'), grantsIn: list('grants_in'));
  }
}

class PermissionEntry {
  const PermissionEntry({required this.userId, required this.name, this.canManage = false});
  final int userId;
  final String name;
  final bool canManage;

  factory PermissionEntry.fromJson(Map<String, dynamic> j) => PermissionEntry(
    userId: j['user_id'] as int,
    name: j['name'] as String? ?? '',
    canManage: j['can_manage'] as bool? ?? false,
  );
}

/// Guruhning Telegram hisobot sozlamalari (faqat ega).
class DigestSettings {
  const DigestSettings({
    this.chatId,
    this.chatTitle,
    this.digestEnabled = false,
    this.digestTime = '21:00',
    this.plansEnabled = false,
    this.plansTime = '07:00',
    this.reportSource = 'both',
    this.allowedTimes = const [],
    this.lastError,
  });

  final int? chatId;
  final String? chatTitle;
  final bool digestEnabled;
  final String digestTime;
  final bool plansEnabled;
  final String plansTime;
  final String reportSource; // plans | habits | both
  final List<String> allowedTimes;
  final String? lastError;

  factory DigestSettings.fromJson(Map<String, dynamic> j) => DigestSettings(
    chatId: j['telegram_chat_id'] as int?,
    chatTitle: j['telegram_chat_title'] as String?,
    digestEnabled: j['digest_enabled'] as bool? ?? false,
    digestTime: j['digest_time'] as String? ?? '21:00',
    plansEnabled: j['plans_enabled'] as bool? ?? false,
    plansTime: j['plans_time'] as String? ?? '07:00',
    reportSource: j['report_source'] as String? ?? 'both',
    allowedTimes: (j['allowed_times'] as List? ?? const []).map((e) => '$e').toList(),
    lastError: (j['digest_last_error'] ?? j['plans_last_error']) as String?,
  );
}

class TelegramChat {
  const TelegramChat({required this.chatId, required this.title, this.canSend = true});
  final int chatId;
  final String title;
  final bool canSend;

  factory TelegramChat.fromJson(Map<String, dynamic> j) => TelegramChat(
    chatId: j['chat_id'] as int,
    title: j['chat_title'] as String? ?? '',
    canSend: j['can_send'] as bool? ?? true,
  );
}
