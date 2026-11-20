/// Profil — server: GET /api/v1/profile.
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    this.username,
    this.age,
    this.email,
    this.onboarded = false,
    this.notificationsEnabled = true,
    this.leaderboardVisible = true,
    this.referralLink,
    this.referralCount = 0,
    this.photoUrl,
    this.customPhotoUrl,
    this.providers = const [],
    this.isPremium = false,
  });

  final int id;
  final String fullName;
  final String? username;
  final int? age;
  final String? email;
  final bool onboarded;
  final bool notificationsEnabled;
  final bool leaderboardVisible;
  final String? referralLink;
  final int referralCount;

  /// Ko'rsatiladigan rasm: yuklangan rasm (nisbiy yo'l) yoki Google rasmi.
  final String? photoUrl;

  /// Foydalanuvchi o'zi yuklagan rasm (bo'lsa).
  final String? customPhotoUrl;

  /// Kirish usullari: google / apple.
  final List<String> providers;
  final bool isPremium;

  String? get avatar => photoUrl;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as int? ?? 0,
    fullName: j['full_name'] as String? ?? 'Foydalanuvchi',
    username: j['username'] as String?,
    age: j['age'] as int?,
    email: j['email'] as String?,
    onboarded: j['onboarded'] as bool? ?? false,
    notificationsEnabled: j['notifications_enabled'] as bool? ?? true,
    leaderboardVisible: j['leaderboard_visible'] as bool? ?? true,
    referralLink: j['referral_link'] as String?,
    referralCount: j['referral_count'] as int? ?? 0,
    photoUrl: j['photo_url'] as String?,
    customPhotoUrl: j['custom_photo_url'] as String?,
    providers: (j['providers'] as List? ?? const []).map((e) => '$e').toList(),
    isPremium: j['is_premium'] as bool? ?? false,
  );
}

/// Boshqa foydalanuvchining ochiq kartasi (qidiruv, taklif, ro'yxatlar).
class UserCard {
  const UserCard({required this.userId, required this.name, this.username, this.photoUrl});

  final int userId;
  final String name;
  final String? username;
  final String? photoUrl;

  factory UserCard.fromJson(Map<String, dynamic> j) => UserCard(
    userId: j['user_id'] as int? ?? 0,
    name: j['name'] as String? ?? 'Foydalanuvchi',
    username: j['username'] as String?,
    photoUrl: j['photo_url'] as String?,
  );
}

/// Username tekshiruvi natijasi.
class UsernameCheck {
  const UsernameCheck({required this.username, required this.available, this.reason});
  final String username;
  final bool available;
  final String? reason;

  factory UsernameCheck.fromJson(Map<String, dynamic> j) => UsernameCheck(
    username: j['username'] as String? ?? '',
    available: j['available'] as bool? ?? false,
    reason: j['reason'] as String?,
  );
}
