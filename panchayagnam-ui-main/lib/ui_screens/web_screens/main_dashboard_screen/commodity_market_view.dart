import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../reusable_widets/order_placement_ticket_dialog.dart';
import '../../../service/copy_trading_engine.dart';
import '../../../service/theme_mode_service.dart';

/// CommodityMarketView
/// Panchayagnam MCX & NSE Commodity Derivatives Terminal
/// Inspired by Angel One's clean Future Chain + Options Watchlist (ITM/ATM/OTM)
/// upgraded to institutional trading-floor standards:
/// - 9 Commodities: Crude Oil, Natural Gas, Gold, Silver, Crude Oil Mini, Gold Mini, Silver Mini, Copper, Zinc
/// - Exchange selector (MCX | NSE) & Expiry selector (Nov | Dec | Jan)
/// - Live 1.1s Future Chain card with embedded sparkline, Day Range bar, Bid/Ask pressure, CHARTS & OPTION CHAIN
/// - MCX Expiry Term Curve (Nov/Dec/Jan) + Lot Economics & Tick Value Calculator
/// - Live-priced 1-Click Commodity Strategy Strip (ATM Straddle, Bull Call Spread, Futures Hedge)
/// - OHLC Candlestick Chart Modal (5m/15m/1H/4H/1D) & Visual OI-Bar Dual-Side Option Chain Modal
class CommodityMarketView extends StatefulWidget {
  final int initialCommodityIndex;
  final bool initialShowOptionChain;

  const CommodityMarketView({
    super.key,
    this.initialCommodityIndex = 0,
    this.initialShowOptionChain = false,
  });

  @override
  State<CommodityMarketView> createState() => _CommodityMarketViewState();
}

