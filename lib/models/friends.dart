import 'profile.dart';

/// Guruhlar — server: /api/v1/groups, /api/v1/invites (app/services/groups.py).
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

/// Guruhlar ro'yxati + kelgan takliflar soni.
class GroupList {
  const GroupList({this.groups = const [], this.invitesCount = 0, this.canCreate = false});
  final List<GroupSummary> groups;
  final int invitesCount;
  final bool canCreate;

  factory GroupList.fromJson(Map<String, dynamic> j) => GroupList(
    groups: (j['groups'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => GroupSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    invitesCount: j['invites_count'] as int? ?? 0,
    canCreate: j['can_create'] as bool? ?? false,
  );
}

class GroupDetail {
  const GroupDetail({
    required this.id,
    required this.name,
    this.description,
    this.isOwner = false,
    this.members = const [],
    this.pendingInvites = const [],
  });

  final int id;
  final String name;
  final String? description;
  final bool isOwner;
  final List<GroupMember> members;

  /// Faqat ega uchun: javob kutilayotgan takliflar.
  final List<OutgoingInvite> pendingInvites;

  factory GroupDetail.fromJson(Map<String, dynamic> j) => GroupDetail(
    id: j['id'] as int,
    name: j['name'] as String? ?? '',
    description: j['description'] as String?,
    isOwner: j['is_owner'] as bool? ?? false,
    members: (j['members'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => GroupMember.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    pendingInvites: (j['pending_invites'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => OutgoingInvite.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.name,
    this.username,
    this.photoUrl,
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
  final String name;
  final String? username;
  final String? photoUrl;
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
      name: j['name'] as String? ?? 'Foydalanuvchi',
      username: j['username'] as String?,
      photoUrl: j['photo_url'] as String?,
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

/// Ega yuborgan, hali javob berilmagan taklif.
class OutgoingInvite {
  const OutgoingInvite({required this.id, required this.user});
  final int id;
  final UserCard user;

  factory OutgoingInvite.fromJson(Map<String, dynamic> j) => OutgoingInvite(
    id: j['id'] as int,
    user: UserCard.fromJson(Map<String, dynamic>.from(j['user'] as Map? ?? const {})),
  );
}

/// Menga kelgan guruh taklifi.
class IncomingInvite {
  const IncomingInvite({
    required this.id,
    required this.groupId,
    required this.groupName,
    this.groupDescription,
    this.memberCount = 0,
    required this.inviter,
  });

  final int id;
  final int groupId;
  final String groupName;
  final String? groupDescription;
  final int memberCount;
  final UserCard inviter;

  factory IncomingInvite.fromJson(Map<String, dynamic> j) {
    final g = Map<String, dynamic>.from(j['group'] as Map? ?? const {});
    return IncomingInvite(
      id: j['id'] as int,
      groupId: g['id'] as int? ?? 0,
      groupName: g['name'] as String? ?? '',
      groupDescription: g['description'] as String?,
      memberCount: g['member_count'] as int? ?? 0,
      inviter: UserCard.fromJson(Map<String, dynamic>.from(j['inviter'] as Map? ?? const {})),
    );
  }
}

class MemberView {
  const MemberView({
    required this.userId,
    required this.name,
    this.username,
    this.photoUrl,
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
  final String? username;
  final String? photoUrl;
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
      username: m['username'] as String?,
      photoUrl: m['photo_url'] as String?,
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
  const PermissionEntry({required this.userId, required this.name, this.photoUrl, this.canManage = false});
  final int userId;
  final String name;
  final String? photoUrl;
  final bool canManage;

  factory PermissionEntry.fromJson(Map<String, dynamic> j) => PermissionEntry(
    userId: j['user_id'] as int,
    name: j['name'] as String? ?? '',
    photoUrl: j['photo_url'] as String?,
    canManage: j['can_manage'] as bool? ?? false,
  );
}
