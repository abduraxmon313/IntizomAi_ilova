import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/intizom_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';

/// AI Coach — faqat suhbat. Coach foydalanuvchining maqsad, reja, odat va
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

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
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
        Padding(
          padding: EdgeInsets.fromLTRB(Navigator.of(context).canPop() ? 6 : AppSpace.page, 12, 10, 12),
          child: Row(
            children: [
              if (Navigator.of(context).canPop())
                IconButton(
                  tooltip: 'Orqaga',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(LucideIcons.chevronLeft, color: scheme.onSurface),
                ),
              const BrandMark(size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Intizom AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -.3)),
                    Text(
                      _sending ? 'Yozmoqda…' : 'Shaxsiy murabbiy',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (_remaining >= 0) Pill(_limit > 0 ? '$_remaining/$_limit bugun' : '$_remaining', muted: true),
              if (_messages.isNotEmpty)
                IconButton(
                  tooltip: 'Yangi suhbat',
                  onPressed: _clear,
                  icon: Icon(LucideIcons.squarePen, size: 19, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.base,
            child: _messages.isEmpty
                ? _Welcome(key: const ValueKey('w'), name: name, onPick: _send, suggestions: _suggestions)
                : ListView.builder(
                    key: const ValueKey('c'),
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpace.page, 20, AppSpace.page, 12),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (_, i) => i == _messages.length
                        ? const _Typing()
                        : _Message(text: _messages[i].content, fromUser: _messages[i].role == 'user'),
                  ),
          ),
        ),
        if (_remaining >= 0 && _remaining <= 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 8),
            child: InkWell(
              onTap: openPremiumInBot,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.infinity, size: 15, color: scheme.tertiary),
                    const SizedBox(width: 6),
                    Text(
                      _remaining == 0 ? 'Bugungi bepul xabarlar tugadi · Premium' : '1 ta bepul xabar qoldi · Premium',
                      style: TextStyle(fontSize: 12.5, color: scheme.tertiary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: Theme.of(context).brightness == Brightness.dark ? null : AppShadows.raised,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 15.5, letterSpacing: -.15),
                      decoration: const InputDecoration(
                        hintText: 'Murabbiyga yozing…',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _input,
                      builder: (_, v, _) {
                        final ready = v.text.trim().isNotEmpty && !_sending;
                        return AnimatedContainer(
                          duration: AppMotion.fast,
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ready ? scheme.primary : scheme.surfaceContainerHigh,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: ready ? () => _send() : null,
                            icon: Icon(
                              LucideIcons.arrowUp,
                              size: 19,
                              color: ready ? scheme.onPrimary : scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({super.key, required this.name, required this.onPick, required this.suggestions});

  final String name;
  final ValueChanged<String> onPick;
  final List<(String, String)> suggestions;

  static const _icons = [LucideIcons.sunrise, LucideIcons.target, LucideIcons.zap, LucideIcons.chartColumn];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 40, AppSpace.page, 20),
      children: [
        Text(
          name.isEmpty ? 'Bugun nimaga\nyordam beray?' : '$name, bugun nimaga\nyordam beray?',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.15),
        ),
        const SizedBox(height: 10),
        Text(
          "Maqsad, reja va odatlaringizni ko'rib turaman. Qayerdan boshlashni, qanday davom etishni yoki nima to'xtatayotganini so'rang.",
          style: TextStyle(fontSize: 15, height: 1.5, color: scheme.onSurfaceVariant, letterSpacing: -.1),
        ),
        const SizedBox(height: 28),
        GroupCard(
          indent: 48,
          children: [
            for (var i = 0; i < suggestions.length; i++)
              InkWell(
                onTap: () {
                  tapFeedback();
                  onPick(suggestions[i].$2);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(
                    children: [
                      Icon(_icons[i % _icons.length], size: 18, color: scheme.tertiary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          suggestions[i].$1,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -.15),
                        ),
                      ),
                      Icon(LucideIcons.arrowUpRight, size: 16, color: scheme.outline),
                    ],
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
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SelectableText(text, style: const TextStyle(fontSize: 15, height: 1.45, letterSpacing: -.1)),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(bottom: 22, right: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: BrandMark(size: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SelectableText(
                      text,
                      style: TextStyle(fontSize: 15, height: 1.55, letterSpacing: -.1, color: scheme.onSurface),
                    ),
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
          const BrandMark(size: 24),
          const SizedBox(width: 14),
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
