/// Kunlik reja modeli.
class Plan {
  const Plan({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.scheduledTime,
    required this.planDate,
    this.status = PlanStatus.pending,
    this.scoreValue = 5,
    this.createdByUserId,
  });

  final int id;
  final int userId;
  final String title;
  final String? description;
  final String? scheduledTime; // "HH:MM"
  final String planDate; // "YYYY-MM-DD"
  final PlanStatus status;
  final int scoreValue;
  final int? createdByUserId;

  bool get isDone => status == PlanStatus.done;
  bool get isPending => status == PlanStatus.pending;
  bool get isFailed => status == PlanStatus.failed;

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      scheduledTime: json['scheduled_time'] as String?,
      planDate: json['plan_date'] as String,
      status: PlanStatus.fromString(json['status'] as String? ?? 'pending'),
      scoreValue: json['score_value'] as int? ?? 5,
      createdByUserId: json['created_by_user_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'scheduled_time': scheduledTime,
    'plan_date': planDate,
  };
}

enum PlanStatus {
  pending,
  done,
  failed;

  static PlanStatus fromString(String s) => switch (s) {
    'done' => PlanStatus.done,
    'failed' => PlanStatus.failed,
    _ => PlanStatus.pending,
  };
}
