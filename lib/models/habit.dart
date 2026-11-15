/// Odat modeli.
class Habit {
  const Habit({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.icon = '✅',
    this.reminderTime,
    this.frequency = 'daily',
    this.weekdays,
    this.durationType = 'permanent',
    this.targetDays,
    this.startDate,
    this.sortOrder = 0,
    this.archived = false,
    this.todayDone = false,
    this.currentStreak = 0,
  });

  final int id;
  final int userId;
  final String title;
  final String? description;
  final String icon;
  final String? reminderTime; // "HH:MM"
  final String frequency; // "daily" | "weekly"
  final String? weekdays; // "0,1,2,3,4" (Mon=0)
  final String durationType; // "permanent" | "days"
  final int? targetDays;
  final String? startDate;
  final int sortOrder;
  final bool archived;
  final bool todayDone;
  final int currentStreak;

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? '✅',
      reminderTime: json['reminder_time'] as String?,
      frequency: json['frequency'] as String? ?? 'daily',
      weekdays: json['weekdays'] as String?,
      durationType: json['duration_type'] as String? ?? 'permanent',
      targetDays: json['target_days'] as int?,
      startDate: json['start_date'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      archived: json['archived'] as bool? ?? false,
      todayDone: json['today_done'] as bool? ?? false,
      currentStreak: json['current_streak'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'icon': icon,
    'reminder_time': reminderTime,
    'frequency': frequency,
    'weekdays': weekdays,
    'duration_type': durationType,
    'target_days': targetDays,
  };
}
