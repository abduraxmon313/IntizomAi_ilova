/// Gamifikatsiya holati — server: build_user_snapshot (/api/webapp/stats).
class UserStats {
  const UserStats({
    this.level = 1,
    this.xp = 0,
    this.totalScore = 0,
    this.xpInLevel = 0,
    this.xpNeeded = 100,
    this.xpPercent = 0,
    this.streak = 0,
    this.longestStreak = 0,
    this.streakAtRisk = false,
    this.disciplineScore = 50,
    this.rankTitle = 'Boshlovchi',
    this.rankEmoji = '🌱',
    this.isPremium = false,
    this.perfectDays = 0,
    this.todayDone = 0,
    this.todayTotal = 0,
    this.achievements = const [],
  });

  final int level;
  final int xp;
  final int totalScore;
  final int xpInLevel;
  final int xpNeeded;
  final int xpPercent;
  final int streak;
  final int longestStreak;
  final bool streakAtRisk;
  final int disciplineScore;
  final String rankTitle;
  final String rankEmoji;
  final bool isPremium;
  final int perfectDays;
  final int todayDone;
  final int todayTotal;
  final List<Achievement> achievements;

  factory UserStats.fromJson(Map<String, dynamic> j) => UserStats(
    level: j['level'] as int? ?? 1,
    xp: j['xp'] as int? ?? 0,
    totalScore: j['total_score'] as int? ?? 0,
    xpInLevel: j['xp_in_level'] as int? ?? 0,
    xpNeeded: j['xp_needed'] as int? ?? 100,
    xpPercent: j['xp_percent'] as int? ?? 0,
    streak: j['streak'] as int? ?? 0,
    longestStreak: j['longest_streak'] as int? ?? 0,
    streakAtRisk: j['streak_at_risk'] as bool? ?? false,
    disciplineScore: j['discipline_score'] as int? ?? 50,
    rankTitle: j['rank_title'] as String? ?? 'Boshlovchi',
    rankEmoji: j['rank_emoji'] as String? ?? '🌱',
    isPremium: j['is_premium'] as bool? ?? false,
    perfectDays: j['perfect_days'] as int? ?? 0,
    todayDone: j['today_done'] as int? ?? 0,
    todayTotal: j['today_total'] as int? ?? 0,
    achievements: (j['achievements'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Achievement.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

/// Bir kunlik faollik — /api/v1/stats/activity. Server hisoblaydi: o'chirilgan
/// odatlar tarixi ham kiradi, bugungi bajarilmagan ish "o'tkazib yuborilgan" emas.
class DayActivity {
  const DayActivity({
    required this.date,
    this.done = 0,
    this.plansDone = 0,
    this.plansDue = 0,
    this.habitsDone = 0,
    this.habitsDue = 0,
  });

  final String date; // YYYY-MM-DD
  final int done;
  final int plansDone;
  final int plansDue;
  final int habitsDone;
  final int habitsDue;

  factory DayActivity.fromJson(Map<String, dynamic> j) => DayActivity(
    date: j['date'] as String? ?? '',
    done: j['done'] as int? ?? 0,
    plansDone: j['plans_done'] as int? ?? 0,
    plansDue: j['plans_due'] as int? ?? 0,
    habitsDone: j['habits_done'] as int? ?? 0,
    habitsDue: j['habits_due'] as int? ?? 0,
  );
}

class Achievement {
  const Achievement({
    required this.code,
    required this.title,
    required this.icon,
    this.rarity = 'common',
  });

  final String code;
  final String title;
  final String icon;
  final String rarity;

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
    code: j['code'] as String? ?? '',
    title: j['title'] as String? ?? '',
    icon: j['icon'] as String? ?? '🏅',
    rarity: j['rarity'] as String? ?? 'common',
  );
}

/// Kunlik topshiriq — /api/webapp/quest.
class DailyQuest {
  const DailyQuest({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.progress = 0,
    this.target = 1,
    this.completed = false,
  });

  final String title;
  final String subtitle;
  final String icon;
  final int progress;
  final int target;
  final bool completed;

  factory DailyQuest.fromJson(Map<String, dynamic> j) => DailyQuest(
    title: j['title'] as String? ?? '',
    subtitle: j['subtitle'] as String? ?? '',
    icon: j['icon'] as String? ?? '🎯',
    progress: j['progress'] as int? ?? 0,
    target: j['target'] as int? ?? 1,
    completed: j['completed'] as bool? ?? false,
  );
}
