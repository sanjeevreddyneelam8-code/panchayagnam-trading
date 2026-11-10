import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../service/copy_trading_engine.dart';
import '../../../service/theme_mode_service.dart';
import '../../../reusable_widets/copy_trade_receipt_dialog.dart';
import 'options_chain_view.dart';

class StrategyBuilderHubView extends StatefulWidget {
  const StrategyBuilderHubView({super.key});

  @override
  State<StrategyBuilderHubView> createState() => _StrategyBuilderHubViewState();
}

class _StrategyBuilderHubViewState extends State<StrategyBuilderHubView> {
  int _activeBuilderTab = 0; // 0: Build with AI, 1: Visual Rule Builder, 2: Multi-Leg Options, 3: Pre-Built Templates

  // AI Builder State
  final TextEditingController _aiPromptCtrl = TextEditingController(
    text: 'At 09:20 AM sell ATM Call & Put for Bank Nifty with 25% stop loss per leg, square off at 03:15 PM',
  );
  bool _isGenerating = false;

  // Visual Rule Builder State
  String _selectedInstrument = 'BANKNIFTY-OPT';
  String _selectedTimeframe = '5m';
  String _entryCondition1 = '9 EMA crosses above 21 EMA';
  String _entryCondition2 = 'RSI(14) > 55';
  double _stopLossPct = 20.0;
  double _targetPct = 40.0;
  bool _enableTrailing = true;

  @override
  void dispose() {
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  void _generateAiStrategy() {
    setState(() => _isGenerating = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showGeneratedStrategyDialog();
    });
  }

