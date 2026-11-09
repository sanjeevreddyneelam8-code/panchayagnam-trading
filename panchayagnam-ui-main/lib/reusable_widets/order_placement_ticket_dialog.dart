import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../service/copy_trading_engine.dart';
import '../service/theme_mode_service.dart';
import 'copy_trade_receipt_dialog.dart';

class OrderPlacementTicketDialog extends StatefulWidget {
  final String symbol;
  final String side; // 'BUY' or 'SELL'
  final double ltp;
  final int lotSize;
  final String category; // 'EQUITY' or 'F&O'

  const OrderPlacementTicketDialog({
    super.key,
    required this.symbol,
    required this.side,
    required this.ltp,
    this.lotSize = 1,
    this.category = 'EQUITY',
  });

  static void show(
    BuildContext context, {
    required String symbol,
    required String side,
    required double ltp,
    int lotSize = 1,
    String category = 'EQUITY',
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => OrderPlacementTicketDialog(
        symbol: symbol,
        side: side,
        ltp: ltp,
        lotSize: lotSize,
        category: category,
      ),
    );
  }

  @override
  State<OrderPlacementTicketDialog> createState() => _OrderPlacementTicketDialogState();
}

class _OrderPlacementTicketDialogState extends State<OrderPlacementTicketDialog> {
  late String _side;
  String _selectedExchange = 'NSE';
  String _productType = 'INTRADAY'; // 'DELIVERY', 'INTRADAY', 'PAY_LATER'
  String _orderType = 'MARKET'; // 'MARKET', 'LIMIT'

  late int _quantity;
  late double _limitPrice;
  bool _usePayLater = false;
  bool _showSmartOrders = false;
  double _slTriggerPrice = 0.0;
  double _targetPrice = 0.0;

  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _slCtrl;
  late TextEditingController _targetCtrl;