class _CommodityMarketViewState extends State<CommodityMarketView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final math.Random _rand = math.Random();
  Timer? _tickTimer;
  DateTime _now = DateTime.now();

  late int _selectedCommodityIdx;
  String _selectedExchange = 'MCX'; // MCX | NSE
  String _selectedExpiry = 'Nov'; // Nov | Dec | Jan
  String _optionTypeMode = 'CALL'; // CALL | PUT | BOTH
  String _strikeFilter = '';
  int _calcLots = 1;

  late List<Map<String, dynamic>> _commodities;

  @override
  void initState() {
    super.initState();
    _selectedCommodityIdx = widget.initialCommodityIndex.clamp(0, 8);
    _initCommodityUniverse();
    _startLiveTicks();

    if (widget.initialShowOptionChain) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showFullOptionChainModal(context);
      });
    }
  }

  void _initCommodityUniverse() {
    _commodities = [
      {
        'tabName': 'Crude Oil',
        'symbol': 'CRUDEOIL',
        'unit': '100 bbl',
        'lot': 100,
        'tickPerPoint': 100.0,
        'marginPerLot': 142500.0,
        'spot': 8229.00,
        'prevClose': 8180.50,
        'high': 8268.00,
        'low': 8135.00,
        'oi': '28.4L',
        'vol': '44.2K',
        'pcr': 1.14,
        'step': 50,
        'atm': 8250,
        'ivBase': 30.2,
        'flash': 0,
        'buyPressure': 0.64,
        'spark': [0.70, 0.64, 0.66, 0.54, 0.50, 0.55, 0.42, 0.36, 0.38, 0.25, 0.21, 0.17],
        'presetCalls': {8150: 314.80, 8200: 287.30, 8250: 264.70, 8300: 241.70, 8350: 217.40},
      },
      {
        'tabName': 'Natural Gas',
        'symbol': 'NATURALGAS',
        'unit': '1250 mmBtu',
        'lot': 1250,
        'tickPerPoint': 1250.0,
        'marginPerLot': 118000.0,
        'spot': 248.40,
        'prevClose': 242.10,
        'high': 252.80,
        'low': 240.50,
        'oi': '41.8L',
        'vol': '89.5K',
        'pcr': 0.96,
        'step': 5,
        'atm': 250,
        'ivBase': 46.5,
        'flash': 0,
        'buyPressure': 0.59,
        'spark': [0.76, 0.68, 0.72, 0.59, 0.52, 0.48, 0.43, 0.37, 0.31, 0.27, 0.22, 0.18],
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Gold',
        'symbol': 'GOLD',
        'unit': '1 Kg (₹/10g)',
        'lot': 100,
        'tickPerPoint': 100.0,
        'marginPerLot': 585000.0,
        'spot': 76450.00,
        'prevClose': 76120.00,
        'high': 76680.00,
        'low': 75980.00,
        'oi': '18.9L',
        'vol': '12.4K',
        'pcr': 1.28,
        'step': 500,
        'atm': 76500,
        'ivBase': 14.8,
        'flash': 0,
        'buyPressure': 0.68,
        'spark': [0.72, 0.66, 0.60, 0.55, 0.51, 0.46, 0.41, 0.35, 0.30, 0.24, 0.20, 0.16],
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Silver',
        'symbol': 'SILVER',
        'unit': '30 Kg',
        'lot': 30,
        'tickPerPoint': 30.0,
        'marginPerLot': 248000.0,
        'spot': 91240.00,
        'prevClose': 90480.00,
        'high': 91800.00,
        'low': 90120.00,
        'oi': '24.5L',
        'vol': '19.8K',
        'pcr': 1.19,
        'step': 500,
        'atm': 91000,
        'ivBase': 22.4,
        'flash': 0,
        'buyPressure': 0.62,
        'spark': [0.78, 0.72, 0.64, 0.61, 0.54, 0.47, 0.39, 0.34, 0.28, 0.22, 0.19, 0.14],
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Crude Oil Mini',
        'symbol': 'CRUDEOILM',
        'unit': '10 bbl',
        'lot': 10,
        'tickPerPoint': 10.0,
        'marginPerLot': 14500.0,
        'spot': 8231.00,
        'prevClose': 8182.00,
        'high': 8270.00,
        'low': 8138.00,
        'oi': '14.2L',
        'vol': '62.1K',
        'pcr': 1.12,
        'step': 50,
        'atm': 8250,
        'ivBase': 30.4,
        'flash': 0,
        'buyPressure': 0.63,
        'spark': [0.69, 0.63, 0.65, 0.53, 0.49, 0.54, 0.41, 0.35, 0.37, 0.24, 0.20, 0.16],
        'presetCalls': {8150: 316.20, 8200: 288.50, 8250: 265.10, 8300: 242.40, 8350: 218.00},
      },
      {
        'tabName': 'Gold Mini',
        'symbol': 'GOLDM',
        'unit': '100 g (₹/10g)',
        'lot': 10,
        'tickPerPoint': 10.0,
        'marginPerLot': 59500.0,
        'spot': 76410.00,
        'prevClose': 76090.00,
        'high': 76640.00,
        'low': 75950.00,
        'oi': '12.6L',
        'vol': '28.3K',
        'pcr': 1.22,
        'step': 500,
        'atm': 76500,
        'ivBase': 15.1,
        'flash': 0,
        'buyPressure': 0.66,
        'spark': [0.71, 0.65, 0.59, 0.54, 0.50, 0.45, 0.40, 0.34, 0.29, 0.23, 0.19, 0.15],
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Silver Mini',
        'symbol': 'SILVERM',
        'unit': '5 Kg',
        'lot': 5,
        'tickPerPoint': 5.0,
        'marginPerLot': 42500.0,
        'spot': 91210.00,
        'prevClose': 90455.00,
        'high': 91760.00,
        'low': 90090.00,
        'oi': '16.8L',
        'vol': '31.7K',
        'pcr': 1.16,
        'step': 500,
        'atm': 91000,
        'ivBase': 22.8,
        'flash': 0,
        'buyPressure': 0.61,
        'spark': [0.77, 0.71, 0.63, 0.60, 0.53, 0.46, 0.38, 0.33, 0.27, 0.21, 0.18, 0.13],
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Copper',
        'symbol': 'COPPER',
        'unit': '2500 Kg',
        'lot': 2500,
        'tickPerPoint': 2500.0,
        'marginPerLot': 164000.0,
        'spot': 842.60,
        'prevClose': 836.40,
        'high': 848.10,
        'low': 833.20,
        'oi': '9.4L',
        'vol': '14.6K',
        'pcr': 1.04,
        'step': 10,
        'atm': 840,
        'ivBase': 19.6,
        'flash': 0,
        'buyPressure': 0.55,
        'spark': [0.68, 0.62, 0.58, 0.55, 0.51, 0.48, 0.44, 0.39, 0.36, 0.32, 0.28, 0.24],
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Zinc',
        'symbol': 'ZINC',
        'unit': '5000 Kg',
        'lot': 5000,
        'tickPerPoint': 5000.0,
        'marginPerLot': 132000.0,
        'spot': 284.20,
        'prevClose': 281.90,
        'high': 286.50,
        'low': 280.10,
        'oi': '7.2L',
        'vol': '8.9K',
        'pcr': 0.98,
        'step': 5,
        'atm': 285,
        'ivBase': 18.2,
        'flash': 0,
        'buyPressure': 0.53,
        'spark': [0.66, 0.63, 0.59, 0.57, 0.52, 0.49, 0.46, 0.42, 0.39, 0.35, 0.31, 0.28],
        'presetCalls': <int, double>{},
      },
    ];
  }

  void _startLiveTicks() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        for (final c in _commodities) {
          final oldSpot = (c['spot'] as num).toDouble();
          final scale = math.max(0.1, oldSpot * 0.00045);
          final delta = (_rand.nextDouble() - 0.485) * scale * 2;
          final newSpot = double.parse(math.max(1.0, oldSpot + delta).toStringAsFixed(2));
          c['spot'] = newSpot;
          c['high'] = math.max((c['high'] as num).toDouble(), newSpot);
          c['low'] = math.min((c['low'] as num).toDouble(), newSpot);
          c['flash'] = delta > 0.02 ? 1 : (delta < -0.02 ? -1 : 0);
          final bp = ((c['buyPressure'] as double) + (delta >= 0 ? 0.015 : -0.015)).clamp(0.35, 0.80);
          c['buyPressure'] = bp;

          final spark = List<double>.from(c['spark'] as List);
          spark.removeAt(0);
          spark.add((spark.last + (delta >= 0 ? -0.035 : 0.035)).clamp(0.08, 0.88));
          c['spark'] = spark;
        }
      });
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatIndianPrice(double val) {
    final parts = val.abs().toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    String formatted;
    if (intPart.length <= 3) {
      formatted = '$intPart.$decPart';
    } else {
      final last3 = intPart.substring(intPart.length - 3);
      final rest = intPart.substring(0, intPart.length - 3);
      formatted = '${rest.replaceAll(RegExp(r'\B(?=(\d{2})+(?!\d))'), ',')},$last3.$decPart';
    }
    return val < 0 ? '-$formatted' : formatted;
  }

  String _expiryFutDate([String? exp]) {
    switch (exp ?? _selectedExpiry) {
      case 'Dec':
        return '18-Dec-26';
      case 'Jan':
        return '20-Jan-27';
      default:
        return '19-Nov-26';
    }
  }

  String _expiryOptDate([String? exp]) {
    switch (exp ?? _selectedExpiry) {
      case 'Dec':
        return '16-Dec-26';
      case 'Jan':
        return '18-Jan-27';
      default:
        return '17-Nov-26';
    }
  }

  double _expiryMultiplier([String? exp]) {
    switch (exp ?? _selectedExpiry) {
      case 'Dec':
        return 1.006;
      case 'Jan':
        return 1.012;
      default:
        return 1.0;
    }
  }

  List<Map<String, dynamic>> _buildStrikesForCommodity(Map<String, dynamic> c) {
    final sym = c['symbol'] as String;
    final spot = (c['spot'] as num).toDouble() * _expiryMultiplier();
    final step = c['step'] as int;
    final atm = c['atm'] as int;
    final ivBase = (c['ivBase'] as num).toDouble();
    final presets = c['presetCalls'] as Map<int, double>;

    final rows = <Map<String, dynamic>>[];
    for (int offset = -3; offset <= 4; offset++) {
      final strike = atm + (offset * step);
      final ceIntrinsic = math.max(0.0, spot - strike);
      final ceDistFactor = math.max(0.15, 1.0 - (offset.abs() * 0.14));
      final baseTimeVal = spot * 0.026 * ceDistFactor * (_selectedExpiry == 'Dec' ? 1.18 : (_selectedExpiry == 'Jan' ? 1.34 : 1.0));
      final cePreset = (_selectedExpiry == 'Nov' && _selectedExchange == 'MCX') ? presets[strike] : null;
      final ceLtp = cePreset != null
          ? double.parse((cePreset + ((_rand.nextDouble() - 0.48) * 0.8)).toStringAsFixed(2))
          : double.parse((ceIntrinsic + baseTimeVal).toStringAsFixed(2));
      final ceChg = double.parse((ceLtp * 0.042 + (offset == 0 ? 1.5 : 0.4)).toStringAsFixed(2));
      final ceChgPct = double.parse(((ceChg / math.max(1.0, ceLtp - ceChg)) * 100).toStringAsFixed(2));
      final ceDelta = double.parse((0.50 - (offset * 0.09)).clamp(0.12, 0.88).toStringAsFixed(2));
      final ceMoneyness = strike < spot - (step * 0.4)
          ? 'ITM'
          : (strike > spot + (step * 0.4) ? 'OTM' : 'ATM');

      final peIntrinsic = math.max(0.0, strike - spot);
      final peLtp = double.parse((peIntrinsic + baseTimeVal * 0.96).toStringAsFixed(2));
      final peChg = double.parse((-(peLtp * 0.031)).toStringAsFixed(2));
      final peChgPct = double.parse(((peChg / math.max(1.0, peLtp - peChg)) * 100).toStringAsFixed(2));
      final peDelta = double.parse((-0.50 - (offset * 0.09)).clamp(-0.88, -0.12).toStringAsFixed(2));
      final peMoneyness = strike > spot + (step * 0.4)
          ? 'ITM'
          : (strike < spot - (step * 0.4) ? 'OTM' : 'ATM');

      final ceOiNum = (14.2 + (offset + 4) * 3.1).clamp(4.0, 45.0);
      final peOiNum = (29.8 - (offset + 3) * 2.4).clamp(4.0, 45.0);

      rows.add({
        'symbol': sym,
        'strike': strike,
        'ceMoneyness': ceMoneyness,
        'peMoneyness': peMoneyness,
        'ceLtp': ceLtp,
        'ceChg': ceChg,
        'ceChgPct': ceChgPct,
        'ceDelta': ceDelta,
        'ceOi': '${ceOiNum.toStringAsFixed(1)}L',
        'ceOiNorm': (ceOiNum / 45.0).clamp(0.12, 1.0),
        'ceVol': '${(18.4 - offset.abs() * 2.1).toStringAsFixed(1)}K',
        'ceIv': '${(ivBase - offset * 0.5).toStringAsFixed(1)}%',
        'peLtp': peLtp,
        'peChg': peChg,
        'peChgPct': peChgPct,
        'peDelta': peDelta,
        'peOi': '${peOiNum.toStringAsFixed(1)}L',
        'peOiNorm': (peOiNum / 45.0).clamp(0.12, 1.0),
        'peVol': '${(16.2 - offset.abs() * 1.9).toStringAsFixed(1)}K',
        'peIv': '${(ivBase + 0.6 + offset * 0.4).toStringAsFixed(1)}%',
      });
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final c = _commodities[_selectedCommodityIdx];
    final sym = c['symbol'] as String;
    final tabName = c['tabName'] as String;
    final unit = c['unit'] as String;
    final lot = c['lot'] as int;
    final baseSpot = (c['spot'] as num).toDouble();
    final spot = baseSpot * _expiryMultiplier();
    final prevClose = (c['prevClose'] as num).toDouble() * _expiryMultiplier();
    final diff = spot - prevClose;
    final chgPct = (diff / prevClose) * 100;
    final isUp = diff >= 0;
    final flash = c['flash'] as int;
    final spark = (c['spark'] as List).cast<double>();
    final buyPressure = c['buyPressure'] as double;
    final tickPerPoint = (c['tickPerPoint'] as num).toDouble();
    final marginPerLot = (c['marginPerLot'] as num).toDouble();
    final allStrikes = _buildStrikesForCommodity(c);
    final strikes = _strikeFilter.trim().isEmpty
        ? allStrikes
        : allStrikes.where((s) => s['strike'].toString().contains(_strikeFilter.trim())).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeModeService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
        final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Scaffold(
          backgroundColor: bg,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header & Strike Search
                _buildTopHeader(isDark, borderCol),

                // 2. Global Commodities Benchmark Strip
                _buildGlobalCommoditiesStrip(isDark, borderCol, textSub),

                // 3. Horizontal Commodity Selector Tabs (Crude Oil, Natural Gas, Gold, Silver, etc.)
                _buildCommodityTabsBar(isDark, cardBg, borderCol, textMain, textSub),

                // 4. Main Derivatives Workspace
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exchange (MCX|NSE) + Live Session Clock + Expiry (Nov|Dec|Jan)
                      _buildExchangeAndExpiryBar(
                        isDark, cardBg, borderCol, textMain, textSub, sym, tabName, spot, lot, unit, c['pcr'] as double,
                      ),
                      const SizedBox(height: 18),

                      // Future Chain Card + Futures Curve / Lot Profit Calculator
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final futCard = _buildFutureChainCard(
                            isDark: isDark,
                            cardBg: cardBg,
                            borderCol: borderCol,
                            textMain: textMain,
                            textSub: textSub,
                            sym: sym,
                            unit: unit,
                            lot: lot,
                            spot: spot,
                            diff: diff,
                            chgPct: chgPct,
                            isUp: isUp,
                            flash: flash,
                            high: (c['high'] as num).toDouble() * _expiryMultiplier(),
                            low: (c['low'] as num).toDouble() * _expiryMultiplier(),
                            oi: c['oi'] as String,
                            vol: c['vol'] as String,
                            spark: spark,
                            buyPressure: buyPressure,
                          );

                          final sideRail = _buildTermCurveAndCalculatorPanel(
                            isDark: isDark,
                            cardBg: cardBg,
                            borderCol: borderCol,
                            textMain: textMain,
                            textSub: textSub,
                            sym: sym,
                            baseSpot: baseSpot,
                            tickPerPoint: tickPerPoint,
                            marginPerLot: marginPerLot,
                            unit: unit,
                          );

                          if (constraints.maxWidth > 1020) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: futCard),
                                const SizedBox(width: 16),
                                Expanded(flex: 4, child: sideRail),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              futCard,
                              const SizedBox(height: 16),
                              sideRail,
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 18),

                      // 1-Click Live Commodity Strategy Strip (ATM Straddle / Spread / Hedge)
                      _buildCommodityStrategyStrip(
                        isDark: isDark,
                        cardBg: cardBg,
                        borderCol: borderCol,
                        textMain: textMain,
                        textSub: textSub,
                        sym: sym,
                        spot: spot,
                        lot: lot,
                        allStrikes: allStrikes,
                      ),

                      const SizedBox(height: 18),

                      // Options Watchlist Section (Call / Put / Straddle + ITM/ATM/OTM)
                      _buildOptionsWatchlistSection(
                        isDark: isDark,
                        cardBg: cardBg,
                        borderCol: borderCol,
                        textMain: textMain,
                        textSub: textSub,
                        sym: sym,
                        lot: lot,
                        strikes: strikes,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(bool isDark, Color borderCol) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B132B) : const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.32), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: const Icon(Icons.oil_barrel_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'COMMODITY DERIVATIVES FLOOR',
                        style: TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                        ),
                        child: const Text(
                          'MCX & NSE LIVE',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Future Chain, Options Watchlist (ITM/ATM/OTM Greeks), Straddle Builder & Multi-Broker Replication',
                    style: TextStyle(color: Colors.white.withOpacity(0.74), fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 205,
                height: 35,
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Filter strike e.g. 8250...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF38BDF8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                    suffixIcon: _strikeFilter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _strikeFilter = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _strikeFilter = v),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedBuilder(
                animation: CopyTradingEngine(),
                builder: (context, _) {
                  final count = CopyTradingEngine().totalAccountsCount;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_rounded, color: Color(0xFF38BDF8), size: 14),
                        const SizedBox(width: 6),
                        Text('$count Brokers Synced', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalCommoditiesStrip(bool isDark, Color borderCol, Color textSub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _stripMetric('WTI CRUDE', '\$71.42 (+0.64%)', const Color(0xFF10B981)),
            _stripDivider(textSub),
            _stripMetric('BRENT CRUDE', '\$75.10 (+0.52%)', const Color(0xFF10B981)),
            _stripDivider(textSub),
            _stripMetric('COMEX GOLD', '\$2,684.50 (+0.43%)', const Color(0xFF10B981)),
            _stripDivider(textSub),
            _stripMetric('COMEX SILVER', '\$31.42 (+0.85%)', const Color(0xFF10B981)),
            _stripDivider(textSub),
            _stripMetric('HENRY HUB NATGAS', '\$2.88 (+2.10%)', const Color(0xFF10B981)),
            _stripDivider(textSub),
            _stripMetric('USD/INR', '84.38 (-0.04%)', const Color(0xFFF59E0B)),
            _stripDivider(textSub),
            _stripMetric('MCX SESSION', '09:00–23:30 IST OPEN', const Color(0xFF38BDF8)),
            _stripDivider(textSub),
            Text(
              'STREAM ${DateFormat('HH:mm:ss').format(_now)} IST',
              style: TextStyle(color: textSub, fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stripMetric(String label, String val, Color col) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: col)),
      ],
    );
  }

  Widget _stripDivider(Color textSub) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('|', style: TextStyle(color: textSub.withOpacity(0.4), fontSize: 11)),
      );

  Widget _buildCommodityTabsBar(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      width: double.infinity,
      color: cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_commodities.length, (idx) {
            final item = _commodities[idx];
            final active = _selectedCommodityIdx == idx;
            final spot = (item['spot'] as num).toDouble();
            final prev = (item['prevClose'] as num).toDouble();
            final pct = ((spot - prev) / prev) * 100;
            final isUp = spot >= prev;

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () => setState(() => _selectedCommodityIdx = idx),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF2563EB).withOpacity(isDark ? 0.25 : 0.1)
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? const Color(0xFF38BDF8) : borderCol,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['tabName'] as String,
                        style: TextStyle(
                          color: active ? (isDark ? Colors.white : const Color(0xFF1D4ED8)) : textMain,
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_formatIndianPrice(spot)} (${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildExchangeAndExpiryBar(
    bool isDark,
    Color cardBg,
    Color borderCol,
    Color textMain,
    Color textSub,
    String sym,
    String tabName,
    double spot,
    int lot,
    String unit,
    double pcr,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol)),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Exchange', style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              _segmentedToggle(
                options: const ['MCX', 'NSE'],
                selected: _selectedExchange,
                isDark: isDark,
                onSelect: (v) => setState(() => _selectedExchange = v),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderCol),
            ),
            child: Text(
              '$tabName ($sym)  ·  Contract Lot: $unit  ·  OI PCR: $pcr',
              style: TextStyle(color: textSub, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Expiry', style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              _segmentedToggle(
                options: const ['Nov', 'Dec', 'Jan'],
                selected: _selectedExpiry,
                isDark: isDark,
                onSelect: (v) => setState(() => _selectedExpiry = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segmentedToggle({
    required List<String> options,
    required String selected,
    required bool isDark,
    required ValueChanged<String> onSelect,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = opt == selected;
          return InkWell(
            onTap: () => onSelect(opt),
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFutureChainCard({
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
    required Color textSub,
    required String sym,
    required String unit,
    required int lot,
    required double spot,
    required double diff,
    required double chgPct,
    required bool isUp,
    required int flash,
    required double high,
    required double low,
    required String oi,
    required String vol,
    required List<double> spark,
    required double buyPressure,
  }) {
    final futContract = '$sym $_selectedExpiry FUT ($_selectedExchange)';
    final bid = spot - math.max(0.5, spot * 0.00015);
    final ask = spot + math.max(0.5, spot * 0.00015);
    final rangePos = ((spot - low) / math.max(0.5, high - low)).clamp(0.06, 0.94);
    final accentCol = isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Future Chain', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
                      child: Text('$_selectedExchange · $unit', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: accentCol.withOpacity(0.14), borderRadius: BorderRadius.circular(5)),
                      child: Text('SUPERTREND: BULLISH BUY', style: TextStyle(color: accentCol, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ),
                    const Spacer(),
                    Text('Exp: ${_expiryFutDate()}', style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),

                // Main Contract Row + Embedded Live Sparkline
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sym, style: TextStyle(color: textMain, fontSize: 21, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            'Bid ₹${_formatIndianPrice(bid)}  |  Ask ₹${_formatIndianPrice(ask)}  ·  OI: $oi · Vol: $vol',
                            style: TextStyle(color: textSub, fontSize: 12),
                          ),
                          const SizedBox(height: 10),

                          // Day Range Bar
                          SizedBox(
                            width: 260,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Day Low ₹${_formatIndianPrice(low)}', style: TextStyle(color: textSub, fontSize: 10.5, fontWeight: FontWeight.w700)),
                                    Text('High ₹${_formatIndianPrice(high)}', style: TextStyle(color: textSub, fontSize: 10.5, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: rangePos,
                                    minHeight: 5.5,
                                    backgroundColor: Colors.grey.withOpacity(0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(accentCol),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Embedded Intraday Live Sparkline
                    Container(
                      width: 115,
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderCol),
                      ),
                      child: CustomPaint(
                        painter: _CommoditySparklinePainter(points: spark, color: accentCol),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Flashing Price & Change
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: flash == 1
                            ? const Color(0xFF10B981).withOpacity(0.14)
                            : (flash == -1 ? const Color(0xFFEF4444).withOpacity(0.14) : Colors.transparent),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${_formatIndianPrice(spot)} ${isUp ? '▲' : '▼'}',
                            style: TextStyle(color: accentCol, fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${isUp ? '+' : ''}₹${diff.toStringAsFixed(2)} (${isUp ? '+' : ''}${chgPct.toStringAsFixed(2)}%)',
                            style: TextStyle(color: accentCol, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Buy / Sell Pressure Depth + Execution Action Row
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    // Orderflow Bid/Ask Pressure Meter
                    SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Buyers ${(buyPressure * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w900)),
                              Text('Sellers ${((1 - buyPressure) * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: (buyPressure * 100).round(),
                                  child: Container(height: 6, color: const Color(0xFF10B981)),
                                ),
                                Expanded(
                                  flex: ((1 - buyPressure) * 100).round(),
                                  child: Container(height: 6, color: const Color(0xFFEF4444)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            OrderPlacementTicketDialog.show(context, symbol: futContract, side: 'BUY', ltp: spot, lotSize: lot, category: 'COMMODITY');
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                          child: const Text('BUY FUT', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            OrderPlacementTicketDialog.show(context, symbol: futContract, side: 'SELL', ltp: spot, lotSize: lot, category: 'COMMODITY');
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                          child: const Text('SELL FUT', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                        ),
                        AnimatedBuilder(
                          animation: CopyTradingEngine(),
                          builder: (context, _) {
                            final count = CopyTradingEngine().totalAccountsCount;
                            return OutlinedButton.icon(
                              onPressed: () {
                                CopyTradingEngine().replicateTrade(symbol: futContract, side: 'BUY', baseQty: lot, price: spot);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('⚡ Replicated $futContract across all $count Connected Brokers!'), backgroundColor: const Color(0xFF059669)),
                                );
                              },
                              icon: const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF10B981)),
                              label: Text('Copy ($count Brokers)', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w800)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF10B981)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: borderCol),

          // CHARTS | OPTION CHAIN Action Strip
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showCommodityChartModal(context, sym, spot, spark, isDark),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.candlestick_chart_rounded, color: Color(0xFF3B82F6), size: 18),
                        SizedBox(width: 8),
                        Text('CHARTS', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: borderCol),
              Expanded(
                child: InkWell(
                  onTap: () => _showFullOptionChainModal(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link_rounded, color: Color(0xFF3B82F6), size: 18),
                        SizedBox(width: 8),
                        Text('OPTION CHAIN', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                      ],
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

  Widget _buildTermCurveAndCalculatorPanel({
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
    required Color textSub,
    required String sym,
    required double baseSpot,
    required double tickPerPoint,
    required double marginPerLot,
    required String unit,
  }) {
    final months = ['Nov', 'Dec', 'Jan'];
    final tickValueTotal = tickPerPoint * _calcLots;
    final totalMargin = marginPerLot * _calcLots;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$sym Futures Term Curve', style: TextStyle(color: textMain, fontSize: 14.5, fontWeight: FontWeight.w900)),
              const Text('Contango Spread', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),

          ...months.map((m) {
            final price = baseSpot * _expiryMultiplier(m);
            final spread = price - baseSpot;
            final isSel = m == _selectedExpiry;
            return InkWell(
              onTap: () => setState(() => _selectedExpiry = m),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF2563EB).withOpacity(isDark ? 0.22 : 0.08) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSel ? const Color(0xFF38BDF8) : borderCol),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$m (${_expiryFutDate(m)})', style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800)),
                        Text(spread == 0 ? 'Front Month Benchmark' : '+₹${spread.toStringAsFixed(1)} vs Nov', style: TextStyle(color: textSub, fontSize: 10)),
                      ],
                    ),
                    Text('₹${_formatIndianPrice(price)}', style: TextStyle(color: isSel ? const Color(0xFF38BDF8) : const Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 10),
          Divider(height: 1, color: borderCol),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lot P&L & Margin Calculator', style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900)),
              Wrap(
                spacing: 4,
                children: [1, 2, 5, 10].map((lots) {
                  final active = _calcLots == lots;
                  return InkWell(
                    onTap: () => setState(() => _calcLots = lots),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF10B981) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text('${lots}L', style: TextStyle(color: active ? Colors.white : textSub, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('P&L per ₹1 move ($_calcLots Lot)', style: TextStyle(color: textSub, fontSize: 11)),
                    Text('₹${_formatIndianPrice(tickValueTotal)} / pt', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Est. NRML Margin ($unit)', style: TextStyle(color: textSub, fontSize: 11)),
                    Text('₹${_formatIndianPrice(totalMargin)}', style: TextStyle(color: textMain, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommodityStrategyStrip({
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
    required Color textSub,
    required String sym,
    required double spot,
    required int lot,
    required List<Map<String, dynamic>> allStrikes,
  }) {
    final atmRow = allStrikes.firstWhere(
      (r) => r['ceMoneyness'] == 'ATM',
      orElse: () => allStrikes[allStrikes.length ~/ 2],
    );
    final atmStrike = atmRow['strike'] as int;
    final atmIdx = allStrikes.indexOf(atmRow);
    final otmRow = allStrikes[(atmIdx + 1).clamp(0, allStrikes.length - 1)];

    final ceLtp = atmRow['ceLtp'] as double;
    final peLtp = atmRow['peLtp'] as double;
    final otmCeLtp = otmRow['ceLtp'] as double;
    final straddlePrem = ceLtp + peLtp;
    final spreadDebit = math.max(1.0, ceLtp - otmCeLtp);

    final strategies = [
      {
        'name': 'ATM Short Straddle',
        'legs': '$sym $atmStrike CE + PE',
        'metric': 'Total Credit: ₹${straddlePrem.toStringAsFixed(1)} · BE ${(atmStrike - straddlePrem).round()}–${(atmStrike + straddlePrem).round()}',
        'side': 'SELL',
        'price': straddlePrem,
        'col': const Color(0xFFF59E0B),
      },
      {
        'name': 'Bull Call Spread',
        'legs': 'Buy $atmStrike CE / Sell ${otmRow['strike']} CE',
        'metric': 'Net Debit: ₹${spreadDebit.toStringAsFixed(1)} · Defined Risk Setup',
        'side': 'BUY',
        'price': spreadDebit,
        'col': const Color(0xFF10B981),
      },
      {
        'name': 'Protected FUT + PE Hedge',
        'legs': 'Long FUT + Buy $atmStrike PE',
        'metric': 'Downside capped below $atmStrike · Hedge Cost ₹${peLtp.toStringAsFixed(1)}',
        'side': 'BUY',
        'price': spot,
        'col': const Color(0xFF38BDF8),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1-Click Institutional Commodity Strategies ($sym ATM $atmStrike)', style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
            const Text('Auto-calculated from Live Options', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardW = constraints.maxWidth > 900 ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: strategies.map((st) {
                final col = st['col'] as Color;
                final legs = st['legs'] as String;
                final price = st['price'] as double;
                final side = st['side'] as String;
                return Container(
                  width: cardW,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: col.withOpacity(0.45))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(st['name'] as String, style: TextStyle(color: col, fontSize: 12.5, fontWeight: FontWeight.w900)),
                          InkWell(
                            onTap: () {
                              final count = CopyTradingEngine().totalAccountsCount;
                              CopyTradingEngine().replicateTrade(symbol: legs, side: side, baseQty: lot, price: price);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('⚡ Deployed ${st['name']} ($legs) across $count brokers!'), backgroundColor: const Color(0xFF059669)),
                              );
                            },
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(5)),
                              child: const Text('Deploy ⚡', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(legs, style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(st['metric'] as String, style: TextStyle(color: textSub, fontSize: 10.5)),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOptionsWatchlistSection({
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
    required Color textSub,
    required String sym,
    required int lot,
    required List<Map<String, dynamic>> strikes,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Options Watchlist', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text('LIVE GREEKS & OI (${_expiryOptDate()})', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              _segmentedToggle(
                options: const ['Call', 'Put', 'Straddle'],
                selected: _optionTypeMode == 'CALL' ? 'Call' : (_optionTypeMode == 'PUT' ? 'Put' : 'Straddle'),
                isDark: isDark,
                onSelect: (val) {
                  setState(() {
                    _optionTypeMode = val == 'Call' ? 'CALL' : (val == 'Put' ? 'PUT' : 'BOTH');
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (strikes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No strikes matching "$_strikeFilter"', style: TextStyle(color: textSub, fontSize: 13))),
            )
          else
            Column(
              children: strikes.expand((row) {
                final List<Widget> widgets = [];
                if (_optionTypeMode == 'CALL' || _optionTypeMode == 'BOTH') {
                  widgets.add(_buildOptionStrikeTile(row: row, isCall: true, sym: sym, lot: lot, isDark: isDark, borderCol: borderCol, textMain: textMain, textSub: textSub));
                }
                if (_optionTypeMode == 'PUT' || _optionTypeMode == 'BOTH') {
                  widgets.add(_buildOptionStrikeTile(row: row, isCall: false, sym: sym, lot: lot, isDark: isDark, borderCol: borderCol, textMain: textMain, textSub: textSub));
                }
                return widgets;
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionStrikeTile({
    required Map<String, dynamic> row,
    required bool isCall,
    required String sym,
    required int lot,
    required bool isDark,
    required Color borderCol,
    required Color textMain,
    required Color textSub,
  }) {
    final strike = row['strike'] as int;
    final moneyness = (isCall ? row['ceMoneyness'] : row['peMoneyness']) as String;
    final ltp = (isCall ? row['ceLtp'] : row['peLtp']) as double;
    final chg = (isCall ? row['ceChg'] : row['peChg']) as double;
    final chgPct = (isCall ? row['ceChgPct'] : row['peChgPct']) as double;
    final delta = (isCall ? row['ceDelta'] : row['peDelta']) as double;
    final oi = (isCall ? row['ceOi'] : row['peOi']) as String;
    final oiNorm = (isCall ? row['ceOiNorm'] : row['peOiNorm']) as double;
    final vol = (isCall ? row['ceVol'] : row['peVol']) as String;
    final iv = (isCall ? row['ceIv'] : row['peIv']) as String;
    final isUp = chg >= 0;
    final optType = isCall ? 'CE' : 'PE';
    final fullContract = '$sym $strike $optType ($_selectedExpiry $_selectedExchange)';

    Color mFg = const Color(0xFF64748B);
    Color mBg = const Color(0xFF64748B).withOpacity(0.14);
    if (moneyness == 'ITM') {
      mFg = const Color(0xFF059669);
      mBg = const Color(0xFF10B981).withOpacity(0.16);
    } else if (moneyness == 'ATM') {
      mFg = const Color(0xFFD97706);
      mBg = const Color(0xFFF59E0B).withOpacity(0.18);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: moneyness == 'ATM'
            ? const Color(0xFFF59E0B).withOpacity(isDark ? 0.08 : 0.04)
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: moneyness == 'ATM' ? const Color(0xFFF59E0B).withOpacity(0.55) : borderCol),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(sym, style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: mBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(moneyness, style: TextStyle(color: mFg, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: (isCall ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.14), borderRadius: BorderRadius.circular(4)),
                      child: Text(optType, style: TextStyle(color: isCall ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_expiryOptDate()}  $strike $optType   ·   OI: $oi  ·  Vol: $vol  ·  IV: $iv  ·  Δ $delta',
                  style: TextStyle(color: textSub, fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: oiNorm,
                      minHeight: 3.5,
                      backgroundColor: Colors.grey.withOpacity(0.18),
                      valueColor: AlwaysStoppedAnimation<Color>(isCall ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${_formatIndianPrice(ltp)} ${isUp ? '▲' : '▼'}',
                style: TextStyle(color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                '${isUp ? '+' : ''}₹${chg.toStringAsFixed(2)} (${isUp ? '+' : ''}${chgPct.toStringAsFixed(2)}%)',
                style: TextStyle(color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(width: 16),

          InkWell(
            onTap: () {
              OrderPlacementTicketDialog.show(context, symbol: fullContract, side: 'BUY', ltp: ltp, lotSize: lot, category: 'COMMODITY');
            },
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 32,
              height: 30,
              decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(5)),
              alignment: Alignment.center,
              child: const Text('B', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              OrderPlacementTicketDialog.show(context, symbol: fullContract, side: 'SELL', ltp: ltp, lotSize: lot, category: 'COMMODITY');
            },
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 32,
              height: 30,
              decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(5)),
              alignment: Alignment.center,
              child: const Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Replicate across all ${CopyTradingEngine().totalAccountsCount} connected brokers',
            child: InkWell(
              onTap: () {
                final count = CopyTradingEngine().totalAccountsCount;
                CopyTradingEngine().replicateTrade(symbol: fullContract, side: 'BUY', baseQty: lot, price: ltp);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('⚡ Replicated $fullContract across all $count Connected Brokers!'), backgroundColor: const Color(0xFF059669)),
                );
              },
              borderRadius: BorderRadius.circular(5),
              child: Container(
                width: 32,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.bolt_rounded, color: Color(0xFF38BDF8), size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Upgraded OHLC Candlestick & EMA Chart Modal ──
  void _showCommodityChartModal(BuildContext context, String sym, double spot, List<double> spark, bool isDark) {
    String selectedTf = '15m';
    final lot = _commodities[_selectedCommodityIdx]['lot'] as int;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.candlestick_chart_rounded, color: Color(0xFF38BDF8), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$sym ($_selectedExchange $_selectedExpiry) · Institutional Candlestick & EMA',
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: ['5m', '15m', '1H', '4H', '1D'].map((tf) {
                          final active = tf == selectedTf;
                          return InkWell(
                            onTap: () => setModalState(() => selectedTf = tf),
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: active ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(tf, style: TextStyle(color: active ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 270,
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$selectedTf  |  LTP ₹${_formatIndianPrice(spot)}  |  EMA(20) ₹${_formatIndianPrice(spot * 0.994)}  |  VWAP ₹${_formatIndianPrice(spot * 0.996)}',
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            const Text('SUPERTREND (10,3): BUY 🟢', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: CustomPaint(
                            size: const Size(double.infinity, double.infinity),
                            painter: _OhlcCandlestickPainter(tfSeed: selectedTf.hashCode),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pivot: ₹${_formatIndianPrice(spot * 0.997)}   ·   R1: ₹${_formatIndianPrice(spot * 1.008)}   ·   S1: ₹${_formatIndianPrice(spot * 0.991)}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              OrderPlacementTicketDialog.show(context, symbol: '$sym $_selectedExpiry FUT', side: 'BUY', ltp: spot, lotSize: lot, category: 'COMMODITY');
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                            child: const Text('BUY FUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              OrderPlacementTicketDialog.show(context, symbol: '$sym $_selectedExpiry FUT', side: 'SELL', ltp: spot, lotSize: lot, category: 'COMMODITY');
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                            child: const Text('SELL FUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ],
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

  // ── Upgraded Dual-Side MCX Option Chain Modal with OI Bars ──
  void _showFullOptionChainModal(BuildContext context) {
    final c = _commodities[_selectedCommodityIdx];
    final sym = c['symbol'] as String;
    final lot = c['lot'] as int;
    final strikes = _buildStrikesForCommodity(c);
    final isDark = ThemeModeService.isDarkModeNotifier.value;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 650),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart_rounded, color: Color(0xFF10B981), size: 22),
                    const SizedBox(width: 10),
                    Text('$sym ($_selectedExchange · $_selectedExpiry) Commodity Option Chain',
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('CALL OI BAR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))),
                      Expanded(child: Text('IV / Δ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))),
                      Expanded(child: Text('CALL LTP', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF10B981)))),
                      Expanded(child: Text('STRIKE', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))),
                      Expanded(child: Text('PUT LTP', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)))),
                      Expanded(child: Text('IV / Δ', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))),
                      Expanded(flex: 2, child: Text('PUT OI BAR', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: strikes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final r = strikes[idx];
                      final strike = r['strike'] as int;
                      final ceLtp = r['ceLtp'] as double;
                      final peLtp = r['peLtp'] as double;
                      final ceOiNorm = r['ceOiNorm'] as double;
                      final peOiNorm = r['peOiNorm'] as double;
                      final isAtm = r['ceMoneyness'] == 'ATM';

                      return Container(
                        color: isAtm ? const Color(0xFFF59E0B).withOpacity(0.12) : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  SizedBox(width: 44, child: Text('${r['ceOi']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                  Expanded(
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: ceOiNorm,
                                      child: Container(height: 7, decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.65), borderRadius: BorderRadius.circular(3))),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: Text('${r['ceIv']} / ${r['ceDelta']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)))),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  OrderPlacementTicketDialog.show(context, symbol: '$sym $strike CE', side: 'BUY', ltp: ceLtp, lotSize: lot, category: 'COMMODITY');
                                },
                                child: Text('₹$ceLtp', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                isAtm ? '$strike ATM' : '$strike',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: isAtm ? const Color(0xFFF59E0B) : null),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  OrderPlacementTicketDialog.show(context, symbol: '$sym $strike PE', side: 'BUY', ltp: peLtp, lotSize: lot, category: 'COMMODITY');
                                },
                                child: Text('₹$peLtp', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ),
                            ),
                            Expanded(child: Text('${r['peIv']} / ${r['peDelta']}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)))),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerRight,
                                      widthFactor: peOiNorm,
                                      child: Container(height: 7, decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.65), borderRadius: BorderRadius.circular(3))),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(width: 44, child: Text('${r['peOi']}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommoditySparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  const _CommoditySparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = points[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.32), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _CommoditySparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

class _OhlcCandlestickPainter extends CustomPainter {
  final int tfSeed;
  const _OhlcCandlestickPainter({required this.tfSeed});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1;
    for (int g = 1; g <= 3; g++) {
      final y = (g / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const count = 24;
    final slotW = size.width / count;
    final candleW = slotW * 0.56;
    final r = math.Random(tfSeed + 42);
    double cursor = 0.68;
    final emaPath = Path();

    for (int i = 0; i < count; i++) {
      final isBull = (i % 5 != 2) ? r.nextDouble() > 0.35 : false;
      final move = (r.nextDouble() * 0.08 + 0.02) * (isBull ? -1 : 1);
      final open = cursor.clamp(0.18, 0.82);
      final close = (cursor + move).clamp(0.14, 0.84);
      final high = math.min(open, close) - r.nextDouble() * 0.05;
      final low = math.max(open, close) + r.nextDouble() * 0.05;
      cursor = close;

      final xCenter = i * slotW + slotW / 2;
      final col = close <= open ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      final paint = Paint()
        ..color = col
        ..strokeWidth = 1.6;

      canvas.drawLine(Offset(xCenter, high * size.height), Offset(xCenter, low * size.height), paint);
      final rectTop = math.min(open, close) * size.height;
      final rectH = math.max(4.0, (open - close).abs() * size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(xCenter - candleW / 2, rectTop, candleW, rectH), const Radius.circular(1.5)),
        paint..style = PaintingStyle.fill,
      );

      final emaY = ((open + close) / 2 + 0.05) * size.height;
      if (i == 0) {
        emaPath.moveTo(xCenter, emaY);
      } else {
        emaPath.lineTo(xCenter, emaY);
      }
    }

    final emaPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(emaPath, emaPaint);
  }

  @override
  bool shouldRepaint(covariant _OhlcCandlestickPainter oldDelegate) => oldDelegate.tfSeed != tfSeed;
}
