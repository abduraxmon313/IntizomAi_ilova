/// Ilova ichidagi Premium sotuvi sozlamasi.
///
/// Obuna ilova ichida (Paylov orqali) sotiladi — iOS va Android'da bir xil.
/// Agar biror do'kon talab qilsa, sotuv tugmalarini build vaqtida o'chirish mumkin:
/// `--dart-define=HIDE_PURCHASES=true` (qayta yig'ish kifoya, kod o'zgarmaydi).
class StorePolicy {
  StorePolicy._();

  static const _hide = bool.fromEnvironment('HIDE_PURCHASES');

  /// Premium sotuvchi tugma/narxlarni ko'rsatish mumkinmi?
  static bool get purchasesVisible => !_hide;
}
