import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// IntizomAI localization — qo'lda tarjima (MyFit uslubida).
/// Kalit so'zlar o'zbekcha yoziladi, shu kalit = uz tarjima.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('uz'));
  }

  static const supportedLocales = [Locale('uz'), Locale('ru'), Locale('en')];

  static const localizationsDelegates = [
    _Delegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  String get languageCode => locale.languageCode;

  String text(String key, [Map<String, Object>? values]) {
    final map = _translations[languageCode];
    String result = map?[key] ?? _translations['uz']?[key] ?? key;
    if (values != null) {
      for (final entry in values.entries) {
        result = result.replaceAll('{${entry.key}}', '${entry.value}');
      }
    }
    return result;
  }

  static const Map<String, Map<String, String>> _translations = {
    'uz': {}, // Kalit o'zi uz tarjima
    'ru': {
      'Bosh sahifa': 'Главная',
      'Rejalar': 'Планы',
      'Odatlar': 'Привычки',
      'Maqsadlar': 'Цели',
      'Coach': 'Коуч',
      'Profil': 'Профиль',
      'Sozlamalar': 'Настройки',
      'Bugun': 'Сегодня',
      'Streak': 'Серия',
      'Daraja': 'Уровень',
      'Intizom': 'Дисциплина',
      'Haftalik XP': 'Недельный XP',
      'Yutuqlar': 'Достижения',
      'Yangi reja': 'Новый план',
      'Yangi odat': 'Новая привычка',
      'Yangi maqsad': 'Новая цель',
      'Bajarildi': 'Выполнено',
      'Kutilmoqda': 'В ожидании',
      'Bajarilmadi': 'Не выполнено',
      'Kundalik': 'Ежедневно',
      'Haftalik': 'Еженедельно',
      'Yillik': 'Годовые',
      'Oylik': 'Месячные',
      'Telegram orqali kirish': 'Войти через Telegram',
      'IntizomAI ilovasiga xush kelibsiz!': 'Добро пожаловать в IntizomAI!',
      'O\'z intizomingizni nazorat qiling': 'Контролируйте свою дисциплину',
      'Chiqish': 'Выйти',
      'Yorug\'': 'Светлая',
      'Qorong\'i': 'Тёмная',
      'Til': 'Язык',
      'Ko\'rinish': 'Оформление',
      'Premium': 'Премиум',
      'Premium olish': 'Получить Премиум',
      'Bot orqali Premium': 'Премиум через бота',
      'Bildirishnomalar': 'Уведомления',
      'Ism': 'Имя',
      'Saqlash': 'Сохранить',
      'Bekor qilish': 'Отмена',
      'O\'chirish': 'Удалить',
      'Ha': 'Да',
      'Yo\'q': 'Нет',
      'Xatolik yuz berdi': 'Произошла ошибка',
      'Qayta urinish': 'Повторить попытку',
      'Yuklanyapti...': 'Загрузка...',
      'Bo\'sh': 'Пусто',
      'Hozircha rejalar yo\'q': 'Пока нет планов',
      'Hozircha odatlar yo\'q': 'Пока нет привычек',
      'Hozircha maqsadlar yo\'q': 'Пока нет целей',
      'AI bilan reja yozish': 'Написать план с AI',
      'Xabar yozing...': 'Напишите сообщение...',
      'kun': 'дн',
      'ball': 'балл',
      'Reyting': 'Рейтинг',
      'Ertaga ko\'chirish': 'Перенести на завтра',
      'Bugungi natijalar': 'Результаты сегодня',
      'Assalomu alaykum': 'Здравствуйте',
    },
    'en': {
      'Bosh sahifa': 'Home',
      'Rejalar': 'Plans',
      'Odatlar': 'Habits',
      'Maqsadlar': 'Goals',
      'Coach': 'Coach',
      'Profil': 'Profile',
      'Sozlamalar': 'Settings',
      'Bugun': 'Today',
      'Streak': 'Streak',
      'Daraja': 'Level',
      'Intizom': 'Discipline',
      'Haftalik XP': 'Weekly XP',
      'Yutuqlar': 'Achievements',
      'Yangi reja': 'New plan',
      'Yangi odat': 'New habit',
      'Yangi maqsad': 'New goal',
      'Bajarildi': 'Done',
      'Kutilmoqda': 'Pending',
      'Bajarilmadi': 'Failed',
      'Kundalik': 'Daily',
      'Haftalik': 'Weekly',
      'Yillik': 'Yearly',
      'Oylik': 'Monthly',
      'Telegram orqali kirish': 'Sign in with Telegram',
      'IntizomAI ilovasiga xush kelibsiz!': 'Welcome to IntizomAI!',
      'O\'z intizomingizni nazorat qiling': 'Take control of your discipline',
      'Chiqish': 'Sign out',
      'Yorug\'': 'Light',
      'Qorong\'i': 'Dark',
      'Til': 'Language',
      'Ko\'rinish': 'Appearance',
      'Premium': 'Premium',
      'Premium olish': 'Get Premium',
      'Bot orqali Premium': 'Premium via bot',
      'Bildirishnomalar': 'Notifications',
      'Ism': 'Name',
      'Saqlash': 'Save',
      'Bekor qilish': 'Cancel',
      'O\'chirish': 'Delete',
      'Ha': 'Yes',
      'Yo\'q': 'No',
      'Xatolik yuz berdi': 'Something went wrong',
      'Qayta urinish': 'Try again',
      'Yuklanyapti...': 'Loading...',
      'Bo\'sh': 'Empty',
      'Hozircha rejalar yo\'q': 'No plans yet',
      'Hozircha odatlar yo\'q': 'No habits yet',
      'Hozircha maqsadlar yo\'q': 'No goals yet',
      'AI bilan reja yozish': 'Create plan with AI',
      'Xabar yozing...': 'Write a message...',
      'kun': 'days',
      'ball': 'pts',
      'Reyting': 'Leaderboard',
      'Ertaga ko\'chirish': 'Move to tomorrow',
      'Bugungi natijalar': 'Today\'s results',
      'Assalomu alaykum': 'Hello',
    },
  };
}

class _Delegate extends LocalizationsDelegate<AppLocalizations> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_Delegate old) => false;
}

/// Qisqa yordamchi — context.tr('Rejalar').
extension AppLocalizationsX on BuildContext {
  String tr(String key, [Map<String, Object>? values]) =>
      AppLocalizations.of(this).text(key, values);
}
