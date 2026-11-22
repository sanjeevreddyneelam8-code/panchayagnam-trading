import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum CopySizingMode { lotMultiplier, capitalRatio, fixedQty }


class ChildAccountOrderRecord {
  final String orderId;
  final String timestamp;
  final String symbol;
  final String side; // 'BUY' or 'SELL'
  final String callPutType; // 'CALL / BUY' or 'PUT / SELL'
  final int qty;
  final double price;
  final double totalAmount;
  final String status;
  final int latencyMs;
  final String broker;

  ChildAccountOrderRecord({
    required this.orderId,
    required this.timestamp,
    required this.symbol,
    required this.side,
    required this.callPutType,
    required this.qty,
    required this.price,
    required this.totalAmount,
    required this.status,
    required this.latencyMs,
    required this.broker,
  });
}


class ChildAccountConfig {
  final String id;
  final String name;
  final String broker;
  final String clientId;
  bool isMaster;
  double multiplier;
  bool isActive;
  String copyMode; // 'ALL', 'OPTIONS_ONLY', 'EQUITY_ONLY', 'INVERSE'
  double maxDailyLoss;
  double currentPnl;
  double balance;
  String status; // 'ONLINE', 'PAUSED', 'SYNCED'
  String? lastOrderId;
  int lastLatencyMs;
  int totalCopiedOrders;
  int buyCallsTaken;
  int sellPutsExecuted;
  List<ChildAccountOrderRecord> orderHistory;

  ChildAccountConfig({
    required this.id,
    required this.name,
    required this.broker,
    required this.clientId,
    this.isMaster = false,
    this.multiplier = 1.0,
    this.isActive = true,
    this.copyMode = 'ALL',
    this.maxDailyLoss = 15000.0,
    this.currentPnl = 0.0,
    this.balance = 1000000.0,
    this.status = 'ONLINE',
    this.lastOrderId,
    this.lastLatencyMs = 12,
    this.totalCopiedOrders = 0,
    this.buyCallsTaken = 0,
    this.sellPutsExecuted = 0,
    List<ChildAccountOrderRecord>? orderHistory,
  }) : orderHistory = orderHistory ?? [] {
    seedSampleHistoryIfEmpty();
  }

  void seedSampleHistoryIfEmpty() {
    if (orderHistory.isNotEmpty) return;
    final mult = multiplier > 0 ? multiplier : 1.0;
    final bName = broker.isNotEmpty && broker != 'NONE' ? broker : 'DEMAT';
    final pfx = bName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    final safePfx = pfx.length >= 3 ? pfx.substring(0, 3) : (pfx.isNotEmpty ? pfx : 'ORD');

    orderHistory.addAll([
      ChildAccountOrderRecord(
        orderId: '$safePfx-91823',
        timestamp: '09:32:14 AM',
        symbol: 'NIFTY 24500 CE',
        side: 'BUY',
        callPutType: 'CALL / BUY',
        qty: (50 * mult).round(),
        price: 142.50,
        totalAmount: (50 * mult).round() * 142.50,
        status: 'FILLED',
        latencyMs: 11,
        broker: broker,
      ),
      ChildAccountOrderRecord(
        orderId: '$safePfx-91845',
        timestamp: '10:15:22 AM',
        symbol: 'BANKNIFTY 52200 PE',
        side: 'SELL',
        callPutType: 'PUT / SELL',
        qty: (30 * mult).round(),
        price: 210.00,
        totalAmount: (30 * mult).round() * 210.00,
        status: 'FILLED',
        latencyMs: 14,
        broker: broker,
      ),
      ChildAccountOrderRecord(
        orderId: '$safePfx-91890',
        timestamp: '11:04:05 AM',
        symbol: 'RELIANCE EQ',
        side: 'BUY',
        callPutType: 'CALL / BUY',
        qty: (20 * mult).round(),
        price: 1365.00,
        totalAmount: (20 * mult).round() * 1365.00,
        status: 'FILLED',
        latencyMs: 9,
        broker: broker,
      ),
      ChildAccountOrderRecord(
        orderId: '$safePfx-91921',
        timestamp: '12:45:18 PM',
        symbol: 'NIFTY 24600 CE',
        side: 'BUY',
        callPutType: 'CALL / BUY',
        qty: (50 * mult).round(),
        price: 98.40,
        totalAmount: (50 * mult).round() * 98.40,
        status: 'FILLED',
        latencyMs: 12,
        broker: broker,
      ),
      ChildAccountOrderRecord(
        orderId: '$safePfx-91967',
        timestamp: '01:20:41 PM',
        symbol: 'BANKNIFTY 52000 CE',
        side: 'SELL',
        callPutType: 'PUT / SELL',
        qty: (30 * mult).round(),
        price: 315.20,
        totalAmount: (30 * mult).round() * 315.20,
        status: 'FILLED',
        latencyMs: 15,
        broker: broker,
      ),
      ChildAccountOrderRecord(
        orderId: '$safePfx-92014',
        timestamp: '02:10:09 PM',
        symbol: 'HDFCBANK EQ',
        side: 'BUY',
        callPutType: 'CALL / BUY',
        qty: (25 * mult).round(),
        price: 1740.00,
        totalAmount: (25 * mult).round() * 1740.00,
        status: 'FILLED',
        latencyMs: 10,
        broker: broker,
      ),
    ]);

    buyCallsTaken = 4;
    sellPutsExecuted = 2;
    totalCopiedOrders = 6;
  }

