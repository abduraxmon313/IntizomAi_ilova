/// Profil — server: webapp/routes/profile.py (ProfileOut).
class Profile {
  const Profile({
    required this.telegramId,
    required this.fullName,
    this.username,
    this.notificationsEnabled = true,
    this.referralLink,
    this.referralCount = 0,
    this.photoUrl,
    this.customPhotoUrl,
  });

  final int telegramId;
  final String fullName;
  final String? username;
  final bool notificationsEnabled;
  final String? referralLink;
  final int referralCount;
  final String? photoUrl;
  final String? customPhotoUrl; // URL yoki "data:image/...;base64,..."

  String? get avatar =>
      (customPhotoUrl?.isNotEmpty ?? false) ? customPhotoUrl : photoUrl;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    telegramId: j['telegram_id'] as int,
    fullName: j['full_name'] as String? ?? 'Foydalanuvchi',
    username: j['username'] as String?,
    notificationsEnabled: j['notifications_enabled'] as bool? ?? true,
    referralLink: j['referral_link'] as String?,
    referralCount: j['referral_count'] as int? ?? 0,
    photoUrl: j['photo_url'] as String?,
    customPhotoUrl: j['custom_photo_url'] as String?,
  );
}
