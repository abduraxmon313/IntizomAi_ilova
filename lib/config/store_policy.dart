import 'package:flutter/foundation.dart';

/// App Store qoidalariga moslik.
///
/// Apple Guideline 3.1.1: ilova raqamli kontent/obuna uchun ilovadan TASHQARI
/// to'lov usuliga (bu yerda — Telegram bot orqali Premium) yo'naltiruvchi
/// tugma, havola yoki narx ko'rsata olmaydi.
///
/// Shu sababli iOS'da Premium sotuvchi CTA'lar (bot havolasi, "Tarifni tanlash",
/// narxlar) yashiriladi — qulflangan imkoniyat neytral tarzda tushuntiriladi.
/// Android'da (Google Play bu masalada yumshoqroq) hammasi avvalgidek ko'rinadi.
class StorePolicy {
  StorePolicy._();

  /// Premium sotuvchi havola/tugmalarni ko'rsatish mumkinmi?
  static bool get purchasesVisible => defaultTargetPlatform != TargetPlatform.iOS;
}
