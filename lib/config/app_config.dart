/// IntizomAI ilova konfiguratsiyasi.
///
/// Ilova bot va Mini App ishlayotgan o'sha Railway serveriga ulanadi
/// (IntizomAi_Bot_Pro_Copy → webapp/app.py). Manzil build vaqtida beriladi:
/// `flutter build apk --dart-define=API_BASE_URL=https://railway-domen`
/// Codemagic buni `intizomai` guruhidagi API_BASE_URL o'zgaruvchisidan oladi.
library;

const kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Telegram bot username (kirish va to'lov uchun).
const kBotUsername = 'intizomAi_bot';

/// Bot havolasi; [start] — /start payload.
Uri botUri([String? start]) => Uri.https(
  't.me',
  '/$kBotUsername',
  start == null ? null : {'start': start},
);

/// Mini App bilan umumiy API: /api/webapp/...
Uri apiUri(String path, [Map<String, String>? query]) {
  final base = kApiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  return Uri.parse('$base/api/webapp$path').replace(queryParameters: query);
}
