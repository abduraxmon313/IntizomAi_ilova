/// Yutuq (badge) modeli.
class Achievement {
  const Achievement({
    required this.id,
    required this.code,
    required this.title,
    required this.icon,
    this.rarity = 'common',
    this.unlockedAt,
  });

  final int id;
  final String code;
  final String title;
  final String icon;
  final String rarity; // "common" | "rare" | "epic" | "legendary"
  final String? unlockedAt;

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as int,
      code: json['code'] as String,
      title: json['title'] as String,
      icon: json['icon'] as String,
      rarity: json['rarity'] as String? ?? 'common',
      unlockedAt: json['unlocked_at'] as String?,
    );
  }
}