  @override
  void initState() {
    super.initState();
    _side = widget.side.toUpperCase();
    _quantity = widget.lotSize > 1 ? widget.lotSize : 25;
    _limitPrice = widget.ltp;
    _slTriggerPrice = _side == 'BUY' ? (_limitPrice * 0.90) : (_limitPrice * 1.10);
    _targetPrice = _side == 'BUY' ? (_limitPrice * 1.20) : (_limitPrice * 0.80);

    _qtyCtrl = TextEditingController(text: '$_quantity');
    _priceCtrl = TextEditingController(text: _limitPrice.toStringAsFixed(2));
    _slCtrl = TextEditingController(text: _slTriggerPrice.toStringAsFixed(2));
    _targetCtrl = TextEditingController(text: _targetPrice.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _slCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  double get _marginRequired {
    final effectivePrice = _orderType == 'MARKET' ? widget.ltp : _limitPrice;
    final totalValue = effectivePrice * _quantity;
    if (_productType == 'INTRADAY') {
      return totalValue / 5.0; // 5x leverage
    } else if (_productType == 'PAY_LATER') {
      return totalValue / 4.2; // 4.2x MTF
    }
    return totalValue; // 1x delivery
  }

  void _onQtyChanged(int newQty) {
    if (newQty < 1) newQty = 1;
    setState(() {
      _quantity = newQty;
      _qtyCtrl.text = '$_quantity';
    });
  }

  void _onPriceChanged(double newPrice) {
    if (newPrice < 0.05) newPrice = 0.05;
    setState(() {
      _limitPrice = newPrice;
      _priceCtrl.text = _limitPrice.toStringAsFixed(2);
    });
  }

  void _executeOrder() async {
    Navigator.pop(context); // Close ticket

    final engine = CopyTradingEngine();
    final productStr = _productType == 'INTRADAY'
        ? 'INTRADAY (MIS)'
        : (_productType == 'PAY_LATER' ? 'MARGIN (MTF)' : 'DELIVERY (CNC)');

    final receipt = await engine.replicateTrade(
      symbol: widget.symbol,
      side: _side,
      baseQty: _quantity,
      price: _orderType == 'MARKET' ? widget.ltp : _limitPrice,
      orderType: _orderType,
      productType: productStr,
      lotSize: widget.lotSize,
    );

    if (mounted) {
      CopyTradeReceiptDialog.show(context, receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = _side == 'BUY';
    final themeColor = isBuy ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final themeBg = isBuy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final themeBorder = isBuy ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header matching AngelOne / Groww Order Sheet ──────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: BoxDecoration(
                color: themeBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: themeBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF1E293B)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.symbol,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Buy / Sell Switcher Pills
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _side = 'BUY'),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isBuy ? const Color(0xFF059669) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('BUY', style: TextStyle(color: isBuy ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _side = 'SELL'),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: !isBuy ? const Color(0xFFDC2626) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('SELL', style: TextStyle(color: !isBuy ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Exchange Selector Radios (NSE vs BSE)
                  Row(
                    children: [
                      _buildExchangeRadio('NSE', '₹${widget.ltp.toStringAsFixed(2)}', '+2.09%'),
                      const SizedBox(width: 14),
                      _buildExchangeRadio('BSE', '₹${(widget.ltp * 0.996).toStringAsFixed(2)}', '+1.98%'),
                    ],
                  ),
                ],
              ),
            ),

            // ── Product Tabs (DELIVERY | INTRADAY Buy 5x | PAY LATER 4.2x) ────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  _buildProductTab('DELIVERY', 'DELIVERY', null),
                  const SizedBox(width: 8),
                  _buildProductTab('INTRADAY', 'INTRADAY', 'Buy 5x'),
                  const SizedBox(width: 8),
                  _buildProductTab('PAY_LATER', 'PAY LATER', '4.2x'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Stepper Form Fields ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // No. of shares / Lots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.lotSize > 1 ? 'No. of shares (Lots)' : 'No. of shares', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      Text(widget.lotSize > 1 ? '1 Lot = ${widget.lotSize} Qty' : 'Max Qty: 50,000', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16, color: Color(0xFF64748B)),
                          onPressed: () => _onQtyChanged(_quantity - (widget.lotSize > 1 ? widget.lotSize : 25)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                            onChanged: (v) {
                              final val = int.tryParse(v);
                              if (val != null) setState(() => _quantity = val);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: Color(0xFF64748B)),
                          onPressed: () => _onQtyChanged(_quantity + (widget.lotSize > 1 ? widget.lotSize : 25)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Limit / Market Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Limit / Market Price', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      Row(
                        children: [
                          _buildTypeChip('MARKET'),
                          const SizedBox(width: 6),
                          _buildTypeChip('LIMIT'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _orderType == 'MARKET' ? const Color(0xFFF1F5F9) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16, color: Color(0xFF64748B)),
                          onPressed: _orderType == 'MARKET' ? null : () => _onPriceChanged(_limitPrice - 0.50),
                        ),
                        Expanded(
                          child: _orderType == 'MARKET'
                              ? Center(
                                  child: Text(
                                    'Market Price (₹${widget.ltp.toStringAsFixed(2)})',
                                    style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                )
                              : TextField(
                                  controller: _priceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                  onChanged: (v) {
                                    final val = double.tryParse(v);
                                    if (val != null) setState(() => _limitPrice = val);
                                  },
                                ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: Color(0xFF64748B)),
                          onPressed: _orderType == 'MARKET' ? null : () => _onPriceChanged(_limitPrice + 0.50),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pay Later MTF Checkbox Box (From AngelOne / Groww Image)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _usePayLater,
                            activeColor: const Color(0xFFD97706),
                            onChanged: (v) => setState(() => _usePayLater = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'With Pay Later (MTF): ₹${(widget.ltp * 0.25).toStringAsFixed(2)} margin',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                          ),
                        ),
                        const Text('KNOW MORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Smart Orders Accordion (STOP LOSS & GTT)
                  InkWell(
                    onTap: () => setState(() => _showSmartOrders = !_showSmartOrders),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Smart Orders (STOP LOSS & GTT)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                          Icon(_showSmartOrders ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20, color: const Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  if (_showSmartOrders) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _slCtrl,
                            decoration: InputDecoration(
                              labelText: 'Stop Loss Trigger (SL)',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _targetCtrl,
                            decoration: InputDecoration(
                              labelText: 'Target (GTT)',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Synchronized Execution Multi-Broker Banner ───────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hub_rounded, size: 14, color: Color(0xFF38BDF8)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Panchayagnam Synchronized: Replicating to 8 Demats (Sub-15ms)',
                      style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('8/8 Ready', style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Bottom Summary & CTA Button ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Margin Required (Approx)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text('₹${_marginRequired.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Available Pooled Margin', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          SizedBox(height: 2),
                          Text('₹80,00,000.00', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Place Buy / Sell Order CTA
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _executeOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      child: Text(
                        'PLACE $_side ORDER (8 DEMATS)',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                      ),
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

  Widget _buildExchangeRadio(String ex, String price, String chg) {
    final isSel = _selectedExchange == ex;
    return InkWell(
      onTap: () => setState(() => _selectedExchange = ex),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSel ? const Color(0xFF059669) : const Color(0xFF94A3B8), width: isSel ? 4 : 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text('$ex: $price ($chg)', style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? const Color(0xFF0F172A) : const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildProductTab(String key, String label, String? badge) {
    final isSel = _productType == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _productType = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF059669).withOpacity(0.12) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSel ? const Color(0xFF059669) : Colors.transparent, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                  color: isSel ? const Color(0xFF059669) : const Color(0xFF475569),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Text(badge, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: isSel ? const Color(0xFF047857) : const Color(0xFF64748B))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final isSel = _orderType == type;
    return InkWell(
      onTap: () => setState(() => _orderType = type),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          type,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isSel ? Colors.white : const Color(0xFF64748B)),
        ),
      ),
    );
  }
}
