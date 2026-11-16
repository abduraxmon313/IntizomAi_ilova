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
///
/// [groupId] berilmasa — guruhlar ro'yxati (Natijalar → Do'stlar ichida),
/// berilsa — o'sha guruhning sahifasi ([FriendsRoute] orqali ochiladi).
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, required this.state, this.groupId});

  final AppState state;
  final int? groupId;

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

  /// Orqaga: a'zo → guruh. Ishlatilsa true (aks holda sahifa yopiladi).
  bool handleBack() {
    if (_member != null) {
      setState(() {
        _member = null;
        _memberUid = null;
      });
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final id = widget.groupId;
    id == null ? _loadGroups() : _openGroup(id);
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
    setState(() => _error = null);
    try {
      final g = await s.api.group(id);
      if (mounted) setState(() => _group = g);
    } catch (e) {
      if (!mounted) return;
      _group == null ? setState(() => _error = e.toString()) : showApiError(context, e);
    }
  }

  /// Ro'yxatdan guruh sahifasini ochadi; qaytgach ro'yxat yangilanadi.
  Future<void> _pushGroup(int id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FriendsRoute(state: s, groupId: id)));
    if (mounted) _loadGroups();
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
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final scheme = Theme.of(ctx).colorScheme;
          final others = perms.grantsOut.where((p) => p.userId != myId).toList();
          final incoming = perms.grantsIn.where((p) => p.userId != myId && p.canManage).toList();
          return SheetScaffold(
            title: 'Ruxsatlar',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SectionBar(title: 'Kim men uchun reja va odat yarata oladi', top: 4),
                if (others.isEmpty)
                  const _SheetNote("Guruhda boshqa a'zo yo'q")
                else
                  GroupCard(
                    indent: 64,
                    children: [
                      for (final p in others)
                        _MemberSwitchRow(
                          member: g.members.where((m) => m.userId == p.userId).firstOrNull,
                          name: p.name,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    "Yoqilgan a'zo sizning hisobingizga reja va odat qo'sha oladi.",
                    style: AppType.caption.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                  ),
                ),
                const SectionBar(title: 'Menga ruxsat berganlar', top: 22),
                if (incoming.isEmpty)
                  const _SheetNote('Hozircha hech kim')
                else
                  GroupCard(
                    indent: 50,
                    children: [
                      for (final p in incoming)
                        SettingTile(
                          icon: LucideIcons.userCheck,
                          title: p.name,
                          subtitle: 'Uning uchun reja va odat yarata olasiz',
                        ),
                    ],
                  ),
              ],
            ),
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
      useSafeArea: true,
      builder: (ctx) => _GroupSettingsSheet(
        api: s,
        group: g,
        onChanged: _reloadGroup,
        onGone: () {
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) return _listView();
    if (_member != null) return _memberView(_member!);
    if (_group != null) return _groupView(_group!);
    return Column(
      children: [
        const PageHeader(title: 'Guruh'),
        Expanded(
          child: _error != null
              ? ErrorRetry(message: _error!, onRetry: () => _openGroup(widget.groupId!))
              : const LoadingView(),
        ),
      ],
    );
  }

  // ── 1. Guruhlar ro'yxati ───────────────────────────
  Widget _listView() {
    final scheme = Theme.of(context).colorScheme;
    final groups = _groups ?? const [];
    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Builder(
              builder: (_) {
                if (_loading) return const LoadingView();
                if (_premiumMessage != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: PremiumGate(
                      icon: LucideIcons.users,
                      title: "Do'stlar Premium bilan ochiladi",
                      message: "Oila, do'stlar yoki jamoa bilan guruh tuzing, bir-biringizning kunini kuzating va Telegram guruhga kunlik hisobot yuboring.",
                      onOpen: () => showPremiumDialog(context, _premiumMessage!),
                    ),
                  );
                }
                if (_error != null) return ErrorRetry(message: _error!, onRetry: _loadGroups);
                if (groups.isEmpty) {
                  return EmptyView(
                    icon: LucideIcons.users,
                    title: "Hozircha guruh yo'q",
                    message: "Guruh yarating va do'stlaringizni taklif qiling — birga intizom oson.",
                    actionLabel: 'Yangi guruh',
                    onAction: _createGroup,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionBar(title: 'Guruhlar', count: '${groups.length}', actionLabel: 'Yangi guruh', onAction: _createGroup, top: 8),
                    GroupCard(
                      indent: 68,
                      children: [
                        for (final g in groups)
                          InkWell(
                            onTap: () => _pushGroup(g.id),
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
                                                style: AppType.bodyStrong,
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
                                          style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
        key: ValueKey('group-${g.id}'),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          PageHeader(
            title: g.name,
            subtitle: "${g.members.length} a'zo",
            actions: [
              HeaderIconButton(icon: LucideIcons.settings, tooltip: 'Guruh sozlamalari', onTap: () => _groupSettings(g)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (_, box) {
                    const pad = EdgeInsets.symmetric(horizontal: 12);
                    final invite = FilledButton.icon(
                      onPressed: () => _invite(g),
                      style: FilledButton.styleFrom(padding: pad, minimumSize: const Size(0, 48)),
                      icon: const Icon(LucideIcons.userPlus, size: 18),
                      label: const Text('Taklif qilish', maxLines: 1),
                    );
                    final perms = OutlinedButton.icon(
                      onPressed: () => _permissions(g),
                      style: OutlinedButton.styleFrom(padding: pad, minimumSize: const Size(0, 48)),
                      icon: const Icon(LucideIcons.shield, size: 18),
                      label: const Text('Ruxsatlar', maxLines: 1),
                    );
                    // Ikki tugma yonma-yon sig'masa — ustma-ust.
                    if (box.maxWidth < 300) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [invite, const SizedBox(height: 8), perms],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: invite),
                        const SizedBox(width: 10),
                        Expanded(child: perms),
                      ],
                    );
                  },
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
                                            style: AppType.bodyStrong,
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
                              const SizedBox(width: 8),
                              Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _inviteLink(g)));
                      toast(context, 'Taklif havolasi nusxalandi');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      textStyle: AppType.label.copyWith(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w500,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                    icon: const Icon(LucideIcons.copy, size: 15),
                    label: Text('Taklif kodi: ${g.inviteCode}'),
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
    return RefreshIndicator(
      onRefresh: () => _openMember(_memberUid!, _memberDay),
      child: ListView(
        key: ValueKey('member-$_memberUid'),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          PageHeader(
            title: m.name,
            subtitle: '${m.streak} kunlik seriya · ${m.totalScore} ball',
            onBack: handleBack,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PeriodStepper(
                  label: relativeDay(_memberDay),
                  isCurrent: m.isToday,
                  onReset: () => _openMember(_memberUid!, tashkentToday()),
                  onPrev: () => shift(-1),
                  onNext: () => shift(1),
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
                  SectionBar(
                    top: 12,
                    title: 'Rejalar',
                    count: '${plans.where((p) => p.done).length}/${plans.length}',
                    actionLabel: canManage ? "Reja qo'shish" : null,
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
                    actionLabel: canManage ? "Odat qo'shish" : null,
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
                        style: AppType.caption.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
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
      return Container(
        decoration: surfaceDecoration(context),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Text(empty, style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant)),
      );
    }
    return GroupCard(
      indent: 52,
      children: [
        for (final it in items)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  CheckCircle(checked: it.done, disabled: true, semanticLabel: it.title),
                  const SizedBox(width: 4),
                  if (it.icon != null) ...[
                    _ItemGlyph(icon: it.icon!),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        it.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration: it.done ? TextDecoration.lineThrough : null,
                          decorationColor: scheme.outline,
                          color: it.done ? scheme.onSurfaceVariant : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (it.time != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      it.time!,
                      style: AppType.label.copyWith(fontFeatures: tabularFigures, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
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
    final picked = await showModalBottomSheet<TelegramChat>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SheetScaffold(
        title: 'Telegram guruhni tanlang',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetNote(
              "Bot va siz a'zo bo'lgan guruhlar. Ro'yxatda bo'lmasa — botni guruhga qo'shing va u yerda bir marta xabar yozing.",
              boxed: false,
            ),
            const SizedBox(height: 14),
            if (chats.isEmpty)
              const _SheetNote('Mos guruh topilmadi')
            else
              GroupCard(
                indent: 50,
                children: [
                  for (final c in chats)
                    SettingTile(
                      icon: LucideIcons.send,
                      title: c.title,
                      subtitle: c.canSend ? null : "Bot xabar yubora olmaydi — botni admin qiling",
                      onTap: () => Navigator.pop(ctx, c),
                    ),
                ],
              ),
          ],
        ),
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
    return SheetScaffold(
      title: 'Guruh sozlamalari',
      subtitle: owner ? null : _g.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!owner) ...[
            if (_g.description?.isNotEmpty == true) ...[
              Text(_g.description!, style: AppType.body.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 4),
            GroupCard(
              children: [
                SettingTile(
                  icon: LucideIcons.logOut,
                  title: 'Guruhdan chiqish',
                  danger: true,
                  onTap: _busy
                      ? null
                      : () async {
                          if (!await confirmAction(context, title: 'Guruhdan chiqish', message: _g.name, confirmLabel: 'Chiqish')) return;
                          await _run(() => _api.leaveGroup(_g.id));
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          widget.onGone();
                        },
                ),
              ],
            ),
          ] else ...[
            SegmentTabs<String>(
              value: _tab,
              items: const [('general', 'Umumiy'), ('digest', 'Hisobot'), ('members', "A'zolar")],
              onChanged: (v) {
                setState(() => _tab = v);
                if (v == 'digest' && _digest == null) _loadDigest();
              },
            ),
            const SizedBox(height: 4),
            AnimatedSize(
              duration: AppMotion.base,
              curve: AppMotion.curve,
              alignment: Alignment.topCenter,
              child: Column(
                key: ValueKey(_tab),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: switch (_tab) {
                  'digest' => _digestPane(scheme),
                  'members' => _members(scheme),
                  _ => _general(),
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _general() => [
    const FieldLabel('Guruh nomi'),
    TextField(
      controller: _name,
      maxLength: 80,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(counterText: ''),
    ),
    const FieldLabel('Tavsif'),
    TextField(
      controller: _desc,
      maxLength: 300,
      minLines: 2,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Ixtiyoriy', counterText: ''),
    ),
    const SizedBox(height: 22),
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
    const SizedBox(height: 4),
    TextButton(
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
      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      child: const Text("Guruhni o'chirish"),
    ),
  ];

  List<Widget> _digestPane(ColorScheme scheme) {
    final d = _digest;
    if (d == null) return const [LoadingView()];
    final times = d.allowedTimes.isEmpty
        ? [for (var h = 0; h < 24; h++) '${h.toString().padLeft(2, '0')}:00']
        : d.allowedTimes;
    return [
      const SizedBox(height: 12),
      _SheetNote(
        "Belgilangan vaqtda har bir a'zoning rejasi (ertalab) va natijasi (kechqurun) Telegram guruhga yuboriladi.",
        boxed: false,
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
        items: const [('plans', 'Rejalar'), ('both', 'Ikkisi'), ('habits', 'Odatlar')],
        onChanged: (v) => _updateDigest({'report_source': v}),
      ),
      const SizedBox(height: 12),
      GroupCard(
        indent: 50,
        children: [
          _DigestRow(
            icon: LucideIcons.sunrise,
            title: 'Kunlik reja',
            subtitle: 'Ertalab — bugun nima qilinadi',
            enabled: d.plansEnabled,
            time: d.plansTime,
            times: times,
            busy: _busy,
            onEnabled: (v) => _updateDigest({'plans_enabled': v}),
            onTime: (v) => _updateDigest({'plans_time': v}),
          ),
          _DigestRow(
            icon: LucideIcons.moon,
            title: 'Kunlik hisobot',
            subtitle: 'Kechqurun — nima bajarildi',
            enabled: d.digestEnabled,
            time: d.digestTime,
            times: times,
            busy: _busy,
            onEnabled: (v) => _updateDigest({'digest_enabled': v}),
            onTime: (v) => _updateDigest({'digest_time': v}),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy || d.chatId == null ? null : () => _test('plans'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 46)),
              child: const Text('Rejani sinash', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: _busy || d.chatId == null ? null : () => _test('report'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 46)),
              child: const Text('Hisobotni sinash', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
      if (d.lastError?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        Text(
          'Oxirgi xato: ${d.lastError}',
          style: AppType.caption.copyWith(fontWeight: FontWeight.w400, color: scheme.error),
        ),
      ],
    ];
  }

  Future<void> _test(String kind) => _run(() async {
    final (ok, reason) = await _api.testDigest(_g.id, kind);
    if (mounted) toast(context, ok ? 'Telegram guruhga yuborildi' : 'Yuborilmadi: ${reason ?? 'noma\'lum sabab'}');
  });

  List<Widget> _members(ColorScheme scheme) {
    final others = _g.members.where((m) => !m.isMe).toList();
    if (others.isEmpty) return const [SizedBox(height: 12), _SheetNote("Boshqa a'zo yo'q")];
    return [
      const SizedBox(height: 12),
      _SheetNote(
        "O'chirilgan (pauza) a'zoning ma'lumotlari boshqalarga va Telegram hisobotiga ko'rinmaydi.",
        boxed: false,
      ),
      const SizedBox(height: 12),
      GroupCard(
        indent: 64,
        children: [
          for (final m in others)
            _MemberSwitchRow(
              member: m,
              name: m.name,
              value: m.isActive,
              subtitle: m.isActive ? 'Faol' : 'Pauza',
              onChanged: _busy
                  ? null
                  : (v) => _run(() async {
                      await _api.setMemberActive(_g.id, m.userId, v);
                      final g = await _api.group(_g.id);
                      if (mounted) setState(() => _g = g);
                      widget.onChanged();
                    }),
              trailing: IconButton(
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
                icon: Icon(LucideIcons.userX, size: 19, color: scheme.error),
              ),
            ),
        ],
      ),
    ];
  }
}

/// Varaq ichidagi izoh yoki bo'sh holat matni.
class _SheetNote extends StatelessWidget {
  const _SheetNote(this.text, {this.boxed = true});
  final String text;

  /// true — bo'sh holat (yuza ichida), false — oddiy izoh.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Text(text, style: AppType.label.copyWith(fontWeight: FontWeight.w400, height: 1.45, color: scheme.onSurfaceVariant));
    if (!boxed) return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: t);
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.lg)),
      padding: const EdgeInsets.all(16),
      child: t,
    );
  }
}

/// A'zo qatori: avatar, ism (2 qatorgacha), o'ngda kalit va ixtiyoriy amal.
class _MemberSwitchRow extends StatelessWidget {
  const _MemberSwitchRow({
    required this.member,
    required this.name,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.trailing,
  });

  final GroupMember? member;
  final String name;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, trailing == null ? 12 : 4, 8),
          child: Row(
            children: [
              ProfileAvatar(url: null, telegramId: member?.telegramId ?? 0, name: name, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
                    if (subtitle != null)
                      Text(subtitle!, style: AppType.caption.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Hisobot qatori: nom va izoh, o'ngda kalit; pastida yuborish vaqti.
class _DigestRow extends StatelessWidget {
  const _DigestRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.time,
    required this.times,
    required this.busy,
    required this.onEnabled,
    required this.onTime,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final String time;
  final List<String> times;
  final bool busy;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<String> onTime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
                    Text(subtitle, style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: enabled, onChanged: busy ? null : onEnabled),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 2),
            child: Row(
              children: [
                Text('Vaqt', style: AppType.label.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: times.contains(time) ? time : null,
                  hint: Text(time, style: AppType.bodyStrong.copyWith(fontFeatures: tabularFigures)),
                  isDense: true,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  icon: Icon(LucideIcons.chevronDown, size: 16, color: scheme.onSurfaceVariant),
                  style: AppType.bodyStrong.copyWith(fontFamily: AppTheme.fontFamily, color: scheme.onSurface, fontFeatures: tabularFigures),
                  items: [for (final t in times) DropdownMenuItem(value: t, child: Text(t))],
                  onChanged: busy ? null : (v) => v == null ? null : onTime(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Guruh nomining bosh harfi.
class _GroupMonogram extends StatelessWidget {
  const _GroupMonogram({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = name.trim();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Text(
        t.isEmpty ? '#' : t.characters.first.toUpperCase(),
        style: AppType.bodyStrong.copyWith(fontSize: 16, color: scheme.onPrimaryContainer),
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
        ? Icon(g, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant)
        : Text(icon, style: AppType.body);
  }
}

/// Guruh sahifasi (Natijalar → Do'stlar ro'yxatidan ochiladi).
/// Orqaga: a'zo → guruh → ro'yxat.
class FriendsRoute extends StatefulWidget {
  const FriendsRoute({super.key, required this.state, required this.groupId});

  final AppState state;
  final int groupId;

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
      body: SafeArea(child: FriendsPage(key: _key, state: widget.state, groupId: widget.groupId)),
    ),
  );
}
