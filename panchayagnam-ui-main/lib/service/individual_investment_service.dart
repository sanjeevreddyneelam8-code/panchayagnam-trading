import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import '../constants/api_url_constants.dart';
import '../constants/auth_header_helper.dart';
import '../models/ScripInfo.dart';
import '../models/add_demat_account_request.dart';
import '../models/add_demat_account_response.dart';

abstract class TradingRemoteDataSource {
  Future<AddDematAccountResponse> addDematAccount(
    AddDematAccountRequest request,
    String actionType,
  );

  Future<String> convertPosition({
    required int accId,
    required String exchange,
    required String symbolToken,
    required String tradingSymbol,
    required String symbolName,
    required String oldProductType,
    required String newProductType,
    required String transactionType,
    required int quantity,
    required String buyQty,
    required String sellQty,
    required String buyAmount,
    required String sellAmount,
  });

  Future<List<ScripInfo>> searchScrip(String query, String exchange);
  Future<LtpData> getLtp({
    required String exchange,
    required String tradingSymbol,
    required String symbolToken,
  });

  Future<String> placeOrder({
    required int accId,
    required String tradingSymbol,
    required String symbolToken,
    required String exchange,
    required int quantity,
    required String orderType,
    required double price,
    required String productType,
    required String variety,
    required String side,
    String? idempotencyKey,
  });
  Future<String> modifyOrder({
    required int accId,
    required String orderId,
    required String variety,
    required String exchange,
    required String tradingSymbol,
    required String symbolToken,
    required String orderType,
    required String productType,
    required int quantity,
    required double price,
    required double triggerPrice,
    required String duration,
  });

  Future<String> cancelOrder({
    required int accId,
    required String orderId,
    required String variety,
  });
  Future<List<OrderHistoryItem>> getOrderHistory(int accId);
  Future<OrderDetail> getOrderStatus({
    required String uniqueOrderId,
    required int accId,
  });

  void dispose();
}

class TradingRemoteDataSourceImpl implements TradingRemoteDataSource {
  String get _baseUrl => ApiUrls.baseUrl;
  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client;

  TradingRemoteDataSourceImpl({http.Client? client})
    : _client = client ?? http.Client();

  Map<String, String> get _headers => AuthHeaderHelper.getHeaders();

  @override
  Future<AddDematAccountResponse> addDematAccount(
    AddDematAccountRequest request,
    String actionType,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/easyTradeApi/dematAccOperations',
    ).replace(queryParameters: {'actionType': actionType});

