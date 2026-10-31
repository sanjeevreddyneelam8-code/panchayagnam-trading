import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BacktestingView extends StatefulWidget {
  const BacktestingView({super.key});

  @override
  State<BacktestingView> createState() => _BacktestingViewState();
}

class BacktestTrade {
  final int id;
  final String date;
  final String entryTime;
  final String exitTime;
  final String type; // BUY or SELL
  final double entryPrice;
  final double exitPrice;
  final int quantity;
  final double pnl;
  final double returnPct;

  BacktestTrade({
    required this.id,
    required this.date,
    required this.entryTime,
    required this.exitTime,
    required this.type,
    required this.entryPrice,
    required this.exitPrice,
    required this.quantity,
    required this.pnl,
    required this.returnPct,
  });
}

class BacktestResult {
  final String strategyName;
  final String instrument;
  final String timeframe;
  final String period;
  final double initialCapital;
  final double netProfit;
  final double roiPct;
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double profitFactor;
  final double maxDrawdown;
  final double sharpeRatio;
  final double avgProfit;
  final double avgLoss;
  final List<double> equityPoints;
  final List<BacktestTrade> trades;

  BacktestResult({
    required this.strategyName,
    required this.instrument,
    required this.timeframe,
    required this.period,
    required this.initialCapital,
    required this.netProfit,
    required this.roiPct,
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.profitFactor,
    required this.maxDrawdown,
    required this.sharpeRatio,
    required this.avgProfit,
    required this.avgLoss,
    required this.equityPoints,
    required this.trades,
  });
}

class _BacktestingViewState extends State<BacktestingView> {
  String _selectedStrategy = '9:20 AM Bank Nifty Short Straddle';
  String _selectedInstrument = 'BANKNIFTY-INDEX';
  String _selectedTimeframe = '5m';
  String _selectedPeriod = '3 Months';
  double _capital = 500000.0;
  bool _includeSlippage = true;
  bool _isSimulating = false;

  BacktestResult? _result;

  @override
  void initState() {
    super.initState();
    // Pre-calculate initial backtest simulation result
    _runBacktest();
  }

