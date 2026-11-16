import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'catalog.dart';

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

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _Delegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  String get languageCode => locale.languageCode;

  String text(String key, [Map<String, Object?>? values]) {
    final map = _translations[languageCode];
    final entry = interfaceTranslations[key];
    String result = (languageCode == 'ru' ? entry?.$1 : languageCode == 'en' ? entry?.$2 : null)
        ?? map?[key] ?? key;
    if (values != null) {
      result = result.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) =>
        values.containsKey(match[1]) ? '${values[match[1]] ?? ''}' : match[0]!);
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
      'AI Coach': 'AI Коуч',
      'Ajoyib natija! Siz haqiqiy intizomli insonsiz.': 'Отличный результат! Вы по-настоящему дисциплинированы.',
      'Ball': 'Баллы',
      'Bot eslatmalari': 'Напоминания бота',
      'Botda «Tasdiqlash» tugmasini bosasiz — ilova o\'zi ochiladi.': 'Нажмите «Подтвердить» в боте — приложение откроется само.',
      'Botda «✅ Ilovaga kirishni tasdiqlash» tugmasini bosing, so\'ng shu yerga qayting.': 'Нажмите в боте кнопку «✅ Подтвердить вход», затем вернитесь сюда.',
      'Bugun dam': 'Сегодня отдых',
      'Bugun qolgan bepul xabarlar: {n}': 'Осталось бесплатных сообщений сегодня: {n}',
      'Bugungi topshiriq': 'Задание дня',
      'Cheksiz reja, odat, maqsad va AI Coach. To\'lov bot orqali.': 'Безлимитные планы, привычки, цели и AI Коуч. Оплата через бота.',
      'Do\'stlarni taklif qilish': 'Пригласить друзей',
      'Eng uzun streak': 'Самая длинная серия',
      'Eslatma vaqti (ixtiyoriy)': 'Время напоминания (необязательно)',
      'Har kuni kichik qadam katta natija beradi.': 'Маленький шаг каждый день даёт большой результат.',
      'Intizom kuchi': 'Сила дисциплины',
      'Maqsad nomi': 'Название цели',
      'Mukammal kunlar': 'Идеальные дни',
      'Nima qilmoqchisiz?': 'Что планируете сделать?',
      'O\'chirilsinmi?': 'Удалить?',
      'O\'rta holat. Bugun bir qadam oldinga!': 'Средний уровень. Сегодня — шаг вперёд!',
      'Odat nomi': 'Название привычки',
      'Premium faol — uzaytirish bot orqali': 'Премиум активен — продление через бота',
      'Premium olish (bot orqali)': 'Получить Премиум (через бота)',
      'Rejalaringiz, odatlaringiz va streakingizni biladi. Savol bering.': 'Знает ваши планы, привычки и серию. Задайте вопрос.',
      'Taklif havolasi nusxalandi': 'Ссылка-приглашение скопирована',
      'Taklif qilinganlar: {n}': 'Приглашено: {n}',
      'Telegram\'ni qayta ochish': 'Открыть Telegram снова',
      'Vaqt (ixtiyoriy)': 'Время (необязательно)',
      'Yaxshi yo\'ldasiz. Davom eting!': 'Вы на верном пути. Продолжайте!',
      'daraja': 'уровень',
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
      'AI Coach': 'AI Coach',
      'Ajoyib natija! Siz haqiqiy intizomli insonsiz.': 'Great result! You are truly disciplined.',
      'Ball': 'Points',
      'Bot eslatmalari': 'Bot reminders',
      'Botda «Tasdiqlash» tugmasini bosasiz — ilova o\'zi ochiladi.': 'Tap «Confirm» in the bot and the app opens by itself.',
      'Botda «✅ Ilovaga kirishni tasdiqlash» tugmasini bosing, so\'ng shu yerga qayting.': 'Tap «✅ Confirm app sign-in» in the bot, then come back here.',
      'Bugun dam': 'Rest day',
      'Bugun qolgan bepul xabarlar: {n}': 'Free messages left today: {n}',
      'Bugungi topshiriq': 'Today\'s quest',
      'Cheksiz reja, odat, maqsad va AI Coach. To\'lov bot orqali.': 'Unlimited plans, habits, goals and AI Coach. Payment via the bot.',
      'Do\'stlarni taklif qilish': 'Invite friends',
      'Eng uzun streak': 'Longest streak',
      'Eslatma vaqti (ixtiyoriy)': 'Reminder time (optional)',
      'Har kuni kichik qadam katta natija beradi.': 'A small step every day brings big results.',
      'Intizom kuchi': 'Discipline score',
      'Maqsad nomi': 'Goal name',
      'Mukammal kunlar': 'Perfect days',
      'Nima qilmoqchisiz?': 'What do you plan to do?',
      'O\'chirilsinmi?': 'Delete?',
      'O\'rta holat. Bugun bir qadam oldinga!': 'Average. Take one step forward today!',
      'Odat nomi': 'Habit name',
      'Premium faol — uzaytirish bot orqali': 'Premium active — renew via the bot',
      'Premium olish (bot orqali)': 'Get Premium (via the bot)',
      'Rejalaringiz, odatlaringiz va streakingizni biladi. Savol bering.': 'Knows your plans, habits and streak. Ask a question.',
      'Taklif havolasi nusxalandi': 'Invite link copied',
      'Taklif qilinganlar: {n}': 'Invited: {n}',
      'Telegram\'ni qayta ochish': 'Open Telegram again',
      'Vaqt (ixtiyoriy)': 'Time (optional)',
      'Yaxshi yo\'ldasiz. Davom eting!': 'You are on the right track. Keep going!',
      'daraja': 'level',
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
  String tr(String key, [Map<String, Object?>? values]) =>
      AppLocalizations.of(this).text(key, values);
}
