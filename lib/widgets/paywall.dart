import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/extras.dart';
import '../services/intizom_api.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';
import 'ui_kit.dart';

/// Premium holati o'zgarganda oshadi (AppState tinglaydi va statistikani yangilaydi).
final premiumChanged = ValueNotifier<int>(0);

/// Ilova ichida Premium sotib olish oynasi: tarif → to'lov usuli → (promokod) → to'lash.
/// To'lov Paylov sahifasida bo'ladi; ilovaga qaytgach holat avtomatik tekshiriladi.
/// [promo] berilsa — promokod oldindan qo'llanadi (Profil → Promokod'dan kelganda).
Future<void> showPaywall(BuildContext context, {String? message, String? promo}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _PaywallSheet(message: message, initialPromo: promo),
  );
}

enum _Stage { choose, waiting, success }

/// Premium rangi (oltin): tugma va tanlangan holat. Ustidagi matn to'q jigarrang (AA).
Color _premiumFill(Brightness b) => AppPalette.premiumFill(b);
Color _onPremium(Brightness b) => AppPalette.onPremium(b);

/// Toj plitasi: ikkala rejimda ham bir xil oltin gradient, to'q ikonka.
const _crownGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFD54F), Color(0xFFE0A100)],
);

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet({this.message, this.initialPromo});
  final String? message;
  final String? initialPromo;

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> with WidgetsBindingObserver {
  final _api = IntizomApi();
  late final _promo = TextEditingController(text: widget.initialPromo ?? '');

  Subscription? _sub;
  String? _error;
  String? _plan;
  String? _provider;
  String? _appliedPromo;
  String? _promoError;
  bool _busy = false;
  bool _promoBusy = false;
  late bool _showPromo = (widget.initialPromo ?? '').isNotEmpty;

  _Stage _stage = _Stage.choose;
  PaymentOrder? _order;
  Timer? _poll;
  DateTime? _waitStarted;
  int _grantedDays = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final p = widget.initialPromo?.trim();
    _load(promo: p == null || p.isEmpty ? null : p);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _promo.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // To'lov sahifasidan qaytildi — darhol tekshiramiz.
    if (state == AppLifecycleState.resumed && _stage == _Stage.waiting) _checkOrder();
  }

  Future<void> _load({String? promo}) async {
    setState(() {
      if (promo == null) {
        _busy = true;
      } else {
        _promoBusy = true;
      }
      _error = null;
      _promoError = null;
    });
    try {
      final s = await _api.subscription(promoCode: promo);
      if (!mounted) return;
      setState(() {
        _sub = s;
        _plan ??= s.plans.length > 1 ? s.plans[1].key : (s.plans.isEmpty ? null : s.plans.first.key);
        if (_provider == null || !s.providers.any((p) => p.key == _provider)) {
          _provider = s.providers.isEmpty ? null : s.providers.first.key;
        }
        _appliedPromo = (s.promo?.valid ?? false) ? s.promo!.code : null;
        if (promo != null && (s.promo == null || !s.promo!.valid)) {
          _promoError = context.tr("Promokod yaroqsiz yoki muddati tugagan");
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _promoBusy = false;
        });
      }
    }
  }

  void _removePromo() {
    _promo.clear();
    setState(() {
      _appliedPromo = null;
      _showPromo = false;
    });
    _load();
  }

  PricePlan? get _selected => _sub?.plans.where((p) => p.key == _plan).firstOrNull;

  Future<void> _pay() async {
    final plan = _plan;
    final provider = _provider;
    if (plan == null || provider == null) return;
    setState(() => _busy = true);
    try {
      final order = await _api.checkout(plan: plan, provider: provider, promoCode: _appliedPromo);
      final url = order.checkoutUrl;
      if (!mounted) return;
      if (url == null) {
        toast(context, context.tr("To'lov sahifasi ochilmadi"));
        return;
      }
      setState(() {
        _order = order;
        _stage = _Stage.waiting;
        _waitStarted = DateTime.now();
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _checkOrder());
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) toast(context, context.tr("To'lov sahifasi ochilmadi"));
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopenCheckout() async {
    final url = _order?.checkoutUrl;
    if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _checkOrder() async {
    final o = _order;
    if (o == null) return;
    if (_waitStarted != null && DateTime.now().difference(_waitStarted!) > const Duration(minutes: 20)) {
      _poll?.cancel();
    }
    try {
      final fresh = await _api.paymentStatus(o.orderId);
      if (!mounted) return;
      if (fresh.isPaid) {
        _poll?.cancel();
        successFeedback();
        premiumChanged.value++;
        setState(() {
          _stage = _Stage.success;
          _grantedDays = fresh.days ?? 0;
          _sub = fresh.subscription ?? _sub;
        });
      } else if (fresh.isFinal) {
        _poll?.cancel();
        setState(() {
          _stage = _Stage.choose;
          _order = null;
        });
        toast(context, context.tr("To'lov bekor qilindi"));
      }
    } catch (_) {
      // Tarmoq xatosi — keyingi urinishda.
    }
  }

  Future<void> _redeemFree() async {
    final code = _appliedPromo ?? _promo.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final days = await _api.redeemPromo(code);
      premiumChanged.value++;
      if (!mounted) return;
      successFeedback();
      setState(() {
        _grantedDays = days;
        _stage = _Stage.success;
      });
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Qobiq ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * .94;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: AnimatedSize(
          duration: AppMotion.base,
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: switch (_stage) {
            _Stage.success => _scrollable(_successView()),
            _Stage.waiting => _scrollable(_waitingView()),
            _Stage.choose => _chooseView(),
          },
        ),
      ),
    );
  }

  Widget _scrollable(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(AppSpace.page, 10, AppSpace.page, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_handle(), Align(alignment: Alignment.centerRight, child: _closeButton()), child],
    ),
  );

  Widget _handle() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _closeButton() => IconButton(
    tooltip: context.tr("Yopish"),
    onPressed: () => Navigator.pop(context),
    icon: Icon(LucideIcons.x, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
  );

  // ── Tanlash ────────────────────────────────────────────
  Widget _chooseView() {
    final s = _sub;
    return Column(
      key: const ValueKey('choose'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, 10, AppSpace.page, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _handle(),
                const SizedBox(height: 12),
                _hero(s),
                if (s == null)
                  _error != null ? _loadError() : const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: LoadingView())
                else ...[
                  SectionBar(title: context.tr("Tarifni tanlang"), top: 22),
                  ..._planTiles(s.plans),
                  if (s.providers.length > 1) ...[
                    SectionBar(title: context.tr("To'lov usuli"), top: 18),
                    _providers(s.providers),
                  ],
                  const SizedBox(height: 14),
                  _promoBlock(s),
                  SectionBar(title: context.tr("Nimalar ochiladi"), top: 22),
                  _comparison(s.freeLimits),
                ],
              ],
            ),
          ),
        ),
        if (s != null) _bottomBar(s),
      ],
    );
  }

  Widget _loadError() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(LucideIcons.cloudOff, size: 28, color: scheme.outline),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center, style: AppType.label.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _load, child: Text(context.tr("Qayta urinish"))),
        ],
      ),
    );
  }

  /// Sarlavha bloki: toj, nom, qisqa va'da, (bo'lsa) qulflangan imkoniyat sababi.
  Widget _hero(Subscription? s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = AppPalette.textTone(AppPalette.premium, theme.brightness);
    final reason = widget.message;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF2E2408), Color(0xFF17130A)]
              : const [AppPalette.premiumTint, Color(0xFFFFE9A8)],
        ),
        border: Border.all(color: AppPalette.premium.withValues(alpha: dark ? .35 : .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  gradient: _crownGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.crown, size: 26, color: AppPalette.premiumDeep),
              ),
              const Spacer(),
              _closeButton(),
            ],
          ),
          const SizedBox(height: 14),
          Text(context.tr("IntizomAI Premium"), style: AppType.title.copyWith(fontSize: 24)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              context.tr("Cheklovsiz rejalar, AI murabbiy va do'stlar bilan guruhlar — intizomingizni keyingi bosqichga olib chiqing."),
              style: AppType.body.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
            ),
          ),
          if (s?.isPremium == true) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(LucideIcons.badgeCheck, size: 16, color: accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.tr("Premium faol · {v0} kun qoldi", {'v0': s!.daysLeft}),
                    style: AppType.label.copyWith(color: accent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: (dark ? Colors.black : Colors.white).withValues(alpha: dark ? .25 : .7),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.lock, size: 15, color: accent)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(reason, style: AppType.label.copyWith(fontWeight: FontWeight.w500, height: 1.4))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Bepul va Premium solishtirish jadvali.
  Widget _comparison(FreeLimits f) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = AppPalette.textTone(AppPalette.premium, theme.brightness);
    final unlimited = context.tr("Cheksiz");
    final rows = <(IconData, String, String?, String)>[
      (LucideIcons.listChecks, context.tr("Kunlik rejalar"), context.tr("{v0} ta", {'v0': f.plansPerDay}), unlimited),
      (LucideIcons.repeat, context.tr("Odatlar"), context.tr("{v0} ta", {'v0': f.habits}), unlimited),
      (LucideIcons.target, context.tr("Maqsadlar"), context.tr("{v0} ta", {'v0': f.goals}), unlimited),
      (LucideIcons.sparkles, context.tr("AI murabbiy"), context.tr("Kuniga {v0} ta", {'v0': f.aiPerDay}), unlimited),
      (LucideIcons.users, context.tr("Guruhlar"), null, ''),
    ];
    final head = AppType.micro.copyWith(fontWeight: FontWeight.w600, letterSpacing: .3);
    Widget cell(String? text, {required bool premium}) {
      if (text == null) return Icon(LucideIcons.minus, size: 16, color: scheme.outline);
      if (text.isEmpty) return Icon(LucideIcons.check, size: 18, color: accent);
      return Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.label.copyWith(
          color: premium ? accent : scheme.onSurfaceVariant,
          fontWeight: premium ? FontWeight.w600 : FontWeight.w500,
          fontFeatures: tabularFigures,
        ),
      );
    }

    return Container(
      decoration: surfaceDecoration(context, color: scheme.surfaceContainerLow),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(width: 82, child: Text(context.tr("Bepul"), textAlign: TextAlign.center, style: head.copyWith(color: scheme.onSurfaceVariant))),
              SizedBox(width: 82, child: Text(context.tr("Premium"), textAlign: TextAlign.center, style: head.copyWith(color: accent))),
            ],
          ),
          for (final (icon, label, free, prem) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
                  ),
                  SizedBox(width: 82, child: Center(child: cell(free, premium: false))),
                  SizedBox(width: 82, child: Center(child: cell(prem, premium: true))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Oyiga necha so'm (eng qisqa tarifga nisbatan tejash foizini hisoblash uchun).
  static double _perMonth(PricePlan p) => p.days <= 0 ? p.price.toDouble() : p.price * 30 / p.days;

  List<Widget> _planTiles(List<PricePlan> plans) {
    if (plans.isEmpty) return const [];
    final shortest = plans.reduce((a, b) => a.days <= b.days ? a : b);
    final base = _perMonth(shortest);
    int saving(PricePlan p) => base <= 0 || p.key == shortest.key ? 0 : ((1 - _perMonth(p) / base) * 100).round();
    final best = plans.reduce((a, b) => saving(a) >= saving(b) ? a : b);
    return [for (final p in plans) _planTile(p, best.key == p.key && saving(p) >= 5)];
  }

  Widget _planTile(PricePlan p, bool bestValue) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = _plan == p.key;
    final accent = AppPalette.textTone(AppPalette.premium, theme.brightness);
    // Tarif ostida bitta qator: belgi (masalan, "33% tejaysiz") bo'lsa — faqat u;
    // bo'lmasa uzun tarifda oylik narx ("≈ 14 990 so'm / oy"), oylikda — kunlar soni.
    final badge = (p.tag != null && p.tag!.isNotEmpty) ? p.tag! : null;
    final sub = badge ??
        (p.days > 31 && p.monthlyLabel != null
            ? context.tr("≈ {v0} / oy", {'v0': p.monthlyLabel})
            : context.tr("{v0} kun", {'v0': p.days}));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: on,
        button: true,
        child: Material(
          color: on ? AppPalette.premium.withValues(alpha: theme.brightness == Brightness.dark ? .12 : .07) : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () {
              tapFeedback();
              setState(() => _plan = p.key);
            },
            child: AnimatedContainer(
              duration: AppMotion.fast,
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: on ? _premiumFill(theme.brightness) : scheme.outlineVariant, width: on ? 2 : 1),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? _premiumFill(theme.brightness) : Colors.transparent,
                      border: Border.all(color: on ? _premiumFill(theme.brightness) : scheme.outline, width: 1.6),
                    ),
                    child: on ? Icon(LucideIcons.check, size: 14, color: _onPremium(theme.brightness)) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(context.tr(p.title), style: AppType.heading),
                            if (bestValue) Pill(context.tr("Eng foydali"), color: AppPalette.premium),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          sub,
                          style: AppType.caption.copyWith(
                            color: badge == null ? scheme.onSurfaceVariant : accent,
                            fontWeight: badge == null ? FontWeight.w400 : FontWeight.w600,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(p.priceLabel, style: AppType.bodyStrong.copyWith(fontFeatures: tabularFigures)),
                      if (p.originalPriceLabel != null)
                        Text(
                          p.originalPriceLabel!,
                          style: AppType.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _providers(List<PayProvider> providers) {
    return Row(
      children: [
        for (var i = 0; i < providers.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: ChoiceChipBox(
              selected: _provider == providers[i].key,
              onTap: () => setState(() => _provider = providers[i].key),
              child: Text(providers[i].title),
            ),
          ),
        ],
      ],
    );
  }

  /// Promokod: yig'ilgan havola → maydon → qo'llangan holat (olib tashlash bilan).
  Widget _promoBlock(Subscription s) {
    final scheme = Theme.of(context).colorScheme;
    final promo = s.promo;
    if (_appliedPromo != null && promo != null && promo.valid) {
      final parts = [
        if (promo.isFree) context.tr("{v0} kun bepul Premium", {'v0': promo.bonusDays}),
        if (!promo.isFree && promo.discountPercent > 0) context.tr("{v0}% chegirma", {'v0': promo.discountPercent}),
        if (!promo.isFree && promo.bonusDays > 0) context.tr("+{v0} kun bonus", {'v0': promo.bonusDays}),
      ];
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppPalette.success.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.ticketCheck, size: 18, color: AppPalette.success),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_appliedPromo!.toUpperCase(), style: AppType.bodyStrong.copyWith(letterSpacing: .5)),
                  if (parts.isNotEmpty)
                    Text(parts.join(' · '), style: AppType.caption.copyWith(color: AppPalette.success, fontWeight: FontWeight.w600)),
                  if (!promo.isFree && promo.planKeys != null && promo.planKeys!.isNotEmpty)
                    Text(
                      context.tr("Faqat: {v0}", {
                        'v0': [for (final p in s.plans) if (promo.planKeys!.contains(p.key)) context.tr(p.title)].join(', '),
                      }),
                      style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.tr("Olib tashlash"),
              onPressed: _busy ? null : _removePromo,
              icon: Icon(LucideIcons.x, size: 18, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (!_showPromo) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _showPromo = true),
          icon: const Icon(LucideIcons.ticket, size: 16),
          label: Text(context.tr("Promokod bormi?")),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promo,
                autofocus: (widget.initialPromo ?? '').isEmpty,
                textCapitalization: TextCapitalization.characters,
                maxLength: 40,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: context.tr("Promokodni kiriting"),
                  counterText: '',
                  isDense: true,
                  prefixIcon: Icon(LucideIcons.ticket, size: 18, color: scheme.outline),
                ),
                onChanged: (_) {
                  if (_promoError != null) setState(() => _promoError = null);
                },
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) _load(promo: v.trim());
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _promoBusy ? null : () {
                  final v = _promo.text.trim();
                  if (v.isNotEmpty) _load(promo: v);
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: _promoBusy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(context.tr("Qo'llash")),
              ),
            ),
          ],
        ),
        if (_promoError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(_promoError!, style: AppType.caption.copyWith(color: scheme.error)),
          ),
      ],
    );
  }

  /// Pastga yopishgan to'lov tugmasi — ro'yxat qancha uzun bo'lmasin, doim ko'rinadi.
  Widget _bottomBar(Subscription s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _selected;
    final freePromo = s.promo?.valid == true && s.promo!.isFree;
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      backgroundColor: _premiumFill(theme.brightness),
      foregroundColor: _onPremium(theme.brightness),
      textStyle: AppType.bodyStrong.copyWith(fontSize: 16, fontFamily: AppTheme.fontFamily),
    );
    final spinner = SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: _onPremium(theme.brightness)),
    );

    Widget button;
    if (freePromo) {
      button = FilledButton.icon(
        onPressed: _busy ? null : _redeemFree,
        style: style,
        icon: _busy ? spinner : const Icon(LucideIcons.gift, size: 18),
        label: Text(context.tr("{v0} kun Premiumni faollashtirish", {'v0': s.promo!.bonusDays})),
      );
    } else if (!s.paymentsEnabled) {
      button = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          context.tr("To'lov tizimi vaqtincha ishlamayapti. Birozdan keyin urinib ko'ring."),
          textAlign: TextAlign.center,
          style: AppType.label.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    } else {
      button = FilledButton(
        onPressed: _busy || selected == null || _provider == null ? null : _pay,
        style: style,
        child: _busy
            ? spinner
            : Text(
                selected == null
                    ? context.tr("Tarifni tanlang")
                    : context.tr("{v0} uchun to'lash · {v1}", {'v0': context.tr(selected.title), 'v1': selected.priceLabel}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      );
    }

    final provider = s.providers.where((p) => p.key == _provider).firstOrNull?.title ?? 'Paylov';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            button,
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.shieldCheck, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    freePromo
                        ? context.tr("To'lov talab qilinmaydi")
                        : context.tr("{v0} orqali xavfsiz to'lov · Avtomatik yechilmaydi", {'v0': provider}),
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── To'lov kutilmoqda ──────────────────────────────────
  Widget _waitingView() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('waiting'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        const Center(child: SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3))),
        const SizedBox(height: 18),
        Text(context.tr("To'lov kutilmoqda"), textAlign: TextAlign.center, style: AppType.heading),
        const SizedBox(height: 6),
        Text(
          context.tr("To'lov sahifasida to'lovni yakunlang va ilovaga qayting. Premium avtomatik ochiladi."),
          textAlign: TextAlign.center,
          style: AppType.body.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (_order?.amountLabel != null) ...[
          const SizedBox(height: 10),
          Text(_order!.amountLabel!, textAlign: TextAlign.center, style: AppType.bodyStrong.copyWith(fontFeatures: tabularFigures)),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _reopenCheckout,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(LucideIcons.externalLink, size: 18),
          label: Text(context.tr("To'lov sahifasini ochish")),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _checkOrder,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          child: Text(context.tr("To'ladim — tekshirish")),
        ),
        TextButton(
          onPressed: () {
            _poll?.cancel();
            setState(() {
              _stage = _Stage.choose;
              _order = null;
            });
          },
          child: Text(context.tr("Boshqa tarif yoki usul")),
        ),
      ],
    );
  }

  // ── Muvaffaqiyat ───────────────────────────────────────
  Widget _successView() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(gradient: _crownGradient, borderRadius: BorderRadius.circular(22)),
            child: const Icon(LucideIcons.crown, size: 34, color: AppPalette.premiumDeep),
          ),
        ),
        const SizedBox(height: 18),
        Text(context.tr("Premium faollashdi!"), textAlign: TextAlign.center, style: AppType.title),
        const SizedBox(height: 6),
        Text(
          _grantedDays > 0
              ? context.tr("Hisobingizga {v0} kun qo'shildi. Rahmat!", {'v0': _grantedDays})
              : context.tr("Barcha imkoniyatlar ochildi. Rahmat!"),
          textAlign: TextAlign.center,
          style: AppType.body.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: _premiumFill(theme.brightness),
            foregroundColor: _onPremium(theme.brightness),
          ),
          child: Text(context.tr("Davom etish")),
        ),
      ],
    );
  }
}

