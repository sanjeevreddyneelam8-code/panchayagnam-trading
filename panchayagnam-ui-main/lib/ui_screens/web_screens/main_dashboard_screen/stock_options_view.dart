import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../reusable_widets/order_placement_ticket_dialog.dart';
import '../../../service/live_market_data_service.dart';
import '../../../service/theme_mode_service.dart';

/// Stock Item representation for F&O Stock Watchlist
class StockWatchItem {
  final String symbol;
  final String companyName;
  final String exchange;
  final String token;
  final double ltp;
  final double change;
  final double changePercent;
  final double open;
  final double high;
  final double low;
  final double prevClose;
  final int lotSize;
  final int volume;
  final String category;

  const StockWatchItem({
    required this.symbol,
    required this.companyName,
    this.exchange = 'NSE',
    this.token = '',
    required this.ltp,
    required this.change,
    required this.changePercent,
    required this.open,
    required this.high,
    required this.low,
    required this.prevClose,
    required this.lotSize,
    required this.volume,
    this.category = 'F&O',
  });

  bool get isPositive => change >= 0;
}

/// Stock Option Strike Row
class StockOptionStrike {
  final double strike;
  final bool isAtm;
  final double callLtp;
  final double callChangePercent;
  final String callVolume;
  final double callOi;
  final double callIv;
  final double putLtp;
  final double putChangePercent;
  final String putVolume;
  final double putOi;
  final double putIv;

  const StockOptionStrike({
    required this.strike,
    this.isAtm = false,
    required this.callLtp,
    required this.callChangePercent,
    required this.callVolume,
    required this.callOi,
    required this.callIv,
    required this.putLtp,
    required this.putChangePercent,
    required this.putVolume,
    required this.putOi,
    required this.putIv,
  });
}

/// Main Stock Options Screen (matching Images 2, 3, 4)
class StockOptionsView extends StatefulWidget {
  final VoidCallback? onNavigateToOrders;
  final VoidCallback? onNavigateToPositions;
  final VoidCallback? onNavigateToCharts;

  const StockOptionsView({
    super.key,
    this.onNavigateToOrders,
    this.onNavigateToPositions,
    this.onNavigateToCharts,
  });

  @override
  State<StockOptionsView> createState() => _StockOptionsViewState();
}

class _StockOptionsViewState extends State<StockOptionsView> {
  // Navigation / View state: 0 = Watchlist (Image 2), 1 = Option Chain (Image 4)
  int _currentViewMode = 0;

  // Search filter
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Watchlist tabs
  int _activeWatchlistTab = 1; // 0: Options, 1: mywatchlist, 2: NIFTYBANK, 3: NIFTYIT
  final List<String> _tabs = ['Options', 'mywatchlist', 'NIFTYBANK', 'NIFTYIT'];

  // Currently selected stock for details (Image 3) or option chain (Image 4)
  late StockWatchItem _selectedStock;

  // Option Chain Filter mode: 0 = LTP, 1 = OI, 2 = Greeks
  int _optionChainFilter = 0;
  String _selectedExpiry = '23 Nov 2026 M';
  final List<String> _expiryDates = [
    '23 Nov 2026 M',
    '28 Dec 2026 M',
    '29 Jan 2027 M',
  ];

  // Benchmark index values synced with live Angel One NSE/BSE feed
  double _niftySpot = 25227.95;
  double _niftyChange = 0.0;
  double _niftyChangePct = 0.0;

  double _sensexSpot = 82030.21;
  double _sensexChange = 0.0;
  double _sensexChangePct = 0.0;

  // Master list of stocks synced with live Angel One feed
  late List<StockWatchItem> _allStocks;