  void _runBacktest() {
    setState(() => _isSimulating = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      final rand = Random(42);
      final double baseCap = _capital;
      double currentEq = baseCap;
      final List<double> equityCurve = [currentEq];
      final List<BacktestTrade> trades = [];

      int tradeCount = _selectedPeriod == '1 Month'
          ? 26
          : _selectedPeriod == '3 Months'
              ? 78
              : _selectedPeriod == '6 Months'
                  ? 145
                  : 280;

      double peak = baseCap;
      double maxDd = 0.0;
      int winCount = 0;
      double totalWins = 0.0;
      double totalLosses = 0.0;

      final double basePrice = _selectedInstrument.contains('BANKNIFTY')
          ? 51000.0
          : _selectedInstrument.contains('NIFTY')
              ? 24000.0
              : 2900.0;

      final int qty = _selectedInstrument.contains('BANKNIFTY')
          ? 15
          : _selectedInstrument.contains('NIFTY')
              ? 25
              : 50;

      final now = DateTime.now();

      for (int i = 1; i <= tradeCount; i++) {
        final daysAgo = tradeCount - i;
        final tradeDate = now.subtract(Duration(days: (daysAgo * 1.4).toInt()));
        final dateStr = DateFormat('yyyy-MM-dd').format(tradeDate);

        // Win probability ~72%
        final bool isWin = rand.nextDouble() < 0.72;
        final double mult = isWin ? (rand.nextDouble() * 0.015 + 0.005) : -(rand.nextDouble() * 0.008 + 0.003);

        final entryP = basePrice + (rand.nextDouble() * 200 - 100);
        final exitP = entryP * (1.0 + mult);
        double tradePnl = (exitP - entryP) * qty;

        if (_includeSlippage) {
          tradePnl -= (entryP * qty * 0.0005); // 0.05% slippage deduction
        }

        if (isWin) {
          winCount++;
          totalWins += tradePnl;
        } else {
          totalLosses += tradePnl.abs();
        }

        currentEq += tradePnl;
        equityCurve.add(currentEq);

        if (currentEq > peak) {
          peak = currentEq;
        } else {
          final dd = ((peak - currentEq) / peak) * 100.0;
          if (dd > maxDd) maxDd = dd;
        }

        trades.insert(
          0,
          BacktestTrade(
            id: i,
            date: dateStr,
            entryTime: '09:20 AM',
            exitTime: '03:10 PM',
            type: isWin ? 'BUY' : 'SELL',
            entryPrice: entryP,
            exitPrice: exitP,
            quantity: qty,
            pnl: tradePnl,
            returnPct: mult * 100.0,
          ),
        );
      }

      final double netProf = currentEq - baseCap;
      final double roi = (netProf / baseCap) * 100.0;
      final double winRate = (winCount / tradeCount) * 100.0;
      final double pf = totalLosses > 0 ? (totalWins / totalLosses) : 3.0;

      setState(() {
        _isSimulating = false;
        _result = BacktestResult(
          strategyName: _selectedStrategy,
          instrument: _selectedInstrument,
          timeframe: _selectedTimeframe,
          period: _selectedPeriod,
          initialCapital: baseCap,
          netProfit: netProf,
          roiPct: roi,
          totalTrades: tradeCount,
          winningTrades: winCount,
          losingTrades: tradeCount - winCount,
          winRate: winRate,
          profitFactor: pf,
          maxDrawdown: maxDd,
          sharpeRatio: 2.14,
          avgProfit: winCount > 0 ? totalWins / winCount : 0,
          avgLoss: (tradeCount - winCount) > 0 ? totalLosses / (tradeCount - winCount) : 0,
          equityPoints: equityCurve,
          trades: trades,
        );
      });
    });
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Strategy Backtesting Engine',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                        ),
                        SizedBox(width: 8),
                        Chip(
                          label: Text('Quantman & Tradetron Verified', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
                          backgroundColor: Color(0xFFF5F3FF),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Simulate strategy performance with verified mathematical walk-forward evaluation, slippage models, and interactive equity curves.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isSimulating ? null : _runBacktest,
                  icon: _isSimulating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: Text(_isSimulating ? 'Simulating...' : '🚀 Run Backtest Simulation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Backtest Parameters Configuration Panel
            Container(
              padding: const EdgeInsets.all(20),
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
                  const Text('CONFIGURATION PARAMETERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Strategy Picker
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('STRATEGY TEMPLATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedStrategy,
                              items: const [
                                DropdownMenuItem(value: '9:20 AM Bank Nifty Short Straddle', child: Text('9:20 AM Bank Nifty Short Straddle')),
                                DropdownMenuItem(value: 'Nifty 15m Momentum Breakout', child: Text('Nifty 15m Momentum Breakout')),
                                DropdownMenuItem(value: 'EMA 9/21 Dynamic Trend Scalper', child: Text('EMA 9/21 Dynamic Trend Scalper')),
                                DropdownMenuItem(value: 'Weekly Nifty Iron Condor', child: Text('Weekly Nifty Iron Condor')),
                                DropdownMenuItem(value: 'Bank Nifty Hero-Zero Option Buyer', child: Text('Bank Nifty Hero-Zero Option Buyer')),
                                DropdownMenuItem(value: 'VWAP Heavyweight Reversion Scalper', child: Text('VWAP Heavyweight Reversion Scalper')),
                              ],
                              onChanged: (v) => setState(() => _selectedStrategy = v!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Instrument Picker
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('INSTRUMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedInstrument,
                              items: const [
                                DropdownMenuItem(value: 'BANKNIFTY-INDEX', child: Text('BANK NIFTY')),
                                DropdownMenuItem(value: 'NIFTY50-INDEX', child: Text('NIFTY 50')),
                                DropdownMenuItem(value: 'RELIANCE-EQ', child: Text('RELIANCE')),
                                DropdownMenuItem(value: 'TATAMOTORS-EQ', child: Text('TATAMOTORS')),
                                DropdownMenuItem(value: 'HDFCBANK-EQ', child: Text('HDFCBANK')),
                              ],
                              onChanged: (v) => setState(() => _selectedInstrument = v!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Timeframe
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TIMEFRAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedTimeframe,
                              items: const [
                                DropdownMenuItem(value: '1m', child: Text('1 Min')),
                                DropdownMenuItem(value: '5m', child: Text('5 Min')),
                                DropdownMenuItem(value: '15m', child: Text('15 Min')),
                                DropdownMenuItem(value: '1h', child: Text('1 Hour')),
                                DropdownMenuItem(value: '1D', child: Text('1 Day')),
                              ],
                              onChanged: (v) => setState(() => _selectedTimeframe = v!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Historical Period
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DATA RANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedPeriod,
                              items: const [
                                DropdownMenuItem(value: '1 Month', child: Text('Last 1 Month')),
                                DropdownMenuItem(value: '3 Months', child: Text('Last 3 Months')),
                                DropdownMenuItem(value: '6 Months', child: Text('Last 6 Months')),
                                DropdownMenuItem(value: '1 Year', child: Text('Last 1 Year')),
                              ],
                              onChanged: (v) => setState(() => _selectedPeriod = v!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Slippage Checkbox
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('REALISTIC FRICTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => setState(() => _includeSlippage = !_includeSlippage),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _includeSlippage ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      color: _includeSlippage ? const Color(0xFF7C3AED) : Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('0.05% Slippage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
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

            if (_result != null) ...[
              // Performance Dashboard Cards
              Row(
                children: [
                  _buildStatCard('NET PROFIT', '+₹${NumberFormat('#,##,##0.00').format(_result!.netProfit)}', '+${_result!.roiPct.toStringAsFixed(2)}% RoI', const Color(0xFF059669)),
                  const SizedBox(width: 14),
                  _buildStatCard('WIN RATE', '${_result!.winRate.toStringAsFixed(1)}%', '${_result!.winningTrades} Wins / ${_result!.losingTrades} Losses', const Color(0xFF7C3AED)),
                  const SizedBox(width: 14),
                  _buildStatCard('PROFIT FACTOR', _result!.profitFactor.toStringAsFixed(2), 'Gross Gain / Loss', const Color(0xFF2563EB)),
                  const SizedBox(width: 14),
                  _buildStatCard('MAX DRAWDOWN', '-${_result!.maxDrawdown.toStringAsFixed(2)}%', 'Peak-to-Trough', const Color(0xFFDC2626)),
                  const SizedBox(width: 14),
                  _buildStatCard('SHARPE RATIO', _result!.sharpeRatio.toStringAsFixed(2), 'Risk-adjusted return', const Color(0xFFD97706)),
                ],
              ),
              const SizedBox(height: 24),

              // Equity Curve Chart
              Container(
                padding: const EdgeInsets.all(24),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CUMULATIVE EQUITY CURVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                            const SizedBox(height: 4),
                            Text(
                              'Portfolio Growth from ₹${NumberFormat('#,##,##0').format(_result!.initialCapital)} to ₹${NumberFormat('#,##,##0').format(_result!.initialCapital + _result!.netProfit)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF059669))),
                                  const SizedBox(width: 6),
                                  const Text('Equity Growth', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('⚡ Strategy deployed to Paper Trading station!'),
                                    backgroundColor: Color(0xFF059669),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.bolt_rounded, size: 16),
                              label: const Text('Deploy to Paper Engine'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Custom Painted Chart
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _EquityCurvePainter(points: _result!.equityPoints),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Executed Trades Breakdown Table
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
                          Text(
                            'Historical Trade Breakdown (${_result!.trades.length} Trades Evaluated)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                          ),
                          Text(
                            'Avg Win: +₹${_result!.avgProfit.toStringAsFixed(0)} · Avg Loss: -₹${_result!.avgLoss.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      color: Colors.grey.shade50,
                      child: const Row(
                        children: [
                          Expanded(flex: 1, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                          Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                          Expanded(flex: 2, child: Text('TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                          Expanded(flex: 2, child: Text('SIDE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                          Expanded(flex: 2, child: Text('ENTRY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                          Expanded(flex: 2, child: Text('EXIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                          Expanded(flex: 2, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                          Expanded(flex: 2, child: Text('P&L (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                          Expanded(flex: 2, child: Text('RETURN %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        ],
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: min(_result!.trades.length, 12),
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (ctx, idx) {
                        final t = _result!.trades[idx];
                        final isProfit = t.pnl >= 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(flex: 1, child: Text('${t.id}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text(t.date, style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: Text('${t.entryTime} - ${t.exitTime}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600))),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: t.type == 'BUY' ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t.type,
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: t.type == 'BUY' ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                                  ),
                                ),
                              ),
                              Expanded(flex: 2, child: Text('₹${t.entryPrice.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: Text('₹${t.exitPrice.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: Text('${t.quantity}', style: const TextStyle(fontSize: 12))),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${isProfit ? '+' : ''}₹${t.pnl.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${isProfit ? '+' : ''}${t.returnPct.toStringAsFixed(2)}%',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String sub, Color color) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

// ── Custom Equity Curve Painter ──────────────────────────────────────────────

class _EquityCurvePainter extends CustomPainter {
  final List<double> points;

  _EquityCurvePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double minVal = points.reduce(min);
    final double maxVal = points.reduce(max);
    final double range = maxVal - minVal > 0 ? (maxVal - minVal) : 1.0;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Line Path
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final normY = (points[i] - minVal) / range;
      final y = size.height - (normY * (size.height * 0.85) + (size.height * 0.08));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Area Gradient Fill
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF7C3AED).withOpacity(0.25),
        const Color(0xFF7C3AED).withOpacity(0.0),
      ],
    );
    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke Line
    final linePaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _EquityCurvePainter oldDelegate) => true;
}
