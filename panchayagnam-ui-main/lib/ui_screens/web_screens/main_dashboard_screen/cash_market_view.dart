import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../reusable_widets/order_placement_ticket_dialog.dart';
import '../../../service/copy_trading_engine.dart';
import '../../../service/live_market_data_service.dart';
import '../../../service/theme_mode_service.dart';

/// Stock Item for Cash / Equity Market
class CashStockItem {
  final String symbol;
  final String companyName;
  final String exchange;
  final String sector;
  final double baseLtp;
  final double dayHigh;
  final double dayLow;
  final double open;
  final double prevClose;
  final int volume;
  final double high52w;
  final double low52w;

  const CashStockItem({
    required this.symbol,
    required this.companyName,
    this.exchange = 'NSE',
    required this.sector,
    required this.baseLtp,
    required this.dayHigh,
    required this.dayLow,
    required this.open,
    required this.prevClose,
    required this.volume,
    required this.high52w,
    required this.low52w,
  });
}

/// Dedicated Screen for CASH MARKET (Equity / Stocks)
/// Allows trading 1 share or any quantity with Delivery (CNC) or Intraday (MIS) on NSE
class CashMarketView extends StatefulWidget {
  final VoidCallback? onNavigateToFutures;
  final VoidCallback? onNavigateToOptions;
  final VoidCallback? onNavigateToOrders;
  final VoidCallback? onNavigateToPositions;

  const CashMarketView({
    super.key,
    this.onNavigateToFutures,
    this.onNavigateToOptions,
    this.onNavigateToOrders,
    this.onNavigateToPositions,
  });

  @override
  State<CashMarketView> createState() => _CashMarketViewState();
}

