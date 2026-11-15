/// Kunlik mood/energiya check-in modeli.
class DailyCheckin {
  const DailyCheckin({
    required this.id,
    required this.userId,
    required this.checkinDate,
    this.mood,
    this.energy,
  });

  final int id;
  final int userId;
  final String checkinDate;
  final String? mood; // "🔥" | "💪" | "😐" | "😴" | "😞"
  final int? energy; // 1-5

  factory DailyCheckin.fromJson(Map<String, dynamic> json) {
    return DailyCheckin(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      checkinDate: json['checkin_date'] as String,
      mood: json['mood'] as String?,
      energy: json['energy'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'checkin_date': checkinDate,
    'mood': mood,
    'energy': energy,
  };
}
