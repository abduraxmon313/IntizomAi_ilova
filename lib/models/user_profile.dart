/// IntizomAI foydalanuvchi profili — Railway PostgreSQL'dan keladi.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.telegramId,
    this.fullName,
    this.displayName,
    this.username,
    this.photoUrl,
    this.customPhotoUrl,
    this.streak = 0,
    this.totalScore = 0,
    this.xp = 0,
    this.level = 1,
    this.longestStreak = 0,
    this.streakFreezes = 0,
    this.disciplineScore = 50,
    this.weeklyXp = 0,
    this.perfectDays = 0,
    this.isPremium = false,
    this.premiumUntil,
    this.onboarded = false,
    this.rankTitle,
    this.avatarEmoji = '🌱',
    this.referralCount = 0,
    this.isActive = true,
    this.notificationsEnabled = true,
    this.createdAt,
  });

  final int id;
  final int telegramId;
  final String? fullName;
  final String? displayName;
  final String? username;
  final String? photoUrl;
  final String? customPhotoUrl;
  final int streak;
  final int totalScore;
  final int xp;
  final int level;
  final int longestStreak;
  final int streakFreezes;
  final int disciplineScore;
  final int weeklyXp;
  final int perfectDays;
  final bool isPremium;
  final String? premiumUntil;
  final bool onboarded;
  final String? rankTitle;
  final String avatarEmoji;
  final int referralCount;
  final bool isActive;
  final bool notificationsEnabled;
  final String? createdAt;

  /// Ko'rsatiladigan ism (display_name > full_name > username).
  String get name =>
      displayName?.isNotEmpty == true
          ? displayName!
          : fullName?.isNotEmpty == true
              ? fullName!
              : username ?? 'Foydalanuvchi';

  /// Profil rasmi (custom > telegram > null).
  String? get effectivePhotoUrl =>
      customPhotoUrl?.isNotEmpty == true ? customPhotoUrl : photoUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      telegramId: json['telegram_id'] as int,
      fullName: json['full_name'] as String?,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      photoUrl: json['photo_url'] as String?,
      customPhotoUrl: json['custom_photo_url'] as String?,
      streak: json['streak'] as int? ?? 0,
      totalScore: json['total_score'] as int? ?? 0,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      longestStreak: json['longest_streak'] as int? ?? 0,
      streakFreezes: json['streak_freezes'] as int? ?? 0,
      disciplineScore: json['discipline_score'] as int? ?? 50,
      weeklyXp: json['weekly_xp'] as int? ?? 0,
      perfectDays: json['perfect_days'] as int? ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      premiumUntil: json['premium_until'] as String?,
      onboarded: json['onboarded'] as bool? ?? false,
      rankTitle: json['rank_title'] as String?,
      avatarEmoji: json['avatar_emoji'] as String? ?? '🌱',
      referralCount: json['referral_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
    );
  }
}
