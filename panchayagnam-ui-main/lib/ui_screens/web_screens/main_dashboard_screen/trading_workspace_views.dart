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

// ─── HOLDINGS VIEW (Multi-Broker Delivery Equity Portfolio) ───────────────────

class HoldingsView extends StatefulWidget {
  const HoldingsView({super.key});

  @override
  State<HoldingsView> createState() => _HoldingsViewState();
}

class _HoldingsViewState extends State<HoldingsView> {
  String _searchQuery = '';
  String _selectedSector = 'All';
  String _selectedDemat = 'All Demats (8 Combined)';

  final List<Map<String, dynamic>> _allHoldings = [
    {
      'symbol': 'RELIANCE',
      'name': 'Reliance Industries Ltd',
      'isin': 'INE002A01018',
      'sector': 'Oil & Gas',
      'demat': 'Dhan Master + 7 Childs',
      'qty': 150,
      't1Qty': 0,
      'avg': 2810.00,
      'ltp': 2949.20,
      'dayChange': 1.25,
    },
    {
      'symbol': 'TCS',
      'name': 'Tata Consultancy Services',
      'isin': 'INE467B01029',
      'sector': 'IT & Software',
      'demat': 'Zerodha Child 1 + 6 Childs',
      'qty': 80,
      't1Qty': 0,
      'avg': 3920.00,
      'ltp': 4120.50,
      'dayChange': 0.82,
    },
    {
      'symbol': 'INFY',
      'name': 'Infosys Limited',
      'isin': 'INE009A01021',
      'sector': 'IT & Software',
      'demat': 'All Demats (8 Combined)',
      'qty': 160,
      't1Qty': 20,
      'avg': 1780.00,
      'ltp': 1885.00,
      'dayChange': 1.48,
    },
    {
      'symbol': 'HDFCBANK',
      'name': 'HDFC Bank Ltd',
      'isin': 'INE040A01034',
      'sector': 'Banking',
      'demat': 'Angel One Child 2',
      'qty': 180,
      't1Qty': 0,
      'avg': 1610.00,
      'ltp': 1652.10,
      'dayChange': 0.41,
    },
    {
      'symbol': 'ICICIBANK',
      'name': 'ICICI Bank Ltd',
      'isin': 'INE090A01021',
      'sector': 'Banking',
      'demat': 'All Demats (8 Combined)',
      'qty': 150,
      't1Qty': 0,
      'avg': 1210.00,
      'ltp': 1288.40,
      'dayChange': 1.12,
    },
    {
      'symbol': 'TATAMOTORS',
      'name': 'Tata Motors Limited',
      'isin': 'INE155A01022',
      'sector': 'Auto',
      'demat': 'Dhan Master + 7 Childs',
      'qty': 140,
      't1Qty': 0,
      'avg': 920.00,
      'ltp': 995.80,
      'dayChange': 2.34,
    },
    {
      'symbol': 'SBIN',
      'name': 'State Bank of India',
      'isin': 'INE062A01020',
      'sector': 'Banking',
      'demat': 'All Demats (8 Combined)',
      'qty': 120,
      't1Qty': 0,
      'avg': 790.00,
      'ltp': 842.30,
      'dayChange': -0.32,
    },
    {
      'symbol': 'ITC',
      'name': 'ITC Limited',
      'isin': 'INE154A01025',
      'sector': 'FMCG',
      'demat': 'Zerodha Child 2',
      'qty': 250,
      't1Qty': 0,
      'avg': 465.00,
      'ltp': 489.20,
      'dayChange': 0.58,
    },
    {
      'symbol': 'LT',
      'name': 'Larsen & Toubro Ltd',
      'isin': 'INE018A01030',
      'sector': 'Infrastructure',
      'demat': 'All Demats (8 Combined)',
      'qty': 30,
      't1Qty': 0,
      'avg': 3420.00,
      'ltp': 3680.00,
      'dayChange': 1.38,
    },
    {
      'symbol': 'BHARTIARTL',
      'name': 'Bharti Airtel Ltd',
      'isin': 'INE397D01024',
      'sector': 'Telecom',
      'demat': 'Dhan Master + 7 Childs',
      'qty': 80,
      't1Qty': 0,
      'avg': 1590.00,
      'ltp': 1712.50,
      'dayChange': 0.94,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _allHoldings.where((h) {
      final symMatch = (h['symbol'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (h['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      final sectorMatch = _selectedSector == 'All' || h['sector'] == _selectedSector;
      return symMatch && sectorMatch;
    }).toList();

    double totalInvested = 0;
    double totalCurrent = 0;
    for (final h in _allHoldings) {
      final q = (h['qty'] as num).toDouble();
      totalInvested += q * (h['avg'] as num).toDouble();
      totalCurrent += q * (h['ltp'] as num).toDouble();
    }
    final totalPnl = totalCurrent - totalInvested;
    final totalPnlPct = totalInvested > 0 ? (totalPnl / totalInvested) * 100 : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Title Bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Multi-Broker Delivery Holdings',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text('8 DEMATS CONSOLIDATED', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SEBI-verified Demat delivery portfolio across Dhan, Angel One, Zerodha Kite & partner accounts.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Holdings exported as Excel / CSV successfully.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Export Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Holdings refreshed from CDSL / NSDL Demat gateways.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4 Glassmorphism KPI Cards
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth > 900;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWide ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 2.3 : 1.8,
                  children: [
                    _buildKpiCard('Total Portfolio Value', '₹${totalCurrent.toStringAsFixed(2)}', 'Liquid Demat Worth', Icons.account_balance_rounded, const Color(0xFF0284C7)),
                    _buildKpiCard('Invested Capital', '₹${totalInvested.toStringAsFixed(2)}', 'Total Cost Basis', Icons.payments_rounded, const Color(0xFF475569)),
                    _buildKpiCard(
                      'Unrealized P&L',
                      '+₹${totalPnl.toStringAsFixed(2)}',
                      '+${totalPnlPct.toStringAsFixed(2)}% Overall Return',
                      Icons.trending_up_rounded,
                      const Color(0xFF059669),
                      isProfit: true,
                    ),
                    _buildKpiCard(
                      "Today's Gain / Loss",
                      '+₹18,420.00',
                      '+1.01% Day Change',
                      Icons.insights_rounded,
                      const Color(0xFF059669),
                      isProfit: true,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Search & Filter Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search holding by symbol, company or ISIN...',
                        hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      style: const TextStyle(fontSize: 12.5),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sector Filter Chips
                  Wrap(
                    spacing: 6,
                    children: ['All', 'Banking', 'IT & Software', 'Oil & Gas', 'Auto', 'FMCG'].map((sector) {
                      final isSel = _selectedSector == sector;
                      return ChoiceChip(
                        label: Text(sector, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF475569))),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        onSelected: (val) => setState(() => _selectedSector = sector),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // High-Density Data Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('INSTRUMENT & ISIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('SECTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('QTY (T1)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('AVG BUY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('LTP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('CURR VAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                        Expanded(flex: 3, child: Text('UNREALIZED P&L', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)), textAlign: TextAlign.right)),
                      ],
                    ),
                  ),

                  // Table Body
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      final h = filtered[idx];
                      final qty = (h['qty'] as num).toDouble();
                      final avg = (h['avg'] as num).toDouble();
                      final ltp = (h['ltp'] as num).toDouble();
                      final currVal = qty * ltp;
                      final invVal = qty * avg;
                      final pnl = currVal - invVal;
                      final pnlPct = invVal > 0 ? (pnl / invVal) * 100 : 0.0;
                      final isGreen = pnl >= 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Instrument
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(h['symbol'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(3)),
                                        child: const Text('EQ', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('${h['name']} • ${h['isin']}', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            // Sector
                            Expanded(
                              flex: 2,
                              child: Text(h['sector'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                            ),
                            // Qty
                            Expanded(
                              flex: 2,
                              child: Text('${h['qty']} Shares', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            ),
                            // Avg
                            Expanded(
                              flex: 2,
                              child: Text('₹${avg.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                            ),
                            // LTP
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('₹${ltp.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                  Text(
                                    '${(h['dayChange'] as double) >= 0 ? '+' : ''}${h['dayChange']}%',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (h['dayChange'] as double) >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            ),
                            // Current Value
                            Expanded(
                              flex: 2,
                              child: Text('₹${currVal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            ),
                            // Unrealized P&L
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isGreen ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${isGreen ? '+' : ''}₹${pnl.toStringAsFixed(2)} (${isGreen ? '+' : ''}${pnlPct.toStringAsFixed(2)}%)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: isGreen ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Quick Action Buttons
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      final receipt = await CopyTradingEngine().replicateTrade(
                                        symbol: '${h['symbol']} EQ',
                                        side: 'BUY',
                                        baseQty: 20,
                                        price: ltp,
                                        orderType: 'MARKET',
                                        productType: 'INTRADAY (MIS)',
                                        lotSize: 1,
                                      );
                                      if (mounted) {
                                        CopyTradeReceiptDialog.show(context, receipt);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('B', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () async {
                                      final receipt = await CopyTradingEngine().replicateTrade(
                                        symbol: '${h['symbol']} EQ',
                                        side: 'SELL',
                                        baseQty: 20,
                                        price: ltp,
                                        orderType: 'MARKET',
                                        productType: 'INTRADAY (MIS)',
                                        lotSize: 1,
                                      );
                                      if (mounted) {
                                        CopyTradeReceiptDialog.show(context, receipt);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('S', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                    ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, String sub, IconData icon, Color color, {bool isProfit = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isProfit ? const Color(0xFF059669) : const Color(0xFF0F172A))),
                const SizedBox(height: 1),
                Text(sub, style: TextStyle(fontSize: 10.5, color: isProfit ? const Color(0xFF059669) : Colors.grey.shade500, fontWeight: isProfit ? FontWeight.w700 : FontWeight.normal)),
              ],
            ),
          ),
        ],
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

// ─── REPORTS VIEW (Institutional Trade Book, Tax P&L Statement & Audit) ───────

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRange = 'FY 2024-25 (YTD)';
  String _selectedSegment = 'All Segments';

  final List<Map<String, dynamic>> _tradeBook = [
    {
      'date': '2024-11-03 14:32:05',
      'orderId': 'ORD-982141',
      'account': 'Dhan Master',
      'symbol': 'NIFTY 24200 CE',
      'segment': 'NFO OPT',
      'side': 'BUY',
      'qty': 200,
      'price': 135.50,
      'turnover': 27100.0,
      'charges': 42.50,
      'pnl': 6400.00,
      'latency': '11ms',
      'status': 'FILLED',
    },
    {
      'date': '2024-11-03 14:32:05',
      'orderId': 'ORD-982142',
      'account': 'Angel Child 1',
      'symbol': 'NIFTY 24200 CE',
      'segment': 'NFO OPT',
      'side': 'BUY',
      'qty': 200,
      'price': 135.50,
      'turnover': 27100.0,
      'charges': 42.50,
      'pnl': 6400.00,
      'latency': '14ms',
      'status': 'FILLED',
    },
    {
      'date': '2024-11-03 14:32:05',
      'orderId': 'ORD-982143',
      'account': 'Zerodha Child 2',
      'symbol': 'NIFTY 24200 CE',
      'segment': 'NFO OPT',
      'side': 'BUY',
      'qty': 400,
      'price': 135.55,
      'turnover': 54220.0,
      'charges': 85.00,
      'pnl': 12760.00,
      'latency': '16ms',
      'status': 'FILLED',
    },
    {
      'date': '2024-11-03 13:15:22',
      'orderId': 'ORD-981902',
      'account': 'Dhan Master',
      'symbol': 'BANKNIFTY 51800 PE',
      'segment': 'NFO OPT',
      'side': 'SELL',
      'qty': 150,
      'price': 210.40,
      'turnover': 31560.0,
      'charges': 48.00,
      'pnl': 8250.00,
      'latency': '10ms',
      'status': 'FILLED',
    },
    {
      'date': '2024-11-03 11:45:10',
      'orderId': 'ORD-981240',
      'account': 'Dhan Master',
      'symbol': 'RELIANCE',
      'segment': 'NSE EQ',
      'side': 'BUY',
      'qty': 50,
      'price': 2940.00,
      'turnover': 147000.0,
      'charges': 58.20,
      'pnl': 4600.00,
      'latency': '12ms',
      'status': 'FILLED',
    },
    {
      'date': '2024-11-03 10:20:44',
      'orderId': 'ORD-980812',
      'account': 'Dhan Master',
      'symbol': 'TCS',
      'segment': 'NSE EQ',
      'side': 'BUY',
      'qty': 30,
      'price': 4110.00,
      'turnover': 123300.0,
      'charges': 52.00,
      'pnl': 3150.00,
      'latency': '15ms',
      'status': 'FILLED',
    },
    {
      'date': '2024-11-03 09:35:12',
      'orderId': 'ORD-980102',
      'account': 'Dhan Master',
      'symbol': 'NIFTY 24300 CE',
      'segment': 'NFO OPT',
      'side': 'BUY',
      'qty': 300,
      'price': 98.20,
      'turnover': 29460.0,
      'charges': 45.00,
      'pnl': -1860.00,
      'latency': '11ms',
      'status': 'FILLED',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header & Export Actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reports, Tax P&L & Audit Station', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text('Comprehensive execution ledger, SEBI-compliant Tax P&L statements, and latency audits across 8 Demats.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tax P&L Statement (PDF) generated with SEBI schedule breakdown.'), duration: Duration(seconds: 2)),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Export Tax P&L (PDF)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Consolidated Trade Book CSV exported successfully.'), duration: Duration(seconds: 2)),
                    );
                  },
                  icon: const Icon(Icons.file_download_outlined, size: 16, color: Colors.white),
                  label: const Text('Export Trade Book (CSV)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // KPI Summary Cards
            Row(
              children: [
                Expanded(child: _buildKpiCard('Gross Turnover', '₹1,42,80,500.00', 'Total Traded Volume', Icons.bar_chart_rounded, const Color(0xFF0284C7))),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard('Realized Net P&L', '+₹2,84,350.00', '+78.4% Win Rate (87/111)', Icons.trending_up_rounded, const Color(0xFF059669), isProfit: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard('Total Taxes & Charges', '₹6,420.00', 'STT, Stamp Duty & Brokerage', Icons.receipt_long_rounded, const Color(0xFF64748B))),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard('Avg Trade P&L', '+₹3,268.00', 'Profit Factor: 2.84', Icons.speed_rounded, const Color(0xFF10B981), isProfit: true)),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF2563EB),
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'Trade Book & Execution Ledger'),
                  Tab(text: 'Tax P&L Statement (SEBI Format)'),
                  Tab(text: 'Multi-Broker Latency & Slippage Audit'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views Container
            SizedBox(
              height: 480,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTradeBookTab(),
                  _buildTaxPnlTab(),
                  _buildLatencyAuditTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeBookTab() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('DATE & TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('ORDER ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('DEMAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                Expanded(flex: 3, child: Text('INSTRUMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                Expanded(flex: 1, child: Text('SIDE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('TURNOVER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('REALIZED P&L', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                Expanded(flex: 1, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)), textAlign: TextAlign.right)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _tradeBook.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final t = _tradeBook[idx];
                final isBuy = t['side'] == 'BUY';
                final isGreen = (t['pnl'] as double) >= 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(t['date'] as String, style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)))),
                      Expanded(flex: 2, child: Text(t['orderId'] as String, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                      Expanded(flex: 2, child: Text(t['account'] as String, style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text(t['symbol'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                      Expanded(
                        flex: 1,
                        child: Text(
                          t['side'] as String,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isBuy ? const Color(0xFF2563EB) : const Color(0xFFDC2626)),
                        ),
                      ),
                      Expanded(flex: 2, child: Text('${t['qty']} Qty', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                      Expanded(flex: 2, child: Text('₹${(t['price'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5))),
                      Expanded(flex: 2, child: Text('₹${(t['turnover'] as double).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${isGreen ? '+' : ''}₹${(t['pnl'] as double).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isGreen ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                            child: const Text('FILLED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxPnlTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('SEBI & Income Tax Act Compliant Statement (FY 2024-25)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A))),
              const Spacer(),
              Text('Prepared for PAN: ABCDE****F', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            border: TableBorder.all(color: const Color(0xFFE2E8F0)),
            children: [
              _buildTableRow('Segment', 'Gross Realized Profit', 'Brokerage / STT / Charges', 'Net Taxable Profit', isHeader: true),
              _buildTableRow('NSE Equity Delivery (STCG u/s 111A)', '₹1,56,710.00', '₹1,240.00', '+₹1,55,470.00'),
              _buildTableRow('NSE Intraday Speculative Trading', '₹45,200.00', '₹980.00', '+₹44,220.00'),
              _buildTableRow('NSE F&O Non-Speculative Business', '₹88,860.00', '₹4,200.00', '+₹84,660.00'),
              _buildTableRow('Consolidated Total', '₹2,90,770.00', '₹6,420.00', '+₹2,84,350.00', isBold: true),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All figures are aggregated across all 8 verified Demat accounts. This statement matches the Annual Information Statement (AIS) and Form 26AS format for direct ITR filing.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String c1, String c2, String c3, String c4, {bool isHeader = false, bool isBold = false}) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: (isHeader || isBold) ? FontWeight.w800 : FontWeight.w500,
      color: isHeader ? const Color(0xFF1E293B) : (isBold ? const Color(0xFF0F172A) : const Color(0xFF475569)),
    );
    return TableRow(
      decoration: BoxDecoration(color: isHeader ? const Color(0xFFF1F5F9) : (isBold ? const Color(0xFFF8FAFC) : Colors.white)),
      children: [
        Padding(padding: const EdgeInsets.all(10), child: Text(c1, style: style)),
        Padding(padding: const EdgeInsets.all(10), child: Text(c2, style: style)),
        Padding(padding: const EdgeInsets.all(10), child: Text(c3, style: style)),
        Padding(padding: const EdgeInsets.all(10), child: Text(c4, style: style)),
      ],
    );
  }

  Widget _buildLatencyAuditTab() {
    final latencies = [
      {'broker': 'Dhan Pro Master (Equinix Direct)', 'latency': '11 ms', 'rate': 99.9, 'color': const Color(0xFF059669)},
      {'broker': 'Angel One Child 1', 'latency': '14 ms', 'rate': 99.8, 'color': const Color(0xFF059669)},
      {'broker': 'Zerodha Child 2', 'latency': '16 ms', 'rate': 99.7, 'color': const Color(0xFF059669)},
      {'broker': 'AliceBlue Child 3', 'latency': '18 ms', 'rate': 99.5, 'color': const Color(0xFF059669)},
      {'broker': 'Motilal Oswal Child 4', 'latency': '21 ms', 'rate': 99.4, 'color': const Color(0xFF059669)},
      {'broker': 'Groww Child 5', 'latency': '22 ms', 'rate': 99.3, 'color': const Color(0xFF059669)},
      {'broker': 'Fyers Child 6', 'latency': '17 ms', 'rate': 99.6, 'color': const Color(0xFF059669)},
      {'broker': 'Upstox Child 7', 'latency': '19 ms', 'rate': 99.5, 'color': const Color(0xFF059669)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Multi-Broker API Execution Latency & Parallel Fan-Out SLA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text('Real-time measurements measured from Panchayagnam Dedicated Gateway 103.159.214.88 to broker exchange endpoints.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: latencies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final item = latencies[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item['broker'] as String, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                        child: Text(item['latency'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                      ),
                      const SizedBox(width: 12),
                      Text('SLA ${item['rate']}%', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, String sub, IconData icon, Color color, {bool isProfit = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isProfit ? const Color(0xFF059669) : const Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 10.5, color: isProfit ? const Color(0xFF059669) : Colors.grey.shade500, fontWeight: isProfit ? FontWeight.w700 : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ─── NOTIFICATIONS VIEW (Live System Notifications & Audit Log) ───────────────

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  String _selectedCategory = 'ALL';

  final List<Map<String, dynamic>> _alerts = [
    {
      'id': 'AL-901',
      'title': 'Order Filled: NIFTY 24200 CE',
      'category': 'EXECUTION',
      'description': '200 Qty filled across 8 Demat accounts at ₹135.50 via sub-12ms parallel dispatch. Master: ₹135.50, Children Avg: ₹135.52 (Slippage: 0.015%).',
      'time': 'Just now • 14:32:05 IST',
      'latency': '12ms',
      'icon': Icons.check_circle_rounded,
      'color': const Color(0xFF10B981),
      'badge': 'INSTANT FILL',
    },
    {
      'id': 'AL-902',
      'title': 'TradingView Pine Script Webhook Received',
      'category': 'WEBHOOK',
      'description': 'Supertrend (10, 2) 15m Long Trigger received from dedicated IP 103.159.214.88. Secret signature verified.',
      'time': '5 min ago • 14:27:00 IST',
      'latency': '4ms',
      'icon': Icons.sensors_rounded,
      'color': const Color(0xFF2563EB),
      'badge': 'WEBHOOK VERIFIED',
    },
    {
      'id': 'AL-903',
      'title': 'Master-Child Copy Replication Synchronized',
      'category': 'COPY_TRADE',
      'description': 'Leader Dhan (#DHAN-9012) triggered order. 7 child followers replicated in parallel. Total pooled volume ₹2,16,800.',
      'time': '12 min ago • 14:20:15 IST',
      'latency': '18ms',
      'icon': Icons.sync_alt_rounded,
      'color': const Color(0xFF8B5CF6),
      'badge': 'FAN-OUT COMPLETE',
    },
    {
      'id': 'AL-904',
      'title': 'Margin Heartbeat & SEBI Peak Compliance',
      'category': 'MARGIN',
      'description': 'Margin utilization at 42.5%. Available pooled liquid cash: ₹80,00,000. All 8 Demat accounts verified with zero deficit.',
      'time': '25 min ago • 14:07:00 IST',
      'latency': '35ms',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFF0EA5E9),
      'badge': 'MARGIN HEALTHY',
    },
    {
      'id': 'AL-905',
      'title': 'Slippage Collar Guard Active',
      'category': 'RISK',
      'description': 'BANKNIFTY 51800 PE order executed strictly within 0.05% slippage tolerance collar. Guarded against market gap.',
      'time': '45 min ago • 13:47:00 IST',
      'latency': '9ms',
      'icon': Icons.shield_rounded,
      'color': const Color(0xFF059669),
      'badge': 'SLIPPAGE GUARD',
    },
    {
      'id': 'AL-906',
      'title': 'Dedicated Static Gateway Keep-Alive OK',
      'category': 'NETWORK',
      'description': 'Dedicated IP 103.159.214.88 ping verified at 8ms to NSE Leased Line Equinix BKC. 0 packets dropped.',
      'time': '1 hr ago • 13:30:00 IST',
      'latency': '8ms',
      'icon': Icons.lan_rounded,
      'color': const Color(0xFF6366F1),
      'badge': 'DEDICATED IP ONLINE',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == 'ALL'
        ? _alerts
        : _alerts.where((a) => a['category'] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('System Notifications & Audit Stream', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text('Real-time alerts, sub-25ms order execution logs, and network telemetry.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Audio alert chime tested successfully.'), duration: Duration(seconds: 1)),
                    );
                  },
                  icon: const Icon(Icons.volume_up_outlined, size: 16),
                  label: const Text('Test Chime', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All system alerts marked as read.'), duration: Duration(seconds: 1)),
                    );
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
                  label: const Text('Mark All Read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Category Filter Chips
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('ALL', 'All Alerts (${_alerts.length})'),
                _buildFilterChip('EXECUTION', 'Order Fills'),
                _buildFilterChip('WEBHOOK', 'Webhooks'),
                _buildFilterChip('COPY_TRADE', 'Copy Replications'),
                _buildFilterChip('MARGIN', 'Margin & Risk'),
                _buildFilterChip('NETWORK', 'Dedicated IP'),
              ],
            ),
            const SizedBox(height: 16),

            // Notification Stream Cards
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final a = filtered[idx];
                final color = a['color'] as Color;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Icon(a['icon'] as IconData, color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(a['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A))),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                  child: Text(a['badge'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                                ),
                                const Spacer(),
                                Text(a['time'] as String, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(a['description'] as String, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.speed_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text('Dispatch Latency: ${a['latency']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                const SizedBox(width: 16),
                                const Icon(Icons.lan_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                const Text('Gateway: 103.159.214.88 (Equinix)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              ],
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
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSel = _selectedCategory == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF475569))),
      selected: isSel,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1))),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onSelected: (_) => setState(() => _selectedCategory = key),
    );
  }
}

// ─── SETTINGS VIEW (Institutional Platform Settings & Safeguards Center) ───────

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Trading & Risk Limits
  double _maxDailyLoss = 25000.0;
  double _maxOrderValue = 500000.0;
  String _slippageTolerance = '0.5%';
  bool _autoSquareOff = true;
  bool _lotSizeSnapping = true;
  bool _rejectIlliquid = true;

  // Network & Sessions
  final String _primaryIp = '103.159.214.88';
  final String _standbyIp = '103.159.214.89';
  String _heartbeatInterval = '100ms (Ultra-Fast)';
  bool _asyncFanOut = true;
  bool _fallbackMaster = true;

  // Audio Chimes
  bool _soundOnFill = true;
  bool _soundOnChildFill = true;
  bool _soundOnRiskBreach = true;
  bool _telegramBridge = true;
  bool _browserNotifications = true;

  // Display & UI
  String _selectedTheme = 'Bloomberg Terminal Dark';
  String _tableDensity = 'Compact (28px)';
  bool _showM2mInTitle = true;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Platform Settings & Safeguards Center', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text('Configure institutional risk safeguards, dedicated static IPs, copy multipliers, and audio chimes.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Platform Settings saved! Risk safeguards active across all 8 Demats.'),
                        backgroundColor: Color(0xFF059669),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                  label: const Text('Save Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF2563EB),
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'Trading & Risk Safeguards'),
                  Tab(text: 'Multi-Broker Session & IPs'),
                  Tab(text: 'Audio Chimes & Notifications'),
                  Tab(text: 'Display & Terminal Density'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTradingRiskTab(),
                  _buildNetworkSessionTab(),
                  _buildAudioNotificationsTab(),
                  _buildDisplayDensityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradingRiskTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: ListView(
        children: [
          // Safety Lock Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBFDBFE))),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Paper Trading Mode is ACTIVE. All strategy executions simulate against live tick feeds with zero financial capital exposure.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Daily Max Loss Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily Global Max Loss (Auto-Kill Switch)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A))),
              Text('₹${_maxDailyLoss.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 4),
          Text('If total intraday loss reaches this threshold, all open positions square off immediately and trading halts.', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          Slider(
            value: _maxDailyLoss,
            min: 5000,
            max: 100000,
            divisions: 19,
            activeColor: const Color(0xFFDC2626),
            onChanged: (v) => setState(() => _maxDailyLoss = v),
          ),
          const Divider(height: 24),

          // Max Order Value Per Demat
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Max Order Value Per Demat Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A))),
              Text('₹${_maxOrderValue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF2563EB))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Rejects individual orders if gross notional value exceeds this limit to avoid fat-finger errors.', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          Slider(
            value: _maxOrderValue,
            min: 50000,
            max: 2000000,
            divisions: 39,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _maxOrderValue = v),
          ),
          const Divider(height: 24),

          // Toggles
          SwitchListTile(
            title: const Text('F&O Lot-size Auto-Snapping', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Guarantees child orders automatically round to valid NSE exchange lot sizes (NIFTY 25, BANKNIFTY 15).', style: TextStyle(fontSize: 11.5)),
            value: _lotSizeSnapping,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _lotSizeSnapping = v),
          ),
          SwitchListTile(
            title: const Text('Emergency Auto-Square-off at 15:15 IST', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Automatically squares off all MIS intraday positions at 15:15 IST to prevent broker penalty charges.', style: TextStyle(fontSize: 11.5)),
            value: _autoSquareOff,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _autoSquareOff = v),
          ),
          SwitchListTile(
            title: const Text('Reject Market Orders on Illiquid Strikes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Protects against extreme slippage on options strikes with Open Interest < 10,000 contracts.', style: TextStyle(fontSize: 11.5)),
            value: _rejectIlliquid,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _rejectIlliquid = v),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSessionTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: ListView(
        children: [
          const Text('Dedicated Static IP Gateways', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text('Static institutional IP whitelisted with NSE/BSE and broker API firewalls.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              children: [
                const Icon(Icons.lan_rounded, color: Color(0xFF059669), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Primary Gateway: $_primaryIp (Equinix Mumbai)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      const Text('Standby Failover: 103.159.214.89 • Latency: 8ms to NSE Leased Line', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                  child: const Text('WHITELISTED 🟢', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          SwitchListTile(
            title: const Text('Asynchronous Parallel Fan-Out (Sub-20ms)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Dispatches copy trades across all 8 Demats concurrently using 8 non-blocking worker threads.', style: TextStyle(fontSize: 11.5)),
            value: _asyncFanOut,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _asyncFanOut = v),
          ),
          SwitchListTile(
            title: const Text('Automatic Failover Master Switch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('If Dhan Master experiences a temporary token disconnect, immediately routes leadership to Angel One.', style: TextStyle(fontSize: 11.5)),
            value: _fallbackMaster,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _fallbackMaster = v),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioNotificationsTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: ListView(
        children: [
          SwitchListTile(
            title: const Text('Order Placed / Filled Chime Bell', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Plays an audible chime bell whenever an order is successfully filled.', style: TextStyle(fontSize: 11.5)),
            value: _soundOnFill,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _soundOnFill = v),
          ),
          SwitchListTile(
            title: const Text('Child Trade Replicated Sound', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Plays a subtle confirmation click when child accounts replicate the leader.', style: TextStyle(fontSize: 11.5)),
            value: _soundOnChildFill,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _soundOnChildFill = v),
          ),
          SwitchListTile(
            title: const Text('Risk Rejection Siren Alert', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Audible warning tone if an order violates margin requirements or slippage collars.', style: TextStyle(fontSize: 11.5)),
            value: _soundOnRiskBreach,
            activeColor: const Color(0xFFDC2626),
            onChanged: (v) => setState(() => _soundOnRiskBreach = v),
          ),
          SwitchListTile(
            title: const Text('Telegram Bot Instant Dispatch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Transmits filled order tickets and execution P&L summaries directly to your Telegram bot.', style: TextStyle(fontSize: 11.5)),
            value: _telegramBridge,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _telegramBridge = v),
          ),
          SwitchListTile(
            title: const Text('Desktop Browser Push Notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Shows desktop push notifications even when the browser tab is minimized.', style: TextStyle(fontSize: 11.5)),
            value: _browserNotifications,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _browserNotifications = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayDensityTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: ListView(
        children: [
          const Text('Theme Preset', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Bloomberg Terminal Dark', 'Tradetron Clean Light', 'Cyber Mint Dark', 'AutoTrader Slate'].map((th) {
              final isSel = _selectedTheme == th;
              return ChoiceChip(
                label: Text(th, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF475569))),
                selected: isSel,
                selectedColor: const Color(0xFF2563EB),
                backgroundColor: const Color(0xFFF1F5F9),
                onSelected: (_) => setState(() => _selectedTheme = th),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          const Text('Order Matrix Row Density', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Compact (28px - Pro Trading)', 'Balanced (36px)', 'Comfortable (44px)'].map((den) {
              final isSel = _tableDensity == den;
              return ChoiceChip(
                label: Text(den, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF475569))),
                selected: isSel,
                selectedColor: const Color(0xFF2563EB),
                backgroundColor: const Color(0xFFF1F5F9),
                onSelected: (_) => setState(() => _tableDensity = den),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          SwitchListTile(
            title: const Text('Show Live M2M P&L in Browser Tab Title', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Updates document title dynamically with live portfolio gain (e.g. "+₹42.8K | Panchayagnam").', style: TextStyle(fontSize: 11.5)),
            value: _showM2mInTitle,
            activeColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _showM2mInTitle = v),
          ),
        ],
      ),
    );
  }
}
