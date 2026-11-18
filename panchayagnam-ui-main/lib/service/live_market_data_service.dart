import 'dart:async';
import 'dart:convert';
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
  Timer? _pollTimer;
  bool _isFetching = false;
  bool _isFetchingCommodities = false;
  bool _isLiveConnected = false;
  DateTime? _lastUpdated;
  String _serverOutboundIp = '74.220.52.132';

  bool get isLiveConnected => _isLiveConnected;
  DateTime? get lastUpdated => _lastUpdated;
  String get serverOutboundIp => _serverOutboundIp;
  Map<String, LiveQuote> get allQuotes => Map.unmodifiable(_quotes);
  Map<String, LiveQuote> get allCommodities => Map.unmodifiable(_commodities);

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
    fetchCommoditiesNow();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchNow();
      fetchCommoditiesNow();
    });
  }

  Future<void> _fetchServerModeAndIp() async {
    try {
      final resp = await http
          .get(Uri.parse('${ApiUrls.baseUrl}/api/v1/market/mode'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) {
          final ip = (decoded['serverOutboundIp'] ?? '').toString().trim();
          if (ip.isNotEmpty && ip.contains('.')) {
            _serverOutboundIp = ip;
            notifyListeners();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> fetchNow() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final resp = await http
          .get(Uri.parse('${ApiUrls.baseUrl}/api/v1/market/quotes'))
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
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
    } finally {
      _isFetching = false;
    }
  }

  Future<void> fetchCommoditiesNow() async {
    if (_isFetchingCommodities) return;
    _isFetchingCommodities = true;
    try {
      final resp = await http
          .get(Uri.parse('${ApiUrls.baseUrl}/api/v1/market/commodities'))
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
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
    } finally {
      _isFetchingCommodities = false;
    }
  }

  Future<Map<String, dynamic>?> fetchOptionChain(String underlying) async {
    try {
      final resp = await http
          .get(Uri.parse('${ApiUrls.baseUrl}/api/v1/market/option-chain?underlying=${Uri.encodeComponent(underlying)}'))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> && decoded['status'] == 'SUCCESS') {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
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