  @override
  void initState() {
    super.initState();
    _initStockData();
    _selectedStock = _allStocks.first;
    LiveMarketDataService().addListener(_syncLiveStockPrices);
    LiveMarketDataService().start();
    _syncLiveStockPrices();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    LiveMarketDataService().removeListener(_syncLiveStockPrices);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _syncLiveStockPrices() {
    if (!mounted) return;
    final svc = LiveMarketDataService();
    bool changed = false;

    final nq = svc.getQuote('NIFTY');
    if (nq != null && nq.ltp > 0) {
      _niftySpot = nq.ltp;
      _niftyChange = nq.change;
      _niftyChangePct = nq.changePct;
      changed = true;
    }
    final sq = svc.getQuote('SENSEX');
    if (sq != null && sq.ltp > 0) {
      _sensexSpot = sq.ltp;
      _sensexChange = sq.change;
      _sensexChangePct = sq.changePct;
      changed = true;
    }

    for (int i = 0; i < _allStocks.length; i++) {
      final item = _allStocks[i];
      final q = svc.getQuote(item.symbol);
      if (q != null && q.ltp > 0) {
        final updated = StockWatchItem(
          symbol: item.symbol,
          companyName: item.companyName,
          exchange: item.exchange,
          token: item.token,
          ltp: q.ltp,
          change: q.change,
          changePercent: q.changePct,
          open: item.open,
          high: q.high > 0 ? q.high : q.ltp,
          low: q.low > 0 ? q.low : q.ltp,
          prevClose: q.prevClose > 0 ? q.prevClose : item.prevClose,
          lotSize: item.lotSize,
          volume: q.volume > 0 ? q.volume : item.volume,
          category: item.category,
        );
        _allStocks[i] = updated;
        if (_selectedStock.symbol == item.symbol) {
          _selectedStock = updated;
        }
        changed = true;
      }
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  void _initStockData() {
    _allStocks = [
      // Exact stocks from Image 2
      const StockWatchItem(
        symbol: 'IOC',
        companyName: 'Indian Oil Corporation Ltd',
        exchange: 'NSE',
        token: '898',
        ltp: 144.04,
        change: -2.13,
        changePercent: -1.46,
        open: 145.38,
        high: 145.38,
        low: 143.24,
        prevClose: 146.17,
        lotSize: 4875,
        volume: 24500000,
      ),
      const StockWatchItem(
        symbol: 'BEL',
        companyName: 'Bharat Electronics Ltd',
        exchange: 'NSE',
        token: '383',
        ltp: 400.85,
        change: -3.95,
        changePercent: -0.98,
        open: 405.00,
        high: 406.80,
        low: 398.20,
        prevClose: 404.80,
        lotSize: 1425,
        volume: 18200000,
      ),
      const StockWatchItem(
        symbol: 'HAL',
        companyName: 'Hindustan Aeronautics Ltd',
        exchange: 'NSE',
        token: '2303',
        ltp: 4809.80,
        change: -33.60,
        changePercent: -0.69,
        open: 4845.00,
        high: 4875.00,
        low: 4790.00,
        prevClose: 4843.40,
        lotSize: 150,
        volume: 4200000,
      ),
      const StockWatchItem(
        symbol: 'POLICYBZR',
        companyName: 'PB Fintech Ltd',
        exchange: 'NSE',
        token: '4871',
        ltp: 1105.00,
        change: 54.90,
        changePercent: 5.23,
        open: 1055.00,
        high: 1118.00,
        low: 1048.00,
        prevClose: 1050.10,
        lotSize: 350,
        volume: 11500000,
      ),
      const StockWatchItem(
        symbol: 'ABB',
        companyName: 'ABB India Ltd',
        exchange: 'NSE',
        token: '20',
        ltp: 7054.50,
        change: 131.50,
        changePercent: 1.90,
        open: 6950.00,
        high: 7120.00,
        low: 6920.00,
        prevClose: 6923.00,
        lotSize: 125,
        volume: 1800000,
      ),
      const StockWatchItem(
        symbol: 'POWERINDIA',
        companyName: 'Hitachi Energy India Ltd',
        exchange: 'NSE',
        token: '1410',
        ltp: 31595.00,
        change: 3050.00,
        changePercent: 10.68,
        open: 28900.00,
        high: 31900.00,
        low: 28500.00,
        prevClose: 28545.00,
        lotSize: 25,
        volume: 980000,
      ),
      const StockWatchItem(
        symbol: 'SIEMENS',
        companyName: 'Siemens Ltd',
        exchange: 'NSE',
        token: '3150',
        ltp: 3660.00,
        change: -10.90,
        changePercent: -0.30,
        open: 3675.00,
        high: 3695.00,
        low: 3640.00,
        prevClose: 3670.90,
        lotSize: 150,
        volume: 1250000,
      ),
      const StockWatchItem(
        symbol: 'YESBANK',
        companyName: 'Yes Bank Ltd',
        exchange: 'NSE',
        token: '11915',
        ltp: 17.42,
        change: -0.27,
        changePercent: -1.53,
        open: 17.70,
        high: 17.85,
        low: 17.30,
        prevClose: 17.69,
        lotSize: 10000,
        volume: 85000000,
      ),
      // Top active F&O leaders
      const StockWatchItem(
        symbol: 'RELIANCE',
        companyName: 'Reliance Industries Ltd',
        exchange: 'NSE',
        token: '2885',
        ltp: 2885.50,
        change: 18.40,
        changePercent: 0.64,
        open: 2870.00,
        high: 2898.00,
        low: 2862.00,
        prevClose: 2867.10,
        lotSize: 250,
        volume: 6500000,
      ),
      const StockWatchItem(
        symbol: 'HDFCBANK',
        companyName: 'HDFC Bank Ltd',
        exchange: 'NSE',
        token: '1333',
        ltp: 1657.80,
        change: -3.40,
        changePercent: -0.20,
        open: 1662.00,
        high: 1670.00,
        low: 1652.00,
        prevClose: 1661.20,
        lotSize: 550,
        volume: 9800000,
      ),
      const StockWatchItem(
        symbol: 'TCS',
        companyName: 'Tata Consultancy Services Ltd',
        exchange: 'NSE',
        token: '11536',
        ltp: 4120.00,
        change: -24.00,
        changePercent: -0.58,
        open: 4145.00,
        high: 4160.00,
        low: 4110.00,
        prevClose: 4144.00,
        lotSize: 175,
        volume: 2400000,
      ),
      const StockWatchItem(
        symbol: 'INFY',
        companyName: 'Infosys Ltd',
        exchange: 'NSE',
        token: '1594',
        ltp: 1785.40,
        change: 19.50,
        changePercent: 1.10,
        open: 1768.00,
        high: 1792.00,
        low: 1762.00,
        prevClose: 1765.90,
        lotSize: 400,
        volume: 7200000,
      ),
    ];
  }

  List<StockWatchItem> get _filteredStocks {
    return _allStocks.where((s) {
      if (_searchQuery.isNotEmpty) {
        return s.symbol.toLowerCase().contains(_searchQuery) ||
            s.companyName.toLowerCase().contains(_searchQuery);
      }
      if (_activeWatchlistTab == 2) {
        return s.symbol == 'HDFCBANK' || s.symbol == 'YESBANK';
      }
      if (_activeWatchlistTab == 3) {
        return s.symbol == 'TCS' || s.symbol == 'INFY';
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeModeService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        final bg = isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Scaffold(
          backgroundColor: bg,
          body: _currentViewMode == 0
              ? _buildWatchlistView(cardBg, borderCol, textMain, textSub, isDark)
              : _buildOptionChainView(cardBg, borderCol, textMain, textSub, isDark),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. WATCHLIST VIEW (IMAGE 2)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWatchlistView(
    Color cardBg,
    Color borderCol,
    Color textMain,
    Color textSub,
    bool isDark,
  ) {
    return Column(
      children: [
        // Top Search Bar (Image 2)
        Container(
          color: cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: textMain, fontSize: 13.5),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: textSub, size: 20),
                    hintText: 'Search for Nifty, Sensex, Stocks (IOC, BEL, HAL, POLICYBZR...)',
                    hintStyle: TextStyle(color: textSub.withOpacity(0.8), fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, color: textSub, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Mini Index Bar (Image 2)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'NIFTY',
                                    style: TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Expiry Tue', style: TextStyle(color: Color(0xFF6366F1), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    NumberFormat('#,##,##0.00').format(_niftySpot),
                                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFFEF4444), size: 16),
                                  Text(
                                    '$_niftyChange ($_niftyChangePct%)',
                                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'SENSEX',
                                    style: TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Expiry Thu', style: TextStyle(color: Color(0xFF6366F1), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    NumberFormat('#,##,##0.00').format(_sensexSpot),
                                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFFEF4444), size: 16),
                                  Text(
                                    '$_sensexChange ($_sensexChangePct%)',
                                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tabs Row (Image 2: Options, mywatchlist, NIFTYBANK, NIFTYIT, +)
        Container(
          color: cardBg,
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ...List.generate(_tabs.length, (idx) {
                      final isSelected = _activeWatchlistTab == idx;
                      return InkWell(
                        onTap: () => setState(() => _activeWatchlistTab = idx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Text(
                            _tabs[idx],
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF2563EB) : textSub,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      color: textSub,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Custom stock watchlist creator ready.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderCol),
            ],
          ),
        ),

        // Sort & Filter Bar
        Container(
          color: cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 14, color: textSub),
              const SizedBox(width: 6),
              Text(
                'Sort & Filter (${_filteredStocks.length} Stocks)',
                style: TextStyle(color: textSub, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const Text('NSE Live Feed', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Divider(height: 1, color: borderCol),

        // Stock List (Image 2)
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _filteredStocks.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: borderCol.withOpacity(0.6)),
            itemBuilder: (ctx, idx) {
              final stock = _filteredStocks[idx];
              final isPos = stock.isPositive;
              final accent = isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444);

              return InkWell(
                onTap: () {
                  setState(() => _selectedStock = stock);
                  _showStockDetailsBottomSheet(context, stock, isDark);
                },
                child: Container(
                  color: cardBg,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Stock Symbol & Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  stock.symbol,
                                  style: TextStyle(
                                    color: textMain,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: borderCol),
                                  ),
                                  child: Text(
                                    '${stock.exchange} ${stock.token.isNotEmpty ? "• ${stock.token}" : ""}',
                                    style: TextStyle(color: textSub, fontSize: 9.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stock.companyName,
                              style: TextStyle(color: textSub, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Quick Action Pills (Option Chain & Charts)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedStock = stock;
                            _currentViewMode = 1; // Switch to Image 4 Option Chain!
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link_rounded, size: 12, color: Color(0xFF2563EB)),
                              SizedBox(width: 3),
                              Text('Options', style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // LTP & Change (Image 2)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${NumberFormat('#,##,##0.00').format(stock.ltp)}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${stock.change >= 0 ? "+" : ""}${stock.change.toStringAsFixed(2)} (${stock.changePercent.toStringAsFixed(2)}%)',
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
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
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. STOCK DETAILS MODAL / BOTTOM SHEET (IMAGE 3)
  // ═══════════════════════════════════════════════════════════════════════════
  void _showStockDetailsBottomSheet(BuildContext context, StockWatchItem stock, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final isPos = stock.isPositive;
        final accent = isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 600,
          ),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: borderCol),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Swipe / Drag Handle (Image 3)
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: textSub.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Swipe up for Stock Details',
                style: TextStyle(color: textSub, fontSize: 10, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Header: Symbol, Company Name, Price, Change (Image 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.symbol,
                            style: TextStyle(
                              color: textMain,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${stock.companyName} • ${stock.exchange}',
                            style: TextStyle(color: textSub, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Text(
                              '₹${stock.ltp.toStringAsFixed(2)}',
                              style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isPos ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                              color: accent,
                              size: 22,
                            ),
                          ],
                        ),
                        Text(
                          '${stock.change >= 0 ? "+" : ""}${stock.change.toStringAsFixed(2)} (${stock.changePercent.toStringAsFixed(2)}%)',
                          style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: borderCol),

              // OHLC Overview Card (Image 3)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildOhlcCol('Open', stock.open.toStringAsFixed(2), textMain, textSub),
                      _buildOhlcCol('High', stock.high.toStringAsFixed(2), textMain, textSub),
                      _buildOhlcCol('Low', stock.low.toStringAsFixed(2), textMain, textSub),
                      _buildOhlcCol('Prev. Close', stock.prevClose.toStringAsFixed(2), textMain, textSub),
                    ],
                  ),
                ),
              ),

              // 5-Depth Market Depth Table (Image 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B).withOpacity(0.3) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderCol),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Qty', style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('Buy Price', style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('Sell Price', style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('Qty', style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Divider(height: 1, color: borderCol.withOpacity(0.5)),
                      const SizedBox(height: 6),
                      _buildDepthRow('0', '₹0.00', '₹${stock.ltp.toStringAsFixed(2)}', '2140', textMain, textSub),
                      _buildDepthRow('0', '₹0.00', '₹0.00', '0', textMain, textSub),
                      _buildDepthRow('0', '₹0.00', '₹0.00', '0', textMain, textSub),
                      _buildDepthRow('0', '₹0.00', '₹0.00', '0', textMain, textSub),
                      _buildDepthRow('0', '₹0.00', '₹0.00', '0', textMain, textSub),
                      const SizedBox(height: 6),
                      Divider(height: 1, color: borderCol.withOpacity(0.5)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Quantity', style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
                          const Text('2140', style: TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons Row: Option Chain, Charts, Stock Details (Image 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Option Chain Pill (Image 3 -> Image 4)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedStock = stock;
                            _currentViewMode = 1; // Switch to Stock Option Chain (Image 4)!
                          });
                        },
                        icon: const Icon(Icons.link_rounded, size: 16, color: Color(0xFF2563EB)),
                        label: const Text('Option Chain', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Charts Pill
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (widget.onNavigateToCharts != null) {
                            widget.onNavigateToCharts!();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Opening live chart for ${stock.symbol}...')),
                            );
                          }
                        },
                        icon: const Icon(Icons.bar_chart_rounded, size: 16, color: Color(0xFF059669)),
                        label: const Text('Charts', style: TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF059669)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Stock Details
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Fundamentals & Delivery info for ${stock.symbol}')),
                          );
                        },
                        icon: const Icon(Icons.business_rounded, size: 16, color: Color(0xFF64748B)),
                        label: const Text('Stock Details', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: borderCol),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Large Primary BUY & SELL Buttons (Image 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            OrderPlacementTicketDialog.show(
                              context,
                              symbol: stock.symbol,
                              side: 'BUY',
                              ltp: stock.ltp,
                              lotSize: 1,
                              category: 'EQUITY',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 2,
                          ),
                          child: const Text('BUY', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            OrderPlacementTicketDialog.show(
                              context,
                              symbol: stock.symbol,
                              side: 'SELL',
                              ltp: stock.ltp,
                              lotSize: 1,
                              category: 'EQUITY',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 2,
                          ),
                          child: const Text('SELL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOhlcCol(String title, String val, Color textMain, Color textSub) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: textSub, fontSize: 10.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(val, style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildDepthRow(String bQty, String bPrice, String sPrice, String sQty, Color textMain, Color textSub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(width: 45, child: Text(bQty, style: TextStyle(color: textSub, fontSize: 11))),
          SizedBox(width: 65, child: Text(bPrice, style: const TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.bold))),
          SizedBox(width: 65, child: Text(sPrice, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.bold))),
          SizedBox(width: 45, child: Text(sQty, textAlign: TextAlign.right, style: TextStyle(color: textSub, fontSize: 11))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. STOCK OPTION CHAIN VIEW (IMAGE 4)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOptionChainView(
    Color cardBg,
    Color borderCol,
    Color textMain,
    Color textSub,
    bool isDark,
  ) {
    final strikes = _generateStrikesForStock(_selectedStock);
    final isPos = _selectedStock.isPositive;
    final accent = isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Column(
      children: [
        // Header with Back Button, Stock & Index summary (Image 4)
        Container(
          color: cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: textMain, size: 22),
                    onPressed: () => setState(() => _currentViewMode = 0),
                  ),
                  const SizedBox(width: 6),

                  // Stock Summary Pill (Image 4)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedStock.symbol,
                          style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${_selectedStock.ltp.toStringAsFixed(2)}',
                              style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${_selectedStock.change.toStringAsFixed(2)} (${_selectedStock.changePercent.toStringAsFixed(2)}%)',
                              style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Nifty Index Benchmark Pill (Image 4)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'NIFTY',
                                style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text('Expiry Tue', style: TextStyle(color: Color(0xFF6366F1), fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_niftySpot.toStringAsFixed(2)} ($_niftyChange, $_niftyChangePct%)',
                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Filter row: LTP | OI | Greeks + Expiry Dropdown (Image 4)
              Row(
                children: [
                  Icon(Icons.search_rounded, color: textSub, size: 18),
                  const SizedBox(width: 8),

                  // Segment Toggle Pills: LTP, OI, Greeks
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      children: [
                        _filterTab('LTP', 0),
                        _filterTab('OI', 1),
                        _filterTab('Greeks', 2),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Expiry Dropdown (Image 4)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderCol),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedExpiry,
                        dropdownColor: cardBg,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        style: TextStyle(color: textMain, fontSize: 11.5, fontWeight: FontWeight.w700),
                        items: _expiryDates.map((e) {
                          return DropdownMenuItem(value: e, child: Text(e));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedExpiry = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderCol),

        // Table Header: Volume | Call LTP | Strike Price | Put LTP | Volume (Image 4)
        Container(
          color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text('Volume', style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: Text('Call LTP', textAlign: TextAlign.right, style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: Text('Strike Price', textAlign: TextAlign.center, style: TextStyle(color: textMain, fontSize: 11.5, fontWeight: FontWeight.w900)),
              ),
              Expanded(
                flex: 2,
                child: Text('Put LTP', textAlign: TextAlign.left, style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: Text('Volume', textAlign: TextAlign.right, style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderCol),

        // Option Chain Rows with ATM Banner (Image 4)
        Expanded(
          child: ListView.separated(
            itemCount: strikes.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: borderCol.withOpacity(0.5)),
            itemBuilder: (ctx, idx) {
              final s = strikes[idx];
              final isAtm = s.isAtm;

              return Column(
                children: [
                  // Long Buildup / ATM Banner between strikes (Image 4)
                  if (isAtm)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      color: const Color(0xFFFEF3C7),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Long Buildup',
                            style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '|  ${_selectedStock.ltp.toStringAsFixed(2)}  |',
                            style: const TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedStock.change.toStringAsFixed(2)} (${_selectedStock.changePercent.toStringAsFixed(2)}%)',
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),

                  // Strike Row
                  Container(
                    color: isAtm
                        ? const Color(0xFFEFF6FF).withOpacity(isDark ? 0.08 : 0.4)
                        : cardBg,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Call Volume
                        Expanded(
                          flex: 2,
                          child: Text(
                            s.callVolume,
                            style: TextStyle(color: textSub, fontSize: 11),
                          ),
                        ),

                        // Call LTP (Tappable for Quick Buy/Sell)
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () {
                              final sym = '${_selectedStock.symbol} ${s.strike.toInt()} CE';
                              OrderPlacementTicketDialog.show(
                                context,
                                symbol: sym,
                                side: 'BUY',
                                ltp: s.callLtp,
                                lotSize: _selectedStock.lotSize,
                                category: 'OPTIONS',
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${s.callLtp.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${s.callChangePercent.toStringAsFixed(2)}%',
                                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 9.5),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Strike Price (Center)
                        Expanded(
                          flex: 2,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              s.strike.toInt().toString(),
                              style: TextStyle(
                                color: textMain,
                                fontSize: 13,
                                fontWeight: isAtm ? FontWeight.w900 : FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                        // Put LTP (Tappable for Quick Buy/Sell)
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () {
                              final sym = '${_selectedStock.symbol} ${s.strike.toInt()} PE';
                              OrderPlacementTicketDialog.show(
                                context,
                                symbol: sym,
                                side: 'BUY',
                                ltp: s.putLtp,
                                lotSize: _selectedStock.lotSize,
                                category: 'OPTIONS',
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₹${s.putLtp.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFF059669), fontSize: 12.5, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '+${s.putChangePercent.toStringAsFixed(2)}%',
                                  style: const TextStyle(color: Color(0xFF059669), fontSize: 9.5),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Put Volume
                        Expanded(
                          flex: 2,
                          child: Text(
                            s.putVolume,
                            textAlign: TextAlign.right,
                            style: TextStyle(color: textSub, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Bottom Shortcuts Bar: Orders, Positions, Charts (Image 4)
        Container(
          color: cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderCol)),
          ),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: widget.onNavigateToOrders,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderCol),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('Orders', style: TextStyle(color: textMain, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: widget.onNavigateToPositions,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderCol),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('Positions', style: TextStyle(color: textMain, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: widget.onNavigateToCharts,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderCol),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('Charts', style: TextStyle(color: textMain, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  _showStockDetailsBottomSheet(context, _selectedStock, isDark);
                },
                icon: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
                label: const Text('Trade Stock', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterTab(String label, int mode) {
    final isSelected = _optionChainFilter == mode;
    return InkWell(
      onTap: () => setState(() => _optionChainFilter = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Generates strike data around stock price (matching Image 4 for IOC)
  List<StockOptionStrike> _generateStrikesForStock(StockWatchItem stock) {
    if (stock.symbol == 'IOC') {
      // Exact values matching Image 4
      return const [
        StockOptionStrike(
          strike: 142.0,
          callLtp: 3.21,
          callChangePercent: -36.56,
          callVolume: '6.53L',
          callOi: 14.2,
          callIv: 24.5,
          putLtp: 1.67,
          putChangePercent: 36.89,
          putVolume: '11.21L',
          putOi: 8.4,
          putIv: 26.1,
        ),
        StockOptionStrike(
          strike: 143.0,
          callLtp: 2.62,
          callChangePercent: -56.11,
          callVolume: '5.17L',
          callOi: 11.8,
          callIv: 23.8,
          putLtp: 2.11,
          putChangePercent: 40.67,
          putVolume: '12.19L',
          putOi: 9.8,
          putIv: 25.4,
        ),
        StockOptionStrike(
          strike: 144.0,
          isAtm: true, // ATM strike from Image 4
          callLtp: 2.15,
          callChangePercent: -41.26,
          callVolume: '21.01L',
          callOi: 32.5,
          callIv: 22.9,
          putLtp: 2.61,
          putChangePercent: 38.83,
          putVolume: '14.53L',
          putOi: 18.2,
          putIv: 24.8,
        ),
        StockOptionStrike(
          strike: 145.0,
          callLtp: 1.73,
          callChangePercent: -43.83,
          callVolume: '65.67L',
          callOi: 84.1,
          callIv: 22.1,
          putLtp: 3.23,
          putChangePercent: 40.43,
          putVolume: '25.98L',
          putOi: 12.6,
          putIv: 24.1,
        ),
        StockOptionStrike(
          strike: 146.0,
          callLtp: 1.41,
          callChangePercent: -45.14,
          callVolume: '16.04L',
          callOi: 28.4,
          callIv: 21.6,
          putLtp: 3.91,
          putChangePercent: 39.64,
          putVolume: '6.14L',
          putOi: 7.2,
          putIv: 23.5,
        ),
        StockOptionStrike(
          strike: 147.0,
          callLtp: 1.13,
          callChangePercent: -47.69,
          callVolume: '24.42L',
          callOi: 35.6,
          callIv: 21.0,
          putLtp: 4.64,
          putChangePercent: 38.92,
          putVolume: '6.24L',
          putOi: 5.9,
          putIv: 23.0,
        ),
        StockOptionStrike(
          strike: 148.0,
          callLtp: 0.92,
          callChangePercent: -48.02,
          callVolume: '29.54L',
          callOi: 42.1,
          callIv: 20.5,
          putLtp: 5.31,
          putChangePercent: 33.75,
          putVolume: '1.17L',
          putOi: 4.8,
          putIv: 22.4,
        ),
        StockOptionStrike(
          strike: 149.0,
          callLtp: 0.74,
          callChangePercent: -49.66,
          callVolume: '18.62L',
          callOi: 22.8,
          callIv: 19.8,
          putLtp: 6.08,
          putChangePercent: 31.60,
          putVolume: '19.50K',
          putOi: 3.4,
          putIv: 21.9,
        ),
        StockOptionStrike(
          strike: 150.0,
          callLtp: 0.63,
          callChangePercent: -48.36,
          callVolume: '92.43L',
          callOi: 110.5,
          callIv: 19.2,
          putLtp: 7.22,
          putChangePercent: 35.21,
          putVolume: '24.18L',
          putOi: 2.1,
          putIv: 21.2,
        ),
      ];
    }

    // Dynamic generation for any other stock
    final double spot = stock.ltp;
    final double step = spot > 10000 ? 500 : (spot > 3000 ? 50 : (spot > 500 ? 20 : (spot > 200 ? 5 : 1)));
    final int atm = (spot / step).round();

    final List<StockOptionStrike> list = [];
    for (int i = -4; i <= 4; i++) {
      final double strike = (atm + i) * step;
      final bool isAtm = i == 0;
      final double dist = (spot - strike);

      final double callPremium = (spot * 0.015 + (dist > 0 ? dist : 0) - (dist < 0 ? -dist * 0.4 : 0)).clamp(0.5, spot * 0.15);
      final double putPremium = (spot * 0.015 + (dist < 0 ? -dist : 0) - (dist > 0 ? dist * 0.4 : 0)).clamp(0.5, spot * 0.15);

      list.add(StockOptionStrike(
        strike: strike,
        isAtm: isAtm,
        callLtp: callPremium,
        callChangePercent: -15.0 - (i * 4.5),
        callVolume: '${(10 + math.Random().nextInt(50))}L',
        callOi: 20.0 + (i.abs() * 5),
        callIv: 22.0 + (i.abs() * 0.5),
        putLtp: putPremium,
        putChangePercent: 12.0 + (i * 4.0),
        putVolume: '${(8 + math.Random().nextInt(40))}L',
        putOi: 18.0 + (i.abs() * 4),
        putIv: 23.0 + (i.abs() * 0.5),
      ));
    }
    return list;
  }
}
