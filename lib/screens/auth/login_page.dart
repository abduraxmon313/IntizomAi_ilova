import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/ui_kit.dart';
import 'language_page.dart';

/// Kirish: iOS'da Apple yoki Google, Android'da faqat Google.
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authService,
    required this.onLoginSuccess,
    this.onLanguageChanged,
  });

  final AuthService authService;
  final ValueChanged<AuthResult> onLoginSuccess;
  final ValueChanged<String>? onLanguageChanged;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _busy; // 'google' | 'apple'
  String? _error;

  Future<void> _run(String provider, Future<AuthResult> Function() action) async {
    if (_busy != null) return;
    setState(() {
      _busy = provider;
      _error = null;
    });
    try {
      final r = await action();
      if (!mounted) return;
      widget.onLoginSuccess(r);
    } on AuthCancelled {
      // Foydalanuvchi oynani yopdi — hech narsa ko'rsatmaymiz.
    } on GoogleConfigError catch (e) {
      if (mounted) {
        setState(() => _error = context.tr(
          "Google kirishni tasdiqlamadi. Google Cloud'dagi Android client (paket nomi va SHA-1) hamda Web client bitta loyihada ekanini tekshiring. ({v0})",
          {'v0': e.toString()},
        ));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = context.tr("Kirib bo'lmadi. Qaytadan urinib ko'ring."));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _openPrivacy() async {
    final uri = Uri.parse(kPrivacyUrl);
    for (final mode in [LaunchMode.externalApplication, LaunchMode.inAppBrowserView, LaunchMode.platformDefault]) {
      try {
        if (await launchUrl(uri, mode: mode)) return;
      } catch (_) {}
    }
    if (mounted) toast(context, context.tr("Sahifani ochib bo'lmadi: {v0}", {'v0': uri.toString()}));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                if (widget.onLanguageChanged != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(LucideIcons.languages, size: 18),
                      label: Text(languageNames[Localizations.localeOf(context).languageCode] ?? context.tr("Til")),
                      onPressed: () => showLanguagePicker(context, widget.onLanguageChanged!),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpace.xl),
                            const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 56)),
                            const SizedBox(height: AppSpace.xl),
                            Text(context.tr("Intizom — natijaning boshlanishi."), style: AppType.display),
                            const SizedBox(height: AppSpace.md),
                            Text(
                              context.tr("Rejalar, odatlar va maqsadlar bitta joyda. AI murabbiy esa har kuni to'g'ri yo'nalish beradi."),
                              style: AppType.body.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                            ),
                            const SizedBox(height: AppSpace.xl),
                            GroupCard(
                              indent: 50,
                              children: [
                                SettingTile(icon: LucideIcons.calendarCheck, title: context.tr("Kunlik reja va vaqtida eslatma")),
                                SettingTile(icon: LucideIcons.repeat, title: context.tr("Odatlar va uzluksiz seriya")),
                                SettingTile(icon: LucideIcons.users, title: context.tr("Do'stlar bilan guruhlar")),
                                SettingTile(icon: LucideIcons.sparkles, title: context.tr("Shaxsiy AI murabbiy")),
                              ],
                            ),
                            const SizedBox(height: AppSpace.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        _ErrorNote(message: _error!),
                        const SizedBox(height: AppSpace.md),
                      ],
                      if (AuthService.appleAvailable) ...[
                        SizedBox(
                          height: 52,
                          child: AbsorbPointer(
                            absorbing: _busy != null,
                            child: Opacity(
                              opacity: _busy == null || _busy == 'apple' ? 1 : .5,
                              child: SignInWithAppleButton(
                                height: 52,
                                text: context.tr("Apple orqali kirish"),
                                style: dark ? SignInWithAppleButtonStyle.white : SignInWithAppleButtonStyle.black,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                onPressed: () => _run('apple', widget.authService.signInWithApple),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                      ],
                      OutlinedButton(
                        onPressed: _busy != null ? null : () => _run('google', widget.authService.signInWithGoogle),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        child: _busy == 'google'
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const _GoogleMark(),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      context.tr("Google orqali kirish"),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.bodyStrong.copyWith(color: scheme.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        context.tr("Davom etish orqali maxfiylik siyosatiga rozilik bildirasiz."),
                        textAlign: TextAlign.center,
                        style: AppType.caption.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                      ),
                      Center(
                          child: TextButton(
                            onPressed: _openPrivacy,
                            style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                            child: Text(context.tr("Maxfiylik siyosati")),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Google "G" belgisi (rasmsiz, rang bo'laklari bilan).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 20,
    child: CustomPaint(painter: _GooglePainter()),
  );
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(r, r), radius: r * .78);
    final stroke = size.width * .2;
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const pi = 3.1415926535;
    canvas.drawArc(rect, -pi * .25, -pi * .5, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(rect, -pi * .75, -pi * .5, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, pi * .75, -pi * .55, false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect, pi * .2, -pi * .2, false, p(const Color(0xFF4285F4)));
    canvas.drawLine(
      Offset(r, r),
      Offset(r + r * .78 + stroke / 2, r),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(LucideIcons.circleAlert, size: 17, color: scheme.onErrorContainer),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: AppType.label.copyWith(color: scheme.onErrorContainer, height: 1.4))),
          ],
        ),
      ),
    );
  }
}
