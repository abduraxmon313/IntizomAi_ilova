/// Sana yordamchilari. Server Toshkent vaqtida ishlaydi (UTC+5).
library;

const uzMonths = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
];
const uzMonthsShort = ['Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyn', 'Iyl', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek'];
const uzWeekdaysShort = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];
const uzWeekdays = ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'];

/// Toshkent bo'yicha bugungi sana (soatsiz).
DateTime tashkentToday() {
  final t = DateTime.now().toUtc().add(const Duration(hours: 5));
  return DateTime(t.year, t.month, t.day);
}

/// Toshkent bo'yicha hozirgi vaqt "HH:MM".
String tashkentHm() {
  final t = DateTime.now().toUtc().add(const Duration(hours: 5));
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseYmd(String? s) {
  if (s == null || s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Dushanba, 15 noyabr"
String longDate(DateTime d) => '${uzWeekdays[d.weekday - 1]}, ${d.day} ${uzMonths[d.month - 1].toLowerCase()}';

/// "15 noy"
String shortDate(DateTime d) => '${d.day} ${uzMonthsShort[d.month - 1].toLowerCase()}';

/// Haftaning dushanbasi.
DateTime weekStart(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));

/// Bugun / Ertaga / Kecha yoki to'liq sana.
String relativeDay(DateTime d) {
  final t = tashkentToday();
  final diff = dateOnly(d).difference(t).inDays;
  if (diff == 0) return 'Bugun';
  if (diff == 1) return 'Ertaga';
  if (diff == -1) return 'Kecha';
  return longDate(d);
}
