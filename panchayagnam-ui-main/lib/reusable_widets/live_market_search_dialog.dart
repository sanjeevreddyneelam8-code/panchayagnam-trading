import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service/theme_mode_service.dart';
import '../service/copy_trading_engine.dart';
import 'order_placement_ticket_dialog.dart';

/// LiveMarketSearchDialog
/// Unified Angel One + Tradetron + Zerodha Kite inspired Universal Search Terminal.
/// Features real-time 1-second streaming quotes, flash indicators, Bid/Ask spread,
/// OI/Volume stats, segment tabs (NSE, NFO F&O, Tradetron Algos, Indices, MCX),
/// and 1-click Buy/Sell/Chart/Option-Chain/Deploy execution.
class LiveMarketSearchDialog extends StatefulWidget {
  final double niftyPrice;
  final double bankNiftyPrice;
  final double reliancePrice;
  final double hdfcPrice;
  final double infyPrice;
  final VoidCallback onOpenCharts;
  final VoidCallback onOpenOptionChain;
  final VoidCallback onOpenAutoTrading;
  final VoidCallback onOpenTradeMarket;

  const LiveMarketSearchDialog({
    super.key,
    required this.niftyPrice,
    required this.bankNiftyPrice,
    required this.reliancePrice,
    required this.hdfcPrice,
    required this.infyPrice,
    required this.onOpenCharts,
    required this.onOpenOptionChain,
    required this.onOpenAutoTrading,
    required this.onOpenTradeMarket,
  });

  static void show(
    BuildContext context, {
    required double niftyPrice,
    required double bankNiftyPrice,
    required double reliancePrice,
    required double hdfcPrice,
    required double infyPrice,
    required VoidCallback onOpenCharts,
    required VoidCallback onOpenOptionChain,
    required VoidCallback onOpenAutoTrading,
    required VoidCallback onOpenTradeMarket,
  }) {
    showDialog(
      context: context,
      builder: (_) => LiveMarketSearchDialog(
        niftyPrice: niftyPrice,
        bankNiftyPrice: bankNiftyPrice,
        reliancePrice: reliancePrice,
        hdfcPrice: hdfcPrice,
        infyPrice: infyPrice,
        onOpenCharts: onOpenCharts,
        onOpenOptionChain: onOpenOptionChain,
        onOpenAutoTrading: onOpenAutoTrading,
        onOpenTradeMarket: onOpenTradeMarket,
      ),
    );
  }

  @override
  State<LiveMarketSearchDialog> createState() => _LiveMarketSearchDialogState();
}

