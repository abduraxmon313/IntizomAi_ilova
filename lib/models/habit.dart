/// Odat — server: bot/services/habit_service.py (habit_snapshot).
class Habit {
  const Habit({
    required this.id,
    required this.title,
    this.description,
    this.icon = '✅',
    this.reminderTime,
    this.frequency = 'daily',
    this.weekdays = const [],
    this.dueToday = true,
    this.doneToday = false,
    this.finished = false,
    this.streak = 0,
    this.totalDone = 0,
  });

  final int id;
  final String title;
  final String? description;
  final String icon;
  final String? reminderTime;
  final String frequency; // daily | weekly
  final List<int> weekdays; // 0=Dushanba .. 6=Yakshanba
  final bool dueToday;
  final bool doneToday;
  final bool finished;
  final int streak;
  final int totalDone;

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    icon: json['icon'] as String? ?? '✅',
    reminderTime: json['reminder_time'] as String?,
    frequency: json['frequency'] as String? ?? 'daily',
    weekdays: (json['weekdays'] as List? ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toList(),
    dueToday: json['due_today'] as bool? ?? true,
    doneToday: json['done_today'] as bool? ?? false,
    finished: json['finished'] as bool? ?? false,
    streak: json['streak'] as int? ?? 0,
    totalDone: json['total_done'] as int? ?? 0,
  );
}
