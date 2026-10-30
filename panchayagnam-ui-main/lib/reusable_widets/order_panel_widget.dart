import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/individual_bloc/individual_execution_bloc.dart';
import '../models/ScripInfo.dart';

class OrderPanelWidget extends StatefulWidget {
  final ScripInfo? scrip;
  final LtpData?   ltpData;
  final String     side;
  final int        accId;
  final double     availableMargin;

  const OrderPanelWidget({
    Key? key,
    required this.scrip,
    required this.ltpData,
    required this.side,
    required this.accId,
    this.availableMargin = 0.0,
  }) : super(key: key);

  @override
  State<OrderPanelWidget> createState() => _OrderPanelWidgetState();
}

class _OrderPanelWidgetState extends State<OrderPanelWidget>
    with SingleTickerProviderStateMixin {

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _bg        = Color(0xFFF2F4F7);
  static const _surface   = Colors.white;
  static const _divider   = Color(0xFFE8ECF2);
  static const _ink       = Color(0xFF0A0E14);
  static const _inkMid    = Color(0xFF2D3748);
  static const _inkLight  = Color(0xFF64748B);
  static const _accent    = Color(0xFF1E40AF);
  static const _gain      = Color(0xFF059669);
  static const _gainBg    = Color(0xFFD1FAE5);
  static const _loss      = Color(0xFFDC2626);
  static const _lossBg    = Color(0xFFFEE2E2);

  // F&O badge colours
  static const _futFg = Color(0xFF1E40AF);
  static const _futBg = Color(0xFFDBEAFE);
  static const _futBd = Color(0xFFBFDBFE);
  static const _optFg = Color(0xFF92400E);
  static const _optBg = Color(0xFFFEF3C7);
  static const _optBd = Color(0xFFFDE68A);

  late TabController _tabController;

  // ── Controllers ────────────────────────────────────────────────────────────
  // For EQ  : _qtyCtrl holds raw share count
  // For F&O : _qtyCtrl holds LOT count; actual qty = lots × lotSize
  final _qtyCtrl    = TextEditingController(text: '1');
  final _priceCtrl  = TextEditingController();
  final _slCtrl     = TextEditingController();
  final _tgtCtrl    = TextEditingController();
  final _gttTrigCtrl = TextEditingController();
  final _gttLimCtrl  = TextEditingController();
  final _trailCtrl  = TextEditingController();

  // ── EQ product type (unchanged) ────────────────────────────────────────────
  String _productType   = 'DELIVERY';   // EQ only
  // ── F&O product type ──────────────────────────────────────────────────────
  String _fnoProductType = 'NRML';      // FnO only: NRML | MIS

  String _baseOrderType = 'LIMIT';
  bool   _isPlacing     = false;
  bool   _stopLossOn    = false;
  bool   _coverOn       = false;
  bool   _roboOn        = false;
  bool   _gttOn         = false;

  // ── Scrip helpers ──────────────────────────────────────────────────────────
  bool   get _isFnO     => widget.scrip?.isDerivative ?? false;
  int    get _lotSize   => (widget.scrip?.lotSize ?? 1).clamp(1, 999999);

  // lots entered in field (for F&O) or shares (for EQ)
  int    get _lotsOrShares => int.tryParse(_qtyCtrl.text.trim()) ?? 0;

  // actual quantity to send in the order
  int    get _qty => _isFnO
      ? _lotsOrShares * _lotSize
      : _lotsOrShares;

  double get _price => _baseOrderType == 'MARKET'
      ? (widget.ltpData?.ltp ?? 0)
      : (double.tryParse(_priceCtrl.text.trim()) ?? 0);

  double get _marginRequired => _qty * _price;

  bool   get _isInsufficient =>
      widget.availableMargin > 0 && _marginRequired > widget.availableMargin;

  String get _resolvedOrderType {
    if (_stopLossOn) {
      return _baseOrderType == 'MARKET' ? 'STOPLOSS_MARKET' : 'STOPLOSS_LIMIT';
    }
    return _baseOrderType;
  }

  String get _resolvedVariety {
    if (_isFnO) return 'NORMAL'; // F&O always NORMAL
    if (_roboOn)    return 'ROBO';
    if (_coverOn)   return 'STOPLOSS';
    if (_stopLossOn) return 'STOPLOSS';
    return 'NORMAL';
  }

  // The product type string actually sent in the API call
  String get _resolvedProductType {
    if (_isFnO) return _fnoProductType; // NRML or MIS
    return _productType == 'PAY_LATER' ? 'MARGIN' : _productType;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.side.toUpperCase() == 'SELL' ? 1 : 0,
    );
    _tabController.addListener(() => setState(() {}));

    if (widget.ltpData != null) {
      _priceCtrl.text = widget.ltpData!.ltp.toStringAsFixed(2);
      _prefillGtt(widget.ltpData!.ltp);
    }
    _qtyCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(OrderPanelWidget old) {
    super.didUpdateWidget(old);
    if (widget.ltpData != null && old.ltpData != widget.ltpData) {
      _priceCtrl.text = widget.ltpData!.ltp.toStringAsFixed(2);
      _prefillGtt(widget.ltpData!.ltp);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _slCtrl.dispose();
    _tgtCtrl.dispose();
    _gttTrigCtrl.dispose();
    _gttLimCtrl.dispose();
    _trailCtrl.dispose();
    super.dispose();
  }

  void _prefillGtt(double ltp) {
    final t = ltp * 0.90;
    _gttTrigCtrl.text = t.toStringAsFixed(2);
    _gttLimCtrl.text  = (t + 0.05).toStringAsFixed(2);
  }

  void _submit(String side) {
    if (_qty <= 0 || widget.scrip == null) return;
    _showOrderConfirmation(context, side);
  }

  void _confirmAndDispatch(String side) {
    final safeSymbol = widget.scrip!.tradingSymbol.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final idempotencyKey = 'UI-${DateTime.now().millisecondsSinceEpoch}-$safeSymbol-$_qty';

    context.read<IndividualExecutionBloc>().add(
      PlaceOrderRequested(
        accId:          widget.accId,
        scrip:          widget.scrip!,
        quantity:       _qty,                      // ← lots × lotSize for F&O
        orderType:      _resolvedOrderType,
        productType:    _resolvedProductType,      // ← NRML/MIS for F&O
        variety:        _resolvedVariety,
        price:          (_baseOrderType == 'MARKET') ? 0 : _price,
        side:           side,
        ctx:            context,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  void _showOrderConfirmation(BuildContext context, String side) {
    final isBuy = side == 'BUY';
    final accentClr = isBuy ? _gain : _loss;
    final symbol = widget.scrip?.tradingSymbol ?? '';
    final estPrice = _baseOrderType == 'MARKET' ? (widget.ltpData?.ltp ?? 0.0) : _price;
    final totalVal = _qty * estPrice;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isBuy ? _gainBg : _lossBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                side,
                style: TextStyle(
                  color: accentClr,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Order Preview & Confirmation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simulation banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.shield_outlined, size: 18, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PAPER TRADING (SIMULATION)\nVirtual order — Zero financial risk',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Order details summary
            _confirmRow('Instrument', symbol),
            _confirmRow('Quantity', '$_qty ${_isFnO ? "shares (${_lotsOrShares} lots)" : "shares"}'),
            _confirmRow('Order Type', _resolvedOrderType),
            _confirmRow('Product', _resolvedProductType),
            _confirmRow('Execution Price', _baseOrderType == 'MARKET' ? 'Market (LTP ₹${estPrice.toStringAsFixed(2)})' : '₹${estPrice.toStringAsFixed(2)}'),
            const Divider(height: 20),
            _confirmRow('Estimated Value', '₹ ${totalVal.toStringAsFixed(2)}', isBold: true),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _confirmAndDispatch(side);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentClr,
              foregroundColor: Colors.white,
            ),
            child: Text('Confirm $side Order'),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? const Color(0xFF111827) : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.scrip == null;
    final isBuy      = _tabController.index == 0;
    final side       = isBuy ? 'BUY' : 'SELL';
    final accentClr  = isBuy ? _gain : _loss;

    return BlocListener<IndividualExecutionBloc, IndividualExecutionState>(
      listener: (context, state) {
        if (state is OrderPlacing)
          setState(() => _isPlacing = true);
        else if (state is OrderPlaced || state is OrderPlacementFailure) {
          setState(() => _isPlacing = false);
          Navigator.of(context).pop();
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Paper Trading simulation banner ─────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.shield_outlined, size: 13, color: Color(0xFFB45309)),
                  SizedBox(width: 5),
                  Text(
                    'Paper Trading Mode (Simulated Execution — Zero Risk)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),

            // ── F&O info banner (shown only for derivatives) ───────────────
            if (_isFnO) _fnoBanner(),

            // ── Product tabs: EQ gets 3 tabs, F&O gets NRML/MIS ───────────
            _isFnO ? _fnoProductTabs() : _eqProductTabs(),

            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: [
                    _mainCard(isBuy, accentClr),
                    const SizedBox(height: 8),
                    // Toggles: hide cover/robo/GTT for F&O
                    _togglesCard(),
                    const SizedBox(height: 8),
                    _validityRow(),
                    const SizedBox(height: 8),
                    _marginSection(accentClr, side, isDisabled),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── F&O banner ─────────────────────────────────────────────────────────────
  Widget _fnoBanner() {
    final s       = widget.scrip!;
    final isFut   = s.typeLabel == 'FUT';
    final fg      = isFut ? _futFg : _optFg;
    final bg      = isFut ? _futBg : _optBg;
    final bd      = isFut ? _futBd : _optBd;
    final icon    = isFut
        ? Icons.candlestick_chart_rounded
        : Icons.receipt_long_rounded;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 8),
          // Instrument type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: bd),
            ),
            child: Text(
              s.typeLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.tradingSymbol,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Lot size info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: bd),
            ),
            child: Text(
              'Lot size: $_lotSize',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── EQ product tabs (unchanged) ────────────────────────────────────────────
  Widget _eqProductTabs() {
    final items = [
      ('DELIVERY',  'Delivery',  null),
      ('INTRADAY',  'Intraday',  '5x'),
      ('PAY_LATER', 'Pay Later', '3.8x'),
    ];
    return Container(
      color: _surface,
      child: Row(
        children: items.map((e) {
          final active = _productType == e.$1;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() {
                _productType = e.$1;
                if (e.$1 != 'INTRADAY') { _coverOn = false; _roboOn = false; }
                if (e.$1 == 'INTRADAY') _gttOn = false;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? _accent : _divider,
                      width: active ? 2 : 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: active ? _accent : _inkLight,
                      ),
                    ),
                    if (e.$3 != null)
                      Text(
                        e.$3!,
                        style: const TextStyle(
                          fontSize: 9,
                          color: _gain,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── F&O product tabs: NRML / MIS ──────────────────────────────────────────
  Widget _fnoProductTabs() {
    final items = [
      ('NRML', 'NRML', 'CARRYFORWARD'),
      ('MIS',  'MIS',  'Intraday'),
    ];
    return Container(
      color: _surface,
      child: Row(
        children: items.map((e) {
          final active = _fnoProductType == e.$1;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _fnoProductType = e.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? _accent : _divider,
                      width: active ? 2 : 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: active ? _accent : _inkLight,
                      ),
                    ),
                    Text(
                      e.$3,
                      style: TextStyle(
                        fontSize: 9,
                        color: active ? _accent : _inkLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Main card ──────────────────────────────────────────────────────────────
  Widget _mainCard(bool isBuy, Color accentClr) => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _divider),
    ),
    child: Column(
      children: [
        Row(
          children: [
            _bsTab('BUY',  0, _gain, _gainBg),
            _bsTab('SELL', 1, _loss, _lossBg),
          ],
        ),
        const Divider(height: 1, color: _divider),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _fieldsRow(),
              const SizedBox(height: 8),
              _estValueRow(),
              const SizedBox(height: 6),
              _orderTypeBadge(),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _orderTypeBadge() {
    final resolved = _resolvedOrderType;
    Color badgeColor;
    switch (resolved) {
      case 'STOPLOSS_LIMIT':
      case 'STOPLOSS_MARKET':
        badgeColor = const Color(0xFFD97706);
        break;
      case 'MARKET':
        badgeColor = _accent;
        break;
      default:
        badgeColor = _inkLight;
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: badgeColor.withOpacity(0.30)),
        ),
        child: Text(
          'Order Type: $resolved',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: badgeColor,
          ),
        ),
      ),
    );
  }

  Widget _bsTab(String label, int idx, Color color, Color bg) {
    final active = _tabController.index == idx;
    return Expanded(
      child: InkWell(
        onTap: () => _tabController.animateTo(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? bg : _surface,
            borderRadius: BorderRadius.only(
              topLeft:  Radius.circular(idx == 0 ? 12 : 0),
              topRight: Radius.circular(idx == 1 ? 12 : 0),
            ),
            border: active
                ? Border(bottom: BorderSide(color: color, width: 2))
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? color : _inkLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Fields row ─────────────────────────────────────────────────────────────
  Widget _fieldsRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label: "Qty" for EQ, "Lots" for F&O
            Row(
              children: [
                Text(
                  _isFnO ? 'Lots' : 'Qty',
                  style: const TextStyle(
                    fontSize: 10,
                    color: _inkLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_isFnO && _lotsOrShares > 0) ...[
                  const Spacer(),
                  Text(
                    '= ${_qty} qty',
                    style: const TextStyle(
                      fontSize: 9,
                      color: _inkLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            _stepField(
              _qtyCtrl,
              isInt: true,
              onDec: () {
                final v = _lotsOrShares;
                if (v > 1) _qtyCtrl.text = '${v - 1}';
              },
              onInc: () => _qtyCtrl.text = '${_lotsOrShares + 1}',
            ),
            // F&O: "1 lot = N qty" hint
            if (_isFnO)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '1 lot = $_lotSize qty',
                  style: const TextStyle(
                    fontSize: 9,
                    color: _inkLight,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Price',
                  style: TextStyle(
                    fontSize: 10,
                    color: _inkLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _pill(
                  'LIMIT',
                  _baseOrderType == 'LIMIT',
                      () => setState(() => _baseOrderType = 'LIMIT'),
                ),
                const SizedBox(width: 4),
                _pill(
                  'MKT',
                  _baseOrderType == 'MARKET',
                      () => setState(() => _baseOrderType = 'MARKET'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _baseOrderType == 'MARKET'
                ? Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _divider),
              ),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'At Market',
                  style: TextStyle(
                    fontSize: 11,
                    color: _inkLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
                : _stepField(
              _priceCtrl,
              isInt: false,
              onDec: () {
                final v = double.tryParse(_priceCtrl.text) ?? 0;
                if (v >= 0.05)
                  _priceCtrl.text = (v - 0.05).toStringAsFixed(2);
              },
              onInc: () {
                final v = double.tryParse(_priceCtrl.text) ?? 0;
                _priceCtrl.text = (v + 0.05).toStringAsFixed(2);
              },
            ),
          ],
        ),
      ),
    ],
  );

  Widget _stepField(
      TextEditingController ctrl, {
        required bool isInt,
        required VoidCallback onDec,
        required VoidCallback onInc,
      }) =>
      SizedBox(
        height: 38,
        child: Row(
          children: [
            _stepBtn(Icons.remove_rounded, onDec),
            const SizedBox(width: 3),
            Expanded(
              child: TextField(
                controller: ctrl,
                textAlign: TextAlign.center,
                keyboardType: isInt
                    ? TextInputType.number
                    : const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: isInt
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d*'))
                ],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                    const BorderSide(color: _accent, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            _stepBtn(Icons.add_rounded, onInc),
          ],
        ),
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      width: 30, height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _divider),
      ),
      child: Icon(icon, size: 15, color: _inkMid),
    ),
  );

  Widget _pill(String label, bool active, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: active ? _accent : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : _inkLight,
        ),
      ),
    ),
  );

  Widget _estValueRow() {
    final total = _marginRequired;
    if (total <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Est. Value',
            style: TextStyle(fontSize: 10, color: _inkLight),
          ),
          // For F&O show breakdown: lots × lotSize × price
          if (_isFnO && _lotsOrShares > 0)
            Text(
              '$_lotsOrShares lot${_lotsOrShares > 1 ? 's' : ''} × $_lotSize × ₹${_price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 9, color: _inkLight),
            ),
          Text(
            '₹${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  // ── Toggles card ────────────────────────────────────────────────────────────
  // For F&O: only Stop Loss toggle is shown; cover/robo/GTT are hidden
  Widget _togglesCard() {
    final isIntraday = !_isFnO && _productType == 'INTRADAY';
    final noneOn     = !_stopLossOn && !_coverOn && !_roboOn && !_gttOn;

    final showStopLoss = noneOn || _stopLossOn;
    // Cover / Robo / GTT are EQ-only features
    final showCover = !_isFnO && isIntraday && (noneOn || _coverOn);
    final showRobo  = !_isFnO && isIntraday && (noneOn || _roboOn);
    final showGtt   = !_isFnO && !isIntraday && (noneOn || _gttOn);

    final List<Widget> rows = [];

    if (showStopLoss) {
      if (rows.isNotEmpty) rows.add(_hr());
      rows.add(_toggleRow(
        label: 'Stop Loss Order',
        value: _stopLossOn,
        enabled: true,
        onChanged: (v) => setState(() {
          _stopLossOn = v;
          if (v) { _roboOn = false; _coverOn = false; _gttOn = false; }
        }),
        infoText:
        'Limits loss by triggering a sell/buy at your set price.\n'
            '• LIMIT price → STOPLOSS_LIMIT\n'
            '• MARKET price → STOPLOSS_MARKET\n'
            'Execution not guaranteed in fast markets.',
      ));
      if (_stopLossOn) {
        rows.add(_hr());
        rows.add(_slBody());
      }
    }

    if (showCover) {
      if (rows.isNotEmpty) rows.add(_hr());
      rows.add(_toggleRow(
        label: 'Cover Order',
        value: _coverOn,
        enabled: true,
        onChanged: (v) => setState(() {
          _coverOn = v;
          if (v) { _stopLossOn = false; _roboOn = false; _gttOn = false; }
        }),
        infoText:
        'Intraday order paired with a compulsory Stop Loss.\n'
            'Higher leverage because risk is capped.\n'
            'Variety sent: STOPLOSS',
      ));
    }

    if (showRobo) {
      if (rows.isNotEmpty) rows.add(_hr());
      rows.add(_toggleRow(
        label: 'Robo Order',
        value: _roboOn,
        enabled: true,
        onChanged: (v) => setState(() {
          _roboOn = v;
          if (v) { _stopLossOn = false; _coverOn = false; _gttOn = false; }
        }),
        infoText:
        'Automates trade with preset SL & Target.\n'
            'Exits automatically when SL or Target is hit.\n'
            'Trailing SL available. Variety sent: ROBO',
      ));
      if (_roboOn) {
        rows.add(_hr());
        rows.add(_roboBody());
      }
    }

    if (showGtt) {
      if (rows.isNotEmpty) rows.add(_hr());
      rows.add(_toggleRow(
        label: 'Create GTT',
        value: _gttOn,
        enabled: true,
        onChanged: (v) => setState(() {
          _gttOn = v;
          if (v) { _stopLossOn = false; _coverOn = false; _roboOn = false; }
        }),
        infoText:
        'Places a limit order automatically when LTP hits your trigger.\n'
            'Useful for long-term entry/exit.\n'
            'Not available for Intraday. OCO leg also supported.',
      ));
      if (_gttOn) {
        rows.add(_hr());
        rows.add(_gttBody());
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider),
      ),
      child: Column(children: rows),
    );
  }

  Widget _hr() => const Divider(height: 1, color: _divider);

  Widget _toggleRow({
    required String label,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    required String infoText,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? _inkMid : _inkLight,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: infoText,
              preferBelow: true,
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                height: 1.5,
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: _accent,
              ),
            ),
            const Spacer(),
            _switch(value, enabled ? () => onChanged(!value) : null),
          ],
        ),
      );

  Widget _switch(bool value, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40, height: 22,
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFFE2E8F0)
              : value
              ? _gain
              : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
          value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18, height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // ── Stop Loss body (unchanged) ─────────────────────────────────────────────
  Widget _slBody() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _baseOrderType == 'MARKET'
              ? 'Trigger Price  (order type → STOPLOSS_MARKET)'
              : 'Trigger Price  (order type → STOPLOSS_LIMIT)',
          style: const TextStyle(fontSize: 10, color: _inkLight),
        ),
        const SizedBox(height: 5),
        _stepField(
          _slCtrl,
          isInt: false,
          onDec: () {
            final v = double.tryParse(_slCtrl.text) ?? 0;
            if (v >= 0.05) {
              _slCtrl.text = (v - 0.05).toStringAsFixed(2);
              setState(() {});
            }
          },
          onInc: () {
            final v = double.tryParse(_slCtrl.text) ?? 0;
            _slCtrl.text = (v + 0.05).toStringAsFixed(2);
            setState(() {});
          },
        ),
        const SizedBox(height: 7),
        Row(
          children: ['2.5', '5', '10', '15']
              .map((p) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                final ltp = widget.ltpData?.ltp ?? 0;
                _slCtrl.text = (ltp *
                    (1 - double.parse(p) / 100))
                    .toStringAsFixed(2);
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _divider),
                ),
                child: Text(
                  '-$p%',
                  style: const TextStyle(
                    fontSize: 10,
                    color: _inkMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ))
              .toList(),
        ),
        const SizedBox(height: 7),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: const [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 11, color: Color(0xFFD97706)),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'SL execution depends on market depth & volatility',
                  style:
                  TextStyle(fontSize: 10, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Robo body (unchanged) ──────────────────────────────────────────────────
  Widget _roboBody() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: _miniLabelField('Stop Loss Price', _slCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _miniLabelField('Target Price', _tgtCtrl)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Trailing SL Jump Price',
              style: TextStyle(
                  fontSize: 12,
                  color: _inkMid,
                  fontWeight: FontWeight.w600),
            ),
            InkWell(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _divider),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Trailing SL Jump Price',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _ink)),
                        const SizedBox(height: 12),
                        _miniLabelField('Jump Price', _trailCtrl),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Done',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  border: Border.all(color: _accent),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 14, color: _accent),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _miniLabelField(
      String label, TextEditingController ctrl) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
              const TextStyle(fontSize: 10, color: _inkLight)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d*'))
            ],
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: _divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: _divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide:
                const BorderSide(color: _accent, width: 1.4),
              ),
            ),
          ),
        ],
      );

  // ── GTT body (unchanged) ───────────────────────────────────────────────────
  Widget _gttBody() {
    final ltp     = widget.ltpData?.ltp ?? 0.0;
    final trigger = double.tryParse(_gttTrigCtrl.text) ?? 0;
    final pct     = ltp > 0 ? ((trigger - ltp) / ltp * 100) : 0.0;
    final pctStr  = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
    final pctClr  = pct >= 0 ? _gain : _loss;
    final pctBg   = pct >= 0 ? _gainBg : _lossBg;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Target Trigger Price',
                        style: TextStyle(
                            fontSize: 10, color: _inkLight)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _gttTrigCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'))
                            ],
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _ink),
                            decoration: _thinDecor(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: pctBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(pctStr,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: pctClr)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Limit Price',
                        style: TextStyle(
                            fontSize: 10, color: _inkLight)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _gttLimCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'))
                      ],
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ink),
                      decoration: _thinDecor(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('OCO Order',
                  style: TextStyle(
                      fontSize: 12,
                      color: _inkMid,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Tooltip(
                message:
                'Set two conditions simultaneously:\n'
                    '1. Target price (fires when price goes up)\n'
                    '2. Stop-loss price (fires when price falls)\n'
                    'Whichever triggers first cancels the other.',
                preferBelow: true,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                    fontSize: 11, color: Colors.white, height: 1.5),
                child: const Icon(Icons.info_outline_rounded,
                    size: 14, color: _accent),
              ),
              const Spacer(),
              InkWell(
                onTap: () {},
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(color: _accent),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 13, color: _accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _thinDecor() => InputDecoration(
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: _divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: _divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: _accent, width: 1.4),
    ),
  );

  // ── Validity row (unchanged) ───────────────────────────────────────────────
  Widget _validityRow() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _divider),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Validity',
                  style: TextStyle(fontSize: 10, color: _inkLight)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _divider),
                ),
                child: Row(
                  children: const [
                    Text('Day',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _ink)),
                    Spacer(),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 15, color: _inkLight),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Disclosed Qty',
                  style: TextStyle(fontSize: 10, color: _inkLight)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _divider),
                ),
                child: const Text('0',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Margin section ─────────────────────────────────────────────────────────
  Widget _marginSection(
      Color accentClr, String side, bool isDisabled) {
    final req    = _marginRequired;
    final avail  = widget.availableMargin;
    final isGtt  = _gttOn && !_isFnO;
    final btnLabel = isGtt
        ? 'CREATE GTT'
        : (isDisabled
        ? 'Select a stock first'
        : 'PLACE $side ORDER');
    final isInactive = isDisabled || _isPlacing;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Margin Required (Approx)',
                      style: TextStyle(
                          fontSize: 10, color: _inkLight)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        req > 0
                            ? '₹${req.toStringAsFixed(2)}'
                            : '₹0.00',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink),
                      ),
                      if (req > 0) ...[
                        const Text(' + ',
                            style: TextStyle(
                                fontSize: 11, color: _inkLight)),
                        const Text('Charges',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _accent)),
                      ],
                    ],
                  ),
                  // F&O: show lot breakdown under margin
                  if (_isFnO && _lotsOrShares > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '$_lotsOrShares lot${_lotsOrShares > 1 ? 's' : ''} · $_qty qty · $_resolvedProductType',
                        style: const TextStyle(
                            fontSize: 9, color: _inkLight),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Available Margin',
                      style: TextStyle(
                          fontSize: 10, color: _inkLight)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${avail.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink),
                  ),
                ],
              ),
            ],
          ),

          if (_isInsufficient && req > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _lossBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 12, color: _loss),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _isFnO
                          ? 'Insufficient margin. Need ₹${(req - avail).toStringAsFixed(2)} more for $_lotsOrShares lot${_lotsOrShares > 1 ? 's' : ''} ($_qty qty).'
                          : 'Order may be rejected due to insufficient margin. '
                          'To buy $_qty share${_qty > 1 ? 's' : ''}, please add ₹${(req - avail).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 10, color: _loss),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: isInactive ? null : () => _submit(side),
              style: ElevatedButton.styleFrom(
                backgroundColor: isInactive
                    ? accentClr.withOpacity(0.4)
                    : accentClr,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isPlacing
                  ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
                  : Text(
                btnLabel,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}