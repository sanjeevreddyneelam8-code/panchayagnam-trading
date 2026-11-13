import '../../../reusable_widets/order_placement_ticket_dialog.dart';
import '../../../service/theme_mode_service.dart';
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

class BasketLegItem {
  final double strike;
  final String optType; // 'CE' or 'PE'
  final String side; // 'BUY' or 'SELL'
  final double premium;
  int lots;

  BasketLegItem({
    required this.strike,
    required this.optType,
    required this.side,
    required this.premium,
    this.lots = 1,
  });

  String get key => '${strike.toInt()}-$optType-$side';
}

class OptionsChainView extends StatefulWidget {
  final int initialTabIndex;
  final VoidCallback? onNavigateToOrders;
  final VoidCallback? onNavigateToPositions;
  final VoidCallback? onNavigateToCharts;

  const OptionsChainView({
    super.key,
    this.initialTabIndex = 0,
    this.onNavigateToOrders,
    this.onNavigateToPositions,
    this.onNavigateToCharts,
  });

  @override
  State<OptionsChainView> createState() => _OptionsChainViewState();
}

class _OptionsChainViewState extends State<OptionsChainView> {
  String _underlying = 'NIFTY';
  String _expiry = '07-NOV-2026 (Weekly)';
  late int _activeSubTab; // 0: Chain, 1: Multi-Strike OI, 2: Strategy Builder

  bool _basketMode = false;
  bool _basketExpanded = false;
  final Map<String, BasketLegItem> _basketLegs = {};

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
    'NIFTY': 24228.31,
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
    final double baseSpot = _spotPrices[_underlying] ?? 24228.31;
    final double atm = (baseSpot / step).round() * step;
    _maxPain = atm;

    final List<OptionStrikeData> list = [];
    final rand = math.Random(_underlying.hashCode + _expiry.hashCode);

    // Realistic Indian F&O ATM straddle benchmarks (Weekly Expiry)
    final double atmStraddle = switch (_underlying) {
      'BANKNIFTY' => 640.0,
      'SENSEX' => 760.0,
      'FINNIFTY' => 180.0,
      'MIDCPNIFTY' => 110.0,
      _ => 210.0, // NIFTY
    };
    final double atmCallPrice = atmStraddle * 0.52;
    final double atmPutPrice = atmStraddle * 0.48;

    // Generate 19 strikes (9 below ATM, 1 ATM, 9 above ATM)
    for (int i = -9; i <= 9; i++) {
      final double strike = atm + (i * step);
      final bool isAtm = (i == 0);
      final double distSteps = (strike - baseSpot) / step;

      // CALL SIDE:
      // When strike < baseSpot -> In-The-Money (Intrinsic = baseSpot - strike)
      // Extrinsic value decays exponentially away from ATM (like real Black-Scholes)
      final double callIntrinsic = math.max(0.0, baseSpot - strike);
      final double callTimeValue = math.max(0.75, atmCallPrice * math.exp(-math.pow(distSteps / 3.4, 2)));
      final double callLtp = double.parse((callIntrinsic + (strike >= baseSpot ? callTimeValue : callTimeValue * 0.55)).toStringAsFixed(2));

      // PUT SIDE:
      // When strike > baseSpot -> In-The-Money (Intrinsic = strike - baseSpot)
      final double putIntrinsic = math.max(0.0, strike - baseSpot);
      final double putTimeValue = math.max(0.65, atmPutPrice * math.exp(-math.pow(distSteps / 3.4, 2)));
      final double putLtp = double.parse((putIntrinsic + (strike <= baseSpot ? putTimeValue : putTimeValue * 0.55)).toStringAsFixed(2));

      // GREEKS:
      final double callDelta = double.parse((1.0 / (1.0 + math.exp(distSteps * 0.65))).toStringAsFixed(2));
      final double putDelta = double.parse((callDelta - 1.0).toStringAsFixed(2));
      final double callIv = double.parse((13.4 + (distSteps.abs() * 0.22) + (rand.nextDouble() * 0.4)).toStringAsFixed(1));
      final double putIv = double.parse((13.6 + (distSteps.abs() * 0.25) + (rand.nextDouble() * 0.4)).toStringAsFixed(1));

      // Real Indian Market Open Interest Distribution:
      final double callOi = double.parse((38.0 + 95.0 * math.exp(-math.pow((distSteps - 2.0) / 4.0, 2)) + rand.nextDouble() * 12.0).toStringAsFixed(1));
      final double putOi = double.parse((35.0 + 102.0 * math.exp(-math.pow((distSteps + 2.0) / 4.0, 2)) + rand.nextDouble() * 12.0).toStringAsFixed(1));
      final double callChg = double.parse(((rand.nextDouble() * 14.0) - 5.0).toStringAsFixed(1));
      final double putChg = double.parse(((rand.nextDouble() * 14.0) - 6.0).toStringAsFixed(1));

      list.add(OptionStrikeData(
        strike: strike,
        isAtm: isAtm,
        callLtp: callLtp,
        callChange: callChg,
        callChangePercent: callChg,
        callOi: callOi,
        callOiChange: double.parse((callChg * 0.4).toStringAsFixed(1)),
        callIv: callIv,
        callDelta: callDelta,
        callVolume: (callOi * 25000).toInt(),
        putLtp: putLtp,
        putChange: putChg,
        putChangePercent: putChg,
        putOi: putOi,
        putOiChange: double.parse((putChg * 0.4).toStringAsFixed(1)),
        putIv: putIv,
        putDelta: putDelta,
        putVolume: (putOi * 25000).toInt(),
      ));
    }

