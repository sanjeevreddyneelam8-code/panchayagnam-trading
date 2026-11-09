import 'package:flutter/material.dart';
import '../../../reusable_widets/order_placement_ticket_dialog.dart';
import '../../../service/theme_mode_service.dart';
import '../../../service/copy_trading_engine.dart';

/// TradeMarketStockGroView
/// Comprehensive StockGro-inspired Social Trading Arena & Market Hub:
/// - Trading Leagues & Tournaments (Daily / Weekly ₹5,00,000+ Prize Pools)
/// - Star Traders & Verified Portfolios Leaderboard (1-Click Copy Trading)
/// - Virtual Practice Arena (StockGro ₹10,00,000 Virtual Wallet & Positions)
/// - Social Sentiment, Crowd Bull/Bear Gauges & Trending Buzz Stocks
class TradeMarketStockGroView extends StatefulWidget {
  final int initialTabIndex;
  const TradeMarketStockGroView({super.key, this.initialTabIndex = 0});

  @override
  State<TradeMarketStockGroView> createState() => _TradeMarketStockGroViewState();
}

class _TradeMarketStockGroViewState extends State<TradeMarketStockGroView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Virtual Wallet State (StockGro Paper Capital)
  double _virtualCapital = 1000000.0;
  double _virtualPnL = 48250.0;
  final List<Map<String, dynamic>> _virtualPositions = [
    {
      'symbol': 'NIFTY 24DEC 24200 CE',
      'type': 'OPT NFO',
      'qty': 100,
      'avg': 210.00,
      'ltp': 214.65,
      'pnl': 465.0,
      'isUp': true,
    },
    {
      'symbol': 'TATASTEEL',
      'type': 'EQ NSE',
      'qty': 500,
      'avg': 186.40,
      'ltp': 190.20,
      'pnl': 1900.0,
      'isUp': true,
    },
    {
      'symbol': 'BANKNIFTY 51800 CE',
      'type': 'OPT NFO',
      'qty': 60,
      'avg': 390.00,
      'ltp': 412.50,
      'pnl': 1350.0,
      'isUp': true,
    },
    {
      'symbol': 'RELIANCE',
      'type': 'EQ NSE',
      'qty': 100,
      'avg': 2920.00,
      'ltp': 2940.50,
      'pnl': 2050.0,
      'isUp': true,
    },
  ];

  // Community Sentiment Poll state
  int _niftyBullVotes = 9710;
  int _niftyBearVotes = 4580;
  String? _userNiftyVote;

  int _bankNiftyBullVotes = 8760;
  int _bankNiftyBearVotes = 3090;
  String? _userBankNiftyVote;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeModeService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9);
        final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
        final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Scaffold(
          backgroundColor: bg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hero Banner (StockGro Social Trading Styling)
                _buildStockGroHeroBanner(isDark, cardBg, borderCol, textMain, textSub),
                const SizedBox(height: 20),

                // 4 Interactive Navigation Tabs
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF10B981),
                    unselectedLabelColor: textSub,
                    indicatorColor: const Color(0xFF10B981),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    tabs: const [
                      Tab(icon: Icon(Icons.emoji_events_rounded, size: 18), text: 'Trading Leagues (Arena)'),
                      Tab(icon: Icon(Icons.military_tech_rounded, size: 18), text: 'Star Traders Leaderboard'),
                      Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 18), text: 'Virtual Practice Arena (₹10L)'),
                      Tab(icon: Icon(Icons.forum_rounded, size: 18), text: 'Community Sentiment & Buzz'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tab Views Content
                SizedBox(
                  height: 960,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTradingLeaguesTab(isDark, cardBg, borderCol, textMain, textSub),
                      _buildStarTradersTab(isDark, cardBg, borderCol, textMain, textSub),
                      _buildVirtualPracticeTab(isDark, cardBg, borderCol, textMain, textSub),
                      _buildCommunitySentimentTab(isDark, cardBg, borderCol, textMain, textSub),
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

  // ── 1. StockGro Hero Banner with Key Market Metrics ──
  Widget _buildStockGroHeroBanner(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF064E3B).withOpacity(0.4)]
              : [const Color(0xFFF8FAFC), const Color(0xFFECFDF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('STOCKGRO POWERED ARENA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF38BDF8)),
                    SizedBox(width: 5),
                    Text('18,420 Social Traders Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Trade Market · Social Trading, Leagues & Virtual Wealth',
            style: TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Compete in daily & weekly trading leagues for ₹15,50,000+ prize pools, practice risk-free with ₹10,00,000 virtual cash, and 1-click copy verified star traders across your 8 demat accounts.',
            style: TextStyle(color: textSub, fontSize: 13),
          ),
          const SizedBox(height: 18),

          // 4 Quick Stat Metric Cards
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _buildMetricStatCard(
                    title: 'Active Tournaments',
                    value: '12 Live Leagues',
                    sub: '₹15,50,000 Total Prize Pool',
                    icon: Icons.emoji_events_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    isDark: isDark,
                    width: isWide ? 220 : constraints.maxWidth,
                  ),
                  _buildMetricStatCard(
                    title: 'Star Pro Traders',
                    value: '48 Verified Masters',
                    sub: 'Avg +84.2% Monthly ROI',
                    icon: Icons.stars_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    width: isWide ? 220 : constraints.maxWidth,
                  ),
                  _buildMetricStatCard(
                    title: 'Your Virtual Wallet',
                    value: '₹10,48,250.00',
                    sub: '+₹48,250 P&L (+4.82%)',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF10B981),
                    isDark: isDark,
                    width: isWide ? 220 : constraints.maxWidth,
                  ),
                  _buildMetricStatCard(
                    title: 'Multi-Demat Replication',
                    value: '8 Demats Active',
                    sub: '1-Click Zero Latency Copy',
                    icon: Icons.bolt_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    isDark: isDark,
                    width: isWide ? 220 : constraints.maxWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricStatCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 0: Trading Leagues (Arena) ──
  Widget _buildTradingLeaguesTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final leagues = [
      {
        'title': 'Nifty Bull Mega League',
        'badge': '🏆 MEGA LEAGUE',
        'badgeColor': const Color(0xFFF59E0B),
        'prize': '₹5,00,000',
        'firstPrize': '₹1,50,000 Cash + Pro Trophy',
        'entry': 'Free Entry',
        'participants': '3,420 Traders Joined',
        'status': 'LIVE NOW',
        'endsIn': 'Ends 3:30 PM Today',
        'segment': 'NIFTY & BANKNIFTY F&O',
        'leaders': [
          {'rank': '#1', 'name': 'Aditya_Scalper', 'ret': '+34.2%'},
          {'rank': '#2', 'name': 'Rohan_Quant', 'ret': '+28.6%'},
          {'rank': '#3', 'name': 'Neha_Trader', 'ret': '+22.1%'},
        ],
      },
      {
        'title': 'Options Champions Arena',
        'badge': '⚡ WEEKLY DERIVATIVES',
        'badgeColor': const Color(0xFF8B5CF6),
        'prize': '₹2,50,000',
        'firstPrize': '₹75,000 Cash',
        'entry': 'Pass Included',
        'participants': '1,890 Traders Joined',
        'status': 'LIVE NOW',
        'endsIn': 'Ends Thursday Expiry',
        'segment': 'Weekly Strikes Only',
        'leaders': [
          {'rank': '#1', 'name': 'Priya_Options', 'ret': '+41.5%'},
          {'rank': '#2', 'name': 'Vikram_Trade', 'ret': '+31.0%'},
          {'rank': '#3', 'name': 'Karan_Theta', 'ret': '+25.4%'},
        ],
      },
      {
        'title': 'Intraday Hustlers Challenge',
        'badge': '🚀 5X EQUITY SPRINT',
        'badgeColor': const Color(0xFF06B6D4),
        'prize': '₹1,00,000',
        'firstPrize': '₹30,000 Cash',
        'entry': 'Free',
        'participants': '840 Registered',
        'status': 'STARTS TOMORROW',
        'endsIn': 'Starts 9:15 AM',
        'segment': 'NSE Top 100 Stocks',
        'leaders': [
          {'rank': '#1', 'name': 'Deepak_Momentum', 'ret': '0.0%'},
          {'rank': '#2', 'name': 'Sanjay_Breakout', 'ret': '0.0%'},
          {'rank': '#3', 'name': 'Rahul_Tape', 'ret': '0.0%'},
        ],
      },
      {
        'title': 'Zero to Hero Rookie Arena',
        'badge': '🌟 BEGINNER LEAGUE',
        'badgeColor': const Color(0xFF10B981),
        'prize': '₹50,000',
        'firstPrize': '₹15,000 Learning Grant',
        'entry': 'Free for All',
        'participants': '4,150 Beginners',
        'status': 'ONGOING',
        'endsIn': '30 Days Tournament',
        'segment': 'Virtual Paper Cash (₹10L)',
        'leaders': [
          {'rank': '#1', 'name': 'Ananya_Learner', 'ret': '+18.4%'},
          {'rank': '#2', 'name': 'Rohit_Student', 'ret': '+14.9%'},
          {'rank': '#3', 'name': 'Manish_Trader', 'ret': '+12.3%'},
        ],
      },
    ];

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active StockGro Trading Leagues', style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Join live tournaments, compete on real-time tick data, win real cash pool rewards.', style: TextStyle(color: textSub, fontSize: 12)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Joined Mega League! ₹10,00,000 Virtual League Portfolio allocated.'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              },
              icon: const Icon(Icons.add_task_rounded, size: 16, color: Colors.white),
              label: const Text('Join Quick League', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Grid / List of Leagues
        ...leagues.map((lg) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (lg['badgeColor'] as Color).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: lg['badgeColor'] as Color, width: 0.8),
                        ),
                        child: Text(
                          lg['badge'] as String,
                          style: TextStyle(color: lg['badgeColor'] as Color, fontSize: 10.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: (lg['status'] == 'LIVE NOW') ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFF64748B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          lg['status'] as String,
                          style: TextStyle(
                            color: (lg['status'] == 'LIVE NOW') ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(lg['endsIn'] as String, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lg['title'] as String, style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text('Segment: ${lg['segment']} · ${lg['participants']}', style: TextStyle(color: textSub, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Prize Pool', style: TextStyle(color: textSub, fontSize: 11)),
                          Text(lg['prize'] as String, style: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFF1E293B)),
                  const SizedBox(height: 12),

                  // Standings preview
                  Row(
                    children: [
                      const Text('Top Standings: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          children: (lg['leaders'] as List<Map<String, String>>).map((ldr) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${ldr['rank']} ', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w900)),
                                Text('${ldr['name']}: ', style: TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.w600)),
                                Text(ldr['ret']!, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
                              title: Text('Join ${lg['title']}', style: TextStyle(color: textMain, fontWeight: FontWeight.w900)),
                              content: Text(
                                'You are joining this tournament with a ₹10,00,000 Virtual League Portfolio.\n\nFirst Prize: ${lg['firstPrize']}\nRules: 8 Demats copy-eligible, real NSE tick engine.',
                                style: TextStyle(color: textSub, fontSize: 13),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Successfully entered ${lg['title']}! Your rank will update in real time.'),
                                        backgroundColor: const Color(0xFF059669),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                                  child: const Text('Confirm Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Join Arena', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ── Tab 1: Star Traders & Portfolios (StockGro Leaderboard) ──
  Widget _buildStarTradersTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final traders = [
      {
        'name': 'Rohan_AlphaQuant',
        'badge': 'SEBI PRO · QUANT',
        'return': '+164.2%',
        'winRate': '81.4%',
        'copiers': '1,420 Demats',
        'risk': 'Low Risk (1.8 Sharpe)',
        'capital': '₹4.2 Cr Managed',
        'allocation': 'NIFTY 24200 CE (40%) · TATASTEEL (30%) · RELIANCE (30%)',
        'initials': 'RA',
        'color': const Color(0xFF2563EB),
      },
      {
        'name': 'Priya_OptionsQueen',
        'badge': 'EXPIRY SPECIALIST',
        'return': '+128.5%',
        'winRate': '76.8%',
        'copiers': '980 Demats',
        'risk': 'Moderate (1.4 Sharpe)',
        'capital': '₹2.8 Cr Managed',
        'allocation': 'BANKNIFTY 51800 Straddle (60%) · Liquid Margin (40%)',
        'initials': 'PO',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'name': 'Vikram_BreakoutScalper',
        'badge': 'MOMENTUM SCALPER',
        'return': '+94.8%',
        'winRate': '84.2%',
        'copiers': '720 Demats',
        'risk': 'Low Drawdown (4.1%)',
        'capital': '₹1.9 Cr Managed',
        'allocation': 'INFY Breakout (50%) · HDFCBANK (50%)',
        'initials': 'VB',
        'color': const Color(0xFF059669),
      },
      {
        'name': 'Aditi_DeltaNeutral',
        'badge': 'HEDGING MASTER',
        'return': '+48.2%',
        'winRate': '92.0%',
        'copiers': '2,150 Demats',
        'risk': 'Ultra Low (0.6 Max DD)',
        'capital': '₹8.5 Cr Managed',
        'allocation': 'Multi-Leg Iron Condors (100% Hedged)',
        'initials': 'AD',
        'color': const Color(0xFF06B6D4),
      },
    ];

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verified Star Traders (1-Click Copy Trading)', style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Inspect top verified portfolios and automatically replicate every execution to your 8 connected Demats.', style: TextStyle(color: textSub, fontSize: 12)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF10B981), width: 0.8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF10B981)),
                  SizedBox(width: 5),
                  Text('SEBI Compliant Disclosures', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ...traders.map((tr) => Container(
              margin: const EdgeInsets.only(bottom: 16),
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
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (tr['color'] as Color).withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: tr['color'] as Color, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(tr['initials'] as String, style: TextStyle(color: tr['color'] as Color, fontWeight: FontWeight.w900, fontSize: 15)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(tr['name'] as String, style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (tr['color'] as Color).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(tr['badge'] as String, style: TextStyle(color: tr['color'] as Color, fontSize: 9.5, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('${tr['copiers']} · ${tr['capital']} · ${tr['risk']}', style: TextStyle(color: textSub, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('30D Return', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.bold)),
                          Text(tr['return'] as String, style: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.w900)),
                          Text('Win Rate: ${tr['winRate']}', style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderCol),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pie_chart_rounded, size: 16, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Live Portfolio Allocation: ${tr['allocation']}', style: TextStyle(color: textSub, fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Viewing full portfolio breakdown for ${tr['name']}.'),
                              backgroundColor: const Color(0xFF2563EB),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(side: BorderSide(color: borderCol)),
                        child: Text('Inspect Portfolio', style: TextStyle(color: textMain, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          CopyTradingEngine().replicateTrade(
                            symbol: 'NIFTY 24200 CE',
                            side: 'BUY',
                            baseQty: 25,
                            price: 214.65,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Auto Copy Active! Following ${tr['name']} across 8 synchronized demat accounts.'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
                        label: const Text('1-Click Copy Trader (8 Demats)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                      ),
                    ],
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ── Tab 2: Virtual Practice Arena (StockGro ₹10L Paper Capital) ──
  Widget _buildVirtualPracticeTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      children: [
        // Big Virtual Wallet Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: const Color(0xFF059669).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('STOCKGRO VIRTUAL PRACTICE WALLET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.6)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('100% Risk Free · Real NSE Tick Engine', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Virtual Portfolio Value', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('₹${(_virtualCapital + _virtualPnL).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '+₹${_virtualPnL.toStringAsFixed(2)} (+4.82% P&L)',
                      style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      OrderPlacementTicketDialog.show(
                        context,
                        symbol: 'NIFTY 24200 CE',
                        side: 'BUY',
                        ltp: 214.65,
                        lotSize: 25,
                        category: 'OPTIONS',
                      );
                    },
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Color(0xFF064E3B)),
                    label: const Text('Place Practice Trade', style: TextStyle(color: Color(0xFF064E3B), fontWeight: FontWeight.w900, fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _virtualCapital = 1000000.0;
                        _virtualPnL = 0.0;
                        _virtualPositions.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Virtual capital reset to ₹10,00,000.'), backgroundColor: Color(0xFF059669)),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                    label: const Text('Reset Capital', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white70)),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Deploying active practice positions to 8 real demat accounts via Copy Engine!'),
                          backgroundColor: Color(0xFF2563EB),
                        ),
                      );
                    },
                    icon: const Icon(Icons.rocket_launch_rounded, size: 16, color: Colors.white),
                    label: const Text('Deploy to Real 8 Demats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Active Practice Positions
        Text('Active Practice Positions (${_virtualPositions.length})', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('INSTRUMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                    Expanded(flex: 2, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                    Expanded(flex: 2, child: Text('AVG PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                    Expanded(flex: 2, child: Text('LTP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                    Expanded(flex: 2, child: Text('UNREALIZED P&L', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                    Expanded(flex: 2, child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF1E293B)),

              ..._virtualPositions.map((pos) {
                final sym = pos['symbol'] as String;
                final qty = pos['qty'] as int;
                final avg = pos['avg'] as double;
                final ltp = pos['ltp'] as double;
                final pnl = pos['pnl'] as double;
                final isUp = pos['isUp'] as bool;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderCol)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sym, style: TextStyle(color: textMain, fontWeight: FontWeight.w800, fontSize: 13)),
                            Text(pos['type'] as String, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text('$qty Qty', style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('₹${avg.toStringAsFixed(2)}', style: TextStyle(color: textSub, fontSize: 13))),
                      Expanded(flex: 2, child: Text('₹${ltp.toStringAsFixed(2)}', style: TextStyle(color: textMain, fontWeight: FontWeight.w700, fontSize: 13))),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '+₹${pnl.toStringAsFixed(2)}',
                          style: TextStyle(color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _virtualPositions.remove(pos);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Position for $sym squared off in virtual wallet.'), backgroundColor: const Color(0xFFD97706)),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: const Text('Square Off', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Community Sentiment, Crowd Bull/Bear Gauges & Buzzing Stocks ──
  Widget _buildCommunitySentimentTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final totalNifty = _niftyBullVotes + _niftyBearVotes;
    final niftyBullPct = ((_niftyBullVotes / totalNifty) * 100).toStringAsFixed(1);
    final niftyBearPct = ((_niftyBearVotes / totalNifty) * 100).toStringAsFixed(1);

    final totalBank = _bankNiftyBullVotes + _bankNiftyBearVotes;
    final bankBullPct = ((_bankNiftyBullVotes / totalBank) * 100).toStringAsFixed(1);
    final bankBearPct = ((_bankNiftyBearVotes / totalBank) * 100).toStringAsFixed(1);

    final buzzingStocks = [
      {'symbol': 'TATASTEEL', 'ltp': 190.20, 'chg': '+2.09%', 'volume': '8,410 Trades in Leagues', 'bullish': '82%'},
      {'symbol': 'ZOMATO', 'ltp': 264.50, 'chg': '+4.15%', 'volume': '6,230 Trades in Leagues', 'bullish': '88%'},
      {'symbol': 'RELIANCE', 'ltp': 2940.50, 'chg': '+0.85%', 'volume': '5,180 Trades in Leagues', 'bullish': '71%'},
      {'symbol': 'SUZLON', 'ltp': 68.40, 'chg': '+3.40%', 'volume': '4,990 Trades in Leagues', 'bullish': '65%'},
      {'symbol': 'HDFCBANK', 'ltp': 1542.10, 'chg': '-0.45%', 'volume': '3,810 Trades in Leagues', 'bullish': '54%'},
    ];

    return ListView(
      children: [
        Text('Crowd Market Sentiment Gauges', style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Real-time crowd voting and allocation ratios from 18,000+ StockGro community traders.', style: TextStyle(color: textSub, fontSize: 12)),
        const SizedBox(height: 16),

        // 2 Gauge Cards (Nifty & Bank Nifty)
        Row(
          children: [
            Expanded(
              child: _buildSentimentPollCard(
                title: 'NIFTY 50 Sentiment',
                bullPct: niftyBullPct,
                bearPct: niftyBearPct,
                totalVotes: totalNifty,
                userVote: _userNiftyVote,
                onVote: (vote) {
                  setState(() {
                    _userNiftyVote = vote;
                    if (vote == 'BULL') _niftyBullVotes++;
                    if (vote == 'BEAR') _niftyBearVotes++;
                  });
                },
                isDark: isDark,
                cardBg: cardBg,
                borderCol: borderCol,
                textMain: textMain,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSentimentPollCard(
                title: 'BANK NIFTY Sentiment',
                bullPct: bankBullPct,
                bearPct: bankBearPct,
                totalVotes: totalBank,
                userVote: _userBankNiftyVote,
                onVote: (vote) {
                  setState(() {
                    _userBankNiftyVote = vote;
                    if (vote == 'BULL') _bankNiftyBullVotes++;
                    if (vote == 'BEAR') _bankNiftyBearVotes++;
                  });
                },
                isDark: isDark,
                cardBg: cardBg,
                borderCol: borderCol,
                textMain: textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Buzzing Stocks in StockGro Leagues
        Text('Trending Buzz Stocks in Leagues Today', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            children: buzzingStocks.map((stk) {
              final sym = stk['symbol'] as String;
              final price = (stk['ltp'] as num).toDouble();
              final chg = stk['chg'] as String;
              final isPos = chg.startsWith('+');

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderCol)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('NSE EQ', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sym, style: TextStyle(color: textMain, fontWeight: FontWeight.w800, fontSize: 13.5)),
                          Text(stk['volume'] as String, style: TextStyle(color: textSub, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${price.toStringAsFixed(2)}', style: TextStyle(color: textMain, fontWeight: FontWeight.w800, fontSize: 13.5)),
                        Text(chg, style: TextStyle(color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${stk['bullish']} Bullish', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 14),
                    // Trade with AngelOne order pad!
                    ElevatedButton(
                      onPressed: () {
                        OrderPlacementTicketDialog.show(
                          context,
                          symbol: sym,
                          side: 'BUY',
                          ltp: price,
                          lotSize: 1,
                          category: 'EQUITY',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Trade [B]', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSentimentPollCard({
    required String title,
    required String bullPct,
    required String bearPct,
    required int totalVotes,
    required String? userVote,
    required Function(String) onVote,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
  }) {
    return Container(
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
              Text(title, style: TextStyle(color: textMain, fontSize: 14.5, fontWeight: FontWeight.w900)),
              Text('$totalVotes Traders Voted', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Ratio Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  Expanded(
                    flex: (double.tryParse(bullPct) ?? 50).toInt(),
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                  Expanded(
                    flex: (double.tryParse(bearPct) ?? 50).toInt(),
                    child: Container(color: const Color(0xFFEF4444)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🟢 Bullish: $bullPct%', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w900)),
              Text('🔴 Bearish: $bearPct%', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),

          // User Voting Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onVote('BULL'),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.white),
                  label: Text(userVote == 'BULL' ? 'Voted Bullish ✓' : 'Vote Bullish', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onVote('BEAR'),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.white),
                  label: Text(userVote == 'BEAR' ? 'Voted Bearish ✓' : 'Vote Bearish', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
