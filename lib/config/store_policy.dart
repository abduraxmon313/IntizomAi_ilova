import 'package:flutter/foundation.dart';

/// Ilova ichidagi Premium sotuvi sozlamasi.
///
/// Qaror serverda: `GET /profile` → `purchases_visible`. iOS'da u Railway'dagi
/// `APPLE_PREMIUM` o'zgaruvchisiga bog'liq (false bo'lsa narx, obuna va promokod
/// ko'rinmaydi, limitlar esa server tomonida olib tashlanadi). Android'da doim ko'rinadi.
///
/// Server javobi kelguncha iOS'da sotuv yashirin turadi (xavfsiz standart).
/// Build vaqtida butunlay o'chirish ham mumkin: `--dart-define=HIDE_PURCHASES=true`.
class StorePolicy {
  StorePolicy._();

  static const _hide = bool.fromEnvironment('HIDE_PURCHASES');

  static bool? _server;

  /// Server qiymatini saqlaydi (profil yuklanganda chaqiriladi).
  static void updateFromServer(bool? visible) => _server = visible;

  /// Premium sotuvchi tugma/narxlarni ko'rsatish mumkinmi?
  static bool get purchasesVisible {
    if (_hide) return false;
    return _server ?? defaultTargetPlatform != TargetPlatform.iOS;
  }
}
