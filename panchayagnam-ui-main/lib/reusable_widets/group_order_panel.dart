// ignore_for_file: library_private_types_in_public_api
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/group_order_buy_sell_bloc/group_order_buy_sell_bloc.dart';
import '../../../bloc/group_order_buy_sell_bloc/group_order_buy_sell_event.dart';
import '../../../bloc/individual_bloc/individual_execution_bloc.dart';
import '../../../models/ScripInfo.dart';
import '../../../service/group_order_buy_sell_service.dart';

const _bg = Color(0xFFF0F2F5);
const _surface = Color(0xFFFFFFFF);
const _surfaceElevated = Color(0xFFF8F9FB);
const _border = Color(0xFFE4E9F0);
const _borderDark = Color(0xFFCDD5DF);
const _primary = Color(0xFF1A56DB);
const _primaryDark = Color(0xFF1344B8);
const _primaryLight = Color(0xFFEEF2FF);
const _primaryBorder = Color(0xFFC7D7FE);
const _textDark = Color(0xFF0F172A);
const _textMid = Color(0xFF334155);
const _textLight = Color(0xFF64748B);
const _textXLight = Color(0xFF94A3B8);
const _green = Color(0xFF047857);
const _greenMid = Color(0xFF059669);
const _greenLight = Color(0xFFECFDF5);
const _greenBorder = Color(0xFFA7F3D0);
const _greenDark = Color(0xFF065F46);
const _red = Color(0xFFDC2626);
const _redLight = Color(0xFFFEF2F2);
const _redBorder = Color(0xFFFECACA);
const _redDark = Color(0xFFB91C1C);
const _amber = Color(0xFFB45309);
const _amberLight = Color(0xFFFFFBEB);
const _amberBorder = Color(0xFFFDE68A);
const _amberText = Color(0xFF78350F);
const _purple = Color(0xFF6D28D9);
const _purpleLight = Color(0xFFF5F3FF);
const _purpleBorder = Color(0xFFDDD6FE);

// ── Exchange brand colours (matching StockSearchWidget) ───────────────────
const _kNseFg = Color(0xFF6366F1);
const _kNseBg = Color(0xFFEEEDFF);
const _kBseFg = Color(0xFF059669);
const _kBseBg = Color(0xFFDBEAFE);
const _kNfoFg = Color(0xFFC2410C);
const _kNfoBg = Color(0xFFFFF7ED);
const _kNfoBd = Color(0xFFFED7AA);

// ── Exchange cycle ────────────────────────────────────────────────────────
const _kExchanges = ['NSE', 'BSE', 'NFO'];

// ── Instrument type badge colours ─────────────────────────────────────────
const _kEqFg = Color(0xFF166534);
const _kEqBg = Color(0xFFDCFCE7);
const _kEqBd = Color(0xFFBBF7D0);
const _kFutFg = Color(0xFF047857);
const _kFutBg = Color(0xFFDBEAFE);
const _kFutBd = Color(0xFFBFDBFE);
const _kOptFg = Color(0xFF92400E);
const _kOptBg = Color(0xFFFEF3C7);
const _kOptBd = Color(0xFFFDE68A);
const _kOtherFg = Color(0xFF4B5563);
const _kOtherBg = Color(0xFFF3F4F6);
const _kOtherBd = Color(0xFFE5E7EB);

// ── Accent (matches StockSearchWidget _kAccent) ───────────────────────────
const _kAccent = Color(0xFF6366F1);
const _kAccentSoft = Color(0xFFEEEDFF);