class _LiveMarketSearchDialogState extends State<LiveMarketSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final math.Random _rand = math.Random();
  Timer? _liveTimer;

  String _query = '';
  int _activeTab = 0; // 0: All, 1: F&O, 2: Equities, 3: Tradetron Algos, 4: Indices, 5: MCX, 6: Star Traders
  DateTime _now = DateTime.now();

  late List<Map<String, dynamic>> _universe;

  @override
  void initState() {
    super.initState();
    _initUniverse();
    _startLiveStreamingTicks();
  }

  void _initUniverse() {
    _universe = [
      // ── 1. F&O Contracts & Option Strikes (Angel One Quick Strikes) ────────
      {
        'symbol': 'NIFTY 24200 CE',
        'exchange': 'NFO',
        'type': 'Weekly Opt · Exp Thu',
        'price': 218.40,
        'prevClose': 184.20,
        'oi': '54.2L (+12%)',
        'vol': '18.4M',
        'category': 1,
        'lot': 25,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'NIFTY 24200 PE',
        'exchange': 'NFO',
        'type': 'Weekly Opt · Exp Thu',
        'price': 176.85,
        'prevClose': 192.10,
        'oi': '48.9L (+6%)',
        'vol': '15.2M',
        'category': 1,
        'lot': 25,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'NIFTY 24300 CE',
        'exchange': 'NFO',
        'type': 'OTM Call · Delta 0.38',
        'price': 142.10,
        'prevClose': 118.50,
        'oi': '72.1L (+19%)',
        'vol': '22.8M',
        'category': 1,
        'lot': 25,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'NIFTY 24100 PE',
        'exchange': 'NFO',
        'type': 'OTM Put · Strong Support',
        'price': 121.30,
        'prevClose': 145.00,
        'oi': '81.4L (+24%)',
        'vol': '19.1M',
        'category': 1,
        'lot': 25,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'NIFTY NOV FUT',
        'exchange': 'NFO',
        'type': 'Index Future · Basis +64',
        'price': widget.niftyPrice + 64.0,
        'prevClose': 24205.00,
        'oi': '1.42 Cr',
        'vol': '9.4M',
        'category': 1,
        'lot': 25,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'BANKNIFTY 51800 CE',
        'exchange': 'NFO',
        'type': 'Monthly Opt · Delta 0.52',
        'price': 418.75,
        'prevClose': 382.00,
        'oi': '28.4L (+9%)',
        'vol': '11.2M',
        'category': 1,
        'lot': 15,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'BANKNIFTY 51800 PE',
        'exchange': 'NFO',
        'type': 'Monthly Opt · Delta -0.48',
        'price': 368.40,
        'prevClose': 395.20,
        'oi': '31.2L (+4%)',
        'vol': '10.6M',
        'category': 1,
        'lot': 15,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'BANKNIFTY 52000 CE',
        'exchange': 'NFO',
        'type': 'Major Resistance Strike',
        'price': 285.90,
        'prevClose': 254.00,
        'oi': '44.8L (+15%)',
        'vol': '14.9M',
        'category': 1,
        'lot': 15,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'BANKNIFTY NOV FUT',
        'exchange': 'NFO',
        'type': 'Index Future · Basis +142',
        'price': widget.bankNiftyPrice + 142.0,
        'prevClose': 51640.00,
        'oi': '34.6L',
        'vol': '6.1M',
        'category': 1,
        'lot': 15,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'FINNIFTY 23400 CE',
        'exchange': 'NFO',
        'type': 'FinNifty Call · IV 13.8%',
        'price': 164.20,
        'prevClose': 149.80,
        'oi': '14.5L',
        'vol': '5.8M',
        'category': 1,
        'lot': 25,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'TATASTEEL 195 CE',
        'exchange': 'NFO',
        'type': 'Stock Call Option · Metal',
        'price': 6.45,
        'prevClose': 5.10,
        'oi': '92.4L (+31%)',
        'vol': '8.2M',
        'category': 1,
        'lot': 5500,
        'kind': 'instrument',
        'flash': 0,
      },

      // ── 2. NSE Equities (Cash Market) ─────────────────────────────────────
      {
        'symbol': 'RELIANCE',
        'exchange': 'NSE',
        'type': 'Reliance Industries Ltd',
        'price': widget.reliancePrice,
        'prevClose': 2915.70,
        'oi': 'Del: 68.5%',
        'vol': '6.8M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'HDFCBANK',
        'exchange': 'NSE',
        'type': 'HDFC Bank Ltd',
        'price': widget.hdfcPrice,
        'prevClose': 1653.30,
        'oi': 'Del: 61.2%',
        'vol': '12.4M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'TATASTEEL',
        'exchange': 'NSE',
        'type': 'Tata Steel Ltd · Breakout',
        'price': 194.50,
        'prevClose': 186.30,
        'oi': 'Vol 3.8x',
        'vol': '48.2M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'INFY',
        'exchange': 'NSE',
        'type': 'Infosys Ltd · IT Sector',
        'price': widget.infyPrice,
        'prevClose': 1766.00,
        'oi': 'Del: 59.4%',
        'vol': '5.9M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'TCS',
        'exchange': 'NSE',
        'type': 'Tata Consultancy Services',
        'price': 4180.25,
        'prevClose': 4152.00,
        'oi': 'Del: 64.1%',
        'vol': '2.1M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'ZOMATO',
        'exchange': 'NSE',
        'type': 'Zomato Ltd · Momentum',
        'price': 268.20,
        'prevClose': 255.80,
        'oi': 'Vol 4.5x',
        'vol': '62.5M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'ICICIBANK',
        'exchange': 'NSE',
        'type': 'ICICI Bank Ltd',
        'price': 1264.80,
        'prevClose': 1253.70,
        'oi': 'Del: 66.0%',
        'vol': '8.7M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'SBIN',
        'exchange': 'NSE',
        'type': 'State Bank of India',
        'price': 824.40,
        'prevClose': 814.10,
        'oi': 'PSU Bank',
        'vol': '14.3M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'TATAMOTORS',
        'exchange': 'NSE',
        'type': 'Tata Motors Ltd · Auto',
        'price': 912.60,
        'prevClose': 898.40,
        'oi': 'Auto Pick',
        'vol': '11.2M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'PERSISTENT',
        'exchange': 'NSE',
        'type': 'Persistent Systems · ATH',
        'price': 5490.00,
        'prevClose': 5324.00,
        'oi': 'Del: 71.4%',
        'vol': '1.8M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'DIXON',
        'exchange': 'NSE',
        'type': 'Dixon Technologies · EMS',
        'price': 15120.00,
        'prevClose': 14765.00,
        'oi': 'Breakout',
        'vol': '940K',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'BHARTIARTL',
        'exchange': 'NSE',
        'type': 'Bharti Airtel Ltd',
        'price': 1584.25,
        'prevClose': 1561.60,
        'oi': 'Telecom',
        'vol': '4.6M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'TRENT',
        'exchange': 'NSE',
        'type': 'Trent Ltd · Retail Leader',
        'price': 7120.50,
        'prevClose': 6860.00,
        'oi': 'Vol 3.4x',
        'vol': '2.4M',
        'category': 2,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },

      // ── 3. Tradetron-Style Automated Algo Strategies ───────────────────────
      {
        'symbol': '9:20 AM Short Straddle Pro',
        'exchange': 'ALGO',
        'type': 'Tradetron Template · Intraday Non-Directional · Margin ₹1.5L',
        'roi': 44.2,
        'liveMtm': 4120.0,
        'subscribers': '2,840 Live',
        'winRate': '78.4%',
        'category': 3,
        'kind': 'algo',
        'flash': 0,
      },
      {
        'symbol': 'Weekly Iron Condor Delta Hedged',
        'exchange': 'ALGO',
        'type': 'Tradetron Template · Expiry Theta Decay · Margin ₹1.2L',
        'roi': 31.8,
        'liveMtm': 2850.0,
        'subscribers': '1,920 Live',
        'winRate': '82.1%',
        'category': 3,
        'kind': 'algo',
        'flash': 0,
      },
      {
        'symbol': 'Supertrend 3x Momentum Engine',
        'exchange': 'ALGO',
        'type': 'Multi-Demat Trend Bot · NIFTY & BANKNIFTY · Margin ₹50k',
        'roi': 58.1,
        'liveMtm': 6490.0,
        'subscribers': '3,150 Live',
        'winRate': '66.5%',
        'category': 3,
        'kind': 'algo',
        'flash': 0,
      },
      {
        'symbol': 'VWAP + OI Breakout Option Buyer',
        'exchange': 'ALGO',
        'type': 'High Gamma Scalp · Low Capital ₹25k · Auto Trailing SL',
        'roi': 72.4,
        'liveMtm': 8320.0,
        'subscribers': '4,210 Live',
        'winRate': '61.2%',
        'category': 3,
        'kind': 'algo',
        'flash': 0,
      },
      {
        'symbol': 'Gamma Blast Expiry Sniper',
        'exchange': 'ALGO',
        'type': 'Zero-Hero Managed Hedged Bot · Margin ₹30k · AI Signal',
        'roi': 91.5,
        'liveMtm': 5780.0,
        'subscribers': '1,540 Live',
        'winRate': '54.8%',
        'category': 3,
        'kind': 'algo',
        'flash': 0,
      },

      // ── 4. Benchmark Indices ───────────────────────────────────────────────
      {
        'symbol': 'NIFTY 50',
        'exchange': 'INDEX',
        'type': 'NSE Benchmark Spot',
        'price': widget.niftyPrice,
        'prevClose': 24150.00,
        'oi': 'PCR 1.18',
        'vol': 'Adv 38/50',
        'category': 4,
        'lot': 25,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'BANK NIFTY',
        'exchange': 'INDEX',
        'type': 'NSE Banking Sector Spot',
        'price': widget.bankNiftyPrice,
        'prevClose': 51500.00,
        'oi': 'PCR 0.94',
        'vol': 'Adv 9/12',
        'category': 4,
        'lot': 15,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'SENSEX',
        'exchange': 'BSE',
        'type': 'BSE 30 Benchmark Spot',
        'price': 79402.20,
        'prevClose': 79060.10,
        'oi': 'MaxPain 79.3k',
        'vol': 'Adv 21/30',
        'category': 4,
        'lot': 10,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'FINNIFTY',
        'exchange': 'INDEX',
        'type': 'NSE Financial Services',
        'price': 23410.00,
        'prevClose': 23321.60,
        'oi': 'PCR 1.05',
        'vol': 'Adv 14/20',
        'category': 4,
        'lot': 25,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'MIDCPNIFTY',
        'exchange': 'INDEX',
        'type': 'NSE Midcap Select Index',
        'price': 13050.80,
        'prevClose': 12978.70,
        'oi': 'PCR 1.12',
        'vol': 'High Momentum',
        'category': 4,
        'lot': 50,
        'kind': 'instrument',
        'flash': 0,
      },

      // ── 5. MCX Commodities ─────────────────────────────────────────────────
      {
        'symbol': 'CRUDEOIL NOV FUT',
        'exchange': 'MCX',
        'type': 'Commodity Energy · Lot 100 bbl',
        'price': 5942.00,
        'prevClose': 5890.00,
        'oi': 'OI 14.2k',
        'vol': '42.1k',
        'category': 5,
        'lot': 100,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'GOLD DEC FUT',
        'exchange': 'MCX',
        'type': 'Bullion Safe Haven · 1 Kg',
        'price': 76450.00,
        'prevClose': 76120.00,
        'oi': 'OI 18.9k',
        'vol': '12.4k',
        'category': 5,
        'lot': 1,
        'kind': 'instrument',
        'flash': 0,
      },
      {
        'symbol': 'SILVER DEC FUT',
        'exchange': 'MCX',
        'type': 'Bullion Silver · 30 Kg',
        'price': 91240.00,
        'prevClose': 90480.00,
        'oi': 'OI 24.5k',
        'vol': '19.8k',
        'category': 5,
        'lot': 30,
        'kind': 'instrument',
        'flash': 0,
      },

      // ── 6. Verified Star Copy Traders ──────────────────────────────────────
      {
        'symbol': 'Rohan_AlphaQuant',
        'exchange': 'PRO',
        'type': 'SEBI Regd Quant Master · 1-Click Multi-Broker Auto Copy',
        'return': '+164.2%',
        'winRate': '81.4%',
        'copiers': '1,420 Demats',
        'category': 6,
        'kind': 'trader',
        'flash': 0,
      },
      {
        'symbol': 'Priya_OptionsQueen',
        'exchange': 'PRO',
        'type': 'Weekly F&O Expiry Specialist · Tight Risk Parity',
        'return': '+128.5%',
        'winRate': '76.8%',
        'copiers': '980 Demats',
        'category': 6,
        'kind': 'trader',
        'flash': 0,
      },
    ];
  }

  void _startLiveStreamingTicks() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        for (final item in _universe) {
          final kind = item['kind'] as String;
          if (kind == 'instrument') {
            final oldPrice = (item['price'] as num).toDouble();
            // Natural tick proportional to asset price
            final stepScale = math.max(0.05, oldPrice * 0.00055);
            final delta = (_rand.nextDouble() - 0.485) * stepScale * 2;
            final newPrice = double.parse(math.max(0.5, oldPrice + delta).toStringAsFixed(2));
            item['price'] = newPrice;
            item['flash'] = delta > 0.01 ? 1 : (delta < -0.01 ? -1 : 0);
          } else if (kind == 'algo') {
            final oldMtm = (item['liveMtm'] as num).toDouble();
            final delta = (_rand.nextDouble() - 0.42) * 140;
            item['liveMtm'] = double.parse((oldMtm + delta).toStringAsFixed(0));
            item['flash'] = delta > 0 ? 1 : -1;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase().trim();
    final filtered = _universe.where((item) {
      final cat = item['category'] as int;
      if (_activeTab != 0 && cat != _activeTab) return false;
      if (q.isEmpty) return true;
      final sym = (item['symbol'] as String).toLowerCase();
      final typ = (item['type'] as String).toLowerCase();
      final ex = (item['exchange'] as String).toLowerCase();
      return sym.contains(q) || typ.contains(q) || ex.contains(q);
    }).toList();

    final niftyItem = _universe.firstWhere((e) => e['symbol'] == 'NIFTY 50');
    final bankItem = _universe.firstWhere((e) => e['symbol'] == 'BANK NIFTY');
    final niftyP = (niftyItem['price'] as num).toDouble();
    final niftyBase = (niftyItem['prevClose'] as num).toDouble();
    final niftyChgPct = ((niftyP - niftyBase) / niftyBase) * 100;
    final bankP = (bankItem['price'] as num).toDouble();
    final bankBase = (bankItem['prevClose'] as num).toDouble();
    final bankChgPct = ((bankP - bankBase) / bankBase) * 100;

    final quickChips = [
      'NIFTY 24200',
      'BANKNIFTY',
      '9:20 Straddle',
      'TATASTEEL',
      'RELIANCE',
      'CRUDEOIL',
      'Iron Condor',
    ];

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeModeService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final headerBg = isDark ? const Color(0xFF141E33) : const Color(0xFFF8FAFC);

        return Dialog(
          backgroundColor: cardBg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderCol, width: 1.2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Live Ticking Market Telemetry Header ──────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF090E1A) : const Color(0xFFF1F5F9),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: borderCol)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE FEED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF10B981), letterSpacing: 0.4),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'NIFTY ${_formatIndianPrice(niftyP)} (${niftyChgPct >= 0 ? '+' : ''}${niftyChgPct.toStringAsFixed(2)}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: niftyChgPct >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'BANKNIFTY ${_formatIndianPrice(bankP)} (${bankChgPct >= 0 ? '+' : ''}${bankChgPct.toStringAsFixed(2)}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: bankChgPct >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('VIX 14.22 (-1.25%)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                        const SizedBox(width: 12),
                        Text(
                          'TICK ${DateFormat('HH:mm:ss').format(_now)} IST',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSub, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 2. Angel One + Tradetron Style Command Input ─────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.search_rounded, color: Color(0xFF38BDF8), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          style: TextStyle(color: textMain, fontSize: 14.5, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: 'Search Scrip, Strike (NIFTY 24200 CE), MCX (CRUDEOIL), or Tradetron Algo (9:20 Straddle)...',
                            hintStyle: TextStyle(color: textSub, fontSize: 12.5),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _query = val),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.cancel_rounded, color: textSub, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          splashRadius: 16,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textSub, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // ── 3. Quick Discovery Chips ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text('HOT SEARCH:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSub)),
                        const SizedBox(width: 8),
                        ...quickChips.map((chip) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () {
                                _searchCtrl.text = chip;
                                setState(() => _query = chip);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderCol),
                                ),
                                child: Text(chip, style: TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // ── 4. Segment Filter Tabs ───────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  color: headerBg,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSegmentTab('All Live (${_universe.length})', 0, isDark),
                        const SizedBox(width: 6),
                        _buildSegmentTab('⚡ F&O / Strikes', 1, isDark),
                        const SizedBox(width: 6),
                        _buildSegmentTab('📊 NSE Equities', 2, isDark),
                        const SizedBox(width: 6),
                        _buildSegmentTab('🤖 Tradetron Algos', 3, isDark),
                        const SizedBox(width: 6),
                        _buildSegmentTab('📈 Indices', 4, isDark),
                        const SizedBox(width: 6),
                        _buildSegmentTab('🛢️ MCX', 5, isDark),
                        const SizedBox(width: 6),
                        _buildSegmentTab('🌟 Star Traders', 6, isDark),
                      ],
                    ),
                  ),
                ),

                // ── 5. Live Results Feed ─────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 46, color: textSub.withOpacity(0.5)),
                              const SizedBox(height: 10),
                              Text('No matching live scrips or strategies for "$_query"', style: TextStyle(color: textSub, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text('Try "NIFTY", "BANKNIFTY", "TATASTEEL", "CRUDEOIL" or "Straddle"', style: TextStyle(color: textSub, fontSize: 11)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => Divider(color: borderCol, height: 1),
                          itemBuilder: (_, idx) {
                            final item = filtered[idx];
                            final kind = item['kind'] as String;

                            if (kind == 'algo') {
                              return _buildTradetronAlgoRow(item, isDark, textMain, textSub);
                            }
                            if (kind == 'trader') {
                              return _buildStarTraderRow(item, isDark, textMain, textSub);
                            }
                            return _buildAngelOneInstrumentRow(item, isDark, textMain, textSub);
                          },
                        ),
                ),

                // ── 6. Bottom Footer Action Strip ────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF090E1A) : const Color(0xFFF1F5F9),
                    border: Border(top: BorderSide(color: borderCol)),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 5),
                          Text(
                            'Live quotes streaming · Click [B] / [S] for Direct Order Ticket or Deploy Algos across ${CopyTradingEngine().totalAccountsCount} Brokers',
                            style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onOpenOptionChain();
                            },
                            child: const Text('Option Chain →', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 14),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onOpenTradeMarket();
                            },
                            child: const Text('Trade Market →', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
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

  Widget _buildSegmentTab(String label, int tabIdx, bool isDark) {
    final active = _activeTab == tabIdx;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabIdx),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF059669) : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildAngelOneInstrumentRow(Map<String, dynamic> item, bool isDark, Color textMain, Color textSub) {
    final sym = item['symbol'] as String;
    final ex = item['exchange'] as String;
    final typ = item['type'] as String;
    final price = (item['price'] as num).toDouble();
    final prevClose = (item['prevClose'] as num).toDouble();
    final diff = price - prevClose;
    final chgPct = (diff / prevClose) * 100;
    final isUp = diff >= 0;
    final flash = item['flash'] as int;
    final oi = item['oi'] as String? ?? '';
    final vol = item['vol'] as String? ?? '';
    final lot = (item['lot'] as num?)?.toInt() ?? 1;

    // Bid / Ask spread
    final spread = math.max(0.05, price * 0.0003);
    final bid = (price - spread).toStringAsFixed(2);
    final ask = (price + spread).toStringAsFixed(2);

    Color exCol = const Color(0xFF3B82F6);
    if (ex == 'NFO') exCol = const Color(0xFFEA580C);
    if (ex == 'INDEX') exCol = const Color(0xFF10B981);
    if (ex == 'MCX') exCol = const Color(0xFFF59E0B);

    final isOptOrIdx = ex == 'NFO' || ex == 'INDEX' || ex == 'BSE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          // Exchange Badge
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 3.5),
            decoration: BoxDecoration(
              color: exCol.withOpacity(0.16),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: exCol.withOpacity(0.5), width: 0.8),
            ),
            alignment: Alignment.center,
            child: Text(
              ex,
              style: TextStyle(color: exCol, fontSize: 9.5, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),

          // Scrip Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(sym, style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    if (oi.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(oi, style: TextStyle(color: textSub, fontSize: 9.5, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$typ · Vol: $vol · Bid ₹$bid / Ask ₹$ask',
                  style: TextStyle(color: textSub, fontSize: 10.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Live Flashing Price & % Change
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: flash == 1
                  ? const Color(0xFF10B981).withOpacity(0.16)
                  : (flash == -1 ? const Color(0xFFEF4444).withOpacity(0.16) : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${_formatIndianPrice(price)}',
                      style: TextStyle(
                        color: flash == 1
                            ? const Color(0xFF10B981)
                            : (flash == -1 ? const Color(0xFFEF4444) : textMain),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${isUp ? '+' : ''}${diff.toStringAsFixed(2)} (${isUp ? '+' : ''}${chgPct.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Quick Chart Button
          IconButton(
            icon: const Icon(Icons.candlestick_chart_rounded, size: 17),
            color: const Color(0xFF38BDF8),
            tooltip: 'Open Live Chart',
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpenCharts();
            },
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),

          if (isOptOrIdx) ...[
            IconButton(
              icon: const Icon(Icons.table_chart_rounded, size: 17),
              color: const Color(0xFF10B981),
              tooltip: 'Open Option Chain',
              onPressed: () {
                Navigator.of(context).pop();
                widget.onOpenOptionChain();
              },
              splashRadius: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],

          // Direct [B] Angel One Buy Ticket
          InkWell(
            onTap: () {
              Navigator.of(context).pop();
              OrderPlacementTicketDialog.show(
                context,
                symbol: sym,
                side: 'BUY',
                ltp: price,
                lotSize: lot,
                category: ex == 'NFO' ? 'OPTIONS' : (ex == 'INDEX' || ex == 'BSE' ? 'INDEX' : 'EQUITY'),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(4)),
              alignment: Alignment.center,
              child: const Text('B', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 6),

          // Direct [S] Angel One Sell Ticket
          InkWell(
            onTap: () {
              Navigator.of(context).pop();
              OrderPlacementTicketDialog.show(
                context,
                symbol: sym,
                side: 'SELL',
                ltp: price,
                lotSize: lot,
                category: ex == 'NFO' ? 'OPTIONS' : (ex == 'INDEX' || ex == 'BSE' ? 'INDEX' : 'EQUITY'),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
              alignment: Alignment.center,
              child: const Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradetronAlgoRow(Map<String, dynamic> item, bool isDark, Color textMain, Color textSub) {
    final sym = item['symbol'] as String;
    final typ = item['type'] as String;
    final roi = (item['roi'] as num).toDouble();
    final mtm = (item['liveMtm'] as num).toDouble();
    final subs = item['subscribers'] as String;
    final win = item['winRate'] as String;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.16),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5), width: 0.8),
            ),
            alignment: Alignment.center,
            child: const Text('ALGO', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 9.5, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(sym, style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(subs, style: const TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('$typ · Win Rate: $win', style: TextStyle(color: textSub, fontSize: 10.5), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${roi.toStringAsFixed(1)}% ROI', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12.5, fontWeight: FontWeight.w900)),
              Text(
                'Live MTM: ${mtm >= 0 ? '+' : ''}₹${mtm.toStringAsFixed(0)}',
                style: TextStyle(color: mtm >= 0 ? const Color(0xFF34D399) : const Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              final count = CopyTradingEngine().totalAccountsCount;
              Navigator.of(context).pop();
              widget.onOpenAutoTrading();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚡ Deploying Tradetron Strategy "$sym" across connected $count-Broker Engine!'),
                  backgroundColor: const Color(0xFF059669),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
            label: const Text('Deploy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarTraderRow(Map<String, dynamic> item, bool isDark, Color textMain, Color textSub) {
    final sym = item['symbol'] as String;
    final typ = item['type'] as String;
    final ret = item['return'] as String;
    final copiers = item['copiers'] as String;
    final win = item['winRate'] as String;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.16),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5), width: 0.8),
            ),
            alignment: Alignment.center,
            child: const Text('PRO', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sym, style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(typ, style: TextStyle(color: textSub, fontSize: 10.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ret, style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w900)),
              Text('$copiers · $win Win', style: TextStyle(color: textSub, fontSize: 10.5)),
            ],
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              final count = CopyTradingEngine().totalAccountsCount;
              Navigator.of(context).pop();
              CopyTradingEngine().replicateTrade(symbol: 'NIFTY 24200 CE', side: 'BUY', baseQty: 25, price: 218.40);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('⚡ 1-Click Auto Copy Active for $sym across $count Brokers!'), backgroundColor: const Color(0xFF059669)),
              );
            },
            icon: const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
            label: const Text('Copy All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
