import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/extras.dart';
import '../../models/goal.dart';
import '../../models/habit.dart';
import '../../models/plan.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/dates.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui_kit.dart';
import '../forms.dart';
import '../profile/profile_page.dart';

/// Bugun — ilovaning asosiy sahifasi. Faqat bugungi kun haqida:
/// 1) Kun qanday ketyapti? — bitta holat bloki (bajarilish, seriya, intizom).
/// 2) Nimaga e'tibor kerak? — faqat kerak bo'lganda chiqadigan bitta tavsiya.
/// 3) Hozir nima qilaman? — bugungi rejalar va odatlar, bir bosishda belgilanadi.
/// 4) Bu nima uchun? — shu oyning maqsadi.
/// 5) O'zimni qanday his qilyapman? — kunlik holat (AI murabbiy uchun).
class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.state,
    required this.onLogout,
    required this.onAppearanceChanged,
    required this.onOpenGoals,
  });

  final AppState state;
  final VoidCallback onLogout;
  final ValueChanged<String> onAppearanceChanged;
  final VoidCallback onOpenGoals;

  @override
  State<TodayPage> createState() => TodayPageState();
}

class TodayPageState extends State<TodayPage> {
  AppState get s => widget.state;

  List<Plan> _today = const [];
  List<Plan> _week = const []; // oxirgi 7 kun (tavsiya uchun)
  bool _loaded = false;
  int _seenVersion = -1;
  Checkin _checkin = const Checkin();
  bool _checkinLoaded = false;

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
    _seenVersion = s.plansVersion;
    _loadPlans();
    _loadCheckin();
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (s.plansVersion != _seenVersion) {
      _seenVersion = s.plansVersion;
      _loadPlans();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadPlans() async {
    try {
      final t = tashkentToday();
      final w = await s.api.plansBetween(t.subtract(const Duration(days: 7)), t);
      if (!mounted) return;
      final k = ymd(t);
      setState(() {
        _week = w;
        _today = w.where((p) => p.planDate == k).toList();
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _loadCheckin() async {
    try {
      final c = await s.api.checkin();
      if (mounted) setState(() => _checkin = c ?? const Checkin());
    } catch (_) {}
    if (mounted) setState(() => _checkinLoaded = true);
  }

  Future<void> _refresh() => Future.wait([s.loadAll(), _loadPlans(), _loadCheckin()]);

  Future<void> _saveCheckin({String? mood, int? energy}) async {
    final prev = _checkin;
    setState(() => _checkin = Checkin(mood: mood ?? prev.mood, energy: energy ?? prev.energy));
    try {
      await s.api.saveCheckin(mood: mood, energy: energy);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkin = prev);
      showApiError(context, e);
    }
  }

  Future<void> _setPlanDone(Plan p, bool done, {bool undoable = true}) async {
    try {
      final updated = await s.api.setPlanStatus(p.id, done ? 'done' : 'pending');
      if (!mounted) return;
      setState(() => _today = [for (final x in _today) x.id == p.id ? updated : x]);
      if (updated.isDone && undoable) {
        toast(
          context,
          'Bajarildi · +${updated.scoreValue} ball',
          actionLabel: 'Qaytarish',
          onAction: () => _setPlanDone(updated, false),
        );
      }
      s.plansChanged();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  /// Bugunga reja qo'shish (pastdagi "+" tugmasi).
  Future<void> addPlan() async {
    if (await showPlanForm(context, api: s.api, initialDate: tashkentToday())) s.plansChanged();
  }

  Future<void> _editPlan(Plan p) async {
    if (await showPlanForm(context, api: s.api, plan: p)) s.plansChanged();
  }

  Future<void> _editHabit(Habit h) async {
    if (await showHabitForm(context, api: s.api, habit: h)) {
      await s.refreshHabits();
      s.refreshStats();
    }
  }

  Future<void> _setHabitDone(Habit h, bool done, {bool undoable = true}) async {
    try {
      final updated = await s.api.toggleHabit(h.id, done: done);
      s.replaceHabit(updated);
      if (!mounted) return;
      if (updated.doneToday && undoable) {
        toast(
          context,
          updated.streak > 1 ? '${updated.title} · ${updated.streak} kun ketma-ket' : '${updated.title} · bajarildi',
          actionLabel: 'Qaytarish',
          onAction: () => _setHabitDone(updated, false),
        );
      }
      s.refreshStats();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  void _openProfile() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProfilePage(state: s, onLogout: widget.onLogout, onAppearanceChanged: widget.onAppearanceChanged),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final profile = s.profile!;
    final st = s.stats;
    final today = tashkentToday();
    final now = tashkentHm();

    // Bajarilmaganlar yuqorida (vaqt bo'yicha), bajarilganlar pastda.
    int byTime(String? a, String? b) => (a ?? '99:99').compareTo(b ?? '99:99');
    final plans = [..._today]..sort((a, b) => a.isDone == b.isDone ? byTime(a.scheduledTime, b.scheduledTime) : (a.isDone ? 1 : -1));
    final habits = s.habits.where((h) => !h.finished && h.dueOn(today)).toList()
      ..sort((a, b) => a.doneToday == b.doneToday ? byTime(a.reminderTime, b.reminderTime) : (a.doneToday ? 1 : -1));

    final plansDone = plans.where((p) => p.isDone).length;
    final habitsDone = habits.where((h) => h.doneToday).length;
    final total = plans.length + habits.length;
    final done = plansDone + habitsDone;

    // Keyingi reja: vaqti hali kelmagan birinchisi, bo'lmasa — birinchi bajarilmagani.
    final pending = plans.where((p) => !p.isDone && !p.isFailed).toList();
    final next = pending.isEmpty
        ? null
        : pending.firstWhere((p) => (p.scheduledTime ?? '').compareTo(now) >= 0, orElse: () => pending.first);

    final month = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final monthGoals = s.goals.where((g) => g.goalType == 'monthly' && g.period == month).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, AppSpace.bottomInset),
        children: [
          _Header(
            name: profile.fullName,
            avatar: profile.avatar,
            telegramId: profile.telegramId,
            onProfile: _openProfile,
          ),
          const SizedBox(height: 20),
          _DayCard(loaded: _loaded, done: done, total: total, streak: st.streak, discipline: st.disciplineScore),
          ?_insight(),

          // ── Rejalar ──────────────────────────────────
          SectionBar(title: 'Rejalar', count: plans.isEmpty ? null : '$plansDone/${plans.length}'),
          if (!_loaded)
            const _Skeleton()
          else if (plans.isEmpty)
            AppCard(
              onTap: addPlan,
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
              child: _HintRow(
                icon: LucideIcons.calendarPlus,
                title: "Bugunga reja yo'q",
                text: "Eng muhim bitta ishni yozing — bot vaqtida eslatadi.",
              ),
            )
          else
            GroupCard(
              indent: 52,
              children: [
                for (final p in plans)
                  TaskRow(
                    key: ValueKey('p${p.id}'),
                    title: p.title,
                    subtitle: p.description,
                    done: p.isDone,
                    trailing: p.scheduledTime?.isNotEmpty == true ? p.scheduledTime : null,
                    highlight: p.id == next?.id,
                    onToggle: () => _setPlanDone(p, !p.isDone),
                    onTap: () => _editPlan(p),
                  ),
              ],
            ),

          // ── Odatlar ──────────────────────────────────
          if (habits.isNotEmpty) ...[
            SectionBar(title: 'Odatlar', count: '$habitsDone/${habits.length}'),
            GroupCard(
              indent: 52,
              children: [
                for (final h in habits)
                  TaskRow(
                    key: ValueKey('h${h.id}'),
                    title: h.title,
                    done: h.doneToday,
                    trailing: h.reminderTime,
                    streak: h.streak,
                    onToggle: () => _setHabitDone(h, !h.doneToday),
                    onTap: () => _editHabit(h),
                  ),
              ],
            ),
          ],

          // ── Oy maqsadi ───────────────────────────────
          if (monthGoals.isNotEmpty) ...[
            SectionBar(title: '${uzMonths[today.month - 1]} maqsadlari'),
            _GoalsCard(goals: monthGoals, onTap: widget.onOpenGoals),
          ],

          // ── Kunlik holat ─────────────────────────────
          if (_checkinLoaded) ...[
            const SectionBar(title: 'Bugungi holat'),
            _CheckinCard(checkin: _checkin, onSave: _saveCheckin),
          ],
        ],
      ),
    );
  }

  /// Bitta, eng muhim tavsiya. Aybdorlik hissi emas — keyingi qadam.
  Widget? _insight() {
    final st = s.stats;
    final done7 = _week.where((p) => p.isDone).length;
    final total7 = _week.length;
    final rate = total7 == 0 ? 0 : (done7 * 100 / total7).round();
    const milestones = {7, 14, 21, 30, 50, 75, 100, 150, 200, 365};
    final (IconData, Color, String, String)? item;
    if (st.streakAtRisk && st.streak >= 2) {
      item = (LucideIcons.flame, AppPalette.ember, '${st.streak} kunlik seriya davom etsin', "Bugun bitta reja yoki odat bajarilsa, seriya saqlanadi.");
    } else if (milestones.contains(st.streak)) {
      item = (LucideIcons.flame, AppPalette.ember, '${st.streak} kun ketma-ket', "Bu endi odat. Bugun ham xuddi shunday davom eting.");
    } else if (rate < 40 && total7 >= 5) {
      item = (LucideIcons.sprout, AppPalette.success, 'Kichik qadamdan boshlang', "Bugun bitta yengil ishni bajaring — ritm shundan tiklanadi.");
    } else if (rate >= 80 && total7 >= 5) {
      item = (LucideIcons.trendingUp, AppPalette.success, 'Kuchli hafta', "Oxirgi 7 kunda $total7 ta rejadan $done7 tasi bajarildi.");
    } else if (st.streak == 0 && total7 > 0) {
      item = (LucideIcons.sprout, AppPalette.success, 'Bugun — yangi boshlanish', "Bitta ishni bajaring, seriya qaytadan boshlanadi.");
    } else {
      item = null;
    }
    if (item == null) return null;
    final (icon, color, title, text) = item;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? .14 : .08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: dark ? Color.lerp(color, Colors.white, .3) : color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.bodyStrong),
                  const SizedBox(height: 2),
                  Text(text, style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().toUtc().add(const Duration(hours: 5)).hour;
  if (h >= 5 && h < 11) return 'Xayrli tong';
  if (h >= 11 && h < 17) return 'Xayrli kun';
  if (h >= 17 && h < 23) return 'Xayrli kech';
  return 'Xayrli tun';
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.avatar, required this.telegramId, required this.onProfile});

  final String name;
  final String? avatar;
  final int telegramId;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = name.trim().isEmpty ? '' : name.trim().split(' ').first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                longDate(tashkentToday()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                first.isEmpty ? _greeting() : '${_greeting()}, $first',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.title,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Profil va sozlamalar',
          child: InkResponse(
            radius: 28,
            onTap: () {
              tapFeedback();
              onProfile();
            },
            child: ProfileAvatar(url: avatar, telegramId: telegramId, name: name, size: 44),
          ),
        ),
      ],
    );
  }
}

