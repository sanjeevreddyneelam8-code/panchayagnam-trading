import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../reusable_widets/order_placement_ticket_dialog.dart';
import '../../../service/copy_trading_engine.dart';
import '../../../service/live_market_data_service.dart';
import '../../../service/theme_mode_service.dart';

/// Futures Contract Representation
class FuturesContractItem {
  final String symbol; // e.g. "NIFTY FUT" or "IOC FUT"
  final String displayName; // e.g. "NIFTY 28-NOV-24 FUT"
  final String underlying;
  final String category; // "INDEX" or "STOCK"
  final String expiry;
  final String exchange;
  final double baseLtp;
  final double spotLtp;
  final double prevClose;
  final int lotSize;
  final int volume;
  final double oiLakh;

  const FuturesContractItem({
    required this.symbol,
    required this.displayName,
    required this.underlying,
    required this.category,
    required this.expiry,
    this.exchange = 'NFO',
    required this.baseLtp,
    required this.spotLtp,
    required this.prevClose,
    required this.lotSize,
    required this.volume,
    required this.oiLakh,
  });

  double get basis => baseLtp - spotLtp;
  bool get isPremium => basis >= 0;
}

/// Dedicated Screen for FUTURES MARKET (Index & Stock Futures)
/// Allows trading standard lot futures contracts across NSE NFO and BSE BFO
class FuturesMarketView extends StatefulWidget {
  final VoidCallback? onNavigateToCash;
  final VoidCallback? onNavigateToOptions;
  final VoidCallback? onNavigateToOrders;
  final VoidCallback? onNavigateToPositions;

  const FuturesMarketView({
    super.key,
    this.onNavigateToCash,
    this.onNavigateToOptions,
    this.onNavigateToOrders,
    this.onNavigateToPositions,
  });

  @override
  State<FuturesMarketView> createState() => _FuturesMarketViewState();
}

