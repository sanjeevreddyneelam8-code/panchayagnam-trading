import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../reusable_widets/order_placement_ticket_dialog.dart';
import '../../../service/copy_trading_engine.dart';
import '../../../service/theme_mode_service.dart';

/// TradeMarketStockGroView
/// Panchayagnam Trade Market • Institutional Alpha Hub & Quantitative Trading Floor
///
/// Upgraded for maximum client clarity & visual impact:
/// - Real-time 1.1s live tick engine across Benchmark Indices, SEBI Alpha Calls, Movers & Paper Portfolio
/// - Live Index Sparkline Strip (NIFTY 50, BANK NIFTY, FINNIFTY, SENSEX, INDIA VIX, MIDCAP NIFTY)
/// - Clickable Sector Performance Treemap + Visual Strike OI Wall & Smart Money Flow
/// - Price Ladder Progress Trackers (SL -> Entry -> Live LTP -> Target 1 -> Target 2)
/// - Multi-mode Movers (Gainers, Volume Shockers, Losers, 52W Breakouts) with live sparklines
/// - Interactive Virtual Practice Composer (₹10,00,000 Paper Capital) with live MTM P&L
class TradeMarketStockGroView extends StatefulWidget {
  final int initialTabIndex;
  const TradeMarketStockGroView({super.key, this.initialTabIndex = 0});

  @override
  State<TradeMarketStockGroView> createState() => _TradeMarketStockGroViewState();
}

