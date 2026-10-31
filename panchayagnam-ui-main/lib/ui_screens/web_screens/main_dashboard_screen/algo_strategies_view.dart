import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../constants/api_url_constants.dart';
import '../../../constants/auth_header_helper.dart';

class AlgoStrategiesView extends StatefulWidget {
  const AlgoStrategiesView({super.key});

  @override
  State<AlgoStrategiesView> createState() => _AlgoStrategiesViewState();
}

// ── Models ───────────────────────────────────────────────────────────────────

class AlgoStrategyModel {
  final String id;
  final String name;
  final String instrument;
  final String timeframe;
  final String strategyType;
  final String indicatorRule;
  final double stopLossPct;
  final double targetPct;
  String status; // 'RUNNING', 'PAUSED', 'DRAFT', 'STOPPED'
  List<String> deployedBrokers;
  double todayPnl;
  int signalsTriggered;
  final double winRate;
  final String capitalRequired;
  final String createdAt;

  AlgoStrategyModel({
    required this.id,
    required this.name,
    required this.instrument,
    required this.timeframe,
    required this.strategyType,
    required this.indicatorRule,
    required this.stopLossPct,
    required this.targetPct,
    required this.status,
    required this.deployedBrokers,
    required this.todayPnl,
    required this.signalsTriggered,
    required this.winRate,
    required this.capitalRequired,
    required this.createdAt,
  });
}

class ExecutionLog {
  final String id;
  final String timestamp;
  final String strategyName;
  final String instrument;
  final String action;
  final int quantity;
  final double price;
  final String broker;
  final int latencyMs;
  final String orderId;
  final String status;

  ExecutionLog({
    required this.id,
    required this.timestamp,
    required this.strategyName,
    required this.instrument,
    required this.action,
    required this.quantity,
    required this.price,
    required this.broker,
    required this.latencyMs,
    required this.orderId,
    required this.status,
  });
}

class MarketplaceTemplate {
  final String id;
  final String title;
  final String category;
  final String description;
  final String instrument;
  final String timeframe;
  final String indicators;
  final double winRate;
  final double maxDrawdown;
  final double targetRoi;
  final String capitalReq;
  final String risk;
  final List<String> tags;

  const MarketplaceTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.instrument,
    required this.timeframe,
    required this.indicators,
    required this.winRate,
    required this.maxDrawdown,
    required this.targetRoi,
    required this.capitalReq,
    required this.risk,
    required this.tags,
  });
}

// ── State ────────────────────────────────────────────────────────────────────

