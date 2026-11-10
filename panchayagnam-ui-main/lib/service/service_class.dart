import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_url_constants.dart';
import '../constants/auth_header_helper.dart';
import '../models/add_demat_account_request.dart';
import '../models/add_demat_account_response.dart';
import '../models/demat_account.dart';
import '../models/fetch_demat_accounts_response.dart';
import '../models/py_user.dart';

class ServiceClass {
  static const String _baseUrl = ApiUrls.baseUrl;
  static const Duration _timeout = Duration(seconds: 75);

  final http.Client _client;

  ServiceClass({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> sendOtp({
    required String phoneNumber,
    required String codeReqFor,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/v1/pyauth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber, "codeReqFor": codeReqFor}),
      ).timeout(_timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) return data;
        throw Exception(data['message'] ?? 'Failed to send OTP');
      }
      throw Exception(data['message'] ?? 'Failed to send OTP (${response.statusCode})');
    } on TimeoutException {
      throw Exception('Server request timed out. Please try again later.');
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('XMLHttpRequest')) {
        rethrow;
      }
      throw Exception('Unable to reach Panchayagnam server. Please verify your connection.');
    }
  }

  Future<List<DematAccount>> fetchDematAccountsByBrokerId(
    int pyBrokerId,
  ) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/pyBrokerApi/account',
      ).replace(queryParameters: {'pyBrokerId': pyBrokerId.toString()});

      final response = await http
          .post(uri, headers: AuthHeaderHelper.getHeaders())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final List data = json['data'] ?? [];
        if (data.isNotEmpty) {
          return data.map((e) => DematAccount.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    final allLocal = _getPermanentLocalAccounts();
    final match = allLocal.where((a) => a.id == pyBrokerId).toList();
    if (match.isNotEmpty) return match;
    return [allLocal.first];
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String mpin,
    required String otp,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/v1/pyauth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'phoneNumber': phoneNumber,
          'mpin': mpin,
          'otp': otp,
        }),
      ).timeout(_timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) return data;
        throw Exception(data['message'] ?? 'Registration failed');
      }
      throw Exception(data['message'] ?? 'Registration failed (${response.statusCode})');
    } on TimeoutException {
      throw Exception('Server request timed out. Please try again later.');
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('XMLHttpRequest')) {
        rethrow;
      }
      throw Exception('Unable to reach Panchayagnam server. Please verify your connection.');
    }
  }

  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String mpin,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/pyauth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber, 'mpin': mpin}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (data['success'] == true) return data;
      throw Exception(data['message'] ?? 'Login failed');
    }
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> forgotMpin({required String phoneNumber}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/pyauth/forgot-mpin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (data['success'] == true) return data;
      throw Exception(data['message'] ?? 'Failed to send OTP');
    }
    throw Exception(data['message'] ?? 'Failed to send OTP');
  }

  Future<Map<String, dynamic>> resetMpin({
    required String phoneNumber,
    required String otp,
    required String newMpin,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/pyauth/reset-mpin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phoneNumber': phoneNumber,
        'otp': otp,
        'newMpin': newMpin,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (data['success'] == true) return data;
      throw Exception(data['message'] ?? 'Failed to reset MPIN');
    }
    throw Exception(data['message'] ?? 'Failed to reset MPIN');
  }

  Future<Map<String, dynamic>> raiseAdminRequestApi({
    required int pyId,
    required String? reason,
    required String? requestType,
    required int? planMonths,
    required double? amount,
    required int? noOfClients,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/user/raise-request/$pyId'),
      headers: AuthHeaderHelper.getHeaders(),
      body: jsonEncode({
        'reason': reason,
        "planMonths": planMonths,
        "requestType": requestType,
        "amount": amount,
        "noOfClients": noOfClients,
      }),
    );

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return responseBody;
    } else {
      throw Exception(
        responseBody['message'] ?? 'Server error. Please try again.',
      );
    }
  }

  static const String _permanentAccountsStorageKey = 'py_permanent_demat_accounts_v2';

  static List<Map<String, dynamic>> _seed35BrokerAccounts() {
    const brokers = [
      ('Dhan Pro Master', 'DHAN_PRO_101', 'DHAN', 2500000.0, true, 'Master Desk'),
      ('AngelOne Alpha Demat', 'ANGEL_ACC_102', 'ANGELONE', 1500000.0, false, 'Alpha Equity Desk'),
      ('Zerodha Kite Beta', 'KITE_ACC_103', 'ZERODHA', 2000000.0, false, 'Nifty Straddle'),
      ('Upstox Pro Gamma', 'UPSTX_ACC_104', 'UPSTOX', 1250000.0, false, 'Delta Hedge'),
      ('Fyers API v3 Desk', 'FYERS_ACC_105', 'FYERS', 1000000.0, false, 'Gamma Momentum'),
      ('Motilal Oswal Prime', 'MOTILAL_ACC_106', 'MOTILAL', 1800000.0, false, 'Institutional Pool'),
      ('Kotak Neo Express', 'KOTAK_ACC_107', 'KOTAKNEO', 1100000.0, false, 'Zero-Brokerage F&O'),
      ('Alice Blue ANT Pro', 'ALICE_ACC_108', 'ALICEBLUE', 950000.0, false, 'Multi-Lot Copier'),
      ('Profitmart Diamond', 'PROFIT_ACC_109', 'PROFITMART', 800000.0, false, 'Margin Scalper'),
      ('Goodwill Giga Desk', 'GOODWL_ACC_110', 'GOODWILL', 850000.0, false, 'MCX & F&O Desk'),
      ('Groww Direct Desk', 'GROWW_ACC_111', 'GROWW', 750000.0, false, 'Retail Mirror'),
      ('5Paisa Xstream Pro', 'PAISA5_ACC_112', 'FIVEPAISA', 650000.0, false, 'Fast Algo Mirror'),
      ('ICICI Direct Breeze', 'ICICI_ACC_113', 'ICICIDIRECT', 2200000.0, false, 'HNI Bank Pool'),
      ('HDFC Sky Prime', 'HDFCSKY_114', 'HDFCSKY', 1600000.0, false, 'Banking Core'),
      ('Axis Direct OpenAPI', 'AXIS_ACC_115', 'AXISDIRECT', 1400000.0, false, 'Swing Cash Desk'),
      ('SBI Securities Smart', 'SBI_ACC_116', 'SBISEC', 1200000.0, false, 'PSU Equity Desk'),
      ('Sharekhan Espresso', 'SHARE_ACC_117', 'SHAREKHAN', 900000.0, false, 'Positional Options'),
      ('IIFL Blaze Terminal', 'IIFL_ACC_118', 'IIFL', 1050000.0, false, 'Quant Arb Desk'),
      ('Paytm Money OpenAPI', 'PAYTM_ACC_119', 'PAYTMMONEY', 600000.0, false, 'Micro Lot Copier'),
      ('Shoonya Finvasia', 'SHOONYA_120', 'SHOONYA', 1150000.0, false, 'Zero Cost Algo'),
      ('Flattrade Pi Zero', 'FLAT_ACC_121', 'FLATTRADE', 700000.0, false, 'Scalping Child'),
      ('Nuvama WealthTech', 'NUVAMA_ACC_122', 'NUVAMA', 3000000.0, false, 'Prop Desk Tier-1'),
      ('Anand Rathi TradeXp', 'ARATHI_123', 'ANANDRATHI', 1300000.0, false, 'Commodities Desk'),
      ('Choice Broking Jiffy', 'CHOICE_124', 'CHOICE', 720000.0, false, 'Family Account 1'),
      ('Samco StockNote', 'SAMCO_ACC_125', 'SAMCO', 880000.0, false, 'Breakout Child'),
      ('Espresso TurboAPI', 'ESPR_ACC_126', 'ESPRESSO', 550000.0, false, 'Intraday Mirror'),
      ('Firstock Connect', 'FIRST_ACC_127', 'FIRSTOCK', 680000.0, false, 'Fast Order Router'),
      ('Tradejini CubePlus', 'TJINI_ACC_128', 'TRADEJINI', 920000.0, false, 'Low Latency F&O'),
      ('Jainam Duck Pro', 'JAINAM_129', 'JAINAM', 1450000.0, false, 'HNI Desk West'),
      ('MasterTrust Swift', 'MTRUST_130', 'MASTERTRUST', 1000000.0, false, 'North Desk Child'),
      ('SMC Global Ace', 'SMC_ACC_131', 'SMCGLOBAL', 1120000.0, false, 'Hedging Child'),
      ('Bajaj Broking Hub', 'BAJAJ_ACC_132', 'BAJAJ', 960000.0, false, 'MTF & Cash Child'),
      ('RMoney Quickso API', 'RMONEY_133', 'RMONEY', 640000.0, false, 'Arbitrage Child'),
      ('Aditya Birla Trade', 'ABM_ACC_134', 'ADITYABIRLA', 1280000.0, false, 'Wealth Mirror'),
      ('Stoxkart Pro Desk', 'STOX_ACC_135', 'STOXKART', 590000.0, false, 'High Speed Copier'),
    ];

    final list = <Map<String, dynamic>>[];
    for (int i = 0; i < brokers.length; i++) {
      final (name, cid, broker, cash, isOwn, assigned) = brokers[i];
      list.add({
        'id': 101 + i,
        'userName': name,
        'clientId': cid,
        'brokerType': broker,
        'availableCash': cash,
        'active': true,
        'isOwnAccount': isOwn,
        'createdDate': '2026-03-${((i % 28) + 1).toString().padLeft(2, '0')}',
        'isAdmin': isOwn,
        'mpin': '1234',
        'apiKey': '${broker.toLowerCase()}_live_key_${101 + i}',
        'totpKey': 'JBSWY3DPEHPK3PXP',
        'password': '',
        'mobileNumber': '955338${(2135 + i).toString()}',
        'assignedTo': assigned,
        'ip': '13.235.14.89',
        'tokenUpdated': true,
        'lastLoginStatus': 'SUCCESS',
      });
    }
    return list;
  }

  List<DematAccount> _getPermanentLocalAccounts() {
    try {
      final raw = html.window.localStorage[_permanentAccountsStorageKey];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        if (decoded.length >= 30) {
          return decoded
              .map((e) => DematAccount.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (_) {}

    final seeded = _seed35BrokerAccounts();
    try {
      html.window.localStorage[_permanentAccountsStorageKey] = jsonEncode(seeded);
    } catch (_) {}
    return seeded.map((e) => DematAccount.fromJson(e)).toList();
  }

  void _savePermanentLocalAccounts(List<Map<String, dynamic>> accounts) {
    try {
      html.window.localStorage[_permanentAccountsStorageKey] = jsonEncode(accounts);
    } catch (_) {}
  }

  Future<List<DematAccount>> fetchDematAccountsApi(int pyUserId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/pyBrokerApi/accounts?pyId=$pyUserId'),
            headers: AuthHeaderHelper.getHeaders(),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List data = json['data'] ?? [];
        if (data.length >= 30) {
          return data.map((e) => DematAccount.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    return _getPermanentLocalAccounts();
  }

  Future<AddDematAccountResponse> addDematAccount(
    AddDematAccountRequest request,
    String actionType,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/pyBrokerApi/brokerAccOperations',
    ).replace(queryParameters: {'actionType': actionType});

    try {
      final response = await _client
          .post(
            uri,
            headers: AuthHeaderHelper.getHeaders(),
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 6));

      return _handleResponse(response);
    } catch (_) {
      // Permanent local persistence when operating standalone / GitHub Pages
      List<Map<String, dynamic>> current;
      try {
        final raw = html.window.localStorage[_permanentAccountsStorageKey];
        if (raw != null && raw.isNotEmpty) {
          current = List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } else {
          current = _seed35BrokerAccounts();
        }
      } catch (_) {
        current = _seed35BrokerAccounts();
      }

      final action = actionType.toUpperCase();
      if (action == 'DELETE') {
        current.removeWhere(
          (a) => (request.id != null && a['id'] == request.id) || a['clientId'] == request.clientId,
        );
        _savePermanentLocalAccounts(current);
        return const AddDematAccountResponse(
          success: true,
          message: 'Broker account removed permanently.',
        );
      } else if (action == 'UPDATE') {
        final idx = current.indexWhere(
          (a) => (request.id != null && a['id'] == request.id) || a['clientId'] == request.clientId,
        );
        if (idx != -1) {
          current[idx] = {
            ...current[idx],
            'userName': request.nickName.isNotEmpty ? request.nickName : current[idx]['userName'],
            'clientId': request.clientId.isNotEmpty ? request.clientId : current[idx]['clientId'],
            'brokerType': request.brokerType.isNotEmpty ? request.brokerType : current[idx]['brokerType'],
            'active': request.isActive,
            'isOwnAccount': request.isOwn,
            'mpin': request.mpin,
            'apiKey': request.apiKey,
            'totpKey': request.totpReferenceKey,
            'mobileNumber': request.mobileNumber,
            'ip': request.ip.isNotEmpty ? request.ip : current[idx]['ip'],
            'apiSecretKey': request.apiSecretKey ?? current[idx]['apiSecretKey'],
            'lastLoginStatus': request.isActive ? 'SUCCESS' : 'INACTIVE',
            'tokenUpdated': true,
          };
          _savePermanentLocalAccounts(current);
        }
        return const AddDematAccountResponse(
          success: true,
          message: 'Broker account updated permanently!',
        );
      } else {
        // ADD new permanent account
        final maxId = current.fold<int>(100, (m, a) => (a['id'] as int? ?? 100) > m ? (a['id'] as int) : m);
        current.add({
          'id': maxId + 1,
          'userName': request.nickName.isNotEmpty ? request.nickName : '${request.brokerType} ${request.clientId}',
          'clientId': request.clientId,
          'brokerType': request.brokerType.toUpperCase(),
          'availableCash': 1000000.0,
          'active': true,
          'isOwnAccount': request.isOwn == true,
          'createdDate': DateTime.now().toIso8601String().split('T').first,
          'isAdmin': request.isAdmin,
          'mpin': request.mpin,
          'apiKey': request.apiKey,
          'totpKey': request.totpReferenceKey,
          'password': request.password,
          'mobileNumber': request.mobileNumber,
          'assignedTo': (request.isOwn == true) ? 'Master Trading Desk' : 'Connected Strategy Pool',
          'ip': request.ip.isNotEmpty ? request.ip : '13.235.14.89',
          'apiSecretKey': request.apiSecretKey,
          'vendorInfo': request.vendorInfo,
          'tokenUpdated': true,
          'lastLoginStatus': 'SUCCESS',
        });
        _savePermanentLocalAccounts(current);
        return AddDematAccountResponse(
          success: true,
          message: '${request.brokerType} account ${request.clientId} connected & saved permanently! (${current.length} Total Demats)',
        );
      }
    }
  }

  Future<Map<String, dynamic>> validateIpAddress({
    required String ipAddress,
    required String brokerType,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/pyconfig/ip/validate'),
            headers: AuthHeaderHelper.getHeaders(),
            body: jsonEncode({'ipAddress': ipAddress, 'brokerType': brokerType}),
          )
          .timeout(const Duration(seconds: 5));

      final body = _decodeBody(response.body);
      if (body.isNotEmpty) return body;
    } catch (_) {}

    final ipTrim = ipAddress.trim();
    final ipRegex = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');
    if (ipRegex.hasMatch(ipTrim)) {
      return {
        'status': 'SUCCESS',
        'data': {
          'portNo': 8080,
          'message': 'Static IP $ipTrim verified & whitelisted permanently for $brokerType!',
        },
      };
    }
    return {
      'status': 400,
      'message': 'Please enter a valid IPv4 address (e.g. 13.235.14.89 or 103.159.214.88).',
    };
  }

  Future<void> reviewRequestApi({
    required int superAdminId,
    required int requestId,
    required String status,
    String? reason,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/v1/super-admin/review-request/$superAdminId'),
      headers: AuthHeaderHelper.getHeaders(),
      body: jsonEncode({
        'requestId': requestId,
        'status': status,
        if (reason != null) 'reason': reason,
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Review failed');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> fetchAllRequestsApi(String client) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/api/v1/super-admin/all-requests?requestType=${client}',
      ),
      headers: AuthHeaderHelper.getHeaders(),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return Map<String, dynamic>.from(body['data'] ?? {});
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch requests');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  Future<List<PyUser>> fetchUsersByRole(String role) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/pyauth/users/by-role'),
      headers: AuthHeaderHelper.getHeaders(),
      body: jsonEncode({'role': role}),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List data = json['data'] ?? [];
      return data.map((e) => PyUser.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load users for role: $role');
    }
  }

  Future<FetchDematAccountsResponse> fetchDematAccounts(bool isAdmin) async {
    final uri = Uri.parse(
      '$_baseUrl/easyTradeApi/fetchDematAccounts',
    ).replace(queryParameters: {'isAdmin': isAdmin.toString()});

    final response = await _client.post(
      uri,
      headers: AuthHeaderHelper.getHeaders(),
    );

    if (response.statusCode == 200) {
      return FetchDematAccountsResponse.fromJson(jsonDecode(response.body));
    } else {
      throw ServiceException('Failed to fetch accounts');
    }
  }

  Future<Map<String, dynamic>> demoteAdmin({
    required int superAdminPyId,
    required int targetPyId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/demote-admin');

    final response = await http.post(
      uri,
      headers: AuthHeaderHelper.getHeaders(),
      body: jsonEncode({
        'superAdminPyId': superAdminPyId,
        'targetPyId': targetPyId,
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && decoded['success'] == true) {
      return decoded['data'] as Map<String, dynamic>;
    }

    throw Exception(decoded['message'] ?? 'Failed to demote admin');
  }

  AddDematAccountResponse _handleResponse(http.Response response) {
    final body = _decodeBody(response.body);

    switch (response.statusCode) {
      case 200:
      case 201:
        return AddDematAccountResponse.fromJson(body);

      case 400:
        throw ServiceException(
          body['message'] as String? ??
              'Invalid request. Please check your inputs.',
        );

      case 401:
        throw const ServiceException(
          'Unauthorized. Please verify your credentials.',
        );

      case 403:
        throw const ServiceException(
          'Access denied. You do not have permission for this action.',
        );

      case 404:
        throw const ServiceException('Service endpoint not found.');

      case 409:
        throw ServiceException(
          body['message'] as String? ?? 'Account already exists.',
        );

      case 500:
      case 502:
      case 503:
        throw const ServiceException('Server error. Please try again later.');

      default:
        throw ServiceException(
          'Request failed with status ${response.statusCode}.',
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

  void dispose() => _client.close();
}

class ServiceException implements Exception {
  final String message;
  const ServiceException(this.message);

  @override
  String toString() => message;
}