class _TradeMarketStockGroViewState extends State<TradeMarketStockGroView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final math.Random _rand = math.Random();
  Timer? _tickTimer;
  DateTime _now = DateTime.now();

  // Filters
  String _selectedTradeCategory = 'ALL';
  String _tradeSearchQuery = '';
  String _selectedMoverTab = 'GAINERS';
  String _moverSearchQuery = '';

  // Live Index Cards State
  late List<Map<String, dynamic>> _liveIndices;

  // Live Alpha Calls State
  late List<Map<String, dynamic>> _alphaCalls;

  // Live Market Movers State
  late List<Map<String, dynamic>> _allMovers;

  // Virtual Wallet & Paper Composer State
  double _virtualCapital = 1000000.0;
  String _paperSymbol = 'NIFTY 24250 CE';
  int _paperQty = 50;
  final List<Map<String, dynamic>> _virtualPositions = [
    {
      'symbol': 'NIFTY 24200 CE',
      'type': 'OPT NFO',
      'qty': 100,
      'avg': 210.00,
      'ltp': 228.40,
      'isUp': true,
    },
    {
      'symbol': 'TATASTEEL',
      'type': 'EQ NSE',
      'qty': 500,
      'avg': 186.40,
      'ltp': 194.50,
      'isUp': true,
    },
    {
      'symbol': 'BANKNIFTY 51800 PE',
      'type': 'OPT NFO',
      'qty': 60,
      'avg': 378.10,
      'ltp': 395.20,
      'isUp': true,
    },
    {
      'symbol': 'RELIANCE',
      'type': 'EQ NSE',
      'qty': 100,
      'avg': 2920.00,
      'ltp': 2948.50,
      'isUp': true,
    },
    {
      'symbol': 'PERSISTENT',
      'type': 'EQ NSE',
      'qty': 40,
      'avg': 5410.00,
      'ltp': 5490.00,
      'isUp': true,
    },
  ];

  // AI Copilot Query State
  final TextEditingController _aiQueryController = TextEditingController();
  String _aiResponseSymbol = 'NIFTY 24200 CE';
  String _aiResponseText =
      'Panchayagnam AI Analysis: NIFTY 24,200 strike exhibits heavy Call Unwinding with 2.8M shares shed in intraday trading. PCR shifted from 0.88 to 1.18, signaling high-probability continuation towards 24,350. Support established firmly at 24,100.';
  String _aiStrategyAction = 'BUY BULL CALL SPREAD';
  double _aiConfidence = 0.94;
  bool _isAiThinking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 6),
    );
    _initMarketData();
    _startLiveTickEngine();
  }

  void _initMarketData() {
    _liveIndices = [
      {
        'name': 'NIFTY 50',
        'price': 24218.65,
        'prev': 24092.40,
        'pcr': '1.18',
        'spark': [0.72, 0.68, 0.61, 0.64, 0.52, 0.46, 0.49, 0.35, 0.28, 0.22],
        'lot': 25,
      },
      {
        'name': 'BANK NIFTY',
        'price': 51842.30,
        'prev': 51510.15,
        'pcr': '1.12',
        'spark': [0.76, 0.70, 0.72, 0.58, 0.50, 0.53, 0.41, 0.36, 0.29, 0.24],
        'lot': 15,
      },
      {
        'name': 'FINNIFTY',
        'price': 23945.80,
        'prev': 23812.00,
        'pcr': '1.09',
        'spark': [0.68, 0.65, 0.58, 0.55, 0.48, 0.44, 0.39, 0.35, 0.30, 0.25],
        'lot': 25,
      },
      {
        'name': 'SENSEX',
        'price': 79845.10,
        'prev': 79412.50,
        'pcr': '1.15',
        'spark': [0.74, 0.69, 0.63, 0.59, 0.54, 0.47, 0.42, 0.34, 0.31, 0.20],
        'lot': 10,
      },
      {
        'name': 'MIDCAP NIFTY',
        'price': 12684.45,
        'prev': 12540.90,
        'pcr': '1.24',
        'spark': [0.80, 0.71, 0.64, 0.60, 0.49, 0.43, 0.37, 0.30, 0.22, 0.16],
        'lot': 50,
      },
      {
        'name': 'INDIA VIX',
        'price': 14.22,
        'prev': 14.40,
        'pcr': 'COOL',
        'spark': [0.25, 0.30, 0.35, 0.33, 0.44, 0.48, 0.52, 0.58, 0.63, 0.68],
        'lot': 1,
      },
    ];

    _alphaCalls = [
      {
        'symbol': 'NIFTY 24DEC 24200 CE',
        'type': 'EXPIRY GAMMA BLAST',
        'category': 'OPTIONS',
        'entry': 214.65,
        'tgt1': 245.0,
        'tgt2': 280.0,
        'sl': 175.0,
        'ltp': 228.40,
        'rr': '1 : 2.4',
        'score': '94% QUANT SCORE',
        'analyst': 'Panchayagnam Institutional Desk (SEBI Regd. INH000012891)',
        'rationale': 'Heavy call unwinding at 24,200 strike + 3.5x metal sector momentum. 2.8M contracts covered.',
        'lot': 25,
      },
      {
        'symbol': 'TATASTEEL',
        'type': 'SWING BREAKOUT',
        'category': 'EQUITY',
        'entry': 190.20,
        'tgt1': 202.0,
        'tgt2': 215.0,
        'sl': 181.0,
        'ltp': 194.50,
        'rr': '1 : 2.7',
        'score': '91% QUANT SCORE',
        'analyst': 'Panchayagnam Research Desk (SEBI Regd. INH000008432)',
        'rationale': 'Multi-week consolidation breakout above 188 on 3.2x 20-DMA volume surge. Fresh buyer buildup.',
        'lot': 1,
      },
      {
        'symbol': 'BANKNIFTY 51800 PE',
        'type': 'MEAN REVERSION HEDGE',
        'category': 'OPTIONS',
        'entry': 378.10,
        'tgt1': 420.0,
        'tgt2': 475.0,
        'sl': 310.0,
        'ltp': 395.20,
        'rr': '1 : 2.5',
        'score': '88% QUANT SCORE',
        'analyst': 'Derivatives Alpha Desk (SEBI Regd. INH000015674)',
        'rationale': 'Rejection at 52,000 round number resistance + high put IV spike. Risk hedged.',
        'lot': 15,
      },
      {
        'symbol': 'PERSISTENT',
        'type': 'TECH MOMENTUM',
        'category': 'EQUITY',
        'entry': 5410.0,
        'tgt1': 5680.0,
        'tgt2': 5950.0,
        'sl': 5220.0,
        'ltp': 5490.0,
        'rr': '1 : 2.8',
        'score': '92% QUANT SCORE',
        'analyst': 'Panchayagnam Institutional Desk (SEBI Regd. INH000012891)',
        'rationale': 'Fresh all-time high continuation after strong Q2 guidance and heavy FII block accumulation.',
        'lot': 1,
      },
      {
        'symbol': 'NIFTY DEC FUT',
        'type': 'VWAP TREND CONTINUATION',
        'category': 'FUTURES',
        'entry': 24180.0,
        'tgt1': 24340.0,
        'tgt2': 24520.0,
        'sl': 24060.0,
        'ltp': 24255.0,
        'rr': '1 : 2.8',
        'score': '93% QUANT SCORE',
        'analyst': 'Panchayagnam Institutional Desk (SEBI Regd. INH000012891)',
        'rationale': 'Sustained institutional VWAP reclaim with positive FII index futures net long rollover (+68.4%).',
        'lot': 25,
      },
      {
        'symbol': 'HDFCBANK 1740 CE',
        'type': 'BULL CALL SPREAD',
        'category': 'OPTIONS',
        'entry': 26.50,
        'tgt1': 34.0,
        'tgt2': 42.0,
        'sl': 19.5,
        'ltp': 29.10,
        'rr': '1 : 2.2',
        'score': '89% QUANT SCORE',
        'analyst': 'Derivatives Alpha Desk (SEBI Regd. INH000015674)',
        'rationale': 'Heavy put writing at 1,720 support floor with positive MACD golden crossover.',
        'lot': 550,
      },
      {
        'symbol': 'DIXON',
        'type': 'SUPERTREND BREAKOUT',
        'category': 'EQUITY',
        'entry': 14850.0,
        'tgt1': 15600.0,
        'tgt2': 16400.0,
        'sl': 14300.0,
        'ltp': 15120.0,
        'rr': '1 : 2.8',
        'score': '90% QUANT SCORE',
        'analyst': 'Panchayagnam Research Desk (SEBI Regd. INH000008432)',
        'rationale': 'Bullish Supertrend flip on daily timeframe with sustained institutional delivery > 62%.',
        'lot': 1,
      },
    ];

    _allMovers = [
      {'symbol': 'ZOMATO', 'sector': 'New Age Tech', 'ltp': 268.20, 'prev': 255.80, 'vol': '4.8x 20-DMA', 'delivery': '58.9%', 'vwap': 262.40, 'low': 256.10, 'high': 271.40, 'tag': 'SHOCKER', '52w': true, 'spark': [0.85, 0.78, 0.72, 0.65, 0.54, 0.42, 0.35, 0.24, 0.18]},
      {'symbol': 'COFORGE', 'sector': 'IT Services', 'ltp': 7820.00, 'prev': 7508.40, 'vol': '4.2x 20-DMA', 'delivery': '62.0%', 'vwap': 7740.00, 'low': 7520.00, 'high': 7865.00, 'tag': 'SHOCKER', '52w': true, 'spark': [0.82, 0.74, 0.69, 0.55, 0.48, 0.41, 0.32, 0.21, 0.15]},
      {'symbol': 'TRENT', 'sector': 'Retail', 'ltp': 7120.00, 'prev': 6859.30, 'vol': '3.4x 20-DMA', 'delivery': '66.1%', 'vwap': 7040.00, 'low': 6890.00, 'high': 7165.00, 'tag': 'SHOCKER', '52w': true, 'spark': [0.78, 0.70, 0.62, 0.58, 0.46, 0.38, 0.29, 0.24, 0.16]},
      {'symbol': 'PERSISTENT', 'sector': 'IT & Software', 'ltp': 5490.00, 'prev': 5323.90, 'vol': '2.9x 20-DMA', 'delivery': '71.4%', 'vwap': 5430.00, 'low': 5340.00, 'high': 5518.00, 'tag': 'GAINER', '52w': true, 'spark': [0.76, 0.66, 0.59, 0.51, 0.44, 0.36, 0.28, 0.22, 0.14]},
      {'symbol': 'DIXON', 'sector': 'EMS / Electronics', 'ltp': 15120.00, 'prev': 14765.60, 'vol': '3.1x 20-DMA', 'delivery': '59.3%', 'vwap': 14980.00, 'low': 14805.00, 'high': 15190.00, 'tag': 'GAINER', '52w': true, 'spark': [0.80, 0.72, 0.64, 0.55, 0.47, 0.40, 0.30, 0.25, 0.18]},
      {'symbol': 'TATASTEEL', 'sector': 'Metals', 'ltp': 194.50, 'prev': 190.20, 'vol': '3.8x 20-DMA', 'delivery': '64.2%', 'vwap': 192.10, 'low': 189.80, 'high': 195.60, 'tag': 'SHOCKER', '52w': false, 'spark': [0.75, 0.68, 0.60, 0.53, 0.49, 0.40, 0.34, 0.27, 0.21]},
      {'symbol': 'RELIANCE', 'sector': 'Energy / Telecom', 'ltp': 2948.50, 'prev': 2915.80, 'vol': '1.8x 20-DMA', 'delivery': '68.5%', 'vwap': 2932.00, 'low': 2912.00, 'high': 2956.00, 'tag': 'GAINER', '52w': false, 'spark': [0.72, 0.66, 0.61, 0.54, 0.48, 0.44, 0.38, 0.30, 0.26]},
      {'symbol': 'ITC', 'sector': 'FMCG', 'ltp': 478.20, 'prev': 485.90, 'vol': '1.5x 20-DMA', 'delivery': '54.1%', 'vwap': 481.40, 'low': 476.80, 'high': 486.50, 'tag': 'LOSER', '52w': false, 'spark': [0.22, 0.28, 0.34, 0.42, 0.51, 0.58, 0.67, 0.74, 0.80]},
      {'symbol': 'NESTLEIND', 'sector': 'FMCG', 'ltp': 2248.00, 'prev': 2292.00, 'vol': '1.7x 20-DMA', 'delivery': '52.8%', 'vwap': 2266.00, 'low': 2240.00, 'high': 2295.00, 'tag': 'LOSER', '52w': false, 'spark': [0.20, 0.26, 0.33, 0.40, 0.48, 0.55, 0.62, 0.70, 0.78]},
      {'symbol': 'INDUSINDBK', 'sector': 'Private Banks', 'ltp': 1038.40, 'prev': 1064.20, 'vol': '2.4x 20-DMA', 'delivery': '46.2%', 'vwap': 1049.00, 'low': 1033.00, 'high': 1068.00, 'tag': 'LOSER', '52w': false, 'spark': [0.18, 0.25, 0.38, 0.45, 0.52, 0.61, 0.68, 0.76, 0.84]},
    ];
  }

  void _startLiveTickEngine() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();

        for (final idx in _liveIndices) {
          final p = (idx['price'] as num).toDouble();
          final scale = math.max(0.02, p * 0.00035);
          final delta = (_rand.nextDouble() - 0.485) * scale * 2;
          final nextP = double.parse(math.max(1.0, p + delta).toStringAsFixed(2));
          idx['price'] = nextP;
          final spark = List<double>.from(idx['spark'] as List);
          spark.removeAt(0);
          spark.add((spark.last + (delta >= 0 ? -0.05 : 0.05)).clamp(0.10, 0.88));
          idx['spark'] = spark;
        }

        for (final call in _alphaCalls) {
          final ltp = (call['ltp'] as num).toDouble();
          final step = math.max(0.05, ltp * 0.0012);
          final delta = (_rand.nextDouble() - 0.47) * step;
          call['ltp'] = double.parse(math.max(0.5, ltp + delta).toStringAsFixed(2));
        }

        for (final m in _allMovers) {
          final ltp = (m['ltp'] as num).toDouble();
          final step = math.max(0.05, ltp * 0.0008);
          final delta = (_rand.nextDouble() - 0.485) * step;
          final nextP = double.parse(math.max(1.0, ltp + delta).toStringAsFixed(2));
          m['ltp'] = nextP;
          m['high'] = math.max((m['high'] as num).toDouble(), nextP);
          m['low'] = math.min((m['low'] as num).toDouble(), nextP);
        }

        for (final pos in _virtualPositions) {
          final ltp = (pos['ltp'] as num).toDouble();
          final step = math.max(0.1, ltp * 0.0015);
          final delta = (_rand.nextDouble() - 0.47) * step;
          pos['ltp'] = double.parse(math.max(0.5, ltp + delta).toStringAsFixed(2));
          final avg = (pos['avg'] as num).toDouble();
          pos['isUp'] = (pos['ltp'] as double) >= avg;
        }
      });
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tabController.dispose();
    _aiQueryController.dispose();
    super.dispose();
  }

  int _activeBrokerCount(CopyTradingEngine engine) {
    final active = engine.childAccounts.where((a) => a.isActive).length;
    return active > 0 ? active : engine.totalAccountsCount;
  }

  String _formatIndian(double val) {
    final absStr = val.abs().toStringAsFixed(2).split('.');
    final intPart = absStr[0];
    final decPart = absStr[1];
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

  @override
  Widget build(BuildContext context) {
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
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Institutional Top Header (Dynamic 35-Broker Count)
              _buildInstitutionalHeader(isDark, borderCol),

              // 2. Real-Time Telemetry Bar (Breadth, FII/DII, PCR, VIX, Clock)
              _buildMarketTelemetryStrip(isDark, borderCol),

              // 3. Navigation Tab Bar
              Container(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF10B981),
                  unselectedLabelColor: textSub,
                  indicatorColor: const Color(0xFF10B981),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard_customize_rounded, size: 17), text: 'Market Overview & Radar'),
                    Tab(icon: Icon(Icons.local_fire_department_rounded, size: 17), text: 'Alpha Trade Ideas (SEBI)'),
                    Tab(icon: Icon(Icons.query_stats_rounded, size: 17), text: 'Market Movers & Shockers'),
                    Tab(icon: Icon(Icons.manage_search_rounded, size: 17), text: 'Quant Scanners (Breakouts)'),
                    Tab(icon: Icon(Icons.smart_toy_rounded, size: 17), text: 'Panchayagnam AI Copilot'),
                    Tab(icon: Icon(Icons.emoji_events_rounded, size: 17), text: 'Alpha Leagues & Star Traders'),
                    Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 17), text: 'Virtual Practice (₹10L)'),
                  ],
                ),
              ),
              Divider(height: 1, color: borderCol),

              // 4. Expanded Tab Body (smooth single-scroll inside every tab!)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMarketOverviewTab(isDark, cardBg, borderCol, textMain, textSub),
                    _buildTradeIdeasTab(isDark, cardBg, borderCol, textMain, textSub),
                    _buildMarketMoversTab(isDark, cardBg, borderCol, textMain, textSub),
                    _buildQuantScannersTab(isDark, cardBg, borderCol, textMain, textSub),
                    _buildAICopilotTab(isDark, cardBg, borderCol, textMain, textSub),
                    _buildLeaguesAndTradersTab(isDark, cardBg, borderCol, textMain, textSub),
                    _buildVirtualPracticeTab(isDark, cardBg, borderCol, textMain, textSub),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 1. Institutional Top Header ──
  Widget _buildInstitutionalHeader(bool isDark, Color borderCol) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withOpacity(0.32), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              AnimatedBuilder(
                animation: CopyTradingEngine(),
                builder: (context, _) {
                  final brokerCount = CopyTradingEngine().totalAccountsCount;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'PANCHAYAGNAM TRADE MARKET',
                            style: TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 13),
                                SizedBox(width: 4),
                                Text(
                                  'INSTITUTIONAL ALPHA FLOOR',
                                  style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Real-Time Quant Radar • SEBI Verified Alpha Calls • $brokerCount-Broker Instant Copy Execution',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),

          // Right Live Badges
          AnimatedBuilder(
            animation: CopyTradingEngine(),
            builder: (context, _) {
              final count = CopyTradingEngine().totalAccountsCount;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'NSE/BSE Tick: 11ms · ${DateFormat('HH:mm:ss').format(_now)}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_rounded, color: Color(0xFF38BDF8), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '$count Brokers Synchronized',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 2. Live Market Telemetry Bar ──
  Widget _buildMarketTelemetryStrip(bool isDark, Color borderCol) {
    final vix = (_liveIndices[5]['price'] as num).toDouble();
    final vixPrev = (_liveIndices[5]['prev'] as num).toDouble();
    final vixPct = ((vix - vixPrev) / vixPrev) * 100;
    final niftySpot = (_liveIndices[0]['price'] as num).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTelemetryBadge(
              icon: Icons.pie_chart_rounded,
              label: 'Market Breadth',
              val: '1,438 Adv / 782 Dec (A/D 1.84)',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            _buildTelemetryDivider(isDark),
            _buildTelemetryBadge(
              icon: Icons.account_balance_rounded,
              label: 'FII Net Cash',
              val: '+₹1,842.30 Cr',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            _buildTelemetryDivider(isDark),
            _buildTelemetryBadge(
              icon: Icons.domain_rounded,
              label: 'DII Net Cash',
              val: '+₹2,105.00 Cr',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            _buildTelemetryDivider(isDark),
            _buildTelemetryBadge(
              icon: Icons.speed_rounded,
              label: 'NIFTY PCR',
              val: '1.18 (Bullish Control)',
              color: const Color(0xFF38BDF8),
              isDark: isDark,
            ),
            _buildTelemetryDivider(isDark),
            _buildTelemetryBadge(
              icon: Icons.track_changes_rounded,
              label: 'Max Pain Strike',
              val: '24,150',
              color: const Color(0xFFF59E0B),
              isDark: isDark,
            ),
            _buildTelemetryDivider(isDark),
            _buildTelemetryBadge(
              icon: Icons.graphic_eq_rounded,
              label: 'India VIX',
              val: '${vix.toStringAsFixed(2)} (${vixPct >= 0 ? '+' : ''}${vixPct.toStringAsFixed(2)}%)',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            _buildTelemetryDivider(isDark),
            _buildTelemetryBadge(
              icon: Icons.public_rounded,
              label: 'Gift Nifty',
              val: '${_formatIndian(niftySpot + 91.5)} (+91 pts)',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryBadge({
    required IconData icon,
    required String label,
    required String val,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Text(val, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildTelemetryDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text('|', style: TextStyle(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), fontSize: 12)),
    );
  }

  // ── Tab 0: Market Overview & Radar ──
  Widget _buildMarketOverviewTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final heroCall = _alphaCalls.first;
    final heroLtp = (heroCall['ltp'] as num).toDouble();
    final heroEntry = (heroCall['entry'] as num).toDouble();
    final heroPct = ((heroLtp - heroEntry) / heroEntry) * 100;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 0. Live Benchmark Index Sparkline Cards
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Live NSE/BSE Indices & Sparklines', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
            const Text('Click any Index for Instant F&O Ticket', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _liveIndices.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, idx) {
              final item = _liveIndices[idx];
              final name = item['name'] as String;
              final price = (item['price'] as num).toDouble();
              final prev = (item['prev'] as num).toDouble();
              final diff = price - prev;
              final pct = (diff / prev) * 100;
              final isUp = name == 'INDIA VIX' ? diff <= 0 : diff >= 0;
              final accent = isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);
              final pts = (item['spark'] as List).cast<double>();

              return InkWell(
                onTap: () {
                  OrderPlacementTicketDialog.show(
                    context,
                    symbol: '$name FUT',
                    side: 'BUY',
                    ltp: price,
                    lotSize: item['lot'] as int,
                    category: 'F&O',
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 215,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: accent.withOpacity(0.14), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              '${diff >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                              style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatIndian(price),
                                  style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} · PCR ${item['pcr']}',
                                  style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            height: 30,
                            child: CustomPaint(painter: _MiniSparklinePainter(points: pts, color: accent)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 22),

        // 1. Institutional Trading Floor Pillars
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Institutional Trading Floor Pillars', style: TextStyle(color: textMain, fontSize: 16.5, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: const Text('PRO TERMINAL', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth > 900)
                ? (constraints.maxWidth - 32) / 3
                : (constraints.maxWidth > 580)
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                _buildOverviewPillarCard(
                  width: cardWidth,
                  title: 'Alpha Trade Ideas',
                  subtitle: 'SEBI setups with live SL-to-Target ladders',
                  badge: '${_alphaCalls.length} LIVE',
                  badgeColor: const Color(0xFFEA580C),
                  icon: Icons.local_fire_department_rounded,
                  accentColor: const Color(0xFFEA580C),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _tabController.animateTo(1),
                ),
                _buildOverviewPillarCard(
                  width: cardWidth,
                  title: 'Movers & Shockers',
                  subtitle: 'Volume surges (>300%), gainers & 52W highs',
                  badge: '4.8x VOL',
                  badgeColor: const Color(0xFF10B981),
                  icon: Icons.query_stats_rounded,
                  accentColor: const Color(0xFF10B981),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _tabController.animateTo(2),
                ),
                _buildOverviewPillarCard(
                  width: cardWidth,
                  title: 'Quant Scanners',
                  subtitle: 'Supertrend, Gamma squeeze & block delivery',
                  badge: 'LIVE SCAN',
                  badgeColor: const Color(0xFF38BDF8),
                  icon: Icons.manage_search_rounded,
                  accentColor: const Color(0xFF38BDF8),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _tabController.animateTo(3),
                ),
                _buildOverviewPillarCard(
                  width: cardWidth,
                  title: 'AI Quant Copilot',
                  subtitle: 'Instant OI, pivot & multi-leg hedge briefs',
                  badge: 'GEMINI AI',
                  badgeColor: const Color(0xFF6366F1),
                  icon: Icons.smart_toy_rounded,
                  accentColor: const Color(0xFF6366F1),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _tabController.animateTo(4),
                ),
                _buildOverviewPillarCard(
                  width: cardWidth,
                  title: 'Leagues & Star Traders',
                  subtitle: '₹7.5L prize pool & verified 1-click auto copy',
                  badge: '₹7.5L POOL',
                  badgeColor: const Color(0xFFF59E0B),
                  icon: Icons.emoji_events_rounded,
                  accentColor: const Color(0xFFF59E0B),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _tabController.animateTo(5),
                ),
                _buildOverviewPillarCard(
                  width: cardWidth,
                  title: 'Virtual Practice Arena',
                  subtitle: '₹10L paper trading desk with live MTM quotes',
                  badge: 'LIVE MTM',
                  badgeColor: const Color(0xFF10B981),
                  icon: Icons.account_balance_wallet_rounded,
                  accentColor: const Color(0xFF10B981),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _tabController.animateTo(6),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 22),

        // 2. Interactive Sector Treemap & Institutional Strike OI Wall
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 920;
            final sectorWidget = _buildInteractiveSectorTreemap(isDark, cardBg, borderCol, textMain, textSub);
            final smartMoneyWidget = _buildSmartMoneyAndOiWallCard(isDark, cardBg, borderCol, textMain, textSub);

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: sectorWidget),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: smartMoneyWidget),
                ],
              );
            }
            return Column(
              children: [
                sectorWidget,
                const SizedBox(height: 16),
                smartMoneyWidget,
              ],
            );
          },
        ),

        const SizedBox(height: 22),

        // 3. Featured Top Alpha Pick Hero Card (Dynamic 35-Broker Execution)
        AnimatedBuilder(
          animation: CopyTradingEngine(),
          builder: (context, _) {
            final activeCount = _activeBrokerCount(CopyTradingEngine());
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.35)),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.16), shape: BoxShape.circle),
                        child: const Icon(Icons.flash_on_rounded, color: Color(0xFF6366F1), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('TOP ALPHA PICK: ${heroCall['symbol']}', style: TextStyle(color: textMain, fontSize: 15.5, fontWeight: FontWeight.w900)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  '${heroPct >= 0 ? '+' : ''}${heroPct.toStringAsFixed(2)}% IN PROFIT',
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Live LTP: ₹${heroLtp.toStringAsFixed(2)}  •  Entry: ₹${heroEntry.toStringAsFixed(2)}  •  Target 1: ₹${heroCall['tgt1']}  •  SL: ₹${heroCall['sl']}  •  94% Conviction',
                            style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          OrderPlacementTicketDialog.show(
                            context,
                            symbol: heroCall['symbol'] as String,
                            side: 'BUY',
                            ltp: heroLtp,
                            lotSize: heroCall['lot'] as int,
                            category: 'OPTIONS',
                          );
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Order Pad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          CopyTradingEngine().replicateTrade(
                            symbol: heroCall['symbol'] as String,
                            side: 'BUY',
                            baseQty: heroCall['lot'] as int,
                            price: heroLtp,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('⚡ Instant Buy Order Dispatched across all $activeCount Connected Brokers!'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        },
                        icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                        label: Text(
                          '1-Click Execute ($activeCount Brokers)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInteractiveSectorTreemap(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final sectors = [
      {'name': 'Nifty Metal', 'chg': '+2.45%', 'pct': 0.85, 'isUp': true, 'leader': 'TATASTEEL', 'ltp': 194.50, 'ad': '14 Adv / 1 Dec'},
      {'name': 'Nifty IT', 'chg': '+1.85%', 'pct': 0.72, 'isUp': true, 'leader': 'PERSISTENT', 'ltp': 5490.00, 'ad': '9 Adv / 1 Dec'},
      {'name': 'Nifty Auto', 'chg': '+1.40%', 'pct': 0.58, 'isUp': true, 'leader': 'M&M', 'ltp': 3085.00, 'ad': '11 Adv / 4 Dec'},
      {'name': 'Nifty Realty', 'chg': '+0.95%', 'pct': 0.44, 'isUp': true, 'leader': 'DLF', 'ltp': 842.00, 'ad': '8 Adv / 2 Dec'},
      {'name': 'Nifty Bank', 'chg': '+0.62%', 'pct': 0.34, 'isUp': true, 'leader': 'HDFCBANK', 'ltp': 1742.00, 'ad': '8 Adv / 4 Dec'},
      {'name': 'Nifty FMCG', 'chg': '-0.35%', 'pct': 0.25, 'isUp': false, 'leader': 'ITC', 'ltp': 478.20, 'ad': '5 Adv / 10 Dec'},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sector Performance Heatmap', style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
              const Text('Click Sector Leader to Trade', style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: sectors.map((sec) {
              final isUp = sec['isUp'] as bool;
              final col = isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);
              final leader = sec['leader'] as String;
              final ltp = (sec['ltp'] as num).toDouble();

              return InkWell(
                onTap: () {
                  OrderPlacementTicketDialog.show(context, symbol: leader, side: 'BUY', ltp: ltp, lotSize: 1, category: 'EQUITY');
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 175,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: col.withOpacity(isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: col.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(sec['name'] as String, style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: FontWeight.w900)),
                          Text(sec['chg'] as String, style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (sec['pct'] as num).toDouble(),
                          backgroundColor: Colors.grey.withOpacity(0.18),
                          valueColor: AlwaysStoppedAnimation<Color>(col),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Top: $leader (₹${ltp.toStringAsFixed(0)})', style: TextStyle(color: textSub, fontSize: 10, fontWeight: FontWeight.w700)),
                      Text(sec['ad'] as String, style: TextStyle(color: col, fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartMoneyAndOiWallCard(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final oiStrikes = [
      {'strike': '24000', 'ce': 0.25, 'pe': 0.72},
      {'strike': '24100', 'ce': 0.34, 'pe': 0.88},
      {'strike': '24150', 'ce': 0.45, 'pe': 0.65},
      {'strike': '24200', 'ce': 0.56, 'pe': 0.78},
      {'strike': '24300', 'ce': 0.92, 'pe': 0.35},
      {'strike': '24400', 'ce': 0.84, 'pe': 0.18},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Smart Money & Strike OI Wall', style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF38BDF8).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: const Text('FII/DII + NIFTY OI', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // FII / DII Visual Split
          Row(
            children: [
              _miniFlowPill('FII Index Fut', '68.4% Long', const Color(0xFF10B981), isDark),
              const SizedBox(width: 8),
              _miniFlowPill('DII Flow (MTD)', '+₹38,450 Cr', const Color(0xFF10B981), isDark),
              const SizedBox(width: 8),
              _miniFlowPill('Prop Calls', '+42.5K Net', const Color(0xFF38BDF8), isDark),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Strike OI Wall
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PUT WRITERS (SUPPORT)', style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w900)),
              Text('STRIKE', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.w900)),
              Text('CALL WRITERS (RESIST)', style: TextStyle(color: Color(0xFFEF4444), fontSize: 9.5, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          ...oiStrikes.map((row) {
            final strike = row['strike'] as String;
            final pe = row['pe'] as double;
            final ce = row['ce'] as double;
            final isAtm = strike == '24200';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: pe,
                        child: Container(
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            borderRadius: BorderRadius.horizontal(left: Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 58,
                    alignment: Alignment.center,
                    child: Text(
                      strike,
                      style: TextStyle(
                        color: isAtm ? const Color(0xFFF59E0B) : textMain,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ce,
                        child: Container(
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 15),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Strong Put Floor at 24,100 vs Call Wall at 24,300 · Breakout above 24,300 opens 24,500.',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniFlowPill(String label, String val, Color col, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: col.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(val, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewPillarCard({
    required double width,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
    required Color textSub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        height: 110,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(color: textMain, fontSize: 14.5, fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: badgeColor.withOpacity(0.14), borderRadius: BorderRadius.circular(4)),
                        child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: textSub, fontSize: 11.5, height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: accentColor.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: accentColor, size: 21),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Live Institutional Trade Ideas (SEBI & Quant Calls) ──
  Widget _buildTradeIdeasTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final filtered = _alphaCalls.where((c) {
      final catOk = _selectedTradeCategory == 'ALL' || c['category'] == _selectedTradeCategory;
      final q = _tradeSearchQuery.trim().toLowerCase();
      final qOk = q.isEmpty || (c['symbol'] as String).toLowerCase().contains(q) || (c['type'] as String).toLowerCase().contains(q);
      return catOk && qOk;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Performance Summary Banner
        Container(
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
            runSpacing: 10,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildFilterChip('ALL', 'All Calls (${_alphaCalls.length})', isDark),
                  _buildFilterChip('OPTIONS', 'F&O Options', isDark),
                  _buildFilterChip('EQUITY', 'Equities (Cash)', isDark),
                  _buildFilterChip('FUTURES', 'Index Futures', isDark),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 210,
                    height: 34,
                    child: TextField(
                      style: TextStyle(color: textMain, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Filter call e.g. NIFTY...',
                        hintStyle: TextStyle(color: textSub, fontSize: 11.5),
                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF38BDF8)),
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                      ),
                      onChanged: (v) => setState(() => _tradeSearchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                    child: const Text('87.4% 30D HIT RATIO', style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No trade ideas matching filter.', style: TextStyle(color: textSub))),
          )
        else
          ...filtered.map((call) => _buildInstitutionalTradeCard(call, isDark, cardBg, borderCol, textMain, textSub)),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _selectedTradeCategory == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontSize: 12, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: const Color(0xFF10B981),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      onSelected: (_) => setState(() => _selectedTradeCategory = key),
    );
  }

  Widget _buildInstitutionalTradeCard(
    Map<String, dynamic> call,
    bool isDark,
    Color cardBg,
    Color borderCol,
    Color textMain,
    Color textSub,
  ) {
    final sym = call['symbol'] as String;
    final entry = (call['entry'] as num).toDouble();
    final tgt1 = (call['tgt1'] as num).toDouble();
    final tgt2 = (call['tgt2'] as num).toDouble();
    final sl = (call['sl'] as num).toDouble();
    final ltp = (call['ltp'] as num).toDouble();
    final pnlPct = ((ltp - entry) / entry) * 100;
    final isUp = pnlPct >= 0;
    final rr = call['rr'] as String;
    final score = call['score'] as String;
    final analyst = call['analyst'] as String;
    final rationale = call['rationale'] as String;
    final cat = call['category'] as String;
    final lot = (call['lot'] as num).toInt();

    final progress = ((ltp - sl) / math.max(1.0, tgt2 - sl)).clamp(0.05, 0.98);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(sym, style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF38BDF8).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(call['type'] as String, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(score, style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Live LTP: ₹${_formatIndian(ltp)}', style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w900)),
                  Text(
                    '${isUp ? '+' : ''}${pnlPct.toStringAsFixed(2)}% from Entry',
                    style: TextStyle(color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Price Ladder Progress Bar (SL -> Entry -> Live LTP -> T1 -> T2)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderCol.withOpacity(0.6)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCardMetric('Stop Loss', '₹${sl.toStringAsFixed(2)}', const Color(0xFFEF4444), textSub),
                    _buildCardMetric('Entry', '₹${entry.toStringAsFixed(2)}', textMain, textSub),
                    _buildCardMetric('Target 1', '₹${tgt1.toStringAsFixed(2)}', const Color(0xFF10B981), textSub),
                    _buildCardMetric('Target 2', '₹${tgt2.toStringAsFixed(2)}', const Color(0xFF10B981), textSub),
                    _buildCardMetric('Risk:Reward', rr, const Color(0xFF38BDF8), textSub),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.22),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.psychology_rounded, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Expanded(child: Text(rationale, style: TextStyle(color: textSub, fontSize: 12, height: 1.3))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Verified by $analyst', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          AnimatedBuilder(
            animation: CopyTradingEngine(),
            builder: (context, _) {
              final activeCount = _activeBrokerCount(CopyTradingEngine());
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      OrderPlacementTicketDialog.show(context, symbol: sym, side: 'BUY', ltp: ltp, lotSize: lot, category: cat);
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Order Pad'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textMain,
                      side: BorderSide(color: borderCol),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      CopyTradingEngine().replicateTrade(symbol: sym, side: 'BUY', baseQty: lot, price: ltp);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('⚡ Multi-Demat Replication: Placed $sym across $activeCount connected brokers!'),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    },
                    icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                    label: Text('1-Click Execute ($activeCount Brokers)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardMetric(String label, String val, Color valCol, Color textSub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textSub, fontSize: 10.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(color: valCol, fontSize: 12.5, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ── Tab 2: Market Movers & Volume Shockers ──
  Widget _buildMarketMoversTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final displayedList = _allMovers.where((m) {
      final symOk = _moverSearchQuery.trim().isEmpty || (m['symbol'] as String).toLowerCase().contains(_moverSearchQuery.trim().toLowerCase());
      if (!symOk) return false;
      switch (_selectedMoverTab) {
        case 'SHOCKERS':
          return m['tag'] == 'SHOCKER';
        case 'LOSERS':
          return m['tag'] == 'LOSER';
        case '52W':
          return m['52w'] == true;
        default:
          return m['tag'] != 'LOSER';
      }
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _moverChip('GAINERS', 'Top Gainers (NSE)', isDark),
                _moverChip('SHOCKERS', 'Volume Shockers (>300%)', isDark),
                _moverChip('52W', '52-Week High Breakouts', isDark),
                _moverChip('LOSERS', 'Top Losers', isDark),
              ],
            ),
            SizedBox(
              width: 210,
              height: 34,
              child: TextField(
                style: TextStyle(color: textMain, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search mover symbol...',
                  hintStyle: TextStyle(color: textSub, fontSize: 11.5),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF38BDF8)),
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                ),
                onChanged: (v) => setState(() => _moverSearchQuery = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('SYMBOL & SECTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('TREND & LTP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('VOLUME SURGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('DAY RANGE (L–H)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('VWAP & DEL%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('INSTANT EXECUTE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
        const SizedBox(height: 8),

        ...displayedList.map((m) {
          final sym = m['symbol'] as String;
          final sec = m['sector'] as String;
          final ltp = (m['ltp'] as num).toDouble();
          final prev = (m['prev'] as num).toDouble();
          final pct = ((ltp - prev) / prev) * 100;
          final isUp = pct >= 0;
          final col = isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);
          final vol = m['vol'] as String;
          final del = m['delivery'] as String;
          final vwap = (m['vwap'] as num).toDouble();
          final low = (m['low'] as num).toDouble();
          final high = (m['high'] as num).toDouble();
          final rangePos = ((ltp - low) / math.max(0.5, high - low)).clamp(0.05, 0.95);
          final spark = (m['spark'] as List).cast<double>();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol)),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(sym, style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900)),
                          if (m['52w'] == true) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.16), borderRadius: BorderRadius.circular(3)),
                              child: const Text('52W HIGH', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 8.5, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ],
                      ),
                      Text(sec, style: TextStyle(color: textSub, fontSize: 10.5)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('₹${_formatIndian(ltp)}', style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: FontWeight.w900)),
                          Text('${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%', style: TextStyle(color: col, fontSize: 10.5, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        height: 22,
                        child: CustomPaint(painter: _MiniSparklinePainter(points: spark, color: col)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(vol, style: TextStyle(color: col, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: rangePos,
                            minHeight: 5,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(col),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text('L:${low.toStringAsFixed(0)} · H:${high.toStringAsFixed(0)}', style: TextStyle(color: textSub, fontSize: 9.5)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VWAP ₹${vwap.toStringAsFixed(1)}', style: TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('Del: $del', style: TextStyle(color: textSub, fontSize: 10.5)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          OrderPlacementTicketDialog.show(context, symbol: sym, side: 'BUY', ltp: ltp, lotSize: 1, category: 'EQUITY');
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
                        child: const Text('BUY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 5),
                      ElevatedButton(
                        onPressed: () {
                          OrderPlacementTicketDialog.show(context, symbol: sym, side: 'SELL', ltp: ltp, lotSize: 1, category: 'EQUITY');
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: Size.zero),
                        child: const Text('SELL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 5),
                      Tooltip(
                        message: 'Copy across all ${CopyTradingEngine().totalAccountsCount} connected brokers',
                        child: InkWell(
                          onTap: () {
                            final cnt = CopyTradingEngine().totalAccountsCount;
                            CopyTradingEngine().replicateTrade(symbol: sym, side: 'BUY', baseQty: 10, price: ltp);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('⚡ Replicated $sym across all $cnt brokers!'), backgroundColor: const Color(0xFF059669)),
                            );
                          },
                          borderRadius: BorderRadius.circular(5),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                            ),
                            child: const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFF38BDF8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _moverChip(String key, String label, bool isDark) {
    final isSelected = _selectedMoverTab == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontSize: 11.5, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: const Color(0xFF10B981),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      onSelected: (_) => setState(() => _selectedMoverTab = key),
    );
  }

  // ── Tab 3: Quantitative Scanners ──
  Widget _buildQuantScannersTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final scanners = [
      {
        'title': 'Supertrend & EMA 9/21 Golden Crossover',
        'desc': 'Bullish Supertrend flip with 9 EMA cutting 21 EMA from below on daily candles.',
        'tag': 'TREND FOLLOWING',
        'strength': '94% BULLISH',
        'tagCol': const Color(0xFF10B981),
        'results': [
          {'sym': 'TATASTEEL', 'ltp': 194.50, 'chg': '+2.26%'},
          {'sym': 'PERSISTENT', 'ltp': 5490.00, 'chg': '+3.12%'},
          {'sym': 'BHARTIARTL', 'ltp': 1584.00, 'chg': '+1.45%'},
        ],
      },
      {
        'title': 'Gamma Blast & Heavy Call Unwinding',
        'desc': 'Options where call writers are covering in panic, triggering aggressive upside gamma bursts.',
        'tag': 'F&O SQUEEZE',
        'strength': '92% MOMENTUM',
        'tagCol': const Color(0xFFEA580C),
        'results': [
          {'sym': 'NIFTY 24200 CE', 'ltp': 228.40, 'chg': '+18.4%'},
          {'sym': 'COFORGE', 'ltp': 7820.00, 'chg': '+4.15%'},
          {'sym': 'TRENT', 'ltp': 7120.00, 'chg': '+3.80%'},
        ],
      },
      {
        'title': 'RSI Oversold Mean Reversion (< 30 Bounce)',
        'desc': 'Large-cap stocks at oversold extremes turning up with bullish RSI divergence.',
        'tag': 'MEAN REVERSION',
        'strength': '86% BOUNCE',
        'tagCol': const Color(0xFF38BDF8),
        'results': [
          {'sym': 'ASIANPAINT', 'ltp': 2840.00, 'chg': '+1.10%'},
          {'sym': 'LT', 'ltp': 3620.00, 'chg': '+1.80%'},
          {'sym': 'BAJFINANCE', 'ltp': 6890.00, 'chg': '+0.95%'},
        ],
      },
      {
        'title': 'Institutional Block Delivery (> 65% Delivery Vol)',
        'desc': 'Stocks registering abnormal delivery spikes signaling quiet institutional accumulation.',
        'tag': 'SMART MONEY',
        'strength': '91% ACCUMULATION',
        'tagCol': const Color(0xFF8B5CF6),
        'results': [
          {'sym': 'RELIANCE', 'ltp': 2948.50, 'chg': '+1.12%'},
          {'sym': 'ICICIBANK', 'ltp': 1264.00, 'chg': '+0.88%'},
          {'sym': 'TCS', 'ltp': 4180.00, 'chg': '+0.65%'},
        ],
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Automated Quantitative Scanners', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: const Text('ALGORITHMIC SCANNER LIVE', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...scanners.map((sc) {
          final title = sc['title'] as String;
          final desc = sc['desc'] as String;
          final tag = sc['tag'] as String;
          final strength = sc['strength'] as String;
          final tagCol = sc['tagCol'] as Color;
          final results = sc['results'] as List<Map<String, dynamic>>;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, style: TextStyle(color: textMain, fontSize: 14.5, fontWeight: FontWeight.w900))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: tagCol.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(tag, style: TextStyle(color: tagCol, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ),
                    const Spacer(),
                    Text(strength, style: TextStyle(color: tagCol, fontSize: 11, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: textSub, fontSize: 11.5)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: results.map((r) {
                    final sym = r['sym'] as String;
                    final ltp = (r['ltp'] as num).toDouble();
                    final chg = r['chg'] as String;

                    return InkWell(
                      onTap: () {
                        OrderPlacementTicketDialog.show(
                          context,
                          symbol: sym,
                          side: 'BUY',
                          ltp: ltp,
                          lotSize: 1,
                          category: sym.contains('CE') || sym.contains('PE') ? 'OPTIONS' : 'EQUITY',
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderCol),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(sym, style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            Text('₹${_formatIndian(ltp)}', style: TextStyle(color: textMain, fontSize: 11.5)),
                            const SizedBox(width: 6),
                            Text(chg, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 6),
                            const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF10B981)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Tab 4: Panchayagnam AI Quant Copilot ──
  Widget _buildAICopilotTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] : [const Color(0xFFF0FDF4), const Color(0xFFE2E8F0)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PANCHAYAGNAM AI QUANT COPILOT', style: TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        Text('Powered by Live NSE/MCX Telemetry for Institutional Trade Synthesis', style: TextStyle(color: textSub, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aiQueryController,
                style: TextStyle(color: textMain, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ask: "Analyze NIFTY 24200 CE OI" or "Best Crude Oil / BankNifty setup"...',
                  hintStyle: TextStyle(color: textSub, fontSize: 12),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                  suffixIcon: IconButton(
                    icon: _isAiThinking
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                        : const Icon(Icons.send_rounded, color: Color(0xFF10B981)),
                    onPressed: _runAiAnalysis,
                  ),
                ),
                onSubmitted: (_) => _runAiAnalysis(),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildPromptChip('Analyze NIFTY 24200 CE strike OI', isDark),
                  _buildPromptChip('Find High Volume Breakouts in Metals', isDark),
                  _buildPromptChip('Options Delta Hedge for Bank Nifty', isDark),
                  _buildPromptChip('MCX Crude Oil 8250 Straddle Analysis', isDark),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Autonomous Synthesis: $_aiResponseSymbol', style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text('$_aiStrategyAction · ${(_aiConfidence * 100).toStringAsFixed(0)}% CONF', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_aiResponseText, style: TextStyle(color: textMain, fontSize: 13, height: 1.45)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Pivot: 24,180', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    Text('Resistance 1: 24,280', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11.5)),
                    Text('Resistance 2: 24,350', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11.5)),
                    Text('Support: 24,100', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: CopyTradingEngine(),
                builder: (context, _) {
                  final activeCount = _activeBrokerCount(CopyTradingEngine());
                  return Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        CopyTradingEngine().replicateTrade(symbol: _aiResponseSymbol, side: 'BUY', baseQty: 25, price: 214.65);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('⚡ Dispatched AI Recommended $_aiStrategyAction across $activeCount connected brokers!'),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      },
                      icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                      label: Text('Execute AI Setup ($activeCount Brokers)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromptChip(String text, bool isDark) {
    return InkWell(
      onTap: () {
        _aiQueryController.text = text;
        _runAiAnalysis();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _runAiAnalysis() {
    setState(() => _isAiThinking = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isAiThinking = false;
        final q = _aiQueryController.text.toLowerCase();
        if (q.contains('crude') || q.contains('mcx')) {
          _aiResponseSymbol = 'CRUDEOIL 8250 CE + PE';
          _aiResponseText =
              'Panchayagnam AI Analysis: MCX Crude Oil trades near 8,229 ahead of US EIA inventory data. ATM 8250 IV is elevated at 30.2%. High Call OI wall sits at 8,350 with strong Put floor at 8,150. Recommended Short Strangle / Iron Fly or momentum breakout buy above 8,265.';
          _aiStrategyAction = 'DEPLOY MCX IRON FLY';
          _aiConfidence = 0.91;
        } else if (q.contains('metal') || q.contains('tata')) {
          _aiResponseSymbol = 'TATASTEEL';
          _aiResponseText =
              'Panchayagnam AI Analysis: Tata Steel has broken out from a 3-week consolidation cup-and-handle pattern at ₹190.20 on 3.5x 20-DMA volume. RSI is at 64 with upside towards ₹205.00 and trailing SL at ₹185.00.';
          _aiStrategyAction = 'BUY SWING EQUITY';
          _aiConfidence = 0.92;
        } else if (q.contains('bank')) {
          _aiResponseSymbol = 'BANKNIFTY 51800 PE';
          _aiResponseText =
              'Panchayagnam AI Analysis: Bank Nifty faces heavy option resistance near 52,000. Hedged Put Ratio Spread or 51,800 PE swing offers optimal convexity.';
          _aiStrategyAction = 'BUY EXPIRY HEDGE';
          _aiConfidence = 0.89;
        } else {
          _aiResponseSymbol = 'NIFTY 24200 CE';
          _aiResponseText =
              'Panchayagnam AI Analysis: NIFTY 24,200 strike exhibits heavy Call Unwinding with 2.8M shares shed in intraday trading. PCR shifted from 0.88 to 1.18, signaling continuation towards 24,350.';
          _aiStrategyAction = 'BUY BULL CALL SPREAD';
          _aiConfidence = 0.94;
        }
      });
    });
  }

  // ── Tab 5: Alpha Leagues & Star Traders Leaderboard ──
  Widget _buildLeaguesAndTradersTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Active Algorithmic & Alpha Leagues', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: const Text('₹7,50,000 TOTAL PRIZE POOL', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTournamentCard('Panchayagnam Mega Trader League', '₹5,00,000 Cash Pool', '3,420 Active Traders', 'Free Pass', isDark, cardBg, borderCol, textMain, textSub),
        const SizedBox(height: 10),
        _buildTournamentCard('Derivatives Alpha Cup (NSE & MCX)', '₹2,50,000 Cash Pool', '1,890 Active Traders', 'Weekly F&O', isDark, cardBg, borderCol, textMain, textSub),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Verified Star Traders (1-Click Auto Replicate)', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
            const Text('SEBI Regd & Quant Masters', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        _buildStarTraderCard('Rohan_AlphaQuant', '+164.2%', '81.4%', '2.45', '1,420 Demats', 'SEBI Pro · Quant Algo Master', isDark, cardBg, borderCol, textMain, textSub),
        const SizedBox(height: 10),
        _buildStarTraderCard('Priya_OptionsQueen', '+128.5%', '76.8%', '2.18', '980 Demats', 'Weekly F&O Expiry Specialist', isDark, cardBg, borderCol, textMain, textSub),
        const SizedBox(height: 10),
        _buildStarTraderCard('Siddharth_MCXPro', '+112.4%', '74.2%', '2.05', '810 Demats', 'Crude Oil & Gold Intraday Expert', isDark, cardBg, borderCol, textMain, textSub),
      ],
    );
  }

  Widget _buildTournamentCard(String title, String pool, String participants, String tag, bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol)),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(color: textMain, fontSize: 14.5, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(tag, style: const TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('$participants · ₹10L Virtual Portfolio Allocated', style: TextStyle(color: textSub, fontSize: 11.5)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pool, style: const TextStyle(color: Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(width: 14),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Joined $title! ₹10,00,000 Virtual League Account Activated.'), backgroundColor: const Color(0xFF059669)),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                child: const Text('Enter Arena', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarTraderCard(String name, String ret, String win, String sharpe, String copiers, String badge, bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
            child: Text(name.substring(0, 2), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: textMain, fontSize: 14.5, fontWeight: FontWeight.w900)),
                Text('$badge · $copiers Following', style: TextStyle(color: textSub, fontSize: 11)),
              ],
            ),
          ),
          SizedBox(
            width: 68,
            height: 26,
            child: CustomPaint(painter: const _MiniSparklinePainter(points: [0.85, 0.78, 0.70, 0.62, 0.50, 0.38, 0.25, 0.14], color: Color(0xFF10B981))),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ret, style: const TextStyle(color: Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.w900)),
              Text('Win: $win • Sharpe: $sharpe', style: TextStyle(color: textSub, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 14),
          AnimatedBuilder(
            animation: CopyTradingEngine(),
            builder: (context, _) {
              final count = _activeBrokerCount(CopyTradingEngine());
              return ElevatedButton(
                onPressed: () {
                  CopyTradingEngine().replicateTrade(symbol: 'NIFTY 24200 CE', side: 'BUY', baseQty: 25, price: 214.65);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('1-Click Auto Copy enabled for $name across $count connected brokers!'), backgroundColor: const Color(0xFF059669)),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                child: const Text('1-Click Copy', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Tab 6: Interactive Virtual Practice Arena ──
  Widget _buildVirtualPracticeTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    double liveUnrealized = 0.0;
    for (final p in _virtualPositions) {
      final qty = (p['qty'] as num).toInt();
      final avg = (p['avg'] as num).toDouble();
      final ltp = (p['ltp'] as num).toDouble();
      liveUnrealized += (ltp - avg) * qty;
    }
    final totalPortfolioVal = _virtualCapital + liveUnrealized;
    final roi = ((totalPortfolioVal - 1000000.0) / 1000000.0) * 100;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF047857)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF047857).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PANCHAYAGNAM VIRTUAL PRACTICE ARENA (LIVE MTM)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text('₹${_formatIndian(totalPortfolioVal)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    'Open MTM: ${liveUnrealized >= 0 ? '+' : ''}₹${_formatIndian(liveUnrealized)} (${roi >= 0 ? '+' : ''}${roi.toStringAsFixed(2)}% ROI) · Real-Time Streaming Quotes',
                    style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _virtualCapital = 1000000.0;
                    _virtualPositions.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Virtual Practice Portfolio reset to ₹10,00,000!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                label: const Text('Reset Capital', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Inline Quick Paper Trade Composer
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol)),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text('Quick Paper Order:', style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w900)),
              DropdownButton<String>(
                value: _paperSymbol,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 'NIFTY 24250 CE', child: Text('NIFTY 24250 CE (₹192)')),
                  DropdownMenuItem(value: 'BANKNIFTY 52000 CE', child: Text('BANKNIFTY 52000 CE (₹310)')),
                  DropdownMenuItem(value: 'CRUDEOIL FUT', child: Text('CRUDEOIL FUT (₹8,229)')),
                  DropdownMenuItem(value: 'GOLD MINI FUT', child: Text('GOLD MINI FUT (₹76,410)')),
                  DropdownMenuItem(value: 'ZOMATO', child: Text('ZOMATO EQ (₹268)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _paperSymbol = v);
                },
              ),
              DropdownButton<int>(
                value: _paperQty,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 25, child: Text('Qty: 25')),
                  DropdownMenuItem(value: 50, child: Text('Qty: 50')),
                  DropdownMenuItem(value: 100, child: Text('Qty: 100')),
                  DropdownMenuItem(value: 250, child: Text('Qty: 250')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _paperQty = v);
                },
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final refPrices = {
                    'NIFTY 24250 CE': 192.40,
                    'BANKNIFTY 52000 CE': 310.20,
                    'CRUDEOIL FUT': 8229.00,
                    'GOLD MINI FUT': 76410.00,
                    'ZOMATO': 268.20,
                  };
                  final entryP = refPrices[_paperSymbol] ?? 200.0;
                  setState(() {
                    _virtualPositions.insert(0, {
                      'symbol': _paperSymbol,
                      'type': _paperSymbol.contains('CE') ? 'OPT NFO' : (_paperSymbol.contains('FUT') ? 'MCX FUT' : 'EQ NSE'),
                      'qty': _paperQty,
                      'avg': entryP,
                      'ltp': entryP + (_paperSymbol.contains('FUT') ? 4.5 : 1.2),
                      'isUp': true,
                    });
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Simulated BUY placed: $_paperQty × $_paperSymbol @ ₹${entryP.toStringAsFixed(2)}'), backgroundColor: const Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: Colors.white),
                label: const Text('Add Simulated Position', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Open Simulated Positions (${_virtualPositions.length})', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
            const Text('Zero Real Risk • Live Ticking MTM', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),

        ..._virtualPositions.map((p) {
          final sym = p['symbol'] as String;
          final qty = (p['qty'] as num).toInt();
          final avg = (p['avg'] as num).toDouble();
          final ltp = (p['ltp'] as num).toDouble();
          final pnl = (ltp - avg) * qty;
          final isPos = pnl >= 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sym, style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900)),
                    Text('$qty Qty @ Avg: ₹${avg.toStringAsFixed(2)} · ${p['type']}', style: TextStyle(color: textSub, fontSize: 11)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('LTP: ₹${_formatIndian(ltp)}', style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(
                      '${isPos ? '+' : ''}₹${_formatIndian(pnl)}',
                      style: TextStyle(color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 11.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _virtualPositions.remove(p);
                      _virtualCapital += pnl;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Position for $sym squared off (${isPos ? '+' : ''}₹${_formatIndian(pnl)})!'), backgroundColor: const Color(0xFF059669)),
                    );
                  },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: Size.zero),
                  child: const Text('Square Off', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  const _MiniSparklinePainter({required this.points, required this.color});

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
        colors: [color.withOpacity(0.28), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