/// Kun holati: bajarilish halqasi + bitta aniq jumla, pastida seriya va intizom.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.loaded,
    required this.done,
    required this.total,
    required this.streak,
    required this.discipline,
  });

  final bool loaded;
  final int done;
  final int total;
  final int streak;
  final int discipline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final left = total - done;
    final allDone = total > 0 && left == 0;
    final ratio = total == 0 ? 0.0 : done / total;
    final ring = dark ? AppPalette.brandOnDark : AppPalette.brandBright;

    final (String title, String text) = !loaded
        ? ('Bugun', 'Yuklanmoqda…')
        : total == 0
        ? ("Bugun bo'sh kun", "Bitta reja qo'shing — kun shundan boshlanadi.")
        : allDone
        ? ('Bugun hammasi bajarildi', "Ajoyib. Ertangi kunni rejalab qo'ysangiz bo'ladi.")
        : done == 0
        ? ('Bugun $total ta ish bor', 'Birinchisidan boshlang — qolgani osonlashadi.')
        : ('$total tadan $done tasi bajarildi', left == 1 ? 'Yana bitta ish qoldi.' : 'Yana $left ta ish qoldi.');

    Widget stat(IconData icon, Color color, String value, String label) => Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, style: AppType.bodyStrong.copyWith(fontFeatures: tabularFigures)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: surfaceDecoration(context, radius: AppRadius.xl),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(
                value: ratio,
                size: 68,
                stroke: 7,
                color: ring,
                child: allDone
                    ? Icon(LucideIcons.check, size: 26, color: scheme.tertiary)
                    : Text(
                        '${(ratio * 100).round()}%',
                        style: AppType.bodyStrong.copyWith(fontSize: 16, fontFeatures: tabularFigures, letterSpacing: -.4),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.heading),
                    const SizedBox(height: 3),
                    Text(text, style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(LucideIcons.flame, streak > 0 ? AppPalette.ember : scheme.outline, '$streak kun', 'seriya'),
              const SizedBox(width: 12),
              stat(LucideIcons.gauge, scheme.tertiary, '$discipline', 'intizom balli'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        AppIconTile(icon: icon, size: 40),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.bodyStrong),
              const SizedBox(height: 2),
              Text(text, style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 112,
    decoration: surfaceDecoration(context),
    child: const LoadingView(padding: 0),
  );
}

/// Shu oyning maqsadlari — bugungi ishlar nima uchun ekanini eslatadi.
class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.goals, required this.onTap});

  final List<Goal> goals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = goals.where((g) => g.completed).length;
    final focus = goals.where((g) => !g.completed).firstOrNull;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Icon(LucideIcons.target, size: 20, color: scheme.tertiary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  focus?.title ?? 'Barcha maqsadlar bajarildi',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${goals.length} tadan $done tasi bajarildi',
                  style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
        ],
      ),
    );
  }
}