class _CashMarketViewState extends State<CashMarketView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _activeSectorIndex = 0;
  final NumberFormat _currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final NumberFormat _numFmt = NumberFormat('#,##,###');

  Timer? _tickTimer;
  final math.Random _random = math.Random();
  final Map<String, double> _liveLtpOverrides = {};
  final Map<String, bool> _tickFlashGreen = {};
  final Map<String, bool> _tickFlashRed = {};

  final List<String> _sectors = [
    'All Bluechips',
    'Nifty 50 Cash',
    'Energy & PSU (IOC, ONGC)',
    'Banking & Finance',
    'IT & Tech',
    'Auto & Metals',
  ];

  late final List<CashStockItem> _allStocks;

  @override
  void initState() {
    super.initState();
    _initStockUniverse();
    _startLiveTickSimulation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _initStockUniverse() {
    _allStocks = const [
      // Energy & PSU Heavyweights (Featuring IOC as requested by user)
      CashStockItem(
        symbol: 'IOC',
        companyName: 'Indian Oil Corporation Ltd',
        sector: 'Energy & PSU (IOC, ONGC)',
        baseLtp: 145.95,
        dayHigh: 147.40,
        dayLow: 143.20,
        open: 144.10,
        prevClose: 143.82,
        volume: 34500000,
        high52w: 196.80,
        low52w: 85.50,
      ),
      CashStockItem(
        symbol: 'RELIANCE',
        companyName: 'Reliance Industries Ltd',
        sector: 'Energy & PSU (IOC, ONGC)',
        baseLtp: 1363.00,
        dayHigh: 1374.50,
        dayLow: 1358.00,
        open: 1360.00,
        prevClose: 1367.00,
        volume: 8200000,
        high52w: 1608.80,
        low52w: 1100.00,
      ),
      CashStockItem(
        symbol: 'ONGC',
        companyName: 'Oil & Natural Gas Corp Ltd',
        sector: 'Energy & PSU (IOC, ONGC)',
        baseLtp: 265.40,
        dayHigh: 268.80,
        dayLow: 263.10,
        open: 264.00,
        prevClose: 262.90,
        volume: 14200000,
        high52w: 344.00,
        low52w: 180.20,
      ),
      CashStockItem(
        symbol: 'NTPC',
        companyName: 'NTPC Ltd',
        sector: 'Energy & PSU (IOC, ONGC)',
        baseLtp: 374.80,
        dayHigh: 378.50,
        dayLow: 371.00,
        open: 372.50,
        prevClose: 370.20,
        volume: 11500000,
        high52w: 435.00,
        low52w: 232.00,
      ),
      CashStockItem(
        symbol: 'COALINDIA',
        companyName: 'Coal India Ltd',
        sector: 'Energy & PSU (IOC, ONGC)',
        baseLtp: 438.50,
        dayHigh: 442.90,
        dayLow: 434.00,
        open: 435.00,
        prevClose: 432.10,
        volume: 9800000,
        high52w: 527.40,
        low52w: 310.00,
      ),
      CashStockItem(
        symbol: 'BPCL',
        companyName: 'Bharat Petroleum Corp Ltd',
        sector: 'Energy & PSU (IOC, ONGC)',
        baseLtp: 308.25,
        dayHigh: 312.00,
        dayLow: 305.50,
        open: 307.00,
        prevClose: 305.80,
        volume: 12400000,
        high52w: 388.00,
        low52w: 195.00,
      ),

      // Banking & Financials
      CashStockItem(
        symbol: 'HDFCBANK',
        companyName: 'HDFC Bank Ltd',
        sector: 'Banking & Finance',
        baseLtp: 1745.20,
        dayHigh: 1756.00,
        dayLow: 1738.00,
        open: 1740.00,
        prevClose: 1735.60,
        volume: 16400000,
        high52w: 1794.00,
        low52w: 1363.00,
      ),
      CashStockItem(
        symbol: 'ICICIBANK',
        companyName: 'ICICI Bank Ltd',
        sector: 'Banking & Finance',
        baseLtp: 1262.50,
        dayHigh: 1271.00,
        dayLow: 1254.00,
        open: 1258.00,
        prevClose: 1255.00,
        volume: 13500000,
        high52w: 1302.00,
        low52w: 915.00,
      ),
      CashStockItem(
        symbol: 'SBIN',
        companyName: 'State Bank of India',
        sector: 'Banking & Finance',
        baseLtp: 814.90,
        dayHigh: 821.50,
        dayLow: 809.00,
        open: 810.00,
        prevClose: 808.40,
        volume: 18900000,
        high52w: 912.00,
        low52w: 555.00,
      ),
      CashStockItem(
        symbol: 'AXISBANK',
        companyName: 'Axis Bank Ltd',
        sector: 'Banking & Finance',
        baseLtp: 1184.00,
        dayHigh: 1195.00,
        dayLow: 1176.00,
        open: 1178.00,
        prevClose: 1175.50,
        volume: 8700000,
        high52w: 1339.00,
        low52w: 980.00,
      ),
      CashStockItem(
        symbol: 'KOTAKBANK',
        companyName: 'Kotak Mahindra Bank Ltd',
        sector: 'Banking & Finance',
        baseLtp: 1754.30,
        dayHigh: 1768.00,
        dayLow: 1744.00,
        open: 1748.00,
        prevClose: 1745.00,
        volume: 6200000,
        high52w: 1908.00,
        low52w: 1544.00,
      ),
      CashStockItem(
        symbol: 'BAJFINANCE',
        companyName: 'Bajaj Finance Ltd',
        sector: 'Banking & Finance',
        baseLtp: 6920.00,
        dayHigh: 6985.00,
        dayLow: 6860.00,
        open: 6880.00,
        prevClose: 6850.00,
        volume: 2100000,
        high52w: 7850.00,
        low52w: 6160.00,
      ),

      // IT & Tech
      CashStockItem(
        symbol: 'TCS',
        companyName: 'Tata Consultancy Services Ltd',
        sector: 'IT & Tech',
        baseLtp: 4124.00,
        dayHigh: 4160.00,
        dayLow: 4095.00,
        open: 4110.00,
        prevClose: 4098.50,
        volume: 3800000,
        high52w: 4585.00,
        low52w: 3313.00,
      ),
      CashStockItem(
        symbol: 'INFY',
        companyName: 'Infosys Ltd',
        sector: 'IT & Tech',
        baseLtp: 1886.50,
        dayHigh: 1904.00,
        dayLow: 1872.00,
        open: 1880.00,
        prevClose: 1870.20,
        volume: 7900000,
        high52w: 1991.00,
        low52w: 1358.00,
      ),
      CashStockItem(
        symbol: 'WIPRO',
        companyName: 'Wipro Ltd',
        sector: 'IT & Tech',
        baseLtp: 566.80,
        dayHigh: 572.50,
        dayLow: 561.00,
        open: 563.00,
        prevClose: 560.40,
        volume: 5400000,
        high52w: 598.00,
        low52w: 375.00,
      ),

      // Auto, Metals & Defence
      CashStockItem(
        symbol: 'TATASTEEL',
        companyName: 'Tata Steel Ltd',
        sector: 'Auto & Metals',
        baseLtp: 148.60,
        dayHigh: 151.20,
        dayLow: 147.10,
        open: 147.80,
        prevClose: 146.90,
        volume: 42000000,
        high52w: 184.60,
        low52w: 114.20,
      ),
      CashStockItem(
        symbol: 'TATAMOTORS',
        companyName: 'Tata Motors Ltd',
        sector: 'Auto & Metals',
        baseLtp: 821.40,
        dayHigh: 832.00,
        dayLow: 814.00,
        open: 818.00,
        prevClose: 815.00,
        volume: 14800000,
        high52w: 1179.00,
        low52w: 660.00,
      ),
      CashStockItem(
        symbol: 'MARUTI',
        companyName: 'Maruti Suzuki India Ltd',
        sector: 'Auto & Metals',
        baseLtp: 11420.00,
        dayHigh: 11540.00,
        dayLow: 11320.00,
        open: 11380.00,
        prevClose: 11350.00,
        volume: 850000,
        high52w: 13680.00,
        low52w: 9737.00,
      ),
      CashStockItem(
        symbol: 'BEL',
        companyName: 'Bharat Electronics Ltd',
        sector: 'Auto & Metals',
        baseLtp: 304.80,
        dayHigh: 309.40,
        dayLow: 301.20,
        open: 303.00,
        prevClose: 301.50,
        volume: 19500000,
        high52w: 340.50,
        low52w: 132.00,
      ),
      CashStockItem(
        symbol: 'HAL',
        companyName: 'Hindustan Aeronautics Ltd',
        sector: 'Auto & Metals',
        baseLtp: 4355.00,
        dayHigh: 4410.00,
        dayLow: 4310.00,
        open: 4330.00,
        prevClose: 4315.00,
        volume: 2400000,
        high52w: 5675.00,
        low52w: 1980.00,
      ),
      CashStockItem(
        symbol: 'ITC',
        companyName: 'ITC Ltd',
        sector: 'Nifty 50 Cash',
        baseLtp: 485.60,
        dayHigh: 490.00,
        dayLow: 482.00,
        open: 484.00,
        prevClose: 483.20,
        volume: 15400000,
        high52w: 528.00,
        low52w: 399.00,
      ),
      CashStockItem(
        symbol: 'BHARTIARTL',
        companyName: 'Bharti Airtel Ltd',
        sector: 'Nifty 50 Cash',
        baseLtp: 1582.00,
        dayHigh: 1598.00,
        dayLow: 1570.00,
        open: 1575.00,
        prevClose: 1569.00,
        volume: 7200000,
        high52w: 1779.00,
        low52w: 920.00,
      ),
      CashStockItem(
        symbol: 'LT',
        companyName: 'Larsen & Toubro Ltd',
        sector: 'Nifty 50 Cash',
        baseLtp: 3562.00,
        dayHigh: 3595.00,
        dayLow: 3530.00,
        open: 3545.00,
        prevClose: 3540.00,
        volume: 3100000,
        high52w: 3919.00,
        low52w: 2850.00,
      ),
    ];
  }

  void _startLiveTickSimulation() {
    _tickTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      final targetIdx = _random.nextInt(_allStocks.length);
      final item = _allStocks[targetIdx];
      final currentLtp = _getLiveLtp(item);
      final delta = (_random.nextDouble() - 0.48) * (currentLtp * 0.003);
      final newLtp = double.parse((currentLtp + delta).toStringAsFixed(2));

      setState(() {
        _liveLtpOverrides[item.symbol] = newLtp;
        if (delta >= 0) {
          _tickFlashGreen[item.symbol] = true;
          _tickFlashRed[item.symbol] = false;
        } else {
          _tickFlashRed[item.symbol] = true;
          _tickFlashGreen[item.symbol] = false;
        }
      });

      Timer(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _tickFlashGreen[item.symbol] = false;
            _tickFlashRed[item.symbol] = false;
          });
        }
      });
    });
  }

  double _getLiveLtp(CashStockItem stock) {
    if (_liveLtpOverrides.containsKey(stock.symbol)) {
      return _liveLtpOverrides[stock.symbol]!;
    }
    final quote = LiveMarketDataService().getQuote(stock.symbol);
    if (quote != null && quote.ltp > 0) {
      return quote.ltp;
    }
    return stock.baseLtp;
  }

  List<CashStockItem> get _filteredStocks {
    return _allStocks.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.symbol.toUpperCase().contains(_searchQuery.toUpperCase()) ||
          s.companyName.toUpperCase().contains(_searchQuery.toUpperCase());

      if (!matchesSearch) return false;

      if (_activeSectorIndex == 0) return true; // All Bluechips
      final sectorName = _sectors[_activeSectorIndex];
      if (sectorName == 'Nifty 50 Cash') return true;
      return s.sector == sectorName;
    }).toList();
  }

  void _openCashOrderTicket(CashStockItem stock, String side) {
    final ltp = _getLiveLtp(stock);
    OrderPlacementTicketDialog.show(
      context,
      symbol: stock.symbol,
      side: side,
      ltp: ltp,
      lotSize: 1, // Cash shares are 1 share lot!
      category: 'EQUITY', // Cash Equity segment
    );
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

        final filtered = _filteredStocks;

        return Scaffold(
          backgroundColor: bg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Market Segment Switcher Bar (Cash, Futures, Options)
                _buildSegmentSwitcherBar(isDark),
                const SizedBox(height: 16),

                // 2. Banner Header
                _buildCashHeader(isDark, cardBg, borderCol, textMain, textSub),
                const SizedBox(height: 16),

                // 3. Search & Filter Bar
                _buildSearchAndFilterBar(isDark, cardBg, borderCol, textMain, textSub),
                const SizedBox(height: 16),

                // 4. Live Cash Stocks Table
                _buildStocksTable(filtered, isDark, cardBg, borderCol, textMain, textSub),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegmentSwitcherBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          // Cash Market (Active)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    '🟢 CASH MARKET (EQUITY / STOCKS)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Futures Market
          Expanded(
            child: InkWell(
              onTap: widget.onNavigateToFutures,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.trending_up_rounded, color: Color(0xFF38BDF8), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '🔵 FUTURES MARKET (F&O)',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Options Market
          Expanded(
            child: InkWell(
              onTap: widget.onNavigateToOptions,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.table_chart_rounded, color: Color(0xFFA855F7), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '🟣 OPTIONS MARKET (CHAIN & GREEKS)',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashHeader(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Panchayagnam Cash Market (Stocks / Equity)',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textMain),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Text(
                            'NSE / BSE LIVE CASH • 1 SHARE TO ANY QTY',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buy and sell normal company shares (IOC, RELIANCE, TCS, INFY, etc.) with Delivery (CNC) or Intraday (MIS). Zero F&O lot restrictions • Trade 1 share or thousands.',
                      style: TextStyle(fontSize: 12.5, color: textSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withOpacity(0.25) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '💡 Why trade Cash here? If your broker app (Angel One) executes normal share purchases cleanly, use this Cash Market desk! Your orders route directly to NSE Cash with 1-share lot sizing, avoiding all Option Chain strike errors.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: textMain, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search any NSE Cash Stock (e.g., IOC, RELIANCE, TCS, INFY, HDFCBANK)...',
                    hintStyle: TextStyle(color: textSub, fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF10B981)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Sector Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_sectors.length, (idx) {
              final isSel = _activeSectorIndex == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_sectors[idx]),
                  selected: isSel,
                  onSelected: (_) => setState(() => _activeSectorIndex = idx),
                  selectedColor: const Color(0xFF059669),
                  backgroundColor: cardBg,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? Colors.white : textSub,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSel ? const Color(0xFF059669) : borderCol),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStocksTable(List<CashStockItem> stocks, bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    if (stocks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text('No cash stocks found matching "$_searchQuery"', style: TextStyle(fontWeight: FontWeight.bold, color: textMain)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: borderCol)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('STOCK / COMPANY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 1, child: Text('SEGMENT', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('LTP (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('CHANGE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('DAY HIGH / LOW', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 1, child: Text('LOT SIZE', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                const Expanded(flex: 3, child: Text('1-CLICK CASH TRADE', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF10B981)))),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stocks.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: borderCol),
            itemBuilder: (ctx, i) {
              final stock = stocks[i];
              final ltp = _getLiveLtp(stock);
              final change = ltp - stock.prevClose;
              final changePct = (change / stock.prevClose) * 100;
              final isPositive = change >= 0;
              final isFlashingGreen = _tickFlashGreen[stock.symbol] == true;
              final isFlashingRed = _tickFlashRed[stock.symbol] == true;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isFlashingGreen
                    ? const Color(0xFF10B981).withOpacity(0.12)
                    : (isFlashingRed ? const Color(0xFFEF4444).withOpacity(0.12) : Colors.transparent),
                child: Row(
                  children: [
                    // Stock & Company
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                stock.symbol,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textMain),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'EQ',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stock.companyName,
                            style: TextStyle(fontSize: 11, color: textSub),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Exchange
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            stock.exchange,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSub),
                          ),
                        ),
                      ),
                    ),

                    // LTP
                    Expanded(
                      flex: 2,
                      child: Text(
                        _currencyFmt.format(ltp),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                    ),

                    // Change
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                          Text(
                            '(${isPositive ? '+' : ''}${changePct.toStringAsFixed(2)}%)',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Day High / Low
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('H: ₹${stock.dayHigh.toStringAsFixed(1)}', style: TextStyle(fontSize: 10.5, color: textSub)),
                          Text('L: ₹${stock.dayLow.toStringAsFixed(1)}', style: TextStyle(fontSize: 10.5, color: textSub)),
                        ],
                      ),
                    ),

                    // Lot Size: 1 Share!
                    const Expanded(
                      flex: 1,
                      child: Center(
                        child: Text(
                          '1 Share',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                        ),
                      ),
                    ),

                    // Action Buttons [ BUY ] [ SELL ]
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                            label: const Text('BUY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _openCashOrderTicket(stock, 'BUY'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                            label: const Text('SELL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _openCashOrderTicket(stock, 'SELL'),
                          ),
                        ],
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
}
