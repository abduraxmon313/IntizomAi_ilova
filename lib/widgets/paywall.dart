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
Future<void> showPaywall(BuildContext context, {String? message}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _PaywallSheet(message: message),
  );
}

enum _Stage { choose, waiting, success }

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet({this.message});
  final String? message;

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> with WidgetsBindingObserver {
  final _api = IntizomApi();
  final _promo = TextEditingController();

  Subscription? _sub;
  String? _error;
  String? _plan;
  String? _provider;
  String? _appliedPromo;
  bool _busy = false;
  bool _showPromo = false;

  _Stage _stage = _Stage.choose;
  PaymentOrder? _order;
  Timer? _poll;
  DateTime? _waitStarted;
  int _grantedDays = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
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
      _busy = true;
      _error = null;
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
      });
      if (promo != null && s.promo != null && !s.promo!.valid && mounted) {
        toast(context, context.tr("Promokod yaroqsiz"));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: context.tr("IntizomAI Premium"),
      child: AnimatedSize(
        duration: AppMotion.base,
        curve: AppMotion.curve,
        alignment: Alignment.topCenter,
        child: switch (_stage) {
          _Stage.success => _successView(),
          _Stage.waiting => _waitingView(),
          _Stage.choose => _chooseView(),
        },
      ),
    );
  }

  Widget _benefit(IconData icon, String title, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 19, color: AppPalette.gold)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.bodyStrong),
                Text(text, style: AppType.label.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chooseView() {
    final scheme = Theme.of(context).colorScheme;
    final s = _sub;
    if (s == null) {
      return _error != null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center, style: AppType.label.copyWith(color: scheme.error)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: Text(context.tr("Qayta urinish"))),
                ],
              ),
            )
          : const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: LoadingView());
    }
    final selected = _selected;
    final freePromo = s.promo?.valid == true && s.promo!.isFree;
    return Column(
      key: const ValueKey('choose'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message != null && widget.message!.isNotEmpty) ...[
          Text(widget.message!, style: AppType.body.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
        ],
        if (s.isPremium)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Pill(context.tr("Premium faol · {v0} kun qoldi", {'v0': s.daysLeft}), color: AppPalette.gold),
          ),
        _benefit(LucideIcons.infinity, context.tr("Cheklovsiz"), context.tr("Reja, odat, maqsad va AI murabbiy — chegarasiz")),
        _benefit(LucideIcons.users, context.tr("Guruhlar"), context.tr("Oila va do'stlar bilan guruh tuzing, bir-biringizni kuzating")),
        _benefit(LucideIcons.trophy, context.tr("Reyting"), context.tr("Umumiy reytingda o'z o'rningizni ko'ring")),
        FieldLabel(context.tr("Tarif")),
        for (final p in s.plans) _planTile(p),
        if (s.providers.isNotEmpty) ...[
          FieldLabel(context.tr("To'lov usuli")),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pr in s.providers)
                ChoiceChip(
                  label: Text(pr.title),
                  selected: _provider == pr.key,
                  onSelected: (_) => setState(() => _provider = pr.key),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (!_showPromo && _appliedPromo == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showPromo = true),
              icon: const Icon(LucideIcons.ticket, size: 16),
              label: Text(context.tr("Promokod bormi?")),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promo,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 40,
                    decoration: InputDecoration(
                      hintText: context.tr("Promokod"),
                      counterText: '',
                      isDense: true,
                      suffixIcon: _appliedPromo == null ? null : Icon(LucideIcons.circleCheck, size: 18, color: AppPalette.success),
                    ),
                    onSubmitted: (v) => _load(promo: v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _load(promo: _promo.text.trim()),
                  child: Text(context.tr("Qo'llash")),
                ),
              ],
            ),
          ),
        if (s.promo?.valid == true && !freePromo && (s.promo!.discountPercent > 0 || s.promo!.bonusDays > 0))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              [
                if (s.promo!.discountPercent > 0) context.tr("{v0}% chegirma", {'v0': s.promo!.discountPercent}),
                if (s.promo!.bonusDays > 0) context.tr("+{v0} kun bonus", {'v0': s.promo!.bonusDays}),
              ].join(' · '),
              style: AppType.label.copyWith(color: AppPalette.success),
            ),
          ),
        const SizedBox(height: 18),
        if (freePromo)
          FilledButton.icon(
            onPressed: _busy ? null : _redeemFree,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(LucideIcons.gift, size: 18),
            label: Text(context.tr("{v0} kun Premiumni faollashtirish", {'v0': s.promo!.bonusDays})),
          )
        else if (!s.paymentsEnabled)
          Text(
            context.tr("To'lov tizimi vaqtincha ishlamayapti. Birozdan keyin urinib ko'ring."),
            textAlign: TextAlign.center,
            style: AppType.label.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          FilledButton(
            onPressed: _busy || selected == null || _provider == null ? null : _pay,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    selected == null
                        ? context.tr("Tarifni tanlang")
                        : context.tr("To'lash · {v0}", {'v0': selected.priceLabel}),
                  ),
          ),
        const SizedBox(height: 10),
        Text(
          context.tr("To'lov Paylov orqali xavfsiz amalga oshiriladi. Obuna avtomatik yangilanmaydi — muddat tugagach o'zingiz uzaytirasiz."),
          textAlign: TextAlign.center,
          style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }

  Widget _planTile(PricePlan p) {
    final scheme = Theme.of(context).colorScheme;
    final on = _plan == p.key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: on,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            tapFeedback();
            setState(() => _plan = p.key);
          },
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: on ? AppPalette.gold : scheme.outlineVariant, width: on ? 2 : 1),
              color: on ? AppPalette.gold.withValues(alpha: .06) : null,
            ),
            child: Row(
              children: [
                Icon(on ? LucideIcons.circleCheck : LucideIcons.circle, size: 20, color: on ? AppPalette.gold : scheme.outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(context.tr(p.title), style: AppType.bodyStrong)),
                          if (p.tag != null && p.tag!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(child: Pill(p.tag!, color: AppPalette.gold)),
                          ],
                        ],
                      ),
                      if (p.monthlyLabel != null && p.days > 31)
                        Text(
                          context.tr("≈ {v0} / oy", {'v0': p.monthlyLabel}),
                          style: AppType.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
                        ),
                    ],
                  ),
                ),
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
    );
  }

  Widget _waitingView() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('waiting'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 18),
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

  Widget _successView() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Center(child: AppIconTile(icon: LucideIcons.crown, tone: AppPalette.gold, size: 56)),
        const SizedBox(height: 16),
        Text(context.tr("Premium faollashdi!"), textAlign: TextAlign.center, style: AppType.title),
        const SizedBox(height: 6),
        Text(
          _grantedDays > 0
              ? context.tr("Hisobingizga {v0} kun qo'shildi. Rahmat!", {'v0': _grantedDays})
              : context.tr("Barcha imkoniyatlar ochildi. Rahmat!"),
          textAlign: TextAlign.center,
          style: AppType.body.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: Text(context.tr("Davom etish")),
        ),
      ],
    );
  }
}

/// Faqat bepul promokodni faollashtirish (Profil → Promokod).
Future<void> showPromoRedeem(BuildContext context) async {
  final ctrl = TextEditingController();
  final api = IntizomApi();
  await showFormSheet<void>(
    context,
    title: context.tr("Promokodni faollashtirish"),
    saveLabel: context.tr("Faollashtirish"),
    builder: (ctx, _) => TextField(
      controller: ctrl,
      autofocus: true,
      maxLength: 40,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(hintText: context.tr("Promokod"), counterText: ''),
    ),
    onSave: () async {
      final code = ctrl.text.trim();
      if (code.isEmpty) return false;
      try {
        final days = await api.redeemPromo(code);
        premiumChanged.value++;
        if (context.mounted) toast(context, context.tr("Hisobingizga {v0} kun qo'shildi. Rahmat!", {'v0': days}));
        return true;
      } catch (e) {
        if (context.mounted) toast(context, e.toString());
        return false;
      }
    },
  );
}
