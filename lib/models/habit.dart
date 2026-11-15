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
    this.durationType = 'permanent',
    this.targetDays,
    this.startDate,
    this.endDate,
    this.daysLeft,
    this.dueToday = true,
    this.doneToday = false,
    this.finished = false,
    this.streak = 0,
    this.totalDone = 0,
    this.logDates = const {},
  });

  final int id;
  final String title;
  final String? description;
  final String icon;
  final String? reminderTime; // "HH:MM"
  final String frequency; // daily | weekly
  final List<int> weekdays; // 0=Dushanba .. 6=Yakshanba
  final String durationType; // permanent | days
  final int? targetDays;
  final String? startDate; // YYYY-MM-DD
  final String? endDate;
  final int? daysLeft;
  final bool dueToday;
  final bool doneToday;
  final bool finished;
  final int streak;
  final int totalDone;

  /// Oxirgi ~45 kunda bajarilgan sanalar (YYYY-MM-DD).
  final Set<String> logDates;

  bool get isWeekly => frequency == 'weekly' && weekdays.isNotEmpty && weekdays.length < 7;

  /// Shu sanada rejadami (server bilan bir xil mantiq).
  bool dueOn(DateTime day) {
    final ds = _ymd(day);
    if (startDate != null && ds.compareTo(startDate!) < 0) return false;
    if (endDate != null && ds.compareTo(endDate!) > 0) return false;
    if (frequency == 'weekly') {
      return weekdays.isEmpty || weekdays.contains(day.weekday - 1);
    }
    return true;
  }

  bool doneOn(DateTime day) => logDates.contains(_ymd(day));

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    durationType: json['duration_type'] as String? ?? 'permanent',
    targetDays: json['target_days'] as int?,
    startDate: json['start_date'] as String?,
    endDate: json['end_date'] as String?,
    daysLeft: json['days_left'] as int?,
    dueToday: json['due_today'] as bool? ?? true,
    doneToday: json['done_today'] as bool? ?? false,
    finished: json['finished'] as bool? ?? false,
    streak: json['streak'] as int? ?? 0,
    totalDone: json['total_done'] as int? ?? 0,
    logDates: (json['log_dates'] as List? ?? const []).whereType<String>().toSet(),
  );
}
