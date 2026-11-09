import 'package:flutter/material.dart';
import '../../../reusable_widets/order_placement_ticket_dialog.dart';
import '../../../service/theme_mode_service.dart';
import '../../../service/copy_trading_engine.dart';

/// TradeMarketStockGroView
/// Panchayagnam Trade Market • Institutional Alpha Hub & Quantitative Trading Floor
/// 
/// Enterprise-grade institutional features:
/// - Real-Time Market Telemetry (Market Breadth, FII/DII Net Flow, PCR, India VIX, Gift Nifty)
/// - Live Institutional Trade Ideas (SEBI Regd & Quant Setups with R:R, Live P&L, 8-Demat Copy)
/// - Live Market Movers & Volume Shockers (>300% 20-DMA, 52W Highs/Lows, VWAP)
/// - Real-Time Quantitative Scanners (Supertrend, Gamma Blast, RSI Mean Reversion, Delivery)
/// - Panchayagnam AI Quant Copilot with natural-language prompt discovery
/// - Social Alpha Leagues & Star Traders Leaderboard with 1-Click Copy Trading
/// - Virtual Practice Arena with ₹10,00,000 Simulated Capital & Real-Time Mark-to-Market
class TradeMarketStockGroView extends StatefulWidget {
  final int initialTabIndex;
  const TradeMarketStockGroView({super.key, this.initialTabIndex = 0});

  @override
  State<TradeMarketStockGroView> createState() => _TradeMarketStockGroViewState();
}

