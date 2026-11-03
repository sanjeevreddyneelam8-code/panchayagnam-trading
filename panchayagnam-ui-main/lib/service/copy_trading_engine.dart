import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum CopySizingMode { lotMultiplier, capitalRatio, fixedQty }

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
  });

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
  }

  bool _isCopyTradingActive = true;
  bool get isCopyTradingActive => _isCopyTradingActive;

  final List<ChildAccountConfig> _accounts = [];
  List<ChildAccountConfig> get accounts => List.unmodifiable(_accounts);

  final List<CopyExecutionReceipt> _executionHistory = [];
  List<CopyExecutionReceipt> get executionHistory => List.unmodifiable(_executionHistory);

  ChildAccountConfig get masterAccount =>
      _accounts.firstWhere((a) => a.isMaster, orElse: () => _accounts.first);

  List<ChildAccountConfig> get childAccounts =>
      _accounts.where((a) => !a.isMaster).toList();

  List<ChildAccountConfig> get activeChildAccounts =>
      _accounts.where((a) => !a.isMaster && a.isActive).toList();

  int get totalAccountsCount => _accounts.length;
  int get activeFollowersCount => activeChildAccounts.length;

  double get pooledCapital =>
      _accounts.fold(0.0, (sum, a) => sum + a.balance);

  double get pooledPnl =>
      _accounts.fold(0.0, (sum, a) => sum + a.currentPnl);

  void _initDefaultAccounts() {
    _accounts.addAll([
      ChildAccountConfig(
        id: 'acc_dhan',
        name: 'Dhan Pro Master',
        broker: 'DHAN',
        clientId: '1100345678',
        isMaster: true,
        multiplier: 1.0,
        isActive: true,
        balance: 1000000.0,
        status: 'ONLINE',
      ),
      ChildAccountConfig(
        id: 'acc_zerodha',
        name: 'Zerodha Kite',
        broker: 'ZERODHA',
        clientId: 'ZR123456',
        isMaster: false,
        multiplier: 1.0,
        isActive: true,
        balance: 1000000.0,
        status: 'ONLINE',
      ),
      ChildAccountConfig(
        id: 'acc_upstox',
        name: 'Upstox Pro',
        broker: 'UPSTOX',
        clientId: 'UP654321',
        isMaster: false,
        multiplier: 1.0,
        isActive: true,
        balance: 1000000.0,
        status: 'ONLINE',
      ),
      ChildAccountConfig(
        id: 'acc_angel',
        name: 'AngelOne Demat',
        broker: 'ANGELONE',
        clientId: 'AG789012',
        isMaster: false,
        multiplier: 1.0,
        isActive: true,
        balance: 1000000.0,
        status: 'ONLINE',
      ),
      ChildAccountConfig(
        id: 'acc_motilal',
        name: 'Motilal Oswal',
        broker: 'MOTILAL',
        clientId: 'MO554433',
        isMaster: false,
        multiplier: 1.0,
        isActive: true,
        balance: 1000000.0,
        status: 'ONLINE',
      ),
      ChildAccountConfig(
        id: 'acc_profitmart',
        name: 'Profitmart Demat',
        broker: 'PROFITMART',
        clientId: 'PM998877',
        isMaster: false,
        multiplier: 1.0,
        isActive: true,
        balance: 1000000.0,
        status: 'ONLINE',
      ),
      ChildAccountConfig(
        id: 'acc_goodwill',
        name: 'Goodwill Giga',
        broker: 'GOODWILL',
        clientId: 'GW112233',
        isMaster: false,
        multiplier: 1.0,
        isActive: true,
        balance: 1000000.0,
        status: 'ONLINE',
      ),
      ChildAccountConfig(
        id: 'acc_groww',
        name: 'Groww Account',
        broker: 'GROWW',
        clientId: 'GR887766',
        isMaster: false,
        multiplier: 1.0,
        isActive: true,
        balance: 1000000.0,
        status: 'ONLINE',
      ),
    ]);
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
  }) async {
    final tradeId = 'COPY-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    final List<ReplicationLegResult> legs = [];
    final rand = math.Random();

    // 1. Execute Master Leg
    final master = masterAccount;
    final masterOrderId = '${master.broker.substring(0, 2)}-M-${DateTime.now().millisecondsSinceEpoch % 100000}';
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
      message: 'Master Order Executed Successfully',
    ));

    master.lastOrderId = masterOrderId;
    master.lastLatencyMs = masterLatency;
    master.totalCopiedOrders++;

    // 2. Execute Active Child Legs (if Copy Trading Active)
    int totalQty = baseQty;
    double totalCapital = masterAmount;
    int latencySum = masterLatency;

    if (_isCopyTradingActive) {
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
      totalAccountsTargeted: _isCopyTradingActive ? _accounts.length : 1,
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