class _FuturesMarketViewState extends State<FuturesMarketView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _activeCategoryIndex = 0; // 0: All Futures, 1: Index Futures, 2: Stock Futures

  final NumberFormat _currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final NumberFormat _numFmt = NumberFormat('#,##,###');

  Timer? _tickTimer;
  final math.Random _random = math.Random();
  final Map<String, double> _liveLtpOverrides = {};
  final Map<String, bool> _tickFlashGreen = {};
  final Map<String, bool> _tickFlashRed = {};

  final List<String> _categories = [
    'All Futures Contracts',
    'Index Futures (NIFTY, BANKNIFTY)',
    'Stock Futures (IOC, RELIANCE, etc.)',
  ];

  late final List<FuturesContractItem> _allFutures;

  @override
  void initState() {
    super.initState();
    _initFuturesUniverse();
    LiveMarketDataService().addListener(_onLiveMarketUpdate);
    LiveMarketDataService().start();
    _startLiveTickSimulation();
  }

  void _onLiveMarketUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LiveMarketDataService().removeListener(_onLiveMarketUpdate);
    _searchCtrl.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _initFuturesUniverse() {
    _allFutures = const [
      // ── Index Futures ───────────────────────────────────────────────
      FuturesContractItem(
        symbol: 'NIFTY FUT',
        displayName: 'NIFTY Current Month FUT',
        underlying: 'NIFTY 50',
        category: 'INDEX',
        expiry: 'Current Month',
        baseLtp: 25285.00,
        spotLtp: 25227.95,
        prevClose: 25240.00,
        lotSize: 65,
        volume: 185000,
        oiLakh: 142.5,
      ),
      FuturesContractItem(
        symbol: 'BANKNIFTY FUT',
        displayName: 'BANKNIFTY Current Month FUT',
        underlying: 'NIFTY BANK',
        category: 'INDEX',
        expiry: 'Current Month',
        baseLtp: 62180.00,
        spotLtp: 62038.65,
        prevClose: 62050.00,
        lotSize: 30,
        volume: 98000,
        oiLakh: 48.2,
      ),
      FuturesContractItem(
        symbol: 'FINNIFTY FUT',
        displayName: 'FINNIFTY Current Month FUT',
        underlying: 'NIFTY FINANCIAL',
        category: 'INDEX',
        expiry: 'Current Month',
        baseLtp: 28065.00,
        spotLtp: 27992.25,
        prevClose: 28010.00,
        lotSize: 60,
        volume: 42000,
        oiLakh: 19.8,
      ),
      FuturesContractItem(
        symbol: 'MIDCPNIFTY FUT',
        displayName: 'MIDCPNIFTY Current Month FUT',
        underlying: 'NIFTY MIDCAP SELECT',
        category: 'INDEX',
        expiry: 'Current Month',
        baseLtp: 14120.00,
        spotLtp: 14083.35,
        prevClose: 14105.00,
        lotSize: 120,
        volume: 31000,
        oiLakh: 14.5,
      ),
      FuturesContractItem(
        symbol: 'SENSEX FUT',
        displayName: 'SENSEX Current Month FUT',
        underlying: 'BSE SENSEX',
        category: 'INDEX',
        expiry: 'Current Month',
        exchange: 'BFO',
        baseLtp: 82210.00,
        spotLtp: 82031.81,
        prevClose: 82100.00,
        lotSize: 20,
        volume: 28000,
        oiLakh: 22.4,
      ),

      // ── Stock Futures (Featuring IOC with lot 4,875) ────────────────
      FuturesContractItem(
        symbol: 'IOC FUT',
        displayName: 'IOC Current Month FUT',
        underlying: 'Indian Oil Corporation',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 146.40,
        spotLtp: 145.95,
        prevClose: 144.20,
        lotSize: 4875,
        volume: 12400,
        oiLakh: 285.0,
      ),
      FuturesContractItem(
        symbol: 'RELIANCE FUT',
        displayName: 'RELIANCE Current Month FUT',
        underlying: 'Reliance Industries',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1369.50,
        spotLtp: 1363.00,
        prevClose: 1373.00,
        lotSize: 250,
        volume: 45000,
        oiLakh: 182.0,
      ),
      FuturesContractItem(
        symbol: 'TCS FUT',
        displayName: 'TCS Current Month FUT',
        underlying: 'Tata Consultancy Services',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 4140.00,
        spotLtp: 4124.00,
        prevClose: 4115.00,
        lotSize: 175,
        volume: 24000,
        oiLakh: 76.4,
      ),
      FuturesContractItem(
        symbol: 'INFY FUT',
        displayName: 'INFY Current Month FUT',
        underlying: 'Infosys Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1894.00,
        spotLtp: 1886.50,
        prevClose: 1878.00,
        lotSize: 400,
        volume: 38000,
        oiLakh: 112.0,
      ),
      FuturesContractItem(
        symbol: 'HDFCBANK FUT',
        displayName: 'HDFCBANK Current Month FUT',
        underlying: 'HDFC Bank Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1752.00,
        spotLtp: 1745.20,
        prevClose: 1742.00,
        lotSize: 550,
        volume: 52000,
        oiLakh: 240.0,
      ),
      FuturesContractItem(
        symbol: 'ICICIBANK FUT',
        displayName: 'ICICIBANK Current Month FUT',
        underlying: 'ICICI Bank Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1268.00,
        spotLtp: 1262.50,
        prevClose: 1260.00,
        lotSize: 700,
        volume: 36000,
        oiLakh: 145.0,
      ),
      FuturesContractItem(
        symbol: 'SBIN FUT',
        displayName: 'SBIN Current Month FUT',
        underlying: 'State Bank of India',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 818.50,
        spotLtp: 814.90,
        prevClose: 812.00,
        lotSize: 750,
        volume: 64000,
        oiLakh: 198.0,
      ),
      FuturesContractItem(
        symbol: 'TATASTEEL FUT',
        displayName: 'TATASTEEL Current Month FUT',
        underlying: 'Tata Steel Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 149.20,
        spotLtp: 148.60,
        prevClose: 147.50,
        lotSize: 5500,
        volume: 72000,
        oiLakh: 420.0,
      ),
      FuturesContractItem(
        symbol: 'TATAMOTORS FUT',
        displayName: 'TATAMOTORS Current Month FUT',
        underlying: 'Tata Motors Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 825.00,
        spotLtp: 821.40,
        prevClose: 818.00,
        lotSize: 1425,
        volume: 48000,
        oiLakh: 165.0,
      ),
      FuturesContractItem(
        symbol: 'BEL FUT',
        displayName: 'BEL Current Month FUT',
        underlying: 'Bharat Electronics',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 306.40,
        spotLtp: 304.80,
        prevClose: 303.00,
        lotSize: 1425,
        volume: 58000,
        oiLakh: 210.0,
      ),
      FuturesContractItem(
        symbol: 'HAL FUT',
        displayName: 'HAL Current Month FUT',
        underlying: 'Hindustan Aeronautics',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 4375.00,
        spotLtp: 4355.00,
        prevClose: 4335.00,
        lotSize: 150,
        volume: 18000,
        oiLakh: 54.0,
      ),
      FuturesContractItem(
        symbol: 'MAZDOCK FUT',
        displayName: 'MAZDOCK Current Month FUT',
        underlying: 'Mazagon Dock Shipbuilders',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 4280.00,
        spotLtp: 4260.00,
        prevClose: 4220.00,
        lotSize: 125,
        volume: 24000,
        oiLakh: 42.0,
      ),
      FuturesContractItem(
        symbol: 'NTPC FUT',
        displayName: 'NTPC Current Month FUT',
        underlying: 'NTPC Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 376.50,
        spotLtp: 374.80,
        prevClose: 372.00,
        lotSize: 1500,
        volume: 72000,
        oiLakh: 310.0,
      ),
      FuturesContractItem(
        symbol: 'ONGC FUT',
        displayName: 'ONGC Current Month FUT',
        underlying: 'Oil & Natural Gas Corp',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 266.80,
        spotLtp: 265.40,
        prevClose: 264.00,
        lotSize: 3850,
        volume: 85000,
        oiLakh: 460.0,
      ),
      FuturesContractItem(
        symbol: 'POWERGRID FUT',
        displayName: 'POWERGRID Current Month FUT',
        underlying: 'Power Grid Corp',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 326.00,
        spotLtp: 324.50,
        prevClose: 322.00,
        lotSize: 1800,
        volume: 68000,
        oiLakh: 290.0,
      ),
      FuturesContractItem(
        symbol: 'ADANIENT FUT',
        displayName: 'ADANIENT Current Month FUT',
        underlying: 'Adani Enterprises Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 2495.00,
        spotLtp: 2480.00,
        prevClose: 2470.00,
        lotSize: 300,
        volume: 45000,
        oiLakh: 120.0,
      ),
      FuturesContractItem(
        symbol: 'ADANIPORTS FUT',
        displayName: 'ADANIPORTS Current Month FUT',
        underlying: 'Adani Ports & SEZ',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1292.00,
        spotLtp: 1285.00,
        prevClose: 1275.00,
        lotSize: 400,
        volume: 52000,
        oiLakh: 165.0,
      ),
      FuturesContractItem(
        symbol: 'TATAPOWER FUT',
        displayName: 'TATAPOWER Current Month FUT',
        underlying: 'Tata Power Co Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 420.50,
        spotLtp: 418.50,
        prevClose: 415.00,
        lotSize: 1350,
        volume: 92000,
        oiLakh: 380.0,
      ),
      FuturesContractItem(
        symbol: 'COALINDIA FUT',
        displayName: 'COALINDIA Current Month FUT',
        underlying: 'Coal India Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 444.80,
        spotLtp: 442.90,
        prevClose: 440.00,
        lotSize: 2100,
        volume: 62000,
        oiLakh: 240.0,
      ),
      FuturesContractItem(
        symbol: 'BPCL FUT',
        displayName: 'BPCL Current Month FUT',
        underlying: 'Bharat Petroleum Corp',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 309.80,
        spotLtp: 308.20,
        prevClose: 306.00,
        lotSize: 1800,
        volume: 48000,
        oiLakh: 195.0,
      ),
      FuturesContractItem(
        symbol: 'GAIL FUT',
        displayName: 'GAIL Current Month FUT',
        underlying: 'GAIL India Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 203.80,
        spotLtp: 202.40,
        prevClose: 200.50,
        lotSize: 2950,
        volume: 54000,
        oiLakh: 260.0,
      ),
      FuturesContractItem(
        symbol: 'PFC FUT',
        displayName: 'PFC Current Month FUT',
        underlying: 'Power Finance Corp',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 497.50,
        spotLtp: 495.00,
        prevClose: 490.00,
        lotSize: 1300,
        volume: 78000,
        oiLakh: 340.0,
      ),
      FuturesContractItem(
        symbol: 'REC FUT',
        displayName: 'REC Current Month FUT',
        underlying: 'REC Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 530.80,
        spotLtp: 528.00,
        prevClose: 522.00,
        lotSize: 1000,
        volume: 82000,
        oiLakh: 360.0,
      ),
      FuturesContractItem(
        symbol: 'BHEL FUT',
        displayName: 'BHEL Current Month FUT',
        underlying: 'Bharat Heavy Electricals',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 246.80,
        spotLtp: 245.00,
        prevClose: 242.00,
        lotSize: 2625,
        volume: 95000,
        oiLakh: 410.0,
      ),
      FuturesContractItem(
        symbol: 'BANKBARODA FUT',
        displayName: 'BANKBARODA Current Month FUT',
        underlying: 'Bank of Baroda',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 256.40,
        spotLtp: 255.00,
        prevClose: 252.50,
        lotSize: 2925,
        volume: 64000,
        oiLakh: 280.0,
      ),
      FuturesContractItem(
        symbol: 'CANBK FUT',
        displayName: 'CANBK Current Month FUT',
        underlying: 'Canara Bank',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 106.50,
        spotLtp: 105.80,
        prevClose: 104.80,
        lotSize: 6750,
        volume: 71000,
        oiLakh: 320.0,
      ),
      FuturesContractItem(
        symbol: 'IDFCFIRSTB FUT',
        displayName: 'IDFCFIRSTB Current Month FUT',
        underlying: 'IDFC First Bank',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 68.90,
        spotLtp: 68.40,
        prevClose: 69.20,
        lotSize: 7500,
        volume: 84000,
        oiLakh: 520.0,
      ),
      FuturesContractItem(
        symbol: 'BAJAJFINSV FUT',
        displayName: 'BAJAJFINSV Current Month FUT',
        underlying: 'Bajaj Finserv Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1638.00,
        spotLtp: 1630.00,
        prevClose: 1620.00,
        lotSize: 500,
        volume: 38000,
        oiLakh: 140.0,
      ),
      FuturesContractItem(
        symbol: 'SHRIRAMFIN FUT',
        displayName: 'SHRIRAMFIN Current Month FUT',
        underlying: 'Shriram Finance Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 3195.00,
        spotLtp: 3180.00,
        prevClose: 3150.00,
        lotSize: 150,
        volume: 29000,
        oiLakh: 88.0,
      ),
      FuturesContractItem(
        symbol: 'SBILIFE FUT',
        displayName: 'SBILIFE Current Month FUT',
        underlying: 'SBI Life Insurance Co',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1528.00,
        spotLtp: 1520.00,
        prevClose: 1510.00,
        lotSize: 375,
        volume: 24000,
        oiLakh: 72.0,
      ),
      FuturesContractItem(
        symbol: 'HDFCLIFE FUT',
        displayName: 'HDFCLIFE Current Month FUT',
        underlying: 'HDFC Life Insurance Co',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 688.50,
        spotLtp: 685.00,
        prevClose: 680.00,
        lotSize: 1100,
        volume: 35000,
        oiLakh: 115.0,
      ),
      FuturesContractItem(
        symbol: 'CHOLAFIN FUT',
        displayName: 'CHOLAFIN Current Month FUT',
        underlying: 'Cholamandalam Inv & Fin',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1368.00,
        spotLtp: 1360.00,
        prevClose: 1345.00,
        lotSize: 625,
        volume: 32000,
        oiLakh: 98.0,
      ),
      FuturesContractItem(
        symbol: 'TECHM FUT',
        displayName: 'TECHM Current Month FUT',
        underlying: 'Tech Mahindra Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1718.00,
        spotLtp: 1710.00,
        prevClose: 1698.00,
        lotSize: 600,
        volume: 42000,
        oiLakh: 130.0,
      ),
      FuturesContractItem(
        symbol: 'LTIM FUT',
        displayName: 'LTIM Current Month FUT',
        underlying: 'LTIMindtree Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 6080.00,
        spotLtp: 6050.00,
        prevClose: 6010.00,
        lotSize: 150,
        volume: 19000,
        oiLakh: 58.0,
      ),
      FuturesContractItem(
        symbol: 'M&M FUT',
        displayName: 'M&M Current Month FUT',
        underlying: 'Mahindra & Mahindra',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 2995.00,
        spotLtp: 2980.00,
        prevClose: 2955.00,
        lotSize: 200,
        volume: 46000,
        oiLakh: 150.0,
      ),
      FuturesContractItem(
        symbol: 'BAJAJ-AUTO FUT',
        displayName: 'BAJAJ-AUTO Current Month FUT',
        underlying: 'Bajaj Auto Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 9890.00,
        spotLtp: 9850.00,
        prevClose: 9780.00,
        lotSize: 75,
        volume: 16000,
        oiLakh: 44.0,
      ),
      FuturesContractItem(
        symbol: 'HEROMOTOCO FUT',
        displayName: 'HEROMOTOCO Current Month FUT',
        underlying: 'Hero MotoCorp Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 4875.00,
        spotLtp: 4850.00,
        prevClose: 4820.00,
        lotSize: 150,
        volume: 22000,
        oiLakh: 62.0,
      ),
      FuturesContractItem(
        symbol: 'TVSMOTOR FUT',
        displayName: 'TVSMOTOR Current Month FUT',
        underlying: 'TVS Motor Co Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 2492.00,
        spotLtp: 2480.00,
        prevClose: 2450.00,
        lotSize: 250,
        volume: 34000,
        oiLakh: 96.0,
      ),
      FuturesContractItem(
        symbol: 'JINDALSTEL FUT',
        displayName: 'JINDALSTEL Current Month FUT',
        underlying: 'Jindal Steel & Power',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 972.00,
        spotLtp: 965.00,
        prevClose: 955.00,
        lotSize: 625,
        volume: 48000,
        oiLakh: 160.0,
      ),
      FuturesContractItem(
        symbol: 'HINDALCO FUT',
        displayName: 'HINDALCO Current Month FUT',
        underlying: 'Hindalco Industries',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 659.00,
        spotLtp: 655.00,
        prevClose: 648.00,
        lotSize: 1400,
        volume: 58000,
        oiLakh: 215.0,
      ),
      FuturesContractItem(
        symbol: 'JSWSTEEL FUT',
        displayName: 'JSWSTEEL Current Month FUT',
        underlying: 'JSW Steel Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 985.00,
        spotLtp: 980.00,
        prevClose: 972.00,
        lotSize: 675,
        volume: 52000,
        oiLakh: 185.0,
      ),
      FuturesContractItem(
        symbol: 'VEDL FUT',
        displayName: 'VEDL Current Month FUT',
        underlying: 'Vedanta Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 471.50,
        spotLtp: 468.00,
        prevClose: 464.00,
        lotSize: 1550,
        volume: 76000,
        oiLakh: 310.0,
      ),
      FuturesContractItem(
        symbol: 'ULTRACEMCO FUT',
        displayName: 'ULTRACEMCO Current Month FUT',
        underlying: 'UltraTech Cement Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 11490.00,
        spotLtp: 11450.00,
        prevClose: 11380.00,
        lotSize: 100,
        volume: 15000,
        oiLakh: 42.0,
      ),
      FuturesContractItem(
        symbol: 'GRASIM FUT',
        displayName: 'GRASIM Current Month FUT',
        underlying: 'Grasim Industries Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 2692.00,
        spotLtp: 2680.00,
        prevClose: 2660.00,
        lotSize: 250,
        volume: 28000,
        oiLakh: 78.0,
      ),
      FuturesContractItem(
        symbol: 'CIPLA FUT',
        displayName: 'CIPLA Current Month FUT',
        underlying: 'Cipla Ltd',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1528.00,
        spotLtp: 1520.00,
        prevClose: 1512.00,
        lotSize: 650,
        volume: 31000,
        oiLakh: 86.0,
      ),
      FuturesContractItem(
        symbol: 'DRREDDY FUT',
        displayName: 'DRREDDY Current Month FUT',
        underlying: 'Dr Reddy\'s Laboratories',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 1245.00,
        spotLtp: 1240.00,
        prevClose: 1232.00,
        lotSize: 125,
        volume: 26000,
        oiLakh: 64.0,
      ),
      FuturesContractItem(
        symbol: 'MCX FUT',
        displayName: 'MCX Current Month FUT',
        underlying: 'Multi Commodity Exchange',
        category: 'STOCK',
        expiry: 'Current Month',
        baseLtp: 6385.00,
        spotLtp: 6350.00,
        prevClose: 6250.00,
        lotSize: 125,
        volume: 44000,
        oiLakh: 92.0,
      ),
    ];
  }

  void _startLiveTickSimulation() {
    _tickTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      LiveMarketDataService().fetchNow();
      setState(() {});
    });
  }

  double _getSpotLtp(FuturesContractItem contract) {
    final cleanSym = contract.symbol.replaceAll(' FUT', '').trim();
    final quote = LiveMarketDataService().getQuote(cleanSym);
    if (quote != null && quote.ltp > 0) {
      return quote.ltp;
    }
    return contract.spotLtp;
  }

  double _getLiveLtp(FuturesContractItem contract) {
    if (_liveLtpOverrides.containsKey(contract.symbol)) {
      return _liveLtpOverrides[contract.symbol]!;
    }
    final cleanSym = contract.symbol.replaceAll(' FUT', '').trim();
    final quote = LiveMarketDataService().getQuote(cleanSym);
    if (quote != null && quote.ltp > 0) {
      final premium = contract.baseLtp - contract.spotLtp;
      return double.parse((quote.ltp + premium).toStringAsFixed(2));
    }
    return contract.baseLtp;
  }

  List<FuturesContractItem> get _filteredFutures {
    return _allFutures.where((f) {
      final matchesSearch = _searchQuery.isEmpty ||
          f.symbol.toUpperCase().contains(_searchQuery.toUpperCase()) ||
          f.underlying.toUpperCase().contains(_searchQuery.toUpperCase()) ||
          f.displayName.toUpperCase().contains(_searchQuery.toUpperCase());

      if (!matchesSearch) return false;

      if (_activeCategoryIndex == 1) return f.category == 'INDEX';
      if (_activeCategoryIndex == 2) return f.category == 'STOCK';
      return true;
    }).toList();
  }

  void _openFuturesOrderTicket(FuturesContractItem contract, String side) {
    final ltp = _getLiveLtp(contract);
    OrderPlacementTicketDialog.show(
      context,
      symbol: contract.symbol,
      side: side,
      ltp: ltp,
      lotSize: contract.lotSize,
      category: 'F&O',
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

        final filtered = _filteredFutures;

        return Scaffold(
          backgroundColor: bg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Market Segment Switcher Bar
                _buildSegmentSwitcherBar(isDark),
                const SizedBox(height: 16),

                // 2. Banner Header
                _buildFuturesHeader(isDark, cardBg, borderCol, textMain, textSub),
                const SizedBox(height: 16),

                // 3. Search & Filter Bar
                _buildSearchAndFilterBar(isDark, cardBg, borderCol, textMain, textSub),
                const SizedBox(height: 16),

                // 4. Live Futures Contracts Table
                _buildFuturesTable(filtered, isDark, cardBg, borderCol, textMain, textSub),
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
          // Cash Market
          Expanded(
            child: InkWell(
              onTap: widget.onNavigateToCash,
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
                    const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '🟢 CASH MARKET (EQUITY / STOCKS)',
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

          // Futures Market (Active)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF38BDF8)]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0284C7).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    '🔵 FUTURES MARKET (INDEX & STOCK FUT)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.3),
                  ),
                ],
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

  Widget _buildFuturesHeader(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
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
                  color: const Color(0xFF0284C7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_up_rounded, color: Color(0xFF0284C7), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Panchayagnam Futures Market (Index & Stock Futures)',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textMain),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: const Text(
                            'NSE NFO • MONTHLY EXPIRIES • HIGH LEVERAGE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0369A1)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trade NIFTY, BANKNIFTY, IOC FUT, RELIANCE FUT and top stock futures. Enforces standard contract lot sizes and near/next month expiries with instant Angel One routing.',
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
              color: isDark ? const Color(0xFF0C4A6E).withOpacity(0.25) : const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚡ Futures vs Cash: Futures orders require trading in multiples of standard contract lots (e.g., 65 for Nifty, 30 for BankNifty, 4,875 for IOC). If you want to buy 1 share or custom quantities without lot minimums, use the 🟢 Cash Market tab above.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1)),
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
                    hintText: 'Search Futures Contracts (e.g., NIFTY, BANKNIFTY, IOC, RELIANCE, TCS)...',
                    hintStyle: TextStyle(color: textSub, fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF0284C7)),
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

        // Category Pills
        Row(
          children: List.generate(_categories.length, (idx) {
            final isSel = _activeCategoryIndex == idx;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_categories[idx]),
                selected: isSel,
                onSelected: (_) => setState(() => _activeCategoryIndex = idx),
                selectedColor: const Color(0xFF0284C7),
                backgroundColor: cardBg,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                  color: isSel ? Colors.white : textSub,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: isSel ? const Color(0xFF0284C7) : borderCol),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFuturesTable(List<FuturesContractItem> contracts, bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    if (contracts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text('No futures contracts found matching "$_searchQuery"', style: TextStyle(fontWeight: FontWeight.bold, color: textMain)),
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
                Expanded(flex: 3, child: Text('FUTURES CONTRACT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 1, child: Text('EXPIRY', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('FUTURES LTP (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('SPOT & BASIS', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('LOT SIZE', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                Expanded(flex: 2, child: Text('CONTRACT VALUE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textSub))),
                const Expanded(flex: 3, child: Text('1-CLICK FUTURES TRADE', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0284C7)))),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: contracts.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: borderCol),
            itemBuilder: (ctx, i) {
              final contract = contracts[i];
              final ltp = _getLiveLtp(contract);
              final spotLtp = _getSpotLtp(contract);
              final basis = ltp - spotLtp;
              final change = ltp - contract.prevClose;
              final changePct = (change / contract.prevClose) * 100;
              final isPositive = change >= 0;
              final contractVal = ltp * contract.lotSize;
              final isFlashingGreen = _tickFlashGreen[contract.symbol] == true;
              final isFlashingRed = _tickFlashRed[contract.symbol] == true;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isFlashingGreen
                    ? const Color(0xFF10B981).withOpacity(0.12)
                    : (isFlashingRed ? const Color(0xFFEF4444).withOpacity(0.12) : Colors.transparent),
                child: Row(
                  children: [
                    // Contract & Underlying
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                contract.symbol,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textMain),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  contract.exchange,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contract.underlying,
                            style: TextStyle(fontSize: 11, color: textSub),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Expiry
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
                            contract.expiry,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSub),
                          ),
                        ),
                      ),
                    ),

                    // Futures LTP
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currencyFmt.format(ltp),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                          Text(
                            '${isPositive ? '+' : ''}${change.toStringAsFixed(2)} (${isPositive ? '+' : ''}${changePct.toStringAsFixed(2)}%)',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Spot & Basis
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Spot: ₹${spotLtp.toStringAsFixed(1)}', style: TextStyle(fontSize: 10.5, color: textSub)),
                          Text(
                            'Basis: ${basis >= 0 ? '+' : ''}${basis.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: basis >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Lot Size
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0369A1).withOpacity(0.2) : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.4)),
                          ),
                          child: Text(
                            '${_numFmt.format(contract.lotSize)} Qty',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0284C7)),
                          ),
                        ),
                      ),
                    ),

                    // Total Contract Value
                    Expanded(
                      flex: 2,
                      child: Text(
                        _currencyFmt.format(contractVal),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textMain),
                      ),
                    ),

                    // Action Buttons [ BUY FUT ] [ SELL FUT ]
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _openFuturesOrderTicket(contract, 'BUY'),
                            child: const Text('BUY FUT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _openFuturesOrderTicket(contract, 'SELL'),
                            child: const Text('SELL FUT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
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
