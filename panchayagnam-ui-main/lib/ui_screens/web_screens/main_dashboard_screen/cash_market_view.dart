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
  final bool isNifty50;

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
    this.isNifty50 = false,
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
    'Nifty 50 Cash (50 Stocks)',
    'Energy',
    'PSU',
    'Banking',
    'Finance',
    'IT',
    'Tech',
    'Auto',
    'Metals',
  ];

  late final List<CashStockItem> _allStocks;

  @override
  void initState() {
    super.initState();
    _initStockUniverse();
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

  void _initStockUniverse() {
    _allStocks = const [
      // ══════════════════════════════════════════════════════════════════════
      // ── 1. ENERGY SECTOR ────────────────────────────────────────────────
      // ══════════════════════════════════════════════════════════════════════
      CashStockItem(
        symbol: 'RELIANCE',
        companyName: 'Reliance Industries Ltd',
        sector: 'Energy',
        baseLtp: 1363.00,
        dayHigh: 1374.50,
        dayLow: 1358.00,
        open: 1360.00,
        prevClose: 1367.00,
        volume: 8200000,
        high52w: 1608.80,
        low52w: 1100.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'ONGC',
        companyName: 'Oil & Natural Gas Corp Ltd',
        sector: 'Energy',
        baseLtp: 265.40,
        dayHigh: 268.80,
        dayLow: 263.10,
        open: 264.00,
        prevClose: 262.90,
        volume: 14200000,
        high52w: 344.00,
        low52w: 180.20,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'NTPC',
        companyName: 'NTPC Ltd',
        sector: 'Energy',
        baseLtp: 374.80,
        dayHigh: 378.50,
        dayLow: 371.00,
        open: 372.50,
        prevClose: 370.20,
        volume: 11500000,
        high52w: 435.00,
        low52w: 232.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'POWERGRID',
        companyName: 'Power Grid Corp of India Ltd',
        sector: 'Energy',
        baseLtp: 324.50,
        dayHigh: 329.00,
        dayLow: 321.00,
        open: 322.00,
        prevClose: 320.80,
        volume: 15600000,
        high52w: 366.50,
        low52w: 200.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'ADANIENT',
        companyName: 'Adani Enterprises Ltd',
        sector: 'Energy',
        baseLtp: 2480.00,
        dayHigh: 2525.00,
        dayLow: 2440.00,
        open: 2450.00,
        prevClose: 2435.00,
        volume: 4800000,
        high52w: 3450.00,
        low52w: 2142.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'ADANIPORTS',
        companyName: 'Adani Ports & Special Economic Zone',
        sector: 'Energy',
        baseLtp: 1180.00,
        dayHigh: 1205.00,
        dayLow: 1165.00,
        open: 1170.00,
        prevClose: 1165.00,
        volume: 6500000,
        high52w: 1607.95,
        low52w: 754.50,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'TATAPOWER',
        companyName: 'Tata Power Company Ltd',
        sector: 'Energy',
        baseLtp: 412.00,
        dayHigh: 418.00,
        dayLow: 408.00,
        open: 410.00,
        prevClose: 409.00,
        volume: 12000000,
        high52w: 494.85,
        low52w: 250.00,
        isNifty50: false,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ── 2. PSU (PUBLIC SECTOR UNDERTAKINGS) SECTOR ───────────────────────
      // ══════════════════════════════════════════════════════════════════════
      CashStockItem(
        symbol: 'IOC',
        companyName: 'Indian Oil Corporation Ltd',
        sector: 'PSU',
        baseLtp: 145.95,
        dayHigh: 147.40,
        dayLow: 143.20,
        open: 144.10,
        prevClose: 143.82,
        volume: 34500000,
        high52w: 196.80,
        low52w: 85.50,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'COALINDIA',
        companyName: 'Coal India Ltd',
        sector: 'PSU',
        baseLtp: 438.50,
        dayHigh: 442.90,
        dayLow: 434.00,
        open: 435.00,
        prevClose: 432.10,
        volume: 9800000,
        high52w: 527.40,
        low52w: 310.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'BPCL',
        companyName: 'Bharat Petroleum Corp Ltd',
        sector: 'PSU',
        baseLtp: 308.25,
        dayHigh: 312.00,
        dayLow: 305.50,
        open: 307.00,
        prevClose: 305.80,
        volume: 12400000,
        high52w: 388.00,
        low52w: 195.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'BEL',
        companyName: 'Bharat Electronics Ltd',
        sector: 'PSU',
        baseLtp: 295.00,
        dayHigh: 301.00,
        dayLow: 291.50,
        open: 293.00,
        prevClose: 291.80,
        volume: 24000000,
        high52w: 340.50,
        low52w: 135.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'GAIL',
        companyName: 'GAIL (India) Ltd',
        sector: 'PSU',
        baseLtp: 198.50,
        dayHigh: 202.00,
        dayLow: 196.20,
        open: 197.00,
        prevClose: 196.50,
        volume: 18400000,
        high52w: 246.35,
        low52w: 120.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'PFC',
        companyName: 'Power Finance Corporation Ltd',
        sector: 'PSU',
        baseLtp: 462.50,
        dayHigh: 469.00,
        dayLow: 458.00,
        open: 460.00,
        prevClose: 459.20,
        volume: 11200000,
        high52w: 580.50,
        low52w: 360.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'REC',
        companyName: 'REC Ltd',
        sector: 'PSU',
        baseLtp: 512.40,
        dayHigh: 518.80,
        dayLow: 507.00,
        open: 509.00,
        prevClose: 508.60,
        volume: 8900000,
        high52w: 654.00,
        low52w: 285.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'BHEL',
        companyName: 'Bharat Heavy Electricals Ltd',
        sector: 'PSU',
        baseLtp: 238.00,
        dayHigh: 242.50,
        dayLow: 235.00,
        open: 236.00,
        prevClose: 235.40,
        volume: 15400000,
        high52w: 335.40,
        low52w: 140.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'NHPC',
        companyName: 'NHPC Ltd',
        sector: 'PSU',
        baseLtp: 84.50,
        dayHigh: 86.20,
        dayLow: 83.40,
        open: 83.80,
        prevClose: 83.70,
        volume: 29000000,
        high52w: 118.40,
        low52w: 50.00,
        isNifty50: false,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ── 3. BANKING SECTOR ────────────────────────────────────────────────
      // ══════════════════════════════════════════════════════════════════════
      CashStockItem(
        symbol: 'HDFCBANK',
        companyName: 'HDFC Bank Ltd',
        sector: 'Banking',
        baseLtp: 1742.00,
        dayHigh: 1756.00,
        dayLow: 1731.00,
        open: 1735.00,
        prevClose: 1730.00,
        volume: 18500000,
        high52w: 1794.00,
        low52w: 1363.55,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'ICICIBANK',
        companyName: 'ICICI Bank Ltd',
        sector: 'Banking',
        baseLtp: 1264.00,
        dayHigh: 1276.00,
        dayLow: 1252.00,
        open: 1255.00,
        prevClose: 1250.00,
        volume: 14200000,
        high52w: 1332.00,
        low52w: 920.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'SBIN',
        companyName: 'State Bank of India',
        sector: 'Banking',
        baseLtp: 814.00,
        dayHigh: 822.00,
        dayLow: 808.00,
        open: 810.00,
        prevClose: 806.00,
        volume: 16200000,
        high52w: 912.00,
        low52w: 555.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'AXISBANK',
        companyName: 'Axis Bank Ltd',
        sector: 'Banking',
        baseLtp: 1168.00,
        dayHigh: 1182.00,
        dayLow: 1155.00,
        open: 1160.00,
        prevClose: 1156.00,
        volume: 9400000,
        high52w: 1339.65,
        low52w: 968.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'KOTAKBANK',
        companyName: 'Kotak Mahindra Bank Ltd',
        sector: 'Banking',
        baseLtp: 1765.00,
        dayHigh: 1782.00,
        dayLow: 1750.00,
        open: 1755.00,
        prevClose: 1752.00,
        volume: 5600000,
        high52w: 1908.00,
        low52w: 1544.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'INDUSINDBK',
        companyName: 'IndusInd Bank Ltd',
        sector: 'Banking',
        baseLtp: 1030.00,
        dayHigh: 1048.00,
        dayLow: 1018.00,
        open: 1022.00,
        prevClose: 1020.00,
        volume: 7800000,
        high52w: 1694.00,
        low52w: 970.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'PNB',
        companyName: 'Punjab National Bank',
        sector: 'Banking',
        baseLtp: 102.50,
        dayHigh: 104.20,
        dayLow: 101.10,
        open: 101.50,
        prevClose: 101.20,
        volume: 38000000,
        high52w: 144.00,
        low52w: 72.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'BANKBARODA',
        companyName: 'Bank of Baroda',
        sector: 'Banking',
        baseLtp: 248.00,
        dayHigh: 252.00,
        dayLow: 245.00,
        open: 246.00,
        prevClose: 245.50,
        volume: 16000000,
        high52w: 298.45,
        low52w: 190.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'CANBK',
        companyName: 'Canara Bank',
        sector: 'Banking',
        baseLtp: 98.50,
        dayHigh: 100.20,
        dayLow: 97.40,
        open: 97.80,
        prevClose: 97.60,
        volume: 22000000,
        high52w: 129.35,
        low52w: 68.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'IDFCFIRSTB',
        companyName: 'IDFC First Bank Ltd',
        sector: 'Banking',
        baseLtp: 66.50,
        dayHigh: 67.80,
        dayLow: 65.60,
        open: 65.90,
        prevClose: 65.80,
        volume: 45000000,
        high52w: 90.70,
        low52w: 64.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'YESBANK',
        companyName: 'Yes Bank Ltd',
        sector: 'Banking',
        baseLtp: 19.85,
        dayHigh: 20.30,
        dayLow: 19.50,
        open: 19.60,
        prevClose: 19.55,
        volume: 72000000,
        high52w: 32.85,
        low52w: 16.00,
        isNifty50: false,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ── 4. FINANCE SECTOR (NBFCs & Insurance) ────────────────────────────
      // ══════════════════════════════════════════════════════════════════════
      CashStockItem(
        symbol: 'BAJFINANCE',
        companyName: 'Bajaj Finance Ltd',
        sector: 'Finance',
        baseLtp: 6820.00,
        dayHigh: 6890.00,
        dayLow: 6770.00,
        open: 6780.00,
        prevClose: 6750.00,
        volume: 1950000,
        high52w: 7850.00,
        low52w: 6160.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'BAJAJFINSV',
        companyName: 'Bajaj Finserv Ltd',
        sector: 'Finance',
        baseLtp: 1625.00,
        dayHigh: 1645.00,
        dayLow: 1610.00,
        open: 1615.00,
        prevClose: 1610.00,
        volume: 3100000,
        high52w: 2029.90,
        low52w: 1419.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'SHRIRAMFIN',
        companyName: 'Shriram Finance Ltd',
        sector: 'Finance',
        baseLtp: 3120.00,
        dayHigh: 3160.00,
        dayLow: 3085.00,
        open: 3095.00,
        prevClose: 3080.00,
        volume: 2200000,
        high52w: 3650.00,
        low52w: 1980.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'SBILIFE',
        companyName: 'SBI Life Insurance Company Ltd',
        sector: 'Finance',
        baseLtp: 1540.00,
        dayHigh: 1560.00,
        dayLow: 1525.00,
        open: 1530.00,
        prevClose: 1528.00,
        volume: 2500000,
        high52w: 1935.00,
        low52w: 1350.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'HDFCLIFE',
        companyName: 'HDFC Life Insurance Company Ltd',
        sector: 'Finance',
        baseLtp: 692.00,
        dayHigh: 702.00,
        dayLow: 685.00,
        open: 688.00,
        prevClose: 685.00,
        volume: 5400000,
        high52w: 760.00,
        low52w: 570.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'CHOLAFIN',
        companyName: 'Cholamandalam Inv & Fin Co',
        sector: 'Finance',
        baseLtp: 1280.00,
        dayHigh: 1305.00,
        dayLow: 1265.00,
        open: 1270.00,
        prevClose: 1268.00,
        volume: 3400000,
        high52w: 1589.00,
        low52w: 1050.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'JIOFIN',
        companyName: 'Jio Financial Services Ltd',
        sector: 'Finance',
        baseLtp: 312.00,
        dayHigh: 318.00,
        dayLow: 308.50,
        open: 310.00,
        prevClose: 309.20,
        volume: 14500000,
        high52w: 394.70,
        low52w: 212.00,
        isNifty50: false,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ── 5. IT (INFORMATION TECHNOLOGY) SECTOR ───────────────────────────
      // ══════════════════════════════════════════════════════════════════════
      CashStockItem(
        symbol: 'TCS',
        companyName: 'Tata Consultancy Services Ltd',
        sector: 'IT',
        baseLtp: 4185.00,
        dayHigh: 4230.00,
        dayLow: 4160.00,
        open: 4175.00,
        prevClose: 4162.00,
        volume: 2200000,
        high52w: 4592.25,
        low52w: 3313.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'INFY',
        companyName: 'Infosys Ltd',
        sector: 'IT',
        baseLtp: 1855.00,
        dayHigh: 1878.00,
        dayLow: 1842.00,
        open: 1845.00,
        prevClose: 1840.00,
        volume: 6800000,
        high52w: 1991.45,
        low52w: 1358.35,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'HCLTECH',
        companyName: 'HCL Technologies Ltd',
        sector: 'IT',
        baseLtp: 1840.00,
        dayHigh: 1862.00,
        dayLow: 1828.00,
        open: 1830.00,
        prevClose: 1825.00,
        volume: 4200000,
        high52w: 1898.00,
        low52w: 1235.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'WIPRO',
        companyName: 'Wipro Ltd',
        sector: 'IT',
        baseLtp: 565.00,
        dayHigh: 574.00,
        dayLow: 558.00,
        open: 560.00,
        prevClose: 558.00,
        volume: 13500000,
        high52w: 590.00,
        low52w: 430.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'TECHM',
        companyName: 'Tech Mahindra Ltd',
        sector: 'IT',
        baseLtp: 1680.00,
        dayHigh: 1705.00,
        dayLow: 1665.00,
        open: 1670.00,
        prevClose: 1665.00,
        volume: 3800000,
        high52w: 1740.00,
        low52w: 1100.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'LTIM',
        companyName: 'LTIMindtree Ltd',
        sector: 'IT',
        baseLtp: 5850.00,
        dayHigh: 5930.00,
        dayLow: 5790.00,
        open: 5810.00,
        prevClose: 5800.00,
        volume: 1200000,
        high52w: 6442.00,
        low52w: 4515.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'COFORGE',
        companyName: 'Coforge Ltd',
        sector: 'IT',
        baseLtp: 7850.00,
        dayHigh: 7980.00,
        dayLow: 7780.00,
        open: 7800.00,
        prevClose: 7770.00,
        volume: 850000,
        high52w: 8400.00,
        low52w: 4287.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'PERSISTENT',
        companyName: 'Persistent Systems Ltd',
        sector: 'IT',
        baseLtp: 5450.00,
        dayHigh: 5540.00,
        dayLow: 5390.00,
        open: 5400.00,
        prevClose: 5380.00,
        volume: 920000,
        high52w: 5950.00,
        low52w: 3340.00,
        isNifty50: false,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ── 6. TECH (TELECOM & CONSUMER TECH) SECTOR ─────────────────────────
      // ══════════════════════════════════════════════════════════════════════
      CashStockItem(
        symbol: 'BHARTIARTL',
        companyName: 'Bharti Airtel Ltd',
        sector: 'Tech',
        baseLtp: 1605.00,
        dayHigh: 1622.00,
        dayLow: 1592.00,
        open: 1595.00,
        prevClose: 1590.00,
        volume: 7400000,
        high52w: 1779.00,
        low52w: 955.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'TATACOMM',
        companyName: 'Tata Communications Ltd',
        sector: 'Tech',
        baseLtp: 1820.00,
        dayHigh: 1850.00,
        dayLow: 1802.00,
        open: 1810.00,
        prevClose: 1805.00,
        volume: 1400000,
        high52w: 2175.00,
        low52w: 1550.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'DIXON',
        companyName: 'Dixon Technologies Ltd',
        sector: 'Tech',
        baseLtp: 14500.00,
        dayHigh: 14750.00,
        dayLow: 14320.00,
        open: 14350.00,
        prevClose: 14310.00,
        volume: 680000,
        high52w: 15998.00,
        low52w: 5200.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'ZOMATO',
        companyName: 'Zomato Ltd',
        sector: 'Tech',
        baseLtp: 275.00,
        dayHigh: 281.00,
        dayLow: 271.50,
        open: 273.00,
        prevClose: 272.50,
        volume: 32000000,
        high52w: 298.20,
        low52w: 112.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'NAUKRI',
        companyName: 'Info Edge (India) Ltd',
        sector: 'Tech',
        baseLtp: 7650.00,
        dayHigh: 7780.00,
        dayLow: 7580.00,
        open: 7600.00,
        prevClose: 7580.00,
        volume: 750000,
        high52w: 8500.00,
        low52w: 4800.00,
        isNifty50: false,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ── 7. AUTO SECTOR ───────────────────────────────────────────────────
      // ══════════════════════════════════════════════════════════════════════
      CashStockItem(
        symbol: 'MARUTI',
        companyName: 'Maruti Suzuki India Ltd',
        sector: 'Auto',
        baseLtp: 11250.00,
        dayHigh: 11390.00,
        dayLow: 11180.00,
        open: 11200.00,
        prevClose: 11150.00,
        volume: 850000,
        high52w: 13680.00,
        low52w: 9737.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'TATAMOTORS',
        companyName: 'Tata Motors Ltd',
        sector: 'Auto',
        baseLtp: 812.00,
        dayHigh: 825.00,
        dayLow: 804.00,
        open: 808.00,
        prevClose: 805.00,
        volume: 19800000,
        high52w: 1179.05,
        low52w: 665.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'M&M',
        companyName: 'Mahindra & Mahindra Ltd',
        sector: 'Auto',
        baseLtp: 2980.00,
        dayHigh: 3025.00,
        dayLow: 2950.00,
        open: 2960.00,
        prevClose: 2945.00,
        volume: 4500000,
        high52w: 3222.00,
        low52w: 1490.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'BAJAJ-AUTO',
        companyName: 'Bajaj Auto Ltd',
        sector: 'Auto',
        baseLtp: 9450.00,
        dayHigh: 9580.00,
        dayLow: 9380.00,
        open: 9400.00,
        prevClose: 9360.00,
        volume: 750000,
        high52w: 12774.00,
        low52w: 5800.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'EICHERMOT',
        companyName: 'Eicher Motors Ltd',
        sector: 'Auto',
        baseLtp: 4920.00,
        dayHigh: 4985.00,
        dayLow: 4880.00,
        open: 4890.00,
        prevClose: 4875.00,
        volume: 1100000,
        high52w: 5104.00,
        low52w: 3600.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'HEROMOTOCO',
        companyName: 'Hero MotoCorp Ltd',
        sector: 'Auto',
        baseLtp: 4780.00,
        dayHigh: 4840.00,
        dayLow: 4730.00,
        open: 4745.00,
        prevClose: 4725.00,
        volume: 1200000,
        high52w: 6095.00,
        low52w: 3000.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'TVSMOTOR',
        companyName: 'TVS Motor Company Ltd',
        sector: 'Auto',
        baseLtp: 2380.00,
        dayHigh: 2420.00,
        dayLow: 2355.00,
        open: 2360.00,
        prevClose: 2350.00,
        volume: 1800000,
        high52w: 2958.00,
        low52w: 1850.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'BHARATFORG',
        companyName: 'Bharat Forge Ltd',
        sector: 'Auto',
        baseLtp: 1380.00,
        dayHigh: 1405.00,
        dayLow: 1365.00,
        open: 1370.00,
        prevClose: 1368.00,
        volume: 2400000,
        high52w: 1720.00,
        low52w: 1050.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'MOTHERSON',
        companyName: 'Samvardhana Motherson International',
        sector: 'Auto',
        baseLtp: 165.00,
        dayHigh: 168.00,
        dayLow: 163.20,
        open: 164.00,
        prevClose: 163.50,
        volume: 28000000,
        high52w: 216.90,
        low52w: 86.00,
        isNifty50: false,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ── 8. METALS SECTOR ─────────────────────────────────────────────────
      // ══════════════════════════════════════════════════════════════════════
      CashStockItem(
        symbol: 'TATASTEEL',
        companyName: 'Tata Steel Ltd',
        sector: 'Metals',
        baseLtp: 146.80,
        dayHigh: 148.50,
        dayLow: 144.90,
        open: 145.20,
        prevClose: 144.50,
        volume: 38000000,
        high52w: 184.60,
        low52w: 114.60,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'JSWSTEEL',
        companyName: 'JSW Steel Ltd',
        sector: 'Metals',
        baseLtp: 945.00,
        dayHigh: 960.00,
        dayLow: 935.00,
        open: 938.00,
        prevClose: 935.00,
        volume: 5200000,
        high52w: 1060.00,
        low52w: 737.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'HINDALCO',
        companyName: 'Hindalco Industries Ltd',
        sector: 'Metals',
        baseLtp: 652.00,
        dayHigh: 662.00,
        dayLow: 645.00,
        open: 648.00,
        prevClose: 645.00,
        volume: 8800000,
        high52w: 715.00,
        low52w: 475.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'VEDL',
        companyName: 'Vedanta Ltd',
        sector: 'Metals',
        baseLtp: 472.00,
        dayHigh: 480.00,
        dayLow: 468.00,
        open: 470.00,
        prevClose: 468.50,
        volume: 19500000,
        high52w: 524.00,
        low52w: 211.00,
        isNifty50: false,
      ),
      CashStockItem(
        symbol: 'JINDALSTEL',
        companyName: 'Jindal Steel & Power Ltd',
        sector: 'Metals',
        baseLtp: 915.00,
        dayHigh: 932.00,
        dayLow: 905.00,
        open: 910.00,
        prevClose: 908.00,
        volume: 4600000,
        high52w: 1080.00,
        low52w: 620.00,
        isNifty50: false,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ── 9. OTHER TOP BLUECHIPS (Pharma, FMCG, Infra) ─────────────────────
      // ══════════════════════════════════════════════════════════════════════
      CashStockItem(
        symbol: 'ITC',
        companyName: 'ITC Ltd',
        sector: 'All Bluechips',
        baseLtp: 472.00,
        dayHigh: 476.50,
        dayLow: 469.00,
        open: 470.00,
        prevClose: 468.50,
        volume: 11400000,
        high52w: 528.55,
        low52w: 399.30,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'HINDUNILVR',
        companyName: 'Hindustan Unilever Ltd',
        sector: 'All Bluechips',
        baseLtp: 2420.00,
        dayHigh: 2445.00,
        dayLow: 2405.00,
        open: 2410.00,
        prevClose: 2408.00,
        volume: 2100000,
        high52w: 3034.50,
        low52w: 2170.25,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'LT',
        companyName: 'Larsen & Toubro Ltd',
        sector: 'All Bluechips',
        baseLtp: 3580.00,
        dayHigh: 3620.00,
        dayLow: 3550.00,
        open: 3560.00,
        prevClose: 3555.00,
        volume: 3100000,
        high52w: 3919.90,
        low52w: 2873.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'SUNPHARMA',
        companyName: 'Sun Pharmaceutical Industries Ltd',
        sector: 'All Bluechips',
        baseLtp: 1785.00,
        dayHigh: 1805.00,
        dayLow: 1770.00,
        open: 1775.00,
        prevClose: 1768.00,
        volume: 3200000,
        high52w: 1960.00,
        low52w: 1165.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'TITAN',
        companyName: 'Titan Company Ltd',
        sector: 'All Bluechips',
        baseLtp: 3240.00,
        dayHigh: 3280.00,
        dayLow: 3215.00,
        open: 3220.00,
        prevClose: 3210.00,
        volume: 1800000,
        high52w: 3886.95,
        low52w: 3055.65,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'ASIANPAINT',
        companyName: 'Asian Paints Ltd',
        sector: 'All Bluechips',
        baseLtp: 2510.00,
        dayHigh: 2540.00,
        dayLow: 2485.00,
        open: 2490.00,
        prevClose: 2480.00,
        volume: 2400000,
        high52w: 3422.00,
        low52w: 2360.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'ULTRACEMCO',
        companyName: 'UltraTech Cement Ltd',
        sector: 'All Bluechips',
        baseLtp: 11200.00,
        dayHigh: 11350.00,
        dayLow: 11100.00,
        open: 11150.00,
        prevClose: 11100.00,
        volume: 720000,
        high52w: 12135.00,
        low52w: 8200.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'NESTLEIND',
        companyName: 'Nestle India Ltd',
        sector: 'All Bluechips',
        baseLtp: 2280.00,
        dayHigh: 2310.00,
        dayLow: 2260.00,
        open: 2265.00,
        prevClose: 2260.00,
        volume: 950000,
        high52w: 2777.00,
        low52w: 2145.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'GRASIM',
        companyName: 'Grasim Industries Ltd',
        sector: 'All Bluechips',
        baseLtp: 2540.00,
        dayHigh: 2575.00,
        dayLow: 2520.00,
        open: 2525.00,
        prevClose: 2520.00,
        volume: 1400000,
        high52w: 2875.00,
        low52w: 1870.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'CIPLA',
        companyName: 'Cipla Ltd',
        sector: 'All Bluechips',
        baseLtp: 1510.00,
        dayHigh: 1530.00,
        dayLow: 1495.00,
        open: 1500.00,
        prevClose: 1495.00,
        volume: 2900000,
        high52w: 1702.00,
        low52w: 1170.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'DRREDDY',
        companyName: "Dr. Reddy's Laboratories Ltd",
        sector: 'All Bluechips',
        baseLtp: 1245.00,
        dayHigh: 1262.00,
        dayLow: 1235.00,
        open: 1240.00,
        prevClose: 1235.00,
        volume: 2600000,
        high52w: 1380.00,
        low52w: 1040.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'BRITANNIA',
        companyName: 'Britannia Industries Ltd',
        sector: 'All Bluechips',
        baseLtp: 4950.00,
        dayHigh: 5010.00,
        dayLow: 4910.00,
        open: 4920.00,
        prevClose: 4905.00,
        volume: 1050000,
        high52w: 6470.00,
        low52w: 4650.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'APOLLOHOSP',
        companyName: 'Apollo Hospitals Enterprise Ltd',
        sector: 'All Bluechips',
        baseLtp: 6880.00,
        dayHigh: 6960.00,
        dayLow: 6820.00,
        open: 6840.00,
        prevClose: 6820.00,
        volume: 820000,
        high52w: 7520.00,
        low52w: 5200.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'DIVISLAB',
        companyName: "Divi's Laboratories Ltd",
        sector: 'All Bluechips',
        baseLtp: 5850.00,
        dayHigh: 5930.00,
        dayLow: 5790.00,
        open: 5800.00,
        prevClose: 5780.00,
        volume: 940000,
        high52w: 6240.00,
        low52w: 3380.00,
        isNifty50: true,
      ),
      CashStockItem(
        symbol: 'TRENT',
        companyName: 'Trent Ltd',
        sector: 'All Bluechips',
        baseLtp: 6450.00,
        dayHigh: 6560.00,
        dayLow: 6380.00,
        open: 6400.00,
        prevClose: 6380.00,
        volume: 2700000,
        high52w: 8345.00,
        low52w: 2800.00,
        isNifty50: true,
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
    final quote = LiveMarketDataService().getQuote(stock.symbol);
    if (quote != null && quote.ltp > 0) {
      return quote.ltp;
    }
    if (_liveLtpOverrides.containsKey(stock.symbol)) {
      return _liveLtpOverrides[stock.symbol]!;
    }
    return stock.baseLtp;
  }

  double _getLiveChange(CashStockItem stock) {
    final quote = LiveMarketDataService().getQuote(stock.symbol);
    if (quote != null && quote.ltp > 0) {
      return quote.change != 0
          ? quote.change
          : (quote.ltp - (quote.prevClose > 0 ? quote.prevClose : stock.prevClose));
    }
    final ltp = _getLiveLtp(stock);
    return ltp - stock.prevClose;
  }

  double _getLiveChangePct(CashStockItem stock) {
    final quote = LiveMarketDataService().getQuote(stock.symbol);
    if (quote != null && quote.ltp > 0 && quote.changePct != 0) {
      return quote.changePct;
    }
    final change = _getLiveChange(stock);
    final prevClose = (quote != null && quote.prevClose > 0) ? quote.prevClose : stock.prevClose;
    return prevClose > 0 ? (change / prevClose) * 100 : 0.0;
  }

  double _getLiveHigh(CashStockItem stock) {
    final quote = LiveMarketDataService().getQuote(stock.symbol);
    if (quote != null && quote.high > 0) {
      return quote.high;
    }
    final ltp = _getLiveLtp(stock);
    return ltp > stock.dayHigh ? ltp : stock.dayHigh;
  }

  double _getLiveLow(CashStockItem stock) {
    final quote = LiveMarketDataService().getQuote(stock.symbol);
    if (quote != null && quote.low > 0) {
      return quote.low;
    }
    final ltp = _getLiveLtp(stock);
    return (ltp < stock.dayLow && ltp > 0) ? ltp : stock.dayLow;
  }

  List<CashStockItem> get _filteredStocks {
    return _allStocks.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.symbol.toUpperCase().contains(_searchQuery.toUpperCase()) ||
          s.companyName.toUpperCase().contains(_searchQuery.toUpperCase());

      if (!matchesSearch) return false;

      if (_activeSectorIndex == 0) return true; // All Bluechips
      final sectorName = _sectors[_activeSectorIndex];
      if (sectorName.contains('Nifty 50')) {
        return s.isNifty50;
      }
      return s.sector.toUpperCase() == sectorName.toUpperCase();
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
              final change = _getLiveChange(stock);
              final changePct = _getLiveChangePct(stock);
              final dayHigh = _getLiveHigh(stock);
              final dayLow = _getLiveLow(stock);
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
                          Text('H: ₹${dayHigh.toStringAsFixed(1)}', style: TextStyle(fontSize: 10.5, color: textSub)),
                          Text('L: ₹${dayLow.toStringAsFixed(1)}', style: TextStyle(fontSize: 10.5, color: textSub)),
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
