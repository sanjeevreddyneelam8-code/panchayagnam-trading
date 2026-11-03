import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../service/copy_trading_engine.dart';
import '../../../reusable_widets/copy_trade_receipt_dialog.dart';

/// Represents strike-level data in the Option Chain
class OptionStrikeData {
  final double strike;
  final bool isAtm;

  // Call option side (CE)
  final double callLtp;
  final double callChange;
  final double callChangePercent;
  final double callOi; // in Lakhs
  final double callOiChange; // in Lakhs
  final double callIv;
  final double callDelta;
  final int callVolume;

  // Put option side (PE)
  final double putLtp;
  final double putChange;
  final double putChangePercent;
  final double putOi; // in Lakhs
  final double putOiChange; // in Lakhs
  final double putIv;
  final double putDelta;
  final int putVolume;

  const OptionStrikeData({
    required this.strike,
    this.isAtm = false,
    required this.callLtp,
    required this.callChange,
    required this.callChangePercent,
    required this.callOi,
    required this.callOiChange,
    required this.callIv,
    required this.callDelta,
    required this.callVolume,
    required this.putLtp,
    required this.putChange,
    required this.putChangePercent,
    required this.putOi,
    required this.putOiChange,
    required this.putIv,
    required this.putDelta,
    required this.putVolume,
  });

  OptionStrikeData copyWith({
    double? strike,
    bool? isAtm,
    double? callLtp,
    double? callChange,
    double? callChangePercent,
    double? callOi,
    double? callOiChange,
    double? callIv,
    double? callDelta,
    int? callVolume,
    double? putLtp,
    double? putChange,
    double? putChangePercent,
    double? putOi,
    double? putOiChange,
    double? putIv,
    double? putDelta,
    int? putVolume,
  }) {
    return OptionStrikeData(
      strike: strike ?? this.strike,
      isAtm: isAtm ?? this.isAtm,
      callLtp: callLtp ?? this.callLtp,
      callChange: callChange ?? this.callChange,
      callChangePercent: callChangePercent ?? this.callChangePercent,
      callOi: callOi ?? this.callOi,
      callOiChange: callOiChange ?? this.callOiChange,
      callIv: callIv ?? this.callIv,
      callDelta: callDelta ?? this.callDelta,
      callVolume: callVolume ?? this.callVolume,
      putLtp: putLtp ?? this.putLtp,
      putChange: putChange ?? this.putChange,
      putChangePercent: putChangePercent ?? this.putChangePercent,
      putOi: putOi ?? this.putOi,
      putOiChange: putOiChange ?? this.putOiChange,
      putIv: putIv ?? this.putIv,
      putDelta: putDelta ?? this.putDelta,
      putVolume: putVolume ?? this.putVolume,
    );
  }
}

class OptionsChainView extends StatefulWidget {
  final int initialTabIndex;
  const OptionsChainView({super.key, this.initialTabIndex = 0});

  @override
  State<OptionsChainView> createState() => _OptionsChainViewState();
}

class _OptionsChainViewState extends State<OptionsChainView> {
  String _underlying = 'NIFTY';
  String _expiry = '07-NOV-2026 (Weekly)';
  late int _activeSubTab; // 0: Chain, 1: Multi-Strike OI, 2: Strategy Builder

  final List<String> _indices = ['NIFTY', 'BANKNIFTY', 'FINNIFTY', 'MIDCPNIFTY', 'SENSEX'];

  final Map<String, List<String>> _expiriesPerIndex = {
    'NIFTY': [
      '07-NOV-2026 (Weekly)',
      '14-NOV-2026 (Next Weekly)',
      '28-NOV-2026 (Monthly Expiry)',
      '31-DEC-2026 (Quarterly)',
    ],
    'BANKNIFTY': [
      '07-NOV-2026 (Weekly)',
      '14-NOV-2026 (Next Weekly)',
      '28-NOV-2026 (Monthly Expiry)',
      '31-DEC-2026 (Quarterly)',
    ],
    'FINNIFTY': [
      '05-NOV-2026 (Weekly)',
      '12-NOV-2026 (Next Weekly)',
      '26-NOV-2026 (Monthly Expiry)',
    ],
    'MIDCPNIFTY': [
      '04-NOV-2026 (Weekly)',
      '11-NOV-2026 (Next Weekly)',
      '25-NOV-2026 (Monthly Expiry)',
    ],
    'SENSEX': [
      '08-NOV-2026 (Weekly)',
      '15-NOV-2026 (Next Weekly)',
      '29-NOV-2026 (Monthly Expiry)',
    ],
  };

