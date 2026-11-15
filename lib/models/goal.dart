/// Maqsad modeli (yillik/oylik).
class Goal {
  const Goal({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.goalType = 'yearly',
    this.period,
    this.completed = false,
  });

  final int id;
  final int userId;
  final String title;
  final String? description;
  final String goalType; // "yearly" | "monthly"
  final String? period; // "2026" yoki "2026-05"
  final bool completed;

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      goalType: json['goal_type'] as String? ?? 'yearly',
      period: json['period'] as String?,
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'goal_type': goalType,
    'period': period,
  };
}