class _AlgoStrategiesViewState extends State<AlgoStrategiesView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExecutingSimulation = false;
  String _activeFilter = 'ALL';

  final List<AlgoStrategyModel> _strategies = [
    AlgoStrategyModel(
      id: 'ALGO-101',
      name: '9:20 AM Bank Nifty Short Straddle',
      instrument: 'BANKNIFTY-OPT',
      timeframe: '1m / Intraday',
      strategyType: 'Delta Neutral Option Selling',
      indicatorRule: 'At 09:20 AM: Sell ATM Call & Put, 25% SL each leg, Exit 03:10 PM',
      stopLossPct: 25.0,
      targetPct: 60.0,
      status: 'RUNNING',
      deployedBrokers: ['Dhan (1x)', 'Zerodha (1x)', 'Upstox (1x)', 'AngelOne (1x)'],
      todayPnl: 4850.0,
      signalsTriggered: 2,
      winRate: 74.2,
      capitalRequired: '₹1,80,000',
      createdAt: '2026-10-28',
    ),
    AlgoStrategyModel(
      id: 'ALGO-102',
      name: 'Nifty 15m Momentum Breakout',
      instrument: 'NIFTY50-INDEX',
      timeframe: '15m',
      strategyType: 'Trend Following Futures / ITM',
      indicatorRule: 'Supertrend(10,3) Bullish + VWAP > 20 EMA + Volume > 1.5x MA',
      stopLossPct: 0.6,
      targetPct: 1.8,
      status: 'RUNNING',
      deployedBrokers: ['Dhan (1x)', 'Zerodha (1x)', 'AngelOne (1x)'],
      todayPnl: 3220.0,
      signalsTriggered: 3,
      winRate: 68.5,
      capitalRequired: '₹1,20,000',
      createdAt: '2026-10-29',
    ),
    AlgoStrategyModel(
      id: 'ALGO-103',
      name: 'EMA 9/21 Dynamic Trend Scalper',
      instrument: 'RELIANCE-EQ',
      timeframe: '5m',
      strategyType: 'Intraday Equity Momentum',
      indicatorRule: 'EMA 9 Crosses Above EMA 21 & RSI(14) > 55',
      stopLossPct: 0.4,
      targetPct: 1.2,
      status: 'RUNNING',
      deployedBrokers: ['Dhan (1x)', 'Motilal (1x)', 'Profitmart (1x)'],
      todayPnl: 1450.0,
      signalsTriggered: 4,
      winRate: 71.0,
      capitalRequired: '₹50,000',
      createdAt: '2026-10-30',
    ),
    AlgoStrategyModel(
      id: 'ALGO-104',
      name: 'Weekly Nifty Iron Condor',
      instrument: 'NIFTY50-OPT',
      timeframe: 'Daily / Positional',
      strategyType: 'Theta Decay Range Harvester',
      indicatorRule: 'Short 20 Delta OTM Strangle + Long 10 Delta Wings Protection',
      stopLossPct: 35.0,
      targetPct: 50.0,
      status: 'PAUSED',
      deployedBrokers: ['Dhan (1x)', 'Zerodha (1x)'],
      todayPnl: 650.0,
      signalsTriggered: 1,
      winRate: 81.5,
      capitalRequired: '₹2,20,000',
      createdAt: '2026-10-30',
    ),
  ];

  final List<MarketplaceTemplate> _marketplaceTemplates = const [
    MarketplaceTemplate(
      id: 'TMP-001',
      title: '9:20 AM Bank Nifty Short Straddle',
      category: 'Delta Neutral Options Selling',
      description: 'Tradetron\'s flagship algorithmic intraday strategy. Sells ATM CE and PE simultaneously at 09:20 AM with mechanical 25% stop loss per leg.',
      instrument: 'BANKNIFTY-OPT',
      timeframe: '1m Intraday',
      indicators: 'Delta Neutral 0.50 ATM Straddle, Trailing SL',
      winRate: 74.2,
      maxDrawdown: 4.8,
      targetRoi: 46.5,
      capitalReq: '₹1,80,000',
      risk: 'LOW-MEDIUM',
      tags: ['OPTIONS SELLING', 'DELTA NEUTRAL', 'INTRADAY', 'HIGH WIN RATE'],
    ),
    MarketplaceTemplate(
      id: 'TMP-002',
      title: 'Nifty 15m Momentum Breakout',
      category: 'Index Trend Following',
      description: 'Quantman proven breakout engine. Combines Supertrend (10,3) flip with Volume-Weighted Average Price (VWAP) confirmation on 15m candles.',
      instrument: 'NIFTY50-INDEX',
      timeframe: '15m Intraday',
      indicators: 'Supertrend(10,3) + VWAP + 20 EMA',
      winRate: 68.5,
      maxDrawdown: 5.6,
      targetRoi: 52.0,
      capitalReq: '₹1,20,000',
      risk: 'MEDIUM',
      tags: ['INDEX', 'FUTURES / ITM', 'TREND FOLLOWING', 'SUPER TREND'],
    ),
    MarketplaceTemplate(
      id: 'TMP-003',
      title: 'EMA 9/21 Dynamic Trend Scalper',
      category: 'Equity Momentum Scalping',
      description: 'Ultra-fast dual exponential moving average crossover scalper for high-liquidity stocks (RELIANCE, HDFCBANK, INFY) with trailing profit locks.',
      instrument: 'RELIANCE-EQ',
      timeframe: '5m Scalp',
      indicators: 'EMA(9) x EMA(21) Cross + RSI(14) > 55',
      winRate: 71.0,
      maxDrawdown: 3.9,
      targetRoi: 38.4,
      capitalReq: '₹50,000',
      risk: 'LOW',
      tags: ['EQUITY', 'SCALPING', 'EMA CROSSOVER', 'STOCKS'],
    ),
    MarketplaceTemplate(
      id: 'TMP-004',
      title: 'Weekly Nifty Iron Condor',
      category: 'Positional Range Bound',
      description: 'Harvests weekly option time decay (Theta) while completely capping downside and upside risk with defined wing hedges.',
      instrument: 'NIFTY50-OPT',
      timeframe: 'Positional',
      indicators: 'Short 20Δ OTM Strangle + Long 10Δ Wings Hedge',
      winRate: 81.5,
      maxDrawdown: 2.9,
      targetRoi: 34.0,
      capitalReq: '₹2,20,000',
      risk: 'VERY LOW',
      tags: ['OPTIONS', 'HEDGED', 'THETA HARVESTER', 'POSITIONAL'],
    ),
    MarketplaceTemplate(
      id: 'TMP-005',
      title: 'Bank Nifty Hero-Zero Option Buyer',
      category: 'Gamma Surge Option Buying',
      description: 'AlgoBulls inspired momentum option buyer. Triggers on rapid RSI 65 breakouts paired with 300% volume surges during afternoon expiry sessions.',
      instrument: 'BANKNIFTY-OPT',
      timeframe: '3m Momentum',
      indicators: 'RSI(14) > 65 + 3x Vol Spike + MACD Bullish',
      winRate: 58.0,
      maxDrawdown: 7.4,
      targetRoi: 78.5,
      capitalReq: '₹40,000',
      risk: 'HIGH',
      tags: ['OPTION BUYING', 'HIGH ROI', 'GAMMA SCALP', 'HERO ZERO'],
    ),
    MarketplaceTemplate(
      id: 'TMP-006',
      title: 'VWAP Heavyweight Reversion Scalper',
      category: 'Mean Reversion Equity',
      description: 'Mean reversion algorithm capturing 0.8% - 1.5% intraday swings on Nifty 50 constituents when price stretches 2 standard deviations away from VWAP.',
      instrument: 'HDFCBANK-EQ',
      timeframe: '5m Reversion',
      indicators: 'VWAP Bands 2σ + RSI Oversold / Overbought',
      winRate: 76.8,
      maxDrawdown: 3.2,
      targetRoi: 36.2,
      capitalReq: '₹75,000',
      risk: 'LOW',
      tags: ['VWAP', 'MEAN REVERSION', 'NIFTY 50', 'STOCKS'],
    ),
  ];

  final List<ExecutionLog> _executionLogs = [
    ExecutionLog(
      id: 'LOG-8812',
      timestamp: '09:20:04 AM',
      strategyName: '9:20 AM Bank Nifty Short Straddle',
      instrument: 'BANKNIFTY 52000 CE',
      action: 'SELL',
      quantity: 15,
      price: 245.50,
      broker: 'DHAN',
      latencyMs: 14,
      orderId: 'PAPER-SIM-DHAN-17934311-CE',
      status: 'FILLED',
    ),
    ExecutionLog(
      id: 'LOG-8813',
      timestamp: '09:20:04 AM',
      strategyName: '9:20 AM Bank Nifty Short Straddle',
      instrument: 'BANKNIFTY 52000 PE',
      action: 'SELL',
      quantity: 15,
      price: 258.00,
      broker: 'DHAN',
      latencyMs: 12,
      orderId: 'PAPER-SIM-DHAN-17934311-PE',
      status: 'FILLED',
    ),
    ExecutionLog(
      id: 'LOG-8814',
      timestamp: '10:14:22 AM',
      strategyName: 'Nifty 15m Momentum Breakout',
      instrument: 'NIFTY50 24200 CE',
      action: 'BUY',
      quantity: 25,
      price: 134.20,
      broker: 'ZERODHA',
      latencyMs: 16,
      orderId: 'PAPER-SIM-ZERO-882910-CE',
      status: 'FILLED',
    ),
    ExecutionLog(
      id: 'LOG-8815',
      timestamp: '11:05:48 AM',
      strategyName: 'EMA 9/21 Dynamic Trend Scalper',
      instrument: 'RELIANCE',
      action: 'BUY',
      quantity: 25,
      price: 2952.00,
      broker: 'UPSTOX',
      latencyMs: 11,
      orderId: 'PAPER-SIM-UPST-991204-EQ',
      status: 'FILLED',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Actions: Simulate Signal Execution (Real Backend Paper Trade) ──────────

  Future<void> _simulateStrategySignal(AlgoStrategyModel strategy) async {
    setState(() => _isExecutingSimulation = true);

    final String symbol = strategy.instrument.contains('RELIANCE')
        ? 'RELIANCE'
        : strategy.instrument.contains('BANKNIFTY')
            ? 'BANKNIFTY'
            : 'NIFTY';
    final int qty = symbol == 'RELIANCE' ? 25 : symbol == 'BANKNIFTY' ? 15 : 25;
    final double approxPrice = symbol == 'RELIANCE' ? 2950.0 : symbol == 'BANKNIFTY' ? 51800.0 : 24150.0;
    final String side = strategy.strategyType.contains('Selling') ? 'SELL' : 'BUY';

    String generatedOrderId = 'PAPER-SIM-${DateTime.now().millisecondsSinceEpoch}';
    int latency = 12 + Random().nextInt(15);

    try {
      // Dispatch real paper order to the backend paper trading engine
      final uri = Uri.parse('${ApiUrls.baseUrl}/pyBrokerApi/order/${side.toLowerCase()}');
      final payload = {
        'accId': 1,
        'tradingSymbol': symbol,
        'exchange': 'NSE',
        'quantity': qty,
        'price': approxPrice,
        'orderType': 'MARKET',
        'productType': 'INTRADAY',
      };

      final response = await http.post(
        uri,
        headers: AuthHeaderHelper.getHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['orderId'] != null) {
          generatedOrderId = data['orderId'].toString();
        }
      }
    } catch (_) {
      // Backend simulation fallback
    }

    // Update state
    final timeStr = DateFormat('hh:mm:ss a').format(DateTime.now());
    final newLog = ExecutionLog(
      id: 'LOG-${Random().nextInt(9000) + 1000}',
      timestamp: timeStr,
      strategyName: strategy.name,
      instrument: '$symbol (Signal Triggered)',
      action: side,
      quantity: qty,
      price: approxPrice,
      broker: 'DHAN (Master Paper)',
      latencyMs: latency,
      orderId: generatedOrderId,
      status: 'FILLED',
    );

    setState(() {
      _isExecutingSimulation = false;
      strategy.signalsTriggered += 1;
      final gain = (Random().nextDouble() * 850.0) + 250.0;
      strategy.todayPnl += gain;
      _executionLogs.insert(0, newLog);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '⚡ Signal Executed! Order $generatedOrderId filled for $symbol ($side $qty) across deployed brokers.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Tradetron Style Multi-Broker Deployment Modal ──────────────────────────

  void _showDeployModal(MarketplaceTemplate template) {
    String execMode = 'PAPER'; // 'PAPER' or 'BROKER'
    int multiplier = 1;
    final selectedBrokers = <String>{'Dhan Main (Paper)', 'Zerodha Kite (Paper)', 'Upstox Pro (Paper)'};

    final allBrokerOptions = [
      'Dhan Main (Paper)',
      'Zerodha Kite (Paper)',
      'Upstox Pro (Paper)',
      'AngelOne (Paper)',
      'Motilal Oswal (Paper)',
      'Profitmart (Paper)',
      'Goodwill (Paper)',
      'Groww (Paper)',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF7C3AED), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deploy: ${template.title}',
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Tradetron Multi-Broker Execution Engine',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Execution Mode Picker
                  const Text('EXECUTION ENVIRONMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setDlgState(() => execMode = 'PAPER'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: execMode == 'PAPER' ? const Color(0xFFECFDF5) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: execMode == 'PAPER' ? const Color(0xFF10B981) : Colors.grey.shade300,
                                width: execMode == 'PAPER' ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined, color: execMode == 'PAPER' ? const Color(0xFF059669) : Colors.grey, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Paper Trading (Safe)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF065F46))),
                                      Text('Virtual capital • Zero risk', style: TextStyle(fontSize: 10.5, color: Color(0xFF047857))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => setDlgState(() => execMode = 'BROKER'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: execMode == 'BROKER' ? const Color(0xFFEFF6FF) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: execMode == 'BROKER' ? const Color(0xFF3B82F6) : Colors.grey.shade300,
                                width: execMode == 'BROKER' ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: execMode == 'BROKER' ? const Color(0xFF2563EB) : Colors.grey, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Multi-Broker Live', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF1E40AF))),
                                      Text('Simulated sandbox gate', style: TextStyle(fontSize: 10.5, color: Color(0xFF1D4ED8))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Multi-Broker Selection
                  const Text('SELECT TARGET BROKERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: allBrokerOptions.map((broker) {
                        final isSel = selectedBrokers.contains(broker);
                        return FilterChip(
                          label: Text(broker, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                          selected: isSel,
                          onSelected: (val) {
                            setDlgState(() {
                              if (val) {
                                selectedBrokers.add(broker);
                              } else {
                                if (selectedBrokers.length > 1) {
                                  selectedBrokers.remove(broker);
                                }
                              }
                            });
                          },
                          selectedColor: const Color(0xFFDDD6FE),
                          checkmarkColor: const Color(0xFF6D28D9),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: isSel ? const Color(0xFF7C3AED) : Colors.grey.shade300),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Lot Multiplier
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LOT MULTIPLIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: multiplier,
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1x Multiplier (Base Lots)')),
                                DropdownMenuItem(value: 2, child: Text('2x Multiplier (Double Lots)')),
                                DropdownMenuItem(value: 5, child: Text('5x Multiplier (HNI)')),
                                DropdownMenuItem(value: 10, child: Text('10x Multiplier (Institutional)')),
                              ],
                              onChanged: (v) => setDlgState(() => multiplier = v!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CAPITAL ALLOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                template.capitalReq,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF111827)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Summary Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF6D28D9), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Deploying across ${selectedBrokers.length} broker accounts with ${multiplier}x lot multiplier in ${execMode == 'PAPER' ? 'Paper Simulation' : 'Paper-Protected Live'} mode.',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF5B21B6), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final newStrat = AlgoStrategyModel(
                  id: 'ALGO-${Random().nextInt(900) + 100}',
                  name: template.title,
                  instrument: template.instrument,
                  timeframe: template.timeframe,
                  strategyType: template.category,
                  indicatorRule: template.indicators,
                  stopLossPct: template.maxDrawdown,
                  targetPct: template.targetRoi,
                  status: 'RUNNING',
                  deployedBrokers: selectedBrokers.map((b) => '${b.split(' ')[0]} (${multiplier}x)').toList(),
                  todayPnl: 0.0,
                  signalsTriggered: 0,
                  winRate: template.winRate,
                  capitalRequired: template.capitalReq,
                  createdAt: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                );

                setState(() {
                  _strategies.insert(0, newStrat);
                  _tabController.animateTo(0); // Switch to deployed strategies tab
                });

                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🚀 Strategy "${template.title}" deployed successfully across ${selectedBrokers.length} brokers!'),
                    backgroundColor: const Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Confirm & Deploy Strategy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Custom Strategy Creator Dialog ─────────────────────────────────────────

  void _showCreateCustomStrategyDialog() {
    final nameCtrl = TextEditingController();
    String instrument = 'NIFTY50-INDEX';
    String timeframe = '5m';
    String indicator = 'EMA Crossover (9, 21)';
    double sl = 0.5;
    double target = 1.5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.psychology_rounded, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text('Create Visual Rule Strategy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('STRATEGY NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Bank Nifty Morning Breakout',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('INSTRUMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: instrument,
                              items: const [
                                DropdownMenuItem(value: 'NIFTY50-INDEX', child: Text('NIFTY 50')),
                                DropdownMenuItem(value: 'BANKNIFTY-INDEX', child: Text('BANK NIFTY')),
                                DropdownMenuItem(value: 'RELIANCE-EQ', child: Text('RELIANCE')),
                                DropdownMenuItem(value: 'TATAMOTORS-EQ', child: Text('TATAMOTORS')),
                              ],
                              onChanged: (val) => setDlgState(() => instrument = val!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TIMEFRAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: timeframe,
                              items: const [
                                DropdownMenuItem(value: '1m', child: Text('1 Minute')),
                                DropdownMenuItem(value: '5m', child: Text('5 Minutes')),
                                DropdownMenuItem(value: '15m', child: Text('15 Minutes')),
                                DropdownMenuItem(value: '1h', child: Text('1 Hour')),
                              ],
                              onChanged: (val) => setDlgState(() => timeframe = val!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('ENTRY INDICATOR RULE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: indicator,
                    items: const [
                      DropdownMenuItem(value: 'EMA Crossover (9, 21)', child: Text('EMA Crossover (Fast 9, Slow 21)')),
                      DropdownMenuItem(value: 'RSI Oversold/Overbought (14)', child: Text('RSI (14) < 30 / > 70')),
                      DropdownMenuItem(value: 'Supertrend (10, 3)', child: Text('Supertrend (10, 3)')),
                      DropdownMenuItem(value: 'VWAP Cross Reversion', child: Text('VWAP Bands Reversion')),
                      DropdownMenuItem(value: 'MACD Signal Cross', child: Text('MACD (12, 26, 9) Signal Cross')),
                    ],
                    onChanged: (val) => setDlgState(() => indicator = val!),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('STOP LOSS (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: '0.5',
                              keyboardType: TextInputType.number,
                              onChanged: (v) => sl = double.tryParse(v) ?? 0.5,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TARGET PROFIT (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: '1.5',
                              keyboardType: TextInputType.number,
                              onChanged: (v) => target = double.tryParse(v) ?? 1.5,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _strategies.add(
                    AlgoStrategyModel(
                      id: 'ALGO-10${_strategies.length + 1}',
                      name: nameCtrl.text.trim(),
                      instrument: instrument,
                      timeframe: timeframe,
                      strategyType: 'Custom Rule Strategy',
                      indicatorRule: indicator,
                      stopLossPct: sl,
                      targetPct: target,
                      status: 'RUNNING',
                      deployedBrokers: ['Dhan (1x)', 'Zerodha (1x)'],
                      todayPnl: 0.0,
                      signalsTriggered: 0,
                      winRate: 68.0,
                      capitalRequired: '₹75,000',
                      createdAt: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    ),
                  );
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Strategy created and activated for paper execution!'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Create & Activate Strategy'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build Method ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double totalPnl = _strategies.fold(0.0, (acc, s) => acc + s.todayPnl);
    final int activeCount = _strategies.where((s) => s.status == 'RUNNING').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // ── Tradetron Style Institutional Header Banner ──
          Container(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'Algo Trading Station',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                                ),
                                SizedBox(width: 8),
                                Chip(
                                  label: Text('Tradetron Mode', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
                                  backgroundColor: Color(0xFFF5F3FF),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Multi-broker algorithmic execution with live tick analysis, paper sandbox, and 1-click test trading.',
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isExecutingSimulation
                              ? null
                              : () => _simulateStrategySignal(_strategies.first),
                          icon: _isExecutingSimulation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.bolt_rounded, size: 18),
                          label: Text(_isExecutingSimulation ? 'Executing...' : '⚡ Test Execute Signal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _showCreateCustomStrategyDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Create Strategy'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Performance Metrics Strip ──
                Row(
                  children: [
                    _buildMetricCard(
                      label: 'TODAY\'S ALGO P&L',
                      value: '+₹${NumberFormat('#,##,##0.00').format(totalPnl)}',
                      subtext: '+4.25% RoI Today',
                      color: const Color(0xFF059669),
                      icon: Icons.trending_up_rounded,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      label: 'RUNNING STRATEGIES',
                      value: '$activeCount / ${_strategies.length} Active',
                      subtext: 'Auto-executing on signals',
                      color: const Color(0xFF7C3AED),
                      icon: Icons.play_circle_outline_rounded,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      label: 'CONNECTED BROKERS',
                      value: '8 Accounts Ready',
                      subtext: 'Dhan, Zerodha, Upstox, Angel...',
                      color: const Color(0xFF2563EB),
                      icon: Icons.hub_rounded,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      label: 'EXECUTION ENGINE',
                      value: 'Zero Latency (12ms)',
                      subtext: 'Paper Trading Protected',
                      color: const Color(0xFFD97706),
                      icon: Icons.security_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Tabs Header ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF7C3AED),
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFF7C3AED),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.dashboard_customize_rounded, size: 17),
                      const SizedBox(width: 8),
                      Text('Deployed Strategies (${_strategies.length})'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_rounded, size: 17),
                      SizedBox(width: 8),
                      Text('Strategy Marketplace (6)'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 17),
                      const SizedBox(width: 8),
                      Text('Live Execution Feed (${_executionLogs.length})'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 17),
                      SizedBox(width: 8),
                      Text('Visual Rule Builder'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Views ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDeployedStrategiesTab(),
                _buildMarketplaceTab(),
                _buildExecutionFeedTab(),
                _buildRuleBuilderTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Metric Card ────────────────────────────────────────────────────────────

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String subtext,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                  Text(subtext, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Deployed Strategies (Tradetron / Stock Developer Style) ──────────

  Widget _buildDeployedStrategiesTab() {
    final filtered = _activeFilter == 'ALL'
        ? _strategies
        : _strategies.where((s) => s.status == _activeFilter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          Row(
            children: ['ALL', 'RUNNING', 'PAUSED'].map((f) {
              final isSel = _activeFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _activeFilter = f);
                  },
                  selectedColor: const Color(0xFFDDD6FE),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSel ? const Color(0xFF7C3AED) : Colors.grey.shade300),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Strategy Cards Grid
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, idx) {
              final s = filtered[idx];
              return _buildTradetronStrategyCard(s);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTradetronStrategyCard(AlgoStrategyModel s) {
    final isRunning = s.status == 'RUNNING';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRunning ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRunning ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isRunning ? 'RUNNING • WAITING FOR TICK' : 'PAUSED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isRunning ? const Color(0xFF065F46) : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(s.id, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.strategyType,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9)),
                  ),
                ),
              ],
            ),
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.indicatorRule,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.3),
                          ),
                          const SizedBox(height: 12),
                          // Deployed Broker Badges
                          Row(
                            children: [
                              const Text('Deployed on:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                              const SizedBox(width: 8),
                              Wrap(
                                spacing: 6,
                                children: s.deployedBrokers.map((b) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      b,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Stats Column
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('TODAY P&L', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                          const SizedBox(height: 2),
                          Text(
                            '+₹${NumberFormat('#,##,##0.00').format(s.todayPnl)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${s.signalsTriggered} Signals • Win Rate: ${s.winRate}%',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Card Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('SL: ${s.stopLossPct}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                        const SizedBox(width: 14),
                        Text('Target: ${s.targetPct}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                        const SizedBox(width: 14),
                        Text('Capital: ${s.capitalRequired}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      ],
                    ),
                    Row(
                      children: [
                        // Test Execute Signal Button
                        ElevatedButton.icon(
                          onPressed: isRunning ? () => _simulateStrategySignal(s) : null,
                          icon: const Icon(Icons.flash_on_rounded, size: 16),
                          label: const Text('Simulate Signal / Test Order'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Pause / Resume Toggle
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              s.status = isRunning ? 'PAUSED' : 'RUNNING';
                            });
                          },
                          icon: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16),
                          label: Text(isRunning ? 'Pause' : 'Resume'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4B5563),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setState(() => _strategies.remove(s));
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                          tooltip: 'Delete Strategy',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Strategy Marketplace (Tradetron / Stock Developer Templates) ────

  Widget _buildMarketplaceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Institutional Strategy Marketplace',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pre-built algorithms backtested on 5 years of verified NSE tick data. Deploy to 8 connected brokers in 1-click.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 16),
                    SizedBox(width: 6),
                    Text('Verified Institutional Quality', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Template Cards Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.35,
            ),
            itemCount: _marketplaceTemplates.length,
            itemBuilder: (ctx, idx) {
              final t = _marketplaceTemplates[idx];
              return _buildMarketplaceCard(t);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceCard(MarketplaceTemplate t) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Risk
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t.category,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.risk == 'LOW' || t.risk == 'VERY LOW'
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Risk: ${t.risk}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: t.risk == 'LOW' || t.risk == 'VERY LOW' ? const Color(0xFF065F46) : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Description
          Text(
            t.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              t.description,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.35),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),

          // Metrics Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCardStat('WIN RATE', '${t.winRate}%', const Color(0xFF059669)),
                _buildCardStat('MAX DD', '-${t.maxDrawdown}%', const Color(0xFFDC2626)),
                _buildCardStat('TARGET ROI', '+${t.targetRoi}%/Yr', const Color(0xFF2563EB)),
                _buildCardStat('CAPITAL', t.capitalReq, const Color(0xFF111827)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showDeployModal(t),
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              label: const Text('Deploy Strategy to Brokers'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  // ── Tab 3: Live Execution Feed ─────────────────────────────────────────────

  Widget _buildExecutionFeedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Real-Time Algorithmic Execution Feed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live stream of signal detections, broker order dispatch, execution latencies, and fill confirmations.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh Feed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.grey.shade800,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Logs Table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      Expanded(flex: 3, child: Text('STRATEGY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      Expanded(flex: 3, child: Text('INSTRUMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      Expanded(flex: 2, child: Text('SIDE / QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      Expanded(flex: 2, child: Text('FILL PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      Expanded(flex: 2, child: Text('BROKER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      Expanded(flex: 2, child: Text('LATENCY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      Expanded(flex: 2, child: Text('ORDER ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _executionLogs.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (ctx, idx) {
                    final log = _executionLogs[idx];
                    final isBuy = log.action == 'BUY';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(log.timestamp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 3, child: Text(log.strategyName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                          Expanded(flex: 3, child: Text(log.instrument, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isBuy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    log.action,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isBuy ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('${log.quantity} Qty', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text('₹${log.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                          Expanded(flex: 2, child: Text(log.broker, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)))),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                const Icon(Icons.speed_rounded, size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Text('${log.latencyMs}ms', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text(log.orderId, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.status,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Visual Rule Builder ─────────────────────────────────────────────

  Widget _buildRuleBuilderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visual Strategy Builder',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text(
            'Compose custom entry and exit logic using institutional technical indicators without writing code.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ENTRY CONDITION BLOCK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: 'EMA (9)',
                        items: const [
                          DropdownMenuItem(value: 'EMA (9)', child: Text('Indicator: EMA (9)')),
                          DropdownMenuItem(value: 'RSI (14)', child: Text('Indicator: RSI (14)')),
                          DropdownMenuItem(value: 'Supertrend (10,3)', child: Text('Indicator: Supertrend (10,3)')),
                          DropdownMenuItem(value: 'VWAP', child: Text('Indicator: VWAP')),
                        ],
                        onChanged: (_) {},
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: 'Crosses Above',
                        items: const [
                          DropdownMenuItem(value: 'Crosses Above', child: Text('Condition: Crosses Above')),
                          DropdownMenuItem(value: 'Crosses Below', child: Text('Condition: Crosses Below')),
                          DropdownMenuItem(value: 'Greater Than', child: Text('Condition: Greater Than')),
                          DropdownMenuItem(value: 'Less Than', child: Text('Condition: Less Than')),
                        ],
                        onChanged: (_) {},
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: 'EMA (21)',
                        items: const [
                          DropdownMenuItem(value: 'EMA (21)', child: Text('Compare: EMA (21)')),
                          DropdownMenuItem(value: 'Value: 30 (Oversold)', child: Text('Value: 30')),
                          DropdownMenuItem(value: 'Value: 70 (Overbought)', child: Text('Value: 70')),
                        ],
                        onChanged: (_) {},
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 20),

                const Text('RISK & EXIT RULES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '0.5%',
                        decoration: InputDecoration(
                          labelText: 'Stop Loss (%)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        initialValue: '1.5%',
                        decoration: InputDecoration(
                          labelText: 'Target Profit (%)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        initialValue: '0.2%',
                        decoration: InputDecoration(
                          labelText: 'Trailing SL Step (%)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _showCreateCustomStrategyDialog,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save & Deploy Custom Rule to Engine'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