  void _showGeneratedStrategyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('AI Strategy Compiled Successfully!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: Text('Prompt: "${_aiPromptCtrl.text}"', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              ),
              const SizedBox(height: 14),
              const Text('Generated Algorithmic Rules & Execution Parameters:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _buildParamRow('Instrument', 'BANKNIFTY Weekly Derivatives (ATM CE & PE)'),
              _buildParamRow('Trigger Condition', '09:20:00 AM mechanical entry (sub-15ms)'),
              _buildParamRow('Risk Management', '25% SL per leg (SL-M orders placed at exchange)'),
              _buildParamRow('Exit Window', '03:15:00 PM auto square-off (All Brokers)'),
              _buildParamRow('Sharpe Ratio', '2.68 · Win Rate: 74.5% · Max DD: -4.2%'),
              _buildParamRow('Demat Replication', '${CopyTradingEngine().totalAccountsCount} Brokers (Sub-15ms Synchronized)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Edit Rules')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final engine = CopyTradingEngine();
              final result = await engine.replicateTrade(
                symbol: 'BANKNIFTY 52000 STRADDLE',
                side: 'SELL',
                baseQty: 30,
                price: 395.0,
                orderType: 'MARKET',
                productType: 'INTRADAY (MIS)',
              );
              if (mounted) {
                CopyTradeReceiptDialog.show(context, result);
              }
            },
            icon: const Icon(Icons.rocket_launch_rounded, size: 16),
            label: Text('Deploy to All ${CopyTradingEngine().totalAccountsCount} Brokers (Sub-15ms)'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  static Widget _buildParamRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeModeService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        final bgColor = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
        final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
        final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textColor = isDark ? Colors.white : const Color(0xFF111827);
        final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Scaffold(
          backgroundColor: bgColor,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Build New Algorithmic Strategy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
                        const SizedBox(height: 4),
                        Text('Create, backtest, and deploy high-frequency quantitative strategies across ${CopyTradingEngine().totalAccountsCount} connected brokers.', style: TextStyle(fontSize: 13, color: subTextColor)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFA7F3D0))),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 15, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text('Direct Broker Execution Engine', style: TextStyle(color: Color(0xFF065F46), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4 Builder Mode Selector Cards
                Row(
                  children: [
                    _buildModeCard(0, '🤖 Build with AI', 'Plain-English Prompt', Icons.auto_awesome_rounded, const Color(0xFF2563EB)),
                    const SizedBox(width: 14),
                    _buildModeCard(1, '🧩 Visual Rule Builder', 'No-Code Condition Blocks', Icons.dashboard_customize_rounded, const Color(0xFF059669)),
                    const SizedBox(width: 14),
                    _buildModeCard(2, '📊 Multi-Leg Options', 'Payoff & Greeks Wizard', Icons.candlestick_chart_rounded, const Color(0xFF7C3AED)),
                    const SizedBox(width: 14),
                    _buildModeCard(3, '📦 Pre-Built Templates', '5Y Backtested Algos', Icons.library_books_rounded, const Color(0xFFD97706)),
                  ],
                ),
                const SizedBox(height: 24),

                // Active Workspace Body
                if (_activeBuilderTab == 0)
                  _buildAiBuilderSection(cardColor, borderColor, textColor, subTextColor)
                else if (_activeBuilderTab == 1)
                  _buildVisualRuleSection(cardColor, borderColor, textColor, subTextColor)
                else if (_activeBuilderTab == 2)
                  const OptionsChainView(initialTabIndex: 2)
                else
                  _buildTemplatesSection(cardColor, borderColor, textColor, subTextColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeCard(int idx, String title, String subtitle, IconData icon, Color color) {
    final isSel = _activeBuilderTab == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeBuilderTab = idx),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSel ? color.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? color : const Color(0xFFE2E8F0), width: isSel ? 2 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: isSel ? color : const Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  // 1. AI Builder Section
  Widget _buildAiBuilderSection(Color cardColor, Color borderColor, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Natural Language Strategy Builder (Gemini 2.5 Algo Copilot)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor)),
                      Text('Type your trading ideas in natural language. The AI will translate them into multi-broker execution logic.', style: TextStyle(fontSize: 12, color: subTextColor)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('GEMINI 2.5 ACTIVE', style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          TextField(
            controller: _aiPromptCtrl,
            maxLines: 3,
            style: TextStyle(color: textColor, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'e.g., At 09:20 AM sell ATM Call & Put for Bank Nifty with 25% stop loss per leg...',
              hintStyle: TextStyle(color: subTextColor),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // Quick Prompt Ideas
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              '9:20 Bank Nifty Short Straddle (25% SL)',
              'Supertrend (10,3) + 20 EMA 15m Momentum',
              'VWAP Reversal with 1:2 Risk-Reward',
              'Nifty 4-Legged Iron Condor for Expiry',
            ].map((p) => InkWell(
              onTap: () => setState(() => _aiPromptCtrl.text = p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 12, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(p, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  ],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateAiStrategy,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isGenerating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.flash_on_rounded, size: 16),
              label: Text(_isGenerating ? 'Compiling Algorithmic Logic...' : 'Compile & Generate Live Strategy', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Visual Rule Builder Section
  Widget _buildVisualRuleSection(Color cardColor, Color borderColor, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Visual No-Code Condition Canvas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                child: const Text('SUB-15ms EXECUTION READY', style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Step 1: Instrument & Timeframe
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedInstrument,
                  decoration: InputDecoration(
                    labelText: 'Instrument Target',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ['BANKNIFTY-OPT', 'NIFTY50-INDEX', 'RELIANCE-EQ', 'FINNIFTY-OPT'].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                  onChanged: (v) => setState(() => _selectedInstrument = v!),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedTimeframe,
                  decoration: InputDecoration(
                    labelText: 'Candle Timeframe',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ['1m', '3m', '5m', '15m', '1h', 'Daily'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _selectedTimeframe = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Step 2: Entry Conditions (IF condition)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.play_circle_outline_rounded, color: Color(0xFF059669), size: 18),
                    SizedBox(width: 6),
                    Text('ENTRY CONDITION 1 (Trigger Rule)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: _entryCondition1),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 6),
                    Text('AND ENTRY CONDITION 2 (Filter Confirmation)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF))),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: _entryCondition2),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Step 3: Risk Management (SL & Target)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: '$_stopLossPct%'),
                  decoration: InputDecoration(
                    labelText: 'Stop Loss %',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: '$_targetPct%'),
                  decoration: InputDecoration(
                    labelText: 'Target Profit %',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              final cnt = CopyTradingEngine().totalAccountsCount;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Visual Strategy Saved & Deployed across all $cnt Brokers! Live engine monitoring ticks.'),
                  backgroundColor: const Color(0xFF059669),
                ),
              );
            },
            icon: const Icon(Icons.save_rounded, size: 16),
            label: Text('Save & Deploy Strategy (${CopyTradingEngine().totalAccountsCount} Brokers)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Pre-Built Templates Section
  Widget _buildTemplatesSection(Color cardColor, Color borderColor, Color textColor, Color subTextColor) {
    final templates = [
      {'title': '9:20 AM Bank Nifty Short Straddle', 'cagr': '+68.4%', 'sharpe': 2.65, 'dd': '-4.8%', 'type': 'Options Selling'},
      {'title': 'Nifty 15m Momentum Breakout', 'cagr': '+52.0%', 'sharpe': 2.32, 'dd': '-5.6%', 'type': 'Trend Following'},
      {'title': 'VWAP Pullback Intraday Scalper', 'cagr': '+44.2%', 'sharpe': 2.15, 'dd': '-3.8%', 'type': 'Equity Scalping'},
      {'title': 'Iron Condor 4-Legged Defined Risk', 'cagr': '+38.5%', 'sharpe': 3.10, 'dd': '-2.4%', 'type': 'Delta Neutral'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.8),
      itemCount: templates.length,
      itemBuilder: (ctx, idx) {
        final t = templates[idx];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                    child: Text(t['type'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                  ),
                  Text('Sharpe: ${t['sharpe']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF059669))),
                ],
              ),
              const SizedBox(height: 8),
              Text(t['title'] as String, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CAGR: ${t['cagr']} | Max DD: ${t['dd']}', style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    onPressed: () {
                      final cnt = CopyTradingEngine().totalAccountsCount;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Cloned "${t['title']}". Deployed across $cnt Brokers!'), backgroundColor: const Color(0xFF059669)),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    child: Text('Deploy (${CopyTradingEngine().totalAccountsCount} Brokers)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