  static final Map<String, double> _spotPrices = {
    'NIFTY': 24150.50,
    'BANKNIFTY': 51820.00,
    'FINNIFTY': 23410.00,
    'MIDCPNIFTY': 13050.80,
    'SENSEX': 79402.20,
  };

  static final Map<String, double> _strikeSteps = {
    'NIFTY': 50.0,
    'BANKNIFTY': 100.0,
    'FINNIFTY': 50.0,
    'MIDCPNIFTY': 25.0,
    'SENSEX': 100.0,
  };

  static final Map<String, int> _lotSizes = {
    'NIFTY': 25,
    'BANKNIFTY': 15,
    'FINNIFTY': 25,
    'MIDCPNIFTY': 50,
    'SENSEX': 10,
  };

  List<OptionStrikeData> _strikesData = [];
  Timer? _liveTicker;
  double _spotPrice = 24150.50;
  double _spotChange = 108.20;
  double _spotChangePct = 0.45;
  double _pcr = 1.08;
  double _maxPain = 24200.0;
  double _vix = 14.22;
  int _tradeLots = 1;

  @override
  void initState() {
    super.initState();
    _activeSubTab = widget.initialTabIndex;
    _expiry = _expiriesPerIndex[_underlying]!.first;
    _spotPrice = _spotPrices[_underlying]!;
    _generateFullOptionChain();
    _startLivePriceTicker();
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    super.dispose();
  }

  void _startLivePriceTicker() {
    _liveTicker?.cancel();
    _liveTicker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _strikesData.isEmpty) return;
      final rand = math.Random();
      final baseSpot = _spotPrices[_underlying] ?? 24000.0;
      final delta = (rand.nextDouble() - 0.48) * (baseSpot * 0.0004);

