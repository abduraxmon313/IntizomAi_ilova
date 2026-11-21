import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../../services/api_client.dart';
import '../../services/intizom_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/ui_kit.dart';
import '../profile/profile_page.dart' show LowerCaseFormatter;

/// Birinchi kirishdan keyin — 3 ta qisqa qadam: ism → yosh → username
/// (+ ixtiyoriy "kim taklif qildi"). Har qadamda bitta savol, tugma doim
/// klaviatura ustida, xato o'sha maydonning o'zida ko'rsatiladi.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.api,
    required this.onDone,
    required this.onSignOut,
    this.initialName,
  });

  final IntizomApi api;
  final ValueChanged<Profile> onDone;
  final VoidCallback onSignOut;
  final String? initialName;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

// Server bilan bir xil cheklovlar (MIN_AGE / MAX_AGE, clean_name, USERNAME_RE).
const _minAge = 13;
const _maxAge = 100;
final _usernameRe = RegExp(r'^[a-z][a-z0-9_]{2,19}$');

class _OnboardingPageState extends State<OnboardingPage> {
  static const _steps = 3;

  late final _name = TextEditingController(text: _cleanInitial(widget.initialName));
  final _age = TextEditingController();
  final _username = TextEditingController();
  final _referrer = TextEditingController();
  final _nameFocus = FocusNode();
  final _ageFocus = FocusNode();
  final _usernameFocus = FocusNode();

  int _step = 0;

  /// Foydalanuvchi maydonga tegib, keyin "Davom etish"ni bosganmi — xato shundan keyin ko'rinadi.
  final _tried = <int>{};

  Timer? _debounce;
  UsernameCheck? _check;
  bool _checking = false;
  bool _usernameEdited = false;
  bool _saving = false;
  bool _showReferrer = false;
  String? _usernameServerError;
  String? _referrerError;
  String? _error;

