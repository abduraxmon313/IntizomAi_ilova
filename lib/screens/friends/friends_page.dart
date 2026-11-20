import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/friends.dart';
import '../../models/profile.dart';
import '../../services/api_client.dart';
import '../../services/intizom_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';
import '../forms.dart';
import '../profile/profile_page.dart' show LowerCaseFormatter, ProfileAvatar;

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
  List<IncomingInvite> _invites = const [];
  bool _canCreate = false;
  GroupDetail? _group;
  MemberView? _member;
  int? _memberUid;
  DateTime _memberDay = tashkentToday();

  bool _loading = false;
  String _memberQuery = '';
  String? _premiumMessage;

  static int _memberTotal(GroupMember m) => m.plansTotal + m.habitsTotal;

  static double _memberRatio(GroupMember m) {
    final total = _memberTotal(m);
    return total == 0 ? 0 : (m.plansDone + m.habitsDone) / total;
  }

  /// Avval o'zingiz, keyin bugungi natijasi yuqori bo'lganlar.
  List<GroupMember> _sortedMembers(GroupDetail g) {
    final list = g.members.where((m) => _memberQuery.isEmpty || m.name.toLowerCase().contains(_memberQuery)).toList();
    list.sort((a, b) {
      if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
      final av = a.isMe || a.visible ? _memberRatio(a) : -1.0;
      final bv = b.isMe || b.visible ? _memberRatio(b) : -1.0;
      final byRatio = bv.compareTo(av);
      return byRatio != 0 ? byRatio : b.streak.compareTo(a.streak);
    });
    return list;
  }
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
      final r = await Future.wait([s.api.groups(), s.api.invites()]);
      if (!mounted) return;
      final list = r[0] as GroupList;
      setState(() {
        _groups = list.groups;
        _canCreate = list.canCreate;
        _invites = r[1] as List<IncomingInvite>;
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

  // ── Takliflar ──────────────────────────────────────
  Future<void> _acceptInvite(IncomingInvite inv) async {
    try {
      await s.api.acceptInvite(inv.id);
      successFeedback();
      if (!mounted) return;
      toast(context, context.tr("«{v0}» guruhiga qo'shildingiz", {'v0': inv.groupName}));
      await _loadGroups();
      if (mounted) _pushGroup(inv.groupId);
    } catch (e) {
      if (mounted) showApiError(context, e);
      _loadGroups();
    }
  }

  Future<void> _declineInvite(IncomingInvite inv) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.x),
              title: Text(context.tr("Rad etish")),
              onTap: () => Navigator.pop(ctx, 'decline'),
            ),
            ListTile(
              leading: Icon(LucideIcons.ban, color: Theme.of(ctx).colorScheme.error),
              title: Text(
                context.tr("Rad etish va @{v0} ni bloklash", {'v0': inv.inviter.username ?? ''}),
                style: AppType.body.copyWith(color: Theme.of(ctx).colorScheme.error),
              ),
              subtitle: Text(context.tr("U sizga boshqa taklif yubora olmaydi")),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      await s.api.declineInvite(inv.id, block: choice == 'block');
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
    _loadGroups();
  }

  /// Ega username orqali taklif yuboradi: avval foydalanuvchi kartasi ko'rsatiladi.
  Future<void> _invite(GroupDetail g) async {
    final ctrl = TextEditingController();
    UserCard? found;
    String? note;
    var busy = false;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final scheme = Theme.of(ctx).colorScheme;
          Future<void> lookup() async {
            final u = ctrl.text.trim();
            if (u.length < 3) return;
            setSheet(() {
              busy = true;
              note = null;
              found = null;
            });
            try {
              final card = await s.api.lookupUser(u);
              setSheet(() => found = card);
            } on ApiException catch (e) {
              setSheet(() => note = e.message);
            } finally {
              setSheet(() => busy = false);
            }
          }

          Future<void> send() async {
            final f = found;
            if (f?.username == null) return;
            setSheet(() => busy = true);
            try {
              await s.api.inviteToGroup(g.id, f!.username!);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on ApiException catch (e) {
              setSheet(() {
                note = e.message;
                busy = false;
              });
            }
          }

          return SheetScaffold(
            title: context.tr("Guruhga taklif qilish"),
            subtitle: g.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr("Do'stingizning username'ini yozing. U taklifni ilovada ko'radi va qabul qilsa, guruhga qo'shiladi."),
                  style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant, height: 1.45),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: 20,
                        textInputAction: TextInputAction.search,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')), LowerCaseFormatter()],
                        decoration: const InputDecoration(prefixText: '@', hintText: 'username', counterText: ''),
                        onChanged: (_) => setSheet(() {
                          found = null;
                          note = null;
                        }),
                        onSubmitted: (_) => lookup(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: busy ? null : lookup, child: Text(context.tr("Topish"))),
                  ],
                ),
                if (note != null) ...[
                  const SizedBox(height: 10),
                  Text(note!, style: AppType.label.copyWith(color: scheme.error)),
                ],
                if (found != null) ...[
                  const SizedBox(height: 14),
                  GroupCard(
                    children: [
                      ListTile(
                        leading: ProfileAvatar(url: found!.photoUrl, name: found!.name, size: 40),
                        title: Text(found!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.bodyStrong),
                        subtitle: Text('@${found!.username}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: busy ? null : send,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(LucideIcons.send, size: 18),
                    label: Text(context.tr("Taklif yuborish")),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    if (sent == true && mounted) {
      toast(context, context.tr("Taklif yuborildi"));
      _reloadGroup();
    }
  }

  Future<void> _cancelInvite(GroupDetail g, OutgoingInvite inv) async {
    try {
      await s.api.cancelInvite(g.id, inv.id);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
    _reloadGroup();
  }

  // ── Guruh amallari ─────────────────────────────────
  Future<void> _createGroup() async {
    if (!_canCreate) {
      showPremiumDialog(context, context.tr("Guruh yaratish Premium bilan ochiladi. Do'stingiz taklif qilsa, guruhga bepul qo'shilasiz."));
      return;
    }
    final name = TextEditingController();
    final desc = TextEditingController();
    await showFormSheet<void>(
      context,
      title: context.tr("Yangi guruh"),
      saveLabel: context.tr("Yaratish"),
      builder: (ctx, _) => Column(
        children: [
          TextField(
            controller: name,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration:  InputDecoration(hintText: context.tr("Guruh nomi (masalan: Oila, Ish jamoasi)"), counterText: ''),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: desc,
            maxLength: 300,
            minLines: 2,
            maxLines: 4,
            decoration:  InputDecoration(hintText: context.tr("Tavsif (ixtiyoriy)"), counterText: ''),
          ),
        ],
      ),
      onSave: () async {
        if (name.text.trim().isEmpty) {
          toast(context, context.tr("Guruh nomini yozing"));
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
            title: context.tr("Ruxsatlar"),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                 SectionBar(title: context.tr("Kim men uchun reja va odat yarata oladi"), top: 4),
                if (others.isEmpty)
                   _SheetNote(context.tr("Guruhda boshqa a'zo yo'q"))
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
                    context.tr("Yoqilgan a'zo sizning hisobingizga reja va odat qo'sha oladi."),
                    style: AppType.caption.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                  ),
                ),
                 SectionBar(title: context.tr("Menga ruxsat berganlar"), top: 22),
                if (incoming.isEmpty)
                   _SheetNote(context.tr("Hozircha hech kim"))
                else
                  GroupCard(
                    indent: 50,
                    children: [
                      for (final p in incoming)
                        SettingTile(
                          icon: LucideIcons.userCheck,
                          title: p.name,
                          subtitle: context.tr("Uning uchun reja va odat yarata olasiz"),
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
         PageHeader(title: context.tr("Guruh")),
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
                      title: context.tr("Do'stlar Premium bilan ochiladi"),
                      message: context.tr("Oila, do'stlar yoki jamoa bilan guruh tuzing va bir-biringizning kunini kuzating."),
                      onOpen: () => showPremiumDialog(context, _premiumMessage!),
                    ),
                  );
                }
                if (_error != null) return ErrorRetry(message: _error!, onRetry: _loadGroups);
                final invites = _invitesSection();
                if (groups.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...invites,
                      EmptyView(
                        icon: LucideIcons.users,
                        title: context.tr("Hozircha guruh yo'q"),
                        message: _invites.isEmpty
                            ? context.tr("Guruh yarating va do'stlaringizni username orqali taklif qiling. Yoki do'stingiz sizni taklif qilsin — taklif shu yerda chiqadi.")
                            : null,
                        actionLabel: context.tr("Yangi guruh"),
                        onAction: _createGroup,
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...invites,
                    SectionBar(title: context.tr("Guruhlar"), count: '${groups.length}', actionLabel: context.tr("Yangi guruh"), onAction: _createGroup, top: 8),
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
                                            if (g.isOwner) ...[const SizedBox(width: 6),  Pill(context.tr("Ega"))],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          context.tr("{v0} a'zo{v1}", {'v0': g.memberCount, 'v1': g.description?.isNotEmpty == true ? ' · ${g.description}' : ''}),
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

  List<Widget> _invitesSection() {
    if (_invites.isEmpty) return const [];
    final scheme = Theme.of(context).colorScheme;
    return [
      SectionBar(title: context.tr("Takliflar"), count: '${_invites.length}', top: 8),
      for (final inv in _invites)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ProfileAvatar(url: inv.inviter.photoUrl, name: inv.inviter.name, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv.groupName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.bodyStrong),
                          const SizedBox(height: 2),
                          Text(
                            context.tr("{v0} taklif qildi · {v1} a'zo", {
                              'v0': inv.inviter.username == null ? inv.inviter.name : '@${inv.inviter.username}',
                              'v1': inv.memberCount,
                            }),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (inv.groupDescription?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(inv.groupDescription!, style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _declineInvite(inv),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                        child: Text(context.tr("Rad etish")),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _acceptInvite(inv),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                        child: Text(context.tr("Qo'shilish")),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
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
            subtitle: context.tr("{v0} a'zo", {'v0': g.members.length}),
            actions: [
              HeaderIconButton(icon: LucideIcons.settings, tooltip: context.tr("Guruh sozlamalari"), onTap: () => _groupSettings(g)),
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
                    final perms = OutlinedButton.icon(
                      onPressed: () => _permissions(g),
                      style: OutlinedButton.styleFrom(padding: pad, minimumSize: const Size(0, 48)),
                      icon: const Icon(LucideIcons.shield, size: 18),
                      label:  Text(context.tr("Ruxsatlar"), maxLines: 1),
                    );
                    // Taklifni faqat ega yuboradi.
                    if (!g.isOwner) return perms;
                    final invite = FilledButton.icon(
                      onPressed: () => _invite(g),
                      style: FilledButton.styleFrom(padding: pad, minimumSize: const Size(0, 48)),
                      icon: const Icon(LucideIcons.userPlus, size: 18),
                      label:  Text(context.tr("Taklif qilish"), maxLines: 1),
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
                _GroupTodaySummary(members: g.members),
                SectionBar(title: context.tr("A'zolar"), count: '${g.members.length}'),
                if (g.members.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      onChanged: (v) => setState(() => _memberQuery = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: context.tr("A'zoni qidirish"),
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        isDense: true,
                      ),
                    ),
                  ),
                GroupCard(
                  indent: 66,
                  children: [
                    for (final m in _sortedMembers(g))
                      InkWell(
                        onTap: () => _openMember(m.userId),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                          child: Row(
                            children: [
                              ProfileAvatar(url: m.photoUrl, name: m.name, size: 38),
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
                                        if (m.isMe) ...[const SizedBox(width: 6),  Pill(context.tr("Siz"))],
                                        if (m.isOwner) ...[const SizedBox(width: 6),  Pill(context.tr("Ega"))],
                                        if (!m.isActive) ...[const SizedBox(width: 6),  Pill(context.tr("Pauza"), muted: true)],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 12,
                                      children: m.isMe || m.visible
                                          ? [
                                              MetaTag(icon: LucideIcons.calendarCheck, text: context.tr("Reja {v0}/{v1}", {'v0': m.plansDone, 'v1': m.plansTotal})),
                                              MetaTag(icon: LucideIcons.repeat, text: context.tr("Odat {v0}/{v1}", {'v0': m.habitsDone, 'v1': m.habitsTotal})),
                                              MetaTag(icon: LucideIcons.flame, text: context.tr("{v0} kun", {'v0': m.streak}), color: AppPalette.ember),
                                            ]
                                          : [
                                               MetaTag(icon: LucideIcons.lock, text: context.tr("Yashirin")),
                                              MetaTag(icon: LucideIcons.flame, text: context.tr("{v0} kun", {'v0': m.streak}), color: AppPalette.ember),
                                            ],
                                    ),
                                    if ((m.isMe || m.visible) && _memberTotal(m) > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: _memberRatio(m),
                                                minHeight: 5,
                                                backgroundColor: scheme.surfaceContainerHighest,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${(_memberRatio(m) * 100).round()}%',
                                            style: AppType.caption.copyWith(fontFeatures: tabularFigures, color: scheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ],
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
                if (g.isOwner && g.pendingInvites.isNotEmpty) ...[
                  SectionBar(title: context.tr("Javob kutilmoqda"), count: '${g.pendingInvites.length}'),
                  GroupCard(
                    indent: 66,
                    children: [
                      for (final inv in g.pendingInvites)
                        ListTile(
                          leading: ProfileAvatar(url: inv.user.photoUrl, name: inv.user.name, size: 38),
                          title: Text(inv.user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: inv.user.username == null ? null : Text('@${inv.user.username}'),
                          trailing: TextButton(
                            onPressed: () => _cancelInvite(g, inv),
                            child: Text(context.tr("Bekor qilish")),
                          ),
                        ),
                    ],
                  ),
                ],
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
            subtitle: context.tr("{v0} kunlik seriya · {v1} ball", {'v0': m.streak, 'v1': m.totalScore}),
            onBack: handleBack,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PeriodStepper(
                  label: relativeDay(context, _memberDay),
                  isCurrent: m.isToday,
                  onReset: () => _openMember(_memberUid!, tashkentToday()),
                  onPrev: () => shift(-1),
                  onNext: () => shift(1),
                ),
                if (!m.visible)
                   Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: EmptyView(
                      icon: LucideIcons.lock,
                      title: context.tr("Ma'lumotlari yashirin"),
                      message: context.tr("Bu a'zoning reja va odatlari sizga ko'rinmaydi."),
                    ),
                  )
                else ...[
                  SectionBar(
                    top: 12,
                    title: context.tr("Rejalar"),
                    count: '${plans.where((p) => p.done).length}/${plans.length}',
                    actionLabel: canManage ? context.tr("Reja qo'shish") : null,
                    onAction: canManage
                        ? () async {
                            final ok = await showPlanForm(
                              context,
                              api: s.api,
                              initialDate: _memberDay,
                              titleOverride: context.tr("{v0} uchun reja", {'v0': m.name}),
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
                  _memberItems(plans, context.tr("Reja yo'q")),
                  SectionBar(
                    title: context.tr("Odatlar"),
                    count: '${habits.where((h) => h.done).length}/${habits.length}',
                    actionLabel: canManage ? context.tr("Odat qo'shish") : null,
                    onAction: canManage
                        ? () async {
                            final ok = await showHabitForm(
                              context,
                              api: s.api,
                              titleOverride: context.tr("{v0} uchun odat", {'v0': m.name}),
                              onSubmit: (input) => s.api.createHabitForMember(g.id, m.userId, input),
                            );
                            if (ok) _openMember(_memberUid!, _memberDay);
                          }
                        : null,
                  ),
                  _memberItems(habits, context.tr("Odat yo'q")),
                  if (!canManage && !m.isMe)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        context.tr("Bu a'zo sizga u uchun reja yaratishga ruxsat bermagan."),
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

/// Guruh sozlamalari: Umumiy / A'zolar (ega uchun), a'zo uchun — chiqish.
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final owner = _g.isOwner;
    return SheetScaffold(
      title: context.tr("Guruh sozlamalari"),
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
                  title: context.tr("Guruhdan chiqish"),
                  danger: true,
                  onTap: _busy
                      ? null
                      : () async {
                          if (!await confirmAction(context, title: context.tr("Guruhdan chiqish"), message: _g.name, confirmLabel: context.tr("Chiqish"))) return;
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
              items:  [('general', context.tr("Umumiy")), ('members', context.tr("A'zolar"))],
              onChanged: (v) => setState(() => _tab = v),
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
     FieldLabel(context.tr("Guruh nomi")),
    TextField(
      controller: _name,
      maxLength: 80,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(counterText: ''),
    ),
     FieldLabel(context.tr("Tavsif")),
    TextField(
      controller: _desc,
      maxLength: 300,
      minLines: 2,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      decoration:  InputDecoration(hintText: context.tr("Ixtiyoriy"), counterText: ''),
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
      child:  Text(context.tr("Saqlash")),
    ),
    const SizedBox(height: 4),
    TextButton(
      onPressed: _busy
          ? null
          : () async {
              if (!await confirmAction(
                context,
                title: context.tr("Guruhni o'chirish"),
                message: context.tr("«{v0}» va undagi ruxsatlar o'chiriladi.", {'v0': _g.name}),
              )) {
                return;
              }
              await _run(() => _api.deleteGroup(_g.id));
              if (!mounted) return;
              Navigator.pop(context);
              widget.onGone();
            },
      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      child:  Text(context.tr("Guruhni o'chirish")),
    ),
  ];

  List<Widget> _members(ColorScheme scheme) {
    final others = _g.members.where((m) => !m.isMe).toList();
    if (others.isEmpty) return  [SizedBox(height: 12), _SheetNote(context.tr("Boshqa a'zo yo'q"))];
    return [
      const SizedBox(height: 12),
      _SheetNote(
        context.tr("Pauzadagi a'zoning reja va odatlari boshqa a'zolarga ko'rinmaydi."),
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
              subtitle: m.isActive ? context.tr("Faol") : context.tr("Pauza"),
              onChanged: _busy
                  ? null
                  : (v) => _run(() async {
                      await _api.setMemberActive(_g.id, m.userId, v);
                      final g = await _api.group(_g.id);
                      if (mounted) setState(() => _g = g);
                      widget.onChanged();
                    }),
              trailing: PopupMenuButton<String>(
                enabled: !_busy,
                tooltip: context.tr("Amallar"),
                icon: Icon(LucideIcons.ellipsisVertical, size: 19, color: scheme.onSurfaceVariant),
                onSelected: (action) async {
                  if (action == 'remove') {
                    if (!await confirmAction(context, title: context.tr("Guruhdan chiqarish"), message: m.name, confirmLabel: context.tr("Chiqarish"))) return;
                    await _run(() async {
                      await _api.removeMember(_g.id, m.userId);
                      final g = await _api.group(_g.id);
                      if (mounted) setState(() => _g = g);
                      widget.onChanged();
                    });
                  } else if (action == 'transfer') {
                    if (!await confirmAction(
                      context,
                      title: context.tr("Egalikni topshirish"),
                      message: context.tr("{v0} guruh egasi bo'ladi. Siz oddiy a'zo bo'lib qolasiz.", {'v0': m.name}),
                      confirmLabel: context.tr("Topshirish"),
                      danger: false,
                    )) {
                      return;
                    }
                    await _run(() async {
                      await _api.transferGroup(_g.id, m.userId);
                      widget.onChanged();
                      if (mounted) Navigator.pop(context);
                    });
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'transfer', child: Text(context.tr("Egalikni topshirish"))),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(context.tr("Chiqarib yuborish"), style: TextStyle(color: scheme.error)),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }
}

/// Varaq ichidagi izoh yoki bo'sh holat matni.
class _GroupTodaySummary extends StatelessWidget {
  const _GroupTodaySummary({required this.members});

  final List<GroupMember> members;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = members.where((m) => m.isMe || m.visible).toList();
    var done = 0, total = 0, finished = 0;
    for (final m in visible) {
      final t = m.plansTotal + m.habitsTotal;
      final d = m.plansDone + m.habitsDone;
      done += d;
      total += t;
      if (t > 0 && d >= t) finished++;
    }
    final ratio = total == 0 ? 0.0 : done / total;
    final bestStreak = members.fold<int>(0, (a, m) => m.streak > a ? m.streak : a);
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, style: AppType.bodyStrong.copyWith(fontFeatures: tabularFigures)),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppType.caption.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr("Bugun guruhda"), style: AppType.bodyStrong),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                stat('${(ratio * 100).round()}%', context.tr("Umumiy bajarilish")),
                stat('$finished/${visible.length}', context.tr("Kunni yakunlagan")),
                stat('$bestStreak', context.tr("Eng uzun seriya")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
              ProfileAvatar(url: member?.photoUrl, name: name, size: 36),
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
