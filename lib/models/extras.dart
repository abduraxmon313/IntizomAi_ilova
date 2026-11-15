/// Reyting qatori — /api/webapp/leaderboard.
class LeaderRow {
  const LeaderRow({
    required this.rank,
    required this.name,
    this.photoUrl,
    this.value = 0,
    this.isMe = false,
  });

  final int rank;
  final String name;
  final String? photoUrl; // nisbiy yo'l: /api/webapp/avatar/<id>
  final int value;
  final bool isMe;

  factory LeaderRow.fromJson(Map<String, dynamic> j) => LeaderRow(
    rank: j['rank'] as int? ?? 0,
    name: j['name'] as String? ?? '',
    photoUrl: j['photo_url'] as String?,
    value: j['value'] as int? ?? 0,
    isMe: j['is_me'] as bool? ?? false,
  );
}

class Leaderboard {
  const Leaderboard({this.top = const [], this.me, this.meInTop = true});
  final List<LeaderRow> top;
  final LeaderRow? me;
  final bool meInTop;

  factory Leaderboard.fromJson(Map<String, dynamic> j) {
    final me = j['me'] is Map ? Map<String, dynamic>.from(j['me'] as Map) : null;
    return Leaderboard(
      top: (j['top'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => LeaderRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      me: me == null ? null : LeaderRow.fromJson({...me, 'is_me': true}),
      meInTop: me?['in_top'] as bool? ?? true,
    );
  }
}

/// Kunlik kayfiyat / energiya — /api/webapp/checkin.
class Checkin {
  const Checkin({this.mood, this.energy});
  final String? mood; // 🔥 💪 😐 😴 😞
  final int? energy; // 1..5

  factory Checkin.fromJson(Map<String, dynamic> j) =>
      Checkin(mood: j['mood'] as String?, energy: j['energy'] as int?);
}

/// Obuna holati — /api/webapp/subscription.
class Subscription {
  const Subscription({
    this.isPremium = false,
    this.premiumUntil,
    this.daysLeft = 0,
    this.planTitle,
  });

  final bool isPremium;
  final String? premiumUntil;
  final int daysLeft;
  final String? planTitle;

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
    isPremium: j['is_premium'] as bool? ?? false,
    premiumUntil: j['premium_until'] as String?,
    daysLeft: j['days_left'] as int? ?? 0,
    planTitle: j['plan_title'] as String?,
  );
}
