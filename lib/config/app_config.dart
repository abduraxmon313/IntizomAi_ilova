/// IntizomAI ilova konfiguratsiyasi.
///
/// Railway backend API bazaviy URL'i. Ishlab chiqishda localhost,
/// production'da Railway URL ishlatiladi.
library;

const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://your-app.up.railway.app',
);

/// Telegram bot username (deep-link uchun).
const kBotUsername = 'intizomAi_bot';

/// Telegram bot URL.
const kBotUrl = 'https://t.me/$kBotUsername';

/// API versiyasi.
const kApiVersion = 'v1';

/// API to'liq yo'li.
String apiUrl(String path) => '$kApiBaseUrl/api/$kApiVersion$path';
