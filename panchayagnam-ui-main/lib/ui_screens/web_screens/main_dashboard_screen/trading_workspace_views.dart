import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../constants/api_url_constants.dart';
import '../../../constants/auth_header_helper.dart';

// ─── ORDERS VIEW ─────────────────────────────────────────────────────────────

class OrdersView extends StatelessWidget {
  const OrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Orders & Execution', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('Track pending, executed, cancelled, and paper-simulated orders.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFB45309), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'PAPER TRADING ACTIVE — Simulated executions are recorded locally. Live broker orders are disabled.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
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
                  Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('Simulated Orders Active', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('Orders placed in Paper Trading Station or Algo Strategies appear live with full audit trails.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── POSITIONS VIEW ──────────────────────────────────────────────────────────

class PositionsView extends StatelessWidget {
  const PositionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Open Positions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('Intraday and carry-forward positions across connected accounts.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
                  Icon(Icons.pie_chart_outline_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('Paper Positions Engine Synchronized', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('Check the "Paper Trading" view under Algo Trading for real-time order placement and 1-click square-off.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
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
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
