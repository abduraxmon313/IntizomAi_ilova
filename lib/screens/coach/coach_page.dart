import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/intizom_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';

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
    final name = widget.state.profile?.fullName.split(' ').first ?? '';
    return Column(
      children: [
        // Sarlavha
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
          child: Row(
            children: [
              AppIconTile.tinted(icon: LucideIcons.sparkles, accent: scheme.primary, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Intizom AI', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -.3)),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: AppPalette.disciplineGreen, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Rejalaringizni ko\'rib turibdi',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_remaining >= 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    _limit > 0 ? '$_remaining/$_limit' : '$_remaining',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                  ),
                ),
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
          child: _messages.isEmpty
              ? _Welcome(name: name, onPick: _send, suggestions: _suggestions)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) => i == _messages.length
                      ? const _Typing()
                      : _Bubble(text: _messages[i].content, fromUser: _messages[i].role == 'user'),
                ),
        ),
        if (_remaining >= 0 && _remaining <= 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: GestureDetector(
              onTap: openPremiumInBot,
              child: Text(
                _remaining == 0
                    ? 'Bugungi bepul xabarlar tugadi · Premium bilan cheksiz'
                    : 'Bugun 1 ta bepul xabar qoldi · Premium bilan cheksiz',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Savol yozing…',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(color: scheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : () => _send(),
                  icon: const Icon(LucideIcons.arrowUp, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.name, required this.onPick, required this.suggestions});

  final String name;
  final ValueChanged<String> onPick;
  final List<(String, String)> suggestions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
      children: [
        Text(
          name.isEmpty ? 'Salom!' : 'Salom, $name!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.5),
        ),
        const SizedBox(height: 6),
        Text(
          "Men sizning shaxsiy murabbiyingizman. Maqsad, reja va odatlaringizni bilaman — "
          "nimadan boshlash, qanday davom etish yoki qayerda to'xtab qolganingiz haqida so'rang.",
          style: TextStyle(fontSize: 14, height: 1.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        for (final (label, query) in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: scheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: () => onPick(query),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Icon(LucideIcons.messageCircle, size: 17, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      Icon(LucideIcons.arrowUpRight, size: 16, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
        decoration: BoxDecoration(
          color: fromUser ? scheme.primary : scheme.surfaceContainerLowest,
          border: fromUser ? null : Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromUser ? 16 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 16),
          ),
        ),
        child: SelectableText(
          text,
          style: TextStyle(fontSize: 14.5, height: 1.45, color: fromUser ? scheme.onPrimary : scheme.onSurface),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Yozmoqda…', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
