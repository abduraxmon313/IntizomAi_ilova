import '../models/user_profile.dart';
import 'api_client.dart';

/// Foydalanuvchi profili boshqaruvi — Railway API orqali.
class UserService {
  UserService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Joriy foydalanuvchi profilini olish.
  Future<UserProfile> getProfile() async {
    final res = await _api.get('/user/profile');
    if (!res.isOk) throw ApiException(res.error ?? 'Profilni yuklashda xato', statusCode: res.statusCode);
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }

  /// Dashboard ma'lumotlari (streak, XP, discipline, bugungi natija).
  Future<Map<String, dynamic>> getDashboard() async {
    final res = await _api.get('/user/dashboard');
    if (!res.isOk) throw ApiException(res.error ?? 'Dashboard xato', statusCode: res.statusCode);
    return res.data as Map<String, dynamic>;
  }

  /// Profil ismini yangilash.
  Future<void> updateDisplayName(String name) async {
    final res = await _api.patch('/user/profile', body: {'display_name': name});
    if (!res.isOk) throw ApiException(res.error ?? 'Yangilashda xato', statusCode: res.statusCode);
  }

  /// Bildirishnomalarni yoqish/o'chirish.
  Future<void> setNotifications(bool enabled) async {
    final res = await _api.patch('/user/profile', body: {'notifications_enabled': enabled});
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
  }

  /// Haftalik reyting.
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final res = await _api.get('/user/leaderboard');
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Yutuqlar ro'yxati.
  Future<List<Map<String, dynamic>>> getAchievements() async {
    final res = await _api.get('/user/achievements');
    if (!res.isOk) throw ApiException(res.error ?? 'Xato', statusCode: res.statusCode);
    return (res.data as List).cast<Map<String, dynamic>>();
  }
}