/// Profil → "Promokodni faollashtirish". Bitta joyda ikkala tur:
///   • bepul (Premium kunlari) — shu yerning o'zida faollashadi;
///   • chegirma — Premium oynasi promokod qo'llangan holda ochiladi.
Future<void> showPromoRedeem(BuildContext context) async {
  final ctrl = TextEditingController();
  final api = IntizomApi();
  String? error;
  String? discountCode;
  await showFormSheet<void>(
    context,
    title: context.tr("Promokodni faollashtirish"),
    subtitle: context.tr("Bepul Premium yoki chegirma promokodi"),
    saveLabel: context.tr("Faollashtirish"),
    builder: (ctx, setSheet) => TextField(
      controller: ctrl,
      autofocus: true,
      maxLength: 40,
      textCapitalization: TextCapitalization.characters,
      onChanged: (_) {
        if (error != null) setSheet(() => error = null);
      },
      decoration: InputDecoration(
        hintText: context.tr("Promokodni kiriting"),
        counterText: '',
        errorText: error,
        prefixIcon: const Icon(LucideIcons.ticket, size: 18),
      ),
    ),
    onSave: () async {
      final code = ctrl.text.trim();
      if (code.isEmpty) return false;
      try {
        final sub = await api.subscription(promoCode: code);
        final promo = sub.promo;
        if (promo == null || !promo.valid) {
          error = context.mounted ? context.tr("Promokod yaroqsiz yoki muddati tugagan") : null;
          return false;
        }
        if (!promo.isFree) {
          // Chegirma promokodi to'lov bilan ishlaydi — Premium oynasini ochamiz.
          discountCode = promo.code;
          return true;
        }
        final days = await api.redeemPromo(code);
        premiumChanged.value++;
        if (context.mounted) toast(context, context.tr("Hisobingizga {v0} kun qo'shildi. Rahmat!", {'v0': days}));
        return true;
      } catch (e) {
        error = e.toString();
        return false;
      }
    },
  );
  final code = discountCode;
  if (code != null && context.mounted) await showPaywall(context, promo: code);
}
