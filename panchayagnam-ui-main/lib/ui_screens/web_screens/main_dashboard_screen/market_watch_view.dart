import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../constants/api_url_constants.dart';
import '../../../models/ScripInfo.dart';
import '../../../reusable_widets/stock_search_widget.dart';
import '../../../service/individual_drop_down_service.dart';
import '../../../service/individual_investment_service.dart';

/// Connection states for market data feeds
enum MarketWatchConnectionStatus {
  disconnected,
  connecting,
  liveStreaming,
  restFeedActive,
  error,
}

/// Represents real-time or snapshot quote details for an instrument
class MarketWatchQuote {
  final double? ltp;
  final double? change;
  final double? percentChange;
  final double? high;
  final double? low;
  final double? open;
  final double? close;
  final int? volume;
  final DateTime? lastUpdated;
  final bool isLiveTick;

  const MarketWatchQuote({
    this.ltp,
    this.change,
    this.percentChange,
    this.high,
    this.low,
    this.open,
    this.close,
    this.volume,
    this.lastUpdated,
    this.isLiveTick = false,
  });
}

class MarketWatchView extends StatefulWidget {
  const MarketWatchView({super.key});

  @override
  State<MarketWatchView> createState() => _MarketWatchViewState();
}

class _MarketWatchViewState extends State<MarketWatchView> {
  int _activeWatchlistIndex = 0;
  final List<String> _watchlists = ['Nifty 50', 'Bank Nifty', 'Custom Watchlist'];

  // Verified default watchlist instruments per category
  final List<List<ScripInfo>> _watchlistTabs = [
    // 0: Nifty 50
    [
      const ScripInfo(
        tradingSymbol: 'RELIANCE-EQ',
        exchange: 'NSE',
        symbolToken: '2885',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'RELIANCE',
        tickSize: 0.05,
      ),
      const ScripInfo(
        tradingSymbol: 'TCS-EQ',
        exchange: 'NSE',
        symbolToken: '11536',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'TCS',
        tickSize: 0.05,
      ),
      const ScripInfo(
        tradingSymbol: 'HDFCBANK-EQ',
        exchange: 'NSE',
        symbolToken: '1333',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'HDFCBANK',
        tickSize: 0.05,
      ),
      const ScripInfo(
        tradingSymbol: 'INFY-EQ',
        exchange: 'NSE',
        symbolToken: '1594',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'INFY',
        tickSize: 0.05,
      ),
      const ScripInfo(
        tradingSymbol: 'ICICIBANK-EQ',
        exchange: 'NSE',
        symbolToken: '4963',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'ICICIBANK',
        tickSize: 0.05,
      ),
    ],
    // 1: Bank Nifty
    [
      const ScripInfo(
        tradingSymbol: 'HDFCBANK-EQ',
        exchange: 'NSE',
        symbolToken: '1333',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'HDFCBANK',
        tickSize: 0.05,
      ),
      const ScripInfo(
        tradingSymbol: 'ICICIBANK-EQ',
        exchange: 'NSE',
        symbolToken: '4963',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'ICICIBANK',
        tickSize: 0.05,
      ),
      const ScripInfo(
        tradingSymbol: 'SBIN-EQ',
        exchange: 'NSE',
        symbolToken: '3045',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'SBIN',
        tickSize: 0.05,
      ),
      const ScripInfo(
        tradingSymbol: 'KOTAKBANK-EQ',
        exchange: 'NSE',
        symbolToken: '1922',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'KOTAKBANK',
        tickSize: 0.05,
      ),
      const ScripInfo(
        tradingSymbol: 'AXISBANK-EQ',
        exchange: 'NSE',
        symbolToken: '5900',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'AXISBANK',
        tickSize: 0.05,
      ),
    ],
    // 2: Custom Watchlist (User managed)
    [
      const ScripInfo(
        tradingSymbol: 'RELIANCE-EQ',
        exchange: 'NSE',
        symbolToken: '2885',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'RELIANCE',
        tickSize: 0.05,
      ),
      const ScripInfo(
        tradingSymbol: 'TCS-EQ',
        exchange: 'NSE',
        symbolToken: '11536',
        instrumentType: 'EQUITY',
        lotSize: 1,
        name: 'TCS',
        tickSize: 0.05,
      ),
    ],
  ];

  List<ScripInfo> get _currentWatchlist => _watchlistTabs[_activeWatchlistIndex];

  // Quotes mapped by symbolToken
  final Map<String, MarketWatchQuote> _quotes = {};

  // Connection management
  MarketWatchConnectionStatus _connectionStatus = MarketWatchConnectionStatus.disconnected;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  Timer? _restPollingTimer;
  bool _isDisposed = false;
  int _brokerAccountId = 0;

  final TradingRemoteDataSource _tradingService = TradingRemoteDataSourceImpl();

