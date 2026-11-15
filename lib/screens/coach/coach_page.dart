import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../services/intizom_api.dart';
import '../../widgets/feedback.dart';

/// AI Coach suhbati. Tarix faqat ilovada saqlanadi (Mini App kabi).
/// Bepul foydalanuvchiga kuniga cheklangan xabar — server hisoblaydi.
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

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage('user', text));
      _sending = true;
    });
    _scrollDown();
    try {
      // Oxirgi 12 ta xabar kontekst sifatida yuboriladi.
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🧠', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('AI Coach'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('Rejalaringiz, odatlaringiz va streakingizni biladi. Savol bering.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) => i == _messages.length
                      ? const _Bubble(text: '…', fromUser: false)
                      : _Bubble(
                          text: _messages[i].content,
                          fromUser: _messages[i].role == 'user',
                        ),
                ),
        ),
        if (_remaining != null && _remaining! >= 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              context.tr('Bugun qolgan bepul xabarlar: {n}', {'n': _remaining!}),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: context.tr('Xabar yozing...'),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: Icon(LucideIcons.sendHorizontal, color: scheme.primary),
                ),
              ],
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
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .8),
        decoration: BoxDecoration(
          color: fromUser ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromUser ? 16 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: fromUser ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
