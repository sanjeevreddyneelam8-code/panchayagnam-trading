import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';

enum PaymentMethod { upi, card, netBanking, wallet }

class PaymentGatewayDialog extends StatefulWidget {
  final String initialPlan;
  final double initialAmount;
  final Function(double amount, String plan, String txnId)? onPaymentSuccess;

  const PaymentGatewayDialog({
    super.key,
    this.initialPlan = 'Dedicated Static IP',
    this.initialAmount = 1500.0,
    this.onPaymentSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    String initialPlan = 'Dedicated Static IP',
    double initialAmount = 1500.0,
    Function(double amount, String plan, String txnId)? onPaymentSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentGatewayDialog(
        initialPlan: initialPlan,
        initialAmount: initialAmount,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<PaymentGatewayDialog> createState() => _PaymentGatewayDialogState();
}

class _PaymentGatewayDialogState extends State<PaymentGatewayDialog> {
  late String _selectedPlan;
  late double _amount;
  PaymentMethod _selectedMethod = PaymentMethod.upi;

  // UPI fields
  final _upiIdCtrl = TextEditingController(text: 'sanjeev@okhdfcbank');
  String _selectedUpiApp = 'Google Pay';

  // Card fields
  final _cardNumberCtrl = TextEditingController(text: '4532 •••• •••• 8821');
  final _cardExpiryCtrl = TextEditingController(text: '12/28');
  final _cardCvvCtrl = TextEditingController(text: '821');
  final _cardNameCtrl = TextEditingController(text: 'SANJEEV REDDY');

  // Net banking
  String _selectedBank = 'HDFC Bank';

  // Processing state
  bool _isProcessing = false;
  bool _isSuccess = false;
  String _txnId = '';
  int _qrCountdown = 299; // 5 mins
  Timer? _countdownTimer;

  final Map<String, double> _plans = {
    'Dedicated Static IP': 1500.0,
    'Starter Plan (20 Demats)': 1999.0,
    'Pro Plan (50 Demats)': 4999.0,
    'Institutional Plan (100 Demats)': 9999.0,
    'Add Trading Margin (₹50,000)': 50000.0,
    'Add Trading Margin (₹1,00,000)': 100000.0,
  };

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.initialPlan;
    _amount = widget.initialAmount;
    if (!_plans.containsKey(_selectedPlan)) {
      _plans[_selectedPlan] = _amount;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_qrCountdown > 0) {
        setState(() => _qrCountdown--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _upiIdCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    _cardNameCtrl.dispose();
    super.dispose();
  }

  String _formatINR(double val) {
    final s = val.toInt().toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i != 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '₹$buf,$last3';
  }

  void _triggerPayment() async {
    setState(() => _isProcessing = true);

    // Simulate realistic bank API roundtrip latency
    await Future.delayed(const Duration(milliseconds: 1800));

    final now = DateTime.now().millisecondsSinceEpoch;
    final generatedTxn = 'TXN_PY_${now.toString().substring(now.toString().length - 8)}';

    // Update session storage for subscription expiry if plan purchased
    try {
      html.window.sessionStorage['expiresInDays'] = '365';
      html.window.sessionStorage['expiredFlag'] = 'false';
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _isSuccess = true;
      _txnId = generatedTxn;
    });

    widget.onPaymentSuccess?.call(_amount, _selectedPlan, generatedTxn);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 24,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: _isSuccess ? _buildSuccessView() : _buildCheckoutView(),
      ),
    );
  }

  Widget _buildCheckoutView() {
    return Column(
      children: [
        // Top Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PANCHAYAGNAM PAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Secured by 256-Bit SSL · NPCI & RBI Certified Gateway',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_rounded, size: 12, color: Color(0xFF34D399)),
                        SizedBox(width: 4),
                        Text('100% SECURE', style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Plan / Item Summary Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PURCHASE ITEM / SERVICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _plans.containsKey(_selectedPlan) ? _selectedPlan : _plans.keys.first,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                      items: _plans.keys.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (newPlan) {
                        if (newPlan != null) {
                          setState(() {
                            _selectedPlan = newPlan;
                            _amount = _plans[newPlan] ?? 1500.0;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('TOTAL PAYABLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(
                    _formatINR(_amount),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Main Body: Left Payment Methods & Right Details
        Expanded(
          child: Row(
            children: [
              // Left: Payment Method Tabs (Width: 220)
              Container(
                width: 220,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: ListView(
                  children: [
                    _buildMethodTab(PaymentMethod.upi, 'UPI & QR Code', Icons.qr_code_scanner_rounded, badge: 'FASTEST'),
                    _buildMethodTab(PaymentMethod.card, 'Credit / Debit Cards', Icons.credit_card_rounded),
                    _buildMethodTab(PaymentMethod.netBanking, 'Net Banking', Icons.account_balance_rounded),
                    _buildMethodTab(PaymentMethod.wallet, 'Wallets & PayLater', Icons.account_balance_wallet_rounded),
                  ],
                ),
              ),

              // Right: Method Form / Checkout
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _isProcessing
                      ? _buildProcessingSpinner()
                      : _buildActiveMethodDetails(),
                ),
              ),
            ],
          ),
        ),

        // Bottom Footer Bar with Pay Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    'Instant Activation · 100% Money-Back Guarantee',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _isProcessing ? null : _triggerPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFF93C5FD),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Pay ${_formatINR(_amount)} Now',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMethodTab(PaymentMethod method, String label, IconData icon, {String? badge}) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 3.5,
            ),
            bottom: const BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: Color(0xFF047857), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveMethodDetails() {
    switch (_selectedMethod) {
      case PaymentMethod.upi:
        return _buildUpiSection();
      case PaymentMethod.card:
        return _buildCardSection();
      case PaymentMethod.netBanking:
        return _buildNetBankingSection();
      case PaymentMethod.wallet:
        return _buildWalletSection();
    }
  }

  // 1. UPI Section
  Widget _buildUpiSection() {
    final mins = (_qrCountdown ~/ 60).toString().padLeft(2, '0');
    final secs = (_qrCountdown % 60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic UPI QR Code Box
              Container(
                width: 160,
                height: 160,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 90, color: Color(0xFF0F172A)),
                    const SizedBox(height: 4),
                    Text(
                      'Scan with any UPI App',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                    Text(
                      '$mins:$secs remaining',
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // UPI Apps list
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scan & Pay via UPI Apps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Google Pay', 'PhonePe', 'Paytm', 'BHIM', 'CRED'].map((app) {
                        final isSel = _selectedUpiApp == app;
                        return InkWell(
                          onTap: () => setState(() => _selectedUpiApp = app),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt, size: 14, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text(app, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Or enter UPI ID
          const Text('Or enter your UPI ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _upiIdCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. mobileNumber@upi / yourname@okhdfcbank',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _triggerPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Verify & Pay', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Card Section
  Widget _buildCardSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Enter Card Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _cardNumberCtrl.text = '4532 •••• •••• 8821';
                    _cardExpiryCtrl.text = '12/28';
                    _cardCvvCtrl.text = '821';
                    _cardNameCtrl.text = 'SANJEEV REDDY';
                  });
                },
                icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: Color(0xFF2563EB)),
                label: const Text('Use Demo Test Card', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cardNumberCtrl,
            decoration: InputDecoration(
              labelText: 'Card Number',
              prefixIcon: const Icon(Icons.credit_card),
              suffixIcon: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardExpiryCtrl,
                  decoration: InputDecoration(
                    labelText: 'Valid Thru (MM/YY)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cardCvvCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    suffixIcon: const Icon(Icons.help_outline, size: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardNameCtrl,
            decoration: InputDecoration(
              labelText: 'Name on Card',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Net Banking Section
  Widget _buildNetBankingSection() {
    final banks = ['HDFC Bank', 'ICICI Bank', 'State Bank of India', 'Axis Bank', 'Kotak Mahindra Bank', 'Punjab National Bank'];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Your Bank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: banks.map((bank) {
              final isSel = _selectedBank == bank;
              return InkWell(
                onTap: () => setState(() => _selectedBank = bank),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 155,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isSel ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance, size: 16, color: isSel ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bank,
                          style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 4. Wallet Section
  Widget _buildWalletSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Popular Wallets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
          leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF2563EB)),
          title: const Text('Paytm Wallet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Link your mobile number for 1-click checkout', style: TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _triggerPayment,
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
          leading: const Icon(Icons.mobile_friendly, color: Color(0xFF059669)),
          title: const Text('Amazon Pay / Mobikwik', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Instant debit with cashback rewards', style: TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _triggerPayment,
        ),
      ],
    );
  }

  Widget _buildProcessingSpinner() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 3),
          ),
          SizedBox(height: 20),
          Text('Securing Connection with Bank...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          SizedBox(height: 6),
          Text('Please do not refresh or close this window.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        ],
      ),
    );
  }

  // Payment Success Screen
  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 54),
          ),
          const SizedBox(height: 18),
          const Text('Payment Successful!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text(
            'Your transaction of ${_formatINR(_amount)} has been approved and activated.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
          ),
          const SizedBox(height: 24),

          // Transaction details box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Transaction ID', _txnId),
                const Divider(height: 16),
                _buildReceiptRow('Service / Plan', _selectedPlan),
                const Divider(height: 16),
                _buildReceiptRow('Amount Paid', _formatINR(_amount)),
                const Divider(height: 16),
                _buildReceiptRow('Payment Mode', _selectedMethod == PaymentMethod.upi ? 'UPI (Verified)' : 'Card / Net Banking'),
                const Divider(height: 16),
                _buildReceiptRow('Status', 'CONFIRMED · ACTIVE', isHighlight: true),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Receipt downloaded successfully (PDF)')),
                  );
                },
                icon: const Icon(Icons.receipt_long, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Download Receipt', style: TextStyle(color: Color(0xFF2563EB))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Done · Back to Trading', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isHighlight ? const Color(0xFF059669) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