    _strikesData = list;
    double totalCallOi = list.fold(0.0, (acc, s) => acc + s.callOi);
    double totalPutOi = list.fold(0.0, (acc, s) => acc + s.putOi);
    _pcr = totalCallOi > 0 ? double.parse((totalPutOi / totalCallOi).toStringAsFixed(2)) : 0.94;
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
  }) {
    final lotSize = _lotSizes[_underlying] ?? 25;
    final symbol = '$_underlying ${strike.toInt()} $optType';

    OrderPlacementTicketDialog.show(
      context,
      symbol: symbol,
      side: side,
      ltp: premium,
      lotSize: lotSize,
      category: 'F&O',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPos = _spotChange >= 0;
    final spotColor = isPos ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final lotSize = _lotSizes[_underlying] ?? 25;

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeModeService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        final cardBg = isDark ? const Color(0xFF0F1E22) : Colors.white;
        final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header Row ───────────────────────────────────────────
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Panchayagnam Trade Options (F&O)',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
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
                      'NSE/BSE derivatives strikes, live implied volatility (IV), Greeks, PCR analysis, and 1-click execution.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),

                // Sub-Tabs: F&O Strikes / Multi-Strike OI / Strategy Builder
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSubTabButton(0, 'Option Chain', Icons.table_chart_rounded),
                        _buildSubTabButton(1, 'Multi-Strike OI & Greeks', Icons.auto_graph_rounded),
                        _buildSubTabButton(2, 'Strategy Builder', Icons.psychology_alt_rounded),
                      ],
                    ),
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
                              color: _pcr >= 0.95 ? const Color(0xFFDCFCE7) : (_pcr >= 0.80 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _pcr >= 0.95 ? 'Mild Bullish' : (_pcr >= 0.80 ? 'Neutral Sentiment' : 'Bearish Sentiment'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: _pcr >= 0.95 ? const Color(0xFF166534) : (_pcr >= 0.80 ? const Color(0xFFB45309) : const Color(0xFF991B1B)),
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
                      Text('₹${_maxPain.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
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
                          selectedColor: const Color(0xFF059669),
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
            if (_activeSubTab == 0) ...[
              _buildOptionChainTable(isDark, cardBg, borderCol, textMain, textSub),
              _buildBasketModeBottomBar(isDark, cardBg, borderCol, textMain, textSub),
            ] else if (_activeSubTab == 1)
              _buildMultiStrikeOiView()
            else
              _buildStrategyBuilderView(),
          ],
        ),
      ),
    );
  },
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
          color: isSelected ? const Color(0xFF059669) : Colors.transparent,
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
  Widget _buildOptionChainTable(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.02), blurRadius: 10, offset: const Offset(0, 3)),
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
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F2E22) : const Color(0xFFDCFCE7),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Text(
                      'CALL OPTIONS (CE)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  child: Center(
                    child: Text(
                      'STRIKE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3B151E) : const Color(0xFFFEE2E2),
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Text(
                      'PUT OPTIONS (PE)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Authentic NSE Legend Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: borderCol)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2210) : const Color(0xFFFFFBEB),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Text('In-The-Money (ITM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSub)),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Text('Out-Of-The-Money (OTM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSub)),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                const Text('At-The-Money (ATM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                const Spacer(),
                const Icon(Icons.fiber_manual_record, color: Color(0xFF16A34A), size: 10),
                const SizedBox(width: 5),
                const Text('LIVE STREAMING (NSE F&O TICK: 11ms)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
              ],
            ),
          ),

          // Sub-Column Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162032) : const Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: borderCol)),
            ),
            child: Row(
              children: [
                // Calls columns
                Expanded(flex: 2, child: Text('OI (Lakh)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('CHG %', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('IV / DELTA', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                const Expanded(flex: 3, child: Text('LTP (₹)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)))),
                Expanded(flex: 2, child: Text('ACTIONS', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),

                // Strike
                Expanded(flex: 3, child: Text('STRIKE PRICE', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: textMain))),

                // Puts columns
                Expanded(flex: 2, child: Text('ACTIONS', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                const Expanded(flex: 3, child: Text('LTP (₹)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)))),
                Expanded(flex: 2, child: Text('IV / DELTA', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('CHG %', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('OI (Lakh)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
              ],
            ),
          ),

          // Strike Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _strikesData.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: borderCol),
            itemBuilder: (ctx, i) {
              final s = _strikesData[i];
              final isCallItm = s.strike < _spotPrice;
              final isPutItm = s.strike > _spotPrice;
              final isAtm = s.isAtm;

              // ITM Shading
              final callSideBg = isCallItm
                  ? (isDark ? const Color(0xFF1C2214) : const Color(0xFFFFFBEB))
                  : cardBg;
              final putSideBg = isPutItm
                  ? (isDark ? const Color(0xFF27171C) : const Color(0xFFFFFBEB))
                  : cardBg;

              final callChgColor = s.callChange >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
              final putChgColor = s.putChange >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

              final callBuyKey = '${s.strike.toInt()}-CE-BUY';
              final callSellKey = '${s.strike.toInt()}-CE-SELL';
              final isCallBuySelected = _basketLegs.containsKey(callBuyKey);
              final isCallSellSelected = _basketLegs.containsKey(callSellKey);
              final selectedCallLeg = isCallBuySelected ? _basketLegs[callBuyKey] : (isCallSellSelected ? _basketLegs[callSellKey] : null);

              final putBuyKey = '${s.strike.toInt()}-PE-BUY';
              final putSellKey = '${s.strike.toInt()}-PE-SELL';
              final isPutBuySelected = _basketLegs.containsKey(putBuyKey);
              final isPutSellSelected = _basketLegs.containsKey(putSellKey);
              final selectedPutLeg = isPutBuySelected ? _basketLegs[putBuyKey] : (isPutSellSelected ? _basketLegs[putSellKey] : null);

              return Container(
                decoration: BoxDecoration(
                  border: isAtm ? Border.all(color: const Color(0xFF2563EB), width: 1.5) : null,
                ),
                child: Row(
                  children: [
                    // ── CALLS (CE) SIDE (Flex: 11) ──
                    Expanded(
                      flex: 11,
                      child: Container(
                        color: callSideBg,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                // 1. Call OI
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${s.callOi}L',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain),
                                  ),
                                ),
                                // 2. Call Change %
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${s.callChange >= 0 ? '+' : ''}${s.callChangePercent.toStringAsFixed(1)}%',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: callChgColor),
                                  ),
                                ),
                                // 3. Call IV / Delta
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${s.callIv}%', style: TextStyle(fontSize: 10, color: textSub)),
                                      const Text('Δ', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                    ],
                                  ),
                                ),
                                // 4. Call LTP
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: isCallItm ? (isDark ? const Color(0xFF2D2E16) : const Color(0xFFFEF3C7)) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '₹${s.callLtp.toStringAsFixed(2)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                                    ),
                                  ),
                                ),
                                // 5. Call Quick Trade Buttons [ B ] [ S ]
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildQuickActionButton(
                                        'B',
                                        const Color(0xFF059669),
                                        isSelected: isCallBuySelected,
                                        isBasketMode: _basketMode,
                                        onTap: () {
                                          if (_basketMode) {
                                            setState(() {
                                              if (isCallBuySelected) {
                                                _basketLegs.remove(callBuyKey);
                                              } else {
                                                _basketLegs.remove(callSellKey);
                                                _basketLegs[callBuyKey] = BasketLegItem(
                                                  strike: s.strike,
                                                  optType: 'CE',
                                                  side: 'BUY',
                                                  premium: s.callLtp,
                                                );
                                              }
                                            });
                                          } else {
                                            _executeOptionOrder(side: 'BUY', optType: 'CE', strike: s.strike, premium: s.callLtp);
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 3),
                                      _buildQuickActionButton(
                                        'S',
                                        const Color(0xFFDC2626),
                                        isSelected: isCallSellSelected,
                                        isBasketMode: _basketMode,
                                        onTap: () {
                                          if (_basketMode) {
                                            setState(() {
                                              if (isCallSellSelected) {
                                                _basketLegs.remove(callSellKey);
                                              } else {
                                                _basketLegs.remove(callBuyKey);
                                                _basketLegs[callSellKey] = BasketLegItem(
                                                  strike: s.strike,
                                                  optType: 'CE',
                                                  side: 'SELL',
                                                  premium: s.callLtp,
                                                );
                                              }
                                            });
                                          } else {
                                            _executeOptionOrder(side: 'SELL', optType: 'CE', strike: s.strike, premium: s.callLtp);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Inline Lots Stepper when selected in Basket Mode (Matching Screenshot)
                            if (_basketMode && selectedCallLeg != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _buildRowLotsStepper(selectedCallLeg, isDark, cardBg, borderCol, textMain),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── 6. CENTER STRIKE (Flex: 3) ──
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isAtm ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          border: Border(
                            left: BorderSide(color: isAtm ? const Color(0xFF1D4ED8) : borderCol),
                            right: BorderSide(color: isAtm ? const Color(0xFF1D4ED8) : borderCol),
                          ),
                        ),
                        child: Text(
                          '${s.strike.toInt()}${isAtm ? ' (ATM)' : ''}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isAtm ? Colors.white : textMain,
                          ),
                        ),
                      ),
                    ),

                    // ── PUTS (PE) SIDE (Flex: 11) ──
                    Expanded(
                      flex: 11,
                      child: Container(
                        color: putSideBg,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                // 7. Put Quick Trade Buttons [ B ] [ S ]
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildQuickActionButton(
                                        'B',
                                        const Color(0xFF059669),
                                        isSelected: isPutBuySelected,
                                        isBasketMode: _basketMode,
                                        onTap: () {
                                          if (_basketMode) {
                                            setState(() {
                                              if (isPutBuySelected) {
                                                _basketLegs.remove(putBuyKey);
                                              } else {
                                                _basketLegs.remove(putSellKey);
                                                _basketLegs[putBuyKey] = BasketLegItem(
                                                  strike: s.strike,
                                                  optType: 'PE',
                                                  side: 'BUY',
                                                  premium: s.putLtp,
                                                );
                                              }
                                            });
                                          } else {
                                            _executeOptionOrder(side: 'BUY', optType: 'PE', strike: s.strike, premium: s.putLtp);
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 3),
                                      _buildQuickActionButton(
                                        'S',
                                        const Color(0xFFDC2626),
                                        isSelected: isPutSellSelected,
                                        isBasketMode: _basketMode,
                                        onTap: () {
                                          if (_basketMode) {
                                            setState(() {
                                              if (isPutSellSelected) {
                                                _basketLegs.remove(putSellKey);
                                              } else {
                                                _basketLegs.remove(putBuyKey);
                                                _basketLegs[putSellKey] = BasketLegItem(
                                                  strike: s.strike,
                                                  optType: 'PE',
                                                  side: 'SELL',
                                                  premium: s.putLtp,
                                                );
                                              }
                                            });
                                          } else {
                                            _executeOptionOrder(side: 'SELL', optType: 'PE', strike: s.strike, premium: s.putLtp);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // 8. Put LTP
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: isPutItm ? (isDark ? const Color(0xFF33161C) : const Color(0xFFFEF3C7)) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '₹${s.putLtp.toStringAsFixed(2)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                                    ),
                                  ),
                                ),
                                // 9. Put IV / Delta
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${s.putIv}%', style: TextStyle(fontSize: 10, color: textSub)),
                                      const Text('Δ', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                    ],
                                  ),
                                ),
                                // 10. Put Change %
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${s.putChange >= 0 ? '+' : ''}${s.putChangePercent.toStringAsFixed(1)}%',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: putChgColor),
                                  ),
                                ),
                                // 11. Put OI
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${s.putOi}L',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain),
                                  ),
                                ),
                              ],
                            ),
                            // Inline Lots Stepper when selected in Basket Mode (Matching Screenshot)
                            if (_basketMode && selectedPutLeg != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildRowLotsStepper(selectedPutLeg, isDark, cardBg, borderCol, textMain),
                                ),
                              ),
                          ],
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

  Widget _buildQuickActionButton(
    String label,
    Color color, {
    required VoidCallback onTap,
    bool isSelected = false,
    bool isBasketMode = false,
  }) {
    final showSolid = !isBasketMode || isSelected;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: showSolid ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isBasketMode ? Border.all(color: color, width: 1.2) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: showSolid ? Colors.white : color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRowLotsStepper(BasketLegItem leg, bool isDark, Color cardBg, Color borderCol, Color textMain) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: borderCol),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: leg.lots > 1
                ? () => setState(() => leg.lots--)
                : () => setState(() => _basketLegs.remove(leg.key)),
            child: const Icon(Icons.remove, size: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 4),
          Text(
            '${leg.lots}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMain),
          ),
          const SizedBox(width: 4),
          const Text('Lots', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => leg.lots++),
            child: const Icon(Icons.add, size: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildBasketModeBottomBar(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final lotSize = _lotSizes[_underlying] ?? 25;
    final totalLots = _basketLegs.values.fold<int>(0, (sum, leg) => sum + leg.lots);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Basket Mode Switch Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 10),
                Text(
                  'Basket Mode',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: _basketMode,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) {
                    setState(() {
                      _basketMode = val;
                      if (!val) {
                        _basketLegs.clear();
                        _basketExpanded = false;
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // If Basket Mode is ON and has legs selected
          if (_basketMode && _basketLegs.isNotEmpty) ...[
            Divider(height: 1, color: borderCol),
            InkWell(
              onTap: () => setState(() => _basketExpanded = !_basketExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      '${_basketLegs.length} Strikes Selected ($totalLots Lots)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _basketExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: textSub,
                    ),
                  ],
                ),
              ),
            ),

            // Expandable drawer of selected legs
            if (_basketExpanded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: isDark ? const Color(0xFF0A1318) : const Color(0xFFF8FAFC),
                child: Column(
                  children: _basketLegs.values.map((leg) {
                    final isBuy = leg.side == 'BUY';
                    final legTotal = leg.premium * leg.lots * lotSize;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBuy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              leg.side,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: isBuy ? const Color(0xFF166534) : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_underlying ${leg.strike.toInt()} ${leg.optType}',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textMain),
                          ),
                          const Spacer(),
                          Text(
                            '₹${leg.premium.toStringAsFixed(2)} × ${leg.lots}L (₹${legTotal.toStringAsFixed(0)})',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSub),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() => _basketLegs.remove(leg.key)),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Full-width PROCEED Button (Matching Screenshot)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _proceedBasketOrder,
                  child: const Text(
                    'PROCEED',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Bottom Pill Action Strip: [ Open Orders ] [ Positions ] [ Charts ↗ ] [ ⋮ ]
          Divider(height: 1, color: borderCol),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildBottomPillButton('Open Orders', Icons.list_alt_rounded, widget.onNavigateToOrders, isDark, textMain),
                const SizedBox(width: 8),
                _buildBottomPillButton('Positions', Icons.account_balance_wallet_outlined, widget.onNavigateToPositions, isDark, textMain),
                const SizedBox(width: 8),
                _buildBottomPillButton('Charts ↗', Icons.show_chart_rounded, widget.onNavigateToCharts, isDark, textMain),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: textSub),
                  onSelected: (val) {
                    if (val == 'clear') {
                      setState(() => _basketLegs.clear());
                    } else if (val == 'refresh') {
                      setState(() => _generateFullOptionChain());
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'refresh', child: Text('Refresh Live Chain')),
                    const PopupMenuItem(value: 'clear', child: Text('Clear Selected Basket Legs')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPillButton(String title, IconData icon, VoidCallback? onTap, bool isDark, Color textMain) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _proceedBasketOrder() {
    if (_basketLegs.isEmpty) return;
    final lotSize = _lotSizes[_underlying] ?? 25;
    final totalLots = _basketLegs.values.fold<int>(0, (sum, leg) => sum + leg.lots);
    final totalEstValue = _basketLegs.values.fold<double>(0.0, (sum, leg) => sum + (leg.premium * leg.lots * lotSize));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: const [
              Icon(Icons.shopping_bag_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Confirm Basket Order', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to place ${_basketLegs.length} legs ($totalLots Lots) across linked child accounts:',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    children: _basketLegs.values.map((leg) {
                      final isBuy = leg.side == 'BUY';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isBuy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                leg.side,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isBuy ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_underlying ${leg.strike.toInt()} ${leg.optType}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              '${leg.lots} Lots @ ₹${leg.premium.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Est. Value / Margin:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    Text('₹${totalEstValue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF059669))),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                final engine = CopyTradingEngine();
                final legsCount = _basketLegs.length;
                for (final leg in _basketLegs.values) {
                  engine.executeLiveOrder(
                    symbol: '$_underlying ${leg.strike.toInt()} ${leg.optType}',
                    side: leg.side,
                    quantity: leg.lots * lotSize,
                    price: leg.premium,
                    productType: 'NRML',
                    orderType: 'MARKET',
                    isAlgo: true,
                    strategyTag: 'BASKET-OPTION-CHAIN',
                  );
                }
                setState(() {
                  _basketLegs.clear();
                  _basketExpanded = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF059669),
                    content: Text('✅ Basket Order placed: $legsCount legs executed across linked accounts!'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('Execute Basket Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
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
    // ── Strategy Builder State & Simulation Variables ──
  int _selectedStrategyIndex = 0;
  double _simSpotOffset = 0.0; // -400 to +400 pts
  int _simDaysToExpiry = 0; // 0 (Today) to 4 (Expiry)

  Widget _buildStrategyBuilderView() {
    final atm = _strikesData.firstWhere((s) => s.isAtm, orElse: () => _strikesData[9]);
    final otmCall = _strikesData[math.min(11, _strikesData.length - 1)];
    final otmPut = _strikesData[math.max(7, 0)];

    final strategies = [
      {
        'name': 'Bull Call Spread',
        'type': 'Moderately Bullish',
        'pop': '68.2%',
        'delta': '+0.28',
        'theta': '+₹1,450/d',
        'maxProfit': '₹${((otmCall.strike - atm.strike - (atm.callLtp - otmCall.callLtp)) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        'maxLoss': '₹${((atm.callLtp - otmCall.callLtp) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        'rr': '1:2.4',
        'beLower': (atm.strike + (atm.callLtp - otmCall.callLtp)).toInt(),
        'beUpper': otmCall.strike.toInt(),
        'legs': [
          {'side': 'BUY', 'strike': atm.strike.toInt(), 'type': 'CE', 'price': atm.callLtp, 'delta': 0.52},
          {'side': 'SELL', 'strike': otmCall.strike.toInt(), 'type': 'CE', 'price': otmCall.callLtp, 'delta': -0.24},
        ],
        'color': const Color(0xFF059669),
      },
      {
        'name': 'Short Straddle (Delta Neutral)',
        'type': 'Non-Directional Premium Decay',
        'pop': '74.8%',
        'delta': '-0.02',
        'theta': '+₹4,250/d',
        'maxProfit': '₹${((atm.callLtp + atm.putLtp) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        'maxLoss': 'Undefined (SL Protected)',
        'rr': 'High Win-Rate',
        'beLower': (atm.strike - (atm.callLtp + atm.putLtp)).toInt(),
        'beUpper': (atm.strike + (atm.callLtp + atm.putLtp)).toInt(),
        'legs': [
          {'side': 'SELL', 'strike': atm.strike.toInt(), 'type': 'CE', 'price': atm.callLtp, 'delta': -0.50},
          {'side': 'SELL', 'strike': atm.strike.toInt(), 'type': 'PE', 'price': atm.putLtp, 'delta': 0.48},
        ],
        'color': const Color(0xFF7C3AED),
      },
      {
        'name': 'Iron Condor (4-Legged Defined Risk)',
        'type': 'Range-Bound Defined Risk',
        'pop': '82.5%',
        'delta': '+0.01',
        'theta': '+₹3,180/d',
        'maxProfit': '₹${((otmCall.callLtp + otmPut.putLtp) * _lotSizes[_underlying]! * 0.7).toStringAsFixed(0)}',
        'maxLoss': '₹${(((otmCall.strike - atm.strike) * 0.5) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        'rr': '1:3.1',
        'beLower': (otmPut.strike - (otmPut.putLtp * 0.8)).toInt(),
        'beUpper': (otmCall.strike + (otmCall.callLtp * 0.8)).toInt(),
        'legs': [
          {'side': 'BUY', 'strike': (otmPut.strike - 200).toInt(), 'type': 'PE', 'price': 12.50, 'delta': 0.08},
          {'side': 'SELL', 'strike': otmPut.strike.toInt(), 'type': 'PE', 'price': otmPut.putLtp, 'delta': -0.22},
          {'side': 'SELL', 'strike': otmCall.strike.toInt(), 'type': 'CE', 'price': otmCall.callLtp, 'delta': -0.25},
          {'side': 'BUY', 'strike': (otmCall.strike + 200).toInt(), 'type': 'CE', 'price': 14.80, 'delta': 0.10},
        ],
        'color': const Color(0xFF2563EB),
      },
      {
        'name': 'Bear Put Spread',
        'type': 'Moderately Bearish',
        'pop': '65.8%',
        'delta': '-0.26',
        'theta': '+₹1,320/d',
        'maxProfit': '₹${((atm.strike - otmPut.strike - (atm.putLtp - otmPut.putLtp)) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        'maxLoss': '₹${((atm.putLtp - otmPut.putLtp) * _lotSizes[_underlying]!).toStringAsFixed(0)}',
        'rr': '1:2.1',
        'beLower': otmPut.strike.toInt(),
        'beUpper': (atm.strike - (atm.putLtp - otmPut.putLtp)).toInt(),
        'legs': [
          {'side': 'BUY', 'strike': atm.strike.toInt(), 'type': 'PE', 'price': atm.putLtp, 'delta': -0.48},
          {'side': 'SELL', 'strike': otmPut.strike.toInt(), 'type': 'PE', 'price': otmPut.putLtp, 'delta': 0.22},
        ],
        'color': const Color(0xFFDC2626),
      },
    ];

    final currentStrat = strategies[_selectedStrategyIndex];
    final spotPrice = _spotPrices[_underlying]!;
    final simulatedSpot = spotPrice + _simSpotOffset;

    // Simulated PnL calculation based on simulated spot offset
    final double simulatedPnl = (_selectedStrategyIndex == 1)
        ? (3500.0 - (_simSpotOffset.abs() * 12.5) + (_simDaysToExpiry * 850.0))
        : (_selectedStrategyIndex == 0
            ? ((_simSpotOffset > 0 ? math.min(6500.0, _simSpotOffset * 28.0) : math.max(-2800.0, _simSpotOffset * 20.0)) + (_simDaysToExpiry * 300.0))
            : (_selectedStrategyIndex == 2
                ? ((_simSpotOffset.abs() < 180 ? 4200.0 : math.max(-2100.0, 4200.0 - (_simSpotOffset.abs() - 180) * 18.0)) + (_simDaysToExpiry * 750.0))
                : ((_simSpotOffset < 0 ? math.min(5800.0, -_simSpotOffset * 25.0) : math.max(-2600.0, -_simSpotOffset * 18.0)) + (_simDaysToExpiry * 280.0))));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strategy Selection Chips (Sensibull Style)
        Container(
          padding: const EdgeInsets.all(16),
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
                  const Row(
                    children: [
                      Icon(Icons.candlestick_chart_rounded, color: Color(0xFF2563EB), size: 20),
                      SizedBox(width: 8),
                      Text('SENSIBULL-GRADE OPTIONS STRATEGY TERMINAL & PAYOFF LAB', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.3)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFA7F3D0))),
                    child: const Text('SPAN MARGIN RELIEF ACTIVE (₹1.37L Saved)', style: TextStyle(color: Color(0xFF065F46), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(strategies.length, (idx) {
                    final s = strategies[idx];
                    final isSel = _selectedStrategyIndex == idx;
                    final col = s['color'] as Color;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selectedStrategyIndex = idx),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? col.withOpacity(0.12) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSel ? col : const Color(0xFFE2E8F0), width: isSel ? 1.8 : 1),
                          ),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(s['name'] as String, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, color: isSel ? col : const Color(0xFF334155))),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                child: Text('POP ${s['pop']}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: col)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Payoff Graph Canvas & Greeks Simulation Lab
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Custom Payoff Canvas (Visual Curve)
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${currentStrat['name']} Payoff Chart', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
                            Text('Solid Curve: P&L at Expiry · Dashed Curve: P&L Today (T+0)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                        Row(
                          children: [
                            _buildChartLegend('Expiry P&L', const Color(0xFF059669), false),
                            const SizedBox(width: 12),
                            _buildChartLegend('Target Date P&L', const Color(0xFF2563EB), true),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Custom Painted Payoff Curve
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: OptionsPayoffPainter(
                          stratIndex: _selectedStrategyIndex,
                          spotPrice: spotPrice,
                          simOffset: _simSpotOffset,
                          daysDecay: _simDaysToExpiry,
                          beLower: (currentStrat['beLower'] as num).toDouble(),
                          beUpper: (currentStrat['beUpper'] as num).toDouble(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Breakevens & Probabilities Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Lower BE: ${currentStrat['beLower']}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('Current Spot: ${spotPrice.toStringAsFixed(1)} (ATM)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                          Text('Upper BE: ${currentStrat['beUpper']}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('R:R: ${currentStrat['rr']}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Right: Target Price & Date Slider Lab (Sensibull Target Simulator)
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text('TARGET PRICE & DATE SIMULATOR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A), letterSpacing: 0.3)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Spot Price Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Target Spot Price:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        Text('${simulatedSpot.toStringAsFixed(1)} (${_simSpotOffset >= 0 ? '+' : ''}${_simSpotOffset.toInt()} pts)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    Slider(
                      value: _simSpotOffset,
                      min: -400,
                      max: 400,
                      divisions: 40,
                      activeColor: const Color(0xFF2563EB),
                      onChanged: (v) => setState(() => _simSpotOffset = v),
                    ),
                    const SizedBox(height: 6),

                    // Days to Expiry Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Target Date (Theta Decay):', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        Text(_simDaysToExpiry == 0 ? 'Today (T+0)' : 'Expiry Day (T+$_simDaysToExpiry)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                      ],
                    ),
                    Slider(
                      value: _simDaysToExpiry.toDouble(),
                      min: 0,
                      max: 4,
                      divisions: 4,
                      activeColor: const Color(0xFF7C3AED),
                      onChanged: (v) => setState(() => _simDaysToExpiry = v.toInt()),
                    ),
                    const SizedBox(height: 12),

                    // Estimated Projected PnL Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: simulatedPnl >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: simulatedPnl >= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PROJECTED P&L AT TARGET', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: simulatedPnl >= 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B))),
                              const SizedBox(height: 2),
                              Text('${simulatedPnl >= 0 ? '+' : ''}₹${simulatedPnl.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: simulatedPnl >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626))),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                            child: Text(simulatedPnl >= 0 ? 'TARGET IN PROFIT 🟢' : 'TARGET IN LOSS 🔴', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: simulatedPnl >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Portfolio Greeks Mini Card
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Net Delta (Δ): ${currentStrat['delta']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              Text('Net Theta (Θ): ${currentStrat['theta']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Max Profit: ${currentStrat['maxProfit']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                              Text('Max Loss: ${currentStrat['maxLoss']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Multi-Leg Strategy Execution Card
        Container(
          padding: const EdgeInsets.all(18),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Strategy Legs & Multi-Broker Synchronized Execution (${currentStrat['name']})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      const Text('Order legs will execute with hedge-first priority across all 8 connected Demats (Margin relief auto-applied)', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final engine = CopyTradingEngine();
                      final result = await engine.replicateTrade(
                        symbol: '$_underlying ${currentStrat['name']}',
                        side: 'BUY',
                        baseQty: _lotSizes[_underlying]!,
                        price: spotPrice,
                        orderType: 'MARKET',
                        productType: 'INTRADAY (MIS)',
                      );
                      if (context.mounted) {
                        CopyTradeReceiptDialog.show(context, result);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentStrat['color'] as Color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: Text('Execute Spread (${CopyTradingEngine().totalAccountsCount} Brokers · Sub-15ms)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Legs Table
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: (currentStrat['legs'] as List<Map<String, dynamic>>).map((leg) {
                    final isBuy = leg['side'] == 'BUY';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: isBuy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4)),
                            child: Text(leg['side'], style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: isBuy ? const Color(0xFF059669) : const Color(0xFFDC2626))),
                          ),
                          const SizedBox(width: 14),
                          Text('$_underlying ${leg['strike']} ${leg['type']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                          const SizedBox(width: 14),
                          Text('1 Lot (${_lotSizes[_underlying]} Qty)', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                          const Spacer(),
                          Text('LTP: ₹${(leg['price'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          const SizedBox(width: 20),
                          Text('Delta: ${leg['delta']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace')),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartLegend(String label, Color color, bool isDashed) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ── Custom Painter for Sensibull-grade Options Payoff Curve ──────────────────

class OptionsPayoffPainter extends CustomPainter {
  final int stratIndex;
  final double spotPrice;
  final double simOffset;
  final int daysDecay;
  final double beLower;
  final double beUpper;

  OptionsPayoffPainter({
    required this.stratIndex,
    required this.spotPrice,
    required this.simOffset,
    required this.daysDecay,
    required this.beLower,
    required this.beUpper,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()..color = const Color(0xFFF1F5F9)..strokeWidth = 1;
    final paintZeroLine = Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final paintCurve = Paint()..color = const Color(0xFF059669)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final paintTargetCurve = Paint()..color = const Color(0xFF2563EB)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final paintProfitArea = Paint()..color = const Color(0xFF10B981).withOpacity(0.12)..style = PaintingStyle.fill;
    final paintLossArea = Paint()..color = const Color(0xFFEF4444).withOpacity(0.08)..style = PaintingStyle.fill;

    // Grid lines
    final midY = size.height * 0.52;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paintZeroLine);

    // Vertical grid lines
    for (double x = 40; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }

    final pathExpiry = Path();
    final pathTarget = Path();
    final pathArea = Path();

    // Generate smooth curve points
    final int points = 60;
    for (int i = 0; i <= points; i++) {
      final x = (size.width / points) * i;
      final pricePoint = spotPrice - 300 + (600 / points) * i;

      double pnl = 0.0;
      if (stratIndex == 1) { // Short Straddle
        final dist = (pricePoint - spotPrice).abs();
        pnl = 3500.0 - dist * 14.0;
      } else if (stratIndex == 0) { // Bull Call Spread
        if (pricePoint < spotPrice) {
          pnl = -2400.0;
        } else if (pricePoint > spotPrice + 150) {
          pnl = 5200.0;
        } else {
          pnl = -2400.0 + (pricePoint - spotPrice) * 50.6;
        }
      } else if (stratIndex == 2) { // Iron Condor
        final dist = (pricePoint - spotPrice).abs();
        if (dist < 120) {
          pnl = 3600.0;
        } else if (dist > 240) {
          pnl = -1800.0;
        } else {
          pnl = 3600.0 - (dist - 120) * 45.0;
        }
      } else { // Bear Put Spread
        if (pricePoint > spotPrice) {
          pnl = -2200.0;
        } else if (pricePoint < spotPrice - 150) {
          pnl = 4800.0;
        } else {
          pnl = -2200.0 + (spotPrice - pricePoint) * 46.6;
        }
      }

      final y = midY - (pnl / 7000.0) * (size.height * 0.42);
      final yTarget = midY - ((pnl + daysDecay * 450.0 - (simOffset - (pricePoint - spotPrice)).abs() * 0.05) / 7000.0) * (size.height * 0.40);

      if (i == 0) {
        pathExpiry.moveTo(x, y.clamp(10.0, size.height - 10.0));
        pathTarget.moveTo(x, yTarget.clamp(10.0, size.height - 10.0));
        pathArea.moveTo(x, midY);
        pathArea.lineTo(x, y.clamp(10.0, size.height - 10.0));
      } else {
        pathExpiry.lineTo(x, y.clamp(10.0, size.height - 10.0));
        pathTarget.lineTo(x, yTarget.clamp(10.0, size.height - 10.0));
        pathArea.lineTo(x, y.clamp(10.0, size.height - 10.0));
      }
    }

    pathArea.lineTo(size.width, midY);
    pathArea.close();

    // Draw Profit/Loss areas
    canvas.drawPath(pathArea, paintProfitArea);

    // Draw curves
    canvas.drawPath(pathExpiry, paintCurve);
    canvas.drawPath(pathTarget, paintTargetCurve);

    // Marker for current Spot Price
    final spotX = size.width * 0.50 + (simOffset / 600.0) * size.width;
    final spotPaint = Paint()..color = const Color(0xFF2563EB)..strokeWidth = 1.5;
    canvas.drawLine(Offset(spotX, 0), Offset(spotX, size.height), spotPaint);
    canvas.drawCircle(Offset(spotX, midY), 4, Paint()..color = const Color(0xFF2563EB));
  }

  @override
  bool shouldRepaint(covariant OptionsPayoffPainter oldDelegate) {
    return oldDelegate.stratIndex != stratIndex ||
        oldDelegate.simOffset != simOffset ||
        oldDelegate.daysDecay != daysDecay;
  }
}