  @override
  void initState() {
    super.initState();
    _initializeMarketData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _restPollingTimer?.cancel();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close(1000);
    super.dispose();
  }

  /// Initializes market data by discovering active broker accounts or defaulting to REST snapshots
  Future<void> _initializeMarketData() async {
    if (_isDisposed) return;
    setState(() {
      _connectionStatus = MarketWatchConnectionStatus.connecting;
    });

    int pyUserId = 0;
    try {
      pyUserId = int.tryParse(html.window.sessionStorage['user_id'] ?? '0') ?? 0;
    } catch (_) {
      pyUserId = 0;
    }

    if (pyUserId > 0) {
      try {
        final accounts = await BrokerService().fetchBrokers(
          pyId: pyUserId,
          broker: 'ANGELONE',
        );
        if (!_isDisposed && accounts.isNotEmpty) {
          _brokerAccountId = accounts.first.brokerId;
          _connectWebSocket(_brokerAccountId);
        }
      } catch (_) {
        // Fall back to REST snapshots if broker lookup fails
      }
    }

    // Fetch initial REST quotes for all current items immediately
    await _fetchRestQuotes();

    // If WebSocket is not connected, set status to REST and start gentle polling
    if (!_isDisposed && _connectionStatus != MarketWatchConnectionStatus.liveStreaming) {
      setState(() {
        _connectionStatus = MarketWatchConnectionStatus.restFeedActive;
      });
      _startRestPolling();
    }
  }

  /// Connects to backend /ws/prices WebSocket gateway
  void _connectWebSocket(int accId) {
    if (_isDisposed || accId <= 0) return;

    try {
      final wsUri = Uri.parse('${ApiUrls.webSocketbaseUrl}/ws/prices?accId=$accId');
      _wsChannel = WebSocketChannel.connect(wsUri);

      _wsSubscription = _wsChannel?.stream.listen(
        (data) {
          if (_isDisposed) return;
          _handleWsMessage(data);
        },
        onError: (err) {
          if (_isDisposed) return;
          setState(() {
            _connectionStatus = MarketWatchConnectionStatus.restFeedActive;
          });
          _startRestPolling();
        },
        onDone: () {
          if (_isDisposed) return;
          setState(() {
            _connectionStatus = MarketWatchConnectionStatus.restFeedActive;
          });
          _startRestPolling();
        },
      );

      // Subscribe to active instruments
      final tokens = _currentWatchlist.map((s) => s.symbolToken).toList();
      _sendWsSubscription(tokens);
    } catch (_) {
      if (!_isDisposed) {
        setState(() {
          _connectionStatus = MarketWatchConnectionStatus.restFeedActive;
        });
        _startRestPolling();
      }
    }
  }

  /// Handles incoming WebSocket ticks and snapshots
  void _handleWsMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type']?.toString();