  static String _cleanInitial(String? n) {
    final s = (n ?? '').trim();
    return s == 'Foydalanuvchi' || s.startsWith('@') ? '' : s;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusStep());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _age.dispose();
    _username.dispose();
    _referrer.dispose();
    _nameFocus.dispose();
    _ageFocus.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  // ── Username taklifi ───────────────────────────────────
  static const _cyr = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo', 'ж': 'j', 'з': 'z',
    'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r',
    'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'x', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sh',
    'ъ': '', 'ы': 'i', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya', 'ў': 'o', 'қ': 'q', 'ғ': 'g', 'ҳ': 'h',
  };

  /// "Ali Valiyev" → "ali_valiyev", "Алишер" → "alisher". Kirill va o'zbekcha belgilar lotinga.
  static String suggestUsername(String name) {
    final buf = StringBuffer();
    for (final ch in name.toLowerCase().split('')) {
      buf.write(_cyr[ch] ?? ch);
    }
    var s = buf.toString().replaceAll(RegExp(r"[ʻʼ’'`]"), '');
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.isEmpty || !RegExp(r'^[a-z]').hasMatch(s)) s = 'user$s';
    if (s.length > 16) s = s.substring(0, 16).replaceAll(RegExp(r'_+$'), '');
    if (s.startsWith('intizom')) s = s.replaceFirst('intizom', '').replaceAll(RegExp(r'^_+'), '');
    if (s.isEmpty || !RegExp(r'^[a-z]').hasMatch(s)) s = 'user$s';
    if (s.length < 3) s = '$s${Random().nextInt(900) + 100}';
    return s;
  }

  void _setUsername(String u, {bool edited = true}) {
    _username.value = TextEditingValue(text: u, selection: TextSelection.collapsed(offset: u.length));
    _usernameEdited = edited;
    _usernameServerError = null;
    _scheduleCheck(immediate: true);
  }

  void _scheduleCheck({bool immediate = false}) {
    _debounce?.cancel();
    final u = _username.text.trim();
    if (!_usernameRe.hasMatch(u)) {
      setState(() {
        _check = null;
        _checking = false;
      });
      return;
    }
    setState(() => _checking = true);
    _debounce = Timer(Duration(milliseconds: immediate ? 0 : 400), () async {
      try {
        final r = await widget.api.checkUsername(u);
        if (mounted && _username.text.trim() == u) setState(() => _check = r);
      } catch (_) {
        // Tarmoq yo'q — saqlashda server baribir tekshiradi.
      } finally {
        if (mounted && _username.text.trim() == u) setState(() => _checking = false);
      }
    });
  }

  // ── Tekshiruvlar (xato matni yoki null) ────────────────
  String? _nameProblem() {
    final n = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.length < 2) return context.tr("Ismingizni yozing (kamida 2 harf)");
    if (n.contains('<') || n.contains('>')) return context.tr("Ismda < va > belgilari bo'lmasin");
    return null;
  }

  String? _ageProblem() {
    final a = int.tryParse(_age.text.trim());
    if (a == null) return context.tr("Yoshingizni kiriting");
    if (a < _minAge) return context.tr("Ilovadan {v0} yoshdan foydalanish mumkin", {'v0': _minAge});
    if (a > _maxAge) return context.tr("Yoshni to'g'ri kiriting");
    return null;
  }

  String? _usernameProblem() {
    final u = _username.text.trim();
    if (u.length < 3) return context.tr("Kamida 3 ta belgi");
    if (!RegExp(r'^[a-z]').hasMatch(u)) return context.tr("Lotin harfi bilan boshlansin");
    if (!_usernameRe.hasMatch(u)) return context.tr("Faqat lotin harfi, raqam va _");
    if (u.endsWith('_') || u.contains('__')) return context.tr("_ oxirida yoki ketma-ket bo'lmasin");
    if (_usernameServerError != null) return _usernameServerError;
    final c = _check;
    if (c != null && c.username == u && !c.available) return c.reason ?? context.tr("Bu username band.");
    return null;
  }

  String? _problemFor(int step) => switch (step) {
    0 => _nameProblem(),
    1 => _ageProblem(),
    _ => _usernameProblem(),
  };

  // ── Qadamlar ───────────────────────────────────────────
  void _focusStep() {
    if (!mounted) return;
    final f = switch (_step) {
      0 => _nameFocus,
      1 => _ageFocus,
      _ => _usernameFocus,
    };
    f.requestFocus();
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    if (step == 2 && !_usernameEdited) {
      final s = suggestUsername(_name.text);
      if (s != _username.text) _setUsername(s, edited: false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusStep());
  }

  void _next() {
    setState(() => _tried.add(_step));
    if (_problemFor(_step) != null) {
      HapticFeedback.mediumImpact();
      return;
    }
    if (_step < _steps - 1) {
      tapFeedback();
      _goTo(_step + 1);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) _goTo(_step - 1);
  }

  Future<void> _submit() async {
    if (_checking) return; // natija kelgach tugma qayta faollashadi
    setState(() {
      _saving = true;
      _error = null;
      _referrerError = null;
    });
    try {
      final p = await widget.api.completeOnboarding(
        fullName: _name.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        age: int.parse(_age.text.trim()),
        username: _username.text.trim(),
        referrerUsername: !_showReferrer || _referrer.text.trim().isEmpty ? null : _referrer.text.trim(),
      );
      successFeedback();
      widget.onDone(p);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 409) {
          _usernameServerError = e.message;
          _tried.add(2);
          _scheduleCheck(immediate: true); // bo'sh variantlarni olish uchun
        } else if (e.statusCode == 404 && _showReferrer) {
          _referrerError = e.message;
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Ko'rinish ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _step == _steps - 1;
    final usernameBlocked = last && (_checking || (_check != null && !_check!.available));
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(scheme),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.lg, AppSpace.page, AppSpace.lg),
                      child: AnimatedSwitcher(
                        duration: AppMotion.base,
                        switchInCurve: AppMotion.curve,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(.04, 0), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        ),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.topLeft,
                          children: [...previous, ?current],
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: switch (_step) {
                            0 => _nameStep(scheme),
                            1 => _ageStep(scheme),
                            _ => _usernameStep(scheme),
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, AppSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(_error!, textAlign: TextAlign.center, style: AppType.label.copyWith(color: scheme.error)),
                          ),
                        FilledButton(
                          onPressed: _saving || usernameBlocked ? null : _next,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                          child: _saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(last ? context.tr("Boshlash") : context.tr("Davom etish")),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, AppSpace.page, 0),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: _step > 0
                ? IconButton(
                    tooltip: context.tr("Orqaga"),
                    onPressed: _saving ? null : _back,
                    icon: const Icon(LucideIcons.arrowLeft, size: 22),
                  )
                : const Padding(padding: EdgeInsets.only(left: 8), child: BrandMark(size: 32)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: context.tr("{v0}-qadam, jami {v1}", {'v0': _step + 1, 'v1': _steps}),
              child: Row(
                children: [
                  for (var i = 0; i < _steps; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedContainer(
                        duration: AppMotion.base,
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= _step ? scheme.primary : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: _saving ? null : widget.onSignOut,
            style: TextButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text(context.tr("Chiqish")),
          ),
        ],
      ),
    );
  }

  Widget _heading(ColorScheme scheme, IconData icon, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconTile(icon: icon, tone: scheme.primary, size: 48),
        const SizedBox(height: AppSpace.lg),
        Text(title, style: AppType.display),
        const SizedBox(height: AppSpace.sm),
        Text(subtitle, style: AppType.body.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
        const SizedBox(height: AppSpace.xl),
      ],
    );
  }

  /// Katta, bitta savolga mo'ljallangan maydon bezagi.
  InputDecoration _bigField({String? hint, String? error, Widget? prefix, Widget? suffix, String? suffixText}) {
    return InputDecoration(
      hintText: hint,
      errorText: error,
      errorMaxLines: 3,
      counterText: '',
      prefixIcon: prefix,
      suffixIcon: suffix,
      suffixText: suffixText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  static const _bigText = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -.3);

  Widget _nameStep(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          scheme,
          LucideIcons.userRound,
          context.tr("Ismingiz nima?"),
          context.tr("Profilingizda va guruhlarda do'stlaringiz shu ismni ko'radi."),
        ),
        TextField(
          controller: _name,
          focusNode: _nameFocus,
          maxLength: 60,
          style: _bigText,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: _bigField(
            hint: context.tr("Masalan: Ali Valiyev"),
            error: _tried.contains(0) ? _nameProblem() : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _next(),
        ),
      ],
    );
  }

  Widget _ageStep(ColorScheme scheme) {
    final first = _name.text.trim().split(RegExp(r'\s+')).first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          scheme,
          LucideIcons.cake,
          first.isEmpty ? context.tr("Yoshingiz nechida?") : context.tr("{v0}, yoshingiz nechida?", {'v0': first}),
          context.tr("Maslahatlarni yoshingizga moslashtirish uchun. Boshqa foydalanuvchilarga ko'rinmaydi."),
        ),
        TextField(
          controller: _age,
          focusNode: _ageFocus,
          maxLength: 3,
          style: _bigText.copyWith(fontFeatures: tabularFigures),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _bigField(
            hint: '18',
            suffixText: context.tr("yosh"),
            error: _tried.contains(1) ? _ageProblem() : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _next(),
        ),
      ],
    );
  }

  Widget _usernameStep(ColorScheme scheme) {
    final u = _username.text.trim();
    final check = _check;
    final localProblem = _usernameProblem();
    final ok = localProblem == null && check != null && check.username == u && check.available && !_checking;
    final showError = localProblem != null && (_tried.contains(2) || u.length >= 3 || _usernameServerError != null);

    Widget? suffix;
    if (_checking) {
      suffix = const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (ok) {
      suffix = const Icon(LucideIcons.circleCheck, size: 22, color: AppPalette.success);
    } else if (showError) {
      suffix = Icon(LucideIcons.circleX, size: 22, color: scheme.error);
    }

    final suggestions = <String>{
      ...?check?.suggestions,
      if (!ok && _usernameEdited) suggestUsername(_name.text),
    }.where((s) => s != u).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          scheme,
          LucideIcons.atSign,
          context.tr("Username tanlang"),
          context.tr("Do'stlaringiz sizni shu nom orqali topib, guruhga taklif qiladi. Keyin Profilda o'zgartirsa bo'ladi."),
        ),
        TextField(
          controller: _username,
          focusNode: _usernameFocus,
          maxLength: 20,
          style: _bigText,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')), LowerCaseFormatter()],
          decoration: _bigField(
            hint: 'username',
            suffix: suffix,
            error: showError ? localProblem : null,
          ).copyWith(prefixText: '@', prefixStyle: _bigText.copyWith(color: scheme.onSurfaceVariant)),
          onChanged: (_) {
            _usernameEdited = true;
            _usernameServerError = null;
            _scheduleCheck();
          },
          onSubmitted: (_) => _next(),
        ),
        if (ok)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              context.tr("@{v0} bo'sh — sizniki bo'lishi mumkin", {'v0': u}),
              style: AppType.caption.copyWith(color: AppPalette.success, fontWeight: FontWeight.w600),
            ),
          )
        else if (!showError)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              context.tr("3–20 belgi: lotin harfi, raqam va _ . Harf bilan boshlansin."),
              style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
            ),
          ),
        if (suggestions.isNotEmpty && !ok) ...[
          const SizedBox(height: 14),
          Text(context.tr("Bo'sh variantlar"), style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text('@$s'),
                  onPressed: () {
                    tapFeedback();
                    _setUsername(s);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        _preview(scheme, u, ok),
        const SizedBox(height: AppSpace.md),
        if (!_showReferrer)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showReferrer = true),
              icon: const Icon(LucideIcons.gift, size: 16),
              label: Text(context.tr("Meni do'stim taklif qildi")),
            ),
          )
        else ...[
          FieldLabel(context.tr("Taklif qilgan do'stning username'i")),
          TextField(
            controller: _referrer,
            maxLength: 20,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')), LowerCaseFormatter()],
            decoration: InputDecoration(
              prefixText: '@',
              counterText: '',
              hintText: context.tr("ixtiyoriy"),
              errorText: _referrerError,
              suffixIcon: IconButton(
                tooltip: context.tr("Olib tashlash"),
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: () => setState(() {
                  _referrer.clear();
                  _referrerError = null;
                  _showReferrer = false;
                }),
              ),
            ),
            onChanged: (_) {
              if (_referrerError != null) setState(() => _referrerError = null);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              context.tr("Do'stingiz bonus oladi. Bilmasangiz — bo'sh qoldiring."),
              style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ],
    );
  }

  /// Profil kartasi qanday ko'rinishi — ism + username jonli.
  Widget _preview(ColorScheme scheme, String u, bool ok) {
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      decoration: surfaceDecoration(context, color: scheme.surfaceContainerLow),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Text(initial, style: AppType.heading.copyWith(color: scheme.onPrimaryContainer)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  u.isEmpty ? '@username' : '@$u',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(color: ok ? scheme.tertiary : scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(context.tr("Profilingiz"), style: AppType.caption.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