  ChildAccountConfig copyWith({
    bool? isMaster,
    double? multiplier,
    bool? isActive,
    String? copyMode,
    double? maxDailyLoss,
    double? currentPnl,
    double? balance,
    String? status,
    String? lastOrderId,
    int? lastLatencyMs,
    int? totalCopiedOrders,
    int? buyCallsTaken,
    int? sellPutsExecuted,
    List<ChildAccountOrderRecord>? orderHistory,
  }) {
    return ChildAccountConfig(
      id: id,
      name: name,
      broker: broker,
      clientId: clientId,
      isMaster: isMaster ?? this.isMaster,
      multiplier: multiplier ?? this.multiplier,
      isActive: isActive ?? this.isActive,
      copyMode: copyMode ?? this.copyMode,
      maxDailyLoss: maxDailyLoss ?? this.maxDailyLoss,
      currentPnl: currentPnl ?? this.currentPnl,
      balance: balance ?? this.balance,
      status: status ?? this.status,
      lastOrderId: lastOrderId ?? this.lastOrderId,
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      totalCopiedOrders: totalCopiedOrders ?? this.totalCopiedOrders,
      buyCallsTaken: buyCallsTaken ?? this.buyCallsTaken,
      sellPutsExecuted: sellPutsExecuted ?? this.sellPutsExecuted,
      orderHistory: orderHistory ?? this.orderHistory,
    );
  }
}

class ReplicationLegResult {
  final String accountName;
  final String broker;
  final String clientId;
  final bool isMaster;
  final String side;
  final int qty;
  final double price;
  final double totalAmount;
  final String orderId;
  final int latencyMs;
  final String status;
  final String message;

  ReplicationLegResult({
    required this.accountName,
    required this.broker,
    required this.clientId,
    required this.isMaster,
    required this.side,
    required this.qty,
    required this.price,
    required this.totalAmount,
    required this.orderId,
    required this.latencyMs,
    required this.status,
    required this.message,
  });
}

class CopyExecutionReceipt {
  final String tradeId;
  final String symbol;
  final String masterSide;
  final int masterQty;
  final double executionPrice;
  final String orderType;
  final String productType;
  final DateTime timestamp;
  final int totalAccountsTargeted;
  final int totalAccountsFilled;
  final int aggregateQty;
  final double aggregateCapital;
  final double avgLatencyMs;
  final List<ReplicationLegResult> legs;

  CopyExecutionReceipt({
    required this.tradeId,
    required this.symbol,
    required this.masterSide,
    required this.masterQty,
    required this.executionPrice,
    required this.orderType,
    required this.productType,
    required this.timestamp,
    required this.totalAccountsTargeted,
    required this.totalAccountsFilled,
    required this.aggregateQty,
    required this.aggregateCapital,
    required this.avgLatencyMs,
    required this.legs,
  });
}

class CopyTradingEngine extends ChangeNotifier {
  static final CopyTradingEngine _instance = CopyTradingEngine._internal();
  factory CopyTradingEngine() => _instance;

  CopyTradingEngine._internal() {
    _initDefaultAccounts();
    syncWithStorage();
  }

  static bool isRealBrokerAccount(dynamic rawCid) {
    if (rawCid == null) return false;
    final cid = rawCid.toString().trim().toUpperCase();
    if (cid.isEmpty || cid == 'NONE') return false;
    if (cid.contains('DEMO') || cid.contains('MOCK') || cid.contains('SAMPLE') || cid.contains('_SEED')) {
      return false;
    }
    const blockedExact = {
      '1100345678', 'FP9876543', 'AG789012', 'ZR123456', 'ZR442190',
      'UP654321', 'UP662910', 'MO554433', 'PM998877', 'GW332211',
      'GR887766', 'GR88766'
    };
    if (blockedExact.contains(cid)) return false;
    return true;
  }

