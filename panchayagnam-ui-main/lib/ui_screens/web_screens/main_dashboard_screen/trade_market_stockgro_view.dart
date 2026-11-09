import 'package:flutter/material.dart';
import '../../../reusable_widets/order_placement_ticket_dialog.dart';
import '../../../service/theme_mode_service.dart';
import '../../../service/copy_trading_engine.dart';

/// TradeMarketStockGroView
/// Full StockGro Experience matching the exact Mobile/Web "More" Hub & Trading Tools:
/// - Trading Tools Grid (Trade Ideas 🔥 HOT, Expert Opinions, Market Movers, STOXO AI, Watchlist, Scanners)
/// - Learning & Insights Grid (News, Academy, Shop / Rewards)
/// - Interactive Dialogs with 1-Click Order Execution across 8 Demats
/// - Social Trading Leagues (₹5,00,000+ Prize Pools)
/// - Star Traders Leaderboard & ₹10,00,000 Virtual Practice Wallet
class TradeMarketStockGroView extends StatefulWidget {
  final int initialTabIndex;
  const TradeMarketStockGroView({super.key, this.initialTabIndex = 0});

  @override
  State<TradeMarketStockGroView> createState() => _TradeMarketStockGroViewState();
}

class _TradeMarketStockGroViewState extends State<TradeMarketStockGroView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Virtual Wallet State
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

  // Community Sentiment Poll
  int _niftyBullVotes = 9710;
  int _niftyBearVotes = 4580;
  String? _userNiftyVote;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 5),
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
                // 1. Purple App Bar Header (Matching StockGro Screenshot "← More")
                _buildStockGroPurpleHeader(isDark),

                // 2. Navigation Pills
                Container(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF5D3FD3),
                    unselectedLabelColor: textSub,
                    indicatorColor: const Color(0xFF5D3FD3),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    tabs: const [
                      Tab(icon: Icon(Icons.apps_rounded, size: 17), text: 'Tools & Hub (StockGro)'),
                      Tab(icon: Icon(Icons.local_fire_department_rounded, size: 17), text: 'Trade Ideas 🔥'),
                      Tab(icon: Icon(Icons.smart_toy_rounded, size: 17), text: 'STOXO AI'),
                      Tab(icon: Icon(Icons.emoji_events_rounded, size: 17), text: 'Trading Leagues'),
                      Tab(icon: Icon(Icons.military_tech_rounded, size: 17), text: 'Star Traders'),
                      Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 17), text: 'Virtual Wallet (₹10L)'),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // 3. Tab Body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    height: 1250,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 0: The EXACT StockGro Screenshot Hub Layout!
                        _buildStockGroMoreHub(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 1: Live Trade Ideas
                        _buildTradeIdeasTab(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 2: STOXO AI Copilot
                        _buildStoxoAITab(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 3: Trading Leagues
                        _buildTradingLeaguesTab(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 4: Star Traders
                        _buildStarTradersTab(isDark, cardBg, borderCol, textMain, textSub),

                        // Tab 5: Virtual Arena
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

  // ── StockGro Signature Purple Top Bar ("← More") ──
  Widget _buildStockGroPurpleHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5D3FD3), Color(0xFF4C2DBB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'More',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: Color(0xFFFDE047), size: 14),
                SizedBox(width: 4),
                Text('STOCKGRO PRO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
          const Spacer(),
          // Live Stats badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.people_alt_rounded, color: Color(0xFF38BDF8), size: 14),
                SizedBox(width: 5),
                Text('18,420 Active Traders', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 0: The Exact StockGro Screenshot "More" Hub Layout ──
  Widget _buildStockGroMoreHub(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      children: [
        // Section 1: Trading Tools
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trading Tools',
              style: TextStyle(
                color: textMain,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF5D3FD3).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('SEBI REGULATED', style: TextStyle(color: Color(0xFF5D3FD3), fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2-Column Responsive Grid of Trading Tools
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth > 640)
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // 1. Trade Ideas (HOT)
                _buildStockGroHubCard(
                  width: cardWidth,
                  title: 'Trade Ideas',
                  subtitle: 'Stock & Option trades',
                  hotBadge: true,
                  pillBadge: 'SEBI Regd. Analysts',
                  pillColor: const Color(0xFF5D3FD3),
                  illustrationType: 'trade_ideas',
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showTradeIdeasModal(context, isDark),
                ),

                // 2. Expert Opinions
                _buildStockGroHubCard(
                  width: cardWidth,
                  title: 'Expert Opinions',
                  subtitle: 'Insights from\nSEBI Regd. Analysts',
                  illustrationType: 'expert_opinions',
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showExpertOpinionsModal(context, isDark),
                ),

                // 3. Market Movers
                _buildStockGroHubCard(
                  width: cardWidth,
                  title: 'Market Movers',
                  subtitle: 'Top daily stocks',
                  illustrationType: 'market_movers',
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showMarketMoversModal(context, isDark),
                ),

                // 4. STOXO (AI Stock Research)
                _buildStockGroHubCard(
                  width: cardWidth,
                  title: 'STOXO',
                  subtitle: 'AI-powered stock research',
                  illustrationType: 'stoxo',
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showStoxoAIModal(context, isDark),
                ),

                // 5. Watchlist
                _buildStockGroHubCard(
                  width: cardWidth,
                  title: 'Watchlist',
                  subtitle: 'Track stocks',
                  illustrationType: 'watchlist',
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showWatchlistModal(context, isDark),
                ),

                // 6. Scanners
                _buildStockGroHubCard(
                  width: cardWidth,
                  title: 'Scanners',
                  subtitle: 'Stock & Options',
                  illustrationType: 'scanners',
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showScannersModal(context, isDark),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        // Section 2: Learning & Insights
        Text(
          'Learning & Insights',
          style: TextStyle(
            color: textMain,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth > 640)
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // 7. News
                _buildStockGroHubCard(
                  width: cardWidth,
                  title: 'News',
                  subtitle: 'Market updates & analysis',
                  illustrationType: 'news',
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showNewsModal(context, isDark),
                ),

                // 8. Academy
                _buildStockGroHubCard(
                  width: cardWidth,
                  title: 'Academy',
                  subtitle: 'Learn to trade & invest',
                  illustrationType: 'academy',
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showAcademyModal(context, isDark),
                ),

                // 9. Shop
                _buildStockGroHubCard(
                  width: cardWidth,
                  title: 'Shop',
                  subtitle: 'StockGro merchandise',
                  illustrationType: 'shop',
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showShopModal(context, isDark),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── StockGro Card Builder (Accurately Styled with 3D Illustrations) ──
  Widget _buildStockGroHubCard({
    required double width,
    required String title,
    required String subtitle,
    required String illustrationType,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
    required Color textSub,
    required VoidCallback onTap,
    bool hotBadge = false,
    String? pillBadge,
    Color? pillColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        height: 110,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textMain,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (hotBadge) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔥', style: TextStyle(fontSize: 9)),
                              SizedBox(width: 2),
                              Text('HOT', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textSub,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (pillBadge != null) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (pillColor ?? const Color(0xFF5D3FD3)).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pillBadge,
                        style: TextStyle(
                          color: pillColor ?? const Color(0xFF5D3FD3),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Right 3D-Styled Illustration Emblem
            _buildIllustrationEmblem(illustrationType, isDark),
          ],
        ),
      ),
    );
  }

  // ── Beautiful 3D Illustrated Emblems Matching the StockGro App ──
  Widget _buildIllustrationEmblem(String type, bool isDark) {
    switch (type) {
      case 'trade_ideas':
        // Dartboard with bullseye, arrows & gold coins
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF5D3FD3).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFFFDE047), Color(0xFF5D3FD3), Color(0xFF3B1E8C)],
                    stops: [0.2, 0.65, 1.0],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 28),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('₹', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                ),
              ),
            ],
          ),
        );

      case 'expert_opinions':
        // Monitor with analyst team avatars
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 52,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.co_present_rounded, color: Colors.white, size: 26),
            ),
          ),
        );

      case 'market_movers':
        // 3D rising bars with gold coins
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 10,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 10,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 10,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        );

      case 'stoxo':
        // Stoxo Cute Robot Face Mascot
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFEA580C).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFEA580C).withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 7, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 10),
                      Container(width: 7, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                  Positioned(
                    top: 5,
                    child: Container(width: 4, height: 6, decoration: BoxDecoration(color: const Color(0xFFFDE047), borderRadius: BorderRadius.circular(2))),
                  ),
                ],
              ),
            ),
          ),
        );

      case 'watchlist':
        // Clipboard with checklist & magnifying glass
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.assignment_rounded, color: Color(0xFF8B5CF6), size: 36),
          ),
        );

      case 'scanners':
        // Monitor with chart & magnifying glass
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.manage_search_rounded, color: Color(0xFF0891B2), size: 38),
          ),
        );

      case 'news':
        // Newspaper & megaphone
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.newspaper_rounded, color: Color(0xFFDC2626), size: 34),
          ),
        );

      case 'academy':
        // Graduation cap & books
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF5D3FD3).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.school_rounded, color: Color(0xFF5D3FD3), size: 34),
          ),
        );

      case 'shop':
        // Storefront with purple awning
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.storefront_rounded, color: Color(0xFF059669), size: 34),
          ),
        );

      default:
        return const SizedBox(width: 76, height: 76);
    }
  }

  // ── 1. Trade Ideas Modal (🔥 HOT Calls by SEBI Regd. Analysts with 1-Click Order Pad) ──
  void _showTradeIdeasModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        final calls = [
          {
            'symbol': 'NIFTY 24DEC 24200 CE',
            'type': 'INTRADAY OPTIONS',
            'entry': 214.65,
            'tgt1': 245.0,
            'tgt2': 280.0,
            'sl': 175.0,
            'analyst': 'Rohan Sharma (SEBI RA: INH000012891)',
            'rationale': 'Heavy call unwinding at 24,200 strike + metal index momentum.',
            'category': 'OPTIONS',
            'lot': 25,
          },
          {
            'symbol': 'TATASTEEL',
            'type': 'SWING CASH (NSE)',
            'entry': 190.20,
            'tgt1': 202.0,
            'tgt2': 215.0,
            'sl': 181.0,
            'analyst': 'Neha Gupta (SEBI RA: INH000008432)',
            'rationale': 'Breakout from 3-week consolidation on 2.5x volume surge.',
            'category': 'EQUITY',
            'lot': 1,
          },
          {
            'symbol': 'BANKNIFTY 51800 PE',
            'type': 'EXPIRY HEDGE',
            'entry': 378.10,
            'tgt1': 420.0,
            'tgt2': 475.0,
            'sl': 310.0,
            'analyst': 'Vikram Sen (SEBI RA: INH000015674)',
            'rationale': 'Rejection at 52,000 psychological resistance + high put IV.',
            'category': 'OPTIONS',
            'lot': 15,
          },
        ];

        return Dialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderCol)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFEA580C), borderRadius: BorderRadius.circular(6)),
                        child: const Text('🔥 HOT CALLS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 10),
                      Text('Trade Ideas (SEBI Regd. Analysts)', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      IconButton(icon: Icon(Icons.close_rounded, color: textSub, size: 20), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: calls.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (c, i) {
                        final call = calls[i];
                        final sym = call['symbol'] as String;
                        final entry = (call['entry'] as num).toDouble();
                        final tgt1 = call['tgt1'] as double;
                        final tgt2 = call['tgt2'] as double;
                        final sl = call['sl'] as double;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderCol),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(sym, style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w900)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFF5D3FD3).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                    child: Text(call['type'] as String, style: const TextStyle(color: Color(0xFF5D3FD3), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                  ),
                                  const Spacer(),
                                  Text('Entry: ₹$entry', style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('🎯 Target 1: ₹$tgt1', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 12),
                                  Text('🎯 Target 2: ₹$tgt2', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 12),
                                  Text('🛑 SL: ₹$sl', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('💡 ${call['rationale']}', style: TextStyle(color: textSub, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('By ${call['analyst']}', style: const TextStyle(color: Color(0xFF5D3FD3), fontSize: 10.5, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      OrderPlacementTicketDialog.show(
                                        context,
                                        symbol: sym,
                                        side: 'BUY',
                                        ltp: entry,
                                        lotSize: (call['lot'] as num?)?.toInt() ?? 1,
                                        category: call['category'] as String,
                                      );
                                    },
                                    icon: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
                                    label: const Text('Execute Call (8 Demats)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5)),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                                  ),
                                ],
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
        );
      },
    );
  }

  // ── 2. Expert Opinions Modal ──
  void _showExpertOpinionsModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.co_present_rounded, color: Color(0xFF5D3FD3)),
            SizedBox(width: 10),
            Text('Expert Opinions & Market Outlook', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• NIFTY Daily Outlook: Bulls in charge above 24,180. Key resistance at 24,350.', style: TextStyle(fontSize: 12.5)),
            SizedBox(height: 8),
            Text('• Institutional Flow: FII net bought +₹1,240 Cr; DII bought +₹890 Cr today.', style: TextStyle(fontSize: 12.5)),
            SizedBox(height: 8),
            Text('• Sector Watch: Metal index (Nifty Metal) leading today (+2.4%), Auto (+1.6%).', style: TextStyle(fontSize: 12.5)),
            SizedBox(height: 8),
            Text('• Options Expiry Range: Max pain settled at 24,150; heavy put writing at 24,100.', style: TextStyle(fontSize: 12.5)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss')),
        ],
      ),
    );
  }

  // ── 3. Market Movers Modal ──
  void _showMarketMoversModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final gainers = [
          {'symbol': 'TATASTEEL', 'ltp': 190.20, 'chg': '+2.09%'},
          {'symbol': 'ZOMATO', 'ltp': 264.50, 'chg': '+4.15%'},
          {'symbol': 'RELIANCE', 'ltp': 2940.50, 'chg': '+0.85%'},
          {'symbol': 'INFY', 'ltp': 1785.40, 'chg': '+1.10%'},
        ];

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          title: const Text('Today\'s Market Movers (Top Daily Stocks)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: gainers.map((g) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(g['symbol'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('₹${(g['ltp'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(g['chg'] as String, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        OrderPlacementTicketDialog.show(context, symbol: g['symbol'] as String, side: 'BUY', ltp: g['ltp'] as double, lotSize: 1, category: 'EQUITY');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                      child: const Text('Trade [B]', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  // ── 4. STOXO AI Modal ──
  void _showStoxoAIModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.smart_toy_rounded, color: Color(0xFFEA580C)),
            SizedBox(width: 10),
            Text('STOXO AI · Stock Research Copilot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask STOXO AI for technical breakouts, fundamental valuation, and option Greeks:', style: TextStyle(fontSize: 12)),
            SizedBox(height: 10),
            Text('• "NIFTY 24200 CE looks attractive with PCR 0.92 and positive volume divergence."', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            SizedBox(height: 6),
            Text('• "Tata Steel RSI is at 62 (Bullish momentum zone), target ₹205 with trailing SL ₹185."', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tabController.animateTo(2); // Jump to STOXO AI tab
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            child: const Text('Open Full STOXO AI Console', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── 5. Watchlist Modal ──
  void _showWatchlistModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: const Text('Your Pro Watchlist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: const Text('Tracking: NIFTY 50, BANK NIFTY, TATASTEEL, RELIANCE, ZOMATO.\n\nAll instruments are synchronized with NSE live tick feeds.', style: TextStyle(fontSize: 12.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── 6. Scanners Modal ──
  void _showScannersModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: const Text('Stock & Options Scanners', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Supertrend Bullish Flip: 4 Stocks detected (Tata Steel, Reliance, Zomato, Suzlon)', style: TextStyle(fontSize: 12)),
            SizedBox(height: 6),
            Text('• High Call OI Unwinding: NIFTY 24150 CE & 24200 CE', style: TextStyle(fontSize: 12)),
            SizedBox(height: 6),
            Text('• Volume Shockers (> 300% 10D Avg): Metal & PSU Banks', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── 7. News Modal ──
  void _showNewsModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: const Text('Market News & Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: const Text('• Metal stocks rally as global demand forecasts improve.\n• RBI hints at stable interest rates for upcoming MPC meet.\n• FIIs turn net buyers in cash market for 3rd consecutive session.', style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── 8. Academy Modal ──
  void _showAcademyModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: const Text('StockGro Academy (Learn to Trade)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: const Text('• Module 1: Options Greeks Demystified (Delta, Theta, Gamma, Vega)\n• Module 2: Price Action & Support-Resistance Strategies\n• Module 3: Algo Trading & 8-Demat Copy Replication\n\n100% Free for Panchayagnam users.', style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── 9. Shop Modal ──
  void _showShopModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: const Text('StockGro Merchandise & Rewards Shop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: const Text('Redeem your League Trophy Coins for:\n\n• Panchayagnam Pro Fast Pass (Zero Brokerage)\n• StockGro Official Hoodies & Merchandise\n• Priority Multi-Demat API Latency Passes', style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Tab 1: Live Trade Ideas Tab ──
  Widget _buildTradeIdeasTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFEA580C), borderRadius: BorderRadius.circular(6)),
              child: const Text('🔥 HOT CALLS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Text('Stock & Option Calls from SEBI Regd. Analysts', style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 14),
        _buildTradeIdeaCard('NIFTY 24DEC 24200 CE', 214.65, 245.0, 280.0, 175.0, 'Rohan Sharma (SEBI RA: INH000012891)', 'Heavy call unwinding at 24,200 strike + metal rally.', 'OPTIONS', 25, isDark, cardBg, borderCol, textMain, textSub),
        const SizedBox(height: 12),
        _buildTradeIdeaCard('TATASTEEL', 190.20, 202.0, 215.0, 181.0, 'Neha Gupta (SEBI RA: INH000008432)', 'Breakout on 2.5x volume surge above 188.', 'EQUITY', 1, isDark, cardBg, borderCol, textMain, textSub),
        const SizedBox(height: 12),
        _buildTradeIdeaCard('BANKNIFTY 51800 PE', 378.10, 420.0, 475.0, 310.0, 'Vikram Sen (SEBI RA: INH000015674)', 'Expiry hedge at 52,000 resistance level.', 'OPTIONS', 15, isDark, cardBg, borderCol, textMain, textSub),
      ],
    );
  }

  Widget _buildTradeIdeaCard(String sym, double entry, double tgt1, double tgt2, double sl, String analyst, String rationale, String cat, int lot, bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(sym, style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('Entry: ₹$entry', style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('🎯 Target 1: ₹$tgt1', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 14),
              Text('🎯 Target 2: ₹$tgt2', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 14),
              Text('🛑 SL: ₹$sl', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(rationale, style: TextStyle(color: textSub, fontSize: 11.5)),
          const SizedBox(height: 2),
          Text('By $analyst', style: const TextStyle(color: Color(0xFF5D3FD3), fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                OrderPlacementTicketDialog.show(
                  context,
                  symbol: sym,
                  side: 'BUY',
                  ltp: entry,
                  lotSize: lot,
                  category: cat,
                );
              },
              icon: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
              label: const Text('Place Buy Order (8 Demats)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: STOXO AI Tab ──
  Widget _buildStoxoAITab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFFEA580C).withOpacity(0.15), const Color(0xFFF97316).withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEA580C).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.smart_toy_rounded, color: Color(0xFFEA580C), size: 24),
                  SizedBox(width: 10),
                  Text('STOXO AI · StockGro Autonomous Market Research', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFEA580C))),
                ],
              ),
              const SizedBox(height: 8),
              Text('Powered by Gemini 2.5 Flash + Real-Time NSE Tick Stream for automated trade discovery.', style: TextStyle(color: textSub, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                style: TextStyle(color: textMain, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ask STOXO AI: "Find high volume breakouts in metals" or "Evaluate Nifty 24200 CE"...',
                  hintStyle: TextStyle(color: textSub, fontSize: 12),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('STOXO AI analyzing NSE order book and Greeks...'), backgroundColor: Color(0xFFEA580C)),
                  );
                },
                icon: const Icon(Icons.psychology_rounded, size: 16, color: Colors.white),
                label: const Text('Run STOXO AI Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Trading Leagues ──
  Widget _buildTradingLeaguesTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Active StockGro Trading Leagues', style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.w800)),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Joined Mega League! ₹10,00,000 Virtual League Portfolio allocated.'), backgroundColor: Color(0xFF059669)),
                );
              },
              icon: const Icon(Icons.add_task_rounded, size: 16, color: Colors.white),
              label: const Text('Join Quick League', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildLeagueItem('Nifty Bull Mega League', '₹5,00,000 Pool', 'LIVE NOW', '3,420 Traders', isDark, cardBg, borderCol, textMain, textSub),
        const SizedBox(height: 12),
        _buildLeagueItem('Options Champions Arena', '₹2,50,000 Pool', 'LIVE NOW', '1,890 Traders', isDark, cardBg, borderCol, textMain, textSub),
      ],
    );
  }

  Widget _buildLeagueItem(String title, String prize, String status, String participants, bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('$participants · $status', style: TextStyle(color: textSub, fontSize: 11)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(prize, style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Entered $title successfully!'), backgroundColor: const Color(0xFF059669)),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D3FD3), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                child: const Text('Join Arena', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Star Traders ──
  Widget _buildStarTradersTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      children: [
        Text('Verified Star Traders (1-Click Copy)', style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _buildTraderRow('Rohan_AlphaQuant', '+164.2%', '81.4%', '1,420 Demats', 'SEBI PRO · QUANT', isDark, cardBg, borderCol, textMain, textSub),
        const SizedBox(height: 12),
        _buildTraderRow('Priya_OptionsQueen', '+128.5%', '76.8%', '980 Demats', 'EXPIRY SPECIALIST', isDark, cardBg, borderCol, textMain, textSub),
      ],
    );
  }

  Widget _buildTraderRow(String name, String ret, String win, String copiers, String badge, bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: const Color(0xFF5D3FD3).withOpacity(0.15), child: Text(name.substring(0, 2), style: const TextStyle(color: Color(0xFF5D3FD3), fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w900)),
                Text('$copiers · $badge', style: TextStyle(color: textSub, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ret, style: const TextStyle(color: Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.w900)),
              Text('Win: $win', style: TextStyle(color: textSub, fontSize: 10.5)),
            ],
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              CopyTradingEngine().replicateTrade(symbol: 'NIFTY 24200 CE', side: 'BUY', baseQty: 25, price: 214.65);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto Copying $name across 8 demats!'), backgroundColor: const Color(0xFF059669)));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            child: const Text('1-Click Copy', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Tab 5: Virtual Practice Arena ──
  Widget _buildVirtualPracticeTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF5D3FD3), Color(0xFF4C2DBB)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('STOCKGRO VIRTUAL PRACTICE WALLET', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text('₹${(_virtualCapital + _virtualPnL).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('+₹48,250.00 (+4.82% P&L) · Real NSE Tick Engine', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Virtual Positions (${_virtualPositions.length})', style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ..._virtualPositions.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p['symbol'] as String, style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
                  Text('${p['qty']} Qty', style: TextStyle(color: textSub)),
                  Text('+₹${p['pnl']}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ],
              ),
            )),
      ],
    );
  }
}
