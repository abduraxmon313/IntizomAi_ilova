/// IntizomAI ilova konfiguratsiyasi.
///
/// API bazaviy URL — Railway'dagi mavjud webapp serverga ulanadi.
/// Bot va ilova BIR XUL server, BIR XUL DB ishlatadi.
///
/// Build vaqtida: flutter run --dart-define=API_BASE_URL=https://sizning-app.up.railway.app
library;

const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://your-app.up.railway.app',
);

/// Telegram bot username (deep-link uchun).
const kBotUsername = 'intizomAi_bot';

/// Telegram bot URL.
const kBotUrl = 'https://t.me/$kBotUsername';

/// API to'liq yo'li — /api/v1 prefiksi (webapp/app.py'dagi route prefix).
String apiUrl(String path) => '$kApiBaseUrl/api/v1$path';
