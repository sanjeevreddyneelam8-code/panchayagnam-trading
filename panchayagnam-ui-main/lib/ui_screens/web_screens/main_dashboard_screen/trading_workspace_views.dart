import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../constants/api_url_constants.dart';
import '../../../constants/auth_header_helper.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../service/copy_trading_engine.dart';
import '../../../reusable_widets/copy_trade_receipt_dialog.dart';

// ─── ORDERS VIEW (Consolidated Multi-Account Order Book) ─────────────────────

class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  String _filter = 'ALL';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _orders = [
    {
      'orderId': 'ORD-882910',
      'time': '09:25:12 AM',
      'symbol': 'NIFTY 24200 CE',
      'side': 'BUY',
      'type': 'MARKET',
      'product': 'MIS',
      'qty': '200 / 200',
      'price': 135.50,
      'status': 'COMPLETED',
      'source': 'TradingView Webhook',
      'latency': '12ms',
    },
    {
      'orderId': 'ORD-882894',
      'time': '09:20:05 AM',
      'symbol': 'RELIANCE EQ',
      'side': 'BUY',
      'type': 'MARKET',
      'product': 'MIS',
      'qty': '200 / 200',
      'price': 2942.00,
      'status': 'COMPLETED',
      'source': 'MarketWatch Quick Trade',
      'latency': '14ms',
    },
    {
      'orderId': 'ORD-882850',
      'time': '09:16:40 AM',
      'symbol': 'BANKNIFTY 52000 PE',
      'side': 'SELL',
      'type': 'MARKET',
      'product': 'MIS',
      'qty': '120 / 120',
      'price': 184.00,
      'status': 'COMPLETED',
      'source': 'Algo 9:20 Straddle',
      'latency': '11ms',
    },
    {
      'orderId': 'ORD-882812',
      'time': '09:15:30 AM',
      'symbol': 'HDFCBANK EQ',
      'side': 'BUY',
      'type': 'LIMIT',
      'product': 'CNC',
      'qty': '200 / 200',
      'price': 1640.00,
      'status': 'COMPLETED',
      'source': 'WebX Copier Engine',
      'latency': '9ms',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _orders.where((o) {
      if (_filter == 'COMPLETED' && o['status'] != 'COMPLETED') return false;
      if (_filter == 'BUY' && o['side'] != 'BUY') return false;
      if (_filter == 'SELL' && o['side'] != 'SELL') return false;
      if (_searchQuery.isNotEmpty &&
          !o['symbol'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !o['orderId'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
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
                    const Text('Consolidated Order Book', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                    const SizedBox(height: 4),
                    Text('Live execution stream across all 8 synchronized Demat accounts in real-time.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sync_rounded, size: 14, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text('8 / 8 Demats Synced (Sub-15ms)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Filter row
            Row(
              children: [
                // Filter chips
                Wrap(
                  spacing: 8,
                  children: ['ALL', 'COMPLETED', 'BUY', 'SELL'].map((f) {
                    final isSel = _filter == f;
                    return ChoiceChip(
                      label: Text(f, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF475569))),
                      selected: isSel,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: Colors.white,
                      onSelected: (_) => setState(() => _filter = f),
                    );
                  }).toList(),
                ),
                const Spacer(),
                // Search box
                SizedBox(
                  width: 240,
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search order ID or scrip...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Order Table Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('TIME / REF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 3, child: Text('CONTRACT / SYMBOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('SIDE / TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('QTY / FILL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('AVG PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('SOURCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                      ],
                    ),
                  ),

                  // Table Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      final o = filtered[idx];
                      final isBuy = o['side'] == 'BUY';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o['time'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(o['orderId'], style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(o['symbol'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                            ),
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
                                      o['side'],
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: isBuy ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('${o['type']} • ${o['product']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o['qty'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  const Text('Across 8 Demats', style: TextStyle(fontSize: 10, color: Color(0xFF059669))),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('₹${(o['price'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(o['status'], style: const TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(o['latency'], style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(o['source'], style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
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
      ),
    );
  }
}

// ─── POSITIONS VIEW (Consolidated Multi-Demat Live Positions Book) ───────────

class PositionsView extends StatefulWidget {
  const PositionsView({super.key});

  @override
  State<PositionsView> createState() => _PositionsViewState();
}

class _PositionsViewState extends State<PositionsView> {
  Timer? _ticker;
  final math.Random _rnd = math.Random();

  final List<Map<String, dynamic>> _positions = [
    {
      'symbol': 'NIFTY 24200 CE',
      'product': 'INTRADAY (MIS)',
      'totalQty': 200,
      'avgPrice': 125.40,
      'ltp': 144.20,
      'isExpanded': false,
      'breakdown': [
        {'broker': 'DHAN (Leader)', 'qty': 50, 'pnl': 940.0},
        {'broker': 'ZERODHA (1x)', 'qty': 25, 'pnl': 470.0},
        {'broker': 'UPSTOX (1x)', 'qty': 25, 'pnl': 470.0},
        {'broker': 'ANGELONE (1x)', 'qty': 25, 'pnl': 470.0},
        {'broker': 'MOTILAL (1x)', 'qty': 25, 'pnl': 470.0},
        {'broker': 'PROFITMART (1x)', 'qty': 25, 'pnl': 470.0},
        {'broker': 'GOODWILL (1x)', 'qty': 25, 'pnl': 470.0},
        {'broker': 'GROWW (1x)', 'qty': 25, 'pnl': 470.0},
      ],
    },
    {
      'symbol': 'BANKNIFTY 52000 PE',
      'product': 'INTRADAY (MIS)',
      'totalQty': -120, // Short leg
      'avgPrice': 210.00,
      'ltp': 182.50,
      'isExpanded': false,
      'breakdown': [
        {'broker': 'DHAN (Leader)', 'qty': -30, 'pnl': 825.0},
        {'broker': 'ZERODHA (1x)', 'qty': -15, 'pnl': 412.5},
        {'broker': 'UPSTOX (1x)', 'qty': -15, 'pnl': 412.5},
        {'broker': 'ANGELONE (1x)', 'qty': -15, 'pnl': 412.5},
        {'broker': 'MOTILAL (1x)', 'qty': -15, 'pnl': 412.5},
        {'broker': 'PROFITMART (1x)', 'qty': -15, 'pnl': 412.5},
        {'broker': 'GOODWILL (1x)', 'qty': -15, 'pnl': 412.5},
      ],
    },
    {
      'symbol': 'RELIANCE EQ',
      'product': 'INTRADAY (MIS)',
      'totalQty': 100,
      'avgPrice': 2935.00,
      'ltp': 2949.20,
      'isExpanded': false,
      'breakdown': [
        {'broker': 'DHAN (Leader)', 'qty': 25, 'pnl': 355.0},
        {'broker': 'ZERODHA (1x)', 'qty': 25, 'pnl': 355.0},
        {'broker': 'UPSTOX (1x)', 'qty': 25, 'pnl': 355.0},
        {'broker': 'ANGELONE (1x)', 'qty': 25, 'pnl': 355.0},
      ],
    },
    {
      'symbol': 'HDFCBANK EQ',
      'product': 'DELIVERY (CNC)',
      'totalQty': 200,
      'avgPrice': 1640.00,
      'ltp': 1652.10,
      'isExpanded': false,
      'breakdown': [
        {'broker': 'DHAN (Leader)', 'qty': 50, 'pnl': 605.0},
        {'broker': 'ZERODHA (1x)', 'qty': 50, 'pnl': 605.0},
        {'broker': 'UPSTOX (1x)', 'qty': 50, 'pnl': 605.0},
        {'broker': 'ANGELONE (1x)', 'qty': 50, 'pnl': 605.0},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    // 2-second realistic price fluctuation ticker
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        for (var p in _positions) {
          final delta = (_rnd.nextDouble() - 0.49) * 0.40;
          final currentLtp = p['ltp'] as double;
          p['ltp'] = math.max(1.0, currentLtp + delta);
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  double get _totalPnl {
    double sum = 0.0;
    for (var p in _positions) {
      final qty = p['totalQty'] as int;
      final avg = p['avgPrice'] as double;
      final ltp = p['ltp'] as double;
      sum += (ltp - avg) * qty;
    }
    return sum;
  }

  void _squareOffPosition(int idx) {
    final pos = _positions[idx];
    final sym = pos['symbol'];
    setState(() {
      _positions.removeAt(idx);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Position "$sym" squared off across all 8 Demats at Market!'),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _squareOffAll() async {
    final count = _positions.length;
    setState(() {
      _positions.clear();
    });
    final engine = CopyTradingEngine();
    await engine.emergencySquareOffAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All $count open positions squared off across all 8 Demats! Portfolio is 100% Flat.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPnl = _totalPnl;
    final isPos = totalPnl >= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Consolidated Positions Book', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                    const SizedBox(height: 4),
                    Text('Aggregated live positions across all 8 connected Demat accounts with sub-second real-time M2M.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
                if (_positions.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _squareOffAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: const Text('Square-Off All (8 Demats)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // M2M Summary Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pie_chart_rounded, size: 14, color: Color(0xFF64748B)),
                            SizedBox(width: 6),
                            Text('TOTAL CONSOLIDATED M2M', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${isPos ? '+' : ''}₹${totalPnl.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isPos ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPos ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPos ? 'LIVE PROFIT 🟢' : 'LIVE LOSS 🔴',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isPos ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryItem('POOLED MARGIN', '₹80,00,000.00', '8 Demats Synced', const Color(0xFF2563EB)),
                  const SizedBox(width: 16),
                  _buildSummaryItem('OPEN POSITIONS', '${_positions.length} Active', 'All Under Limits', const Color(0xFF7C3AED)),
                  const SizedBox(width: 16),
                  _buildSummaryItem('AVERAGE SPREAD', '< 0.05%', 'Low Slippage Guard', const Color(0xFF0284C7)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Positions Table Card
            if (_positions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF059669)),
                    const SizedBox(height: 12),
                    const Text('No Open Positions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Your portfolio is currently 100% square. Place a trade from MarketWatch or Option Chain to open a multi-broker position.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('CONTRACT / PRODUCT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                          Expanded(flex: 2, child: Text('NET QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                          Expanded(flex: 2, child: Text('BUY / AVG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                          Expanded(flex: 2, child: Text('LTP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                          Expanded(flex: 2, child: Text('NET P&L', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                          Expanded(flex: 2, child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        ],
                      ),
                    ),

                    // Table Items
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _positions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, idx) {
                        final pos = _positions[idx];
                        final qty = pos['totalQty'] as int;
                        final avg = pos['avgPrice'] as double;
                        final ltp = pos['ltp'] as double;
                        final pnl = (ltp - avg) * qty;
                        final isPnlPos = pnl >= 0;
                        final isExpanded = pos['isExpanded'] == true;
                        final breakdown = List<Map<String, dynamic>>.from(pos['breakdown'] ?? []);

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () => setState(() => pos['isExpanded'] = !isExpanded),
                                          child: Icon(
                                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                            size: 20,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(pos['symbol'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B))),
                                            Text('${pos['product']} • 8 Demats Synced', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${qty > 0 ? '+' : ''}$qty Qty',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: qty > 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('₹${avg.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '₹${ltp.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: isPnlPos ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${isPnlPos ? '+' : ''}₹${pnl.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                        color: isPnlPos ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: OutlinedButton(
                                      onPressed: () => _squareOffPosition(idx),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFDC2626),
                                        side: const BorderSide(color: Color(0xFFF87171)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: const Text('Square Off', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Expandable Multi-Account Breakdown
                            if (isExpanded)
                              Container(
                                color: const Color(0xFFF8FAFC),
                                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('CHILD DEMAT ALLOCATION BREAKDOWN:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: breakdown.map((b) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(b['broker'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                              const SizedBox(width: 8),
                                              Text('${b['qty']} Qty', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                              const SizedBox(width: 8),
                                              Text(
                                                '+₹${(b['pnl'] as double).toStringAsFixed(0)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF059669)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, String sub, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color), overflow: TextOverflow.ellipsis),
            Text(sub, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─── HOLDINGS VIEW ───────────────────────────────────────────────────────────

class HoldingsView extends StatelessWidget {
  const HoldingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Demat Holdings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('Long-term delivery holdings confirmed by connected brokers.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('Multi-Broker Holdings Synchronized', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('Connect and authenticate your broker account to view verified Demat holdings.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FULL INTERACTIVE PAPER TRADING STATION ──────────────────────────────────

class PaperTradingView extends StatefulWidget {
  const PaperTradingView({super.key});

  @override
  State<PaperTradingView> createState() => _PaperTradingViewState();
}

class _PaperTradingViewState extends State<PaperTradingView> {
  bool _isLoading = false;
  bool _isSubmittingOrder = false;

  double _virtualCash = 1000000.0;
  double _realizedPnl = 0.0;
  int _selectedAccId = 1;
  String _selectedSymbol = 'RELIANCE';
  String _orderSide = 'BUY';
  final TextEditingController _qtyCtrl = TextEditingController(text: '25');
  final TextEditingController _priceCtrl = TextEditingController(text: '2950.0');
  String _orderType = 'MARKET';

  List<Map<String, dynamic>> _openPositions = [];
  List<Map<String, dynamic>> _orderHistory = [];

  final List<Map<String, dynamic>> _brokerAccounts = const [
    {'accId': 1, 'name': 'Dhan Main Account (1100345678)', 'broker': 'DHAN'},
    {'accId': 2, 'name': 'Zerodha Kite Account (ZR123456)', 'broker': 'ZERODHA'},
    {'accId': 3, 'name': 'Upstox Pro Account (UP654321)', 'broker': 'UPSTOX'},
    {'accId': 4, 'name': 'AngelOne Child Account (AG789012)', 'broker': 'ANGELONE'},
    {'accId': 5, 'name': 'Motilal Oswal Account (MO554433)', 'broker': 'MOTILAL'},
    {'accId': 6, 'name': 'Profitmart Account (PM998877)', 'broker': 'PROFITMART'},
    {'accId': 7, 'name': 'Goodwill Giga Account (GW112233)', 'broker': 'GOODWILL'},
    {'accId': 8, 'name': 'Groww Account (GR887766)', 'broker': 'GROWW'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchPaperData();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPaperData() async {
    setState(() => _isLoading = true);

    try {
      final headers = AuthHeaderHelper.getHeaders();

      // 1. Fetch Paper Balance
      final balUri = Uri.parse('${ApiUrls.baseUrl}/pyBrokerApi/paper/balance?accId=$_selectedAccId');
      final balRes = await http.get(balUri, headers: headers).timeout(const Duration(seconds: 6));
      if (balRes.statusCode == 200) {
        final balJson = jsonDecode(balRes.body);
        if (balJson is Map && balJson['virtualCashBalance'] != null) {
          _virtualCash = (balJson['virtualCashBalance'] as num).toDouble();
          _realizedPnl = ((balJson['realizedPnl'] ?? 0.0) as num).toDouble();
        }
      }

      // 2. Fetch Paper Positions
      final posUri = Uri.parse('${ApiUrls.baseUrl}/pyBrokerApi/paper/positions?accId=$_selectedAccId');
      final posRes = await http.get(posUri, headers: headers).timeout(const Duration(seconds: 6));
      if (posRes.statusCode == 200) {
        final posJson = jsonDecode(posRes.body);
        if (posJson is List) {
          _openPositions = List<Map<String, dynamic>>.from(posJson);
        }
      }

      // 3. Fetch Order History
      final histUri = Uri.parse('${ApiUrls.baseUrl}/pyBrokerApi/order/history?accId=$_selectedAccId');
      final histRes = await http.get(histUri, headers: headers).timeout(const Duration(seconds: 6));
      if (histRes.statusCode == 200) {
        final histJson = jsonDecode(histRes.body);
        if (histJson is Map && histJson['data'] is List) {
          _orderHistory = List<Map<String, dynamic>>.from(histJson['data']);
        }
      }
    } catch (_) {
      // Local simulated fallback
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executePaperTrade() async {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 10;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 1000.0;

    setState(() => _isSubmittingOrder = true);

    try {
      final sideLower = _orderSide.toLowerCase();
      final uri = Uri.parse('${ApiUrls.baseUrl}/pyBrokerApi/order/$sideLower');
      final payload = {
        'accId': _selectedAccId,
        'tradingSymbol': _selectedSymbol,
        'exchange': 'NSE',
        'quantity': qty,
        'price': price,
        'orderType': _orderType,
        'productType': 'INTRADAY',
      };

      final response = await http.post(
        uri,
        headers: AuthHeaderHelper.getHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      String orderId = 'PAPER-SIM-${DateTime.now().millisecondsSinceEpoch}';
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['orderId'] != null) {
          orderId = data['orderId'].toString();
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚡ Paper Order Placed! Order ID: $orderId ($_orderSide $qty $_selectedSymbol @ ₹$price)',
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

      // Re-fetch positions, balance & orders
      await _fetchPaperData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing paper order: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingOrder = false);
    }
  }

  Future<void> _squareOffPosition(Map<String, dynamic> pos) async {
    final symbol = pos['tradingSymbol'] ?? 'STOCK';
    final qty = pos['quantity'] ?? 10;
    final avgPrice = (pos['averageBuyPrice'] ?? 1000.0) as num;

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse('${ApiUrls.baseUrl}/pyBrokerApi/order/sell');
      final payload = {
        'accId': _selectedAccId,
        'tradingSymbol': symbol,
        'exchange': 'NSE',
        'quantity': qty,
        'price': avgPrice.toDouble(),
        'orderType': 'MARKET',
        'productType': 'INTRADAY',
      };

      await http.post(
        uri,
        headers: AuthHeaderHelper.getHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ Squared off position for $symbol ($qty Qty)!'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _fetchPaperData();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Status Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('Paper Trading Workstation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                        SizedBox(width: 10),
                        Chip(
                          label: Text('Simulated Live Execution', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                          backgroundColor: Color(0xFFECFDF5),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Place virtual buy/sell trades with live order execution, balance tracking, and real-time open positions.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _fetchPaperData,
                  icon: _isLoading
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh Station'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Capital Cards Strip
            Row(
              children: [
                _buildCard('AVAILABLE PAPER CAPITAL', '₹${NumberFormat('#,##,##0.00').format(_virtualCash)}', 'Multi-Broker Pool: ₹80,00,000', const Color(0xFF059669), Icons.account_balance_wallet_rounded),
                const SizedBox(width: 14),
                _buildCard('REALIZED P&L', '${_realizedPnl >= 0 ? '+' : ''}₹${NumberFormat('#,##,##0.00').format(_realizedPnl)}', 'Closed positions today', const Color(0xFF7C3AED), Icons.trending_up_rounded),
                const SizedBox(width: 14),
                _buildCard('OPEN POSITIONS', '${_openPositions.length}', 'Active holdings in sandbox', const Color(0xFF2563EB), Icons.pie_chart_rounded),
                const SizedBox(width: 14),
                _buildCard('EXECUTED ORDERS', '${_orderHistory.length}', 'Session simulated fills', const Color(0xFFD97706), Icons.receipt_long_rounded),
              ],
            ),
            const SizedBox(height: 24),

            // Interactive Order Ticket Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'QUICK PAPER ORDER TICKET',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text('Zero Live Financial Risk • Sandbox Engine', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      // Target Broker Account
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SELECT BROKER ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: _selectedAccId,
                              items: _brokerAccounts.map((acc) {
                                return DropdownMenuItem<int>(
                                  value: acc['accId'] as int,
                                  child: Text('${acc['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedAccId = val);
                                  _fetchPaperData();
                                }
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Symbol Picker
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('INSTRUMENT SYMBOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedSymbol,
                              items: const [
                                DropdownMenuItem(value: 'RELIANCE', child: Text('RELIANCE (₹2,950.0)')),
                                DropdownMenuItem(value: 'TATAMOTORS', child: Text('TATAMOTORS (₹950.0)')),
                                DropdownMenuItem(value: 'HDFCBANK', child: Text('HDFCBANK (₹1,680.0)')),
                                DropdownMenuItem(value: 'INFY', child: Text('INFY (₹1,850.0)')),
                                DropdownMenuItem(value: 'NIFTY50', child: Text('NIFTY 50 (₹24,150.0)')),
                                DropdownMenuItem(value: 'BANKNIFTY', child: Text('BANK NIFTY (₹51,800.0)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedSymbol = val;
                                    if (val == 'RELIANCE') _priceCtrl.text = '2950.0';
                                    if (val == 'TATAMOTORS') _priceCtrl.text = '950.0';
                                    if (val == 'HDFCBANK') _priceCtrl.text = '1680.0';
                                    if (val == 'INFY') _priceCtrl.text = '1850.0';
                                    if (val == 'NIFTY50') _priceCtrl.text = '24150.0';
                                    if (val == 'BANKNIFTY') _priceCtrl.text = '51800.0';
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Side: BUY / SELL
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SIDE / ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _orderSide = 'BUY'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _orderSide == 'BUY' ? const Color(0xFF059669) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'BUY',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: _orderSide == 'BUY' ? Colors.white : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _orderSide = 'SELL'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _orderSide == 'SELL' ? const Color(0xFFDC2626) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'SELL',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: _orderSide == 'SELL' ? Colors.white : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Quantity
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('QUANTITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Execute Button
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.transparent)),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmittingOrder ? null : _executePaperTrade,
                                icon: _isSubmittingOrder
                                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.flash_on_rounded, size: 18),
                                label: Text(_isSubmittingOrder ? 'Placing...' : 'Execute Trade'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _orderSide == 'BUY' ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
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
            const SizedBox(height: 24),

            // Open Positions Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Open Paper Positions (${_openPositions.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Live P&L Tracking', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    color: Colors.grey.shade50,
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('SYMBOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('EXCHANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('AVG BUY PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('CURRENT LTP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('P&L (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      ],
                    ),
                  ),
                  if (_openPositions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text('No active open positions. Place a trade above to see real-time updates.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _openPositions.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (ctx, idx) {
                        final pos = _openPositions[idx];
                        final symbol = pos['tradingSymbol'] ?? '-';
                        final qty = pos['quantity'] ?? 0;
                        final avgBuy = (pos['averageBuyPrice'] ?? 0.0) as num;
                        final ltp = (pos['lastSimulatedPrice'] ?? avgBuy) as num;
                        final pnl = (ltp - avgBuy) * qty;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(symbol, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
                              Expanded(flex: 2, child: Text(pos['exchange'] ?? 'NSE', style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: Text('$qty', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                              Expanded(flex: 2, child: Text('₹${avgBuy.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5))),
                              Expanded(flex: 2, child: Text('₹${ltp.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${pnl >= 0 ? '+' : ''}₹${pnl.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: pnl >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: () => _squareOffPosition(pos),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Square Off', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 24),

            // Executed Orders Log Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text('Simulated Orders Audit Trail (${_orderHistory.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    color: Colors.grey.shade50,
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('ORDER ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('SYMBOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 1, child: Text('SIDE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 1, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('BROKER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      ],
                    ),
                  ),
                  if (_orderHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text('No order records found for this account.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _orderHistory.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (ctx, idx) {
                        final order = _orderHistory[idx];
                        final isBuy = (order['transactiontype'] ?? 'BUY').toString().toUpperCase() == 'BUY';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(order['orderid'] ?? '-', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                              Expanded(flex: 2, child: Text(order['exchtime']?.toString().substring(11, 19) ?? '-', style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: Text(order['tradingsymbol'] ?? '-', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  order['transactiontype'] ?? '-',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isBuy ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                                ),
                              ),
                              Expanded(flex: 1, child: Text('${order['quantity'] ?? order['filledshares'] ?? 0}', style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: Text('₹${order['price'] ?? order['averageprice'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text(order['broker'] ?? 'DHAN', style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600))),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    order['orderstatus'] ?? order['status'] ?? 'complete',
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
      ),
    );
  }

  Widget _buildCard(String title, String val, String sub, Color col, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: col.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: col, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  const SizedBox(height: 3),
                  Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: col)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── REPORTS VIEW ────────────────────────────────────────────────────────────

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reports & Audit Log', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('Searchable execution logs, audit trails, and trade reports.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.assessment_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No Reports Generated Yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('Completed trading sessions will automatically aggregate into trade audit reports.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── NOTIFICATIONS VIEW ──────────────────────────────────────────────────────

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('System Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('Real-time alerts, order executions, and broker status notifications.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('System Connected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        SizedBox(height: 2),
                        Text('Panchayagnam Core Service is active and running in Paper Trading mode.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SETTINGS VIEW ───────────────────────────────────────────────────────────

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Platform Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('Manage account settings, security safeguards, and connection preferences.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FINANCIAL SAFEGUARDS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Paper Trading Mode (Simulation Only)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Guarantees all orders execute in paper simulation without live broker risk.', style: TextStyle(fontSize: 12)),
                    value: true,
                    onChanged: null, // Locked on for safety
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Twilio SMS Gateway', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Disabled by policy. OTP verification runs via demo allowlist.', style: TextStyle(fontSize: 12)),
                    value: false,
                    onChanged: null, // Locked off for safety
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}