import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_url_constants.dart';

class LiveQuote {
  final String symbol;
  final double ltp;
  final double prevClose;
  final double change;
  final double changePct;
  final double high;
  final double low;
  final int volume;

  const LiveQuote({
    required this.symbol,
    required this.ltp,
    required this.prevClose,
    required this.change,
    required this.changePct,
    required this.high,
    required this.low,
    required this.volume,
  });

  factory LiveQuote.fromJson(String key, Map<String, dynamic> json) {
    return LiveQuote(
      symbol: (json['symbol'] ?? key).toString().toUpperCase(),
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0.0,
      prevClose: (json['prevClose'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      changePct: (json['changePct'] as num?)?.toDouble() ?? 0.0,
      high: (json['high'] as num?)?.toDouble() ?? 0.0,
      low: (json['low'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
    );
  }
}

class LiveMarketDataService extends ChangeNotifier {
  static final LiveMarketDataService _instance = LiveMarketDataService._internal();
  factory LiveMarketDataService() => _instance;
  LiveMarketDataService._internal();

  final Map<String, LiveQuote> _quotes = {};
  Timer? _pollTimer;
  bool _isFetching = false;
  bool _isLiveConnected = false;
  DateTime? _lastUpdated;

  bool get isLiveConnected => _isLiveConnected;
  DateTime? get lastUpdated => _lastUpdated;
  Map<String, LiveQuote> get allQuotes => Map.unmodifiable(_quotes);

  LiveQuote? getQuote(String rawSymbol) {
    final clean = rawSymbol
        .toUpperCase()
        .replaceAll(' 50', '')
        .replaceAll(' ', '')
        .split('-')
        .first
        .trim();
    if (_quotes.containsKey(clean)) return _quotes[clean];
    if (clean == 'NIFTY50' && _quotes.containsKey('NIFTY')) return _quotes['NIFTY'];
    if (clean == 'BANKNIFTY' && _quotes.containsKey('BANKNIFTY')) return _quotes['BANKNIFTY'];
    return null;
  }

  void start() {
    if (_pollTimer != null && _pollTimer!.isActive) return;
    fetchNow();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => fetchNow());
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
      // Retain last known live quotes on transient network hiccup
    } finally {
      _isFetching = false;
    }
  }
}
