/// IntizomAI ilova konfiguratsiyasi.
///
/// Ilova o'zining alohida backend'iga ulanadi (IntizomAi_ilova_database → Railway).
/// Qiymatlar build vaqtida beriladi:
/// `flutter build apk --dart-define=API_BASE_URL=https://... --dart-define=GOOGLE_SERVER_CLIENT_ID=...`
/// Codemagic ularni `IntizomAi` guruhidagi o'zgaruvchilardan oladi.
library;

const _rawApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Server manzili. `https://` yozilmay qolgan bo'lsa ham to'g'ri ishlaydi,
/// oxiridagi `/` olib tashlanadi.
final String kApiBaseUrl = _normalizeBase(_rawApiBaseUrl);

String _normalizeBase(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'/+$'), '');
  if (s.isEmpty) return s;
  if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
  return s;
}

/// Ilova sayti: do'stga yuborilgan taklifda yuklab olish havolasi sifatida.
const kSiteUrl = 'https://intizom.app';

/// Maxfiylik siyosati sahifasi (build vaqtida `--dart-define=PRIVACY_URL=...` bilan almashtirsa bo'ladi).
const kPrivacyUrl = String.fromEnvironment('PRIVACY_URL', defaultValue: 'https://intizom.app/privacy');

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
  return Uri.parse('$kApiBaseUrl/api/v1$path').replace(queryParameters: query);
}
