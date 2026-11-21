/// Reyting qatori — /api/webapp/leaderboard.
class LeaderRow {
  const LeaderRow({
    required this.rank,
    required this.name,
    this.photoUrl,
    this.value = 0,
    this.isMe = false,
  });

  final int rank;
  final String name;
  final String? photoUrl; // nisbiy yo'l (/api/v1/avatars/...) yoki to'liq URL
  final int value;
  final bool isMe;

  factory LeaderRow.fromJson(Map<String, dynamic> j) => LeaderRow(
    rank: j['rank'] as int? ?? 0,
    name: j['name'] as String? ?? '',
    photoUrl: j['photo_url'] as String?,
    value: j['value'] as int? ?? 0,
    isMe: j['is_me'] as bool? ?? false,
  );
}

class Leaderboard {
  const Leaderboard({this.top = const [], this.me, this.meInTop = true});
  final List<LeaderRow> top;
  final LeaderRow? me;
  final bool meInTop;

  factory Leaderboard.fromJson(Map<String, dynamic> j) {
    final me = j['me'] is Map ? Map<String, dynamic>.from(j['me'] as Map) : null;
    return Leaderboard(
      top: (j['top'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => LeaderRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      me: me == null ? null : LeaderRow.fromJson({...me, 'is_me': true}),
      meInTop: me?['in_top'] as bool? ?? true,
    );
  }
}

/// Kunlik kayfiyat / energiya — /api/webapp/checkin.
class Checkin {
  const Checkin({this.mood, this.energy});
  final String? mood; // 🔥 💪 😐 😴 😞
  final int? energy; // 1..5

  factory Checkin.fromJson(Map<String, dynamic> j) =>
      Checkin(mood: j['mood'] as String?, energy: j['energy'] as int?);
}

/// Obuna holati va tariflar — /api/v1/subscription.
class Subscription {
  const Subscription({
    this.isPremium = false,
    this.premiumUntil,
    this.daysLeft = 0,
    this.planTitle,
    this.plans = const [],
    this.providers = const [],
    this.promo,
    this.paymentsEnabled = false,
    this.freeLimits = const FreeLimits(),
  });

  final bool isPremium;
  final String? premiumUntil;
  final int daysLeft;
  final String? planTitle;
  final List<PricePlan> plans;
  final List<PayProvider> providers;
  final PromoInfo? promo;
  final bool paymentsEnabled;
  final FreeLimits freeLimits;

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
    isPremium: j['is_premium'] as bool? ?? false,
    premiumUntil: j['premium_until'] as String?,
    daysLeft: j['days_left'] as int? ?? 0,
    planTitle: j['plan_title'] as String?,
    plans: (j['plans'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => PricePlan.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    providers: (j['providers'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => PayProvider.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    promo: j['promo'] is Map ? PromoInfo.fromJson(Map<String, dynamic>.from(j['promo'] as Map)) : null,
    paymentsEnabled: j['payments_enabled'] as bool? ?? false,
    freeLimits: j['free_limits'] is Map
        ? FreeLimits.fromJson(Map<String, dynamic>.from(j['free_limits'] as Map))
        : const FreeLimits(),
  );
}

/// Bepul tarif cheklovlari (server sozlamasi) — Premium oynasidagi solishtirish uchun.
class FreeLimits {
  const FreeLimits({this.plansPerDay = 5, this.habits = 3, this.goals = 3, this.aiPerDay = 3});
  final int plansPerDay;
  final int habits;
  final int goals;
  final int aiPerDay;

  factory FreeLimits.fromJson(Map<String, dynamic> j) => FreeLimits(
    plansPerDay: j['plans_per_day'] as int? ?? 5,
    habits: j['habits'] as int? ?? 3,
    goals: j['goals'] as int? ?? 3,
    aiPerDay: j['ai_per_day'] as int? ?? 3,
  );
}

class PricePlan {
  const PricePlan({
    required this.key,
    required this.title,
    required this.days,
    required this.price,
    required this.priceLabel,
    this.monthlyLabel,
    this.tag,
    this.originalPriceLabel,
  });

  final String key;
  final String title;
  final int days;
  final int price;
  final String priceLabel;
  final String? monthlyLabel;
  final String? tag;
  final String? originalPriceLabel;

  factory PricePlan.fromJson(Map<String, dynamic> j) => PricePlan(
    key: j['key'] as String? ?? '',
    title: j['title'] as String? ?? '',
    days: j['days'] as int? ?? 0,
    price: j['price'] as int? ?? 0,
    priceLabel: j['price_label'] as String? ?? '',
    monthlyLabel: j['monthly_label'] as String?,
    tag: j['tag'] as String?,
    originalPriceLabel: j['original_price_label'] as String?,
  );
}

class PayProvider {
  const PayProvider({required this.key, required this.title});
  final String key;
  final String title;

  factory PayProvider.fromJson(Map<String, dynamic> j) =>
      PayProvider(key: j['key'] as String? ?? '', title: j['title'] as String? ?? '');
}

class PromoInfo {
  const PromoInfo({required this.code, this.valid = false, this.isFree = false, this.discountPercent = 0, this.bonusDays = 0, this.planKeys});
  final String code;
  final bool valid;
  final bool isFree;
  final int discountPercent;
  final int bonusDays;

  /// Faqat shu tariflarga amal qiladi (null — hammasiga).
  final List<String>? planKeys;

  factory PromoInfo.fromJson(Map<String, dynamic> j) => PromoInfo(
    code: j['code'] as String? ?? '',
    valid: j['valid'] as bool? ?? false,
    isFree: j['is_free'] as bool? ?? false,
    discountPercent: j['discount_percent'] as int? ?? 0,
    bonusDays: j['bonus_days'] as int? ?? 0,
    planKeys: (j['plan_keys'] as List?)?.whereType<String>().toList(),
  );
}

/// To'lov buyurtmasi — /api/v1/payments/...
class PaymentOrder {
  const PaymentOrder({
    required this.orderId,
    required this.status,
    this.checkoutUrl,
    this.amountLabel,
    this.days,
    this.subscription,
  });

  final String orderId;

  /// creating | pending | paid | cancelled | failed
  final String status;
  final String? checkoutUrl;
  final String? amountLabel;
  final int? days;
  final Subscription? subscription;

  bool get isPaid => status == 'paid';
  bool get isFinal => status == 'paid' || status == 'cancelled' || status == 'failed';

  factory PaymentOrder.fromJson(Map<String, dynamic> j) => PaymentOrder(
    orderId: j['order_id'] as String? ?? '',
    status: j['status'] as String? ?? 'pending',
    checkoutUrl: j['checkout_url'] as String?,
    amountLabel: j['amount_label'] as String?,
    days: j['days'] as int?,
    subscription: j['subscription'] is Map
        ? Subscription.fromJson(Map<String, dynamic>.from(j['subscription'] as Map))
        : null,
  );
}

/// Admin paneldan yozilgan e'lon — /api/v1/announcements. «Bugun» sahifasida ko'rinadi.
class Announcement {
  const Announcement({required this.id, required this.title, required this.body, this.buttonLabel, this.buttonUrl});

  final int id;
  final String title;
  final String body;
  final String? buttonLabel;
  final String? buttonUrl;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
    id: j['id'] as int? ?? 0,
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    buttonLabel: j['button_label'] as String?,
    buttonUrl: j['button_url'] as String?,
  );
}
