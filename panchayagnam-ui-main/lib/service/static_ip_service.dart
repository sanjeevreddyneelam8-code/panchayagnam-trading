import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../reusable_widets/payment_gateway_dialog.dart';

/// Centralized state manager for Dedicated Static IP unlock and payment status.
/// Static IP is NOT visible upon initial login.
/// It becomes visible and active only AFTER payment, adding money to wallet,
/// or scanning the UPI QR code.
class StaticIpService {
  static const String staticIp = '13.235.14.89';
  static const String storageKey = 'has_paid_static_ip';

  static final ValueNotifier<bool> isUnlockedNotifier =
      ValueNotifier<bool>(_checkIsUnlocked());

  static bool _checkIsUnlocked() {
    try {
      final local = html.window.localStorage[storageKey];
      final session = html.window.sessionStorage[storageKey];
      return local == 'true' || session == 'true';
    } catch (_) {
      return false;
    }
  }

  static bool get isUnlocked => isUnlockedNotifier.value;

  static int get daysRemaining {
    try {
      final days = html.window.localStorage['static_ip_days'];
      if (days != null && int.tryParse(days) != null) {
        return int.parse(days);
      }
    } catch (_) {}
    return isUnlocked ? 30 : 0;
  }

  /// Mark Dedicated Static IP as unlocked & paid
  static void unlock({String plan = 'Dedicated Static IP', String? txnId}) {
    try {
      html.window.localStorage[storageKey] = 'true';
      html.window.sessionStorage[storageKey] = 'true';
      html.window.localStorage['static_ip_days'] = '30';
      html.window.localStorage['static_ip_plan'] = plan;
      if (txnId != null) {
        html.window.localStorage['static_ip_txn_id'] = txnId;
      }
    } catch (_) {}
    isUnlockedNotifier.value = true;
  }

  /// Lock Dedicated Static IP (used for test mode or reset)
  static void lock() {
    try {
      html.window.localStorage.remove(storageKey);
      html.window.sessionStorage.remove(storageKey);
      html.window.localStorage.remove('static_ip_days');
      html.window.localStorage.remove('static_ip_plan');
      html.window.localStorage.remove('static_ip_txn_id');
    } catch (_) {}
    isUnlockedNotifier.value = false;
  }

  /// Open Payment / QR Code / Wallet dialog to activate Dedicated Static IP
  static Future<void> showPaymentOrQrDialog(
    BuildContext context, {
    VoidCallback? onSuccess,
  }) async {
    await PaymentGatewayDialog.show(
      context,
      initialPlan: 'Dedicated Static IP',
      initialAmount: 1500.0,
      onPaymentSuccess: (amount, plan, txnId) {
        unlock(plan: plan, txnId: txnId);
        onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment verified ($txnId)! Dedicated Static IP $staticIp is now unlocked and visible.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      },
    );
  }
}
