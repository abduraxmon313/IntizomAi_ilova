import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/language_page.dart';
import 'screens/auth/notification_permission_page.dart';
import 'screens/home_page.dart';
import 'services/api_client.dart';
import 'services/appearance_store.dart';
import 'services/auth_service.dart';
import 'services/auth_store.dart';
import 'services/intizom_api.dart';
import 'services/locale_store.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearanceStore = AppearanceStore();
  final localeStore = LocaleStore();
  final authStore = AuthStore();

  final initialAppearance = await appearanceStore.load();
  final initialLocale = await localeStore.load();
  final loggedIn = await authStore.isLoggedIn();
  await ReminderService.instance.init();
  final askReminders = loggedIn && await ReminderService.instance.needsPrompt(afterLogin: false);

  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.systemOverlay(initialAppearance == 'dark' ? AppTheme.dark : AppTheme.light),
  );

  runApp(
    IntizomAiApp(
      appearanceStore: appearanceStore,
      localeStore: localeStore,
      authStore: authStore,
      initialAppearance: initialAppearance,
      initialLocale: initialLocale,
      loggedIn: loggedIn,
      askReminders: askReminders,
    ),
  );
}

class IntizomAiApp extends StatefulWidget {
  const IntizomAiApp({
    super.key,
    required this.appearanceStore,
    required this.localeStore,
    required this.authStore,
    this.initialAppearance,
    this.initialLocale,
    this.loggedIn = false,
    this.askReminders = false,
  });

  final AppearanceStore appearanceStore;
  final LocaleStore localeStore;
  final AuthStore authStore;
  final String? initialAppearance;
  final String? initialLocale;
  final bool loggedIn;
  final bool askReminders;

  @override
  State<IntizomAiApp> createState() => _IntizomAiAppState();
}

class _IntizomAiAppState extends State<IntizomAiApp> {
  late ThemeMode _themeMode;
  Locale? _locale;
  late bool _loggedIn;
  late bool _askReminders;

  late final ApiClient _client;
  late final AuthService _auth;
  late final IntizomApi _api;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialAppearance == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _locale = widget.initialLocale == null ? null : Locale(widget.initialLocale!);
    _loggedIn = widget.loggedIn;
    _askReminders = widget.askReminders;

    _client = ApiClient(authStore: widget.authStore);
    _auth = AuthService(api: _client, store: widget.authStore);
    _api = IntizomApi(client: _client);

    // Token eskirsa (401) — login sahifasiga qaytamiz.
    ApiClient.onUnauthorized = () {
      if (mounted && _loggedIn) setState(() => _loggedIn = false);
    };
  }

  void _setTheme(String mode) {
    final next = mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    if (next == _themeMode) return;
    setState(() => _themeMode = next);
    unawaited(widget.appearanceStore.save(mode).catchError((Object _) {}));
  }

  void _setLocale(String code) {
    if (_locale?.languageCode == code) return;
    setState(() => _locale = Locale(code));
    unawaited(widget.localeStore.save(code).catchError((Object _) {}));
  }

  Future<void> _onLoginSuccess() async {
    await ApiClient.clearCache(); // yangi hisob — eski saqlangan ma'lumotni tozalaymiz
    final ask = await ReminderService.instance.needsPrompt(afterLogin: true);
    if (mounted) {
      setState(() {
        _loggedIn = true;
        _askReminders = ask;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    await ReminderService.instance.cancelAll();
    await ApiClient.clearCache();
    if (mounted) setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntizomAI',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      themeAnimationDuration: const Duration(milliseconds: 220),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemOverlay(Theme.of(context)),
        child: child!,
      ),
      home: _locale == null
          ? LanguagePage(onSelected: _setLocale)
          : _loggedIn && _askReminders
          ? NotificationPermissionPage(
              key: const ValueKey('reminders'),
              onDone: () => setState(() => _askReminders = false),
            )
          : _loggedIn
          ? HomePage(
              key: const ValueKey('home'),
              api: _api,
              onLogout: _logout,
              onAppearanceChanged: _setTheme,
              onLanguageChanged: _setLocale,
            )
          : LoginPage(
              key: const ValueKey('login'),
              authService: _auth,
              onLoginSuccess: _onLoginSuccess,
              onLanguageChanged: _setLocale,
            ),
    );
  }
}