List<BoxShadow> get _cardShadow => [
  BoxShadow(
    color: const Color(0xFF0F172A).withOpacity(0.04),
    blurRadius: 6,
    offset: const Offset(0, 1),
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
// MARGIN MULTIPLIERS
// ═══════════════════════════════════════════════════════════════════════════

double marginMultiplierFor(ProductType product) {
  switch (product) {
    case ProductType.intraday:
      return 5.0;
    case ProductType.payLater:
      return 3.8;
    case ProductType.delivery:
      return 1.0;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHARGES CALCULATOR
// ═══════════════════════════════════════════════════════════════════════════

class TradeCharges {
  final double brokerage, stt, exchangeTxnCharges, gst, sebiCharges, stampDuty;
  const TradeCharges({
    this.brokerage = 0,
    this.stt = 0,
    this.exchangeTxnCharges = 0,
    this.gst = 0,
    this.sebiCharges = 0,
    this.stampDuty = 0,
  });

  double get total =>
      brokerage + stt + exchangeTxnCharges + gst + sebiCharges + stampDuty;

  TradeCharges operator +(TradeCharges o) => TradeCharges(
    brokerage: brokerage + o.brokerage,
    stt: stt + o.stt,
    exchangeTxnCharges: exchangeTxnCharges + o.exchangeTxnCharges,
    gst: gst + o.gst,
    sebiCharges: sebiCharges + o.sebiCharges,
    stampDuty: stampDuty + o.stampDuty,
  );

  static TradeCharges calculate({
    required double tradeValue,
    required String productType,
    required String orderSide,
    required String exchange,
  }) {
    if (tradeValue <= 0) return const TradeCharges();
    final bool isDelivery = productType == 'DELIVERY';
    final double brokerage =
    isDelivery ? 0.0 : (tradeValue * 0.0025).clamp(0, 20.0);
    final double stt = isDelivery
        ? tradeValue * 0.001
        : (orderSide == 'SELL' ? tradeValue * 0.00025 : 0.0);
    final double txnRate = exchange == 'BSE' ? 0.0000375 : 0.0000325;
    final double exchangeTxn = tradeValue * txnRate;
    final double sebi = tradeValue * 0.0000001;
    final double gst = (brokerage + exchangeTxn) * 0.18;
    final double stampDuty = orderSide == 'BUY'
        ? tradeValue * (isDelivery ? 0.00015 : 0.00003)
        : 0.0;
    return TradeCharges(
      brokerage: _r(brokerage),
      stt: _r(stt),
      exchangeTxnCharges: _r(exchangeTxn),
      gst: _r(gst),
      sebiCharges: _r(sebi),
      stampDuty: _r(stampDuty),
    );
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}

class GroupMember {
  final int id;
  final String initials, name, clientId, brokerType;
  final double cashBalance;
  final bool linked;
  final bool memberActive;

  const GroupMember({
    required this.id,
    required this.initials,
    required this.name,
    required this.clientId,
    required this.brokerType,
    required this.cashBalance,
    this.linked = false,
    this.memberActive = true,
  });

  bool get isDeactivated => !memberActive;
  bool get shouldExecute => memberActive;

  double effectiveBuyingPowerFor(ProductType product) {
    if (cashBalance <= 0) return 0;
    switch (product) {
      case ProductType.delivery:
        return cashBalance;
      case ProductType.intraday:
        return cashBalance * 5.0;
      case ProductType.payLater:
        return cashBalance * 3.8;
    }
  }
}

class StockOrderItem {
  final String id;
  final ScripInfo scrip;
  final TextEditingController qtyCtrl;
  final TextEditingController slPriceCtrl;
  final TextEditingController triggerPriceCtrl;
  final TextEditingController targetPriceCtrl;
  final TextEditingController trailJumpCtrl;
  double ltp, ltpChange;
  bool ltpLoading;
  String? ltpError;

  StockOrderItem({
    required this.id,
    required this.scrip,
    this.ltp = 0.0,
    this.ltpChange = 0.0,
    this.ltpLoading = true,
    this.ltpError,
  })  : qtyCtrl = TextEditingController(text: '1'),
        slPriceCtrl = TextEditingController(),
        triggerPriceCtrl = TextEditingController(),
        targetPriceCtrl = TextEditingController(),
        trailJumpCtrl = TextEditingController();

  void dispose() {
    qtyCtrl.dispose();
    slPriceCtrl.dispose();
    triggerPriceCtrl.dispose();
    targetPriceCtrl.dispose();
    trailJumpCtrl.dispose();
  }

  int get qty => int.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get slPrice => double.tryParse(slPriceCtrl.text.trim()) ?? 0;
  double get triggerPrice =>
      double.tryParse(triggerPriceCtrl.text.trim()) ?? 0;
  double get targetPrice => double.tryParse(targetPriceCtrl.text.trim()) ?? 0;
  double get trailJump => double.tryParse(trailJumpCtrl.text.trim()) ?? 0;

  void autoFillFromLtp(SpecialOrder special) {
    if (ltp <= 0) return;
    if (special == SpecialOrder.stopLoss) {
      if (slPriceCtrl.text.isEmpty)
        slPriceCtrl.text = (ltp * 0.95).toStringAsFixed(2);
      if (triggerPriceCtrl.text.isEmpty)
        triggerPriceCtrl.text = (ltp * 0.96).toStringAsFixed(2);
    } else if (special == SpecialOrder.robo) {
      if (slPriceCtrl.text.isEmpty)
        slPriceCtrl.text = (ltp * 0.975).toStringAsFixed(2);
      if (targetPriceCtrl.text.isEmpty)
        targetPriceCtrl.text = (ltp * 1.05).toStringAsFixed(2);
      if (trailJumpCtrl.text.isEmpty)
        trailJumpCtrl.text = (ltp * 0.005).toStringAsFixed(2);
    } else if (special == SpecialOrder.gtt) {
      if (triggerPriceCtrl.text.isEmpty)
        triggerPriceCtrl.text = ltp.toStringAsFixed(2);
    }
  }

  int affordableQty(double buyingPower) {
    if (ltp <= 0) return 0;
    return (buyingPower / ltp).floor().clamp(0, 999999);
  }

  int effectiveQty(double buyingPower) {
    if (ltp <= 0 || qty <= 0) return 0;
    return qty.clamp(0, affordableQty(buyingPower));
  }

  double valueForBuyingPower(double buyingPower) =>
      effectiveQty(buyingPower) * ltp;
}

class StockAllocation {
  final StockOrderItem item;
  final int requestedQty, effectiveQty, maxAffordableQty;
  final double allocatedValue;
  final TradeCharges charges;
  const StockAllocation({
    required this.item,
    required this.requestedQty,
    required this.effectiveQty,
    required this.maxAffordableQty,
    required this.allocatedValue,
    required this.charges,
  });
  bool get isReduced => effectiveQty > 0 && effectiveQty < requestedQty;
  bool get isSkipped => effectiveQty == 0;
  bool get isOk => effectiveQty == requestedQty && effectiveQty > 0;
}

class MemberOrderSummary {
  final GroupMember member;
  final List<StockAllocation> allocations;
  final ProductType product;
  const MemberOrderSummary({
    required this.member,
    required this.allocations,
    required this.product,
  });
  bool get hasReduced => allocations.any((a) => a.isReduced);
  bool get hasSkipped => allocations.any((a) => a.isSkipped);
  bool get allOk => allocations.every((a) => a.isOk);
  bool get hasAnyOrder => allocations.any((a) => a.effectiveQty > 0);
  double get totalTradeValue =>
      allocations.fold(0.0, (s, a) => s + a.allocatedValue);
  TradeCharges get totalCharges =>
      allocations.fold(const TradeCharges(), (s, a) => s + a.charges);
  double get totalWithCharges => totalTradeValue + totalCharges.total;
  double get effectiveBuyingPower => member.effectiveBuyingPowerFor(product);
}

// ═══════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════

enum OrderSide { buy, sell }

enum ProductType { delivery, intraday, payLater }

enum BaseOrderType { limit, market }

enum SpecialOrder { none, stopLoss, robo, gtt }

// ═══════════════════════════════════════════════════════════════════════════
// GROUP ORDER PANEL
// ═══════════════════════════════════════════════════════════════════════════

class GroupOrderPanel extends StatefulWidget {
  final Map<String, dynamic> group;
  final List<GroupMember> members;
  final String initialSide;

  const GroupOrderPanel({
    super.key,
    required this.group,
    required this.members,
    this.initialSide = 'BUY',
  });

  @override
  State<GroupOrderPanel> createState() => _GroupOrderPanelState();
}

class _GroupOrderPanelState extends State<GroupOrderPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _bsTab;

  final List<StockOrderItem> _basket = [];
  final Map<String, String> _pendingFetch = {};

  late OrderSide _side;
  ProductType _product = ProductType.delivery;
  BaseOrderType _orderType = BaseOrderType.limit;
  SpecialOrder _special = SpecialOrder.none;
  bool _membersExpanded = false;
  bool _breakdownExpanded = false;

  List<GroupMember> get _executableMembers =>
      widget.members.where((m) => m.shouldExecute).toList();

  List<GroupMember> get _allMembers => widget.members;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide.toUpperCase() == 'SELL'
        ? OrderSide.sell
        : OrderSide.buy;

    final initialIndex = _side == OrderSide.sell ? 1 : 0;
    _bsTab = TabController(length: 2, vsync: this, initialIndex: initialIndex);

    _bsTab.addListener(() {
      if (!_bsTab.indexIsChanging) {
        setState(
              () => _side = _bsTab.index == 0 ? OrderSide.buy : OrderSide.sell,
        );
      }
    });
  }

  @override
  void dispose() {
    _bsTab.dispose();
    for (final b in _basket) b.dispose();
    super.dispose();
  }

  // ── basket helpers ────────────────────────────────────────────────────────

  void _addScrip(ScripInfo s) {
    final dup = _basket.any(
          (b) =>
      b.scrip.tradingSymbol == s.tradingSymbol &&
          b.scrip.exchange == s.exchange,
    );
    if (dup) {
      _toast('${s.tradingSymbol} already in basket');
      return;
    }
    final id =
        '${s.exchange}_${s.tradingSymbol}_${DateTime.now().millisecondsSinceEpoch}';
    final item = StockOrderItem(id: id, scrip: s, ltpLoading: true);
    item.qtyCtrl.addListener(() => setState(() {}));
    setState(() => _basket.add(item));
    _pendingFetch[s.symbolToken] = id;
    context.read<IndividualExecutionBloc>().add(
      LtpRequested(
        ScripInfo(
          tradingSymbol: s.tradingSymbol,
          exchange: s.exchange,
          symbolToken: s.symbolToken,
        ),
      ),
    );
  }

  void _removeStock(String id) => setState(() {
    final idx = _basket.indexWhere((b) => b.id == id);
    if (idx != -1) {
      _pendingFetch.removeWhere((_, v) => v == id);
      _basket[idx].dispose();
      _basket.removeAt(idx);
    }
  });

  void _stepQty(StockOrderItem item, int delta) {
    item.qtyCtrl.text = '${(item.qty + delta).clamp(1, 999999)}';
    setState(() {});
  }

  void _onSpecialChanged(SpecialOrder newSpecial) {
    setState(() {
      _special = newSpecial;
      for (final item in _basket) {
        if (!item.ltpLoading && item.ltp > 0) {
          item.autoFillFromLtp(newSpecial);
        }
      }
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _textDark,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── computed ──────────────────────────────────────────────────────────────

  List<MemberOrderSummary> get _summaries {
    final side = _side == OrderSide.buy ? 'BUY' : 'SELL';
    final prod = _productLabel;

    return _executableMembers.map((m) {
      double remaining = m.effectiveBuyingPowerFor(_product);
      final allocs = <StockAllocation>[];

      for (final item in _basket) {
        if (item.ltp <= 0) {
          allocs.add(
            StockAllocation(
              item: item,
              requestedQty: item.qty,
              effectiveQty: 0,
              maxAffordableQty: 0,
              allocatedValue: 0,
              charges: const TradeCharges(),
            ),
          );
          continue;
        }

        final maxAfford = (remaining / item.ltp).floor().clamp(0, 999999);
        final eff = item.qty <= 0 ? 0 : item.qty.clamp(0, maxAfford);
        final val = eff * item.ltp;

        final charges = TradeCharges.calculate(
          tradeValue: val,
          productType: prod,
          orderSide: side,
          exchange: item.scrip.exchange,
        );

        allocs.add(
          StockAllocation(
            item: item,
            requestedQty: item.qty,
            effectiveQty: eff,
            maxAffordableQty: maxAfford,
            allocatedValue: val,
            charges: charges,
          ),
        );

        remaining -= (val + charges.total);
        if (remaining < 0) remaining = 0;
      }

      return MemberOrderSummary(
        member: m,
        allocations: allocs,
        product: _product,
      );
    }).toList();
  }

  String get _productLabel => switch (_product) {
    ProductType.delivery => 'DELIVERY',
    ProductType.intraday => 'INTRADAY',
    ProductType.payLater => 'PAY_LATER',
  };

  double get _perAccountRaw =>
      _basket.fold(0.0, (s, b) => s + b.qty * b.ltp);

  double get _totalGroupValue =>
      _summaries.fold(0.0, (s, ms) => s + ms.totalTradeValue);

  double get _totalGroupCharges =>
      _summaries.fold(0.0, (s, ms) => s + ms.totalCharges.total);

  int get _activeAccounts => _summaries.where((s) => s.hasAnyOrder).length;

  bool get _basketReady =>
      _basket.isNotEmpty &&
          _basket.every((b) => !b.ltpLoading && b.ltp > 0);

  // ── build request ─────────────────────────────────────────────────────────

  PlaceGroupOrderRequest _buildRequest(List<MemberOrderSummary> summaries) {
    final groupId = widget.group['groupId'] as int? ?? 0;
    final side = _side == OrderSide.buy ? 'BUY' : 'SELL';

    String orderType;
    if (_special == SpecialOrder.stopLoss) {
      orderType = _orderType == BaseOrderType.market
          ? 'STOPLOSS_MARKET'
          : 'STOPLOSS_LIMIT';
    } else {
      orderType = _orderType == BaseOrderType.limit ? 'LIMIT' : 'MARKET';
    }

    final variety = switch (_special) {
      SpecialOrder.robo => 'ROBO',
      SpecialOrder.stopLoss => 'STOPLOSS',
      SpecialOrder.gtt => 'GTT',
      SpecialOrder.none => 'NORMAL',
    };

    final stocks = _basket.map((item) {
      final brokerQtys = <BrokerQuantity>[];
      for (final s in summaries) {
        final alloc = s.allocations.firstWhere(
              (a) => a.item.id == item.id,
          orElse: () => StockAllocation(
            item: item,
            requestedQty: 0,
            effectiveQty: 0,
            maxAffordableQty: 0,
            allocatedValue: 0,
            charges: const TradeCharges(),
          ),
        );
        if (alloc.effectiveQty > 0) {
          brokerQtys.add(
            BrokerQuantity(
              brokerId: s.member.id,
              quantity: alloc.effectiveQty,
            ),
          );
        }
      }
      return GroupOrderStockRequest(
        tradingSymbol: item.scrip.tradingSymbol,
        symbolToken: item.scrip.symbolToken,
        exchange: item.scrip.exchange,
        price: _orderType == BaseOrderType.limit ? item.ltp : 0.0,
        brokerQuantities: brokerQtys,
      );
    }).toList();

    return PlaceGroupOrderRequest(
      groupId: groupId,
      transactionType: side,
      orderType: orderType,
      productType: _productLabel == 'PAY_LATER' ? 'MARGIN' : _productLabel,
      variety: variety,
      stocks: stocks.where((s) => s.brokerQuantities.isNotEmpty).toList(),
    );
  }

  void _placeOrder() {
    if (!_basketReady ||
        _executableMembers.isEmpty ||
        _activeAccounts == 0) return;
    final summaries = _summaries;
    final req = _buildRequest(summaries);
    if (req.stocks.isEmpty) {
      _toast('No valid orders — check account balances');
      return;
    }
    context.read<GroupOrderBloc>().add(
      PlaceGroupBasketOrderRequested(request: req),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return MultiBlocListener(
      listeners: [
        BlocListener<IndividualExecutionBloc, IndividualExecutionState>(
          listener: (_, state) {
            if (state is LtpSuccess) {
              final basketId = _pendingFetch[state.scrip.symbolToken];
              if (basketId == null) return;
              final idx = _basket.indexWhere((b) => b.id == basketId);
              if (idx == -1) return;
              setState(() {
                _basket[idx].ltp = state.ltpData.ltp;
                _basket[idx].ltpChange = state.ltpData.change;
                _basket[idx].ltpLoading = false;
                _basket[idx].ltpError = null;
                _pendingFetch.remove(state.scrip.symbolToken);
                _basket[idx].autoFillFromLtp(_special);
              });
            } else if (state is LtpFailure) {
              final basketId = _pendingFetch[state.scrip.symbolToken];
              if (basketId == null) return;
              final idx = _basket.indexWhere((b) => b.id == basketId);
              if (idx == -1) return;
              setState(() {
                _basket[idx].ltpLoading = false;
                _basket[idx].ltpError = state.message;
                _pendingFetch.remove(state.scrip.symbolToken);
              });
            }
          },
        ),
        BlocListener<GroupOrderBloc, GroupOrderState>(
          listener: (ctx, state) {
            if (state is GroupOrderSuccess) {
              Navigator.pop(ctx);
              showGroupOrderResultSheet(ctx, state.response);
              ctx.read<GroupOrderBloc>().add(const GroupOrderReset());
            } else if (state is GroupOrderFailure) {
              _toast('Order failed: ${state.message}');
            }
          },
        ),
      ],
      child: WillPopScope(
        onWillPop: () async => false,
        child: Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    bottomInset > 0 ? bottomInset + 12 : safeBottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      _groupInfoCard(),
                      const SizedBox(height: 8),
                      _searchCard(),
                      if (_basket.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _basketCard(),
                        const SizedBox(height: 8),
                        _orderSettingsCard(),
                        if (_special != SpecialOrder.none) ...[
                          const SizedBox(height: 8),
                          _specialOrderFieldsCard(),
                        ],
                        const SizedBox(height: 8),
                        _validityCard(),
                        const SizedBox(height: 8),
                        _summaryCard(),
                      ] else ...[
                        const SizedBox(height: 8),
                        _emptyHint(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isBuy = _side == OrderSide.buy;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBuy
              ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
              : [const Color(0xFF7F1D1D), const Color(0xFF991B1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                top: 8, left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.group['groupName'] ?? 'Trade Group',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.15)),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _HeaderTabItem(
                    label: 'BUY',
                    index: 0,
                    controller: _bsTab,
                    activeColor: Colors.white,
                    activeBg: _green,
                    activeShadow: _green.withOpacity(0.4),
                  ),
                  _HeaderTabItem(
                    label: 'SELL',
                    index: 1,
                    controller: _bsTab,
                    activeColor: Colors.white,
                    activeBg: _red,
                    activeShadow: _red.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
          _productTabs(),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _productTabs() {
    const tabs = [
      (ProductType.delivery, 'Delivery', null),
      (ProductType.intraday, 'Intraday', '5×'),
      (ProductType.payLater, 'Pay Later', '3.8×'),
    ];
    return Row(
      children: tabs.map((t) {
        final active = _product == t.$1;
        return Expanded(
          child: InkWell(
            onTap: () => setState(() {
              _product = t.$1;
              if (t.$1 == ProductType.intraday &&
                  _special == SpecialOrder.gtt) {
                _special = SpecialOrder.none;
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.45),
                    ),
                  ),
                  if (t.$3 != null) ...[
                    const SizedBox(height: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        t.$3!,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : Colors.white.withOpacity(0.35),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Group info card ───────────────────────────────────────────────────────

  Widget _groupInfoCard() {
    final name = widget.group['groupName'] ?? 'Group';
    final totalCash =
    _executableMembers.fold(0.0, (s, m) => s + m.cashBalance);
    final totalEffective = _executableMembers.fold(
      0.0,
          (s, m) => s + m.effectiveBuyingPowerFor(_product),
    );

    final totalCount = _allMembers.length;
    final activeCount = _executableMembers.length;
    final deactivatedCount = totalCount - activeCount;

    return _Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            child: Row(
              children: [
                _Avatar(
                    label: name[0],
                    color: _primary,
                    bg: _primaryLight,
                    size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(
                            '$activeCount active account${activeCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 11, color: _textLight),
                          ),
                          if (deactivatedCount > 0) ...[
                            const Text(' · ',
                                style: TextStyle(
                                    fontSize: 11, color: _textXLight)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFFFCD34D)),
                              ),
                              child: Text(
                                '$deactivatedCount deactivated',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _amber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _ExpandButton(
                  expanded: _membersExpanded,
                  label: _membersExpanded ? 'Hide' : 'Members',
                  onTap: () => setState(
                          () => _membersExpanded = !_membersExpanded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 11),
            child: Column(
              children: [
                _BalChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Total Cash (active accounts)',
                  value: '₹${_fmt(totalCash)}',
                  color: _green,
                  bg: _greenLight,
                ),
                if (_product != ProductType.delivery) ...[
                  const SizedBox(height: 6),
                  _BalChip(
                    icon: Icons.bolt_rounded,
                    label: _product == ProductType.intraday
                        ? 'Intraday Buying Power (5×)'
                        : 'Pay Later Buying Power (3.8×)',
                    value: '₹${_fmt(totalEffective)}',
                    color: _purple,
                    bg: _purpleLight,
                  ),
                ],
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            child: _membersExpanded
                ? Column(
              children: [
                const _Div(),
                if (deactivatedCount > 0)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _amberLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _amberBorder),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 12, color: _amber),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Deactivated accounts are visible but will be skipped during order execution.',
                            style: TextStyle(
                              fontSize: 10,
                              color: _amberText,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    children: [
                      ..._executableMembers.map(
                            (m) => _MemberTile(
                            member: m, product: _product),
                      ),
                      ..._allMembers
                          .where((m) => m.isDeactivated)
                          .map(
                            (m) => _MemberTile(
                            member: m, product: _product),
                      ),
                    ],
                  ),
                ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Search card ───────────────────────────────────────────────────────────

  Widget _searchCard() => _Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.add_chart_rounded,
                    size: 13, color: _primary),
              ),
              const SizedBox(width: 8),
              const Text(
                'Add Stocks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const Spacer(),
              if (_basket.isNotEmpty)
                _Pill(
                  '${_basket.length} stock${_basket.length == 1 ? '' : 's'}',
                  _primary,
                  _primaryLight,
                  _primaryBorder,
                ),
            ],
          ),
          const SizedBox(height: 10),
          // ── UPGRADED: uses the new _EmbeddedStockSearch ──
          _EmbeddedStockSearch(onScripSelected: _addScrip),
        ],
      ),
    ),
  );

  // ── Basket card ───────────────────────────────────────────────────────────

  Widget _basketCard() => _Card(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
          child: Row(
            children: [
              const Text(
                'Basket',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _textDark),
              ),
              const SizedBox(width: 6),
              _Pill(
                _side == OrderSide.buy ? 'BUY' : 'SELL',
                _side == OrderSide.buy ? _green : _red,
                _side == OrderSide.buy ? _greenLight : _redLight,
                _side == OrderSide.buy ? _greenBorder : _redBorder,
              ),
              const Spacer(),
              const Text(
                'Qty / Acc',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: _textXLight),
              ),
            ],
          ),
        ),
        const _Div(),
        ...List.generate(_basket.length, (i) {
          final item = _basket[i];
          return Column(
            children: [
              _BasketRow(
                item: item,
                side: _side,
                onRemove: () => _removeStock(item.id),
                onDec: () => _stepQty(item, -1),
                onInc: () => _stepQty(item, 1),
              ),
              if (i < _basket.length - 1) const _Div(),
            ],
          );
        }),
        const _Div(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TotalCol(
                  label: 'Est. per account',
                  value: '₹${_fmt(_perAccountRaw)}',
                  color: _textDark),
              _TotalCol(
                label: 'Total group value',
                value: '₹${_fmt(_totalGroupValue)}',
                color: _primary,
                alignEnd: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Order Settings ────────────────────────────────────────────────────────

  Widget _orderSettingsCard() => _Card(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            children: [
              const Text(
                'Order Type',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _textDark),
              ),
              const Spacer(),
              _SegmentedPill(
                options: const ['LIMIT', 'MARKET'],
                selected:
                _orderType == BaseOrderType.limit ? 0 : 1,
                onTap: (i) => setState(
                      () => _orderType = i == 0
                      ? BaseOrderType.limit
                      : BaseOrderType.market,
                ),
              ),
            ],
          ),
        ),
        const _Div(),
        _SpecialToggleRow(
          icon: Icons.shield_outlined,
          label: 'Stop Loss',
          subtitle: 'Manual SL & trigger price per stock',
          color: _red,
          active: _special == SpecialOrder.stopLoss,
          onChanged: (v) => _onSpecialChanged(
              v ? SpecialOrder.stopLoss : SpecialOrder.none),
        ),
        const _Div(),
        _SpecialToggleRow(
          icon: Icons.smart_toy_outlined,
          label: 'Robo Order',
          subtitle: 'Auto-exit at SL / Target per stock',
          color: _purple,
          active: _special == SpecialOrder.robo,
          onChanged: (v) => _onSpecialChanged(
              v ? SpecialOrder.robo : SpecialOrder.none),
        ),
        if (_product != ProductType.intraday) ...[
          const _Div(),
          _SpecialToggleRow(
            icon: Icons.schedule_rounded,
            label: 'GTT Order',
            subtitle: 'Trigger price per stock',
            color: _amber,
            active: _special == SpecialOrder.gtt,
            onChanged: (v) => _onSpecialChanged(
                v ? SpecialOrder.gtt : SpecialOrder.none),
          ),
        ],
      ],
    ),
  );

  // ── Special Order Fields ──────────────────────────────────────────────────

  Widget _specialOrderFieldsCard() {
    final Color accentColor = _special == SpecialOrder.stopLoss
        ? _red
        : _special == SpecialOrder.robo
        ? _purple
        : _amber;
    final Color accentLight = _special == SpecialOrder.stopLoss
        ? _redLight
        : _special == SpecialOrder.robo
        ? _purpleLight
        : _amberLight;
    final Color accentBorder = _special == SpecialOrder.stopLoss
        ? _redBorder
        : _special == SpecialOrder.robo
        ? _purpleBorder
        : _amberBorder;
    final IconData accentIcon = _special == SpecialOrder.stopLoss
        ? Icons.shield_outlined
        : _special == SpecialOrder.robo
        ? Icons.smart_toy_outlined
        : Icons.schedule_rounded;
    final String title = _special == SpecialOrder.stopLoss
        ? 'Stop Loss Settings'
        : _special == SpecialOrder.robo
        ? 'Robo Order Settings'
        : 'GTT Settings';
    final String subtitle = _special == SpecialOrder.stopLoss
        ? 'Set stop loss & trigger price for each stock.'
        : _special == SpecialOrder.robo
        ? 'Set SL, target & trailing jump per stock.'
        : 'Set GTT trigger price for each stock.';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(accentIcon, size: 11, color: accentColor),
                      const SizedBox(width: 5),
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accentColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 4),
            child: Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 10, color: _textLight, height: 1.4),
            ),
          ),
          const SizedBox(height: 2),
          ..._basket.asMap().entries.map((e) {
            return Column(
              children: [
                if (e.key > 0) const _Div(),
                _StockSpecialFields(
                  item: e.value,
                  special: _special,
                  onChanged: () => setState(() {}),
                ),
              ],
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Validity card ─────────────────────────────────────────────────────────

  Widget _validityCard() => _Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Row(
        children: [
          Expanded(
              child: _LabeledDropdown(label: 'Validity', value: 'Day')),
          const SizedBox(width: 12),
          Expanded(
              child:
              _LabeledDropdown(label: 'Disclosed Qty', value: '0')),
        ],
      ),
    ),
  );

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _summaryCard() {
    return BlocBuilder<GroupOrderBloc, GroupOrderState>(
      builder: (context, orderState) {
        final isLoading = orderState is GroupOrderLoading;
        final summaries = _summaries;
        final activeCount = _activeAccounts;
        final hasIssues =
        summaries.any((s) => s.hasReduced || s.hasSkipped);
        final totalCharges = _totalGroupCharges;
        final totalCash =
        _executableMembers.fold(0.0, (s, m) => s + m.cashBalance);
        final isBuy = _side == OrderSide.buy;
        final totalEffectiveBP = _executableMembers.fold(
          0.0,
              (s, m) => s + m.effectiveBuyingPowerFor(_product),
        );

        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
                decoration: BoxDecoration(
                  color: _surfaceElevated,
                  border: Border(bottom: BorderSide(color: _border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ValTile(
                        label: 'Est. per account',
                        value: '₹${_fmt(_perAccountRaw)}',
                        sub: '+ est. charges',
                        color: _textDark,
                      ),
                    ),
                    Container(width: 1, height: 38, color: _border),
                    Expanded(
                      child: _ValTile(
                        label: 'Total group value',
                        value: '₹${_fmt(_totalGroupValue)}',
                        sub: '+ ₹${_fmt(totalCharges)} charges',
                        color: _primary,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoChip(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total group cash (active)',
                      value: '₹${_fmt(totalCash)}',
                      color: _green,
                      bg: _greenLight,
                      border: _greenBorder,
                    ),
                    if (_product != ProductType.delivery) ...[
                      const SizedBox(height: 6),
                      _InfoChip(
                        icon: Icons.bolt_rounded,
                        label: _product == ProductType.intraday
                            ? 'Intraday BP (5×)'
                            : 'Pay Later BP (3.8×)',
                        value: '₹${_fmt(totalEffectiveBP)}',
                        color: _purple,
                        bg: _purpleLight,
                        border: _purpleBorder,
                      ),
                    ],
                    if (totalCharges > 0) ...[
                      const SizedBox(height: 10),
                      _chargesBreakdown(summaries),
                    ],
                    if (hasIssues) ...[
                      const SizedBox(height: 10),
                      _issueBanner(summaries),
                    ],
                    const SizedBox(height: 12),

                    // ── Expandable per-account breakdown header ──
                    InkWell(
                      onTap: () => setState(() =>
                      _breakdownExpanded = !_breakdownExpanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Text(
                              'Per-account breakdown',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _textMid,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const Spacer(),
                            _Pill(
                              '$activeCount of ${_executableMembers.length} active',
                              _primary,
                              _primaryLight,
                              _primaryBorder,
                            ),
                            const SizedBox(width: 6),
                            AnimatedRotation(
                              turns: _breakdownExpanded ? 0.5 : 0,
                              duration:
                              const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: _textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeInOut,
                      child: _breakdownExpanded
                          ? Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: _bg,
                              borderRadius:
                              BorderRadius.circular(10),
                              border: Border.all(color: _border),
                            ),
                            child: Column(
                              children: [
                                ...summaries
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => Column(
                                    children: [
                                      _MemberSummaryRow(
                                          summary: e.value),
                                      if (e.key <
                                          summaries.length - 1)
                                        const _Div(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 12),
                    _PlaceOrderButton(
                      isBuy: isBuy,
                      isLoading: isLoading ||
                          _basket.any((b) => b.ltpLoading),
                      isEnabled: activeCount > 0 &&
                          _basketReady &&
                          !isLoading,
                      stockCount: _basket.length,
                      accountCount: activeCount,
                      totalCharges: totalCharges,
                      onPressed: _placeOrder,
                    ),
                    if (!_basketReady &&
                        _basket.isNotEmpty &&
                        !_basket.any((b) => b.ltpLoading))
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_rounded,
                                size: 11, color: _red),
                            SizedBox(width: 4),
                            Text(
                              'Some stocks failed to load LTP. Remove and re-add.',
                              style:
                              TextStyle(fontSize: 10, color: _red),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chargesBreakdown(List<MemberOrderSummary> summaries) {
    final agg = summaries.fold(
      const TradeCharges(),
          (s, ms) => s + ms.totalCharges,
    );
    if (agg.total <= 0) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Charges',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textMid),
                ),
                Text(
                  '₹${_fmt(agg.total)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _textDark),
                ),
              ],
            ),
          ),
          const _Div(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              children: [
                _chargeRow('Brokerage', agg.brokerage),
                _chargeRow('STT', agg.stt),
                _chargeRow('Exchange Txn', agg.exchangeTxnCharges),
                _chargeRow('GST (18%)', agg.gst),
                _chargeRow('SEBI', agg.sebiCharges),
                _chargeRow('Stamp Duty', agg.stampDuty),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chargeRow(String label, double value) {
    if (value <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: _textLight)),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _textMid),
          ),
        ],
      ),
    );
  }

  Widget _issueBanner(List<MemberOrderSummary> summaries) {
    final reduced = summaries
        .where((s) => s.hasReduced && !s.hasSkipped)
        .map((s) => s.member.name.split(' ').first)
        .toList();
    final skipped = summaries
        .where((s) => s.hasSkipped && !s.hasAnyOrder)
        .map((s) => s.member.name.split(' ').first)
        .toList();
    final parts = <String>[];
    if (skipped.isNotEmpty)
      parts.add('${skipped.join(', ')} — insufficient balance');
    if (reduced.isNotEmpty)
      parts.add('${reduced.join(', ')} — qty reduced by balance');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _amberLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _amberBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 13, color: _amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join('\n'),
              style: const TextStyle(
                  fontSize: 11, color: _amberText, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint() => _Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.add_shopping_cart_rounded,
                color: _primary, size: 22),
          ),
          const SizedBox(height: 14),
          const Text(
            'Basket is empty',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textDark,
                letterSpacing: -0.2),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search and add stocks above to place a group order.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: _textLight, height: 1.5),
          ),
        ],
      ),
    ),
  );

  static String _fmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)} L';
    return v.toStringAsFixed(2);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER TAB ITEM
// ═══════════════════════════════════════════════════════════════════════════

class _HeaderTabItem extends StatelessWidget {
  final String label;
  final int index;
  final TabController controller;
  final Color activeColor, activeBg, activeShadow;

  const _HeaderTabItem({
    required this.label,
    required this.index,
    required this.controller,
    required this.activeColor,
    required this.activeBg,
    required this.activeShadow,
  });

  @override
  Widget build(BuildContext context) {
    final active = controller.index == index;
    return Expanded(
      child: InkWell(
        onTap: () => controller.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(2),
          height: double.infinity,
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
              BoxShadow(
                  color: activeShadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: active
                    ? activeColor
                    : Colors.white.withOpacity(0.40),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PLACE ORDER BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _PlaceOrderButton extends StatelessWidget {
  final bool isBuy, isLoading, isEnabled;
  final int stockCount, accountCount;
  final double totalCharges;
  final VoidCallback onPressed;

  const _PlaceOrderButton({
    required this.isBuy,
    required this.isLoading,
    required this.isEnabled,
    required this.stockCount,
    required this.accountCount,
    required this.totalCharges,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color c1 = isBuy ? _greenDark : _redDark;
    final Color c2 = isBuy ? _greenMid : _red;
    final Color shadow = isBuy ? _green : _red;

    return AnimatedOpacity(
      opacity: isEnabled ? 1.0 : 0.55,
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: isEnabled
                ? LinearGradient(
              colors: [c1, c2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
                : null,
            color: isEnabled ? null : _textXLight,
            borderRadius: BorderRadius.circular(13),
            boxShadow: isEnabled
                ? [
              BoxShadow(
                  color: shadow.withOpacity(0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 5)),
              BoxShadow(
                  color: shadow.withOpacity(0.10),
                  blurRadius: 4,
                  offset: const Offset(0, 1)),
            ]
                : [],
          ),
          child: isLoading
              ? Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PLACE ${isBuy ? 'BUY' : 'SELL'} · $stockCount STOCK${stockCount == 1 ? '' : 'S'} · $accountCount ACCOUNT${accountCount == 1 ? '' : 'S'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              if (totalCharges > 0) ...[
                const SizedBox(height: 1),
                Text(
                  '+ ₹${totalCharges.toStringAsFixed(2)} est. charges',
                  style:
                  const TextStyle(fontSize: 9, color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STOCK SPECIAL ORDER FIELDS
// ═══════════════════════════════════════════════════════════════════════════

class _StockSpecialFields extends StatelessWidget {
  final StockOrderItem item;
  final SpecialOrder special;
  final VoidCallback onChanged;

  const _StockSpecialFields({
    required this.item,
    required this.special,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final name = item.scrip.tradingSymbol.replaceAll('-EQ', '');
    final ltpStr =
    item.ltp > 0 ? '₹${item.ltp.toStringAsFixed(2)}' : '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(
                label: name[0],
                color: _stockColor(name),
                bg: _stockColor(name).withOpacity(0.1),
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _textDark),
                    ),
                    Text(
                      'LTP: $ltpStr · ${item.scrip.exchange}',
                      style:
                      const TextStyle(fontSize: 10, color: _textLight),
                    ),
                  ],
                ),
              ),
              if (item.ltpLoading)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: _primary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (special == SpecialOrder.stopLoss) ...[
            Row(
              children: [
                Expanded(
                  child: _ManualPriceField(
                    label: 'SL Price (₹)',
                    hint: item.ltp > 0
                        ? (item.ltp * 0.95).toStringAsFixed(2)
                        : '0.00',
                    ctrl: item.slPriceCtrl,
                    color: _red,
                    onChanged: onChanged,
                    warning: item.ltp > 0 &&
                        item.slPriceCtrl.text.isNotEmpty
                        ? (double.tryParse(item.slPriceCtrl.text) ?? 0) >=
                        item.ltp
                        ? 'SL must be below LTP'
                        : null
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ManualPriceField(
                    label: 'Trigger (₹)',
                    hint: item.ltp > 0
                        ? (item.ltp * 0.96).toStringAsFixed(2)
                        : '0.00',
                    ctrl: item.triggerPriceCtrl,
                    color: _amber,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
            if (item.ltp > 0 && item.slPriceCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              _slPreview(item),
            ],
          ],
          if (special == SpecialOrder.robo) ...[
            Row(
              children: [
                Expanded(
                  child: _ManualPriceField(
                    label: 'SL Price (₹)',
                    hint: item.ltp > 0
                        ? (item.ltp * 0.975).toStringAsFixed(2)
                        : '0.00',
                    ctrl: item.slPriceCtrl,
                    color: _red,
                    onChanged: onChanged,
                    warning: item.ltp > 0 &&
                        item.slPriceCtrl.text.isNotEmpty
                        ? (double.tryParse(item.slPriceCtrl.text) ?? 0) >=
                        item.ltp
                        ? 'SL must be below LTP'
                        : null
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ManualPriceField(
                    label: 'Target (₹)',
                    hint: item.ltp > 0
                        ? (item.ltp * 1.05).toStringAsFixed(2)
                        : '0.00',
                    ctrl: item.targetPriceCtrl,
                    color: _green,
                    onChanged: onChanged,
                    warning: item.ltp > 0 &&
                        item.targetPriceCtrl.text.isNotEmpty
                        ? (double.tryParse(item.targetPriceCtrl.text) ?? 0) <=
                        item.ltp
                        ? 'Target must be above LTP'
                        : null
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ManualPriceField(
              label: 'Trailing SL Jump (₹)',
              hint: item.ltp > 0
                  ? (item.ltp * 0.005).toStringAsFixed(2)
                  : '0.00',
              ctrl: item.trailJumpCtrl,
              color: _amber,
              onChanged: onChanged,
            ),
            if (item.ltp > 0) ...[
              const SizedBox(height: 6),
              _roboPreview(item),
            ],
          ],
          if (special == SpecialOrder.gtt) ...[
            _ManualPriceField(
              label: 'GTT Trigger (₹)',
              hint: item.ltp > 0 ? item.ltp.toStringAsFixed(2) : '0.00',
              ctrl: item.triggerPriceCtrl,
              color: _amber,
              onChanged: onChanged,
            ),
            if (item.ltp > 0 &&
                item.triggerPriceCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              _gttPreview(item),
            ],
          ],
        ],
      ),
    );
  }

  Widget _slPreview(StockOrderItem item) {
    final sl = double.tryParse(item.slPriceCtrl.text) ?? 0;
    if (sl <= 0 || item.ltp <= 0) return const SizedBox.shrink();
    final risk = ((item.ltp - sl) / item.ltp * 100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _redLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _redBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 11, color: _red),
          const SizedBox(width: 6),
          Text(
            'Risk: ₹${(item.ltp - sl).toStringAsFixed(2)}/share (${risk.toStringAsFixed(2)}%)',
            style: const TextStyle(
                fontSize: 11, color: _red, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _roboPreview(StockOrderItem item) {
    final sl = double.tryParse(item.slPriceCtrl.text) ?? 0;
    final tgt = double.tryParse(item.targetPriceCtrl.text) ?? 0;
    if (sl <= 0 && tgt <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          if (sl > 0)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Risk/share',
                      style: TextStyle(fontSize: 9, color: _textLight)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${(item.ltp - sl).abs().toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _red),
                  ),
                ],
              ),
            ),
          if (sl > 0 && tgt > 0)
            Container(
                width: 1,
                height: 26,
                color: _border,
                margin: const EdgeInsets.symmetric(horizontal: 8)),
          if (tgt > 0)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reward/share',
                      style: TextStyle(fontSize: 9, color: _textLight)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${(tgt - item.ltp).abs().toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _green),
                  ),
                ],
              ),
            ),
          if (sl > 0 && tgt > 0) ...[
            Container(
                width: 1,
                height: 26,
                color: _border,
                margin: const EdgeInsets.symmetric(horizontal: 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('R:R',
                      style: TextStyle(fontSize: 9, color: _textLight)),
                  const SizedBox(height: 2),
                  Text(
                    '1 : ${((tgt - item.ltp) / (item.ltp - sl)).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gttPreview(StockOrderItem item) {
    final trigger = double.tryParse(item.triggerPriceCtrl.text) ?? 0;
    if (trigger <= 0) return const SizedBox.shrink();
    final diff = trigger - item.ltp;
    final pct = (diff / item.ltp * 100);
    final isAbove = diff >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _amberLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _amberBorder),
      ),
      child: Row(
        children: [
          Icon(
            isAbove
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 11,
            color: _amber,
          ),
          const SizedBox(width: 6),
          Text(
            'Trigger ${diff.abs().toStringAsFixed(2)} (${pct.abs().toStringAsFixed(2)}%) ${isAbove ? 'above' : 'below'} LTP',
            style: const TextStyle(
                fontSize: 11,
                color: _amberText,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static Color _stockColor(String name) {
    const colors = [
      Color(0xFF3B5BDB),
      Color(0xFF0B7285),
      Color(0xFFD63939),
      Color(0xFFE67700),
      Color(0xFF7048E8),
      Color(0xFF1098AD),
      Color(0xFF2F9E44),
      Color(0xFFC2255C),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MANUAL PRICE INPUT FIELD
// ═══════════════════════════════════════════════════════════════════════════

class _ManualPriceField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final Color color;
  final VoidCallback onChanged;
  final String? warning;

  const _ManualPriceField({
    required this.label,
    required this.hint,
    required this.ctrl,
    required this.color,
    required this.onChanged,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: _textMid),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: TextField(
            controller: ctrl,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            onChanged: (_) => onChanged(),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  fontSize: 11,
                  color: _textXLight,
                  fontWeight: FontWeight.w400),
              filled: true,
              fillColor: color.withOpacity(0.04),
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.6),
                  fontWeight: FontWeight.w600),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color:
                    warning != null ? _red : color.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
            ),
          ),
        ),
        if (warning != null) ...[
          const SizedBox(height: 3),
          Text(warning!, style: const TextStyle(fontSize: 10, color: _red)),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BASKET ROW
// ═══════════════════════════════════════════════════════════════════════════

class _BasketRow extends StatelessWidget {
  final StockOrderItem item;
  final OrderSide side;
  final VoidCallback onRemove, onDec, onInc;
  const _BasketRow({
    required this.item,
    required this.side,
    required this.onRemove,
    required this.onDec,
    required this.onInc,
  });

  @override
  Widget build(BuildContext context) {
    final name = item.scrip.tradingSymbol.replaceAll('-EQ', '');
    final ltpUp = item.ltpChange >= 0;
    final exchange = item.scrip.exchange.toUpperCase();

    Color exchFg;
    Color exchBg;
    Color exchBd;
    switch (exchange) {
      case 'BSE':
        exchFg = _kBseFg;
        exchBg = _kBseBg;
        exchBd = _kBseBg;
        break;
      case 'NFO':
        exchFg = _kNfoFg;
        exchBg = _kNfoBg;
        exchBd = _kNfoBd;
        break;
      default:
        exchFg = _kNseFg;
        exchBg = _kNseBg;
        exchBd = _kNseBg;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _Avatar(
            label: name.isNotEmpty ? name[0] : '?',
            color: _stockColor(name),
            bg: _stockColor(name).withOpacity(0.1),
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                      letterSpacing: -0.1),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: exchBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: exchBd),
                      ),
                      child: Text(
                        exchange,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: exchFg,
                            letterSpacing: 0.1),
                      ),
                    ),
                    SizedBox(width: 6),
                    if (item.ltpLoading)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: _primary),
                      )
                    else if (item.ltpError != null)
                      const Text('LTP error',
                          style: TextStyle(fontSize: 9, color: _red))
                    else
                      Row(
                        children: [
                          Icon(
                            ltpUp
                                ? Icons.arrow_drop_up_rounded
                                : Icons.arrow_drop_down_rounded,
                            size: 15,
                            color: ltpUp ? _green : _red,
                          ),
                          Text(
                            '₹${item.ltp.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ltpUp ? _green : _red),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          _MiniStepper(
              ctrl: item.qtyCtrl, onDec: onDec, onInc: onInc),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _redLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _redBorder),
              ),
              child:
              const Icon(Icons.close_rounded, size: 12, color: _red),
            ),
          ),
        ],
      ),
    );
  }

  static Color _stockColor(String name) {
    const colors = [
      Color(0xFF3B5BDB),
      Color(0xFF0B7285),
      Color(0xFFD63939),
      Color(0xFFE67700),
      Color(0xFF7048E8),
      Color(0xFF1098AD),
      Color(0xFF2F9E44),
      Color(0xFFC2255C),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MINI STEPPER
// ═══════════════════════════════════════════════════════════════════════════

class _MiniStepper extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onDec, onInc;
  const _MiniStepper(
      {required this.ctrl, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove_rounded, onDec, isLeft: true),
        SizedBox(
          width: 38,
          child: TextField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textDark),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
        _btn(Icons.add_rounded, onInc, isLeft: false),
      ],
    ),
  );

  Widget _btn(IconData icon, VoidCallback onTap, {required bool isLeft}) =>
      InkWell(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              right: isLeft
                  ? const BorderSide(color: _border)
                  : BorderSide.none,
              left: isLeft
                  ? BorderSide.none
                  : const BorderSide(color: _border),
            ),
          ),
          child: Icon(icon, size: 13, color: _textMid),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// MEMBER SUMMARY ROW
// ═══════════════════════════════════════════════════════════════════════════

class _MemberSummaryRow extends StatefulWidget {
  final MemberOrderSummary summary;
  const _MemberSummaryRow({required this.summary});

  @override
  State<_MemberSummaryRow> createState() => _MemberSummaryRowState();
}

class _MemberSummaryRowState extends State<_MemberSummaryRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.summary.member;
    final charges = widget.summary.totalCharges;
    final tradeVal = widget.summary.totalTradeValue;
    final bp = widget.summary.effectiveBuyingPower;
    final product = widget.summary.product;

    Color statusColor;
    Color statusBg;
    String statusLabel;
    if (!widget.summary.hasAnyOrder) {
      statusColor = _red;
      statusBg = _redLight;
      statusLabel = 'Insufficient';
    } else if (widget.summary.hasReduced || widget.summary.hasSkipped) {
      statusColor = _amber;
      statusBg = _amberLight;
      statusLabel = 'Partial';
    } else {
      statusColor = _green;
      statusBg = _greenLight;
      statusLabel = 'Full Qty';
    }

    final String bpLabel = switch (product) {
      ProductType.delivery => 'Cash',
      ProductType.intraday => 'BP (5×)',
      ProductType.payLater => 'BP (3.8×)',
    };

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: _primaryLight,
                  child: Text(
                    m.initials,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                            letterSpacing: -0.1),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 9,
                              color: _textLight),
                          const SizedBox(width: 2),
                          Text(
                            '₹${_fmt(m.cashBalance)}',
                            style: const TextStyle(
                                fontSize: 10, color: _textLight),
                          ),
                          if (product != ProductType.delivery) ...[
                            const Text(' · ',
                                style: TextStyle(
                                    fontSize: 10, color: _textXLight)),
                            Icon(
                              product == ProductType.intraday
                                  ? Icons.bolt_rounded
                                  : Icons.access_time_rounded,
                              size: 9,
                              color: _purple,
                            ),
                            const SizedBox(width: 1),
                            Text(
                              '$bpLabel: ₹${_fmt(bp)}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _purple),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (tradeVal > 0)
                      Text(
                        '₹${_fmt(tradeVal)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _textDark),
                      ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: statusColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: _textLight),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: widget.summary.allocations
                        .asMap()
                        .entries
                        .map((e) {
                      final alloc = e.value;
                      final item = alloc.item;
                      final name = item.scrip.tradingSymbol
                          .replaceAll('-EQ', '');
                      final isLast = e.key ==
                          widget.summary.allocations.length - 1;

                      Color qtyColor;
                      Color qtyBg;
                      String qtyLabel;
                      if (alloc.isSkipped) {
                        qtyColor = _red;
                        qtyBg = _redLight;
                        qtyLabel = 'Skip';
                      } else if (alloc.isReduced) {
                        qtyColor = _amber;
                        qtyBg = _amberLight;
                        qtyLabel =
                        '${alloc.effectiveQty}/${alloc.requestedQty}';
                      } else {
                        qtyColor = _green;
                        qtyBg = _greenLight;
                        qtyLabel = 'Qty ${alloc.effectiveQty}';
                      }

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                10, 8, 10, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight:
                                            FontWeight.w600,
                                            color: _textMid),
                                      ),
                                      if (alloc.effectiveQty > 0)
                                        Text(
                                          '₹${_fmt(alloc.allocatedValue)} + ₹${alloc.charges.total.toStringAsFixed(2)} charges',
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: _textLight),
                                        ),
                                      if (alloc.isSkipped)
                                        Text(
                                          'Need ₹${_fmt(item.ltp)}, have ₹${_fmt(bp)}',
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: _red),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!alloc.isOk &&
                                    alloc.maxAffordableQty > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        right: 6),
                                    child: Text(
                                      'max ${alloc.maxAffordableQty}',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: _textLight),
                                    ),
                                  ),
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3),
                                  decoration: BoxDecoration(
                                    color: qtyBg,
                                    borderRadius:
                                    BorderRadius.circular(5),
                                    border: Border.all(
                                        color: qtyColor
                                            .withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    qtyLabel,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: qtyColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast) const _Div(),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                if (charges.total > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 10, color: _textLight),
                      const SizedBox(width: 3),
                      Text(
                        'Total incl. charges: ₹${_fmt(tradeVal + charges.total)}',
                        style: const TextStyle(
                            fontSize: 10, color: _textLight),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  static String _fmt(double v) {
    if (v >= 10000000)
      return '${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)} L';
    return v.toStringAsFixed(2);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMBEDDED STOCK SEARCH  ── upgraded to match StockSearchWidget style
// ═══════════════════════════════════════════════════════════════════════════

/// Which instrument-type filter is active.  null / all = no filter.
enum _InstrFilter { all, eq, fut, opt }

class _EmbeddedStockSearch extends StatefulWidget {
  final ValueChanged<ScripInfo> onScripSelected;
  const _EmbeddedStockSearch({required this.onScripSelected});

  @override
  State<_EmbeddedStockSearch> createState() =>
      _EmbeddedStockSearchState();
}

class _EmbeddedStockSearchState extends State<_EmbeddedStockSearch>
    with TickerProviderStateMixin {

  final _ctrl      = TextEditingController();
  final _focus     = FocusNode();
  final _layerLink = LayerLink();

  Timer?          _debounce;
  List<ScripInfo> _results      = [];
  bool            _loading      = false;
  bool            _isFocused    = false;
  _InstrFilter    _activeFilter = _InstrFilter.all;

  /// True while the pointer is inside the overlay.
  /// Prevents the focus-lost close when a filter chip is tapped.
  bool _pointerInsideOverlay = false;

  OverlayEntry? _overlayEntry;

  // Focus ring animation (matches StockSearchWidget)
  late AnimationController _focusCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _borderAnim;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();

    _focusCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _borderAnim =
        CurvedAnimation(parent: _focusCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _focus.addListener(_onFocusChanged);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _removeOverlay();
    _focus.removeListener(_onFocusChanged);
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _focusCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _isFocused = _focus.hasFocus);
    if (_focus.hasFocus) {
      _focusCtrl.forward();
    } else {
      if (_pointerInsideOverlay) {
        Future.microtask(() {
          if (mounted) _focus.requestFocus();
        });
        return;
      }
      _focusCtrl.reverse();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_pointerInsideOverlay) _removeOverlay();
      });
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      _removeOverlay();
      return;
    }
    _debounce = Timer(
        const Duration(milliseconds: 350), () => _doSearch(val.trim()));
  }

  void _doSearch(String query) {
    if (!mounted) return;
    setState(() => _loading = true);
    // No exchange filter — search all (group panel shows all exchanges)
    context.read<IndividualExecutionBloc>().add(
      SearchScripRequested(query: query.toUpperCase(), exchange: ''),
    );
  }

  void _onResultsReceived(List<ScripInfo> results) {
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
    results.isNotEmpty ? _refreshOverlay() : _removeOverlay();
  }

  void _select(ScripInfo s) {
    _ctrl.clear();
    setState(() {
      _results = [];
      _loading = false;
      _activeFilter = _InstrFilter.all;
    });
    _removeOverlay();
    _focus.unfocus();
    widget.onScripSelected(s);
  }

  void _clear() {
    _ctrl.clear();
    setState(() {
      _results = [];
      _loading = false;
      _activeFilter = _InstrFilter.all;
    });
    _removeOverlay();
  }

  void _setFilter(_InstrFilter f) {
    setState(() => _activeFilter = f);
    _refreshOverlay();
    _focus.requestFocus();
  }

  // ── Overlay ───────────────────────────────────────────────────────────────

  void _refreshOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => _EmbeddedDropdownOverlay(
        layerLink:       _layerLink,
        results:         _results,
        activeFilter:    _activeFilter,
        onSelect:        _select,
        onFilterChanged: (f) {
          _activeFilter = f;
          _overlayEntry?.markNeedsBuild();
          _focus.requestFocus();
        },
        onPointerEnter: () => _pointerInsideOverlay = true,
        onPointerExit:  () => _pointerInsideOverlay = false,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<IndividualExecutionBloc, IndividualExecutionState>(
      listener: (_, state) {
        if (state is ScripSearchSuccess) {
          _onResultsReceived(state.results);
        } else if (state is ScripSearchLoading) {
          if (mounted) setState(() => _loading = true);
        } else if (state is ScripSearchFailure) {
          if (mounted) setState(() {
            _results = [];
            _loading = false;
          });
          _removeOverlay();
        }
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: AnimatedBuilder(
          animation: _borderAnim,
          builder: (_, __) {
            final t = _borderAnim.value;
            return Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color.lerp(_border, _kAccent, t)!,
                  width: 1.0 + (t * 0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.055),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  if (t > 0)
                    BoxShadow(
                      color: _kAccent.withOpacity(0.14 * t),
                      blurRadius: 16 * t,
                      spreadRadius: t * 1,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Search icon / loader ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: _loading
                          ? Center(
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, __) => Opacity(
                            opacity: _pulse.value,
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: _kAccent,
                              ),
                            ),
                          ),
                        ),
                      )
                          : Center(
                        child: AnimatedBuilder(
                          animation: _borderAnim,
                          builder: (_, __) => Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: Color.lerp(
                              const Color(0xFFCBD5E1),
                              _kAccent,
                              _borderAnim.value,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Text field ───────────────────────────────────
                    Expanded(
                      child: Center(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          onChanged: _onChanged,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: _textDark,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.15,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                            'Search stocks, F&O  e.g. INFY, NIFTY…',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFBCC8D8),
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),

                    // ── Clear button ─────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: _ctrl.text.isNotEmpty
                          ? InkWell(
                        key: const ValueKey('clear'),
                        onTap: _clear,
                        child: Padding(
                          padding:
                          const EdgeInsets.only(right: 12),
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEDF0F5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.close_rounded,
                                  size: 12,
                                  color: _textLight),
                            ),
                          ),
                        ),
                      )
                          : const SizedBox(
                          key: ValueKey('empty'), width: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMBEDDED DROPDOWN OVERLAY
// Matches _DropdownOverlay in StockSearchWidget exactly.
// ═══════════════════════════════════════════════════════════════════════════

class _EmbeddedDropdownOverlay extends StatefulWidget {
  final LayerLink                     layerLink;
  final List<ScripInfo>               results;
  final _InstrFilter                  activeFilter;
  final ValueChanged<ScripInfo>       onSelect;
  final ValueChanged<_InstrFilter>    onFilterChanged;
  final VoidCallback                  onPointerEnter;
  final VoidCallback                  onPointerExit;

  const _EmbeddedDropdownOverlay({
    required this.layerLink,
    required this.results,
    required this.activeFilter,
    required this.onSelect,
    required this.onFilterChanged,
    required this.onPointerEnter,
    required this.onPointerExit,
  });

  @override
  State<_EmbeddedDropdownOverlay> createState() =>
      _EmbeddedDropdownOverlayState();
}

class _EmbeddedDropdownOverlayState
    extends State<_EmbeddedDropdownOverlay>
    with SingleTickerProviderStateMixin {

  late AnimationController _enterCtrl;
  late Animation<double>   _slideAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _slideAnim = Tween<double>(begin: -8, end: 0).animate(
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _fadeAnim  =
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  List<ScripInfo> get _filtered {
    if (widget.activeFilter == _InstrFilter.all) return widget.results;
    return widget.results.where((s) {
      final t = s.instrumentType.toUpperCase();
      switch (widget.activeFilter) {
        case _InstrFilter.eq:
          return t == 'EQ' || t.isEmpty;
        case _InstrFilter.fut:
          return t.contains('FUT');
        case _InstrFilter.opt:
          return t.contains('OPT') || t == 'CE' || t == 'PE';
        default:
          return true;
      }
    }).toList();
  }

  int _countFor(_InstrFilter f) {
    if (f == _InstrFilter.all) return widget.results.length;
    return widget.results.where((s) {
      final t = s.instrumentType.toUpperCase();
      switch (f) {
        case _InstrFilter.eq:  return t == 'EQ' || t.isEmpty;
        case _InstrFilter.fut: return t.contains('FUT');
        case _InstrFilter.opt:
          return t.contains('OPT') || t == 'CE' || t == 'PE';
        default: return true;
      }
    }).length;
  }

  // ── Section grouping ──────────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildSections(List<ScripInfo> items) {
    final eq    = <ScripInfo>[];
    final fut   = <ScripInfo>[];
    final opt   = <ScripInfo>[];
    final other = <ScripInfo>[];
    for (final s in items) {
      final t = s.instrumentType.toUpperCase();
      if (t.contains('FUT'))                       fut.add(s);
      else if (t.contains('OPT') || t == 'CE' || t == 'PE') opt.add(s);
      else if (t == 'EQ' || t.isEmpty)             eq.add(s);
      else                                          other.add(s);
    }
    return [
      if (eq.isNotEmpty)    {'label': 'EQUITY',  'items': eq},
      if (fut.isNotEmpty)   {'label': 'FUTURES', 'items': fut},
      if (opt.isNotEmpty)   {'label': 'OPTIONS', 'items': opt},
      if (other.isNotEmpty) {'label': 'OTHER',   'items': other},
    ];
  }

  static Color _avatarColor(String name) {
    const colors = [
      Color(0xFF047857), Color(0xFF059669), Color(0xFF10B981),
      Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6),
      Color(0xFF06B6D4), Color(0xFFEC4899),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) return const SizedBox.shrink();

    final filtered = _filtered;
    final sections = _buildSections(filtered);

    final List<Widget> rows = [];
    for (final section in sections) {
      final label = section['label'] as String;
      final items = section['items'] as List<ScripInfo>;
      rows.add(_EmbSectionHeader(label: label, count: items.length));
      for (int i = 0; i < items.length; i++) {
        final s    = items[i];
        final name = (s.name.isNotEmpty ? s.name : s.tradingSymbol)
            .replaceAll('-EQ', '');
        rows.add(_EmbResultTile(
          s: s,
          name: name,
          col: _avatarColor(name),
          onSelect: widget.onSelect,
        ));
        if (i < items.length - 1) {
          rows.add(const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 1, color: Color(0xFFF3F4F8)),
          ));
        }
      }
    }

    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: widget.layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 54),
        child: AnimatedBuilder(
          animation: _enterCtrl,
          builder: (_, child) => FadeTransition(
            opacity: _fadeAnim,
            child: Transform.translate(
              offset: Offset(0, _slideAnim.value),
              child: child,
            ),
          ),
          child: MouseRegion(
            onEnter: (_) => widget.onPointerEnter(),
            onExit:  (_) => widget.onPointerExit(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                // Width fills the card minus the 12+12 horizontal padding
                width: MediaQuery.of(context).size.width - 24 - 24,
                constraints: const BoxConstraints(maxHeight: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFEBEDF3), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 32,
                      spreadRadius: -2,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: _kAccent.withOpacity(0.07),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ── Header: result count + filter chips ──────────
                      Container(
                        padding:
                        const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFBFBFD),
                          border: Border(
                              bottom:
                              BorderSide(color: Color(0xFFEEF0F5))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7, height: 7,
                              decoration: const BoxDecoration(
                                color: _kAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _textLight,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Filter chips — identical to StockSearchWidget
                            _EmbFilterChip(
                              label: 'All',
                              count: _countFor(_InstrFilter.all),
                              active: widget.activeFilter ==
                                  _InstrFilter.all,
                              activeFg: Colors.white,
                              activeBg: _kAccent,
                              inactiveFg: _textLight,
                              inactiveBg: const Color(0xFFF1F3F8),
                              onTap: () => widget
                                  .onFilterChanged(_InstrFilter.all),
                            ),
                            const SizedBox(width: 6),
                            _EmbFilterChip(
                              label: 'EQ',
                              count: _countFor(_InstrFilter.eq),
                              active: widget.activeFilter ==
                                  _InstrFilter.eq,
                              activeFg: Colors.white,
                              activeBg: _kEqFg,
                              inactiveFg: _kEqFg,
                              inactiveBg: _kEqBg,
                              borderColor: _kEqBd,
                              onTap: () => widget
                                  .onFilterChanged(_InstrFilter.eq),
                            ),
                            const SizedBox(width: 6),
                            _EmbFilterChip(
                              label: 'FUT',
                              count: _countFor(_InstrFilter.fut),
                              active: widget.activeFilter ==
                                  _InstrFilter.fut,
                              activeFg: Colors.white,
                              activeBg: _kFutFg,
                              inactiveFg: _kFutFg,
                              inactiveBg: _kFutBg,
                              borderColor: _kFutBd,
                              onTap: () => widget
                                  .onFilterChanged(_InstrFilter.fut),
                            ),
                            const SizedBox(width: 6),
                            _EmbFilterChip(
                              label: 'OPT',
                              count: _countFor(_InstrFilter.opt),
                              active: widget.activeFilter ==
                                  _InstrFilter.opt,
                              activeFg: Colors.white,
                              activeBg: _kOptFg,
                              inactiveFg: _kOptFg,
                              inactiveBg: _kOptBg,
                              borderColor: _kOptBd,
                              onTap: () => widget
                                  .onFilterChanged(_InstrFilter.opt),
                            ),
                            const Spacer(),
                            const Text(
                              'tap to add',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFCBD5E1)),
                            ),
                          ],
                        ),
                      ),

                      // ── Sectioned results ────────────────────────────
                      if (rows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No results for this filter',
                              style: TextStyle(
                                  fontSize: 13, color: _textLight),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView(
                            padding:
                            const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            children: rows,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter chip (embedded version, matches StockSearchWidget _FilterChip) ─────

class _EmbFilterChip extends StatelessWidget {
  final String  label;
  final int     count;
  final bool    active;
  final Color   activeFg, activeBg;
  final Color   inactiveFg, inactiveBg;
  final Color?  borderColor;
  final VoidCallback onTap;

  const _EmbFilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.activeFg,
    required this.activeBg,
    required this.inactiveFg,
    required this.inactiveBg,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? activeFg : inactiveFg;
    final bg = active ? activeBg : inactiveBg;
    final bd = active ? activeBg : (borderColor ?? inactiveBg);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: bd, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: 0.4,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? activeFg.withOpacity(0.20)
                      : fg.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section header (embedded version) ────────────────────────────────────────

class _EmbSectionHeader extends StatelessWidget {
  final String label;
  final int    count;
  const _EmbSectionHeader({required this.label, required this.count});

  Color get _fg {
    switch (label) {
      case 'FUTURES': return _kFutFg;
      case 'OPTIONS': return _kOptFg;
      case 'EQUITY':  return _kEqFg;
      default:        return _kOtherFg;
    }
  }
  Color get _bg {
    switch (label) {
      case 'FUTURES': return _kFutBg;
      case 'OPTIONS': return _kOptBg;
      case 'EQUITY':  return _kEqBg;
      default:        return _kOtherBg;
    }
  }
  Color get _bd {
    switch (label) {
      case 'FUTURES': return _kFutBd;
      case 'OPTIONS': return _kOptBd;
      case 'EQUITY':  return _kEqBd;
      default:        return _kOtherBd;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 6),
      color: const Color(0xFFFAFAFC),
      child: Row(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bd),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _fg,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count item${count == 1 ? '' : 's'}',
            style: const TextStyle(
                fontSize: 11,
                color: _textLight,
                fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              height: 1,
              color: const Color(0xFFEEF0F5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated result tile (embedded version) ───────────────────────────────────

class _EmbResultTile extends StatefulWidget {
  final ScripInfo               s;
  final String                  name;
  final Color                   col;
  final ValueChanged<ScripInfo> onSelect;

  const _EmbResultTile({
    required this.s,
    required this.name,
    required this.col,
    required this.onSelect,
  });

  @override
  State<_EmbResultTile> createState() => _EmbResultTileState();
}

class _EmbResultTileState extends State<_EmbResultTile>
    with SingleTickerProviderStateMixin {

  late AnimationController _hoverCtrl;
  late Animation<double>   _hoverAnim;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _hoverAnim =
        CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  // ── Badge helpers ─────────────────────────────────────────────────────────

  _EmbBadgeStyle get _instrumentBadge {
    switch (widget.s.typeLabel) {
      case 'FUT': return const _EmbBadgeStyle(_kFutFg, _kFutBg, _kFutBd);
      case 'OPT': return const _EmbBadgeStyle(_kOptFg, _kOptBg, _kOptBd);
      case 'EQ':  return const _EmbBadgeStyle(_kEqFg,  _kEqBg,  _kEqBd);
      default:    return const _EmbBadgeStyle(_kOtherFg, _kOtherBg, _kOtherBd);
    }
  }

  _EmbBadgeStyle get _exchangeBadge {
    switch (widget.s.exchange.toUpperCase()) {
      case 'NFO': return const _EmbBadgeStyle(_kNfoFg, _kNfoBg, _kNfoBd);
      case 'BSE': return const _EmbBadgeStyle(_kBseFg, _kBseBg, _kBseBg);
      default:    return const _EmbBadgeStyle(_kNseFg, _kNseBg, _kNseBg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ib = _instrumentBadge;
    final eb = _exchangeBadge;

    return MouseRegion(
      onEnter: (_) => _hoverCtrl.forward(),
      onExit:  (_) => _hoverCtrl.reverse(),
      child: InkWell(
        onTap: () => widget.onSelect(widget.s),
        child: AnimatedBuilder(
          animation: _hoverAnim,
          builder: (_, __) => Container(
            color: Color.lerp(
                Colors.transparent, _kAccentSoft, _hoverAnim.value),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              children: [

                // Avatar
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: widget.col.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: widget.col.withOpacity(0.20), width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0] : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: widget.col,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name + symbol + lot size
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.s.tradingSymbol,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textLight,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.s.isDerivative &&
                              widget.s.lotSize > 1) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: _kOptBg,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: _kOptBd),
                              ),
                              child: Text(
                                'Lot ${widget.s.lotSize}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: _kOptFg,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Instrument type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: ib.bg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: ib.bd),
                  ),
                  child: Text(
                    widget.s.typeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ib.fg,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Exchange badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: eb.bg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: eb.bd),
                  ),
                  child: Text(
                    widget.s.exchange,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: eb.fg,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Add button
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _greenLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _greenBorder),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 14, color: _green),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Badge style data (embedded, avoids collision with outer _BadgeStyleData) ──

class _EmbBadgeStyle {
  final Color fg, bg, bd;
  const _EmbBadgeStyle(this.fg, this.bg, this.bd);
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED PRIMITIVE WIDGETS  (unchanged from original)
// ═══════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border, width: 1),
      boxShadow: _cardShadow,
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: _border);
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color, bg, border;
  const _Pill(this.text, this.color, this.bg, this.border);

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: border),
    ),
    child: Text(
      text,
      style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.1),
    ),
  );
}

class _Avatar extends StatelessWidget {
  final String label;
  final Color color, bg;
  final double size;
  const _Avatar(
      {required this.label,
        required this.color,
        required this.bg,
        required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(size * 0.28),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(
            fontSize: size * 0.40,
            fontWeight: FontWeight.w800,
            color: color),
      ),
    ),
  );
}

class _ExpandButton extends StatelessWidget {
  final bool expanded;
  final String label;
  final VoidCallback onTap;
  const _ExpandButton(
      {required this.expanded,
        required this.label,
        required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _primaryBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _primary),
          ),
          const SizedBox(width: 3),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 13, color: _primary),
          ),
        ],
      ),
    ),
  );
}

class _SegmentedPill extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onTap;
  const _SegmentedPill(
      {required this.options,
        required this.selected,
        required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: _border),
    ),
    padding: const EdgeInsets.all(2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: options.asMap().entries.map((e) {
        final isActive = e.key == selected;
        return InkWell(
          onTap: () => onTap(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(
                horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: isActive ? _primary : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              boxShadow: isActive
                  ? [
                BoxShadow(
                    color: _primary.withOpacity(0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 1))
              ]
                  : [],
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: isActive ? Colors.white : _textLight,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class _SpecialToggleRow extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final bool active;
  final ValueChanged<bool> onChanged;
  const _SpecialToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color:
            active ? color.withOpacity(0.10) : _bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active
                    ? color.withOpacity(0.3)
                    : _border),
          ),
          child: Icon(icon,
              size: 15, color: active ? color : _textLight),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? color : _textDark),
              ),
              const SizedBox(height: 1),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 10, color: _textLight)),
            ],
          ),
        ),
        _ToggleSwitch(
            value: active,
            activeColor: color,
            onChanged: onChanged),
      ],
    ),
  );
}

class _ToggleSwitch extends StatelessWidget {
  final bool value;
  final Color? activeColor;
  final ValueChanged<bool> onChanged;
  const _ToggleSwitch(
      {required this.value,
        required this.onChanged,
        this.activeColor});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 38,
      height: 22,
      decoration: BoxDecoration(
        color: value
            ? (activeColor ?? _green)
            : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(11),
        boxShadow: value
            ? [
          BoxShadow(
              color: (activeColor ?? _green).withOpacity(0.20),
              blurRadius: 6,
              offset: const Offset(0, 1))
        ]
            : [],
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment:
        value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    ),
  );
}

class _BalChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color, bg;
  const _BalChip(
      {required this.icon,
        required this.label,
        required this.value,
        required this.color,
        required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.12)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: color.withOpacity(0.7)),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color, bg, border;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color),
        ),
      ],
    ),
  );
}

class _LabeledDropdown extends StatelessWidget {
  final String label, value;
  const _LabeledDropdown({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _textLight),
      ),
      const SizedBox(height: 4),
      Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textDark),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 15, color: _textLight),
          ],
        ),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// MEMBER TILE
// ═══════════════════════════════════════════════════════════════════════════

class _MemberTile extends StatelessWidget {
  final GroupMember member;
  final ProductType product;
  const _MemberTile({required this.member, required this.product});

  @override
  Widget build(BuildContext context) {
    final bp = member.effectiveBuyingPowerFor(product);
    final bpLabel = switch (product) {
      ProductType.delivery => null,
      ProductType.intraday => 'BP (5×)',
      ProductType.payLater => 'BP (3.8×)',
    };
    final bool isDeactivated = member.isDeactivated;
    final bool linked = member.linked;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color:
          isDeactivated ? const Color(0xFFF9FAFB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isDeactivated
              ? Border.all(color: const Color(0xFFE5E7EB))
              : null,
        ),
        child: Row(
          children: [
            Tooltip(
              message: linked ? 'Linked to group' : 'Not linked',
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: linked
                      ? (isDeactivated ? _textXLight : _primary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: linked
                        ? (isDeactivated ? _textXLight : _primary)
                        : _textXLight,
                    width: 1.5,
                  ),
                ),
                child: linked
                    ? const Icon(Icons.check,
                    size: 10, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 13,
              backgroundColor:
              isDeactivated ? const Color(0xFFF3F4F6) : _primaryLight,
              child: Text(
                member.initials,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isDeactivated ? _textXLight : _primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDeactivated ? _textXLight : _textDark,
                            letterSpacing: -0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDeactivated) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _amberLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _amberBorder),
                          ),
                          child: const Text(
                            'Deactivated',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: _amber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${member.clientId} · ${member.brokerType}',
                    style: TextStyle(
                        fontSize: 10,
                        color:
                        isDeactivated ? _textXLight : _textLight),
                  ),
                ],
              ),
            ),
            if (!isDeactivated)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 9,
                          color: _textLight),
                      const SizedBox(width: 2),
                      Text(
                        '₹${member.cashBalance.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _textMid),
                      ),
                    ],
                  ),
                  if (bpLabel != null)
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded,
                            size: 9, color: _purple),
                        const SizedBox(width: 2),
                        Text(
                          '$bpLabel: ₹${bp.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _purple),
                        ),
                      ],
                    ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Skipped',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _textXLight),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalCol extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool alignEnd;
  const _TotalCol(
      {required this.label,
        required this.value,
        required this.color,
        this.alignEnd = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(fontSize: 10, color: _textLight)),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.2),
      ),
    ],
  );
}

class _ValTile extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Color color;
  final bool alignEnd;
  const _ValTile(
      {required this.label,
        required this.value,
        this.sub,
        required this.color,
        this.alignEnd = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
        left: alignEnd ? 12 : 0, right: alignEnd ? 0 : 12),
    child: Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
            const TextStyle(fontSize: 10, color: _textLight)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3),
        ),
        if (sub != null)
          Text(sub!,
              style:
              const TextStyle(fontSize: 9, color: _textLight)),
      ],
    ),
  );
}