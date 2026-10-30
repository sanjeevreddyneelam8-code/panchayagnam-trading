import 'dart:async';
import 'dart:convert';
import 'package:easy_trade_web/bloc/individual_dropdown_bloc/individual_drop_down_state.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../bloc/individual_bloc/individual_execution_bloc.dart';
import '../../../bloc/individual_dropdown_bloc/individual_drop_down_bloc.dart';
import '../../../bloc/individual_dropdown_bloc/individual_drop_down_event.dart';
import '../../../constants/api_url_constants.dart';
import '../../../models/ScripInfo.dart';
import '../../../models/individual_drop_downmodel.dart';
import '../../../models/ws_holding.dart';
import '../../../reusable_widets/hot_stocks_widget.dart';
import '../../../reusable_widets/order_panel_widget.dart';
import '../../../reusable_widets/shimmer_box_widget.dart';
import '../../../reusable_widets/stock_search_widget.dart';
import '../../../service/individual_drop_down_service.dart';
import 'dart:html' as html;

// ─────────────────────────────────────────────────────────────────────────────
//  HOW EACH BROKER HANDLES VARIETY
// ─────────────────────────────────────────────────────────────────────────────

String resolveVariety(String rawVariety, String brokerKey) {
  final v = rawVariety.trim().toUpperCase();
  switch (brokerKey.toUpperCase()) {
    case 'ANGELONE':
      const angelValid = {'NORMAL', 'STOPLOSS', 'AMO', 'ROBO'};
      return angelValid.contains(v) ? v : 'NORMAL';
    case 'MOTILAL':
      if (v == 'AMO') return 'AMO';
      if (v == 'REGULAR' || v == 'NORMAL') return 'REGULAR';
      return 'REGULAR';
    case 'DHAN':
      const dhanValid = {'NORMAL', 'STOPLOSS'};
      return dhanValid.contains(v) ? v : 'NORMAL';
    case 'PROFITMART':
      const pmValid = {'NORMAL', 'STOPLOSS', 'AMO', 'ROBO'};
      return pmValid.contains(v) ? v : 'NORMAL';
    case 'GOODWILL':
      const gwValid = {'NORMAL', 'STOPLOSS', 'AMO'};
      return gwValid.contains(v) ? v : 'NORMAL';
    default:
      return 'NORMAL';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════════════════════════

class WsPosition {
  final String tradingSymbol;
  final String exchange;
  final String token;
  final int netQty;
  final int buyQty;
  final int sellQty;
  final double avgPrice;
  final double ltp;
  final double pnl;
  final double pnlPercent;
  final double dayChange;
  final double investedValue;
  final double currentValue;
  final String productType;

  const WsPosition({
    required this.tradingSymbol,
    required this.exchange,
    required this.token,
    required this.netQty,
    required this.buyQty,
    required this.sellQty,
    required this.avgPrice,
    required this.ltp,
    required this.pnl,
    required this.pnlPercent,
    required this.dayChange,
    required this.investedValue,
    required this.currentValue,
    required this.productType,
  });

  factory WsPosition.fromJson(Map<String, dynamic> json) => WsPosition(
    tradingSymbol: (json['tradingsymbol'] as String?) ?? '',
    exchange: (json['exchange'] as String?) ?? 'NSE',
    token: (json['token'] as String?) ?? '',
    netQty: (json['netQty'] as num?)?.toInt() ?? 0,
    buyQty: (json['buyQty'] as num?)?.toInt() ?? 0,
    sellQty: (json['sellQty'] as num?)?.toInt() ?? 0,
    avgPrice: (json['avgPrice'] as num?)?.toDouble() ?? 0.0,
    ltp: (json['ltp'] as num?)?.toDouble() ?? 0.0,
    pnl: (json['pnl'] as num?)?.toDouble() ?? 0.0,
    pnlPercent: (json['pnlPercent'] as num?)?.toDouble() ?? 0.0,
    dayChange: (json['dayChange'] as num?)?.toDouble() ?? 0.0,
    investedValue: (json['investedValue'] as num?)?.toDouble() ?? 0.0,
    currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0.0,
    productType: (json['productType'] as String?) ?? '',
  );
}

class WsPortfolio {
  final double totalInvested;
  final double totalCurrentValue;
  final double totalPnl;
  final double totalPnlPercent;
  final double todayProfit;
  final double todayLoss;
  final double totalDayChange;
  final double totalDayChangePercent;

  const WsPortfolio({
    required this.totalInvested,
    required this.totalCurrentValue,
    required this.totalPnl,
    required this.totalPnlPercent,
    required this.todayProfit,
    this.todayLoss = 0.0,
    this.totalDayChange = 0.0,
    this.totalDayChangePercent = 0.0,
  });

  double get netTodayChange => todayProfit + todayLoss;
}

class WsHoldingExtra {
  final WsHolding base;
  final double todayPnl;
  final double todayPnlPercent;
  final double closePrice;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final int volume;

  const WsHoldingExtra({
    required this.base,
    required this.todayPnl,
    required this.todayPnlPercent,
    required this.closePrice,
    this.openPrice = 0.0,
    this.highPrice = 0.0,
    this.lowPrice = 0.0,
    this.volume = 0,
  });

  factory WsHoldingExtra.fromJson(Map<String, dynamic> json) => WsHoldingExtra(
    base: WsHolding.fromJson(json),
    todayPnl: (json['todayPnl'] as num?)?.toDouble() ?? 0.0,
    todayPnlPercent: (json['todayPnlPercent'] as num?)?.toDouble() ?? 0.0,
    closePrice: (json['closePrice'] as num?)?.toDouble() ?? 0.0,
    openPrice: (json['openPrice'] as num?)?.toDouble() ?? 0.0,
    highPrice: (json['highPrice'] as num?)?.toDouble() ?? 0.0,
    lowPrice: (json['lowPrice'] as num?)?.toDouble() ?? 0.0,
    volume: (json['volume'] as num?)?.toInt() ?? 0,
  );

  String get tradingSymbol => base.tradingSymbol;
  String get token => base.token;
  int get quantity => base.quantity;
  double get avgPrice => base.avgPrice;
  double get ltp => base.ltp;
  double get pnl => base.pnl;
  double get pnlPercent => base.pnlPercent;
  double get dayChange => base.dayChange;
  double get investedValue => base.investedValue;
  double get currentValue => base.currentValue;
}

class PositionsSummary {
  final int count;
  final double totalPnl;

  const PositionsSummary({required this.count, required this.totalPnl});

  factory PositionsSummary.fromJson(Map<String, dynamic> json) =>
      PositionsSummary(
        count: (json['count'] as num?)?.toInt() ?? 0,
        totalPnl: (json['totalPnl'] as num?)?.toDouble() ?? 0.0,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  BROKER ENUM  — GOODWILL added
// ══════════════════════════════════════════════════════════════════════════════

enum _Broker { angelOne, motilal, dhan, profitMart, goodWill }

extension _BrokerExt on _Broker {
  String get label {
    switch (this) {
      case _Broker.angelOne:
        return 'Angel One';
      case _Broker.motilal:
        return 'Motilal Oswal';
      case _Broker.dhan:
        return 'Dhan';
      case _Broker.profitMart:
        return 'Profit Mart';
      case _Broker.goodWill:
        return 'Goodwill';
    }
  }

  String get initials {
    switch (this) {
      case _Broker.angelOne:
        return 'AO';
      case _Broker.motilal:
        return 'MO';
      case _Broker.dhan:
        return 'DH';
      case _Broker.profitMart:
        return 'PM';
      case _Broker.goodWill:
        return 'GW';
    }
  }

  Color get brandColor {
    switch (this) {
      case _Broker.angelOne:
        return const Color(0xFFE53E3E);
      case _Broker.motilal:
        return const Color(0xFF2563EB);
      case _Broker.dhan:
        return const Color(0xFF7C3AED);
      case _Broker.profitMart:
        return const Color(0xFF059669);
      case _Broker.goodWill:
        return const Color(0xFFD97706); // amber/orange
    }
  }

  String get brokerKey {
    switch (this) {
      case _Broker.angelOne:
        return 'ANGELONE';
      case _Broker.motilal:
        return 'MOTILAL';
      case _Broker.dhan:
        return 'DHAN';
      case _Broker.profitMart:
        return 'PROFITMART';
      case _Broker.goodWill:
        return 'GOODWILL';
    }
  }

  List<String> get varieties {
    switch (this) {
      case _Broker.angelOne:
        return ['NORMAL', 'STOPLOSS', 'AMO', 'ROBO'];
      case _Broker.motilal:
        return ['REGULAR', 'AMO'];
      case _Broker.dhan:
        return ['NORMAL', 'STOPLOSS'];
      case _Broker.profitMart:
        return ['NORMAL', 'STOPLOSS', 'AMO', 'ROBO'];
      case _Broker.goodWill:
        return ['NORMAL', 'STOPLOSS', 'AMO'];
    }
  }

  String get defaultVariety {
    switch (this) {
      case _Broker.angelOne:
        return 'NORMAL';
      case _Broker.motilal:
        return 'REGULAR';
      case _Broker.dhan:
        return 'NORMAL';
      case _Broker.profitMart:
        return 'NORMAL';
      case _Broker.goodWill:
        return 'NORMAL';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class IndividualExecutionScreen extends StatefulWidget {
  final int accId;
  const IndividualExecutionScreen(this.accId);
  @override
  State<IndividualExecutionScreen> createState() =>
      _IndividualExecutionScreenState();
}

class _IndividualExecutionScreenState extends State<IndividualExecutionScreen>
    with SingleTickerProviderStateMixin {
  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _pageBg = Color(0xFFF1F5F9);
  static const _surface = Colors.white;
  static const _surfaceAlt = Color(0xFFF8FAFC);
  static const _surfaceMid = Color(0xFFF1F5F9);
  static const _ink = Color(0xFF0F172A);
  static const _inkMid = Color(0xFF334155);
  static const _inkLight = Color(0xFF64748B);
  static const _inkXLight = Color(0xFF94A3B8);
  static const _border = Color(0xFFE2E8F0);
  static const _divider = Color(0xFFF1F5F9);
  static const _accent = Color(0xFF4F46E5);
  static const _accentLight = Color(0xFFEEF2FF);
  static const _accentBorder = Color(0xFFC7D2FE);
  static const _gainText = Color(0xFF166534);
  static const _gainBg = Color(0xFFF0FDF4);
  static const _gainBorder = Color(0xFFBBF7D0);
  static const _lossText = Color(0xFF991B1B);
  static const _lossBg = Color(0xFFFFF1F2);
  static const _lossBorder = Color(0xFFFECDD3);
  static const _exitBg = Color(0xFFFFF7ED);
  static const _exitBorder = Color(0xFFFED7AA);
  static const _exitText = Color(0xFFC2410C);
  static const _modifyBg = Color(0xFFF0F9FF);
  static const _modifyBorder = Color(0xFFBAE6FD);
  static const _modifyText = Color(0xFF0369A1);
  static const _cancelBg = Color(0xFFFEF2F2);
  static const _cancelBorder = Color(0xFFFECACA);
  static const _cancelText = Color(0xFFB91C1C);

  // ── WebSocket config ───────────────────────────────────────────────────────
  static const _wsReconnectDelay = Duration(seconds: 3);
  static const _wsMaxRetries = 2;

  int? _activeSocketBrokerId;
  int _wsRetryCount = 0;
  Timer? _wsRetryTimer;
  bool _wsConnecting = false;
  bool _wsConnected = false;
  bool _wsMaxRetriesReached = false;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _uiThrottleTimer;

  List<WsHoldingExtra>? _pendingHoldings;
  WsPortfolio? _pendingPortfolio;
  List<WsPosition>? _pendingPositions;
  PositionsSummary? _pendingPositionsSummary;

  // ── State ──────────────────────────────────────────────────────────────────
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  _Broker _activeBroker = _Broker.angelOne;

  List<WsHoldingExtra> _holdings = [];
  final Map<String, WsHoldingExtra> _holdingsMap = {};

  WsPortfolio? _portfolio;
  bool _holdingsLoading = true;

  List<WsPosition> _positions = [];
  PositionsSummary? _positionsSummary;

  final Set<String> _exitingTokens = {};
  final Set<String> _cancellingOrderIds = {};
  final Set<String> _modifyingOrderIds = {};
  // ── NEW: convert tracking ──────────────────────────────────────────────────
  final Set<String> _convertingTokens = {};

  final TextEditingController _filterCtrl = TextEditingController();
  ScripInfo? _selectedScrip;
  LtpData? _ltpData;
  bool _loadingLtp = false;

  List<OrderHistoryItem> _orders = [];
  bool _loadingOrders = false;
  String? _ordersError;

  late TabController _tabCtrl;
  String _orderStatusFilter = 'ALL';
  String _orderSideFilter = 'ALL';

  String _pendingFetchBrokerKey = '';

  List<WsHoldingExtra> get _filtered {
    final q = _filterCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return _holdings;
    return _holdings
        .where((h) => h.tradingSymbol.toLowerCase().contains(q))
        .toList();
  }

  List<OrderHistoryItem> get _filteredOrders => _orders.where((o) {
    return (_orderStatusFilter == 'ALL' ||
            o.status.toUpperCase() == _orderStatusFilter) &&
        (_orderSideFilter == 'ALL' || o.side.toUpperCase() == _orderSideFilter);
  }).toList();

  late final BrokerBloc _brokerBloc;
  final Map<String, List<BrokerAccount>> _brokerAccountsMap = {};
  final Map<String, BrokerAccount?> _selectedAccountPerBroker = {};
  int _activeBrokerId = 0;

  BrokerAccount? get _currentAccount =>
      _selectedAccountPerBroker[_activeBroker.brokerKey];

  bool get _ltpReady =>
      _selectedScrip != null && _ltpData != null && !_loadingLtp;

  bool get _activeHasNoAccounts {
    final cached = _brokerAccountsMap[_activeBroker.brokerKey];
    return cached != null && cached.isEmpty;
  }

  bool get _activeAccountsFetchPending =>
      _brokerAccountsMap[_activeBroker.brokerKey] == null &&
      _pendingFetchBrokerKey == _activeBroker.brokerKey;

  // ── initState ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pendingFetchBrokerKey = 'ANGELONE';
    _brokerBloc = BrokerBloc(brokerService: BrokerService())
      ..add(
        FetchBrokers(
          pyId: int.parse(html.window.sessionStorage['user_id'] ?? '0'),
          broker: 'ANGELONE',
        ),
      );
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
      if (_tabCtrl.index == 1 && _orders.isEmpty && !_loadingOrders) {
        _dispatchOrderHistory();
      }
    });
    _filterCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _uiThrottleTimer?.cancel();
    _wsRetryTimer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close(1000);
    _filterCtrl.dispose();
    _tabCtrl.dispose();
    _brokerBloc.close();
    super.dispose();
  }

  // ── Variety resolver ───────────────────────────────────────────────────────
  String _resolveOrderVariety(String? rawVariety) =>
      resolveVariety(rawVariety ?? '', _activeBroker.brokerKey);

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _dispatchOrderHistory() {
    if (_activeBrokerId <= 0) return;
    context.read<IndividualExecutionBloc>().add(
      OrderHistoryRequested(_activeBrokerId),
    );
  }

  void _onScripSelected(ScripInfo scrip) {
    setState(() {
      _selectedScrip = scrip;
      _ltpData = null;
      _loadingLtp = true;
    });
    context.read<IndividualExecutionBloc>().add(ScripSelected(scrip));
  }

  void _killSocket() {
    _wsRetryTimer?.cancel();
    _wsRetryTimer = null;
    _uiThrottleTimer?.cancel();
    _uiThrottleTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    _channel?.sink.close(1000);
    _channel = null;
    _activeSocketBrokerId = null;
    _pendingHoldings = null;
    _pendingPortfolio = null;
    _pendingPositions = null;
    _pendingPositionsSummary = null;
  }

  // ── Switch broker ──────────────────────────────────────────────────────────
  void _switchBroker(_Broker b) {
    if (_activeBroker == b) return;
    _killSocket();
    setState(() {
      _activeBroker = b;
      _holdings = [];
      _holdingsMap.clear();
      _positions = [];
      _positionsSummary = null;
      _portfolio = null;
      _holdingsLoading = true;
      _orders = [];
      _exitingTokens.clear();
      _cancellingOrderIds.clear();
      _modifyingOrderIds.clear();
      _convertingTokens.clear();
      _wsConnected = false;
      _wsConnecting = false;
      _wsRetryCount = 0;
      _wsMaxRetriesReached = false;
      _activeBrokerId = 0;
    });

    final key = b.brokerKey;
    final cached = _brokerAccountsMap[key];

    if (cached != null) {
      if (cached.isEmpty) {
        setState(() => _holdingsLoading = false);
        return;
      }
      final account = _selectedAccountPerBroker[key] ?? cached.first;
      setState(() => _activeBrokerId = account.brokerId);
      _openSocket(brokerId: account.brokerId);
      _dispatchOrderHistory();
    } else {
      _pendingFetchBrokerKey = key;
      _brokerBloc.add(
        FetchBrokers(
          pyId: int.parse(html.window.sessionStorage['user_id'] ?? '0'),
          broker: key,
        ),
      );
    }
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────
  void _openSocket({required int brokerId, bool isRetry = false}) {
    if (!mounted) return;
    if (_activeSocketBrokerId == brokerId && _wsConnected) return;
    if (!isRetry) _wsRetryCount = 0;
    _activeSocketBrokerId = brokerId;
    setState(() {
      _wsConnected = false;
      _wsConnecting = true;
      _wsMaxRetriesReached = false;
      if (!isRetry) _holdingsLoading = true;
    });
    try {
      final uri = Uri.parse(
        '${ApiUrls.webSocketbaseUrl}/ws/holdings?accId=$brokerId',
      );
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      final expectedBrokerId = brokerId;
      _wsSub = channel.stream.listen(
        (data) {
          if (_activeSocketBrokerId != expectedBrokerId) return;
          if (!_wsConnected && mounted) {
            setState(() {
              _wsConnected = true;
              _wsConnecting = false;
              _wsRetryCount = 0;
            });
          }
          _onWsMessage(data, expectedBrokerId);
        },
        onError: (_) {
          if (_activeSocketBrokerId == expectedBrokerId)
            _handleDisconnect(expectedBrokerId);
        },
        onDone: () {
          if (_activeSocketBrokerId == expectedBrokerId)
            _handleDisconnect(expectedBrokerId);
        },
        cancelOnError: true,
      );
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted &&
            _activeSocketBrokerId == expectedBrokerId &&
            _wsConnecting &&
            !_wsConnected) {
          _handleDisconnect(expectedBrokerId);
        }
      });
    } catch (_) {
      if (_activeSocketBrokerId == brokerId) {
        if (mounted) setState(() => _wsConnecting = false);
        _handleDisconnect(brokerId);
      }
    }
  }

  void _handleDisconnect(int brokerId) {
    if (!mounted) return;
    if (_activeSocketBrokerId != brokerId) return;
    _uiThrottleTimer?.cancel();
    _uiThrottleTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    _channel?.sink.close(1000);
    _channel = null;
    _pendingHoldings = null;
    _pendingPortfolio = null;
    _pendingPositions = null;
    _pendingPositionsSummary = null;
    setState(() {
      _wsConnected = false;
      _wsConnecting = false;
    });
    if (_wsRetryCount < _wsMaxRetries) {
      _wsRetryCount++;
      _wsRetryTimer = Timer(_wsReconnectDelay, () {
        if (mounted && _activeSocketBrokerId == brokerId) {
          _openSocket(brokerId: brokerId, isRetry: true);
        }
      });
    } else {
      _activeSocketBrokerId = null;
      if (mounted) {
        setState(() {
          _holdingsLoading = false;
          _wsMaxRetriesReached = true;
        });
      }
    }
  }

  void _connectWs({required int brokerId}) {
    if (_activeSocketBrokerId == brokerId && _wsConnected) return;
    _killSocket();
    setState(() {
      _wsMaxRetriesReached = false;
      _wsRetryCount = 0;
    });
    _openSocket(brokerId: brokerId);
  }

  void _onWsMessage(dynamic raw, int expectedBrokerId) {
    if (_activeSocketBrokerId != expectedBrokerId) return;
    try {
      final decoded = jsonDecode(raw as String);
      bool gotValidMessage = false;

      if (decoded is List) {
        gotValidMessage = true;
        for (final e in decoded) {
          final h = WsHoldingExtra.fromJson(e as Map<String, dynamic>);
          _holdingsMap[h.token] = h;
        }
        if (_holdingsMap.isNotEmpty)
          _pendingHoldings = _holdingsMap.values.toList();
      } else if (decoded is Map<String, dynamic>) {
        gotValidMessage = true;
        final msgType = (decoded['type'] as String?) ?? '';

        if (msgType == 'TICK' ||
            msgType == 'SNAPSHOT' ||
            decoded.containsKey('holdings') ||
            decoded.containsKey('tradingsymbol')) {
          final holdingsList = decoded['holdings'];
          if (holdingsList is List) {
            for (final e in holdingsList) {
              final h = WsHoldingExtra.fromJson(e as Map<String, dynamic>);
              _holdingsMap[h.token] = h;
            }
            if (_holdingsMap.isNotEmpty)
              _pendingHoldings = _holdingsMap.values.toList();
          } else if (decoded.containsKey('tradingsymbol')) {
            final h = WsHoldingExtra.fromJson(decoded);
            _holdingsMap[h.token] = h;
            _pendingHoldings = _holdingsMap.values.toList();
          }
          final portfolioMap = decoded['portfolio'];
          if (portfolioMap is Map<String, dynamic>)
            _pendingPortfolio = _parsePortfolio(portfolioMap);

          final summaryMap = decoded['positionsSummary'];
          if (summaryMap is Map<String, dynamic>)
            _pendingPositionsSummary = PositionsSummary.fromJson(summaryMap);

          final positionsList = decoded['positions'];
          if (positionsList is List) {
            if (positionsList.isNotEmpty) {
              _pendingPositions = positionsList
                  .map((e) => WsPosition.fromJson(e as Map<String, dynamic>))
                  .toList();
            } else if (_positions.isEmpty) {
              _pendingPositions = [];
            }
          }
        } else {
          final holdingsList = decoded['holdings'];
          if (holdingsList is List) {
            for (final e in holdingsList) {
              final h = WsHoldingExtra.fromJson(e as Map<String, dynamic>);
              _holdingsMap[h.token] = h;
            }
            if (_holdingsMap.isNotEmpty)
              _pendingHoldings = _holdingsMap.values.toList();
          }
          final positionsList = decoded['positions'];
          if (positionsList is List) {
            _pendingPositions = positionsList
                .map((e) => WsPosition.fromJson(e as Map<String, dynamic>))
                .toList();
          }
          final summaryMap = decoded['positionsSummary'];
          if (summaryMap is Map<String, dynamic>)
            _pendingPositionsSummary = PositionsSummary.fromJson(summaryMap);

          final portfolioMap = decoded['portfolio'];
          if (portfolioMap is Map<String, dynamic>)
            _pendingPortfolio = _parsePortfolio(portfolioMap);
        }
      }

      if (!gotValidMessage) return;

      if (_pendingHoldings != null &&
          _pendingHoldings!.isNotEmpty &&
          _pendingPortfolio == null) {
        final invested = _pendingHoldings!.fold(
          0.0,
          (s, h) => s + h.investedValue,
        );
        final current = _pendingHoldings!.fold(
          0.0,
          (s, h) => s + h.currentValue,
        );
        final pnl = current - invested;
        final pnlPct = invested > 0 ? (pnl / invested) * 100 : 0.0;
        final todayPnl = _pendingHoldings!.fold(0.0, (s, h) => s + h.todayPnl);
        _pendingPortfolio = WsPortfolio(
          totalInvested: invested,
          totalCurrentValue: current,
          totalPnl: pnl,
          totalPnlPercent: pnlPct,
          todayProfit: todayPnl > 0 ? todayPnl : 0,
          todayLoss: todayPnl < 0 ? todayPnl : 0,
        );
      }

      if (_pendingHoldings == null && _pendingPositions == null) {
        if (mounted) {
          setState(() {
            _wsConnected = true;
            _wsConnecting = false;
            _wsRetryCount = 0;
            if (_pendingPortfolio != null) {
              _portfolio = _pendingPortfolio;
              _pendingPortfolio = null;
            }
            if (_pendingPositionsSummary != null) {
              _positionsSummary = _pendingPositionsSummary;
              _pendingPositionsSummary = null;
            }
          });
        }
        return;
      }

      _uiThrottleTimer ??= Timer.periodic(const Duration(milliseconds: 250), (
        _,
      ) {
        if (!mounted) {
          _uiThrottleTimer?.cancel();
          _uiThrottleTimer = null;
          return;
        }
        if (_pendingHoldings != null ||
            _pendingPositions != null ||
            _pendingPortfolio != null ||
            _pendingPositionsSummary != null) {
          setState(() {
            if (_pendingHoldings != null) {
              _holdings = _pendingHoldings!;
              _pendingHoldings = null;
            }
            if (_pendingPositions != null) {
              _positions = _pendingPositions!;
              _pendingPositions = null;
            }
            if (_pendingPortfolio != null) {
              _portfolio = _pendingPortfolio;
              _pendingPortfolio = null;
            }
            if (_pendingPositionsSummary != null) {
              _positionsSummary = _pendingPositionsSummary;
              _pendingPositionsSummary = null;
            }
            _holdingsLoading = false;
            _wsConnected = true;
          });
        }
      });
    } catch (_) {}
  }

  WsPortfolio _parsePortfolio(Map<String, dynamic> m) {
    final invested = (m['totalInvested'] as num?)?.toDouble() ?? 0.0;
    final current = (m['totalCurrentValue'] as num?)?.toDouble() ?? 0.0;
    final pnl = (m['totalPnl'] as num?)?.toDouble() ?? current - invested;
    final pnlPct =
        (m['totalPnlPercent'] as num?)?.toDouble() ??
        (invested > 0 ? (pnl / invested) * 100 : 0.0);
    return WsPortfolio(
      totalInvested: invested,
      totalCurrentValue: current,
      totalPnl: pnl,
      totalPnlPercent: pnlPct,
      todayProfit: (m['todayProfit'] as num?)?.toDouble() ?? 0.0,
      todayLoss: (m['todayLoss'] as num?)?.toDouble() ?? 0.0,
      totalDayChange: (m['totalDayChange'] as num?)?.toDouble() ?? 0.0,
      totalDayChangePercent:
          (m['totalDayChangePercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ── BrokerBloc listener ────────────────────────────────────────────────────
  void _onBrokerState(BuildContext ctx, BrokerState state) {
    if (state is! BrokerLoaded) return;
    final brokers = state.brokers;
    if (!mounted) return;

    final key = _activeBroker.brokerKey;
    if (_pendingFetchBrokerKey.isNotEmpty && _pendingFetchBrokerKey != key) {
      _pendingFetchBrokerKey = '';
      return;
    }
    _pendingFetchBrokerKey = '';

    setState(() {
      _brokerAccountsMap[key] = brokers;
      if (brokers.isNotEmpty) {
        _selectedAccountPerBroker[key] ??=
            state.selectedBroker ?? brokers.first;
      }
    });

    if (brokers.isEmpty) {
      setState(() => _holdingsLoading = false);
      return;
    }

    final account = _selectedAccountPerBroker[key]!;
    final targetId = account.brokerId;
    if (_activeSocketBrokerId == targetId && _wsConnected) return;
    setState(() => _activeBrokerId = targetId);
    _killSocket();
    _openSocket(brokerId: targetId);
    context.read<IndividualExecutionBloc>().add(
      OrderHistoryRequested(targetId),
    );
  }

  // ── ExecutionBloc listener ─────────────────────────────────────────────────
  void _onBlocState(BuildContext ctx, IndividualExecutionState state) {
    if (state is LtpLoading) {
      setState(() => _loadingLtp = true);
    } else if (state is LtpSuccess) {
      setState(() {
        _ltpData = state.ltpData;
        _loadingLtp = false;
      });
    } else if (state is LtpFailure) {
      setState(() => _loadingLtp = false);
    } else if (state is OrderHistoryLoading) {
      setState(() {
        _loadingOrders = true;
        _ordersError = null;
      });
    } else if (state is OrderHistorySuccess) {
      setState(() {
        _orders = state.orders;
        _loadingOrders = false;
        _ordersError = null;
      });
    } else if (state is OrderHistoryFailure) {
      setState(() {
        _loadingOrders = false;
        _ordersError = state.message;
      });
    } else if (state is OrderPlaced) {
      setState(() => _exitingTokens.clear());
      if (mounted && _tabCtrl.index == 1) _dispatchOrderHistory();
    } else if (state is OrderPlacementFailure) {
      setState(() => _exitingTokens.clear());
    } else if (state is CancelOrderLoading) {
      setState(() => _cancellingOrderIds.add(state.orderId));
    } else if (state is CancelOrderSuccess) {
      setState(() => _cancellingOrderIds.remove(state.orderId));
      if (mounted) _dispatchOrderHistory();
    } else if (state is CancelOrderFailure) {
      setState(() => _cancellingOrderIds.remove(state.orderId));
    } else if (state is ModifyOrderLoading) {
      setState(() => _modifyingOrderIds.add(state.orderId));
    } else if (state is ModifyOrderSuccess) {
      setState(() => _modifyingOrderIds.remove(state.orderId));
      if (mounted) _dispatchOrderHistory();
    } else if (state is ModifyOrderFailure) {
      setState(() => _modifyingOrderIds.remove(state.orderId));
    }
    // ── convert position states ──────────────────────────────────────────────
    else if (state is ConvertPositionLoading) {
      setState(() => _convertingTokens.add(state.token));
    } else if (state is ConvertPositionSuccess) {
      setState(() => _convertingTokens.remove(state.token));
    } else if (state is ConvertPositionFailure) {
      setState(() => _convertingTokens.remove(state.token));
    }
  }

  // ── Order panel / actions ──────────────────────────────────────────────────
  void _showOrderPanel(String side) {
    if (_selectedScrip == null) return;
    showModalBottomSheet(
      context: _scaffoldKey.currentContext ?? context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<IndividualExecutionBloc>(),
        child: OrderPanelWidget(
          scrip: _selectedScrip!,
          ltpData: _ltpData,
          side: side,
          accId: _activeBrokerId,
        ),
      ),
    ).then((_) {
      if (mounted && _tabCtrl.index == 1) _dispatchOrderHistory();
    });
  }

  void _showExitConfirmation(WsPosition position) {
    final exitSide = position.netQty > 0 ? 'SELL' : 'BUY';
    final exitQty = position.netQty.abs();
    showModalBottomSheet(
      context: _scaffoldKey.currentContext ?? context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<IndividualExecutionBloc>(),
        child: _ExitConfirmationSheet(
          position: position,
          exitSide: exitSide,
          exitQty: exitQty,
          accId: _activeBrokerId,
          onConfirm: (qty) =>
              _executeExit(position: position, exitSide: exitSide, qty: qty),
        ),
      ),
    ).then((_) {
      if (mounted && _tabCtrl.index == 1) _dispatchOrderHistory();
    });
  }

  void _executeExit({
    required WsPosition position,
    required String exitSide,
    required int qty,
  }) {
    if (qty <= 0) return;
    setState(() => _exitingTokens.add(position.token));
    context.read<IndividualExecutionBloc>().add(
      PlaceOrderRequested(
        accId: _activeBrokerId,
        scrip: ScripInfo(
          tradingSymbol: position.tradingSymbol,
          exchange: position.exchange,
          symbolToken: position.token,
        ),
        quantity: qty,
        orderType: 'MARKET',
        productType: _mapProductType(position.productType),
        variety: _activeBroker.defaultVariety,
        price: 0,
        side: exitSide,
        ctx: context,
      ),
    );
  }

  String _mapProductType(String wsProductType) {
    switch (wsProductType.toUpperCase()) {
      case 'INTRADAY':
      case 'MIS':
        return 'INTRADAY';
      case 'MARGIN':
      case 'PAY_LATER':
        return 'MARGIN';
      case 'DELIVERY':
      case 'CNC':
      default:
        return 'DELIVERY';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CONVERT POSITION
  // ══════════════════════════════════════════════════════════════════════════

  void _showConvertConfirmation(WsPosition position) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => BlocProvider.value(
        value: context.read<IndividualExecutionBloc>(),
        child: _ConvertPositionDialog(
          position: position,
          accId: _activeBrokerId,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CANCEL CONFIRMATION
  // ══════════════════════════════════════════════════════════════════════════

  void _showCancelConfirmation(OrderHistoryItem order) {
    final resolvedVariety = _resolveOrderVariety(order.variety);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cancelBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cancelBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: const Border(
                    bottom: BorderSide(color: _cancelBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _cancelBorder),
                      ),
                      child: const Icon(
                        Icons.cancel_outlined,
                        size: 20,
                        color: _cancelText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cancel Order',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          Text(
                            order.tradingSymbol.replaceAll('-EQ', ''),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _inkLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cancelInfoRow('Side', order.side),
                    const SizedBox(height: 8),
                    _cancelInfoRow('Qty', '${order.quantity}'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _cancelBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _cancelBorder),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: _cancelText,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Are you sure you want to cancel the order.',
                              style: TextStyle(
                                fontSize: 15,
                                color: _cancelText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: _inkLight,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: _border),
                              ),
                            ),
                            child: const Text(
                              'Go Back',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              context.read<IndividualExecutionBloc>().add(
                                CancelOrderRequested(
                                  accId: _activeBrokerId,
                                  orderId: order.orderId,
                                  variety: resolvedVariety,
                                  ctx: context,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _cancelText,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel Order',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
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
        ),
      ),
    );
  }

  Widget _cancelInfoRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: _inkLight)),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
    ],
  );

  // ══════════════════════════════════════════════════════════════════════════
  //  MODIFY ORDER
  // ══════════════════════════════════════════════════════════════════════════

  void _showModifyDialog(OrderHistoryItem order) {
    final resolvedVariety = _resolveOrderVariety(order.variety);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => BlocProvider.value(
        value: context.read<IndividualExecutionBloc>(),
        child: _ModifyOrderSheet(
          order: order,
          accId: _activeBrokerId,
          resolvedVariety: resolvedVariety,
          onConfirm:
              ({
                required int quantity,
                required double price,
                required String orderType,
              }) {
                context.read<IndividualExecutionBloc>().add(
                  ModifyOrderRequested(
                    accId: _activeBrokerId,
                    orderId: order.orderId,
                    variety: resolvedVariety,
                    exchange: order.exchange,
                    tradingSymbol: order.tradingSymbol,
                    symbolToken: order.symboltoken ?? '',
                    orderType: orderType,
                    productType: order.productType,
                    quantity: quantity,
                    price: price,
                    triggerPrice: 0.0,
                    duration: 'DAY',
                    ctx: context,
                  ),
                );
              },
        ),
      ),
    ).then((_) {
      if (mounted) _dispatchOrderHistory();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ROOT BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return BlocProvider<BrokerBloc>.value(
      value: _brokerBloc,
      child: BlocListener<IndividualExecutionBloc, IndividualExecutionState>(
        listener: _onBlocState,
        child: BlocListener<BrokerBloc, BrokerState>(
          bloc: _brokerBloc,
          listener: _onBrokerState,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: _pageBg,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                _buildHeader(),
                Expanded(child: _contentArea()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: const Color(0xFF0F172A),
            child: const HotStocksWidgetIndividualScreen(),
          ),
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Four broker tabs ──────────────────────────────────────
                  _brokerTab(_Broker.angelOne),
                  const SizedBox(width: 4),
                  _brokerTab(_Broker.motilal),
                  const SizedBox(width: 4),
                  _brokerTab(_Broker.dhan),
                  const SizedBox(width: 4),
                  _brokerTab(_Broker.profitMart),
                  const SizedBox(width: 4),
                  _brokerTab(_Broker.goodWill),
                  _vSep(),
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 38,
                      child: StockSearchWidget(
                        onScripSelected: _onScripSelected,
                      ),
                    ),
                  ),
                  _vSep(),
                  Expanded(
                    flex: 3,
                    child: BlocBuilder<BrokerBloc, BrokerState>(
                      bloc: _brokerBloc,
                      builder: (ctx, state) => _accountDropdown(ctx, state),
                    ),
                  ),
                  _vSep(),
                  Tooltip(
                    message: 'Paper Trading Mode: orders are executed virtually with simulation funds. Real money live trading is currently locked by safety gate.',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.shield_outlined, size: 14, color: Color(0xFFB45309)),
                          SizedBox(width: 5),
                          Text(
                            'PAPER TRADING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_activeHasNoAccounts && _portfolio != null) ...[
            Container(height: 1, color: _border),
            _portfolioBar(),
          ],
          if (_selectedScrip != null) ...[
            Container(height: 1, color: _border),
            _scripBar(),
          ],
        ],
      ),
    );
  }

  Widget _brokerTab(_Broker b) {
    final active = _activeBroker == b;
    final color = b.brandColor;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: () => _switchBroker(b),
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: active ? color.withOpacity(0.4) : _border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: active ? color : _surfaceMid,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: Text(
                  b.initials,
                  style: TextStyle(
                    fontSize: 6.5,
                    fontWeight: FontWeight.w900,
                    color: active ? Colors.white : _inkLight,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                b.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? color : _inkLight,
                ),
              ),
              if (b == _Broker.goodWill) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'Coming Soon',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color fg,
    required Color bg,
    required Color bd,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: bd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Account dropdown ───────────────────────────────────────────────────────
  Widget _accountDropdown(BuildContext ctx, BrokerState state) {
    Widget shell(Widget child) => Container(
      height: 36,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    final brokerKey = _activeBroker.brokerKey;
    List<BrokerAccount> clients = _brokerAccountsMap[brokerKey] ?? [];

    if (state is BrokerLoading && clients.isEmpty) {
      return shell(
        Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _activeBroker.brandColor,
            ),
          ),
        ),
      );
    }
    if (state is BrokerError && clients.isEmpty) {
      return shell(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Center(
            child: Text(
              state.message,
              style: const TextStyle(fontSize: 11, color: _lossText),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    if (clients.isEmpty &&
        state is BrokerLoaded &&
        _pendingFetchBrokerKey.isEmpty) {
      clients = state.brokers;
    }
    if (clients.isEmpty) {
      return shell(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Center(
            child: Text(
              'No accounts',
              style: TextStyle(fontSize: 11, color: _inkLight),
            ),
          ),
        ),
      );
    }

    BrokerAccount selected =
        _selectedAccountPerBroker[brokerKey] ?? clients.first;
    if (!clients.any((c) => c.brokerId == selected.brokerId))
      selected = clients.first;

    return _BrokerAccountDropdown(
      key: ValueKey('dropdown_${brokerKey}_${selected.brokerId}'),
      accounts: clients,
      selected: selected,
      brokerColor: _activeBroker.brandColor,
      onChanged: (account) {
        setState(() {
          _selectedAccountPerBroker[brokerKey] = account;
          _activeBrokerId = account.brokerId;
          _holdings = [];
          _holdingsMap.clear();
          _positions = [];
          _positionsSummary = null;
          _portfolio = null;
          _orders = [];
          _exitingTokens.clear();
          _cancellingOrderIds.clear();
          _modifyingOrderIds.clear();
          _convertingTokens.clear();
          _holdingsLoading = true;
        });
        _connectWs(brokerId: account.brokerId);
        context.read<IndividualExecutionBloc>().add(
          OrderHistoryRequested(account.brokerId),
        );
        ctx.read<BrokerBloc>().add(SelectBroker(account));
      },
    );
  }

  // ── Portfolio bar ──────────────────────────────────────────────────────────
  Widget _portfolioBar() {
    final p = _portfolio!;
    final gain = p.totalPnl >= 0;
    final gc = gain ? _gainText : _lossText;
    final gcBg = gain ? _gainBg : _lossBg;
    final gcBd = gain ? _gainBorder : _lossBorder;
    final sign = gain ? '+' : '';
    final todayNet = p.netTodayChange;
    final todayGain = todayNet >= 0;
    final todayColor = todayGain ? _gainText : _lossText;
    final todayBg = todayGain ? _gainBg : _lossBg;
    final todayBd = todayGain ? _gainBorder : _lossBorder;
    final todaySign = todayGain ? '+' : '';
    final dayGain = p.totalDayChange >= 0;
    final dayColor = dayGain ? _gainText : _lossText;
    final dayBg = dayGain ? _gainBg : _lossBg;
    final dayBd = dayGain ? _gainBorder : _lossBorder;
    final positionsPnl = _positionsSummary?.totalPnl ?? 0.0;
    final positionsGain = positionsPnl >= 0;

    return Container(
      color: const Color(0xFFFAFBFF),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PORTFOLIO VALUE',
                style: TextStyle(
                  fontSize: 8,
                  color: _inkXLight,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '₹${_fmt(p.totalCurrentValue)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: gcBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: gcBd),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      gain
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 9,
                      color: gc,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$sign₹${p.totalPnl.abs().toStringAsFixed(0)}  ($sign${p.totalPnlPercent.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: gc,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _sep(),
          _stat('INVESTED', '₹${_fmt(p.totalInvested)}', _inkMid),
          _sep(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TODAY'S P&L",
                style: TextStyle(
                  fontSize: 8,
                  color: _inkXLight,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: todayBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: todayBd),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      todayGain
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 10,
                      color: todayColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$todaySign₹${todayNet.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: todayColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _sep(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DAY CHANGE',
                style: TextStyle(
                  fontSize: 8,
                  color: _inkXLight,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: dayBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: dayBd),
                ),
                child: Text(
                  '${dayGain ? '+' : ''}₹${p.totalDayChange.toStringAsFixed(2)} (${dayGain ? '+' : ''}${p.totalDayChangePercent.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: dayColor,
                  ),
                ),
              ),
            ],
          ),
          _sep(),
          _stat('HOLDINGS', '${_holdings.length} stocks', _inkMid),
          _sep(),
          _stat(
            'POSITIONS',
            '${_positionsSummary?.count ?? _positions.length} open',
            positionsGain ? _inkMid : _lossText,
          ),
          const Spacer(),
          _wsStatusBadge(),
        ],
      ),
    );
  }

  Widget _wsStatusBadge() {
    Color dotColor, textColor, bgColor, bdColor;
    String label;
    if (_wsConnected) {
      dotColor = _gainText;
      textColor = _gainText;
      bgColor = _gainBg;
      bdColor = _gainBorder;
      label = 'LIVE';
    } else if (_wsConnecting) {
      dotColor = _accent;
      textColor = _accent;
      bgColor = _accentLight;
      bdColor = _accentBorder;
      label = 'SYNCING';
    } else {
      dotColor = _lossText;
      textColor = _lossText;
      bgColor = _lossBg;
      bdColor = _lossBorder;
      label = 'OFFLINE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bdColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_wsConnecting)
            SizedBox(
              width: 6,
              height: 6,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: dotColor,
              ),
            )
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sep() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 14),
    child: SizedBox(width: 1, height: 28, child: ColoredBox(color: _border)),
  );

  Widget _stat(String label, String value, Color vc) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 8,
          color: _inkXLight,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vc),
      ),
    ],
  );

  // ── Scrip bar ──────────────────────────────────────────────────────────────
  Widget _scripBar() {
    final name = _selectedScrip!.tradingSymbol.replaceAll('-EQ', '');
    final chg = (_ltpData != null && _ltpData!.close > 0)
        ? _ltpData!.ltp - _ltpData!.close
        : 0.0;
    final pct = (_ltpData != null && _ltpData!.close > 0)
        ? (chg / _ltpData!.close) * 100
        : 0.0;
    final pos = chg >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(color: _accentLight),
      child: Row(
        children: [
          _avatar(name, 28, _accent),
          const SizedBox(width: 9),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _accentBorder),
            ),
            child: Text(
              _selectedScrip!.exchange,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_loadingLtp)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accent,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'Loading price…',
                  style: TextStyle(fontSize: 11, color: _accent),
                ),
              ],
            )
          else if (_ltpData != null) ...[
            Text(
              '₹${_ltpData!.ltp.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: pos ? _gainBg : _lossBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: pos ? _gainBorder : _lossBorder),
              ),
              child: Text(
                '${pos ? '+' : ''}${pct.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: pos ? _gainText : _lossText,
                ),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _surfaceMid,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _border),
              ),
              child: const Text(
                'Price unavailable',
                style: TextStyle(fontSize: 10, color: _inkLight),
              ),
            ),
          const Spacer(),
          if (_ltpReady) ...[
            if (_activeBroker == _Broker.goodWill)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Text(
                  'API Integration Pending — Coming Soon',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              )
            else ...[
              _miniTradeBtn(
                'BUY',
                _gainText,
                _gainBg,
                _gainBorder,
                () => _showOrderPanel('BUY'),
              ),
              const SizedBox(width: 6),
              _miniTradeBtn(
                'SELL',
                _lossText,
                _lossBg,
                _lossBorder,
                () => _showOrderPanel('SELL'),
              ),
            ],
            const SizedBox(width: 10),
          ],
          InkWell(
            onTap: () => setState(() {
              _selectedScrip = null;
              _ltpData = null;
            }),
            borderRadius: BorderRadius.circular(4),
            child: const Icon(Icons.close_rounded, size: 15, color: _inkLight),
          ),
        ],
      ),
    );
  }

  Widget _miniTradeBtn(
    String label,
    Color fg,
    Color bg,
    Color bd,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bd),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    ),
  );

  Widget _vSep() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: SizedBox(width: 1, height: 28, child: ColoredBox(color: _border)),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  //  CONTENT AREA
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _contentArea() {
    if (_activeHasNoAccounts) return _noAccountsBody(_activeBroker);

    return Column(
      children: [
        Container(
          color: _surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  children: [
                    _tabBtn(
                      0,
                      'Holdings',
                      Icons.pie_chart_outline_rounded,
                      _holdings.isNotEmpty ? '${_filtered.length}' : null,
                    ),
                    _tabBtn(
                      1,
                      'Orders',
                      Icons.receipt_long_rounded,
                      _orders.isNotEmpty ? '${_filteredOrders.length}' : null,
                    ),
                    _tabBtn(
                      2,
                      'Positions',
                      Icons.swap_horiz_rounded,
                      _positions.isNotEmpty ? '${_positions.length}' : null,
                    ),
                    const Spacer(),
                    if (_wsConnecting)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 11,
                              height: 11,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: _accent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Syncing… ($_wsRetryCount/$_wsMaxRetries)',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _inkLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(height: 1, color: _border),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [_holdingsTab(), _ordersTab(), _positionsTab()],
          ),
        ),
      ],
    );
  }

  Widget _tabBtn(int i, String label, IconData icon, String? badge) {
    final active = _tabCtrl.index == i;
    return InkWell(
      onTap: () => setState(() => _tabCtrl.animateTo(i)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? _accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? _accent : _inkLight),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? _accent : _inkLight,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? _accent : _surfaceMid,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : _inkLight,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  NO ACCOUNTS BODY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _noAccountsBody(_Broker broker) {
    return Container(
      color: _pageBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: broker.brandColor.withOpacity(0.07),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: broker.brandColor.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.account_circle_outlined,
                  size: 38,
                  color: broker.brandColor.withOpacity(0.55),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: broker.brandColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: broker.brandColor.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: broker.brandColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        broker.initials,
                        style: const TextStyle(
                          fontSize: 6,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      broker.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: broker.brandColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Accounts Linked',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 340,
                child: Text(
                  'There are no ${broker.label} accounts linked to your profile. '
                  'Please add an account in Settings to view holdings, positions and place orders.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inkLight,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _infoPill(
                    Icons.bar_chart_rounded,
                    'Holdings',
                    'No data available',
                  ),
                  _infoPill(
                    Icons.receipt_long_rounded,
                    'Orders',
                    'No data available',
                  ),
                  _infoPill(
                    Icons.swap_horiz_rounded,
                    'Positions',
                    'No data available',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _surfaceMid,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _inkXLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Live data feed inactive — no account to connect',
                      style: TextStyle(
                        fontSize: 11,
                        color: _inkLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String label, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _inkXLight),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _inkMid,
                ),
              ),
              Text(sub, style: const TextStyle(fontSize: 9, color: _inkXLight)),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HOLDINGS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _holdingsTab() {
    if (_activeHasNoAccounts) return _noAccountsBody(_activeBroker);

    return Column(
      children: [
        Container(
          color: _surface,
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _surfaceMid,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  '${_filtered.length} stocks',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _inkLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 200,
                height: 32,
                child: TextField(
                  controller: _filterCtrl,
                  style: const TextStyle(fontSize: 12, color: _ink),
                  decoration: InputDecoration(
                    hintText: 'Search holdings…',
                    hintStyle: const TextStyle(fontSize: 12, color: _inkXLight),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 14,
                      color: _inkXLight,
                    ),
                    suffixIcon: _filterCtrl.text.isNotEmpty
                        ? InkWell(
                            onTap: () {
                              _filterCtrl.clear();
                              setState(() {});
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: _inkXLight,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: _surfaceMid,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(color: _accent, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          color: _surfaceAlt,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              _hCol('STOCK', flex: 5, left: true),
              _hCol('QTY', flex: 2),
              _hCol('AVG', flex: 3),
              _hCol('LTP', flex: 3),
              _hCol('INVESTED', flex: 4),
              _hCol('CUR. VAL', flex: 4),
              _hCol('P&L', flex: 4),
              _hCol('TODAY', flex: 3),
              _hCol('%', flex: 3),
            ],
          ),
        ),
        Container(height: 1, color: _border),
        Expanded(
          child: Container(
            color: _surface,
            child: _holdingsLoading
                ? _shimmerList()
                : (_wsMaxRetriesReached && _holdings.isEmpty)
                ? _noDataWidget(
                    icon: Icons.wifi_off_rounded,
                    title: 'Connection Failed',
                    subtitle:
                        'Unable to connect after $_wsMaxRetries attempts.',
                    onRetry: () => _connectWs(brokerId: _activeBrokerId),
                    retryLabel: 'Reconnect',
                    isError: true,
                  )
                : _holdings.isEmpty
                ? _noDataWidget(
                    icon: _wsConnected
                        ? Icons.show_chart_rounded
                        : Icons.signal_wifi_off_rounded,
                    title: _wsConnected ? 'No Holdings Found' : 'Not Connected',
                    subtitle: _wsConnected
                        ? 'Your holdings will appear here once data is available.'
                        : 'Tap reconnect to establish a live data connection.',
                    onRetry: _wsConnected
                        ? null
                        : () => _connectWs(brokerId: _activeBrokerId),
                    retryLabel: 'Reconnect',
                  )
                : _filtered.isEmpty
                ? _noDataWidget(
                    icon: Icons.search_off_rounded,
                    title: 'No Matching Stocks',
                    subtitle: 'Try a different search term.',
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _holdingRow(_filtered[i]),
                        Container(height: 1, color: _divider),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _holdingRow(WsHoldingExtra h) {
    final gain = h.pnl >= 0;
    final gc = gain ? _gainText : _lossText;
    final gb = gain ? _gainBg : _lossBg;
    final gbd = gain ? _gainBorder : _lossBorder;
    final sign = gain ? '+' : '';
    final todayGain = h.todayPnl >= 0;
    final tgc = todayGain ? _gainText : _lossText;
    final todaySign = todayGain ? '+' : '';
    final name = h.tradingSymbol.replaceAll('-EQ', '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onScripSelected(
          ScripInfo(
            tradingSymbol: h.tradingSymbol,
            exchange: 'NSE',
            symbolToken: h.token,
          ),
        ),
        hoverColor: const Color(0xFFF8F9FF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    _avatar(name, 30, _avatarColor(name)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${h.base.exchange} · EQ',
                            style: const TextStyle(
                              fontSize: 9,
                              color: _inkXLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${h.quantity}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _inkMid,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '₹${h.avgPrice.toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: _inkLight),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${h.ltp.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    if (h.closePrice > 0)
                      Text(
                        'C: ₹${h.closePrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 8, color: _inkXLight),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '₹${_fmt(h.investedValue)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: _inkLight),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '₹${_fmt(h.currentValue)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '$sign₹${h.pnl.abs().toStringAsFixed(0)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: gc,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${todaySign}₹${h.todayPnl.abs().toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tgc,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: gb,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: gbd),
                    ),
                    child: Text(
                      '$sign${h.pnlPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: gc,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ORDERS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _ordersTab() {
    if (_activeHasNoAccounts) return _noAccountsBody(_activeBroker);

    if (_loadingOrders) {
      return Column(
        children: [
          _orderFilterBar(),
          _ordHdrRow(),
          Container(height: 1, color: _border),
          Expanded(
            child: Container(color: _surface, child: _ordersShimmerList()),
          ),
        ],
      );
    }
    if (_ordersError != null && _orders.isEmpty) {
      return _noDataWidget(
        icon: Icons.wifi_off_rounded,
        title: 'Unable to Load Orders',
        subtitle: _ordersError!,
        onRetry: _dispatchOrderHistory,
        retryLabel: 'Retry',
        isError: true,
      );
    }
    if (_orders.isEmpty) {
      return _noDataWidget(
        icon: Icons.receipt_long_rounded,
        title: 'No Orders Today',
        subtitle: 'Orders placed today will appear here in real time.',
        onRetry: _dispatchOrderHistory,
        retryLabel: 'Refresh',
      );
    }
    final fil = _filteredOrders;
    return Column(
      children: [
        _orderFilterBar(),
        _ordersSummary(),
        _ordHdrRow(),
        Container(height: 1, color: _border),
        Expanded(
          child: Container(
            color: _surface,
            child: fil.isEmpty
                ? _noDataWidget(
                    icon: Icons.filter_list_off_rounded,
                    title: 'No Matching Orders',
                    subtitle: 'Try a different filter.',
                  )
                : RefreshIndicator(
                    color: _accent,
                    onRefresh: () async => _dispatchOrderHistory(),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: fil.length,
                      itemBuilder: (_, i) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _orderRow(fil[i]),
                          Container(
                            height: 1,
                            color: _divider,
                            margin: const EdgeInsets.only(left: 58),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _orderFilterBar() => Container(
    color: _surface,
    padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
    child: Row(
      children: [
        _chip(
          'ALL',
          _orderStatusFilter == 'ALL',
          () => setState(() => _orderStatusFilter = 'ALL'),
        ),
        const SizedBox(width: 4),
        _chip(
          'COMPLETE',
          _orderStatusFilter == 'COMPLETE',
          () => setState(() => _orderStatusFilter = 'COMPLETE'),
          c: _gainText,
        ),
        const SizedBox(width: 4),
        _chip(
          'OPEN',
          _orderStatusFilter == 'OPEN',
          () => setState(() => _orderStatusFilter = 'OPEN'),
          c: _accent,
        ),
        const SizedBox(width: 4),
        _chip(
          'CANCELLED',
          _orderStatusFilter == 'CANCELLED',
          () => setState(() => _orderStatusFilter = 'CANCELLED'),
          c: _inkLight,
        ),
        const SizedBox(width: 4),
        _chip(
          'REJECTED',
          _orderStatusFilter == 'REJECTED',
          () => setState(() => _orderStatusFilter = 'REJECTED'),
          c: _lossText,
        ),
        const Spacer(),
        _chip(
          'BUY',
          _orderSideFilter == 'BUY',
          () => setState(
            () => _orderSideFilter = _orderSideFilter == 'BUY' ? 'ALL' : 'BUY',
          ),
          c: _gainText,
        ),
        const SizedBox(width: 4),
        _chip(
          'SELL',
          _orderSideFilter == 'SELL',
          () => setState(
            () =>
                _orderSideFilter = _orderSideFilter == 'SELL' ? 'ALL' : 'SELL',
          ),
          c: _lossText,
        ),
      ],
    ),
  );

  Widget _chip(
    String label,
    bool active,
    VoidCallback onTap, {
    Color c = _inkLight,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: active ? c.withOpacity(0.08) : _surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? c.withOpacity(0.35) : _border,
          width: active ? 1.2 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          color: active ? c : _inkLight,
        ),
      ),
    ),
  );

  Widget _ordersSummary() {
    final total = _orders.length;
    final complete = _orders
        .where((o) => o.status.toUpperCase() == 'COMPLETE')
        .length;
    final open = _orders.where((o) => o.status.toUpperCase() == 'OPEN').length;
    final rejected = _orders
        .where((o) => o.status.toUpperCase() == 'REJECTED')
        .length;
    return Container(
      color: _surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _sChip('$total', 'Total', _inkLight, _surfaceMid, _border),
          const SizedBox(width: 6),
          _sChip('$complete', 'Complete', _gainText, _gainBg, _gainBorder),
          const SizedBox(width: 6),
          _sChip('$open', 'Open', _accent, _accentLight, _accentBorder),
          const SizedBox(width: 6),
          _sChip('$rejected', 'Rejected', _lossText, _lossBg, _lossBorder),
          const Spacer(),
          InkWell(
            onTap: _dispatchOrderHistory,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _surfaceMid,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 12, color: _inkLight),
                  SizedBox(width: 5),
                  Text(
                    'Refresh',
                    style: TextStyle(
                      fontSize: 11,
                      color: _inkLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sChip(String val, String label, Color fg, Color bg, Color bd) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: bd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: fg.withOpacity(0.65)),
            ),
          ],
        ),
      );

  Widget _ordHdrRow() => Container(
    color: _surfaceAlt,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      children: [
        const Expanded(
          flex: 6,
          child: Text(
            'STOCK',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _inkXLight,
              letterSpacing: 0.7,
            ),
          ),
        ),
        _oHd('TYPE', flex: 3),
        _oHd('QTY', flex: 2),
        _oHd('PRICE', flex: 3),
        _oHd('VALUE', flex: 4),
        _oHd('STATUS', flex: 4),
        _oHd('ACTIONS', flex: 4),
      ],
    ),
  );

  Widget _oHd(String t, {required int flex}) => Expanded(
    flex: flex,
    child: Text(
      t,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: _inkXLight,
        letterSpacing: 0.7,
      ),
    ),
  );

  Widget _orderRow(OrderHistoryItem o) {
    final isBuy = o.side.toUpperCase() == 'BUY';
    final sc = isBuy ? _gainText : _lossText;
    final sb = isBuy ? _gainBg : _lossBg;
    final sbd = isBuy ? _gainBorder : _lossBorder;
    final name = o.tradingSymbol.replaceAll('-EQ', '');
    final statusUpper = o.status.toUpperCase();
    final isOpen = statusUpper == 'OPEN';
    final isCancelling = _cancellingOrderIds.contains(o.orderId);
    final isModifying = _modifyingOrderIds.contains(o.orderId);

    Color stFg, stBg, stBd;
    switch (statusUpper) {
      case 'COMPLETE':
        stFg = _gainText;
        stBg = _gainBg;
        stBd = _gainBorder;
        break;
      case 'OPEN':
        stFg = _accent;
        stBg = _accentLight;
        stBd = _accentBorder;
        break;
      case 'CANCELLED':
        stFg = _inkLight;
        stBg = _surfaceMid;
        stBd = _border;
        break;
      case 'REJECTED':
        stFg = _lossText;
        stBg = _lossBg;
        stBd = _lossBorder;
        break;
      default:
        stFg = _inkLight;
        stBg = _surfaceAlt;
        stBd = _border;
    }

    final dp = o.filledPrice ?? (o.price > 0 ? o.price : null);
    final value = dp != null ? dp * o.quantity : 0.0;
    final timeStr = o.orderTime != null
        ? '${o.orderTime!.hour.toString().padLeft(2, '0')}:${o.orderTime!.minute.toString().padLeft(2, '0')}'
        : '';
    final isAmo = (o.variety ?? '').toUpperCase() == 'AMO';
    final isSimulated = o.orderId.startsWith('PAPER-SIM-') || (o.variety ?? '').toUpperCase().contains('PAPER');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: const Color(0xFFF8F9FF),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 6,
                child: Row(
                  children: [
                    _avatar(name, 32, _avatarColor(name)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: sb,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: sbd),
                                ),
                                child: Text(
                                  o.side,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: sc,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                o.productType,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _inkLight,
                                ),
                              ),
                              if (timeStr.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: _inkXLight,
                                  ),
                                ),
                              ],
                              if (isAmo) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: const Text(
                                    'AMO',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                              if (isSimulated) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: const Color(0xFFC7D2FE),
                                    ),
                                  ),
                                  child: const Text(
                                    'SIMULATED',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4338CA),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  o.orderType,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: _inkMid),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${o.quantity}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  dp != null ? '₹${dp.toStringAsFixed(1)}' : 'MKT',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dp != null ? _ink : _inkLight,
                    fontStyle: dp == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  value > 0 ? '₹${_fmt(value)}' : '–',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: _inkLight),
                ),
              ),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stBg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: stBd),
                    ),
                    child: Text(
                      statusUpper,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: stFg,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: isOpen
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _orderActionBtn(
                              label: isModifying ? '' : 'Modify',
                              icon: isModifying ? null : Icons.edit_outlined,
                              fg: _modifyText,
                              bg: _modifyBg,
                              bd: _modifyBorder,
                              isLoading: isModifying,
                              onTap: isModifying || isCancelling
                                  ? null
                                  : () => _showModifyDialog(o),
                            ),
                            const SizedBox(width: 5),
                            _orderActionBtn(
                              label: isCancelling ? '' : 'Cancel',
                              icon: isCancelling ? null : Icons.close_rounded,
                              fg: _cancelText,
                              bg: _cancelBg,
                              bd: _cancelBorder,
                              isLoading: isCancelling,
                              onTap: isCancelling || isModifying
                                  ? null
                                  : () => _showCancelConfirmation(o),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderActionBtn({
    required String label,
    required IconData? icon,
    required Color fg,
    required Color bg,
    required Color bd,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: onTap == null ? _surfaceMid : bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: onTap == null ? _border : bd),
        ),
        child: isLoading
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: fg),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) Icon(icon, size: 11, color: fg),
                  if (icon != null && label.isNotEmpty)
                    const SizedBox(width: 3),
                  if (label.isNotEmpty)
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  POSITIONS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _positionsTab() {
    if (_activeHasNoAccounts) return _noAccountsBody(_activeBroker);

    if (_holdingsLoading && _positions.isEmpty) {
      return Column(
        children: [
          _posHdrRow(),
          Container(height: 1, color: _border),
          Expanded(
            child: Container(color: _surface, child: _shimmerList()),
          ),
        ],
      );
    }
    if (_wsMaxRetriesReached && _positions.isEmpty) {
      return _noDataWidget(
        icon: Icons.wifi_off_rounded,
        title: 'Connection Failed',
        subtitle:
            'Unable to fetch live position data after $_wsMaxRetries attempts.',
        onRetry: () => _connectWs(brokerId: _activeBrokerId),
        retryLabel: 'Reconnect',
        isError: true,
      );
    }
    if (_positions.isEmpty) {
      return _noDataWidget(
        icon: Icons.swap_horiz_rounded,
        title: 'No Open Positions',
        subtitle: _wsConnected
            ? 'You have no open positions for today.'
            : 'Connect to view your live positions.',
        onRetry: _wsConnected
            ? null
            : () => _connectWs(brokerId: _activeBrokerId),
        retryLabel: 'Reconnect',
      );
    }

    final double totalPnl =
        _positionsSummary?.totalPnl ??
        _positions.fold(0.0, (double s, p) => s + p.pnl);
    final bool pnlGain = totalPnl >= 0;

    return Column(
      children: [
        Container(
          color: _surfaceAlt,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _sChip(
                '${_positionsSummary?.count ?? _positions.length}',
                'Open',
                _accent,
                _accentLight,
                _accentBorder,
              ),
              const SizedBox(width: 8),
              _sChip(
                '${_positions.where((p) => p.netQty > 0).length}',
                'Long',
                _gainText,
                _gainBg,
                _gainBorder,
              ),
              const SizedBox(width: 8),
              _sChip(
                '${_positions.where((p) => p.netQty < 0).length}',
                'Short',
                _lossText,
                _lossBg,
                _lossBorder,
              ),
              const Spacer(),
              _exitAllBtn(),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'DAY P&L',
                    style: TextStyle(
                      fontSize: 8,
                      color: _inkXLight,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: pnlGain ? _gainBg : _lossBg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: pnlGain ? _gainBorder : _lossBorder,
                      ),
                    ),
                    child: Text(
                      '${pnlGain ? '+' : ''}₹${totalPnl.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: pnlGain ? _gainText : _lossText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _posHdrRow(),
        Container(height: 1, color: _border),
        Expanded(
          child: Container(
            color: _surface,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _positions.length,
              itemBuilder: (_, i) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _positionRow(_positions[i]),
                  Container(height: 1, color: _divider),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _exitAllBtn() {
    final anyExiting = _exitingTokens.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: anyExiting ? null : _showExitAllConfirmation,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: anyExiting ? _surfaceMid : _exitBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: anyExiting ? _border : _exitBorder),
          ),
          child: anyExiting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _exitText,
                      ),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Exiting…',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _exitText,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.exit_to_app_rounded, size: 12, color: _exitText),
                    SizedBox(width: 5),
                    Text(
                      'Exit All',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _exitText,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showExitAllConfirmation() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _exitBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _exitBorder),
                    ),
                    child: const Icon(
                      Icons.exit_to_app_rounded,
                      size: 18,
                      color: _exitText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Exit All Positions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'This will place MARKET orders to close all ${_positions.length} open position${_positions.length > 1 ? 's' : ''} immediately.',
                style: const TextStyle(
                  fontSize: 13,
                  color: _inkMid,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _exitBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _exitBorder),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: _exitText,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Market orders execute at current price. Slippage may occur.',
                        style: TextStyle(fontSize: 11, color: _exitText),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: _inkLight,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: _border),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _executeExitAll();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _exitText,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Exit All',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
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

  void _executeExitAll() {
    for (final pos in _positions) {
      if (pos.netQty != 0) {
        _executeExit(
          position: pos,
          exitSide: pos.netQty > 0 ? 'SELL' : 'BUY',
          qty: pos.netQty.abs(),
        );
      }
    }
  }

  Widget _posHdrRow() => Container(
    color: _surfaceAlt,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    child: Row(
      children: [
        _hCol('STOCK', flex: 5, left: true),
        _hCol('NET QTY', flex: 2),
        _hCol('AVG', flex: 3),
        _hCol('LTP', flex: 3),
        _hCol('INVESTED', flex: 4),
        _hCol('CUR. VAL', flex: 4),
        _hCol('P&L', flex: 4),
        _hCol('%', flex: 3),
        _hCol('TYPE', flex: 3),
        const Expanded(
          flex: 5,
          child: Text(
            'ACTION',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _inkXLight,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _positionRow(WsPosition p) {
    final gain = p.pnl >= 0;
    final gc = gain ? _gainText : _lossText;
    final gb = gain ? _gainBg : _lossBg;
    final gbd = gain ? _gainBorder : _lossBorder;
    final sign = gain ? '+' : '';
    final name = p.tradingSymbol.replaceAll('-EQ', '');
    final isLong = p.netQty >= 0;
    final isExiting = _exitingTokens.contains(p.token);
    final isConverting = _convertingTokens.contains(p.token);
    final exitSide = isLong ? 'SELL' : 'BUY';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onScripSelected(
          ScripInfo(
            tradingSymbol: p.tradingSymbol,
            exchange: p.exchange,
            symbolToken: p.token,
          ),
        ),
        hoverColor: const Color(0xFFF8F9FF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Stack(
                      children: [
                        _avatar(name, 30, _avatarColor(name)),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: isLong ? _gainText : _lossText,
                              shape: BoxShape.circle,
                              border: Border.all(color: _surface, width: 1.5),
                            ),
                            child: Icon(
                              isLong
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 7,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${p.exchange} · B:${p.buyQty} S:${p.sellQty}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: _inkXLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${p.netQty > 0 ? '+' : ''}${p.netQty}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isLong ? _gainText : _lossText,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '₹${p.avgPrice.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: _inkLight),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${p.ltp.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    if (p.dayChange != 0)
                      Text(
                        '${p.dayChange >= 0 ? '+' : ''}${p.dayChange.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 9,
                          color: p.dayChange >= 0 ? _gainText : _lossText,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '₹${_fmt(p.investedValue)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: _inkLight),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '₹${_fmt(p.currentValue)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '$sign₹${p.pnl.abs().toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: gc,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: gb,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: gbd),
                    ),
                    child: Text(
                      '$sign${p.pnlPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: gc,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  p.productType,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10, color: _inkLight),
                ),
              ),
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: isExiting
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _surfaceMid,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _border),
                          ),
                          child: const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: _exitText,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            isConverting
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _surfaceMid,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _border),
                                    ),
                                    child: const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: _accent,
                                      ),
                                    ),
                                  )
                                : InkWell(
                                    onTap: () => _showConvertConfirmation(p),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _accentLight,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _accentBorder,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.swap_horiz_rounded,
                                            size: 10,
                                            color: _accent,
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'Conv',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: _accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            const SizedBox(width: 5),
                            InkWell(
                              onTap: () => _showExitConfirmation(p),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _exitBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _exitBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      exitSide == 'SELL'
                                          ? Icons.trending_down_rounded
                                          : Icons.trending_up_rounded,
                                      size: 10,
                                      color: _exitText,
                                    ),
                                    const SizedBox(width: 3),
                                    const Text(
                                      'Exit',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _exitText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  NO DATA WIDGET
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _noDataWidget({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onRetry,
    String retryLabel = 'Reconnect',
    bool isError = false,
  }) {
    final fg = isError ? _lossText : _inkLight;
    final bg = isError ? _lossBg : _surfaceMid;
    final bd = isError ? _lossBorder : _border;
    final btnFg = isError ? _lossText : _accent;
    final btnBg = isError ? _lossBg : _accentLight;
    final btnBd = isError ? _lossBorder : _accentBorder;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: bd, width: 1.5),
              ),
              child: Icon(icon, size: 30, color: fg.withOpacity(0.7)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _inkLight,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRetry,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: btnBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: btnBd, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isError ? Icons.refresh_rounded : Icons.wifi_rounded,
                          size: 16,
                          color: btnFg,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          retryLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: btnFg,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isError) ...[
                const SizedBox(height: 10),
                Text(
                  'Tried $_wsMaxRetries time${_wsMaxRetries == 1 ? '' : 's'}. Check your connection.',
                  style: const TextStyle(fontSize: 11, color: _inkXLight),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _shimmerList() => Center(
    child: Lottie.asset(
      'assets/animations/No Data.json',
      width: 200,
      height: 200,
      fit: BoxFit.contain,
    ),
  );

  Widget _shimmerHRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(
      children: [
        _sb(30, 30, r: 8),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_sb(11, 90), const SizedBox(height: 5), _sb(9, 50)],
          ),
        ),
        const SizedBox(width: 10),
        _sb(11, 30),
        const SizedBox(width: 10),
        _sb(11, 46),
        const SizedBox(width: 10),
        _sb(11, 46),
        const SizedBox(width: 10),
        _sb(11, 58),
        const SizedBox(width: 10),
        _sb(11, 58),
        const SizedBox(width: 10),
        _sb(11, 40),
        const SizedBox(width: 10),
        _sb(11, 50),
        const SizedBox(width: 10),
        _sb(20, 50, r: 6),
      ],
    ),
  );

  Widget _ordersShimmerList() => ListView.builder(
    padding: EdgeInsets.zero,
    itemCount: 7,
    itemBuilder: (_, i) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _shimmerORow(),
        Container(height: 1, color: _divider),
      ],
    ),
  );

  Widget _shimmerORow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(
      children: [
        _sb(32, 32, r: 9),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_sb(11, 100), const SizedBox(height: 5), _sb(9, 70)],
          ),
        ),
        const SizedBox(width: 10),
        _sb(11, 50),
        const SizedBox(width: 10),
        _sb(11, 30),
        const SizedBox(width: 10),
        _sb(11, 60),
        const SizedBox(width: 10),
        _sb(11, 60),
        const SizedBox(width: 10),
        _sb(22, 74, r: 6),
        const SizedBox(width: 10),
        _sb(22, 60, r: 6),
      ],
    ),
  );

  Widget _sb(double h, double w, {double r = 4}) =>
      ShimmerBox(height: h, width: w, radius: r);

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _hCol(String t, {int flex = 3, bool left = false}) => Expanded(
    flex: flex,
    child: Text(
      t,
      textAlign: left ? TextAlign.left : TextAlign.right,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: _inkXLight,
        letterSpacing: 0.7,
      ),
    ),
  );

  Widget _avatar(String name, double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    alignment: Alignment.center,
    child: Text(
      name.isNotEmpty ? name[0] : '?',
      style: TextStyle(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );

  Color _avatarColor(String name) {
    const cols = [
      Color(0xFF4F46E5),
      Color(0xFF059669),
      Color(0xFFDC2626),
      Color(0xFFD97706),
      Color(0xFF7C3AED),
      Color(0xFF0284C7),
      Color(0xFF0D9488),
      Color(0xFFDB2777),
    ];
    if (name.isEmpty) return cols[0];
    return cols[name.codeUnitAt(0) % cols.length];
  }

  String _fmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) {
      final s = v.toStringAsFixed(0);
      return s.length > 3
          ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}'
          : s;
    }
    return v.toStringAsFixed(1);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MODIFY ORDER DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class _ModifyOrderSheet extends StatefulWidget {
  final OrderHistoryItem order;
  final int accId;
  final String resolvedVariety;
  final void Function({
    required int quantity,
    required double price,
    required String orderType,
  })
  onConfirm;

  const _ModifyOrderSheet({
    required this.order,
    required this.accId,
    required this.resolvedVariety,
    required this.onConfirm,
  });

  @override
  State<_ModifyOrderSheet> createState() => _ModifyOrderSheetState();
}

class _ModifyOrderSheetState extends State<_ModifyOrderSheet> {
  static const _surface = Colors.white;
  static const _surfaceAlt = Color(0xFFF8FAFC);
  static const _surfaceMid = Color(0xFFF1F5F9);
  static const _border = Color(0xFFE2E8F0);
  static const _ink = Color(0xFF0F172A);
  static const _inkMid = Color(0xFF334155);
  static const _inkLight = Color(0xFF64748B);
  static const _inkXLight = Color(0xFF94A3B8);
  static const _accent = Color(0xFF4F46E5);
  static const _accentLight = Color(0xFFEEF2FF);
  static const _accentBorder = Color(0xFFC7D2FE);
  static const _gainText = Color(0xFF166534);
  static const _gainBg = Color(0xFFF0FDF4);
  static const _gainBorder = Color(0xFFBBF7D0);
  static const _lossText = Color(0xFF991B1B);
  static const _lossBg = Color(0xFFFFF1F2);
  static const _lossBorder = Color(0xFFFECDD3);

  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  String _orderType = 'LIMIT';

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '${widget.order.quantity}');
    _priceCtrl = TextEditingController(
      text: widget.order.price > 0
          ? widget.order.price.toStringAsFixed(2)
          : '0.00',
    );
    final ot = widget.order.orderType.toUpperCase();
    _orderType = (ot == 'MARKET' || ot == 'MKT') ? 'MARKET' : 'LIMIT';
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  int get _qty => int.tryParse(_qtyCtrl.text.trim()) ?? 0;
  double get _price =>
      _isLimitOrder ? (double.tryParse(_priceCtrl.text.trim()) ?? 0.0) : 0.0;
  double get _total => _qty * _price;
  bool get _isLimitOrder => _orderType == 'LIMIT';
  String get _name => widget.order.tradingSymbol.replaceAll('-EQ', '');
  bool get _isBuy => widget.order.side.toUpperCase() == 'BUY';

  void _stepPrice(double delta) {
    if (!_isLimitOrder) return;
    final current = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final next = (current + delta).clamp(0.05, double.infinity);
    _priceCtrl.text = next.toStringAsFixed(2);
    setState(() {});
  }

  void _submit() {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) return;
    final price = _isLimitOrder
        ? (double.tryParse(_priceCtrl.text.trim()) ?? 0.0)
        : 0.0;
    if (_isLimitOrder && price <= 0) return;
    Navigator.of(context).pop();
    widget.onConfirm(quantity: qty, price: price, orderType: _orderType);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStockCard(),
                  const SizedBox(height: 16),
                  _fieldLabel('No. of Shares'),
                  const SizedBox(height: 8),
                  _sharesField(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _fieldLabel(
                        _isLimitOrder ? 'Limit Price' : 'Market Price',
                      ),
                      const Spacer(),
                      _orderTypeToggle(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _priceRow(),
                  const SizedBox(height: 10),
                  if (widget.resolvedVariety == 'AMO')
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Color(0xFFB45309),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'After-Market Order — executes at market open',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _totalBar(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: const BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _accentLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accentBorder),
            ),
            child: const Icon(Icons.edit_outlined, size: 18, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modify Order',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                Text(
                  _name,
                  style: const TextStyle(fontSize: 12, color: _inkLight),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _surfaceMid,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _border),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 15,
                color: _inkLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard() {
    final price = widget.order.price;
    final sc = _isBuy ? _gainText : _lossText;
    final sb = _isBuy ? _gainBg : _lossBg;
    final sbd = _isBuy ? _gainBorder : _lossBorder;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent.withOpacity(0.2)),
            ),
            alignment: Alignment.center,
            child: Text(
              _name.isNotEmpty ? _name[0] : '?',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceMid,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        widget.order.exchange,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: _inkLight,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: sb,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: sbd),
                      ),
                      child: Text(
                        widget.order.side.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: sc,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.order.productType,
                      style: const TextStyle(fontSize: 11, color: _inkLight),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.order.quantity} qty',
                      style: const TextStyle(fontSize: 11, color: _inkXLight),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price > 0 ? '₹${price.toStringAsFixed(2)}' : 'MARKET',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: price > 0 ? _ink : _inkLight,
                ),
              ),
              const Text(
                'Order Price',
                style: TextStyle(fontSize: 9, color: _inkXLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _inkMid,
    ),
  );

  Widget _sharesField() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(color: _inkXLight, fontSize: 18),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderTypeToggle() {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: _surfaceMid,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['LIMIT', 'MARKET'].map((t) {
          final active = _orderType == t;
          return GestureDetector(
            onTap: () => setState(() => _orderType = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.all(3),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? _surface : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: active ? _border : Colors.transparent,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 4,
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: Text(
                t,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? _ink : _inkLight,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _priceRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _stepPrice(-0.05),
          child: Container(
            width: 44,
            height: 50,
            decoration: BoxDecoration(
              color: _lossBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _lossBorder),
            ),
            child: const Icon(Icons.remove_rounded, color: _lossText, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: _isLimitOrder ? _surface : _surfaceMid,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _border),
            ),
            alignment: Alignment.center,
            child: _isLimitOrder
                ? TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: TextStyle(color: _inkXLight, fontSize: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                : const Text(
                    'At Market Price',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _inkLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _stepPrice(0.05),
          child: Container(
            width: 44,
            height: 50,
            decoration: BoxDecoration(
              color: _gainBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _gainBorder),
            ),
            child: const Icon(Icons.add_rounded, color: _gainText, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _totalBar() {
    final showTotal = _isLimitOrder && _price > 0 && _qty > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_outlined, size: 15, color: _inkXLight),
          const SizedBox(width: 8),
          const Text(
            'Estimated Total',
            style: TextStyle(
              fontSize: 12,
              color: _inkLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            showTotal ? '₹${_total.toStringAsFixed(2)}' : '—',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: _inkLight,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: _border),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Update Order',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  EXIT CONFIRMATION BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _ExitConfirmationSheet extends StatefulWidget {
  final WsPosition position;
  final String exitSide;
  final int exitQty;
  final int accId;
  final void Function(int qty) onConfirm;

  const _ExitConfirmationSheet({
    required this.position,
    required this.exitSide,
    required this.exitQty,
    required this.accId,
    required this.onConfirm,
  });

  @override
  State<_ExitConfirmationSheet> createState() => _ExitConfirmationSheetState();
}

class _ExitConfirmationSheetState extends State<_ExitConfirmationSheet> {
  static const _bg = Color(0xFFF2F4F7);
  static const _surface = Colors.white;
  static const _divider = Color(0xFFE8ECF2);
  static const _ink = Color(0xFF0A0E14);
  static const _inkMid = Color(0xFF2D3748);
  static const _inkLight = Color(0xFF64748B);
  static const _inkXLight = Color(0xFF94A3B8);
  static const _border = Color(0xFFE2E8F0);
  static const _surfaceMid = Color(0xFFF1F5F9);
  static const _gainText = Color(0xFF166534);
  static const _gainBg = Color(0xFFF0FDF4);
  static const _gainBorder = Color(0xFFBBF7D0);
  static const _lossText = Color(0xFF991B1B);
  static const _lossBg = Color(0xFFFFF1F2);
  static const _lossBorder = Color(0xFFFECDD3);
  static const _exitBg = Color(0xFFFFF7ED);
  static const _exitBorder = Color(0xFFFED7AA);
  static const _exitText = Color(0xFFC2410C);

  late int _qty;
  bool _isPlacing = false;

  @override
  void initState() {
    super.initState();
    _qty = widget.exitQty;
  }

  String get _name => widget.position.tradingSymbol.replaceAll('-EQ', '');
  bool get _isSell => widget.exitSide == 'SELL';
  double get _estValue => _qty * widget.position.ltp;

  @override
  Widget build(BuildContext context) {
    final p = widget.position;
    final gain = p.pnl >= 0;

    return BlocListener<IndividualExecutionBloc, IndividualExecutionState>(
      listener: (ctx, state) {
        if (state is OrderPlacing)
          setState(() => _isPlacing = true);
        else if (state is OrderPlaced || state is OrderPlacementFailure) {
          setState(() => _isPlacing = false);
          Navigator.of(context).pop();
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _exitBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _exitBorder),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _name.isNotEmpty ? _name[0] : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _exitText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _isSell ? _lossBg : _gainBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _isSell ? _lossBorder : _gainBorder,
                                ),
                              ),
                              child: Text(
                                'EXIT ${widget.exitSide}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _isSell ? _lossText : _gainText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.exchange,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _inkXLight,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.productType,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _inkLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${p.ltp.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const Text(
                        'LTP',
                        style: TextStyle(fontSize: 9, color: _inkXLight),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _divider),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _infoCell(
                      'POSITION',
                      '${p.netQty > 0 ? '+' : ''}${p.netQty} qty',
                      p.netQty >= 0 ? _gainText : _lossText,
                    ),
                    _divCell(),
                    _infoCell(
                      'AVG PRICE',
                      '₹${p.avgPrice.toStringAsFixed(2)}',
                      _inkMid,
                    ),
                    _divCell(),
                    _infoCell(
                      'P&L',
                      '${gain ? '+' : ''}₹${p.pnl.toStringAsFixed(2)}',
                      gain ? _gainText : _lossText,
                    ),
                    _divCell(),
                    _infoCell(
                      'P&L %',
                      '${gain ? '+' : ''}${p.pnlPercent.toStringAsFixed(2)}%',
                      gain ? _gainText : _lossText,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _divider),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Exit Quantity',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _inkMid,
                          ),
                        ),
                        const Spacer(),
                        _qtyPreset('25%', (widget.exitQty * 0.25).ceil()),
                        const SizedBox(width: 4),
                        _qtyPreset('50%', (widget.exitQty * 0.50).ceil()),
                        const SizedBox(width: 4),
                        _qtyPreset('75%', (widget.exitQty * 0.75).ceil()),
                        const SizedBox(width: 4),
                        _qtyPreset('ALL', widget.exitQty, isAll: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _stepBtn(Icons.remove_rounded, () {
                          if (_qty > 1) setState(() => _qty--);
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: _exitBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _exitBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$_qty',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _exitText,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _stepBtn(Icons.add_rounded, () {
                          if (_qty < widget.exitQty) setState(() => _qty++);
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceMid,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Order Type',
                            style: TextStyle(fontSize: 11, color: _inkLight),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _exitBg,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: _exitBorder),
                            ),
                            child: const Text(
                              'MARKET',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _exitText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Est. Value',
                            style: TextStyle(fontSize: 11, color: _inkLight),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${_estValue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _exitBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _exitBorder),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: _exitText,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Market exit executes at current price. Actual fill may differ slightly.',
                            style: TextStyle(fontSize: 11, color: _exitText),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: _isPlacing
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _inkLight,
                              side: const BorderSide(color: _border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: (_isPlacing || _qty <= 0)
                                ? null
                                : () {
                                    widget.onConfirm(_qty);
                                    Navigator.of(context).pop();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _exitText,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isPlacing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Exit ${widget.exitSide} · $_qty qty',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
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
      ),
    );
  }

  Widget _infoCell(String label, String value, Color vc) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            color: _inkXLight,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: vc,
          ),
        ),
      ],
    ),
  );

  Widget _divCell() => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: _divider,
  );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _surfaceMid,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Icon(icon, size: 18, color: _inkMid),
    ),
  );

  Widget _qtyPreset(String label, int qty, {bool isAll = false}) {
    final isActive = _qty == qty;
    return InkWell(
      onTap: () => setState(() => _qty = qty.clamp(1, widget.exitQty)),
      borderRadius: BorderRadius.circular(5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? (isAll ? _exitText : _exitBg) : _surfaceMid,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: isActive ? _exitBorder : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isActive ? (isAll ? Colors.white : _exitText) : _inkLight,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BROKER ACCOUNT DROPDOWN
// ══════════════════════════════════════════════════════════════════════════════

class _BrokerAccountDropdown extends StatefulWidget {
  final List<BrokerAccount> accounts;
  final BrokerAccount selected;
  final Color brokerColor;
  final ValueChanged<BrokerAccount> onChanged;

  const _BrokerAccountDropdown({
    super.key,
    required this.accounts,
    required this.selected,
    required this.brokerColor,
    required this.onChanged,
  });

  @override
  State<_BrokerAccountDropdown> createState() => _BrokerAccountDropdownState();
}

class _BrokerAccountDropdownState extends State<_BrokerAccountDropdown> {
  static const _ink = Color(0xFF0F172A);
  static const _inkLight = Color(0xFF64748B);
  static const _inkXLight = Color(0xFF94A3B8);
  static const _border = Color(0xFFE2E8F0);
  static const _surface = Colors.white;
  static const _accent = Color(0xFF4F46E5);

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  bool _isOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleDropdown() => _isOpen ? _closeDropdown() : _openDropdown();

  void _openDropdown() {
    _searchCtrl.clear();
    _overlay = OverlayEntry(
      builder: (_) => _AccountDropdownOverlay(
        layerLink: _layerLink,
        accounts: widget.accounts,
        selected: widget.selected,
        brokerColor: widget.brokerColor,
        searchCtrl: _searchCtrl,
        onSelected: (account) {
          _closeDropdown();
          widget.onChanged(account);
        },
        onDismiss: _closeDropdown,
      ),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _isOpen = false);
  }

  Widget _avatar(String name, double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(size * 0.3),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    alignment: Alignment.center,
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: size * 0.44,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleDropdown,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _isOpen ? _accent : _border,
              width: _isOpen ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              _avatar(widget.selected.userName, 22, widget.brokerColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.selected.userName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if ((widget.selected.brokerClientId ?? '').isNotEmpty)
                      Text(
                        widget.selected.brokerClientId!,
                        style: const TextStyle(fontSize: 9, color: _inkXLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: _isOpen ? 0.5 : 0,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _inkLight,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDropdownOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final List<BrokerAccount> accounts;
  final BrokerAccount selected;
  final Color brokerColor;
  final TextEditingController searchCtrl;
  final ValueChanged<BrokerAccount> onSelected;
  final VoidCallback onDismiss;

  const _AccountDropdownOverlay({
    required this.layerLink,
    required this.accounts,
    required this.selected,
    required this.brokerColor,
    required this.searchCtrl,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  State<_AccountDropdownOverlay> createState() =>
      _AccountDropdownOverlayState();
}

class _AccountDropdownOverlayState extends State<_AccountDropdownOverlay> {
  static const _ink = Color(0xFF0F172A);
  static const _inkLight = Color(0xFF64748B);
  static const _inkXLight = Color(0xFF94A3B8);
  static const _border = Color(0xFFE2E8F0);
  static const _surface = Colors.white;
  static const _surfaceMid = Color(0xFFF1F5F9);
  static const _accent = Color(0xFF4F46E5);
  static const _accentLight = Color(0xFFEEF2FF);

  List<BrokerAccount> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.accounts);
    widget.searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onSearch);
    super.dispose();
  }

  void _onSearch() {
    final q = widget.searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(widget.accounts)
          : widget.accounts
                .where(
                  (a) =>
                      a.userName.toLowerCase().contains(q) ||
                      (a.brokerClientId ?? '').toLowerCase().contains(q),
                )
                .toList();
    });
  }

  Widget _avatar(String name, double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(size * 0.3),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    alignment: Alignment.center,
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: size * 0.44,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onDismiss,
      child: Stack(
        children: [
          CompositedTransformFollower(
            link: widget.layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 44),
            child: Material(
              child: InkWell(
                onTap: () {},
                child: Material(
                  elevation: 12,
                  shadowColor: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 260,
                    constraints: const BoxConstraints(maxHeight: 320),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                          child: SizedBox(
                            height: 34,
                            child: TextField(
                              controller: widget.searchCtrl,
                              autofocus: true,
                              style: const TextStyle(fontSize: 12, color: _ink),
                              decoration: InputDecoration(
                                hintText: 'Search accounts…',
                                hintStyle: const TextStyle(
                                  fontSize: 12,
                                  color: _inkXLight,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 14,
                                  color: _inkXLight,
                                ),
                                filled: true,
                                fillColor: _surfaceMid,
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(7),
                                  borderSide: const BorderSide(color: _border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(7),
                                  borderSide: const BorderSide(color: _border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(7),
                                  borderSide: const BorderSide(
                                    color: _accent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(height: 1, color: _border),
                        Flexible(
                          child: _filtered.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'No accounts found',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _inkLight,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  shrinkWrap: true,
                                  itemCount: _filtered.length,
                                  itemBuilder: (_, i) {
                                    final account = _filtered[i];
                                    final isSel =
                                        account.brokerId ==
                                        widget.selected.brokerId;
                                    return InkWell(
                                      onTap: () => widget.onSelected(account),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 100,
                                        ),
                                        color: isSel
                                            ? _accentLight
                                            : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 9,
                                        ),
                                        child: Row(
                                          children: [
                                            _avatar(
                                              account.userName,
                                              30,
                                              widget.brokerColor,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    account.userName,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: isSel
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      color: _ink,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if ((account.brokerClientId ??
                                                          '')
                                                      .isNotEmpty)
                                                    Text(
                                                      account.brokerClientId!,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: _inkXLight,
                                                      ),
                                                    ),
                                                  if (!account.isOwn)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            top: 2,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 5,
                                                            vertical: 1,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: _surfaceMid,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              3,
                                                            ),
                                                        border: Border.all(
                                                          color: _border,
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'Managed',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: _inkLight,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (isSel)
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration: const BoxDecoration(
                                                  color: _accent,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check_rounded,
                                                  size: 11,
                                                  color: Colors.white,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONVERT POSITION DIALOG  — compact, light mode, no overflow
// ══════════════════════════════════════════════════════════════════════════════

class _ConvertPositionDialog extends StatefulWidget {
  final WsPosition position;
  final int accId;

  const _ConvertPositionDialog({required this.position, required this.accId});

  @override
  State<_ConvertPositionDialog> createState() => _ConvertPositionDialogState();
}

class _ConvertPositionDialogState extends State<_ConvertPositionDialog> {
  static const _bg = Color(0xFFFFFFFF);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _ink = Color(0xFF0F172A);
  static const _inkMid = Color(0xFF334155);
  static const _inkLight = Color(0xFF64748B);
  static const _inkXLight = Color(0xFF94A3B8);
  static const _accent = Color(0xFF4F46E5);
  static const _accentL = Color(0xFFEEF2FF);
  static const _accentBd = Color(0xFFC7D2FE);
  static const _gainText = Color(0xFF166534);
  static const _gainBg = Color(0xFFF0FDF4);
  static const _gainBd = Color(0xFFBBF7D0);
  static const _lossText = Color(0xFF991B1B);
  static const _lossBg = Color(0xFFFFF1F2);
  static const _lossBd = Color(0xFFFECDD3);
  static const _warnBg = Color(0xFFFFFBEB);
  static const _warnBd = Color(0xFFFDE68A);
  static const _warnText = Color(0xFF92400E);

  late List<String> _options;
  late String _selected;
  late int _qty;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _qty = widget.position.netQty.abs();
    _buildOptions();
  }

  void _buildOptions() {
    final t = widget.position.productType.toUpperCase();
    if (t == 'INTRADAY' || t == 'MIS') {
      _options = ['DELIVERY'];
    } else if (t == 'DELIVERY' || t == 'CNC') {
      _options = ['INTRADAY'];
    } else {
      _options = ['DELIVERY', 'INTRADAY'];
    }
    _selected = _options.first;
  }

  int get _maxQty => widget.position.netQty.abs();

  String _fromLabel() {
    final t = widget.position.productType.toUpperCase();
    if (t == 'INTRADAY' || t == 'MIS') return 'Intraday (MIS)';
    if (t == 'DELIVERY' || t == 'CNC') return 'Delivery (CNC)';
    if (t == 'MARGIN' || t == 'PAY_LATER') return 'Margin (MTF)';
    return t;
  }

  String _toLabel(String t) {
    switch (t.toUpperCase()) {
      case 'INTRADAY':
        return 'Intraday (MIS)';
      case 'DELIVERY':
        return 'Delivery (CNC)';
      case 'MARGIN':
        return 'Pay Later (MTF)';
      default:
        return t;
    }
  }

  String _apiProduct(String t) {
    switch (t.toUpperCase()) {
      case 'INTRADAY':
        return 'INTRADAY';
      case 'DELIVERY':
        return 'DELIVERY';
      default:
        return t;
    }
  }

  void _submit() {
    if (_submitting || _qty <= 0 || _qty > _maxQty) return;
    setState(() => _submitting = true);

    context.read<IndividualExecutionBloc>().add(
      ConvertPositionRequested(
        accId: widget.accId,
        position: widget.position,
        newProductType: _apiProduct(_selected),
        quantity: _qty,
        ctx: context,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.position;
    final name = p.tradingSymbol.replaceAll('-EQ', '');
    final gain = p.pnl >= 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(name),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stockPill(p, name, gain),
                    const SizedBox(height: 14),
                    Text(
                      'Convert ${_fromLabel()} to',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _inkMid,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._options.map((opt) => _radioTile(opt)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _inkMid,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Max $_maxQty',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _inkXLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _qtyRow(),
                    const SizedBox(height: 14),
                    _notes(),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: _inkLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: _border),
                          ),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: (_qty > 0 && _qty <= _maxQty && !_submitting)
                            ? _submit
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          disabledBackgroundColor: const Color(0xFFCBD5E1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'CONVERT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 14),
                                ],
                              ),
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

  Widget _header(String name) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
    decoration: const BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      border: Border(bottom: BorderSide(color: _border)),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _accentL,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _accentBd),
          ),
          child: const Icon(Icons.swap_horiz_rounded, size: 18, color: _accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Convert Position',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              Text(
                name,
                style: const TextStyle(fontSize: 11, color: _inkLight),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.close_rounded, size: 14, color: _inkLight),
          ),
        ),
      ],
    ),
  );

  Widget _stockPill(WsPosition p, String name, bool gain) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.09),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              Text(
                '${p.exchange}  ·  Qty: ${p.netQty.abs()}  ·  Avg: ₹${p.avgPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 10, color: _inkXLight),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${p.ltp.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: gain ? _gainBg : _lossBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: gain ? _gainBd : _lossBd),
              ),
              child: Text(
                '${gain ? '+' : ''}₹${p.pnl.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: gain ? _gainText : _lossText,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _radioTile(String opt) {
    final sel = _selected == opt;
    return GestureDetector(
      onTap: () => setState(() => _selected = opt),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: sel ? _accentL : _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? _accent : _border,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sel ? _accent : _bg,
                border: Border.all(
                  color: sel ? _accent : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: sel
                  ? const Icon(Icons.circle, size: 7, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _toLabel(opt),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? _accent : _inkMid,
                ),
              ),
            ),
            if (sel)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Selected',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _qtyRow() => Container(
    height: 46,
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        _qtyBtn(Icons.remove_rounded, () {
          if (_qty > 1) setState(() => _qty--);
        }),
        Container(width: 1, height: 46, color: _border),
        Expanded(
          child: Center(
            child: Text(
              '$_qty / $_maxQty',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ),
        Container(width: 1, height: 46, color: _border),
        _qtyBtn(Icons.add_rounded, () {
          if (_qty < _maxQty) setState(() => _qty++);
        }),
      ],
    ),
  );

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: 46,
      height: 46,
      child: Icon(icon, size: 18, color: _inkMid),
    ),
  );

  Widget _notes() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _warnBg,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: _warnBd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.info_outline_rounded, size: 12, color: _warnText),
            SizedBox(width: 5),
            Text(
              'NOTE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _warnText,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _note('OCO orders related to this position will be cancelled.'),
        const SizedBox(height: 4),
        _note('Conversion will revise the charges of the original order.'),
      ],
    ),
  );

  Widget _note(String t) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Icon(Icons.circle, size: 4, color: _warnText),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          t,
          style: const TextStyle(fontSize: 10, color: _warnText, height: 1.45),
        ),
      ),
    ],
  );
}