/// Kayfiyat: serverga emoji yuboriladi (AI konteksti uchun), ilovada ikonka.
const _moods = [
  ('🔥', LucideIcons.flame, "A'lo"),
  ('💪', LucideIcons.zap, 'Kuchli'),
  ('😐', LucideIcons.meh, 'Oddiy'),
  ('😴', LucideIcons.moon, 'Charchoq'),
  ('😞', LucideIcons.frown, 'Past'),
];

/// Kunlik holat. Belgilangach bir qatorga yig'iladi — sahifani band qilmaydi.
class _CheckinCard extends StatefulWidget {
  const _CheckinCard({required this.checkin, required this.onSave});

  final Checkin checkin;
  final Future<void> Function({String? mood, int? energy}) onSave;

  @override
  State<_CheckinCard> createState() => _CheckinCardState();
}

class _CheckinCardState extends State<_CheckinCard> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = widget.checkin;
    final complete = c.mood != null && c.energy != null;
    final mood = _moods.where((m) => m.$1 == c.mood).firstOrNull;

    if (complete && !_editing) {
      return AppCard(
        onTap: () => setState(() => _editing = true),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Icon(mood?.$2 ?? LucideIcons.smile, size: 20, color: scheme.tertiary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '${mood?.$3 ?? 'Belgilangan'} · energiya ${c.energy}/5',
                style: AppType.body.copyWith(fontWeight: FontWeight.w500, fontFeatures: tabularFigures),
              ),
            ),
            Text("O'zgartirish", style: AppType.label.copyWith(fontWeight: FontWeight.w600, color: scheme.tertiary)),
          ],
        ),
      );
    }

    return Container(
      decoration: surfaceDecoration(context),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kayfiyatingiz qanday?', style: AppType.bodyStrong),
          const SizedBox(height: 2),
          Text(
            'Murabbiy maslahat berishda shuni hisobga oladi.',
            style: AppType.label.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (i, (emoji, icon, label)) in _moods.indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                    child: ChoiceChipBox(
                      selected: c.mood == emoji,
                      onTap: () => widget.onSave(mood: emoji),
                      scaleToFit: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(icon, size: 20),
                          const SizedBox(height: 5),
                          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: AppType.micro)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Energiya', style: AppType.label.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text(
                c.energy == null ? 'Tanlanmagan' : '${c.energy} / 5',
                style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var e = 1; e <= 5; e++)
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Energiya $e',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        tapFeedback();
                        await widget.onSave(energy: e);
                        if (mounted) setState(() => _editing = false);
                      },
                      child: Padding(
                        padding: EdgeInsets.only(left: e == 1 ? 0 : 4, top: 10, bottom: 10),
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          height: 10,
                          decoration: BoxDecoration(
                            color: (c.energy ?? 0) >= e ? scheme.primary : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