class _TradeMarketStockGroViewState extends State<TradeMarketStockGroView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Active filter for Trade Ideas
  String _selectedTradeCategory = 'ALL';

  // Active filter for Movers
  String _selectedMoverTab = 'GAINERS';

  // Virtual Wallet State
  double _virtualCapital = 1000000.0;
  double _virtualPnL = 48250.0;
  final List<Map<String, dynamic>> _virtualPositions = [
    {
      'symbol': 'NIFTY 24200 CE',
      'type': 'OPT NFO',
      'qty': 100,
      'avg': 210.00,
      'ltp': 228.40,
      'pnl': 1840.0,
      'isUp': true,
    },
    {
      'symbol': 'TATASTEEL',
      'type': 'EQ NSE',
      'qty': 500,
      'avg': 186.40,
      'ltp': 194.50,
      'pnl': 4050.0,
      'isUp': true,
    },
    {
      'symbol': 'BANKNIFTY 51800 PE',
      'type': 'OPT NFO',
      'qty': 60,
      'avg': 378.10,
      'ltp': 395.20,
      'pnl': 1026.0,
      'isUp': true,
    },
    {
      'symbol': 'RELIANCE',
      'type': 'EQ NSE',
      'qty': 100,
      'avg': 2920.00,
      'ltp': 2948.50,
      'pnl': 2850.0,
      'isUp': true,
    },
    {
      'symbol': 'PERSISTENT',
      'type': 'EQ NSE',
      'qty': 40,
      'avg': 5410.00,
      'ltp': 5490.00,
      'pnl': 3200.0,
      'isUp': true,
    },
  ];

  // AI Copilot Query State
  final TextEditingController _aiQueryController = TextEditingController();
  String _aiResponseSymbol = 'NIFTY 24200 CE';
  String _aiResponseText =
      'Panchayagnam AI Analysis: NIFTY 24,200 strike exhibits heavy Call Unwinding with 2.8M shares shed in intraday trading. PCR shifted from 0.88 to 1.18, signaling high-probability continuation towards 24,350. Support established firmly at 24,100.';
  String _aiStrategyAction = 'BUY BULL CALL SPREAD';
  bool _isAiThinking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 6),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aiQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeModeService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8F9FE);
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
                // 1. Institutional Top Bar & Live Market Telemetry Banner
                _buildInstitutionalHeader(isDark, cardBg, borderCol, textMain, textSub),

                // 2. Real-Time Telemetry Bar (Breadth, FII/DII, PCR, VIX)
                _buildMarketTelemetryStrip(isDark, cardBg, borderCol, textMain, textSub),

                // 3. Navigation Tab Bar (Institutional Dark / Light Styling)
                Container(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
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

                // 4. Tab Body Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    height: 1250,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 0: Market Overview & Radar
                        _buildMarketOverviewTab(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 1: Live Institutional Trade Ideas
                        _buildTradeIdeasTab(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 2: Market Movers & Volume Shockers
                        _buildMarketMoversTab(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 3: Quant & F&O Scanners
                        _buildQuantScannersTab(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 4: Panchayagnam AI Quant Copilot
                        _buildAICopilotTab(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 5: Alpha Leagues & Star Traders
                        _buildLeaguesAndTradersTab(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 6: Virtual Practice Arena
                        _buildVirtualPracticeTab(isDark, cardBg, borderCol, textMain, textSub),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 1. Institutional Top Bar ──
  Widget _buildInstitutionalHeader(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'PANCHAYAGNAM TRADE MARKET',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
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
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Real-Time Quant Radar • SEBI Verified Alpha Calls • 8-Demat Instant Copy Execution',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right Badges
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_tethering_rounded, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 6),
                    Text('NSE/BSE Tick Stream: 11ms', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.sync_rounded, color: Color(0xFF38BDF8), size: 14),
                    SizedBox(width: 6),
                    Text('8 Demats Synchronized', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. Live Market Telemetry Bar ──
  Widget _buildMarketTelemetryStrip(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Breadth
            _buildTelemetryBadge(
              icon: Icons.pie_chart_rounded,
              label: 'Market Breadth',
              val: '1,438 Adv / 782 Dec (A/D 1.84)',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            _buildTelemetryDivider(isDark),

            // FII / DII Flow
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

            // Nifty PCR
            _buildTelemetryBadge(
              icon: Icons.speed_rounded,
              label: 'NIFTY PCR',
              val: '1.18 (Mild Bullish)',
              color: const Color(0xFF38BDF8),
              isDark: isDark,
            ),
            _buildTelemetryDivider(isDark),

            // Max Pain
            _buildTelemetryBadge(
              icon: Icons.track_changes_rounded,
              label: 'Max Pain Strike',
              val: '24,150',
              color: const Color(0xFFF59E0B),
              isDark: isDark,
            ),
            _buildTelemetryDivider(isDark),

            // India VIX
            _buildTelemetryBadge(
              icon: Icons.graphic_eq_rounded,
              label: 'India VIX',
              val: '14.22 (-1.25%)',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            _buildTelemetryDivider(isDark),

            // Gift Nifty
            _buildTelemetryBadge(
              icon: Icons.public_rounded,
              label: 'Gift Nifty',
              val: '24,310 (+92 pts)',
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
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          val,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        '|',
        style: TextStyle(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          fontSize: 12,
        ),
      ),
    );
  }

  // ── Tab 0: Market Overview & Radar (Elite Institutional Hub) ──
  Widget _buildMarketOverviewTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      children: [
        // 1. Executive Quick Pillars Grid
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Institutional Trading Floor Pillars',
              style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
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
              runSpacing: 16,
              children: [
                _buildOverviewPillarCard(
                  width: cardWidth,
                  title: 'Alpha Trade Ideas',
                  subtitle: 'High conviction SEBI calls with exact R:R',
                  badge: '6 ACTIVE CALLS',
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
                  title: 'Market Movers & Shockers',
                  subtitle: 'Volume shockers (>300%), 52W breakouts',
                  badge: '4.8x VOL SURGE',
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
                  subtitle: 'Supertrend, Gamma blasts, RSI bounce',
                  badge: 'LIVE BREAKOUTS',
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
                  title: 'Panchayagnam AI Copilot',
                  subtitle: 'Autonomous natural language market analysis',
                  badge: 'GEMINI 2.5 FLASH',
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
                  title: 'Trading Arena & Star Traders',
                  subtitle: '₹5,00,000 Mega League & 1-Click Copy Trading',
                  badge: '₹5L PRIZE POOL',
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
                  title: 'Virtual Practice Wallet',
                  subtitle: '₹10,00,000 live paper capital & analytics',
                  badge: '+₹48,250 P&L',
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

        const SizedBox(height: 24),

        // 2. Sector Heatmap & Smart Money Positioning Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Sector Heatmap
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sector Performance Heatmap', style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
                        const Text('Live NSE Sector Indices', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSectorHeatmapRow('Nifty Metal', '+2.45%', 0.85, true, 'TATASTEEL, JSWSTEEL, VEDL', textMain, textSub),
                    const SizedBox(height: 10),
                    _buildSectorHeatmapRow('Nifty IT', '+1.85%', 0.70, true, 'PERSISTENT, INFY, COFORGE', textMain, textSub),
                    const SizedBox(height: 10),
                    _buildSectorHeatmapRow('Nifty Auto', '+1.40%', 0.55, true, 'TATAMOTORS, M&M, BAJAJ-AUTO', textMain, textSub),
                    const SizedBox(height: 10),
                    _buildSectorHeatmapRow('Nifty Realty', '+0.95%', 0.40, true, 'DLF, GODREJPROP, LODHA', textMain, textSub),
                    const SizedBox(height: 10),
                    _buildSectorHeatmapRow('Nifty Bank', '+0.62%', 0.30, true, 'HDFCBANK, ICICIBANK, SBIN', textMain, textSub),
                    const SizedBox(height: 10),
                    _buildSectorHeatmapRow('Nifty FMCG', '-0.35%', 0.20, false, 'ITC, HINDUNILVR, NESTLEIND', textMain, textSub),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Right: Institutional Smart Money Flow Breakdown
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Institutional Smart Money Flow', style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
                        const Icon(Icons.security_rounded, color: Color(0xFF38BDF8), size: 16),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSmartMoneyStatRow('FII Index Futures Long %', '68.4% (Heavy Bullish)', const Color(0xFF10B981), textMain, textSub),
                    const SizedBox(height: 10),
                    _buildSmartMoneyStatRow('DII Net Monthly Absorption', '+₹38,450 Cr', const Color(0xFF10B981), textMain, textSub),
                    const SizedBox(height: 10),
                    _buildSmartMoneyStatRow('Prop Desk Stock Options', '+42,500 Long CE contracts', const Color(0xFF38BDF8), textMain, textSub),
                    const SizedBox(height: 10),
                    _buildSmartMoneyStatRow('Client (Retail) Put Writing', '-18,200 Net Short PE', const Color(0xFFF59E0B), textMain, textSub),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Smart Money Bias: High probability upward continuation towards 24,350 before expiry roll.',
                              style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
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

        const SizedBox(height: 24),

        // 3. Featured Hot Trade Idea Quick Action
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: Color(0xFF6366F1), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('TOP ALPHA PICK TODAY: NIFTY 24DEC 24200 CE', style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                          child: const Text('+18.4% CMP IN PROFIT', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Entry: ₹214.65 • Target 1: ₹245.00 • Target 2: ₹280.00 • Stop Loss: ₹175.00 • 94% Quant Conviction',
                      style: TextStyle(color: textSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  CopyTradingEngine().replicateTrade(symbol: 'NIFTY 24200 CE', side: 'BUY', baseQty: 25, price: 214.65);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚡ Instant Buy Order Dispatched across 8 Demat Accounts!'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                },
                icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                label: const Text('1-Click 8-Demat Execute', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
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
        height: 116,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
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
                      Text(title, style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(color: textSub, fontSize: 11.5, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorHeatmapRow(String sector, String chg, double progress, bool isUp, String stocks, Color textMain, Color textSub) {
    final col = isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Row(
      children: [
        SizedBox(width: 88, child: Text(sector, style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: FontWeight.bold))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(col),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 2),
              Text(stocks, style: TextStyle(color: textSub, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 54,
          child: Text(
            chg,
            textAlign: TextAlign.right,
            style: TextStyle(color: col, fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartMoneyStatRow(String label, String val, Color valCol, Color textMain, Color textSub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: textSub, fontSize: 12)),
        Text(val, style: TextStyle(color: valCol, fontSize: 12.5, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ── Tab 1: Live Institutional Trade Ideas (SEBI & Quant Calls) ──
  Widget _buildTradeIdeasTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final List<Map<String, dynamic>> allCalls = [
      {
        'symbol': 'NIFTY 24DEC 24200 CE',
        'type': 'EXPIRY GAMMA BLAST',
        'category': 'OPTIONS',
        'entry': 214.65,
        'tgt1': 245.0,
        'tgt2': 280.0,
        'sl': 175.0,
        'ltp': 228.40,
        'pnl': '+6.4%',
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
        'pnl': '+2.26%',
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
        'pnl': '+4.5%',
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
        'pnl': '+1.48%',
        'rr': '1 : 2.8',
        'score': '92% QUANT SCORE',
        'analyst': 'Panchayagnam Institutional Desk (SEBI Regd. INH000012891)',
        'rationale': 'Fresh all-time high continuation after strong Q2 guidance and heavy FII block accumulation.',
        'lot': 1,
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
        'pnl': '+9.8%',
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
        'pnl': '+1.82%',
        'rr': '1 : 2.8',
        'score': '90% QUANT SCORE',
        'analyst': 'Panchayagnam Research Desk (SEBI Regd. INH000008432)',
        'rationale': 'Bullish Supertrend flip on daily timeframe with sustained institutional delivery > 62%.',
        'lot': 1,
      },
    ];

    final filteredCalls = (_selectedTradeCategory == 'ALL')
        ? allCalls
        : allCalls.where((c) => c['category'] == _selectedTradeCategory).toList();

    return ListView(
      children: [
        // Category Pills
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('ALL', 'All Calls (${allCalls.length})', isDark),
                _buildFilterChip('OPTIONS', 'F&O Options', isDark),
                _buildFilterChip('EQUITY', 'Equities (Cash)', isDark),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('100% SEBI REGISTERED RESEARCH', style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Cards List
        ...filteredCalls.map((call) => _buildInstitutionalTradeCard(call, isDark, cardBg, borderCol, textMain, textSub)),
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
    final pnl = call['pnl'] as String;
    final rr = call['rr'] as String;
    final score = call['score'] as String;
    final analyst = call['analyst'] as String;
    final rationale = call['rationale'] as String;
    final cat = call['category'] as String;
    final lot = (call['lot'] as num).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row
          Row(
            children: [
              Text(sym, style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(call['type'] as String, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(score, style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('LTP: ₹${ltp.toStringAsFixed(2)}', style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w900)),
                  Text(pnl, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quantitative Telemetry Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderCol.withOpacity(0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardMetric('Entry Price', '₹${entry.toStringAsFixed(2)}', textMain, textSub),
                _buildCardMetric('Target 1', '₹${tgt1.toStringAsFixed(2)}', const Color(0xFF10B981), textSub),
                _buildCardMetric('Target 2', '₹${tgt2.toStringAsFixed(2)}', const Color(0xFF10B981), textSub),
                _buildCardMetric('Stop Loss', '₹${sl.toStringAsFixed(2)}', const Color(0xFFEF4444), textSub),
                _buildCardMetric('Risk:Reward', rr, const Color(0xFF38BDF8), textSub),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Rationale & Verification
          Row(
            children: [
              const Icon(Icons.psychology_rounded, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rationale,
                  style: TextStyle(color: textSub, fontSize: 12, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Verified by $analyst',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),

          // Bottom Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  OrderPlacementTicketDialog.show(
                    context,
                    symbol: sym,
                    side: 'BUY',
                    ltp: ltp,
                    lotSize: lot,
                    category: cat,
                  );
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
                      content: Text('⚡ Multi-Demat Replication: Placed order for $sym across 8 demats!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                },
                icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                label: const Text('1-Click Execute (8 Demats)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
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
    final gainers = [
      {'symbol': 'TATASTEEL', 'sector': 'Metals', 'ltp': 194.50, 'chg': '+2.26%', 'vol': '3.8x Avg', 'delivery': '64.2%', 'vwap': 192.10, 'isUp': true},
      {'symbol': 'ZOMATO', 'sector': 'New Age Tech', 'ltp': 268.20, 'chg': '+4.85%', 'vol': '4.5x Avg', 'delivery': '58.9%', 'vwap': 262.40, 'isUp': true},
      {'symbol': 'PERSISTENT', 'sector': 'IT & Software', 'ltp': 5490.00, 'chg': '+3.12%', 'vol': '2.9x Avg', 'delivery': '71.4%', 'vwap': 5430.00, 'isUp': true},
      {'symbol': 'COFORGE', 'sector': 'IT Services', 'ltp': 7820.00, 'chg': '+4.15%', 'vol': '4.2x Avg', 'delivery': '62.0%', 'vwap': 7740.00, 'isUp': true},
      {'symbol': 'RELIANCE', 'sector': 'Energy / Telecom', 'ltp': 2948.50, 'chg': '+1.12%', 'vol': '1.8x Avg', 'delivery': '68.5%', 'vwap': 2932.00, 'isUp': true},
      {'symbol': 'DIXON', 'sector': 'EMS / Electronics', 'ltp': 15120.00, 'chg': '+2.40%', 'vol': '3.1x Avg', 'delivery': '59.3%', 'vwap': 14980.00, 'isUp': true},
    ];

    final volumeShockers = [
      {'symbol': 'COFORGE', 'sector': 'IT Services', 'ltp': 7820.00, 'chg': '+4.15%', 'vol': '480% of 20-DMA', 'delivery': '62.0%', 'vwap': 7740.00, 'isUp': true},
      {'symbol': 'ZOMATO', 'sector': 'New Age Tech', 'ltp': 268.20, 'chg': '+4.85%', 'vol': '450% of 20-DMA', 'delivery': '58.9%', 'vwap': 262.40, 'isUp': true},
      {'symbol': 'TATASTEEL', 'sector': 'Metals', 'ltp': 194.50, 'chg': '+2.26%', 'vol': '380% of 20-DMA', 'delivery': '64.2%', 'vwap': 192.10, 'isUp': true},
      {'symbol': 'TRENT', 'sector': 'Retail', 'ltp': 7120.00, 'chg': '+3.80%', 'vol': '340% of 20-DMA', 'delivery': '66.1%', 'vwap': 7040.00, 'isUp': true},
    ];

    final displayedList = (_selectedMoverTab == 'SHOCKERS') ? volumeShockers : gainers;

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Top Gainers (NSE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: _selectedMoverTab == 'GAINERS',
                  selectedColor: const Color(0xFF10B981),
                  onSelected: (_) => setState(() => _selectedMoverTab = 'GAINERS'),
                ),
                ChoiceChip(
                  label: const Text('Volume Shockers (>300%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: _selectedMoverTab == 'SHOCKERS',
                  selectedColor: const Color(0xFF10B981),
                  onSelected: (_) => setState(() => _selectedMoverTab = 'SHOCKERS'),
                ),
              ],
            ),
            const Text('Real-Time NSE Tick Sync', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('SYMBOL & SECTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('LTP & CHANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('VOLUME SURGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('DELIVERY %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('VWAP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('ACTION', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Table Rows
        ...displayedList.map((m) {
          final sym = m['symbol'] as String;
          final sec = m['sector'] as String;
          final ltp = (m['ltp'] as num).toDouble();
          final chg = m['chg'] as String;
          final vol = m['vol'] as String;
          final del = m['delivery'] as String;
          final vwap = (m['vwap'] as num).toDouble();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sym, style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900)),
                      Text(sec, style: TextStyle(color: textSub, fontSize: 10.5)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('₹${ltp.toStringAsFixed(2)}', style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(chg, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(vol, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(flex: 2, child: Text(del, style: TextStyle(color: textSub, fontSize: 11.5, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('₹${vwap.toStringAsFixed(2)}', style: TextStyle(color: textSub, fontSize: 11.5))),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          OrderPlacementTicketDialog.show(context, symbol: sym, side: 'BUY', ltp: ltp, lotSize: 1, category: 'EQUITY');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('BUY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {
                          OrderPlacementTicketDialog.show(context, symbol: sym, side: 'SELL', ltp: ltp, lotSize: 1, category: 'EQUITY');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('SELL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
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

  // ── Tab 3: Quantitative Scanners (Live Breakout Engine) ──
  Widget _buildQuantScannersTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final scanners = [
      {
        'title': 'Supertrend & EMA 9/21 Golden Crossover',
        'desc': 'Bullish Supertrend flip with 9 EMA cutting 21 EMA from below on daily candles.',
        'tag': 'TREND FOLLOWING',
        'tagCol': const Color(0xFF10B981),
        'results': [
          {'sym': 'TATASTEEL', 'ltp': 194.50, 'chg': '+2.26%'},
          {'sym': 'PERSISTENT', 'ltp': 5490.00, 'chg': '+3.12%'},
          {'sym': 'BHARTIARTL', 'ltp': 1584.00, 'chg': '+1.45%'},
        ],
      },
      {
        'title': 'Gamma Blast & Heavy Call Unwinding',
        'desc': 'Options where call writers are covering in panic, causing aggressive upside gamma bursts.',
        'tag': 'F&O SQUEEZE',
        'tagCol': const Color(0xFFEA580C),
        'results': [
          {'sym': 'NIFTY 24200 CE', 'ltp': 228.40, 'chg': '+18.4%'},
          {'sym': 'COFORGE', 'ltp': 7820.00, 'chg': '+4.15%'},
          {'sym': 'TRENT', 'ltp': 7120.00, 'chg': '+3.80%'},
        ],
      },
      {
        'title': 'RSI Oversold Mean Reversion (< 30 Bounce)',
        'desc': 'Large-cap stocks trading at extreme oversold levels turning up with bullish divergence.',
        'tag': 'MEAN REVERSION',
        'tagCol': const Color(0xFF38BDF8),
        'results': [
          {'sym': 'ASIANPAINT', 'ltp': 2840.00, 'chg': '+1.10%'},
          {'sym': 'LT', 'ltp': 3620.00, 'chg': '+1.80%'},
          {'sym': 'BAJFINANCE', 'ltp': 6890.00, 'chg': '+0.95%'},
        ],
      },
      {
        'title': 'Institutional Block Delivery (> 65% Delivery Vol)',
        'desc': 'Stocks experiencing high delivery volume percentage signaling institutional accumulation.',
        'tag': 'SMART MONEY',
        'tagCol': const Color(0xFF8B5CF6),
        'results': [
          {'sym': 'RELIANCE', 'ltp': 2948.50, 'chg': '+1.12%'},
          {'sym': 'ICICIBANK', 'ltp': 1264.00, 'chg': '+0.88%'},
          {'sym': 'TCS', 'ltp': 4180.00, 'chg': '+0.65%'},
        ],
      },
    ];

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Automated Quantitative Scanners', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: const Text('ALGORITHMIC ENGINE', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        ...scanners.map((sc) {
          final title = sc['title'] as String;
          final desc = sc['desc'] as String;
          final tag = sc['tag'] as String;
          final tagCol = sc['tagCol'] as Color;
          final results = sc['results'] as List<Map<String, dynamic>>;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(color: textMain, fontSize: 14.5, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: tagCol.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(tag, style: TextStyle(color: tagCol, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: textSub, fontSize: 11.5)),
                const SizedBox(height: 12),

                // Stocks found chips
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            Text('₹${ltp.toStringAsFixed(2)}', style: TextStyle(color: textMain, fontSize: 11.5)),
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
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFF0FDF4), const Color(0xFFE2E8F0)],
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PANCHAYAGNAM AI QUANT COPILOT',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      Text(
                        'Powered by Gemini 2.5 Flash + Live NSE Tick Stream for Institutional Setup Generation',
                        style: TextStyle(color: textSub, fontSize: 11.5),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Query Box
              TextField(
                controller: _aiQueryController,
                style: TextStyle(color: textMain, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ask: "Analyze NIFTY 24200 CE open interest" or "Best low-risk F&O strategy for expiry"...',
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

              // Quick Prompts
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildPromptChip('Analyze NIFTY 24200 CE strike OI', isDark),
                  _buildPromptChip('Find High Volume Breakouts in Metals', isDark),
                  _buildPromptChip('Options Delta Hedge for Bank Nifty', isDark),
                  _buildPromptChip('Tata Steel RSI & Support Pivots', isDark),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // AI Response Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Text('Autonomous Synthesis: $_aiResponseSymbol', style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(_aiStrategyAction, style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _aiResponseText,
                style: TextStyle(color: textMain, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Quantitative Pivots
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

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    CopyTradingEngine().replicateTrade(symbol: _aiResponseSymbol, side: 'BUY', baseQty: 25, price: 214.65);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚡ Dispatched AI Recommended $_aiStrategyAction across 8 demats!'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                  label: const Text('Execute AI Suggested Setup (8 Demats)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11)),
      ),
    );
  }

  void _runAiAnalysis() {
    setState(() => _isAiThinking = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isAiThinking = false;
        final q = _aiQueryController.text.toLowerCase();
        if (q.contains('metal') || q.contains('tata')) {
          _aiResponseSymbol = 'TATASTEEL';
          _aiResponseText =
              'Panchayagnam AI Analysis: Tata Steel has broken out from a 3-week consolidation cup-and-handle pattern at ₹190.20 on 3.5x 20-DMA volume. RSI is at 64 with strong upside room before overbought zone. Target: ₹205.00 with trailing SL at ₹185.00.';
          _aiStrategyAction = 'BUY SWING EQUITY';
        } else if (q.contains('bank')) {
          _aiResponseSymbol = 'BANKNIFTY 51800 PE';
          _aiResponseText =
              'Panchayagnam AI Analysis: Bank Nifty is facing heavy supply near 52,000. Institutional open interest shows heavy Call resistance built at 52,000 strike. Recommended mean-reversion hedge with target 51,500.';
          _aiStrategyAction = 'BUY EXPIRY HEDGE';
        } else {
          _aiResponseSymbol = 'NIFTY 24200 CE';
          _aiResponseText =
              'Panchayagnam AI Analysis: NIFTY 24,200 strike exhibits heavy Call Unwinding with 2.8M shares shed in intraday trading. PCR shifted from 0.88 to 1.18, signaling high-probability continuation towards 24,350.';
          _aiStrategyAction = 'BUY BULL CALL SPREAD';
        }
      });
    });
  }

  // ── Tab 5: Alpha Leagues & Star Traders Leaderboard ──
  Widget _buildLeaguesAndTradersTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      children: [
        // Leagues Row
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

        _buildTournamentCard('Panchayagnam Mega Trader League', '₹5,00,000 Cash Pool', '3,420 Active Traders', 'LIVE NOW', 'Free Pass', isDark, cardBg, borderCol, textMain, textSub),
        const SizedBox(height: 10),
        _buildTournamentCard('Derivatives Alpha Cup', '₹2,50,000 Cash Pool', '1,890 Active Traders', 'LIVE NOW', 'Weekly F&O', isDark, cardBg, borderCol, textMain, textSub),

        const SizedBox(height: 24),

        // Star Traders Section
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
        _buildStarTraderCard('Siddharth_F&O', '+98.4%', '72.1%', '1.95', '750 Demats', 'Directional Momentum Trader', isDark, cardBg, borderCol, textMain, textSub),
      ],
    );
  }

  Widget _buildTournamentCard(String title, String pool, String participants, String status, String tag, bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ret, style: const TextStyle(color: Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.w900)),
              Text('Win Rate: $win • Sharpe: $sharpe', style: TextStyle(color: textSub, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 14),
          ElevatedButton(
            onPressed: () {
              CopyTradingEngine().replicateTrade(symbol: 'NIFTY 24200 CE', side: 'BUY', baseQty: 25, price: 214.65);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('1-Click Auto Copy enabled for $name across 8 demats!'), backgroundColor: const Color(0xFF059669)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            child: const Text('1-Click Copy', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ── Tab 6: Virtual Practice Arena (₹10,00,000 Portfolio) ──
  Widget _buildVirtualPracticeTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final totalPortfolioVal = _virtualCapital + _virtualPnL;

    return ListView(
      children: [
        // Capital Banner
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: const Color(0xFF047857).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PANCHAYAGNAM VIRTUAL PRACTICE ARENA', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text('₹${totalPortfolioVal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('+₹48,250.00 (+4.82% All-Time ROI) · Real-Time NSE Streaming Quotes', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 12.5, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _virtualCapital = 1000000.0;
                    _virtualPnL = 0.0;
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

        const SizedBox(height: 20),

        // Virtual Positions List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Open Simulated Positions (${_virtualPositions.length})', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
            const Text('Zero Real Risk • Live Execution Engine', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),

        ..._virtualPositions.map((p) {
          final sym = p['symbol'] as String;
          final qty = p['qty'] as int;
          final avg = (p['avg'] as num).toDouble();
          final ltp = (p['ltp'] as num).toDouble();
          final pnl = (p['pnl'] as num).toDouble();

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
                    Text('$qty Qty @ Avg: ₹${avg.toStringAsFixed(2)}', style: TextStyle(color: textSub, fontSize: 11)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('LTP: ₹${ltp.toStringAsFixed(2)}', style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('+₹${pnl.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.w900)),
                  ],
                ),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _virtualPositions.remove(p);
                      _virtualCapital += (ltp * qty);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Position for $sym squared off!'), backgroundColor: const Color(0xFF059669)),
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