    try {
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(request.toJson()))
          .timeout(_timeout);
      return _handleDematResponse(response);
    } on SocketException {
      throw const TradingServiceException(
        'No internet connection. Please check your network.',
      );
    } on HttpException {
      throw const TradingServiceException(
        'Server is unreachable. Please try again.',
      );
    } on FormatException {
      throw const TradingServiceException(
        'Unexpected response format from server.',
      );
    } catch (e) {
      if (e is TradingServiceException) rethrow;
      throw TradingServiceException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<String> convertPosition({
    required int accId,
    required String exchange,
    required String symbolToken,
    required String tradingSymbol,
    required String symbolName,
    required String oldProductType,
    required String newProductType,
    required String transactionType,
    required int quantity,
    required String buyQty,
    required String sellQty,
    required String buyAmount,
    required String sellAmount,
  }) async {
    final uri = Uri.parse('$_baseUrl/pyBrokerApi/order/convertPosition');
    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'accId': accId,
            'exchange': exchange,
            'symboltoken': symbolToken,
            'oldproducttype': oldProductType,
            'newproducttype': newProductType,
            'tradingsymbol': tradingSymbol,
            'symbolname': symbolName,
            'instrumenttype': '',
            'priceden': '1',
            'pricenum': '1',
            'genden': '1',
            'gennum': '1',
            'precision': '2',
            'multiplier': '-1',
            'boardlotsize': '1',
            'buyqty': buyQty,
            'sellqty': sellQty,
            'buyamount': buyAmount,
            'sellamount': sellAmount,
            'transactiontype': transactionType,
            'quantity': quantity,
            'type': 'DAY',
          }),
        )
        .timeout(_timeout);

    final body = _decodeBody(response.body);
    final apiStatus = (body['status'] as String? ?? '').toUpperCase();
    final apiMessage = body['message'] as String? ?? '';

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        apiStatus == 'SUCCESS') {
      return apiMessage.isNotEmpty
          ? apiMessage
          : 'Position converted successfully';
    }

    throw TradingServiceException(
      apiMessage.isNotEmpty
          ? apiMessage
          : 'Convert position failed (${response.statusCode})',
    );
  }

  @override
  Future<List<ScripInfo>> searchScrip(String query, String exchange) async {
    int pyUserId =
        int.tryParse(html.window.sessionStorage['user_id'] ?? '') ?? 0;

    final uri = Uri.parse('$_baseUrl/api/smart/market/search-scrip');
    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'searchscrip': query.toUpperCase(),
            'pyUserId': pyUserId,
          }),
        )
        .timeout(_timeout);
    _checkStatus(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ScripInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String> modifyOrder({
    required int accId,
    required String orderId,
    required String variety,
    required String exchange,
    required String tradingSymbol,
    required String symbolToken,
    required String orderType,
    required String productType,
    required int quantity,
    required double price,
    required double triggerPrice,
    required String duration,
  }) async {
    final uri = Uri.parse('$_baseUrl/pyBrokerApi/modifyOrder');
    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'accId': accId,
            'orderId': orderId,
            'variety': variety == "AMO" ? "NORMAL" : variety,
            'exchange': exchange,
            'tradingSymbol': tradingSymbol,
            'symbolToken': symbolToken,
            'orderType': orderType,
            'productType': productType,
            'quantity': quantity,
            'price': price,
            'triggerPrice': triggerPrice,
            'duration': duration,
          }),
        )
        .timeout(_timeout);

    // Parse the response body for the API's status field
    final body = _decodeBody(response.body);
    final apiStatus = (body['status'] as String? ?? '').toUpperCase();
    final apiMessage = body['message'] as String? ?? '';

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        apiStatus == 'SUCCESS') {
      return apiMessage.isNotEmpty ? apiMessage : 'Order modified successfully';
    }

    throw TradingServiceException(
      apiMessage.isNotEmpty
          ? apiMessage
          : 'Modify order failed (${response.statusCode})',
    );
  }

  // ── Cancel Order ────────────────────────────────────────────────────────────
  @override
  Future<String> cancelOrder({
    required int accId,
    required String orderId,
    required String variety,
  }) async {
    final uri = Uri.parse('$_baseUrl/pyBrokerApi/cancelOrder');
    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'accId': accId,
            'orderId': orderId,
            'variety': variety == "AMO" ? "NORMAL" : variety,
          }),
        )
        .timeout(_timeout);

    final body = _decodeBody(response.body);
    final apiStatus = (body['status'] as String? ?? '').toUpperCase();
    final apiMessage = body['message'] as String? ?? '';

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        apiStatus == 'SUCCESS') {
      return apiMessage.isNotEmpty
          ? apiMessage
          : 'Order cancelled successfully';
    }

    throw TradingServiceException(
      apiMessage.isNotEmpty
          ? apiMessage
          : 'Cancel order failed (${response.statusCode})',
    );
  }

  @override
  Future<LtpData> getLtp({
    required String exchange,
    required String tradingSymbol,
    required String symbolToken,
  }) async {
    int pyUserId = int.parse(html.window.sessionStorage['user_id'] ?? '0');
    final uri = Uri.parse('$_baseUrl/api/smart/market/ltp').replace(
      queryParameters: {
        'exchange': exchange,
        'tradingSymbol': tradingSymbol,
        'symboltoken': symbolToken,
        'pyUserId': pyUserId.toString(),
      },
    );
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);
    _checkStatus(response);
    // ✅ Returns group_models.dart LtpData
    return LtpData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<String> placeOrder({
    required int accId,
    required String tradingSymbol,
    required String symbolToken,
    required String exchange,
    required int quantity,
    required String orderType,
    required double price,
    required String productType,
    required String variety,
    required String side,
    String? idempotencyKey,
  }) async {
    final clientKey = (idempotencyKey != null && idempotencyKey.isNotEmpty)
        ? idempotencyKey
        : 'UI-${DateTime.now().millisecondsSinceEpoch}-${tradingSymbol.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}-$quantity';

    final endpoint = side.toUpperCase() == 'BUY'
        ? '$_baseUrl/pyBrokerApi/order/buy'
        : '$_baseUrl/pyBrokerApi/order/sell';

    final requestHeaders = Map<String, String>.from(_headers);
    requestHeaders['Idempotency-Key'] = clientKey;

    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: requestHeaders,
          body: jsonEncode({
            'accId': accId,
            'tradingSymbol': tradingSymbol,
            'symbolToken': symbolToken,
            'exchange': exchange,
            'quantity': quantity,
            'orderType': orderType,
            'price': price,
            'productType': productType == "NRML" ? "CARRYFORWARD" : productType,
            'variety': variety,
            'idempotencyKey': clientKey,
          }),
        )
        .timeout(_timeout);
    _checkStatus(response);
    return "Order Executed Successfully";
  }

  @override
  Future<List<OrderHistoryItem>> getOrderHistory(int accId) async {
    final uri = Uri.parse(
      '$_baseUrl/pyBrokerApi/order/history',
    ).replace(queryParameters: {'accId': accId.toString()});
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);
    _checkStatus(response);

    final body = jsonDecode(response.body);
    List<dynamic> rawList = [];
    if (body is List) {
      rawList = body;
    } else if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is List) rawList = d;
    }
    return rawList
        .map((e) => _parseAngelOneOrder(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderDetail> getOrderStatus({
    required String uniqueOrderId,
    required int accId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/easyTradeApi/order/$uniqueOrderId',
    ).replace(queryParameters: {'accId': accId.toString()});
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);
    _checkStatus(response);
    return OrderDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  void dispose() => _client.close();

  AddDematAccountResponse _handleDematResponse(http.Response response) {
    final body = _decodeBody(response.body);
    switch (response.statusCode) {
      case 200:
      case 201:
        return AddDematAccountResponse.fromJson(body);
      case 400:
        throw TradingServiceException(
          body['message'] as String? ??
              'Invalid request. Please check your inputs.',
        );
      case 401:
        throw const TradingServiceException(
          'Unauthorized. Please verify your credentials.',
        );
      case 403:
        throw const TradingServiceException(
          'Access denied. You do not have permission for this action.',
        );
      case 404:
        throw const TradingServiceException('Service endpoint not found.');
      case 409:
        throw TradingServiceException(
          body['message'] as String? ?? 'Account already exists.',
        );
      case 500:
      case 502:
      case 503:
        throw const TradingServiceException(
          'Server error. Please try again later.',
        );
      default:
        throw TradingServiceException(
          'Request failed with status ${response.statusCode}.',
        );
    }
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}
      throw TradingServiceException(
        body['message'] as String? ?? 'Request failed (${response.statusCode})',
      );
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  OrderHistoryItem _parseAngelOneOrder(Map<String, dynamic> j) {
    final qty = int.tryParse(j['quantity']?.toString() ?? '0') ?? 0;
    final filledQty = int.tryParse(j['filledshares']?.toString() ?? '0') ?? 0;
    final avgPrice = (j['averageprice'] as num?)?.toDouble() ?? 0.0;
    final limitPrice = (j['price'] as num?)?.toDouble() ?? 0.0;
    final filledPrice = avgPrice > 0 ? avgPrice : null;
    final rawStatus = (j['orderstatus'] ?? j['status'] ?? '').toString();
    final status = _mapStatus(rawStatus);
    final side = (j['transactiontype'] ?? '').toString().toUpperCase();

    return OrderHistoryItem(
      orderId: j['orderid']?.toString() ?? '',
      uniqueOrderId: j['uniqueorderid']?.toString() ?? '',
      tradingSymbol: j['tradingsymbol']?.toString() ?? '',
      exchange: j['exchange']?.toString() ?? 'NSE',
      quantity: qty,
      price: limitPrice,
      orderType: (j['ordertype'] ?? '').toString().toUpperCase(),
      productType: (j['producttype'] ?? '').toString().toUpperCase(),
      status: status,
      side: side,
      filledPrice: filledPrice,
      filledQty: filledQty,
      orderTime: _parseAngelTime(j['updatetime']?.toString()),
      symboltoken: j['symboltoken'],
      variety: j['variety'],
    );
  }

  String _mapStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'complete':
      case 'filled':
        return 'COMPLETE';
      case 'open':
      case 'pending':
        return 'OPEN';
      case 'cancelled':
      case 'canceled':
        return 'CANCELLED';
      case 'rejected':
        return 'REJECTED';
      default:
        return raw.toUpperCase();
    }
  }

  DateTime? _parseAngelTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    try {
      final parts = raw.split(' ');
      if (parts.length < 2) return null;
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');
      return DateTime(
        int.parse(dateParts[2]),
        months[dateParts[1]] ?? 1,
        int.parse(dateParts[0]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (_) {
      return null;
    }
  }
}

class TradingServiceException implements Exception {
  final String message;
  const TradingServiceException(this.message);

  @override
  String toString() => message;
}
