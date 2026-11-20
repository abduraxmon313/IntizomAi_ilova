import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/store_policy.dart';
import '../../services/ai_consent_store.dart';
import '../../services/intizom_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';

/// Murabbiy (AI) — faqat suhbat. Bo'lim sifatida ochiladi, suhbat sessiya davomida saqlanadi. Coach foydalanuvchining maqsad, reja, odat va
/// streakini server tomonda ko'radi (webapp/routes/ai.py).
class CoachPage extends StatefulWidget {
  const CoachPage({super.key, required this.state});

  final AppState state;

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  int _remaining = -1;
  int _limit = -1;

  static const _suggestions = [
    ('Bugun nimadan boshlay?', "Bugun nimadan boshlasam yaxshi bo'ladi?"),
    ("Maqsadlarim bo'yicha", 'Maqsadlarimga qanday erishaman?'),
    ('Menga turtki ber', 'Menga motivatsiya ber.'),
    ('Haftamni tahlil qil', "Shu haftadagi natijalarimni tahlil qilib ber."),
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Birinchi xabardan oldin uchinchi tomon AI'ga ma'lumot yuborishga rozilik.
  Future<bool> _ensureConsent() async {
    final store = AiConsentStore();
    if (await store.load()) return true;
    if (!mounted) return false;
    final ok = await confirmAction(
      context,
      title: context.tr("AI murabbiy haqida"),
      message: context.tr("Murabbiy javoblarini OpenAI sun'iy intellekti tayyorlaydi. Buning uchun xabarlaringiz hamda maqsad, reja, odat va natijalaringiz OpenAI'ga yuboriladi. Javoblar xato bo'lishi mumkin — ular maslahat xolos. Rozilikni Profil sahifasida istalgan vaqtda bekor qilasiz."),
      confirmLabel: "Roziman",
      danger: false,
    );
    if (ok) await store.save(true);
    return ok;
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    if (!await _ensureConsent() || !mounted) return;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage('user', text));
      _sending = true;
    });
    _scrollDown();
    try {
      final history = _messages.length > 12 ? _messages.sublist(_messages.length - 12) : List.of(_messages);
      final r = await widget.state.api.chat(history);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage('assistant', r.reply));
        _remaining = r.remaining;
        _limit = r.limit;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeLast());
      _input.text = text;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clear() => setState(() {
    _messages.clear();
    _remaining = -1;
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = widget.state.profile?.fullName.trim().split(' ').first ?? '';
    return Column(
      children: [
        PageHeader(
          title: context.tr("Murabbiy"),
          actions: [
            if (_remaining >= 0)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Pill(_limit > 0 ? context.tr("Bugun {v0}/{v1}", {'v0': _remaining, 'v1': _limit}) : '$_remaining', muted: true),
              ),
            if (_messages.isNotEmpty)
              HeaderIconButton(icon: LucideIcons.squarePen, tooltip: context.tr("Yangi suhbat"), onTap: _clear),
          ],
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.base,
            child: _messages.isEmpty
                ? _Welcome(key: const ValueKey('w'), name: name, onPick: _send, suggestions: _suggestions)
                : ListView.builder(
                    key: const ValueKey('c'),
                    controller: _scroll,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 12),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (_, i) => i == _messages.length
                        ? const _Typing()
                        : _Message(text: _messages[i].content, fromUser: _messages[i].role == 'user'),
                  ),
          ),
        ),
        if (_remaining >= 0 && _remaining <= 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 4),
            child: StorePolicy.purchasesVisible
                ? TextButton(
                    onPressed: openPremiumInBot,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 36)),
                    child: Text(_remaining == 0 ? context.tr("Bugungi bepul xabarlar tugadi · Premium") : context.tr("1 ta bepul xabar qoldi · Premium")),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _remaining == 0
                          ? context.tr("Bugungi bepul xabarlar tugadi. Ertaga yangilanadi.")
                          : context.tr("Bugun yana 1 ta bepul xabar qoldi."),
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 4, AppSpace.lg, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 3, 5, 3),
            decoration: surfaceDecoration(context, radius: 26),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppType.body,
                    decoration:  InputDecoration(
                      hintText: context.tr("Savolingizni yozing…"),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _input,
                    builder: (_, v, _) {
                      final ready = v.text.trim().isNotEmpty && !_sending;
                      return AnimatedContainer(
                        duration: AppMotion.fast,
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ready ? scheme.primary : scheme.surfaceContainerLow,
                        ),
                        child: IconButton(
                          tooltip: context.tr("Yuborish"),
                          padding: EdgeInsets.zero,
                          onPressed: ready ? () => _send() : null,
                          icon: Icon(LucideIcons.arrowUp, size: 20, color: ready ? scheme.onPrimary : scheme.outline),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Suhbat boshlanishidan oldin: qisqa tanishtiruv va tayyor savollar.
class _Welcome extends StatelessWidget {
  const _Welcome({super.key, required this.name, required this.onPick, required this.suggestions});

  final String name;
  final ValueChanged<String> onPick;
  final List<(String, String)> suggestions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 20),
      children: [
        Text(
          name.isEmpty ? context.tr("Bugun nimada yordam beray?") : context.tr("{v0}, bugun nimada yordam beray?", {'v0': name}),
          style: AppType.title,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr("Reja, odat va maqsadlaringizni ko'rib turaman — maslahatlarim aynan sizning holatingizga mos bo'ladi."),
          style: AppType.body.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
        ),
         SectionBar(title: context.tr("Shundan boshlash mumkin"), top: 24),
        GroupCard(
          children: [
            for (final (label, prompt) in suggestions)
              InkWell(
                onTap: () {
                  tapFeedback();
                  onPick(context.tr(prompt));
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(context.tr(label), style: AppType.body.copyWith(fontWeight: FontWeight.w500))),
                        Icon(LucideIcons.arrowUp, size: 17, color: scheme.outline),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Foydalanuvchi — neytral pufakcha o'ngda; murabbiy — pufakchasiz matn, chapda belgi.
class _Message extends StatelessWidget {
  const _Message({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appear = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.base,
      curve: AppMotion.curve,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 8), child: child),
      ),
      child: fromUser
          ? Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 18, left: 48),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: SelectableText(text, style: AppType.body.copyWith(color: scheme.onPrimary, height: 1.45)),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(bottom: 22, right: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(LucideIcons.sparkles, size: 18, color: scheme.tertiary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SelectableText(text, style: AppType.body.copyWith(height: 1.55, color: scheme.onSurface)),
                  ),
                ],
              ),
            ),
    );
    return appear;
  }
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        children: [
          Icon(LucideIcons.sparkles, size: 18, color: scheme.tertiary),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.onSurfaceVariant.withValues(
                        alpha: .25 + .6 * (1 - ((_c.value * 3 - i) % 3).clamp(0, 1)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
