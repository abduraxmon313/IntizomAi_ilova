/// Maqsad (yillik/oylik) — server: webapp/routes/goals.py (GoalOut).
class Goal {
  const Goal({
    required this.id,
    required this.title,
    this.description,
    required this.goalType,
    required this.period,
    this.completed = false,
  });

  final int id;
  final String title;
  final String? description;
  final String goalType; // yearly | monthly
  final String period; // "2026" | "2026-05"
  final bool completed;

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    goalType: json['goal_type'] as String? ?? 'yearly',
    period: json['period'] as String? ?? '',
    completed: json['completed'] as bool? ?? false,
  );
}
