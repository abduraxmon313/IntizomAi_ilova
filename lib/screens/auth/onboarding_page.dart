import 'dart:async';
import 'dart:math';

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

/// Birinchi kirishdan keyin: ism, yosh, username va (ixtiyoriy) taklif qilgan do'st.
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

class _OnboardingPageState extends State<OnboardingPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _cleanInitial(widget.initialName));
  final _age = TextEditingController();
  final _username = TextEditingController();
  final _referrer = TextEditingController();

  Timer? _debounce;
  UsernameCheck? _check;
  bool _checking = false;
  bool _saving = false;
  bool _showReferrer = false;
  String? _error;

  static String _cleanInitial(String? n) {
    final s = (n ?? '').trim();
    return s == 'Foydalanuvchi' || s.startsWith('@') ? '' : s;
  }

  @override
  void initState() {
    super.initState();
    if (_name.text.isNotEmpty) {
      _username.text = _suggest(_name.text);
      _scheduleCheck();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _age.dispose();
    _username.dispose();
    _referrer.dispose();
    super.dispose();
  }

  /// "Ali Valiyev" → "ali_valiyev" (+ 2 raqam, agar qisqa bo'lsa).
  static String _suggest(String name) {
    const map = {"o'": 'o', "g'": 'g', 'sh': 'sh', 'ch': 'ch', "'": '', 'ʻ': '', '’': ''};
    var s = name.toLowerCase();
    map.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.isEmpty || !RegExp(r'^[a-z]').hasMatch(s)) s = 'user$s';
    if (s.length > 16) s = s.substring(0, 16).replaceAll(RegExp(r'_+$'), '');
    if (s.length < 5) s = '$s${Random().nextInt(90) + 10}';
    return s;
  }

  void _scheduleCheck() {
    _debounce?.cancel();
    final u = _username.text.trim();
    if (u.length < 3) {
      setState(() => _check = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _checking = true);
      try {
        final r = await widget.api.checkUsername(u);
        if (mounted && _username.text.trim() == u) setState(() => _check = r);
      } catch (_) {
        // Tarmoq yo'q — saqlashda server baribir tekshiradi.
      } finally {
        if (mounted) setState(() => _checking = false);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_check != null && !_check!.available) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final p = await widget.api.completeOnboarding(
        fullName: _name.text.trim(),
        age: int.parse(_age.text.trim()),
        username: _username.text.trim(),
        referrerUsername: _referrer.text.trim().isEmpty ? null : _referrer.text.trim(),
      );
      successFeedback();
      widget.onDone(p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final check = _check;
    Widget? usernameSuffix;
    if (_checking) {
      usernameSuffix = const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (check != null) {
      usernameSuffix = Icon(
        check.available ? LucideIcons.circleCheck : LucideIcons.circleX,
        size: 20,
        color: check.available ? AppPalette.success : scheme.error,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.xl, AppSpace.page, AppSpace.xl),
                children: [
                  const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 48)),
                  const SizedBox(height: AppSpace.lg),
                  Text(context.tr("Keling, tanishamiz"), style: AppType.display),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    context.tr("Bu ma'lumotlar profilingizda ko'rinadi. Username orqali do'stlaringiz sizni guruhga taklif qiladi."),
                    style: AppType.body.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                  ),
                  FieldLabel(context.tr("Ismingiz")),
                  TextFormField(
                    controller: _name,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: InputDecoration(hintText: context.tr("Masalan: Ali Valiyev"), counterText: ''),
                    onChanged: (v) {
                      if (_check == null && _username.text.isEmpty && v.trim().length >= 2) {
                        _username.text = _suggest(v);
                        _scheduleCheck();
                      }
                    },
                    validator: (v) => (v ?? '').trim().length < 2 ? context.tr("Ismingizni yozing") : null,
                  ),
                  FieldLabel(context.tr("Yoshingiz")),
                  TextFormField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(hintText: '18', counterText: ''),
                    validator: (v) {
                      final a = int.tryParse((v ?? '').trim());
                      if (a == null) return context.tr("Yoshingizni kiriting");
                      if (a < 13) return context.tr("Ilovadan 13 yoshdan foydalanish mumkin");
                      if (a > 100) return context.tr("Yoshni to'g'ri kiriting");
                      return null;
                    },
                  ),
                  FieldLabel(context.tr("Username")),
                  TextFormField(
                    controller: _username,
                    maxLength: 20,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')), LowerCaseFormatter()],
                    decoration: InputDecoration(
                      prefixText: '@',
                      hintText: 'username',
                      counterText: '',
                      suffixIcon: usernameSuffix,
                    ),
                    onChanged: (_) => _scheduleCheck(),
                    validator: (v) {
                      final u = (v ?? '').trim();
                      if (!RegExp(r'^[a-z][a-z0-9_]{2,19}$').hasMatch(u)) {
                        return context.tr("3–20 belgi: lotin harfi, raqam va _ . Harf bilan boshlansin.");
                      }
                      return null;
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      check != null && !check.available
                          ? (check.reason ?? context.tr("Bu username band."))
                          : context.tr("Keyin Profil sozlamalarida o'zgartirish mumkin."),
                      style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w400,
                        color: check != null && !check.available ? scheme.error : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                    FieldLabel(context.tr("Taklif qilgan do'stning username'i (ixtiyoriy)")),
                    TextFormField(
                      controller: _referrer,
                      maxLength: 20,
                      autocorrect: false,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')), LowerCaseFormatter()],
                      decoration: const InputDecoration(prefixText: '@', counterText: ''),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: AppType.label.copyWith(color: scheme.error)),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  FilledButton(
                    onPressed: _saving || (check != null && !check.available) ? null : _submit,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(context.tr("Boshlash")),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _saving ? null : widget.onSignOut,
                    child: Text(context.tr("Boshqa hisob bilan kirish")),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
