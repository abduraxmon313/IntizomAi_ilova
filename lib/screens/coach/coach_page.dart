import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/intizom_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feedback.dart';

/// AI Coach sahifasi: Chat + Mood + Energy + Insights (Mini App uslubi).
class CoachPage extends StatefulWidget {
  const CoachPage({super.key, required this.api});
  final IntizomApi api;

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> with AutomaticKeepAliveClientMixin {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  int? _remaining;
  String? _selectedMood;
  int? _selectedEnergy;

  static const _suggestions = [
    'Bugun nimadan boshlay?',
    'Maqsadlarim bo\'yicha',
    'Menga turtki ber',
  ];
  static const _suggestionQueries = [
    'Bugun nimadan boshlasam yaxshi bo\'ladi?',
    'Maqsadlarimga qanday erishaman?',
    'Motivatsiya bermaysanmi?',
  ];

  static const _moods = [
    ('🔥', 'Olovli'),
    ('💪', 'Kuchli'),
    ('😐', 'Oddiy'),
    ('😴', 'Charchagan'),
    ('😞', 'Past'),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final msg = (text ?? _input.text).trim();
    if (msg.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage('user', msg));
      _sending = true;
    });
    _scrollDown();
    try {
      final history = _messages.length > 12
          ? _messages.sublist(_messages.length - 12)
          : List<ChatMessage>.of(_messages);
      final reply = await widget.api.chat(history);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage('assistant', reply.reply));
        _remaining = reply.remaining;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeLast());
      _input.text = msg;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Coach ✨',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Sening shaxsiy mentoring',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                // Chat card
                _ChatCard(
                  messages: _messages,
                  sending: _sending,
                  remaining: _remaining,
                  suggestions: _suggestions,
                  onSuggestion: (i) => _send(_suggestionQueries[i]),
                  input: _input,
                  onSend: () => _send(),
                ),
                const SizedBox(height: 20),

                // Mood picker
                _SectionTitle(title: 'Bugungi kayfiyat'),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final m in _moods)
                      _MoodPill(
                        emoji: m.$1,
                        label: m.$2,
                        selected: _selectedMood == m.$1,
                        onTap: () {
                          setState(() => _selectedMood = m.$1);
                          _send('Bugungi kayfiyatim: ${m.$1} ${m.$2}');
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Energy picker
                _SectionTitle(title: 'Energiya darajasi'),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (int i = 1; i <= 5; i++)
                      _EnergyCell(
                        level: i,
                        selected: _selectedEnergy == i,
                        onTap: () {
                          setState(() => _selectedEnergy = i);
                          _send('Energiya darajam: $i/5');
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Insights placeholder
                _SectionTitle(title: 'Smart insights 🧠'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    'AI Coach sizning rejalaringiz va odatlaringizni tahlil qilib, shaxsiy tavsiyalar beradi.',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({
    required this.messages,
    required this.sending,
    required this.remaining,
    required this.suggestions,
    required this.onSuggestion,
    required this.input,
    required this.onSend,
  });

  final List<ChatMessage> messages;
  final bool sending;
  final int? remaining;
  final List<String> suggestions;
  final void Function(int) onSuggestion;
  final TextEditingController input;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chat header with bot avatar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, AppPalette.accent],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.bot, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Intizom AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Sening maqsadlaringni ko'rib turibdi",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (remaining != null && remaining! >= 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$remaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Messages
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300, minHeight: 80),
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Savol bering — AI Coach sizga yordam beradi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    itemCount: messages.length + (sending ? 1 : 0),
                    itemBuilder: (_, i) => i == messages.length
                        ? const _Bubble(text: '…', fromUser: false)
                        : _Bubble(
                            text: messages[i].content,
                            fromUser: messages[i].role == 'user',
                          ),
                  ),
          ),

          // Suggestion chips
          if (messages.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (int i = 0; i < suggestions.length; i++)
                    _SuggestionChip(
                      label: suggestions[i],
                      onTap: () => onSuggestion(i),
                    ),
                ],
              ),
            ),
          ],

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: 'Intizom AI ga yoz…',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: sending ? null : onSend,
                  icon: Icon(LucideIcons.sendHorizontal, color: scheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .7),
        decoration: BoxDecoration(
          color: fromUser ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(fromUser ? 14 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 14),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: fromUser ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.primary.withValues(alpha: .2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _MoodPill extends StatelessWidget {
  const _MoodPill({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: .15)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

class _EnergyCell extends StatelessWidget {
  const _EnergyCell({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final int level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [scheme.primary, AppPalette.accent])
              : null,
          color: selected ? null : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: selected ? null : Border.all(color: scheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Text(
          '$level',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
