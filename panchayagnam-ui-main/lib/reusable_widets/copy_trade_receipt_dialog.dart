import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service/copy_trading_engine.dart';

class CopyTradeReceiptDialog extends StatelessWidget {
  final CopyExecutionReceipt receipt;

  const CopyTradeReceiptDialog({super.key, required this.receipt});

  static void show(BuildContext context, CopyExecutionReceipt receipt) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => CopyTradeReceiptDialog(receipt: receipt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isBuy = receipt.masterSide.toUpperCase() == 'BUY';
    final themeColor = isBuy ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final themeBg = isBuy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final themeBorder = isBuy ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenW > 850 ? (screenW - 780) / 2 : 16,
        vertical: 24,
      ),
      child: Container(
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isBuy
                        ? [const Color(0xFF059669), const Color(0xFF047857)]
                        : [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${receipt.masterSide} EXECUTED',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${receipt.totalAccountsFilled} DEMATS SYNCED',
                                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Panchayagnam Real-Time Trade Copier Engine • Trade ID: ${receipt.tradeId}',
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

              // Summary Metric Cards
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    _buildMetricCard(
                      label: 'CONTRACT / SYMBOL',
                      value: receipt.symbol,
                      subtext: '${receipt.orderType} • ${receipt.productType}',
                      color: const Color(0xFF1E293B),
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      label: 'EXECUTION PRICE',
                      value: '₹${receipt.executionPrice.toStringAsFixed(2)}',
                      subtext: 'NSE Real-Time Tick',
                      color: themeColor,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      label: 'TOTAL POOLED QTY',
                      value: '${receipt.aggregateQty} Qty',
                      subtext: '${receipt.masterQty} Qty Master Base',
                      color: const Color(0xFF6D28D9),
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      label: 'AVG DISPATCH SPEED',
                      value: '${receipt.avgLatencyMs.toStringAsFixed(1)} ms',
                      subtext: 'Parallel CompletableFuture',
                      color: const Color(0xFF0284C7),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Multi-Account Execution Fan-Out List
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CONCURRENT DEMAT DISPATCH BREAKDOWN',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.security_rounded, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          'Total Deployed: ₹${receipt.aggregateCapital.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                  itemCount: receipt.legs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final leg = receipt.legs[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: leg.isMaster ? const Color(0xFFF5F3FF) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: leg.isMaster ? const Color(0xFFDDD6FE) : const Color(0xFFE2E8F0),
                          width: leg.isMaster ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: leg.isMaster ? const Color(0xFF7C3AED) : const Color(0xFF475569),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              leg.broker,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      leg.accountName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: leg.isMaster ? FontWeight.w800 : FontWeight.w600,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (leg.isMaster) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('MASTER / LEADER', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 9, fontWeight: FontWeight.w800)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${leg.clientId} • Order Ref: ${leg.orderId} • ${leg.message}',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${leg.side} ${leg.qty} Qty',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: themeColor),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: Text(leg.status, style: const TextStyle(color: Color(0xFF059669), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${leg.totalAmount.toStringAsFixed(0)} • ${leg.latencyMs}ms',
                                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Action Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Executed at ${DateFormat('HH:mm:ss.SSS').format(receipt.timestamp)} IST',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color), overflow: TextOverflow.ellipsis),
            Text(subtext, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