      setState(() {
        _spotPrice = double.parse((_spotPrice + delta).toStringAsFixed(2));
        _spotChange = _spotPrice - baseSpot;
        _spotChangePct = (_spotChange / baseSpot) * 100;

        for (int i = 0; i < _strikesData.length; i++) {
          final s = _strikesData[i];
          final callDeltaTick = (rand.nextDouble() - 0.49) * 0.4;
          final putDeltaTick = (rand.nextDouble() - 0.49) * 0.4;

          final newCallLtp = math.max(0.50, double.parse((s.callLtp + callDeltaTick).toStringAsFixed(2)));
          final newPutLtp = math.max(0.50, double.parse((s.putLtp + putDeltaTick).toStringAsFixed(2)));

          _strikesData[i] = s.copyWith(
            callLtp: newCallLtp,
            putLtp: newPutLtp,
          );
        }
      });
    });
  }

  void _generateFullOptionChain() {
    final double step = _strikeSteps[_underlying] ?? 50.0;
    final double baseSpot = _spotPrices[_underlying] ?? 24000.0;
    final double atm = (baseSpot / step).round() * step;
    _maxPain = atm;

    final List<OptionStrikeData> list = [];
    final rand = math.Random(_underlying.hashCode + _expiry.hashCode);

    // Generate 19 strikes (9 below ATM, 1 ATM, 9 above ATM)
    for (int i = -9; i <= 9; i++) {
      final double strike = atm + (i * step);
      final bool isAtm = (i == 0);

      // Black-Scholes realistic approximation for Indian options
      final double distance = strike - baseSpot;
      final double moneyness = distance / baseSpot;

      // Call side
      double callIntrinsic = math.max(0.0, baseSpot - strike);
      double callExtrinsic = math.max(1.5, (baseSpot * 0.009) * math.exp(-math.pow(moneyness * 8.0, 2)));
      double callLtp = double.parse((callIntrinsic + callExtrinsic).toStringAsFixed(2));
      double callChg = double.parse(((rand.nextDouble() * 25.0) - 10.0).toStringAsFixed(2));
      double callOi = double.parse((20.0 + (rand.nextDouble() * 75.0)).toStringAsFixed(1));
      double callOiChg = double.parse(((rand.nextDouble() * 12.0) - 4.0).toStringAsFixed(1));
      double callDelta = double.parse((1.0 / (1.0 + math.exp(moneyness * 12.0))).toStringAsFixed(2));
      double callIv = double.parse((13.2 + (rand.nextDouble() * 2.5)).toStringAsFixed(1));
      int callVol = 150000 + rand.nextInt(850000);

      // Put side
      double putIntrinsic = math.max(0.0, strike - baseSpot);
      double putExtrinsic = math.max(1.5, (baseSpot * 0.009) * math.exp(-math.pow(moneyness * 8.0, 2)));
      double putLtp = double.parse((putIntrinsic + putExtrinsic).toStringAsFixed(2));
      double putChg = double.parse(((rand.nextDouble() * 25.0) - 14.0).toStringAsFixed(2));
      double putOi = double.parse((20.0 + (rand.nextDouble() * 75.0)).toStringAsFixed(1));
      double putOiChg = double.parse(((rand.nextDouble() * 12.0) - 5.0).toStringAsFixed(1));
      double putDelta = double.parse((-1.0 + callDelta).toStringAsFixed(2));
      double putIv = double.parse((13.4 + (rand.nextDouble() * 2.5)).toStringAsFixed(1));
      int putVol = 150000 + rand.nextInt(850000);

      list.add(OptionStrikeData(
        strike: strike,
        isAtm: isAtm,
        callLtp: callLtp,
        callChange: callChg,
        callChangePercent: callChg,
        callOi: callOi,
        callOiChange: callOiChg,
        callIv: callIv,
        callDelta: callDelta,
        callVolume: callVol,
        putLtp: putLtp,
        putChange: putChg,
        putChangePercent: putChg,
        putOi: putOi,
        putOiChange: putOiChg,
        putIv: putIv,
        putDelta: putDelta,
        putVolume: putVol,
      ));
    }

    _strikesData = list;
    double totalCallOi = list.fold(0.0, (acc, s) => acc + s.callOi);
    double totalPutOi = list.fold(0.0, (acc, s) => acc + s.putOi);
    _pcr = totalCallOi > 0 ? double.parse((totalPutOi / totalCallOi).toStringAsFixed(2)) : 1.05;
  }

  void _switchUnderlying(String sym) {
    if (sym == _underlying) return;
    setState(() {
      _underlying = sym;
      _expiry = _expiriesPerIndex[_underlying]!.first;
      _spotPrice = _spotPrices[_underlying]!;
      _generateFullOptionChain();
    });
  }

  void _executeOptionOrder({
    required String side,
    required String optType,
    required double strike,
    required double premium,
  }) async {
    final lotSize = _lotSizes[_underlying] ?? 25;
    final totalQty = lotSize * _tradeLots;
    final symbol = '$_underlying ${strike.toInt()} $optType';

    final engine = CopyTradingEngine();
    final receipt = await engine.replicateTrade(
      symbol: symbol,
      side: side,
      baseQty: totalQty,
      price: premium,
      orderType: 'MARKET',
      productType: 'OPTIONS (NRML)',
      lotSize: lotSize,
    );

    if (mounted) {
      CopyTradeReceiptDialog.show(context, receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPos = _spotChange >= 0;
    final spotColor = isPos ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final lotSize = _lotSizes[_underlying] ?? 25;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header Row ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Panchayagnam Options Chain (F&O)',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE GREEKS & OI STREAM',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NSE/BSE derivatives contract chain, live implied volatility (IV), Greeks, PCR analysis, and 1-click execution.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),

                // Sub-Tabs: Option Chain / Multi-Strike OI / Strategy Builder
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      _buildSubTabButton(0, 'Option Chain (F&O)', Icons.table_chart_rounded),
                      _buildSubTabButton(1, 'Multi-Strike OI & Greeks', Icons.auto_graph_rounded),
                      _buildSubTabButton(2, 'Strategy Builder', Icons.psychology_alt_rounded),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Live F&O KPI Metrics Strip ───────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  // Spot Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_underlying SPOT', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '₹${_spotPrice.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: spotColor),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${isPos ? '+' : ''}${_spotChange.toStringAsFixed(2)} (${isPos ? '+' : ''}${_spotChangePct.toStringAsFixed(2)}%)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: spotColor),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(width: 24),
                  Container(height: 32, width: 1, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 24),

                  // PCR
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PUT-CALL RATIO (PCR)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('$_pcr', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _pcr >= 1.0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _pcr >= 1.0 ? 'Bullish Sentiment' : 'Bearish Sentiment',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: _pcr >= 1.0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(width: 24),
                  Container(height: 32, width: 1, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 24),

                  // Max Pain
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MAX PAIN STRIKE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text('₹${_maxPain.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                    ],
                  ),

                  const SizedBox(width: 24),
                  Container(height: 32, width: 1, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 24),

                  // India VIX
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('INDIA VIX (VOLATILITY)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text('$_vix', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    ],
                  ),

                  const Spacer(),

                  // Lots Stepper
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Text('Lots: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        IconButton(
                          icon: const Icon(Icons.remove, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: _tradeLots > 1 ? () => setState(() => _tradeLots--) : null,
                        ),
                        Text('$_tradeLots (${_tradeLots * lotSize} Qty)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() => _tradeLots++),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Controls Bar: Index Selector & Expiry Dropdown ───────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Text('Underlying: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(width: 8),

                  // Index Chips
                  Row(
                    children: _indices.map((sym) {
                      final isSelected = sym == _underlying;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(sym, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
                          selected: isSelected,
                          onSelected: (_) => _switchUnderlying(sym),
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF334155)),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),

                  const Spacer(),

                  const Text('Expiry: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _expiry,
                        items: (_expiriesPerIndex[_underlying] ?? []).map((exp) {
                          return DropdownMenuItem<String>(
                            value: exp,
                            child: Text(exp, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _expiry = val;
                              _generateFullOptionChain();
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF475569)),
                    tooltip: 'Refresh Chain Data',
                    onPressed: () {
                      setState(() => _generateFullOptionChain());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Option Chain refreshed with live ticks'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Main Body: Option Chain vs OI vs Strategy Builder ─────────
            if (_activeSubTab == 0)
              _buildOptionChainTable()
            else if (_activeSubTab == 1)
              _buildMultiStrikeOiView()
            else
              _buildStrategyBuilderView(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabButton(int idx, String title, IconData icon) {
    final isSelected = _activeSubTab == idx;
    return InkWell(
      onTap: () => setState(() => _activeSubTab = idx),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. Full Option Chain Table ───────────────────────────────────────────────
  Widget _buildOptionChainTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Dual Header Banner (Calls CE vs Strike vs Puts PE)
          Row(
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                  ),
                  child: const Center(
                    child: Text(
                      'CALL OPTIONS (CE)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF166534), letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: Text(
                      'STRIKE',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
                  ),
                  child: const Center(
                    child: Text(
                      'PUT OPTIONS (PE)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF991B1B), letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Sub-Column Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              children: [
                // Calls columns
                Expanded(flex: 2, child: Text('OI (Lakh)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('CHG %', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('IV / DELTA', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 3, child: Text('LTP (₹)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('ACTIONS', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),

                // Strike
                Expanded(flex: 3, child: Text('STRIKE PRICE', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),

                // Puts columns
                Expanded(flex: 2, child: Text('ACTIONS', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 3, child: Text('LTP (₹)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('IV / DELTA', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('CHG %', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('OI (Lakh)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
              ],
            ),
          ),

          // All 19 Strike Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _strikesData.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (ctx, i) {
              final s = _strikesData[i];
              final isCallItm = s.strike < _spotPrice;
              final isPutItm = s.strike > _spotPrice;
              final isAtm = s.isAtm;

              final callChgColor = s.callChange >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
              final putChgColor = s.putChange >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: isAtm
                    ? const Color(0xFFFEF3C7).withOpacity(0.5)
                    : Colors.white,
                child: Row(
                  children: [
                    // 1. Call OI
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: isCallItm ? const EdgeInsets.symmetric(vertical: 4) : EdgeInsets.zero,
                        color: isCallItm ? const Color(0xFFF0FDF4) : Colors.transparent,
                        child: Text(
                          '${s.callOi}L',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ),

                    // 2. Call Change %
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${s.callChange >= 0 ? '+' : ''}${s.callChangePercent.toStringAsFixed(1)}%',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: callChgColor),
                      ),
                    ),

                    // 3. Call IV / Delta
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${s.callIv}%', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text('Δ ${s.callDelta}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ],
                      ),
                    ),

                    // 4. Call LTP
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isCallItm ? const Color(0xFFDCFCE7).withOpacity(0.6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '₹${s.callLtp.toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF166534)),
                        ),
                      ),
                    ),

                    // 5. Call Quick Trade Buttons [ B ] [ S ]
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildQuickActionButton('B', const Color(0xFF059669), () {
                            _executeOptionOrder(side: 'BUY', optType: 'CE', strike: s.strike, premium: s.callLtp);
                          }),
                          const SizedBox(width: 4),
                          _buildQuickActionButton('S', const Color(0xFFDC2626), () {
                            _executeOptionOrder(side: 'SELL', optType: 'CE', strike: s.strike, premium: s.callLtp);
                          }),
                        ],
                      ),
                    ),

                    // ── 6. Strike Price (Center) ──────────────────────────
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: isAtm ? const Color(0xFFF59E0B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isAtm ? const Color(0xFFD97706) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '${s.strike.toInt()}${isAtm ? ' (ATM)' : ''}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: isAtm ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),

                    // 7. Put Quick Trade Buttons [ B ] [ S ]
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildQuickActionButton('B', const Color(0xFF059669), () {
                            _executeOptionOrder(side: 'BUY', optType: 'PE', strike: s.strike, premium: s.putLtp);
                          }),
                          const SizedBox(width: 4),
                          _buildQuickActionButton('S', const Color(0xFFDC2626), () {
                            _executeOptionOrder(side: 'SELL', optType: 'PE', strike: s.strike, premium: s.putLtp);
                          }),
                        ],
                      ),
                    ),

                    // 8. Put LTP
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isPutItm ? const Color(0xFFFEE2E2).withOpacity(0.6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '₹${s.putLtp.toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ),

                    // 9. Put IV / Delta
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${s.putIv}%', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text('Δ ${s.putDelta}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),

                    // 10. Put Change %
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${s.putChange >= 0 ? '+' : ''}${s.putChangePercent.toStringAsFixed(1)}%',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: putChgColor),
                      ),
                    ),

                    // 11. Put OI
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: isPutItm ? const EdgeInsets.symmetric(vertical: 4) : EdgeInsets.zero,
                        color: isPutItm ? const Color(0xFFFEF2F2) : Colors.transparent,
                        child: Text(
                          '${s.putOi}L',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Center(
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  // ── 2. Multi-Strike Open Interest (OI) & Greeks Analysis View ────────────────
  Widget _buildMultiStrikeOiView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Multi-Strike Open Interest (Call vs Put Distribution)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  const Text('Call OI (Resistance)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  const Text('Put OI (Support)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Visual OI Bars across 11 key strikes
          ...List.generate(11, (idx) {
            final s = _strikesData[idx + 4];
            final maxOi = 100.0;
            final callWidth = (s.callOi / maxOi).clamp(0.05, 1.0);
            final putWidth = (s.putOi / maxOi).clamp(0.05, 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // Call OI Bar
                  Expanded(
                    flex: 5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${s.callOi}L', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor: callWidth,
                              child: Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withOpacity(0.85),
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Strike Center Badge
                  Container(
                    width: 90,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: s.isAtm ? const Color(0xFFF59E0B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: Text(
                        '${s.strike.toInt()}${s.isAtm ? ' ATM' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: s.isAtm ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),

                  // Put OI Bar
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: putWidth,
                              child: Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withOpacity(0.85),
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${s.putOi}L', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── 3. Strategy Builder (Spreads, Straddles, Condors) ─────────────────────────
  Widget _buildStrategyBuilderView() {
    final atm = _strikesData.firstWhere((s) => s.isAtm, orElse: () => _strikesData[9]);
    final otmCall = _strikesData[math.min(11, _strikesData.length - 1)];
    final otmPut = _strikesData[math.max(7, 0)];

    final strategies = [
      (
        'Bull Call Spread',
        'Bullish moderately directional spread. Buy ATM Call, Sell OTM Call to cap downside theta decay.',
        'Buy ${atm.strike.toInt()} CE @ ₹${atm.callLtp} · Sell ${otmCall.strike.toInt()} CE @ ₹${otmCall.callLtp}',
        'Max Profit: ₹${((otmCall.strike - atm.strike - (atm.callLtp - otmCall.callLtp)) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        'Max Loss: ₹${((atm.callLtp - otmCall.callLtp) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        '1:2.4',
        const Color(0xFF059669),
      ),
      (
        'Short Straddle (Delta Neutral)',
        'Sell ATM Call and ATM Put simultaneously to capture premium erosion on low volatility days.',
        'Sell ${atm.strike.toInt()} CE @ ₹${atm.callLtp} · Sell ${atm.strike.toInt()} PE @ ₹${atm.putLtp}',
        'Max Profit: ₹${((atm.callLtp + atm.putLtp) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        'Breakevens: ${(atm.strike - (atm.callLtp + atm.putLtp)).toInt()} to ${(atm.strike + (atm.callLtp + atm.putLtp)).toInt()}',
        'High Win Rate',
        const Color(0xFF7C3AED),
      ),
      (
        'Bear Put Spread',
        'Moderately bearish debit spread. Buy ATM Put and finance with OTM Put writing.',
        'Buy ${atm.strike.toInt()} PE @ ₹${atm.putLtp} · Sell ${otmPut.strike.toInt()} PE @ ₹${otmPut.putLtp}',
        'Max Profit: ₹${((atm.strike - otmPut.strike - (atm.putLtp - otmPut.putLtp)) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        'Max Loss: ₹${((atm.putLtp - otmPut.putLtp) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        '1:2.1',
        const Color(0xFFDC2626),
      ),
      (
        'Iron Condor (4-Legged)',
        'Range-bound non-directional 4-leg structure. Sell OTM Strangle and Buy wings for margin relief.',
        'Sell ${otmCall.strike.toInt()} CE & ${otmPut.strike.toInt()} PE · Buy Wings',
        'Max Profit: ₹${((otmCall.callLtp + otmPut.putLtp) * _lotSizes[_underlying]! * 0.7).toStringAsFixed(0)}',
        'Defined Risk: 85% POP',
        '1:3.0',
        const Color(0xFF2563EB),
      ),
    ];

    return Column(
      children: strategies.map((strat) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: strat.$7.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.psychology_alt_rounded, color: strat.$7, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(strat.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: strat.$7.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                          child: Text(strat.$6, style: TextStyle(color: strat.$7, fontWeight: FontWeight.bold, fontSize: 10.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(strat.$2, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Text('Legs: ${strat.$3}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(strat.$4, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF059669))),
                  const SizedBox(height: 2),
                  Text(strat.$5, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final lotSize = _lotSizes[_underlying] ?? 25;
                      final totalQty = lotSize * 2;
                      final symbol = '$_underlying ${strat.$1}';

                      final engine = CopyTradingEngine();
                      final receipt = await engine.replicateTrade(
                        symbol: symbol,
                        side: 'BUY',
                        baseQty: totalQty,
                        price: 185.0,
                        orderType: 'MARKET',
                        productType: 'STRATEGY SPREAD',
                        lotSize: lotSize,
                      );

                      if (mounted) {
                        CopyTradeReceiptDialog.show(context, receipt);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: strat.$7,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.flash_on, size: 14),
                    label: const Text('Execute Spread (8 Demats)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
