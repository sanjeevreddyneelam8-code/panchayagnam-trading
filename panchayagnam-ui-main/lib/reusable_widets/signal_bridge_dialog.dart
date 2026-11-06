import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../service/copy_trading_engine.dart';
import 'copy_trade_receipt_dialog.dart';

class WebhookLogItem {
  final String id;
  final String source;
  final String symbol;
  final String action;
  final int qty;
  final double price;
  final String timestamp;
  final String status;
  final int latencyMs;

  WebhookLogItem({
    required this.id,
    required this.source,
    required this.symbol,
    required this.action,
    required this.qty,
    required this.price,
    required this.timestamp,
    required this.status,
    required this.latencyMs,
  });
}

class SignalBridgeDialog extends StatefulWidget {
  const SignalBridgeDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => const SignalBridgeDialog(),
    );
  }

  @override
  State<SignalBridgeDialog> createState() => _SignalBridgeDialogState();
}

class _SignalBridgeDialogState extends State<SignalBridgeDialog> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final String _webhookUrl = 'https://panchayagnam-api.onrender.com/api/v1/webhook/py-bridge-live-8821';
  final String _secretKey = 'PY_LIVE_SEC_8829';

  // Test Console Fields
  String _testSource = 'TradingView Pine Script';
  String _testAction = 'BUY';
  String _testSymbol = 'NIFTY 24200 CE';
  int _testQty = 50;
  double _testPrice = 135.50;
  bool _isFiring = false;

  final List<WebhookLogItem> _webhookLogs = [
    WebhookLogItem(
      id: 'WH-882910',
      source: 'TradingView Alert',
      symbol: 'NIFTY 24200 CE',
      action: 'BUY',
      qty: 50,
      price: 135.50,
      timestamp: 'Today, 09:25:12 AM',
      status: 'EXECUTED (8 Demats)',
      latencyMs: 14,
    ),
    WebhookLogItem(
      id: 'WH-882894',
      source: 'Chartink Breakout Scan',
      symbol: 'RELIANCE',
      action: 'BUY',
      qty: 25,
      price: 2942.00,
      timestamp: 'Today, 09:20:05 AM',
      status: 'EXECUTED (8 Demats)',
      latencyMs: 12,
    ),
    WebhookLogItem(
      id: 'WH-882850',
      source: 'Python REST API',
      symbol: 'BANKNIFTY 52000 PE',
      action: 'SELL',
      qty: 30,
      price: 184.00,
      timestamp: 'Today, 09:16:40 AM',
      status: 'EXECUTED (8 Demats)',
      latencyMs: 11,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fireTestWebhook() async {
    setState(() => _isFiring = true);
    await Future.delayed(const Duration(milliseconds: 300));

    final engine = CopyTradingEngine();
    final receipt = await engine.replicateTrade(
      symbol: _testSymbol,
      side: _testAction,
      baseQty: _testQty,
      price: _testPrice,
      orderType: 'MARKET',
      productType: 'INTRADAY',
      lotSize: _testSymbol.contains('NIFTY') ? 25 : 1,
    );

    final timeStr = DateFormat('hh:mm:ss a').format(DateTime.now());
    final newLog = WebhookLogItem(
      id: 'WH-${DateTime.now().millisecondsSinceEpoch % 1000000}',
      source: _testSource,
      symbol: _testSymbol,
      action: _testAction,
      qty: _testQty,
      price: _testPrice,
      timestamp: 'Today, $timeStr',
      status: 'EXECUTED (${receipt.totalAccountsFilled} Demats)',
      latencyMs: receipt.avgLatencyMs.round(),
    );

    setState(() {
      _isFiring = false;
      _webhookLogs.insert(0, newLog);
    });

    if (mounted) {
      CopyTradeReceiptDialog.show(context, receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenW > 920 ? (screenW - 880) / 2 : 16,
        vertical: 24,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: screenH * 0.90),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF022C22), Color(0xFF064E3B)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sensors_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'Alert Auto • Signal Bridge & Webhook Hub',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                              SizedBox(width: 8),
                              Badge(
                                label: Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Connect TradingView alerts, Chartink scanners, Amibroker, or Python scripts directly into Panchayagnam.',
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Webhook Endpoint Bar
              Container(
                color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('YOUR DEDICATED WEBHOOK URL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(_webhookUrl, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _copyToClipboard(_webhookUrl, 'Webhook URL'),
                                  child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SECRET AUTH KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(_secretKey, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                ),
                                InkWell(
                                  onTap: () => _copyToClipboard(_secretKey, 'Secret Key'),
                                  child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // TabBar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: const Color(0xFF10B981),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF10B981),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'TradingView Pine Script'),
                    Tab(text: 'Chartink & Scanners'),
                    Tab(text: 'Live Signal Console & Logs'),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildTradingViewTab(),
                    _buildChartinkTab(),
                    _buildTestConsoleTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTradingViewTab() {
    const pineCode = '''// TradingView Alert Message JSON (Paste into Alert > Message)
{
  "secret": "PY_LIVE_SEC_8829",
  "action": "{{strategy.order.action}}",
  "symbol": "{{ticker}}",
  "quantity": {{strategy.order.contracts}},
  "price": {{close}},
  "orderType": "MARKET",
  "product": "MIS"
}''';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to Hook TradingView Alerts into All 8 Broker Accounts:',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          _buildStepRow('1', 'Create an Alert on your TradingView chart (Alt + A).'),
          _buildStepRow('2', 'Under "Notifications", check "Webhook URL" and paste your Dedicated Webhook URL above.'),
          _buildStepRow('3', 'In the "Message" box, paste the exact JSON template below:'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TRADINGVIEW WEBHOOK MESSAGE (JSON)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: () => _copyToClipboard(pineCode, 'TradingView JSON Payload'),
                      child: const Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 14, color: Color(0xFF34D399)),
                          SizedBox(width: 4),
                          Text('Copy JSON', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SelectableText(
                  pineCode,
                  style: TextStyle(color: Color(0xFFE2E8F0), fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Panchayagnam Trade Copier Engine will automatically receive TradingView signals and fan out across Zerodha, Angel One, Dhan, Upstox, etc. in < 25ms!',
                    style: TextStyle(color: Color(0xFF065F46), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartinkTab() {
    const chartinkJson = '''{
  "secret": "PY_LIVE_SEC_8829",
  "action": "BUY",
  "symbol": "RELIANCE",
  "quantity": 25,
  "orderType": "MARKET",
  "product": "MIS"
}''';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chartink Scanner Webhook Configuration:',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          _buildStepRow('1', 'In Chartink Dashboard, create or open your scanner (e.g. 15-min Supertrend Breakout).'),
          _buildStepRow('2', 'Click "Create Alert" and set the Webhook URL to your dedicated endpoint.'),
          _buildStepRow('3', 'Set Payload to JSON:'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CHARTINK ALERT PAYLOAD', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: () => _copyToClipboard(chartinkJson, 'Chartink Payload'),
                      child: const Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 14, color: Color(0xFF34D399)),
                          SizedBox(width: 4),
                          Text('Copy JSON', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SelectableText(
                  chartinkJson,
                  style: TextStyle(color: Color(0xFFE2E8F0), fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestConsoleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Simulator Console
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.play_circle_fill_rounded, color: Color(0xFF059669), size: 18),
                    SizedBox(width: 8),
                    Text('Live Webhook Signal Simulator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Source
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _testSource,
                        decoration: const InputDecoration(labelText: 'Source', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        items: ['TradingView Pine Script', 'Chartink Scanner', 'Python REST API'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) => setState(() => _testSource = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Action
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<String>(
                        value: _testAction,
                        decoration: const InputDecoration(labelText: 'Action', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        items: ['BUY', 'SELL'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: s == 'BUY' ? const Color(0xFF059669) : const Color(0xFFDC2626))))).toList(),
                        onChanged: (v) => setState(() => _testAction = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Symbol
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _testSymbol,
                        decoration: const InputDecoration(labelText: 'Contract / Symbol', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        items: ['NIFTY 24200 CE', 'BANKNIFTY 52000 PE', 'RELIANCE', 'HDFCBANK'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) => setState(() => _testSymbol = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _isFiring ? null : _fireTestWebhook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isFiring
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text('Fire Live Test Webhook Across 8 Demats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Log Stream
          const Text('Recent Incoming Webhook Triggers:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _webhookLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final log = _webhookLogs[idx];
              final isBuy = log.action == 'BUY';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBuy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(log.action, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isBuy ? const Color(0xFF059669) : const Color(0xFFDC2626))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${log.symbol} (${log.qty} Qty @ ₹${log.price.toStringAsFixed(2)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          Text('${log.source} • Ref: ${log.id} • ${log.timestamp}', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(log.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                        ),
                        const SizedBox(height: 2),
                        Text('${log.latencyMs}ms dispatch', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace')),
                      ],
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

  Widget _buildStepRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF059669),
              shape: BoxShape.circle,
            ),
            child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)))),
        ],
      ),
    );
  }
}
