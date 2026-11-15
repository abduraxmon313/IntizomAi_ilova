/// Kunlik reja — server: webapp/routes/plans.py (PlanOut).
class Plan {
  const Plan({
    required this.id,
    required this.title,
    this.description,
    this.scheduledTime,
    required this.planDate,
    this.status = 'pending',
    this.scoreValue = 5,
  });

  final int id;
  final String title;
  final String? description;
  final String? scheduledTime; // "HH:MM"
  final String planDate; // "YYYY-MM-DD"
  final String status; // pending | done | failed
  final int scoreValue;

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    scheduledTime: json['scheduled_time'] as String?,
    planDate: json['plan_date'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    scoreValue: json['score_value'] as int? ?? 5,
  );
}
