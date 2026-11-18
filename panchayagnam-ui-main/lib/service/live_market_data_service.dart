import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_url_constants.dart';

class LiveQuote {
  final String symbol;
  final String tradingSymbol;
  final double ltp;
  final double prevClose;
  final double change;
  final double changePct;
  final double high;
  final double low;
  final int volume;
  final int oi;

  const LiveQuote({
    required this.symbol,
    this.tradingSymbol = '',
    required this.ltp,
    required this.prevClose,
    required this.change,
    required this.changePct,
    required this.high,
    required this.low,
    required this.volume,
    this.oi = 0,
  });

  factory LiveQuote.fromJson(String key, Map<String, dynamic> json) {
    return LiveQuote(
      symbol: (json['symbol'] ?? key).toString().toUpperCase(),
      tradingSymbol: (json['tradingSymbol'] ?? '').toString(),
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0.0,
      prevClose: (json['prevClose'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      changePct: (json['changePct'] as num?)?.toDouble() ?? 0.0,
      high: (json['high'] as num?)?.toDouble() ?? 0.0,
      low: (json['low'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      oi: (json['oi'] as num?)?.toInt() ?? 0,
    );
  }
}

class LiveMarketDataService extends ChangeNotifier {
  static final LiveMarketDataService _instance = LiveMarketDataService._internal();
  factory LiveMarketDataService() => _instance;
  LiveMarketDataService._internal();

  final Map<String, LiveQuote> _quotes = {};
  final Map<String, LiveQuote> _commodities = {};
  final Map<String, Map<String, dynamic>> _optionChainCache = {};
  final Map<String, DateTime> _lastOptionChainFetch = {};
  final Set<String> _inFlightOptionChains = {};
  Timer? _pollTimer;
  bool _isFetching = false;
  bool _isFetchingCommodities = false;
  bool _isLiveConnected = false;
  DateTime? _lastUpdated;
  DateTime? _lastQuotesFetch;
  DateTime? _lastCommoditiesFetch;
  DateTime? _backoffUntil;
  int _backoffSeconds = 30;
  String _serverOutboundIp = '178.214.212.207';

  static const Duration _quotesPollInterval = Duration(seconds: 20);
  static const Duration _minQuotesCooldown = Duration(seconds: 15);
  static const Duration _minCommoditiesCooldown = Duration(seconds: 18);
  static const Duration _minOptionChainCooldown = Duration(seconds: 18);

  bool get isLiveConnected => _isLiveConnected;
  DateTime? get lastUpdated => _lastUpdated;
  String get serverOutboundIp => _serverOutboundIp;
  Map<String, LiveQuote> get allQuotes => Map.unmodifiable(_quotes);
  Map<String, LiveQuote> get allCommodities => Map.unmodifiable(_commodities);

  bool get _isTabHidden {
    try {
      return html.document.hidden == true;
    } catch (_) {
      return false;
    }
  }

  bool get _isBackingOff {
    final until = _backoffUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _triggerBackoff({int? overrideSeconds}) {
    final secs = overrideSeconds ?? _backoffSeconds;
    _backoffUntil = DateTime.now().add(Duration(seconds: secs));
    _backoffSeconds = (_backoffSeconds * 2).clamp(30, 180);
  }

  void _resetBackoff() {
    _backoffUntil = null;
    _backoffSeconds = 30;
  }

  /// Temporarily pauses background polling (e.g., while placing a live broker order)
  void pauseBriefly([Duration duration = const Duration(seconds: 12)]) {
    final target = DateTime.now().add(duration);
    if (_backoffUntil == null || target.isAfter(_backoffUntil!)) {
      _backoffUntil = target;
    }
  }

  LiveQuote? getQuote(String rawSymbol) {
    final clean = rawSymbol
        .toUpperCase()
        .replaceAll(' 50', '')
        .replaceAll(' ', '')
        .split('-')
        .first
        .trim();
    if (_quotes.containsKey(clean)) return _quotes[clean];
    if (_commodities.containsKey(clean)) return _commodities[clean];
    if (clean == 'NIFTY50' && _quotes.containsKey('NIFTY')) return _quotes['NIFTY'];
    if (clean == 'BANKNIFTY' && _quotes.containsKey('BANKNIFTY')) return _quotes['BANKNIFTY'];
    if (clean == 'MIDCAPNIFTY' && _quotes.containsKey('MIDCPNIFTY')) return _quotes['MIDCPNIFTY'];
    return null;
  }

  LiveQuote? getCommodityQuote(String rawSymbol) {
    final clean = rawSymbol.toUpperCase().trim();
    return _commodities[clean];
  }

  void start() {
    if (_pollTimer != null && _pollTimer!.isActive) return;
    _fetchServerModeAndIp();
    fetchNow();
    // Poll quotes every 20s only while the tab is visible to prevent Render/Cloudflare 429 rate limits.
    _pollTimer = Timer.periodic(_quotesPollInterval, (_) {
      if (_isTabHidden || _isBackingOff) return;
      fetchNow();
    });
  }

  Future<void> _fetchServerModeAndIp() async {
    if (_isBackingOff) return;
    try {
      final resp = await http
          .get(Uri.parse('${ApiUrls.baseUrl}/api/v1/market/mode'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 429 || resp.statusCode == 503) {
        _triggerBackoff();
        return;
      }
      if (resp.statusCode == 200) {
        _resetBackoff();
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) {
          final ip = (decoded['serverOutboundIp'] ?? '').toString().trim();
          if (ip.isNotEmpty && ip.contains('.')) {
            _serverOutboundIp = ip;
            notifyListeners();
          }
        }
      }
    } catch (_) {
      _triggerBackoff();
    }
  }

  Future<void> fetchNow({bool force = false}) async {
    if (_isFetching) return;
    if (!force && (_isTabHidden || _isBackingOff)) return;
    final now = DateTime.now();
    if (!force &&
        _lastQuotesFetch != null &&
        now.difference(_lastQuotesFetch!) < _minQuotesCooldown) {
      return;
    }
    _isFetching = true;
    _lastQuotesFetch = now;
    try {
      final resp = await http
          .get(Uri.parse('${ApiUrls.baseUrl}/api/v1/market/quotes'))
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 429 || resp.statusCode == 503) {
        _triggerBackoff();
        return;
      }
      if (resp.statusCode == 200) {
        _resetBackoff();
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> && decoded['data'] is Map) {
          final dataMap = Map<String, dynamic>.from(decoded['data'] as Map);
          bool updated = false;
          dataMap.forEach((k, v) {
            if (v is Map) {
              final q = LiveQuote.fromJson(k.toString(), Map<String, dynamic>.from(v));
              if (q.ltp > 0) {
                _quotes[k.toString().toUpperCase()] = q;
                updated = true;
              }
            }
          });
          if (updated) {
            _isLiveConnected = true;
            _lastUpdated = DateTime.now();
            notifyListeners();
          }
        }
      }
    } catch (_) {
      _triggerBackoff();
    } finally {
      _isFetching = false;
    }
  }

  Future<void> fetchCommoditiesNow({bool force = false}) async {
    if (_isFetchingCommodities) return;
    if (!force && (_isTabHidden || _isBackingOff)) return;
    final now = DateTime.now();
    if (!force &&
        _lastCommoditiesFetch != null &&
        now.difference(_lastCommoditiesFetch!) < _minCommoditiesCooldown) {
      return;
    }
    _isFetchingCommodities = true;
    _lastCommoditiesFetch = now;
    try {
      final resp = await http
          .get(Uri.parse('${ApiUrls.baseUrl}/api/v1/market/commodities'))
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 429 || resp.statusCode == 503) {
        _triggerBackoff();
        return;
      }
      if (resp.statusCode == 200) {
        _resetBackoff();
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> && decoded['data'] is Map) {
          final dataMap = Map<String, dynamic>.from(decoded['data'] as Map);
          bool updated = false;
          dataMap.forEach((k, v) {
            if (v is Map) {
              final q = LiveQuote.fromJson(k.toString(), Map<String, dynamic>.from(v));
              if (q.ltp > 0) {
                _commodities[k.toString().toUpperCase()] = q;
                updated = true;
              }
            }
          });
          if (updated) {
            _isLiveConnected = true;
            _lastUpdated = DateTime.now();
            notifyListeners();
          }
        }
      }
    } catch (_) {
      _triggerBackoff();
    } finally {
      _isFetchingCommodities = false;
    }
  }

  Future<Map<String, dynamic>?> fetchOptionChain(String underlying, {bool force = false}) async {
    final key = underlying.toUpperCase().trim();
    if (_inFlightOptionChains.contains(key)) {
      return _optionChainCache[key];
    }
    if (!force && (_isTabHidden || _isBackingOff)) {
      return _optionChainCache[key];
    }
    final now = DateTime.now();
    final lastFetch = _lastOptionChainFetch[key];
    if (!force &&
        lastFetch != null &&
        now.difference(lastFetch) < _minOptionChainCooldown &&
        _optionChainCache.containsKey(key)) {
      return _optionChainCache[key];
    }

    _inFlightOptionChains.add(key);
    _lastOptionChainFetch[key] = now;
    try {
      final resp = await http
          .get(Uri.parse('${ApiUrls.baseUrl}/api/v1/market/option-chain?underlying=${Uri.encodeComponent(key)}'))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 429 || resp.statusCode == 503) {
        _triggerBackoff();
        return _optionChainCache[key];
      }
      if (resp.statusCode == 200) {
        _resetBackoff();
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> && decoded['status'] == 'SUCCESS') {
          _optionChainCache[key] = decoded;
          return decoded;
        }
      }
    } catch (_) {
      _triggerBackoff();
    } finally {
      _inFlightOptionChains.remove(key);
    }
    return _optionChainCache[key];
  }

  Future<double?> fetchLiveFunds({String? clientId}) async {
    try {
      final uri = clientId != null && clientId.isNotEmpty
          ? Uri.parse('${ApiUrls.baseUrl}/api/v1/market/funds?clientId=${Uri.encodeComponent(clientId)}')
          : Uri.parse('${ApiUrls.baseUrl}/api/v1/market/funds');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> && decoded['status'] == 'SUCCESS') {
          return (decoded['availableCash'] as num?)?.toDouble();
        }
      }
    } catch (_) {}
    return null;
  }
}