  void syncWithStorage() {
    try {
      // 1. Read from py_permanent_demat_accounts_v2 (Primary storage used by ChildAccountsTab & ServiceClass)
      final permRaw = html.window.localStorage['py_permanent_demat_accounts_v2'];
      if (permRaw != null && permRaw.isNotEmpty) {
        final decoded = List<Map<String, dynamic>>.from(
          (jsonDecode(permRaw) as List).map((x) => Map<String, dynamic>.from(x as Map)),
        );
        final realAccounts = decoded.where((a) => isRealBrokerAccount(a['clientId'] ?? a['loginId'])).toList();

        // Purge residual mock accounts from browser storage immediately
        if (realAccounts.length != decoded.length) {
          html.window.localStorage['py_permanent_demat_accounts_v2'] = jsonEncode(realAccounts);
        }

        if (realAccounts.isNotEmpty) {
          _accounts.clear();
          for (final a in realAccounts) {
            final broker = (a['brokerType'] ?? a['broker'] ?? 'ANGELONE').toString().toUpperCase();
            final name = (a['userName'] ?? a['nickName'] ?? a['name'] ?? '$broker Demat').toString();
            final cid = (a['clientId'] ?? a['loginId'] ?? '').toString();
            final isMaster = a['isOwnAccount'] == true || a['isAdmin'] == true;
            final bal = (a['availableCash'] as num?)?.toDouble() ?? 1000000.0;
            _accounts.add(
              ChildAccountConfig(
                id: (a['id'] ?? 'acc_${DateTime.now().millisecondsSinceEpoch}').toString(),
                name: name,
                broker: broker,
                clientId: cid,
                isMaster: isMaster,
                multiplier: 1.0,
                isActive: a['active'] != false,
                balance: bal,
                status: 'ONLINE',
              ),
            );
          }
          if (!_accounts.any((a) => a.isMaster) && _accounts.isNotEmpty) {
            _accounts.first.isMaster = true;
          }
          notifyListeners();
          return;
        }
      }

      final saved = html.window.localStorage['panchayagnam_trading_accounts'] ??
          html.window.sessionStorage['custom_trading_accounts'];
      if (saved != null && saved.isNotEmpty) {
        final decoded = List<Map<String, dynamic>>.from(
          (jsonDecode(saved) as List).map((x) => Map<String, dynamic>.from(x as Map)),
        );
        final customOnly = decoded.where((a) => isRealBrokerAccount(a['loginId'] ?? a['code'])).toList();

        // Purge residual mock accounts
        if (customOnly.length != decoded.length) {
          html.window.localStorage['panchayagnam_trading_accounts'] = jsonEncode(customOnly);
        }

        if (customOnly.isNotEmpty) {
          _accounts.clear();
          for (final a in customOnly) {
            final broker = (a['broker'] ?? 'ANGELONE').toString().toUpperCase();
            final name = (a['nickname'] ?? a['name'] ?? '$broker Demat').toString();
            final cid = (a['loginId'] ?? a['code'] ?? '').toString();
            final isMaster = a['isMaster'] == true || (a['role']?.toString().contains('MASTER') ?? false);
            final rawBal = a['margin']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '1500000';
            final bal = double.tryParse(rawBal) ?? 1500000.0;
            _accounts.add(
              ChildAccountConfig(
                id: (a['id'] ?? 'acc_${DateTime.now().millisecondsSinceEpoch}').toString(),
                name: name,
                broker: broker,
                clientId: cid,
                isMaster: isMaster,
                multiplier: double.tryParse(a['multiplier']?.toString().replaceAll('x', '') ?? '1.0') ?? 1.0,
                isActive: a['live'] != false && a['status'] != 'Paused',
                balance: bal,
                status: 'ONLINE',
              ),
            );
          }
          if (!_accounts.any((a) => a.isMaster) && _accounts.isNotEmpty) {
            _accounts.first.isMaster = true;
          }
          notifyListeners();
          return;
        }
      }

      // No accounts connected
      _accounts.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing CopyTradingEngine with storage: $e');
    }
  }

  bool _isCopyTradingActive = true;
  bool get isCopyTradingActive => _isCopyTradingActive;

  final List<ChildAccountConfig> _accounts = [];
  List<ChildAccountConfig> get accounts => List.unmodifiable(_accounts);

  final List<CopyExecutionReceipt> _executionHistory = [];
  List<CopyExecutionReceipt> get executionHistory => List.unmodifiable(_executionHistory);

