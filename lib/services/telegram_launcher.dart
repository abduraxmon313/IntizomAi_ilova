import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Bot qayerda ochilishi.
enum TelegramTarget {
  /// Rasmiy Telegram (`t.me` havolasi). Androidda tizim klientlar orasidan
  /// tanlash oynasini o'zi ko'rsatadi.
  telegram,

  /// Telegram asosidagi boshqa ilova (Nicegram, Swiftgram, Ayugram, Novagram…)
  /// — `tg://` sxemasi orqali.
  otherApp,

  /// Telegram Web (brauzerda).
  web,
}

/// Telefonda topilgan Telegram ilovalari.
class TelegramApps {
  const TelegramApps({required this.anyApp, this.otherApps = const []});

  /// `tg://` ni ochadigan kamida bitta ilova bor.
  final bool anyApp;

  /// Alohida aniqlangan muqobil klientlar (faqat iOS).
  final List<String> otherApps;
}

/// Botni Telegram ilovasida yoki Telegram Web'da ochadi.
///
/// iOS'da tizim tanlash oynasi yo'q: `t.me` faqat rasmiy Telegram'da ochiladi,
/// `tg://` ni esa bir nechta klient egallagan bo'lsa iOS o'zi bittasini tanlaydi.
/// Muqobil klientlar faqat o'z sxemasi bilan aniqlanadi (Info.plist →
/// LSApplicationQueriesSchemes). Novagram iOS'da faqat `tg`/`telegram`
/// sxemasini ro'yxatdan o'tkazgan, shuning uchun uni alohida aniqlab bo'lmaydi.
class TelegramLauncher {
  const TelegramLauncher();

  static const _iosClients = <String, String>{
    'nicegram': 'Nicegram',
    'sg': 'Swiftgram / Ayugram',
  };

  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Uri tgUri([String? start]) => Uri(
    scheme: 'tg',
    host: 'resolve',
    queryParameters: {'domain': kBotUsername, 'start': ?start},
  );

  static Uri webUri([String? start]) =>
      Uri.parse('https://web.telegram.org/k/#?tgaddr=${Uri.encodeComponent(tgUri(start).toString())}');

  Future<TelegramApps> detect() async {
    final anyApp = await _can(tgUri());
    if (!anyApp || !_isIOS) return TelegramApps(anyApp: anyApp);
    final others = <String>[];
    for (final e in _iosClients.entries) {
      if (await _can(Uri.parse('${e.key}://'))) others.add(e.value);
    }
    return TelegramApps(anyApp: true, otherApps: others);
  }

  /// Ochilmasa keyingi variantga o'tadi: Telegram → boshqa ilova → Web.
  Future<bool> open(TelegramTarget target, [String? start]) async {
    // iOS: faqat Universal Link (rasmiy Telegram); Android: brauzer emas, ilova.
    if (target == TelegramTarget.telegram &&
        await _launch(botUri(start), LaunchMode.externalNonBrowserApplication)) {
      return true;
    }
    if (target != TelegramTarget.web &&
        await _launch(tgUri(start), LaunchMode.externalApplication)) {
      return true;
    }
    return _launch(webUri(start), LaunchMode.externalApplication);
  }

  static Future<bool> _can(Uri uri) async {
    try {
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _launch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }
}
