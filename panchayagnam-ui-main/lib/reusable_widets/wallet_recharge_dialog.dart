import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service/wallet_service.dart';

class WalletRechargeDialog extends StatefulWidget {
  final double requiredAmount;
  final VoidCallback? onRechargeSuccess;
  final String? customMessage;

  const WalletRechargeDialog({
    super.key,
    this.requiredAmount = 500.0,
    this.onRechargeSuccess,
    this.customMessage,
  });

  static Future<bool> show(
    BuildContext context, {
    double requiredAmount = 500.0,
    VoidCallback? onRechargeSuccess,
    String? customMessage,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WalletRechargeDialog(
        requiredAmount: requiredAmount,
        onRechargeSuccess: onRechargeSuccess,
        customMessage: customMessage,
      ),
    );
    return res ?? false;
  }

  @override
  State<WalletRechargeDialog> createState() => _WalletRechargeDialogState();
}

class _WalletRechargeDialogState extends State<WalletRechargeDialog> {
  late double _selectedAmount;
  final TextEditingController _customAmountCtrl = TextEditingController();
  final TextEditingController _utrCtrl = TextEditingController();
  bool _isProcessing = false;
  int _qrCountdown = 299; // 5 mins
  Timer? _countdownTimer;

  final List<int> _presetDemats = [1, 2, 3, 5, 10];

  @override
  void initState() {
    super.initState();
    _selectedAmount = widget.requiredAmount > 0 ? widget.requiredAmount : 500.0;
    _customAmountCtrl.text = _selectedAmount.toStringAsFixed(0);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          if (_qrCountdown > 0) {
            _qrCountdown--;
          } else {
            _qrCountdown = 299;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _customAmountCtrl.dispose();
    _utrCtrl.dispose();
    super.dispose();
  }

  void _onSelectDematCount(int count) {
    setState(() {
      _selectedAmount = count * WalletService.costPerDematSlot;
      _customAmountCtrl.text = _selectedAmount.toStringAsFixed(0);
    });
  }

  void _processRecharge() async {
    if (_selectedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a valid recharge amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final utr = _utrCtrl.text.trim().isNotEmpty
        ? _utrCtrl.text.trim()
        : 'UTR${DateTime.now().millisecondsSinceEpoch}';

    WalletService.instance.addFunds(
      _selectedAmount,
      method: 'PhonePe UPI QR',
      utr: utr,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    Navigator.pop(context, true);
    widget.onRechargeSuccess?.call();

    final dematSlots = (_selectedAmount / WalletService.costPerDematSlot).floor();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '✅ ₹${NumberFormat('#,##,##0').format(_selectedAmount)} added to wallet! You can now connect $dematSlots Demat account(s).',
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
  }

  @override
  Widget build(BuildContext context) {
    final mins = (_qrCountdown ~/ 60).toString().padLeft(2, '0');
    final secs = (_qrCountdown % 60).toString().padLeft(2, '0');
    final isOwner = WalletService.isOwner;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 24,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 660),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Add Money to Wallet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Text(
                                'AlgoDelta Rule',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.customMessage ??
                              'Like AlgoDelta, Demat accounts require sufficient wallet balance. One client can connect multiple accounts by adding ₹500 / account / month.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Owner Exemption Banner (if user is Owner)
              if (isOwner)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFFB45309), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '👑 Owner Mode (Bhaskar S): You have unlimited Demat accounts with ZERO wallet restriction! You can add accounts freely or test wallet recharge below.',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                          widget.onRechargeSuccess?.call();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFB45309),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        child: const Text('Bypass as Owner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              // Current Wallet Balance & Required Fee Notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: WalletService.instance.balanceNotifier,
                      builder: (context, balance, _) {
                        return Row(
                          children: [
                            const Text('Current Wallet Balance: ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            Text(
                              '₹${NumberFormat('#,##,##0.00').format(balance)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: balance >= 500 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_clock_rounded, size: 14, color: Color(0xFFDC2626)),
                          SizedBox(width: 4),
                          Text('Rate: ₹500.00 / Demat / Month', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Demat Accounts Multi-Pack Selector
              const Text('Select Number of Demat Accounts to Add Funds For:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _presetDemats.map((count) {
                    final packAmount = count * WalletService.costPerDematSlot;
                    final isSel = _selectedAmount == packAmount;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () => _onSelectDematCount(count),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 125,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFFECFDF5) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSel ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                              width: isSel ? 1.8 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$count Demat${count > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${NumberFormat('#,##,##0').format(packAmount)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: isSel ? const Color(0xFF059669) : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹500 / account',
                                style: TextStyle(fontSize: 9.5, color: isSel ? const Color(0xFF047857) : Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Two-column layout: QR Code on Left, Payment Details on Right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // QR Box
                  Container(
                    width: 190,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6739B7), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/panchayagnam_payment_qr.jpg',
                            width: 174,
                            height: 210,
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
                              style: const TextStyle(fontSize: 10, color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Payment Controls & UTR Verification
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6739B7).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 15, color: Color(0xFF7C3AED)),
                              SizedBox(width: 6),
                              Text('PANCHA YAGNAM INVESTMENTS', style: TextStyle(color: Color(0xFF6D28D9), fontSize: 11, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan QR code with PhonePe, Google Pay, Paytm, or BHIM to pay ₹${NumberFormat('#,##,##0').format(_selectedAmount)}.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                        ),
                        const SizedBox(height: 14),

                        // UTR Input
                        const Text('12-Digit UPI UTR Reference Number (Optional):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _utrCtrl,
                          maxLength: 12,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'e.g. 431829019284',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : _processRecharge,
                                icon: _isProcessing
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_circle_rounded, size: 16),
                                label: Text(
                                  _isProcessing ? 'Processing...' : 'Add ₹${NumberFormat('#,##,##0').format(_selectedAmount)} to Wallet',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
