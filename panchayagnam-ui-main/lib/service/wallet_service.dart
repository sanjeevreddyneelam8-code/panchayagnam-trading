import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';

class WalletTransaction {
  final String id;
  final String title;
  final String type; // 'CREDIT' or 'DEBIT'
  final double amount;
  final String date;
  final String status;
  final String? utr;

  WalletTransaction({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.date,
    this.status = 'COMPLETED',
    this.utr,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'amount': amount,
        'date': date,
        'status': status,
        if (utr != null) 'utr': utr,
      };

  factory WalletTransaction.fromJson(Map<String, dynamic> map) =>
      WalletTransaction(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        type: map['type'] ?? 'CREDIT',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        date: map['date'] ?? '',
        status: map['status'] ?? 'COMPLETED',
        utr: map['utr'],
      );
}

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  static WalletService get instance => _instance;

  static const double costPerDematSlot = 500.0;
  static const String _storageKeyBalance = 'py_wallet_balance_v3';
  static const String _storageKeyTxns = 'py_wallet_txns_v3';
  static const String _storageKeySimClient = 'py_wallet_sim_client_mode';

  final ValueNotifier<double> balanceNotifier = ValueNotifier<double>(0.0);
  final List<WalletTransaction> _transactions = [];

  bool _isSimulatedClientMode = false;

  WalletService._internal() {
    _loadFromStorage();
  }

  /// Whether simulated client mode is active (allows owner to test client wallet restriction)
  bool get isSimulatedClientMode => _isSimulatedClientMode;
  set isSimulatedClientMode(bool val) {
    _isSimulatedClientMode = val;
    try {
      html.window.localStorage[_storageKeySimClient] = val.toString();
    } catch (_) {}
  }

  /// Strictly checks if the active session belongs to the OWNER (Bhaskar S / Super Admin)
  static bool get isOwner {
    try {
      final role = (html.window.sessionStorage['user_role'] ?? '').toUpperCase().trim();
      final uid = (html.window.sessionStorage['user_id'] ?? '').trim();
      final cleanPhone = (html.window.sessionStorage['user_phoneNumber'] ??
              html.window.sessionStorage['user_phone'] ??
              '')
          .replaceAll(RegExp(r'\D'), '');
      final name = (html.window.sessionStorage['user_fullName'] ?? '').toLowerCase();

      // Owner credentials whitelist
      if (cleanPhone.endsWith('9553382135') || cleanPhone.contains('9553382135')) return true;
      if (name.contains('bhaskar')) return true;
      if (role == 'SUPER_ADMIN' || role == 'OWNER') return true;
      if (role != 'USER' && (uid == '1' || uid == '2')) return true;
    } catch (_) {}
    return false;
  }

  /// Returns true if the user is treated as Owner for wallet exemption (unless simulating client mode)
  bool get isOwnerExempt => isOwner && !_isSimulatedClientMode;

  double get balance => balanceNotifier.value;
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);

  void _loadFromStorage() {
    try {
      _isSimulatedClientMode =
          html.window.localStorage[_storageKeySimClient] == 'true';

      final storedBalance = html.window.localStorage[_storageKeyBalance];
      if (storedBalance != null && double.tryParse(storedBalance) != null) {
        balanceNotifier.value = double.parse(storedBalance);
      } else {
        // Default: If owner, balance is not restricted; if client, initial wallet is 0.00
        balanceNotifier.value = isOwner ? 15000.0 : 0.0;
      }

      final storedTxns = html.window.localStorage[_storageKeyTxns];
      if (storedTxns != null) {
        final decoded = jsonDecode(storedTxns);
        if (decoded is List) {
          _transactions.clear();
          for (final t in decoded) {
            if (t is Map<String, dynamic>) {
              _transactions.add(WalletTransaction.fromJson(t));
            }
          }
        }
      }
    } catch (_) {}
  }

  void _saveToStorage() {
    try {
      html.window.localStorage[_storageKeyBalance] = balanceNotifier.value.toString();
      final encoded = jsonEncode(_transactions.map((t) => t.toJson()).toList());
      html.window.localStorage[_storageKeyTxns] = encoded;
    } catch (_) {}
  }

  /// AlgoDelta Rule Check:
  /// Owner can add unlimited Demat accounts without adding money to wallet.
  /// Regular clients MUST have at least ₹500 in their wallet to add a Demat account.
  bool canAddDematAccount() {
    if (isOwnerExempt) {
      return true; // Owner is completely exempt!
    }
    return balanceNotifier.value >= costPerDematSlot;
  }

  /// Calculates how many additional Demat accounts client can currently add
  int get availableDematSlots {
    if (isOwnerExempt) return 999;
    return (balanceNotifier.value / costPerDematSlot).floor();
  }

  /// Deducts ₹500 from client's wallet for a Demat account slot.
  /// Owner is exempt (zero deduction).
  bool deductForDematAccount({
    required String broker,
    required String clientId,
    String? nickname,
  }) {
    if (isOwnerExempt) {
      // Owner privilege: No deduction required
      return true;
    }

    if (balanceNotifier.value >= costPerDematSlot) {
      balanceNotifier.value -= costPerDematSlot;
      final label = nickname != null && nickname.isNotEmpty ? nickname : '$broker $clientId';
      final txn = WalletTransaction(
        id: 'DEBIT_${DateTime.now().millisecondsSinceEpoch}',
        title: 'AlgoDelta Demat Slot Fee: $label',
        type: 'DEBIT',
        amount: costPerDematSlot,
        date: _formatCurrentDate(),
        status: 'CONFIRMED',
      );
      _transactions.insert(0, txn);
      _saveToStorage();
      return true;
    }
    return false;
  }

  /// Adds funds to wallet (e.g. via PhonePe QR / UPI)
  void addFunds(
    double amount, {
    String method = 'PhonePe UPI QR',
    String? utr,
  }) {
    balanceNotifier.value += amount;
    final txn = WalletTransaction(
      id: 'CREDIT_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Panchayagnam Wallet Deposit via $method',
      type: 'CREDIT',
      amount: amount,
      date: _formatCurrentDate(),
      status: 'CONFIRMED',
      utr: utr,
    );
    _transactions.insert(0, txn);
    _saveToStorage();
  }

  static String _formatCurrentDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