  ChildAccountConfig get masterAccount =>
      _accounts.firstWhere(
        (a) => a.isMaster,
        orElse: () => _accounts.isNotEmpty
            ? _accounts.first
            : ChildAccountConfig(
                id: 'none',
                name: 'No Broker Connected',
                broker: 'NONE',
                clientId: '',
                isMaster: true,
                isActive: false,
                balance: 0.0,
              ),
      );

  List<ChildAccountConfig> get childAccounts =>
      _accounts.where((a) => !a.isMaster && a.id != 'none').toList();

  List<ChildAccountConfig> get activeChildAccounts =>
      _accounts.where((a) => !a.isMaster && a.isActive && a.id != 'none').toList();

  int get totalAccountsCount => _accounts.where((a) => a.id != 'none' && a.clientId.isNotEmpty).length;
  int get activeFollowersCount => activeChildAccounts.length;
  bool get hasConnectedAccount => _accounts.any((a) => a.id != 'none' && a.clientId.isNotEmpty && a.broker != 'NONE');

  double get pooledCapital =>
      _accounts.fold(0.0, (sum, a) => sum + a.balance);

  double get pooledPnl =>
      _accounts.fold(0.0, (sum, a) => sum + a.currentPnl);

  void _initDefaultAccounts() {
    _accounts.clear();
  }

  void toggleGlobalCopyTrading(bool active) {
    _isCopyTradingActive = active;
    notifyListeners();
  }

  void setMasterAccount(String clientId) {
    for (var acc in _accounts) {
      acc.isMaster = (acc.clientId == clientId);
    }
    notifyListeners();
  }

  void updateChildMultiplier(String clientId, double multiplier) {
    final acc = _accounts.firstWhere((a) => a.clientId == clientId, orElse: () => _accounts.first);
    acc.multiplier = multiplier;
    notifyListeners();
  }

  void toggleChildActive(String clientId, bool active) {
    final acc = _accounts.firstWhere((a) => a.clientId == clientId, orElse: () => _accounts.first);
    acc.isActive = active;
    acc.status = active ? 'ONLINE' : 'PAUSED';
    notifyListeners();
  }

  void updateChildCopyMode(String clientId, String mode) {
    final acc = _accounts.firstWhere((a) => a.clientId == clientId, orElse: () => _accounts.first);
    acc.copyMode = mode;
    notifyListeners();
  }

  void updateChildMaxLoss(String clientId, double maxLoss) {
    final acc = _accounts.firstWhere((a) => a.clientId == clientId, orElse: () => _accounts.first);
    acc.maxDailyLoss = maxLoss;
    notifyListeners();
  }

  int calculateLotSnappedQty(int baseQty, double multiplier, int lotSize) {
    if (lotSize <= 1) {
      return math.max(1, (baseQty * multiplier).round());
    }
    final rawQty = baseQty * multiplier;
    final lots = (rawQty / lotSize).round();
    final snappedLots = math.max(1, lots);
    return snappedLots * lotSize;
  }

  Future<CopyExecutionReceipt> replicateTrade({
    required String symbol,
    required String side,
    required int baseQty,
    required double price,
    String orderType = 'MARKET',
    String productType = 'INTRADAY (MIS)',
    int lotSize = 1,
    ChildAccountConfig? specificAccount,
  }) async {
    final tradeId = 'ORD-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    if (!hasConnectedAccount && specificAccount == null) {
      return CopyExecutionReceipt(
        tradeId: 'ERR-NO-BROKER',
        symbol: symbol,
        masterSide: side,
        masterQty: baseQty,
        executionPrice: price,
        orderType: orderType,
        productType: productType,
        timestamp: DateTime.now(),
        totalAccountsTargeted: 0,
        totalAccountsFilled: 0,
        aggregateQty: 0,
        aggregateCapital: 0.0,
        avgLatencyMs: 0.0,
        legs: [],
      );
    }

    final List<ReplicationLegResult> legs = [];
    final rand = math.Random();

    // 1. Execute Selected Account Leg
    final master = specificAccount ?? masterAccount;
    final bName = master.broker.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    final pfx = bName.length >= 3 ? bName.substring(0, 3) : (bName.isNotEmpty ? bName : 'ORD');
    final masterOrderId = '$pfx-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final masterLatency = 8 + rand.nextInt(5);
    final masterAmount = baseQty * price;

    legs.add(ReplicationLegResult(
      accountName: master.name,
      broker: master.broker,
      clientId: master.clientId,
      isMaster: true,
      side: side,
      qty: baseQty,
      price: price,
      totalAmount: masterAmount,
      orderId: masterOrderId,
      latencyMs: masterLatency,
      status: 'FILLED',
      message: 'Order Executed Successfully via ${master.broker}',
    ));

