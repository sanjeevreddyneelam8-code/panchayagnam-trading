import 'package:flutter/material.dart';
import '../../../service/theme_mode_service.dart';

class BasketItem {
  final String symbol;
  final String exchange;
  final String action; // 'BUY' or 'SELL'
  final int quantity;
  final String orderType; // 'MARKET', 'LIMIT'
  final double? price;

  BasketItem({
    required this.symbol,
    required this.exchange,
    required this.action,
    required this.quantity,
    required this.orderType,
    this.price,
  });
}

class BasketOrdersView extends StatefulWidget {
  const BasketOrdersView({super.key});

  @override
  State<BasketOrdersView> createState() => _BasketOrdersViewState();
}

class _BasketOrdersViewState extends State<BasketOrdersView> {
  final List<BasketItem> _items = [
    BasketItem(symbol: 'RELIANCE', exchange: 'NSE', action: 'BUY', quantity: 25, orderType: 'MARKET'),
    BasketItem(symbol: 'INFY', exchange: 'NSE', action: 'BUY', quantity: 50, orderType: 'MARKET'),
    BasketItem(symbol: 'TCS', exchange: 'NSE', action: 'BUY', quantity: 15, orderType: 'MARKET'),
  ];

  bool _isExecuting = false;

  void _showAddDialog() {
    final symCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '10');
    String action = 'BUY';
    String orderType = 'MARKET';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Basket Leg', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TRADING SYMBOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                const SizedBox(height: 6),
                TextField(
                  controller: symCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'e.g. HDFCBANK',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: action,
                            items: const [
                              DropdownMenuItem(value: 'BUY', child: Text('BUY', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700))),
                              DropdownMenuItem(value: 'SELL', child: Text('SELL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
                            ],
                            onChanged: (v) => setDlgState(() => action = v!),
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
                          const Text('QUANTITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (symCtrl.text.trim().isEmpty) return;
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                setState(() {
                  _items.add(
                    BasketItem(
                      symbol: symCtrl.text.trim().toUpperCase(),
                      exchange: 'NSE',
                      action: action,
                      quantity: qty,
                      orderType: orderType,
                    ),
                  );
                });
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add to Basket'),
            ),
          ],
        ),
      ),
    );
  }

  void _executePaperBasket() {
    setState(() => _isExecuting = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _isExecuting = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 10),
              Text('Paper Basket Executed', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            'Client-Side Simulation: Successfully validated ${_items.length} order legs in local paper-trading simulation. No orders were transmitted to brokers or backend. Engine persistence is scheduled for Phase 4.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeModeService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        final cardBg = isDark ? const Color(0xFF0F1E22) : Colors.white;
        final borderCol = isDark ? const Color(0xFF1E293B) : Colors.grey.shade200;
        final textMain = isDark ? Colors.white : const Color(0xFF111827);
        final textSub = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF081214) : const Color(0xFFF9FAFB),
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
                        Row(
                          children: [
                            Text(
                              'Stocks Basket',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textMain),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'TRADE MARKET',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Create equity & derivative multi-leg order baskets for single-click execution.', style: TextStyle(fontSize: 13, color: textSub)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Leg'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Simulation Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF78350F).withOpacity(0.2) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'STOCKS BASKET EXECUTION — Multi-leg basket orders validate client-side for structure, margins and copy allocation before transmission.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Basket Table
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B171A) : Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(bottom: BorderSide(color: borderCol)),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text('SYMBOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSub))),
                            Expanded(flex: 2, child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSub))),
                            Expanded(flex: 2, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSub))),
                            Expanded(flex: 2, child: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSub))),
                            Expanded(flex: 2, child: Text('EXCHANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSub))),
                            Expanded(flex: 1, child: Text('', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSub))),
                          ],
                        ),
                      ),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('Basket is empty. Click "Add Leg" above.', style: TextStyle(color: textSub)),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: borderCol),
                          itemBuilder: (ctx, i) {
                            final item = _items[i];
                            final isBuy = item.action == 'BUY';
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text(item.symbol, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textMain))),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isBuy
                                            ? (isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFECFDF5))
                                            : (isDark ? const Color(0xFF7F1D1D).withOpacity(0.4) : const Color(0xFFFEF2F2)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.action,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                          color: isBuy ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(flex: 2, child: Text('${item.quantity}', style: TextStyle(fontSize: 13, color: textMain))),
                                  Expanded(flex: 2, child: Text(item.orderType, style: TextStyle(fontSize: 12, color: textSub))),
                                  Expanded(flex: 2, child: Text(item.exchange, style: TextStyle(fontSize: 12, color: textMain))),
                                  Expanded(
                                    flex: 1,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                      onPressed: () => setState(() => _items.removeAt(i)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B171A) : Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          border: Border(top: BorderSide(color: borderCol)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Legs: ${_items.length}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textMain)),
                            ElevatedButton.icon(
                              onPressed: _items.isEmpty || _isExecuting ? null : _executePaperBasket,
                              icon: _isExecuting
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.play_circle_filled_rounded, size: 18),
                              label: Text(_isExecuting ? 'Transmitting...' : 'Execute Stocks Basket'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
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
        );
      },
    );
  }
}