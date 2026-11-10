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
/// - Commodities: Crude Oil, Natural Gas, Gold, Silver, Crude Oil Mini, Gold Mini, Silver Mini, Copper, Zinc
/// - Exchange selector (MCX | NSE) & Expiry selector (Nov | Dec | Jan)
/// - Live 1.1s streaming Future Chain + bid/ask depth + OI/Volume
/// - Interactive Commodity Chart modal & Full Dual-Side MCX Option Chain modal
/// - Options Watchlist with Call / Put / Straddle toggle, ITM/ATM/OTM badges, Greeks & 1-click 35-demat replication
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
        'presetCalls': {8150: 314.80, 8200: 287.30, 8250: 264.70, 8300: 241.70, 8350: 217.40},
      },
      {
        'tabName': 'Natural Gas',
        'symbol': 'NATURALGAS',
        'unit': '1250 mmBtu',
        'lot': 1250,
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
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Gold',
        'symbol': 'GOLD',
        'unit': '1 Kg',
        'lot': 1,
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
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Silver',
        'symbol': 'SILVER',
        'unit': '30 Kg',
        'lot': 30,
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
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Crude Oil Mini',
        'symbol': 'CRUDEOILM',
        'unit': '10 bbl',
        'lot': 10,
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
        'presetCalls': {8150: 316.20, 8200: 288.50, 8250: 265.10, 8300: 242.40, 8350: 218.00},
      },
      {
        'tabName': 'Gold Mini',
        'symbol': 'GOLDM',
        'unit': '100 g',
        'lot': 100,
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
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Silver Mini',
        'symbol': 'SILVERM',
        'unit': '5 Kg',
        'lot': 5,
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
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Copper',
        'symbol': 'COPPER',
        'unit': '2500 Kg',
        'lot': 2500,
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
        'presetCalls': <int, double>{},
      },
      {
        'tabName': 'Zinc',
        'symbol': 'ZINC',
        'unit': '5000 Kg',
        'lot': 5000,
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
    final parts = val.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    if (intPart.length <= 3) return '$intPart.$decPart';
    final last3 = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final reg = RegExp(r'\B(?=(\d{2})+(?!\d))');
    return '${rest.replaceAll(reg, ',')},$last3.$decPart';
  }

  String _expiryFutDate() {
    switch (_selectedExpiry) {
      case 'Dec':
        return '18-Dec-26';
      case 'Jan':
        return '20-Jan-27';
      default:
        return '19-Nov-26';
    }
  }

  String _expiryOptDate() {
    switch (_selectedExpiry) {
      case 'Dec':
        return '16-Dec-26';
      case 'Jan':
        return '18-Jan-27';
      default:
        return '17-Nov-26';
    }
  }

  double _expiryMultiplier() {
    switch (_selectedExpiry) {
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
      // CE calculations
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

      // PE calculations
      final peIntrinsic = math.max(0.0, strike - spot);
      final peLtp = double.parse((peIntrinsic + baseTimeVal * 0.96).toStringAsFixed(2));
      final peChg = double.parse((-(peLtp * 0.031)).toStringAsFixed(2));
      final peChgPct = double.parse(((peChg / math.max(1.0, peLtp - peChg)) * 100).toStringAsFixed(2));
      final peDelta = double.parse((-0.50 - (offset * 0.09)).clamp(-0.88, -0.12).toStringAsFixed(2));
      final peMoneyness = strike > spot + (step * 0.4)
          ? 'ITM'
          : (strike < spot - (step * 0.4) ? 'OTM' : 'ATM');

      rows.add({
        'symbol': sym,
        'strike': strike,
        'ceMoneyness': ceMoneyness,
        'peMoneyness': peMoneyness,
        'ceLtp': ceLtp,
        'ceChg': ceChg,
        'ceChgPct': ceChgPct,
        'ceDelta': ceDelta,
        'ceOi': '${(14.2 + (offset + 4) * 3.1).toStringAsFixed(1)}L',
        'ceVol': '${(18.4 - offset.abs() * 2.1).toStringAsFixed(1)}K',
        'ceIv': '${(ivBase - offset * 0.5).toStringAsFixed(1)}%',
        'peLtp': peLtp,
        'peChg': peChg,
        'peChgPct': peChgPct,
        'peDelta': peDelta,
        'peOi': '${(29.8 - (offset + 3) * 2.4).clamp(4.0, 45.0).toStringAsFixed(1)}L',
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
    final spot = (c['spot'] as num).toDouble() * _expiryMultiplier();
    final prevClose = (c['prevClose'] as num).toDouble() * _expiryMultiplier();
    final diff = spot - prevClose;
    final chgPct = (diff / prevClose) * 100;
    final isUp = diff >= 0;
    final flash = c['flash'] as int;
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
                // ── 1. Institutional Commodity Header & Search Bar ────────────
                _buildTopHeader(isDark, borderCol, textSub),

                // ── 2. Global Commodities Benchmark Strip ─────────────────────
                _buildGlobalCommoditiesStrip(isDark, borderCol, textSub),

                // ── 3. Horizontal Commodity Selector Tabs (Crude Oil, Natural Gas, Gold, Silver...) ──
                _buildCommodityTabsBar(isDark, cardBg, borderCol, textMain, textSub),

                // ── 4. Exchange & Expiry Filter Bar + Main Content ────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildExchangeAndExpiryBar(isDark, cardBg, borderCol, textMain, textSub, sym, tabName, spot, lot, unit, c['pcr'] as double),
                      const SizedBox(height: 18),

                      // Future Chain Card (Matching & Elevating Image Design)
                      _buildFutureChainCard(
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
                        high: (c['high'] as num).toDouble(),
                        low: (c['low'] as num).toDouble(),
                        oi: c['oi'] as String,
                        vol: c['vol'] as String,
                      ),
                      const SizedBox(height: 20),

                      // Options Watchlist Section (Matching Call/Put Toggle & ITM/ATM/OTM Strikes)
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

  Widget _buildTopHeader(bool isDark, Color borderCol, Color textSub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B132B) : const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
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
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.4),
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
                    'Future Chain, Options Watchlist (ITM/ATM/OTM Greeks) & Instant Multi-Demat MCX Replication',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          // Quick Strike Search + Connected Demats Pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Filter strike e.g. 8250...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF38BDF8)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_rounded, color: Color(0xFF38BDF8), size: 14),
                        const SizedBox(width: 6),
                        Text('$count Demats Synced', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w900)),
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
                        '₹${_formatIndianPrice(spot)} ${isUp ? '▲' : '▼'}',
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
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          // Left: Exchange Toggle (MCX | NSE)
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

          // Center Telemetry Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderCol),
            ),
            child: Text(
              '$tabName ($sym) · Lot: $unit · Spot PCR: $pcr',
              style: TextStyle(color: textSub, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),

          // Right: Expiry Toggle (Nov | Dec | Jan)
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
  }) {
    final futContract = '$sym $_selectedExpiry FUT ($_selectedExchange)';
    final bid = spot - math.max(0.5, spot * 0.00015);
    final ask = spot + math.max(0.5, spot * 0.00015);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
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
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text('$_selectedExchange · $unit', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                    const Spacer(),
                    Text('Exp: ${_expiryFutDate()}', style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),

                // Main Contract Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sym, style: TextStyle(color: textMain, fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            '${_expiryFutDate()}  ·  Bid ₹${_formatIndianPrice(bid)} | Ask ₹${_formatIndianPrice(ask)}  ·  OI: $oi · Vol: $vol',
                            style: TextStyle(color: textSub, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Day High: ₹${_formatIndianPrice(high)}   ·   Day Low: ₹${_formatIndianPrice(low)}',
                            style: TextStyle(color: textSub, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    // Flashing Price & Change
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                            style: TextStyle(
                              color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${isUp ? '+' : ''}₹${diff.toStringAsFixed(2)} (${isUp ? '+' : ''}${chgPct.toStringAsFixed(2)}%)',
                            style: TextStyle(
                              color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Direct Execution Action Buttons
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                OrderPlacementTicketDialog.show(
                                  context,
                                  symbol: futContract,
                                  side: 'BUY',
                                  ltp: spot,
                                  lotSize: lot,
                                  category: 'COMMODITY',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              child: const Text('BUY FUT', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                OrderPlacementTicketDialog.show(
                                  context,
                                  symbol: futContract,
                                  side: 'SELL',
                                  ltp: spot,
                                  lotSize: lot,
                                  category: 'COMMODITY',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              child: const Text('SELL FUT', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () {
                            final count = CopyTradingEngine().totalAccountsCount;
                            CopyTradingEngine().replicateTrade(symbol: futContract, side: 'BUY', baseQty: lot, price: spot);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚡ Replicated $futContract across all $count Connected Demats!'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          },
                          icon: const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF10B981)),
                          label: Text(
                            'Copy across ${CopyTradingEngine().totalAccountsCount} Demats',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: borderCol),

          // Angel One-Inspired Split Action Strip: CHARTS | OPTION CHAIN
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showCommodityChartModal(context, sym, spot, isDark),
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
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Call / Put / Straddle toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
              child: Center(
                child: Text('No strikes matching "$_strikeFilter"', style: TextStyle(color: textSub, fontSize: 13)),
              ),
            )
          else
            Column(
              children: strikes.expand((row) {
                final List<Widget> widgets = [];
                if (_optionTypeMode == 'CALL' || _optionTypeMode == 'BOTH') {
                  widgets.add(_buildOptionStrikeTile(
                    row: row,
                    isCall: true,
                    sym: sym,
                    lot: lot,
                    isDark: isDark,
                    borderCol: borderCol,
                    textMain: textMain,
                    textSub: textSub,
                  ));
                }
                if (_optionTypeMode == 'PUT' || _optionTypeMode == 'BOTH') {
                  widgets.add(_buildOptionStrikeTile(
                    row: row,
                    isCall: false,
                    sym: sym,
                    lot: lot,
                    isDark: isDark,
                    borderCol: borderCol,
                    textMain: textMain,
                    textSub: textSub,
                  ));
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
        border: Border.all(
          color: moneyness == 'ATM' ? const Color(0xFFF59E0B).withOpacity(0.55) : borderCol,
        ),
      ),
      child: Row(
        children: [
          // Left: Contract & ITM/ATM/OTM badge + Expiry & Strike
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
                      decoration: BoxDecoration(
                        color: (isCall ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        optType,
                        style: TextStyle(color: isCall ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_expiryOptDate()}  $strike $optType   ·   OI: $oi  ·  Vol: $vol  ·  IV: $iv  ·  Δ $delta',
                  style: TextStyle(color: textSub, fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Middle-Right: Live LTP & Change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${_formatIndianPrice(ltp)} ${isUp ? '▲' : '▼'}',
                style: TextStyle(
                  color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${isUp ? '+' : ''}₹${chg.toStringAsFixed(2)} (${isUp ? '+' : ''}${chgPct.toStringAsFixed(2)}%)',
                style: TextStyle(
                  color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Direct Execution Buttons ([B], [S], [⚡ Copy])
          InkWell(
            onTap: () {
              OrderPlacementTicketDialog.show(
                context,
                symbol: fullContract,
                side: 'BUY',
                ltp: ltp,
                lotSize: lot,
                category: 'COMMODITY',
              );
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
              OrderPlacementTicketDialog.show(
                context,
                symbol: fullContract,
                side: 'SELL',
                ltp: ltp,
                lotSize: lot,
                category: 'COMMODITY',
              );
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
            message: 'Replicate across all ${CopyTradingEngine().totalAccountsCount} connected demats',
            child: InkWell(
              onTap: () {
                final count = CopyTradingEngine().totalAccountsCount;
                CopyTradingEngine().replicateTrade(symbol: fullContract, side: 'BUY', baseQty: lot, price: ltp);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('⚡ Replicated $fullContract across $count Connected Demats!'), backgroundColor: const Color(0xFF059669)),
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

  // ── Interactive Commodity Chart Modal ──
  void _showCommodityChartModal(BuildContext context, String sym, double spot, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
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
                    Text('$sym ($_selectedExchange $_selectedExpiry) · Live Technical Chart',
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 220,
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
                          Text('LTP: ₹${_formatIndianPrice(spot)}  |  EMA(20): ₹${_formatIndianPrice(spot * 0.994)}  |  VWAP: ₹${_formatIndianPrice(spot * 0.996)}',
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                          const Text('SUPERTREND (10,3): BULLISH BUY 🟢', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const Spacer(),
                      CustomPaint(
                        size: const Size(double.infinity, 130),
                        painter: _CommoditySparklinePainter(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Full Dual-Side MCX Option Chain Modal ──
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
          constraints: const BoxConstraints(maxWidth: 880, maxHeight: 640),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Expanded(child: Text('CALL OI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
                      Expanded(child: Text('CALL LTP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF10B981)))),
                      Expanded(child: Text('STRIKE', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
                      Expanded(child: Text('PUT LTP', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)))),
                      Expanded(child: Text('PUT OI', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
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
                      final isAtm = r['ceMoneyness'] == 'ATM';

                      return Container(
                        color: isAtm ? const Color(0xFFF59E0B).withOpacity(0.12) : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text('${r['ceOi']}', style: const TextStyle(fontSize: 12))),
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
                                isAtm ? '$strike (ATM)' : '$strike',
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
                            Expanded(child: Text('${r['peOi']}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
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
  @override
  void paint(Canvas canvas, Size size) {
    final pts = [0.65, 0.58, 0.62, 0.52, 0.48, 0.54, 0.42, 0.36, 0.40, 0.28, 0.22, 0.16];
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < pts.length; i++) {
      final x = (i / (pts.length - 1)) * size.width;
      final y = pts[i] * size.height;
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
        colors: [const Color(0xFF10B981).withOpacity(0.35), const Color(0xFF10B981).withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
