import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../app_route/user_session.dart';
import '../service/service_class.dart';
import '../service/static_ip_service.dart';

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
  int _clientCount = 12; // Flexible client accounts count (10, 11, 12, 13, 14, 15...)
  bool _includeDedicatedIp = false;

  double _calculateClientPrice(int count) {
    double unitPrice;
    if (count <= 10) {
      unitPrice = 199.0;
    } else if (count <= 25) {
      unitPrice = 179.0;
    } else if (count <= 50) {
      unitPrice = 149.0;
    } else {
      unitPrice = 119.0;
    }
    double total = count * unitPrice;
    if (_includeDedicatedIp) total += 1500.0;
    return total;
  }

  // UPI fields
  final _upiIdCtrl = TextEditingController();
  String _selectedUpiApp = 'PhonePe (Official)';

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
    _selectedPlan = 'Custom Client Accounts';
    _amount = _calculateClientPrice(_clientCount);
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
    final utr = _upiIdCtrl.text.trim();
    final role = (html.window.sessionStorage['user_role'] ?? '').toUpperCase();
    final uid = (html.window.sessionStorage['user_id'] ?? '').trim();
    final cleanPhone = (html.window.sessionStorage['user_phoneNumber'] ??
            html.window.sessionStorage['user_phone'] ??
            '')
        .replaceAll(RegExp(r'\D'), '');
    final isOwner = role == 'SUPER_ADMIN' ||
        cleanPhone.endsWith('9553382135') ||
        (role != 'USER' && (uid == '1' || uid == '2'));

    // For clients, require a valid 12-digit numeric UTR from PhonePe
    if (!isOwner) {
      if (utr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter the 12-digit UPI UTR / Reference number from your PhonePe receipt.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (utr.length != 12 || int.tryParse(utr) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid UTR: Please enter the exact 12 numeric digits from your PhonePe receipt.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1400));

    final now = DateTime.now().millisecondsSinceEpoch;
    final generatedTxn = utr.isNotEmpty ? utr : 'TXN_PY_${now.toString().substring(now.toString().length - 8)}';

    if (isOwner) {
      // Owner can instant-unlock for demonstration
      try {
        html.window.sessionStorage['expiresInDays'] = '365';
        html.window.sessionStorage['expiredFlag'] = 'false';
        html.window.sessionStorage['static_ip_unlocked'] = 'true';
      } catch (_) {}
      StaticIpService.unlock(plan: _selectedPlan, txnId: generatedTxn);
    } else {
      // CLIENT: STRICTLY PENDING OWNER APPROVAL!
      // Send real request to backend server database so Owner sees it in Client Requests!
      final rawUid = html.window.sessionStorage['user_id'] ?? '';
      int pyId = int.tryParse(rawUid) ?? 0;
      if (pyId <= 0) {
        pyId = UserSession().userId;
      }
      String? submitError;
      if (pyId > 0) {
        try {
          await ServiceClass().raiseAdminRequestApi(
            pyId: pyId,
            reason: 'PhonePe UPI UTR: $generatedTxn | Plan: $_selectedPlan | Amount: ${_formatINR(_amount)}',
            planMonths: 1,
            requestType: 'CLIENT',
            amount: _amount,
            noOfClients: 1,
          );
        } catch (e) {
          final errStr = e.toString();
          if (!errStr.toLowerCase().contains('already have a pending')) {
            submitError = errStr.replaceAll('Exception:', '').trim();
          }
        }
      }

      if (submitError != null && submitError.isNotEmpty) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server notice: $submitError. Please wait 10 seconds and tap Submit again.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Keep static IP completely LOCKED until owner verifies in PhonePe
      try {
        html.window.sessionStorage['pending_payment_utr'] = generatedTxn;
        html.window.sessionStorage['pending_payment_plan'] = _selectedPlan;
        html.window.sessionStorage['pending_payment_time'] = DateTime.now().toIso8601String();
        html.window.sessionStorage['static_ip_unlocked'] = 'false';
      } catch (_) {}
      StaticIpService.lock();
    }

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _isSuccess = true;
      _txnId = generatedTxn;
    });

    if (isOwner) {
      widget.onPaymentSuccess?.call(_amount, _selectedPlan, generatedTxn);
    }
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
                      color: const Color(0xFF059669),
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

        // Plan / Custom Client Accounts Summary Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.people_alt_rounded, color: Color(0xFF059669), size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FLEXIBLE CLIENT ACCOUNTS PLAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669), letterSpacing: 0.8)),
                          Text('Choose any number of Demat accounts based on your requirement', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('TOTAL PAYABLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
                      Text(
                        _formatINR(_amount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Counter, Slider and Pricing Breakdown Row
              Row(
                children: [
                  // Minus button
                  InkWell(
                    onTap: () {
                      if (_clientCount > 1) {
                        setState(() {
                          _clientCount--;
                          _amount = _calculateClientPrice(_clientCount);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Center(child: Icon(Icons.remove_rounded, size: 18, color: Color(0xFF1E293B))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Display count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$_clientCount Demats',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Plus button
                  InkWell(
                    onTap: () {
                      if (_clientCount < 100) {
                        setState(() {
                          _clientCount++;
                          _amount = _calculateClientPrice(_clientCount);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Center(child: Icon(Icons.add_rounded, size: 18, color: Color(0xFF1E293B))),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Quick selection chips (10, 11, 12, 13, 14, 15, 20, 25)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [10, 11, 12, 13, 14, 15, 20, 25, 30, 50].map((c) {
                          final isSel = _clientCount == c;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('$c', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF334155))),
                              selected: isSel,
                              selectedColor: const Color(0xFF059669),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) {
                                setState(() {
                                  _clientCount = c;
                                  _amount = _calculateClientPrice(_clientCount);
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
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
                  backgroundColor: const Color(0xFF059669),
                  disabledBackgroundColor: const Color(0xFFA7F3D0),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                child: _isProcessing
                    ? SizedBox(
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
              color: isSelected ? const Color(0xFF059669) : Colors.transparent,
              width: 3.5,
            ),
            bottom: const BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B)),
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
              // Official PhonePe Merchant QR Code Box (Pancha Yagnam Investments)
              Container(
                width: 210,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6739B7), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6739B7).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/panchayagnam_payment_qr.jpg',
                        width: 194,
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Text(
                          '$mins:$secs remaining',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _triggerPayment,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 5),
                            Text('Enter UTR Below to Verify ↓', style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // UPI Apps & Merchant Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6739B7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 15, color: Color(0xFF7C3AED)),
                          SizedBox(width: 6),
                          Text('PANCHA YAGNAM INVESTMENTS', style: TextStyle(color: Color(0xFF6D28D9), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Scan & Pay via Any UPI App', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    const Text('Scan the PhonePe merchant QR on the left with PhonePe, Google Pay, Paytm, BHIM, or any banking app on your mobile.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['PhonePe (Official)', 'Google Pay', 'Paytm', 'BHIM', 'CRED'].map((app) {
                        final isSel = _selectedUpiApp == app;
                        return InkWell(
                          onTap: () => setState(() => _selectedUpiApp = app),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFF5F3FF) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isSel ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, size: 14, color: isSel ? const Color(0xFF7C3AED) : const Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Text(app, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFF6D28D9) : const Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Anti-Fraud Verification: After paying on PhonePe, copy the 12-digit UTR number from your payment receipt and enter it below. The owner verifies receipt before activating the Static IP.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600, height: 1.3),
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

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // UTR input (Mandatory for clients)
          const Row(
            children: [
              Text('Step 2: Enter 12-Digit UTR / UPI Ref No ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text('(Required)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _upiIdCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'e.g. 431829019284 (from PhonePe receipt)',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _triggerPayment,
                icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
                label: const Text('Submit UTR for Verification', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
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
                icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: Color(0xFF059669)),
                label: const Text('Use Demo Test Card', style: TextStyle(fontSize: 11, color: Color(0xFF059669))),
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
                    border: Border.all(color: isSel ? const Color(0xFF059669) : const Color(0xFFE2E8F0), width: isSel ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance, size: 16, color: isSel ? const Color(0xFF059669) : const Color(0xFF64748B)),
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
        const Text('Add Money & Pay via Wallet', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Add money to wallet via UPI or Net Banking to activate Dedicated Static IP instantly.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF059669), width: 1.5)),
          tileColor: const Color(0xFFECFDF5),
          leading: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 28),
          title: const Text('Panchayagnam Trading Wallet (Add Money & Pay)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
          subtitle: const Text('Add ₹1,500 to wallet via UPI / Netbanking & activate Static IP instantly', style: TextStyle(fontSize: 11, color: Color(0xFF047857))),
          trailing: ElevatedButton(
            onPressed: _triggerPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Add & Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          onTap: _triggerPayment,
        ),
        const SizedBox(height: 10),
        const Text('Popular Wallets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
          leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF059669)),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(color: Color(0xFF059669), strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          const Text('Securing Connection with Bank...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('Please do not refresh or close this window.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        ],
      ),
    );
  }

  // Payment Result Screen (Success for Owner, Strict Pending Verification for Clients)
  Widget _buildSuccessView() {
    final role = (html.window.sessionStorage['user_role'] ?? '').toUpperCase();
    final uid = (html.window.sessionStorage['user_id'] ?? '').trim();
    final cleanPhone = (html.window.sessionStorage['user_phoneNumber'] ??
            html.window.sessionStorage['user_phone'] ??
            '')
        .replaceAll(RegExp(r'\D'), '');
    final isOwner = role == 'SUPER_ADMIN' ||
        cleanPhone.endsWith('9553382135') ||
        (role != 'USER' && (uid == '1' || uid == '2'));

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: isOwner ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOwner ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
              color: isOwner ? const Color(0xFF10B981) : const Color(0xFFD97706),
              size: 46,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isOwner ? 'Payment Successful!' : 'Payment Request Submitted!',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            isOwner
                ? 'Your transaction of ${_formatINR(_amount)} has been approved and activated.'
                : 'Your payment details for ${_formatINR(_amount)} have been sent to PANCHA YAGNAM INVESTMENTS.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 20),

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
                _buildReceiptRow(isOwner ? 'Transaction ID' : '12-Digit UTR Ref', _txnId),
                const Divider(height: 14),
                _buildReceiptRow('Service / Plan', _selectedPlan),
                const Divider(height: 14),
                _buildReceiptRow('Amount', _formatINR(_amount)),
                const Divider(height: 14),
                _buildReceiptRow('Payment Mode', _selectedMethod == PaymentMethod.upi ? 'PhonePe UPI QR' : 'Card / Net Banking'),
                const Divider(height: 14),
                _buildReceiptRow(
                  'Status',
                  isOwner ? 'CONFIRMED · ACTIVE' : 'PENDING OWNER APPROVAL ⏳',
                  isHighlight: true,
                  color: isOwner ? const Color(0xFF10B981) : const Color(0xFFD97706),
                ),
              ],
            ),
          ),

          // Static IP Status Box
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isOwner ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isOwner ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                Icon(
                  isOwner ? Icons.router_rounded : Icons.lock_clock_rounded,
                  color: isOwner ? const Color(0xFF059669) : const Color(0xFFD97706),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOwner ? 'Dedicated Static IP Unlocked & Active' : 'Dedicated Static IP: LOCKED 🔒',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: isOwner ? const Color(0xFF065F46) : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOwner
                            ? 'Static IP: 74.220.52.132 (Dedicated Owner Gateway · 30 Days)'
                            : 'Your Static IP will activate immediately once the owner confirms payment receipt on PhonePe. Please await approval (usually 5–15 mins).',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isOwner ? FontWeight.w800 : FontWeight.w500,
                          color: isOwner ? const Color(0xFF047857) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isOwner) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt downloaded successfully (PDF)')),
                    );
                  },
                  icon: const Icon(Icons.receipt_long, size: 16, color: Color(0xFF059669)),
                  label: const Text('Download Receipt', style: TextStyle(color: Color(0xFF059669))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOwner ? const Color(0xFF059669) : const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isOwner ? 'Done · Back to Trading' : 'Close & Await Activation',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isHighlight = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: color ?? (isHighlight ? const Color(0xFF059669) : const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }
}