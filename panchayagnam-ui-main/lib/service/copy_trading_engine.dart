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
    const seededBrokers = [
      ('acc_dhan', 'Dhan Pro Master', 'DHAN', '1100345678', true, 2500000.0),
      ('acc_zerodha', 'Zerodha Kite', 'ZERODHA', 'ZR123456', false, 2000000.0),
      ('acc_upstox', 'Upstox Pro', 'UPSTOX', 'UP654321', false, 1250000.0),
      ('acc_angel', 'AngelOne Demat', 'ANGELONE', 'AG789012', false, 1500000.0),
      ('acc_motilal', 'Motilal Oswal', 'MOTILAL', 'MO554433', false, 1800000.0),
      ('acc_profitmart', 'Profitmart Demat', 'PROFITMART', 'PM998877', false, 800000.0),
      ('acc_goodwill', 'Goodwill Giga', 'GOODWILL', 'GW112233', false, 850000.0),
      ('acc_groww', 'Groww Direct', 'GROWW', 'GR887766', false, 750000.0),
      ('acc_fyers', 'Fyers API v3', 'FYERS', 'FY773120', false, 1000000.0),
      ('acc_kotak', 'Kotak Neo Pro', 'KOTAKNEO', 'KT992140', false, 1100000.0),
      ('acc_alice', 'Alice Blue ANT', 'ALICEBLUE', 'AL102930', false, 950000.0),
      ('acc_5paisa', '5Paisa Xstream', 'FIVEPAISA', 'FP663210', false, 650000.0),
      ('acc_icici', 'ICICI Direct Breeze', 'ICICIDIRECT', 'IC441122', false, 2200000.0),
      ('acc_hdfc', 'HDFC Sky Prime', 'HDFCSKY', 'HD552233', false, 1600000.0),
      ('acc_axis', 'Axis Direct OpenAPI', 'AXISDIRECT', 'AX663344', false, 1400000.0),
      ('acc_sbi', 'SBI Securities Smart', 'SBISEC', 'SB774455', false, 1200000.0),
      ('acc_sharekhan', 'Sharekhan Espresso', 'SHAREKHAN', 'SK885566', false, 900000.0),
      ('acc_iifl', 'IIFL Blaze API', 'IIFL', 'II996677', false, 1050000.0),
      ('acc_paytm', 'Paytm Money OpenAPI', 'PAYTMMONEY', 'PT107788', false, 600000.0),
      ('acc_shoonya', 'Shoonya Finvasia', 'SHOONYA', 'SH208899', false, 1150000.0),
      ('acc_flattrade', 'Flattrade Pi Zero', 'FLATTRADE', 'FL309900', false, 700000.0),
      ('acc_nuvama', 'Nuvama WealthTech', 'NUVAMA', 'NV410011', false, 3000000.0),
      ('acc_anandrathi', 'Anand Rathi TradeXp', 'ANANDRATHI', 'AR511122', false, 1300000.0),
      ('acc_choice', 'Choice Broking Jiffy', 'CHOICE', 'CH612233', false, 720000.0),
      ('acc_samco', 'Samco StockNote', 'SAMCO', 'SM713344', false, 880000.0),
      ('acc_espresso', 'Espresso TurboAPI', 'ESPRESSO', 'ES814455', false, 550000.0),
      ('acc_firstock', 'Firstock Connect', 'FIRSTOCK', 'FS915566', false, 680000.0),
      ('acc_tradejini', 'Tradejini CubePlus', 'TRADEJINI', 'TJ126677', false, 920000.0),
      ('acc_jainam', 'Jainam Duck Pro', 'JAINAM', 'JN227788', false, 1450000.0),
      ('acc_mastertrust', 'MasterTrust Swift', 'MASTERTRUST', 'MT328899', false, 1000000.0),
      ('acc_smc', 'SMC Global Ace', 'SMCGLOBAL', 'MC429900', false, 1120000.0),
      ('acc_bajaj', 'Bajaj Broking Connect', 'BAJAJ', 'BJ530011', false, 960000.0),
      ('acc_rmoney', 'RMoney Quickso API', 'RMONEY', 'RM631122', false, 640000.0),
      ('acc_aditya', 'Aditya Birla Money', 'ADITYABIRLA', 'AB732233', false, 1280000.0),
      ('acc_stoxkart', 'Stoxkart Pro Desk', 'STOXKART', 'SX833344', false, 590000.0),
    ];

    for (final b in seededBrokers) {
      _accounts.add(
        ChildAccountConfig(
          id: b.$1,
          name: b.$2,
          broker: b.$3,
          clientId: b.$4,
          isMaster: b.$5,
          multiplier: 1.0,
          isActive: true,
          balance: b.$6,
          status: 'ONLINE',
        ),
      );
    }
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
