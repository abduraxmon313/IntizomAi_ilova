import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../models/friends.dart';
import '../../services/api_client.dart';
import '../../services/intizom_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';
import '../forms.dart';
import '../profile/profile_page.dart' show ProfileAvatar;

/// Do'stlar: guruhlar → guruh a'zolari → a'zoning kuni.
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, required this.state, required this.active});

  final AppState state;

  /// Bo'lim ochiq bo'lganda ma'lumot yuklanadi (Premium so'rovi oldindan chiqmasin).
  final bool active;

  @override
  State<FriendsPage> createState() => FriendsPageState();
}

class FriendsPageState extends State<FriendsPage> {
  AppState get s => widget.state;

  List<GroupSummary>? _groups;
  GroupDetail? _group;
  MemberView? _member;
  int? _memberUid;
  DateTime _memberDay = tashkentToday();

  bool _loading = false;
  String? _premiumMessage;
  String? _error;

  /// Orqaga: a'zo → guruh → ro'yxat. Ishlatilsa true.
  bool handleBack() {
    if (_member != null) {
      setState(() {
        _member = null;
        _memberUid = null;
      });
      return true;
    }
    if (_group != null) {
      setState(() => _group = null);
      _loadGroups();
      return true;
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant FriendsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && _groups == null) _loadGroups();
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = _groups == null;
      _error = null;
    });
    try {
      final g = await s.api.groups();
      if (!mounted) return;
      setState(() {
        _groups = g;
        _premiumMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.needsPremium) {
          _premiumMessage = e.message;
          _groups = const [];
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openGroup(int id) async {
    try {
      final g = await s.api.group(id);
      if (mounted) setState(() => _group = g);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _reloadGroup() async {
    final g = _group;
    if (g == null) return;
    await _openGroup(g.id);
  }

  Future<void> _openMember(int uid, [DateTime? day]) async {
    final g = _group;
    if (g == null) return;
    final d = day ?? tashkentToday();
    try {
      final m = await s.api.member(g.id, uid, d);
      if (!mounted) return;
      setState(() {
        _member = m;
        _memberUid = uid;
        _memberDay = parseYmd(m.date) ?? d;
      });
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  // ── Guruh amallari ─────────────────────────────────
  Future<void> _createGroup() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    await showFormSheet<void>(
      context,
      title: 'Yangi guruh',
      saveLabel: 'Yaratish',
      builder: (ctx, _) => Column(
        children: [
          TextField(
            controller: name,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Guruh nomi (masalan: Oila, Ish jamoasi)', counterText: ''),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: desc,
            maxLength: 300,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Tavsif (ixtiyoriy)', counterText: ''),
          ),
        ],
      ),
      onSave: () async {
        if (name.text.trim().isEmpty) {
          toast(context, 'Guruh nomini yozing');
          return false;
        }
        try {
          await s.api.createGroup(name.text.trim(), desc.text.trim().isEmpty ? null : desc.text.trim());
          await _loadGroups();
          return true;
        } catch (e) {
          if (mounted) showApiError(context, e);
          return false;
        }
      },
    );
  }

  String _inviteLink(GroupDetail g) => 'https://t.me/$kBotUsername?start=grp_${g.inviteCode}';

  Future<void> _invite(GroupDetail g) async {
    final link = _inviteLink(g);
    final text = "«${g.name}» guruhiga taklif qilinyapsiz! IntizomAI botiga qo'shiling va birga intizomli bo'laylik.";
    final share = Uri.https('t.me', '/share/url', {'url': link, 'text': text});
    try {
      if (await launchUrl(share, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) toast(context, 'Taklif havolasi nusxalandi');
  }

  Future<void> _permissions(GroupDetail g) async {
    Permissions perms;
    try {
      perms = await s.api.permissions(g.id);
    } catch (e) {
      if (mounted) showApiError(context, e);
      return;
    }
    if (!mounted) return;
    final out = {for (final p in perms.grantsOut) p.userId: p.canManage};
    final myId = g.members.where((m) => m.isMe).map((m) => m.userId).firstOrNull;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final scheme = Theme.of(ctx).colorScheme;
          final others = perms.grantsOut.where((p) => p.userId != myId).toList();
          final incoming = perms.grantsIn.where((p) => p.userId != myId && p.canManage).toList();
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text('Ruxsatlar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5)),
              const SizedBox(height: 16),
              const Text('Kim men uchun reja va odat yarata oladi', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                "Yoqilgan a'zo sizning hisobingizga reja va odat qo'sha oladi.",
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              if (others.isEmpty)
                Text("Guruhda boshqa a'zo yo'q", style: TextStyle(color: scheme.onSurfaceVariant))
              else
                GroupCard(
                  children: [
                    for (final p in others)
                      SwitchListTile.adaptive(
                        title: Text(p.name, style: const TextStyle(fontSize: 14.5)),
                        value: out[p.userId] ?? false,
                        onChanged: (v) async {
                          setSheet(() => out[p.userId] = v);
                          try {
                            await s.api.setPermission(g.id, p.userId, canManage: v);
                          } catch (e) {
                            setSheet(() => out[p.userId] = !v);
                            if (ctx.mounted) showApiError(ctx, e);
                          }
                        },
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              const Text('Menga ruxsat berganlar', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              if (incoming.isEmpty)
                Text("Hozircha hech kim", style: TextStyle(color: scheme.onSurfaceVariant))
              else
                GroupCard(
                  children: [
                    for (final p in incoming)
                      ListTile(
                        leading: Icon(LucideIcons.userCheck, size: 20, color: scheme.onSurfaceVariant),
                        title: Text(p.name),
                        subtitle: const Text('Uning uchun reja va odat yarata olasiz'),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
    _reloadGroup();
  }

  Future<void> _groupSettings(GroupDetail g) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => _GroupSettingsSheet(
        api: s,
        group: g,
        onChanged: _reloadGroup,
        onGone: () {
          setState(() {
            _group = null;
            _member = null;
          });
          _loadGroups();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_member != null) return _memberView(_member!);
    if (_group != null) return _groupView(_group!);
    return _listView();
  }

  // ── 1. Guruhlar ro'yxati ───────────────────────────
  Widget _listView() {
    final scheme = Theme.of(context).colorScheme;
    final groups = _groups ?? const [];
    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          PageHeader(
            title: "Do'stlar",
            subtitle: "Jamoa bo'lib intizom yig'ing",
            actions: [
              if (_premiumMessage == null)
                HeaderIconButton(icon: LucideIcons.plus, tooltip: 'Yangi guruh', filled: true, onTap: _createGroup),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Builder(
              builder: (_) {
                if (_loading) {
                  return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                }
                if (_premiumMessage != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AppCard(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppPalette.gold.withValues(alpha: .5)),
                            ),
                            child: const Icon(LucideIcons.users, size: 20, color: AppPalette.gold),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "Do'stlar Premium bilan ochiladi",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -.3),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Oila, do'stlar yoki jamoa bilan guruh tuzing, bir-biringizning kunini kuzating va Telegram guruhga kunlik hisobot yuboring.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, height: 1.45, color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: openPremiumInBot,
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                            child: const Text('Premium olish'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (_error != null) return ErrorRetry(message: _error!, onRetry: _loadGroups);
                if (groups.isEmpty) {
                  return EmptyView(
                    icon: LucideIcons.users,
                    title: "Hozircha guruh yo'q",
                    message: "Guruh yarating va do'stlaringizni taklif qiling.",
                    actionLabel: 'Yangi guruh',
                    onAction: _createGroup,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    GroupCard(
                      indent: 68,
                      children: [
                        for (final g in groups)
                          InkWell(
                            onTap: () => _openGroup(g.id),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                              child: Row(
                                children: [
                                  _GroupMonogram(name: g.name),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                g.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -.2),
                                              ),
                                            ),
                                            if (g.isOwner) ...[const SizedBox(width: 6), const Pill('Ega')],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${g.memberCount} a'zo${g.description?.isNotEmpty == true ? ' · ${g.description}' : ''}",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Guruh ichi ──────────────────────────────────
  Widget _groupView(GroupDetail g) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _reloadGroup,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          PageHeader(
            title: g.name,
            subtitle: "${g.members.length} a'zo",
            leading: IconButton(onPressed: handleBack, icon: const Icon(LucideIcons.chevronLeft)),
            actions: [
              HeaderIconButton(icon: LucideIcons.settings, tooltip: 'Guruh sozlamalari', onTap: () => _groupSettings(g)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _invite(g),
                        icon: const Icon(LucideIcons.userPlus, size: 17),
                        label: const Text('Taklif qilish'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _permissions(g),
                        icon: const Icon(LucideIcons.shield, size: 17),
                        label: const Text('Ruxsatlar'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  ],
                ),
                SectionBar(title: "A'zolar", count: '${g.members.length}'),
                GroupCard(
                  indent: 66,
                  children: [
                    for (final m in g.members)
                      InkWell(
                        onTap: () => _openMember(m.userId),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                          child: Row(
                            children: [
                              ProfileAvatar(url: null, telegramId: m.telegramId, name: m.name, size: 38),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            m.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.15),
                                          ),
                                        ),
                                        if (m.isMe) ...[const SizedBox(width: 6), const Pill('Siz')],
                                        if (m.isOwner) ...[const SizedBox(width: 6), const Pill('Ega')],
                                        if (!m.isActive) ...[const SizedBox(width: 6), const Pill('Pauza', muted: true)],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 12,
                                      children: m.isMe || m.visible
                                          ? [
                                              MetaTag(icon: LucideIcons.calendarCheck, text: '${m.plansDone}/${m.plansTotal}'),
                                              MetaTag(icon: LucideIcons.repeat, text: '${m.habitsDone}/${m.habitsTotal}'),
                                              MetaTag(icon: LucideIcons.flame, text: '${m.streak}', color: AppPalette.ember),
                                            ]
                                          : [
                                              const MetaTag(icon: LucideIcons.lock, text: 'Yashirin'),
                                              MetaTag(icon: LucideIcons.flame, text: '${m.streak}', color: AppPalette.ember),
                                            ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _inviteLink(g)));
                    toast(context, 'Taklif havolasi nusxalandi');
                  },
                  child: Text(
                    'Taklif kodi: ${g.inviteCode} · nusxalash',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. A'zoning kuni ───────────────────────────────
  Widget _memberView(MemberView m) {
    final scheme = Theme.of(context).colorScheme;
    final g = _group!;
    final canManage = m.canManage && !m.isMe;
    final plans = [...m.plans]..sort((a, b) => (a.time ?? '99:99').compareTo(b.time ?? '99:99'));
    final habits = [...m.habits]..sort((a, b) => (a.time ?? '99:99').compareTo(b.time ?? '99:99'));

    void shift(int days) => _openMember(_memberUid!, _memberDay.add(Duration(days: days)));
    void shiftMonth(int months) {
      final target = DateTime(_memberDay.year, _memberDay.month + months, 1);
      final last = DateTime(target.year, target.month + 1, 0).day;
      _openMember(_memberUid!, DateTime(target.year, target.month, _memberDay.day.clamp(1, last)));
    }

    return RefreshIndicator(
      onRefresh: () => _openMember(_memberUid!, _memberDay),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          PageHeader(
            title: m.name,
            subtitle: '${m.streak} kun streak · ${m.totalScore} ball',
            leading: IconButton(onPressed: handleBack, icon: const Icon(LucideIcons.chevronLeft)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      IconButton(tooltip: 'Oldingi oy', onPressed: () => shiftMonth(-1), icon: const Icon(LucideIcons.chevronsLeft, size: 18)),
                      IconButton(tooltip: 'Oldingi kun', onPressed: () => shift(-1), icon: const Icon(LucideIcons.chevronLeft, size: 18)),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openMember(_memberUid!, tashkentToday()),
                          child: Text(
                            relativeDay(_memberDay),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      IconButton(tooltip: 'Keyingi kun', onPressed: () => shift(1), icon: const Icon(LucideIcons.chevronRight, size: 18)),
                      IconButton(tooltip: 'Keyingi oy', onPressed: () => shiftMonth(1), icon: const Icon(LucideIcons.chevronsRight, size: 18)),
                    ],
                  ),
                ),
                if (!m.visible)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: EmptyView(
                      icon: LucideIcons.lock,
                      title: "Ma'lumotlari yashirin",
                      message: "Bu a'zoning reja va odatlari sizga ko'rinmaydi.",
                    ),
                  )
                else ...[
                  if (m.isPast || m.isFuture)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        m.isPast ? "O'tgan kun ko'rinishi" : "Kelajakdagi kun ko'rinishi",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                      ),
                    ),
                  SectionBar(
                    title: 'Rejalar',
                    count: '${plans.where((p) => p.done).length}/${plans.length}',
                    actionLabel: canManage ? 'Reja' : null,
                    onAction: canManage
                        ? () async {
                            final ok = await showPlanForm(
                              context,
                              api: s.api,
                              initialDate: _memberDay,
                              titleOverride: '${m.name} uchun reja',
                              onSubmit: (t, d, time, date) => s.api.createPlanForMember(
                                g.id,
                                m.userId,
                                title: t,
                                description: d,
                                scheduledTime: time,
                                planDate: ymd(date),
                              ),
                            );
                            if (ok) _openMember(_memberUid!, _memberDay);
                          }
                        : null,
                  ),
                  _memberItems(plans, "Reja yo'q"),
                  SectionBar(
                    title: 'Odatlar',
                    count: '${habits.where((h) => h.done).length}/${habits.length}',
                    actionLabel: canManage ? 'Odat' : null,
                    onAction: canManage
                        ? () async {
                            final ok = await showHabitForm(
                              context,
                              api: s.api,
                              titleOverride: '${m.name} uchun odat',
                              onSubmit: (input) => s.api.createHabitForMember(g.id, m.userId, input),
                            );
                            if (ok) _openMember(_memberUid!, _memberDay);
                          }
                        : null,
                  ),
                  _memberItems(habits, "Odat yo'q"),
                  if (!canManage && !m.isMe)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        "Bu a'zo sizga u uchun reja yaratishga ruxsat bermagan.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberItems(List<MemberItem> items, String empty) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(empty, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      );
    }
    return GroupCard(
      indent: 50,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
            child: Row(
              children: [
                CheckCircle(checked: it.done, disabled: true),
                const SizedBox(width: 6),
                if (it.icon != null) ...[
                  _ItemGlyph(icon: it.icon!),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    it.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      letterSpacing: -.1,
                      decoration: it.done ? TextDecoration.lineThrough : null,
                      color: it.done ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                ),
                if (it.time != null) MetaTag(icon: LucideIcons.clock, text: it.time!),
              ],
            ),
          ),
      ],
    );
  }
}

/// Guruh sozlamalari: Umumiy / Hisobot / A'zolar (ega uchun), a'zo uchun — chiqish.
class _GroupSettingsSheet extends StatefulWidget {
  const _GroupSettingsSheet({
    required this.api,
    required this.group,
    required this.onChanged,
    required this.onGone,
  });

  final AppState api;
  final GroupDetail group;
  final VoidCallback onChanged;
  final VoidCallback onGone;

  @override
  State<_GroupSettingsSheet> createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends State<_GroupSettingsSheet> {
  late final _name = TextEditingController(text: widget.group.name);
  late final _desc = TextEditingController(text: widget.group.description ?? '');
  late GroupDetail _g = widget.group;
  String _tab = 'general';
  DigestSettings? _digest;
  bool _busy = false;

  IntizomApi get _api => widget.api.api;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadDigest() async {
    try {
      final d = await _api.digestSettings(_g.id);
      if (mounted) setState(() => _digest = d);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _updateDigest(Map<String, dynamic> body) => _run(() async {
    final d = await _api.updateDigest(_g.id, body);
    if (mounted) setState(() => _digest = d);
  });

  Future<void> _pickChat() async {
    List<TelegramChat> chats;
    try {
      chats = await _api.digestCandidates(_g.id);
    } catch (e) {
      if (mounted) showApiError(context, e);
      return;
    }
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final picked = await showModalBottomSheet<TelegramChat>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text('Telegram guruhni tanlang', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5)),
          const SizedBox(height: 6),
          Text(
            "Bot va siz a'zo bo'lgan guruhlar. Ro'yxatda bo'lmasa — botni guruhga qo'shing va u yerda bir marta xabar yozing.",
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (chats.isEmpty)
            Text("Mos guruh topilmadi", style: TextStyle(color: scheme.onSurfaceVariant))
          else
            for (final c in chats)
              ListTile(
                leading: Icon(LucideIcons.send, size: 20, color: scheme.onSurfaceVariant),
                title: Text(c.title),
                subtitle: c.canSend ? null : const Text("Bot xabar yubora olmaydi — botni admin qiling"),
                onTap: () => Navigator.pop(ctx, c),
              ),
        ],
      ),
    );
    if (picked != null) {
      await _run(() async {
        await _api.linkTelegram(_g.id, picked);
      });
      _loadDigest();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final owner = _g.isOwner;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text('Guruh sozlamalari', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5)),
          const SizedBox(height: 14),
          if (!owner) ...[
            Text(_g.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (_g.description?.isNotEmpty == true)
              Text(_g.description!, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      if (!await confirmAction(context, title: 'Guruhdan chiqish', message: _g.name, confirmLabel: 'Chiqish')) return;
                      await _run(() => _api.leaveGroup(_g.id));
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      widget.onGone();
                    },
              icon: const Icon(LucideIcons.logOut, size: 17, color: AppPalette.danger),
              label: const Text('Guruhdan chiqish', style: TextStyle(color: AppPalette.danger)),
            ),
          ] else ...[
            SegmentTabs<String>(
              value: _tab,
              items: const [('general', 'Umumiy', null), ('digest', 'Hisobot', null), ('members', "A'zolar", null)],
              onChanged: (v) {
                setState(() => _tab = v);
                if (v == 'digest' && _digest == null) _loadDigest();
              },
            ),
            const SizedBox(height: 16),
            if (_tab == 'general') ..._general(),
            if (_tab == 'digest') ..._digestPane(scheme),
            if (_tab == 'members') ..._members(scheme),
          ],
        ],
      ),
    );
  }

  List<Widget> _general() => [
    const FieldLabel('Guruh nomi'),
    TextField(controller: _name, maxLength: 80, decoration: const InputDecoration(counterText: '')),
    const FieldLabel('Tavsif'),
    TextField(controller: _desc, maxLength: 300, minLines: 2, maxLines: 4, decoration: const InputDecoration(counterText: '')),
    const SizedBox(height: 14),
    FilledButton(
      onPressed: _busy
          ? null
          : () => _run(() async {
              if (_name.text.trim().isEmpty) return;
              await _api.updateGroup(_g.id, name: _name.text.trim(), description: _desc.text.trim().isEmpty ? null : _desc.text.trim());
              widget.onChanged();
              if (mounted) Navigator.pop(context);
            }),
      child: const Text('Saqlash'),
    ),
    const SizedBox(height: 10),
    TextButton.icon(
      onPressed: _busy
          ? null
          : () async {
              if (!await confirmAction(
                context,
                title: "Guruhni o'chirish",
                message: "«${_g.name}» va undagi ruxsatlar o'chiriladi.",
              )) {
                return;
              }
              await _run(() => _api.deleteGroup(_g.id));
              if (!mounted) return;
              Navigator.pop(context);
              widget.onGone();
            },
      icon: const Icon(LucideIcons.trash2, size: 17, color: AppPalette.danger),
      label: const Text("Guruhni o'chirish", style: TextStyle(color: AppPalette.danger)),
    ),
  ];

  List<Widget> _digestPane(ColorScheme scheme) {
    final d = _digest;
    if (d == null) return const [Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))];
    final times = d.allowedTimes.isEmpty
        ? [for (var h = 0; h < 24; h++) '${h.toString().padLeft(2, '0')}:00']
        : d.allowedTimes;
    Widget timeDrop(String value, ValueChanged<String> onChanged) => DropdownButton<String>(
      value: times.contains(value) ? value : null,
      hint: Text(value),
      underline: const SizedBox(),
      items: [for (final t in times) DropdownMenuItem(value: t, child: Text(t))],
      onChanged: _busy ? null : (v) => v == null ? null : onChanged(v),
    );
    return [
      Text(
        "Belgilangan vaqtda har bir a'zoning rejasi (ertalab) va natijasi (kechqurun) Telegram guruhga yuboriladi.",
        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.4),
      ),
      const SizedBox(height: 12),
      GroupCard(
        children: [
          SettingTile(
            icon: LucideIcons.send,
            title: 'Telegram guruh',
            subtitle: d.chatTitle ?? 'Tanlanmagan',
            onTap: _busy ? null : _pickChat,
            trailing: d.chatId == null
                ? null
                : TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await _run(() => _api.unlinkTelegram(_g.id));
                            _loadDigest();
                          },
                    child: const Text('Uzish'),
                  ),
          ),
        ],
      ),
      const FieldLabel('Nima yuborilsin'),
      SegmentTabs<String>(
        value: d.reportSource,
        items: const [('plans', 'Rejalar', null), ('both', 'Ikkisi', null), ('habits', 'Odatlar', null)],
        onChanged: (v) => _updateDigest({'report_source': v}),
      ),
      const SizedBox(height: 12),
      GroupCard(
        children: [
          SettingTile(
            icon: LucideIcons.sunrise,
            title: 'Kunlik reja',
            subtitle: 'Ertalab — bugun nima qilinadi',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                timeDrop(d.plansTime, (v) => _updateDigest({'plans_time': v})),
                Switch.adaptive(value: d.plansEnabled, onChanged: _busy ? null : (v) => _updateDigest({'plans_enabled': v})),
              ],
            ),
          ),
          SettingTile(
            icon: LucideIcons.moon,
            title: 'Kunlik hisobot',
            subtitle: 'Kechqurun — nima bajarildi',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                timeDrop(d.digestTime, (v) => _updateDigest({'digest_time': v})),
                Switch.adaptive(value: d.digestEnabled, onChanged: _busy ? null : (v) => _updateDigest({'digest_enabled': v})),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy || d.chatId == null ? null : () => _test('plans'),
              child: const Text('Rejani sinash'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: _busy || d.chatId == null ? null : () => _test('report'),
              child: const Text('Hisobotni sinash'),
            ),
          ),
        ],
      ),
      if (d.lastError?.isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Text('Oxirgi xato: ${d.lastError}', style: const TextStyle(fontSize: 12, color: AppPalette.danger)),
      ],
    ];
  }

  Future<void> _test(String kind) => _run(() async {
    final (ok, reason) = await _api.testDigest(_g.id, kind);
    if (mounted) toast(context, ok ? 'Telegram guruhga yuborildi' : 'Yuborilmadi: ${reason ?? 'noma\'lum sabab'}');
  });

  List<Widget> _members(ColorScheme scheme) {
    final others = _g.members.where((m) => !m.isMe).toList();
    if (others.isEmpty) return [Text("Boshqa a'zo yo'q", style: TextStyle(color: scheme.onSurfaceVariant))];
    return [
      Text(
        "O'chirilgan (pauza) a'zoning ma'lumotlari boshqalarga va Telegram hisobotiga ko'rinmaydi.",
        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
      ),
      const SizedBox(height: 10),
      GroupCard(
        children: [
          for (final m in others)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  ProfileAvatar(url: null, telegramId: m.telegramId, name: m.name, size: 32),
                  const SizedBox(width: 10),
                  Expanded(child: Text(m.name, style: const TextStyle(fontSize: 14))),
                  Switch.adaptive(
                    value: m.isActive,
                    onChanged: _busy
                        ? null
                        : (v) => _run(() async {
                            await _api.setMemberActive(_g.id, m.userId, v);
                            final g = await _api.group(_g.id);
                            if (mounted) setState(() => _g = g);
                            widget.onChanged();
                          }),
                  ),
                  IconButton(
                    tooltip: 'Chiqarib yuborish',
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!await confirmAction(context, title: 'Guruhdan chiqarish', message: m.name, confirmLabel: 'Chiqarish')) return;
                            await _run(() async {
                              await _api.removeMember(_g.id, m.userId);
                              final g = await _api.group(_g.id);
                              if (mounted) setState(() => _g = g);
                              widget.onChanged();
                            });
                          },
                    icon: const Icon(LucideIcons.userX, size: 18, color: AppPalette.danger),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }
}

/// Guruh nomining bosh harfi — neytral kvadrat.
class _GroupMonogram extends StatelessWidget {
  const _GroupMonogram({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = name.trim();
    final accent = HabitGlyph.accentFor(t);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? .16 : .09),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: accent.withValues(alpha: dark ? .22 : .14)),
      ),
      child: Text(
        t.isEmpty ? '#' : t.characters.first.toUpperCase(),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dark ? Color.lerp(accent, Colors.white, .35) : accent),
      ),
    );
  }
}

/// A'zo odati belgisi: ma'lum emoji → Lucide ikonka.
class _ItemGlyph extends StatelessWidget {
  const _ItemGlyph({required this.icon});
  final String icon;

  @override
  Widget build(BuildContext context) {
    final g = habitGlyphs[icon.trim()];
    return g != null
        ? Icon(g, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant)
        : Text(icon, style: const TextStyle(fontSize: 15));
  }
}

/// Do'stlar bo'limi alohida sahifa sifatida (Asosiy → Tezkor kirish).
/// Orqaga: a'zo → guruh → ro'yxat → Asosiy.
class FriendsRoute extends StatefulWidget {
  const FriendsRoute({super.key, required this.state});

  final AppState state;

  @override
  State<FriendsRoute> createState() => _FriendsRouteState();
}

class _FriendsRouteState extends State<FriendsRoute> {
  final _key = GlobalKey<FriendsPageState>();

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (_key.currentState?.handleBack() ?? false) return;
      Navigator.of(context).pop();
    },
    child: Scaffold(
      body: SafeArea(child: FriendsPage(key: _key, state: widget.state, active: true)),
    ),
  );
}
