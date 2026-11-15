import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'services/appearance_store.dart';
import 'services/locale_store.dart';
import 'services/auth_store.dart';
import 'services/user_service.dart';
import 'models/user_profile.dart';
import 'screens/auth/login_page.dart';
import 'screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appearanceStore = AppearanceStore();
  final initialAppearance = await appearanceStore.load();
  final localeStore = LocaleStore();
  final initialLocale = await localeStore.load();
  final authStore = AuthStore();
  final isLoggedIn = await authStore.isLoggedIn();

  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.systemOverlay(
      initialAppearance == 'dark' ? AppTheme.dark : AppTheme.light,
    ),
  );

  runApp(
    IntizomAiApp(
      appearanceStore: appearanceStore,
      localeStore: localeStore,
      authStore: authStore,
      initialAppearance: initialAppearance,
      initialLocale: initialLocale,
      isLoggedIn: isLoggedIn,
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
    this.isLoggedIn = false,
  });

  final AppearanceStore appearanceStore;
  final LocaleStore localeStore;
  final AuthStore authStore;
  final String? initialAppearance;
  final String? initialLocale;
  final bool isLoggedIn;

  @override
  State<IntizomAiApp> createState() => _IntizomAiAppState();
}

class _IntizomAiAppState extends State<IntizomAiApp> {
  Locale? _locale;
  late ThemeMode _themeMode;
  bool _isLoggedIn = false;
  UserProfile? _profile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialAppearance == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    if (widget.initialLocale != null) {
      _locale = Locale(widget.initialLocale!);
    }
    _isLoggedIn = widget.isLoggedIn;
    if (_isLoggedIn) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await UserService().getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setTheme(String mode) {
    final next = mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == next) return;
    setState(() => _themeMode = next);
    unawaited(
      widget.appearanceStore.save(mode).catchError((Object _) {}),
    );
  }

  void _setLocale(String code) {
    final next = Locale(code);
    if (_locale == next) return;
    setState(() => _locale = next);
    unawaited(
      widget.localeStore.save(code).catchError((Object _) {}),
    );
  }

  void _onLoginSuccess() {
    setState(() => _isLoggedIn = true);
    _loadProfile();
  }

  void _onLogout() async {
    await widget.authStore.clear();
    setState(() {
      _isLoggedIn = false;
      _profile = null;
    });
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
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_isLoggedIn) {
      return LoginPage(
        onLoginSuccess: _onLoginSuccess,
        onLanguageChanged: _setLocale,
      );
    }

    if (_loading || _profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return HomePage(
      profile: _profile!,
      onLogout: _onLogout,
      onAppearanceChanged: _setTheme,
      onLanguageChanged: _setLocale,
    );
  }
}
