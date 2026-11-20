/// IntizomAI ilova konfiguratsiyasi.
///
/// Ilova o'zining alohida backend'iga ulanadi (IntizomAi_ilova_database → Railway).
/// Qiymatlar build vaqtida beriladi:
/// `flutter build apk --dart-define=API_BASE_URL=https://... --dart-define=GOOGLE_SERVER_CLIENT_ID=...`
/// Codemagic ularni `IntizomAi` guruhidagi o'zgaruvchilardan oladi.
library;

const kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Google Cloud → OAuth "Web application" client ID. Android'da ID token shu
/// auditoriya bilan beriladi va server uni tekshiradi.
const kGoogleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

/// Google Cloud → OAuth "iOS" client ID (faqat iOS).
const kGoogleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

/// Qo'llab-quvvatlash va ijtimoiy havolalar.
const kSupportUrl = 'https://t.me/IntizomAI_Admin_bot';
const kChannelUrl = 'https://t.me/Intizom_AI';
const kInstagramUrl = 'https://www.instagram.com/intizomai.uz';

/// Ilova API'si: /api/v1/...
Uri apiUri(String path, [Map<String, String>? query]) {
  final base = kApiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  return Uri.parse('$base/api/v1$path').replace(queryParameters: query);
}