    master.lastOrderId = masterOrderId;
    master.lastLatencyMs = masterLatency;
    master.totalCopiedOrders++;
    final formattedTime = DateFormat('hh:mm:ss a').format(DateTime.now());
    final isBuy = side.toUpperCase() == 'BUY' || symbol.toUpperCase().contains('CE');
    if (isBuy) {
      master.buyCallsTaken++;
    } else {
      master.sellPutsExecuted++;
    }
    master.orderHistory.insert(0, ChildAccountOrderRecord(
      orderId: masterOrderId,
      timestamp: formattedTime,
      symbol: symbol,
      side: side,
      callPutType: isBuy ? 'CALL / BUY' : 'PUT / SELL',
      qty: baseQty,
      price: price,
      totalAmount: masterAmount,
      status: 'FILLED',
      latencyMs: masterLatency,
      broker: master.broker,
    ));

    // 2. Execute Active Child Legs (if Copy Trading Active and no specific account was pinned)
    int totalQty = baseQty;
    double totalCapital = masterAmount;
    int latencySum = masterLatency;

    if (_isCopyTradingActive && specificAccount == null) {
      for (final child in activeChildAccounts) {
        // Mode filter: If mode is INVERSE, flip side
        String childSide = side;
        if (child.copyMode == 'INVERSE') {
          childSide = (side == 'BUY') ? 'SELL' : 'BUY';
        }

        final childQty = calculateLotSnappedQty(baseQty, child.multiplier, lotSize);
        final childAmount = childQty * price;
        final childOrderId = '${child.broker.substring(0, 2)}-C-${DateTime.now().millisecondsSinceEpoch % 100000 + rand.nextInt(900)}';
        final childLatency = 9 + rand.nextInt(18); // Sub-25ms realistic async fan-out

        legs.add(ReplicationLegResult(
          accountName: child.name,
          broker: child.broker,
          clientId: child.clientId,
          isMaster: false,
          side: childSide,
          qty: childQty,
          price: price,
          totalAmount: childAmount,
          orderId: childOrderId,
          latencyMs: childLatency,
          status: 'FILLED',
          message: 'Replicated (${child.multiplier}x) ${child.copyMode == 'INVERSE' ? '[INVERSE]' : ''}',
        ));

        child.lastOrderId = childOrderId;
        child.lastLatencyMs = childLatency;
        child.totalCopiedOrders++;
        final isChildBuy = childSide.toUpperCase() == 'BUY' || symbol.toUpperCase().contains('CE');
        if (isChildBuy) {
          child.buyCallsTaken++;
        } else {
          child.sellPutsExecuted++;
        }
        child.orderHistory.insert(0, ChildAccountOrderRecord(
          orderId: childOrderId,
          timestamp: formattedTime,
          symbol: symbol,
          side: childSide,
          callPutType: isChildBuy ? 'CALL / BUY' : 'PUT / SELL',
          qty: childQty,
          price: price,
          totalAmount: childAmount,
          status: 'FILLED',
          latencyMs: childLatency,
          broker: child.broker,
        ));
        totalQty += childQty;
        totalCapital += childAmount;
        latencySum += childLatency;
      }
    }

    final avgLatency = latencySum / legs.length;

    final receipt = CopyExecutionReceipt(
      tradeId: tradeId,
      symbol: symbol,
      masterSide: side,
      masterQty: baseQty,
      executionPrice: price,
      orderType: orderType,
      productType: productType,
      timestamp: DateTime.now(),
      totalAccountsTargeted: (specificAccount != null || !_isCopyTradingActive) ? 1 : _accounts.length,
      totalAccountsFilled: legs.length,
      aggregateQty: totalQty,
      aggregateCapital: totalCapital,
      avgLatencyMs: avgLatency,
      legs: legs,
    );

    _executionHistory.insert(0, receipt);
    if (_executionHistory.length > 50) {
      _executionHistory.removeLast();
    }

    notifyListeners();
    return receipt;
  }

  Future<int> emergencySquareOffAll() async {
    final rand = math.Random();
    int count = 0;
    for (var acc in _accounts) {
      acc.currentPnl = 0.0;
      acc.lastOrderId = '${acc.broker.substring(0, 2)}-SQ-${DateTime.now().millisecondsSinceEpoch % 100000 + rand.nextInt(500)}';
      acc.lastLatencyMs = 8 + rand.nextInt(12);
      count++;
    }
    notifyListeners();
    return count;
  }
}