      if (type == 'PRICE_SNAPSHOT') {
        final stocks = decoded['stocks'] as List<dynamic>? ?? [];
        for (final item in stocks) {
          if (item is Map<String, dynamic>) {
            final token = item['token']?.toString() ?? item['symbolToken']?.toString();
            if (token != null) {
              final ltp = (item['ltp'] as num?)?.toDouble();
              final dayChange = (item['dayChange'] as num?)?.toDouble();
              final dayChangePercent = (item['dayChangePercent'] as num?)?.toDouble();
              _quotes[token] = MarketWatchQuote(
                ltp: ltp,
                change: dayChange,
                percentChange: dayChangePercent,
                open: (item['openPrice'] as num?)?.toDouble(),
                high: (item['highPrice'] as num?)?.toDouble(),
                low: (item['lowPrice'] as num?)?.toDouble(),
                close: (item['closePrice'] as num?)?.toDouble(),
                volume: (item['volume'] as num?)?.toInt(),
                lastUpdated: DateTime.now(),
                isLiveTick: true,
              );
            }
          }
        }
        if (!_isDisposed) {
          setState(() {
            _connectionStatus = MarketWatchConnectionStatus.liveStreaming;
          });
        }
      } else if (type == 'PRICE_TICK') {
        final token = decoded['token']?.toString();
        if (token != null) {
          final ltp = (decoded['ltp'] as num?)?.toDouble();
          final dayChange = (decoded['dayChange'] as num?)?.toDouble();
          final dayChangePercent = (decoded['dayChangePercent'] as num?)?.toDouble();

          _quotes[token] = MarketWatchQuote(
            ltp: ltp,
            change: dayChange,
            percentChange: dayChangePercent,
            open: (decoded['openPrice'] as num?)?.toDouble(),
            high: (decoded['highPrice'] as num?)?.toDouble(),
            low: (decoded['lowPrice'] as num?)?.toDouble(),
            close: (decoded['closePrice'] as num?)?.toDouble(),
            volume: (decoded['volume'] as num?)?.toInt(),
            lastUpdated: DateTime.now(),
            isLiveTick: true,
          );
          if (!_isDisposed) {
            setState(() {
              _connectionStatus = MarketWatchConnectionStatus.liveStreaming;
            });
          }
        }
      }
    } catch (_) {
      // Ignore unparseable frames safely
    }
  }

  void _sendWsSubscription(List<String> tokens) {
    if (_wsChannel == null || tokens.isEmpty) return;
    try {
      final msg = jsonEncode({
        'action': 'SUBSCRIBE',
        'tokens': tokens,
      });
      _wsChannel?.sink.add(msg);
    } catch (_) {}
  }

  void _sendWsUnsubscription(List<String> tokens) {
    if (_wsChannel == null || tokens.isEmpty) return;
    try {
      final msg = jsonEncode({
        'action': 'UNSUBSCRIBE',
        'tokens': tokens,
      });
      _wsChannel?.sink.add(msg);
    } catch (_) {}
  }

  /// Gentle 15-second REST polling for honest quote snapshots when WebSocket is not streaming
  void _startRestPolling() {
    _restPollingTimer?.cancel();
    _restPollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_isDisposed && _connectionStatus != MarketWatchConnectionStatus.liveStreaming) {
        _fetchRestQuotes();
      }
    });
  }

  /// Fetches real quotes via backend REST LTP API
  Future<void> _fetchRestQuotes() async {
    for (final item in _currentWatchlist) {
      if (_isDisposed) return;
      try {
        final ltpData = await _tradingService.getLtp(
          exchange: item.exchange,
          tradingSymbol: item.tradingSymbol,
          symbolToken: item.symbolToken,
        );
        if (!_isDisposed && ltpData.ltp > 0) {
          setState(() {
            _quotes[item.symbolToken] = MarketWatchQuote(
              ltp: ltpData.ltp,
              change: ltpData.change,
              percentChange: ltpData.percentChange,
              open: ltpData.open,
              high: ltpData.high,
              low: ltpData.low,
              close: ltpData.close,
              lastUpdated: DateTime.now(),
              isLiveTick: false,
            );
          });
        }
      } catch (_) {
        // If symbol fails to resolve or market is offline, keep as null (honest unavailable state)
      }
    }
  }

  Future<void> _fetchSingleRestQuote(ScripInfo item) async {
    try {
      final ltpData = await _tradingService.getLtp(
        exchange: item.exchange,
        tradingSymbol: item.tradingSymbol,
        symbolToken: item.symbolToken,
      );
      if (!_isDisposed && ltpData.ltp > 0) {
        setState(() {
          _quotes[item.symbolToken] = MarketWatchQuote(
            ltp: ltpData.ltp,
            change: ltpData.change,
            percentChange: ltpData.percentChange,
            open: ltpData.open,
            high: ltpData.high,
            low: ltpData.low,
            close: ltpData.close,
            lastUpdated: DateTime.now(),
            isLiveTick: false,
          );
        });
      }
    } catch (_) {}
  }

  void _addScrip(ScripInfo scrip) {
    if (!_currentWatchlist.any((item) => item.symbolToken == scrip.symbolToken)) {
      setState(() {
        _currentWatchlist.add(scrip);
      });
      _sendWsSubscription([scrip.symbolToken]);
      _fetchSingleRestQuote(scrip);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${scrip.tradingSymbol} added to ${_watchlists[_activeWatchlistIndex]}'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${scrip.tradingSymbol} is already in watchlist'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeScrip(int index) {
    final removed = _currentWatchlist[index];
    setState(() {
      _currentWatchlist.removeAt(index);
      _quotes.remove(removed.symbolToken);
    });
    _sendWsUnsubscription([removed.symbolToken]);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed.tradingSymbol} removed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _switchWatchlistTab(int idx) {
    if (_activeWatchlistIndex == idx) return;
    setState(() {
      _activeWatchlistIndex = idx;
    });
    // Subscribe to new tab tokens
    final tokens = _currentWatchlist.map((s) => s.symbolToken).toList();
    _sendWsSubscription(tokens);
    _fetchRestQuotes();
  }

  Widget _buildConnectionBadge() {
    switch (_connectionStatus) {
      case MarketWatchConnectionStatus.liveStreaming:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sensors, color: Color(0xFF16A34A), size: 14),
              SizedBox(width: 6),
              Text(
                'Live SmartStream',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
              ),
            ],
          ),
        );

      case MarketWatchConnectionStatus.restFeedActive:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done_outlined, color: Color(0xFF2563EB), size: 14),
              SizedBox(width: 6),
              Text(
                'REST Snapshots Active',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
              ),
            ],
          ),
        );

      case MarketWatchConnectionStatus.connecting:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
              ),
              SizedBox(width: 6),
              Text(
                'Connecting...',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
              ),
            ],
          ),
        );

      case MarketWatchConnectionStatus.disconnected:
      case MarketWatchConnectionStatus.error:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, color: Color(0xFF6B7280), size: 14),
              SizedBox(width: 6),
              Text(
                'Standby (Connect Broker)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Market Watch',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildConnectionBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live quotes, contract master verified scrips, and real-time LTP streaming.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                // Watchlist Tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: List.generate(_watchlists.length, (idx) {
                      final isSelected = _activeWatchlistIndex == idx;
                      return InkWell(
                        onTap: () => _switchWatchlistTab(idx),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _watchlists[idx],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Honest Feed Information Notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _connectionStatus == MarketWatchConnectionStatus.liveStreaming
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _connectionStatus == MarketWatchConnectionStatus.liveStreaming
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _connectionStatus == MarketWatchConnectionStatus.liveStreaming
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    color: _connectionStatus == MarketWatchConnectionStatus.liveStreaming
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF2563EB),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _connectionStatus == MarketWatchConnectionStatus.liveStreaming
                          ? 'Angel One SmartStream Connected: Stocks with green [LIVE STREAM] receive real-time tick-by-tick prices. Other symbols update via periodic verified REST snapshots.'
                          : 'Panchayagnam Market Watch: Verified NSE/BSE equity scrips. Periodic REST price snapshots are active (updated every 15s). Symbols with blue [REST SNAPSHOT] show verified prices from backend/Groww fallback feeds.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _connectionStatus == MarketWatchConnectionStatus.liveStreaming
                            ? const Color(0xFF166534)
                            : const Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF4B5563)),
                    tooltip: 'Refresh Quotes Now',
                    onPressed: _fetchRestQuotes,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search Bar
            SizedBox(
              width: double.infinity,
              child: StockSearchWidget(onScripSelected: _addScrip),
            ),
            const SizedBox(height: 20),

            // Watchlist Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('INSTRUMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 1, child: Text('EXCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('LTP (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('CHANGE (%)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('HIGH / LOW', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 1, child: Text('LOT', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 2, child: Text('UPDATED', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        Expanded(flex: 1, child: Text('ACTIONS', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      ],
                    ),
                  ),
                  if (_currentWatchlist.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.format_list_bulleted_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text('Watchlist is empty', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                            const SizedBox(height: 4),
                            Text('Search above to add verified instruments to this watchlist', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentWatchlist.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (ctx, i) {
                        final item = _currentWatchlist[i];
                        final quote = _quotes[item.symbolToken];

                        final ltpVal = quote?.ltp;
                        final hasLtp = ltpVal != null && ltpVal > 0;
                        final isPositive = (quote?.change ?? 0) >= 0;
                        final changeColor = isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              // Instrument Column
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name.isNotEmpty ? item.name : item.tradingSymbol,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827)),
                                    ),
                                    Text('${item.tradingSymbol} (${item.symbolToken})', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),

                              // Exchange
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.exchange,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9)),
                                  ),
                                ),
                              ),

                              // LTP
                              Expanded(
                                flex: 2,
                                child: Text(
                                  hasLtp ? '₹${ltpVal.toStringAsFixed(2)}' : '—',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: hasLtp ? changeColor : Colors.grey.shade400,
                                  ),
                                ),
                              ),

                              // Change & %
                              Expanded(
                                flex: 2,
                                child: quote?.change != null
                                    ? Text(
                                        '${isPositive ? '+' : ''}${quote!.change!.toStringAsFixed(2)} (${isPositive ? '+' : ''}${quote.percentChange?.toStringAsFixed(2) ?? '0.00'}%)',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: changeColor),
                                      )
                                    : Text('—', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                              ),

                              // High / Low
                              Expanded(
                                flex: 2,
                                child: (quote?.high != null && quote!.high! > 0)
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('H: ₹${quote.high!.toStringAsFixed(1)}', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                                          Text('L: ₹${quote.low!.toStringAsFixed(1)}', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                                        ],
                                      )
                                    : Text('—', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                              ),

                              // Lot Size
                              Expanded(
                                flex: 1,
                                child: Text('${item.lotSize}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              ),

                              // Updated Timestamp + Feed Type
                              Expanded(
                                flex: 2,
                                child: quote?.lastUpdated != null
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            DateFormat('HH:mm:ss').format(quote!.lastUpdated!),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: quote.isLiveTick ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              quote.isLiveTick ? 'LIVE STREAM' : 'REST SNAPSHOT',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w700,
                                                color: quote.isLiveTick ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text('—', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                              ),

                              // Actions
                              Expanded(
                                flex: 1,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                  onPressed: () => _removeScrip(i),
                                  tooltip: 'Remove from Watchlist',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
