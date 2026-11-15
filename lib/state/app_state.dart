import 'package:flutter/foundation.dart';

import '../models/goal.dart';
import '../models/habit.dart';
import '../models/profile.dart';
import '../models/stats.dart';
import '../services/intizom_api.dart';

/// Bir nechta bo'limda ishlatiladigan ma'lumotlar: profil, statistika,
/// odatlar, maqsadlar. Biror bo'limda o'zgarish bo'lsa, qolganlari ham yangilanadi.
class AppState extends ChangeNotifier {
  AppState(this.api);

  final IntizomApi api;

  Profile? profile;
  UserStats stats = const UserStats();
  List<Habit> habits = const [];
  List<Goal> goals = const [];

  bool loading = true;
  String? error;

  /// Rejalar o'zgarganini bildiradi (Asosiy va Statistika qayta yuklaydi).
  int plansVersion = 0;

  Future<void> loadAll() async {
    loading = profile == null;
    error = null;
    notifyListeners();
    try {
      final r = await Future.wait([api.profile(), api.stats(), api.habits(), api.goals()]);
      profile = r[0] as Profile;
      stats = r[1] as UserStats;
      habits = r[2] as List<Habit>;
      goals = r[3] as List<Goal>;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refreshStats() async {
    try {
      stats = await api.stats();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshProfile() async {
    try {
      profile = await api.profile();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshHabits() async {
    habits = await api.habits();
    notifyListeners();
  }

  Future<void> refreshGoals() async {
    goals = await api.goals();
    notifyListeners();
  }

  void replaceHabit(Habit h) {
    habits = [for (final x in habits) x.id == h.id ? h : x];
    notifyListeners();
  }

  void setProfile(Profile p) {
    profile = p;
    notifyListeners();
  }

  void plansChanged() {
    plansVersion++;
    notifyListeners();
    refreshStats();
  }
}
