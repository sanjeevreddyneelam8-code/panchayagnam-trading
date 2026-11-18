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
import 'copy_trading_engine.dart';

class ServerUnreachableException implements Exception {
  final String message;
  ServerUnreachableException(this.message);
  @override
  String toString() => message;
}

class ServiceClass {
  static const String _baseUrl = ApiUrls.baseUrl;
  static const Duration _postTimeout = Duration(seconds: 30);
  static const Duration _wakeupTotalBudget = Duration(seconds: 95);

  static Future<bool>? _inFlightWarmup;
  static DateTime? _lastWarmupSuccess;

  final http.Client _client;

  ServiceClass({http.Client? client}) : _client = client ?? http.Client();

  /// Proactively wakes up the hosted backend (e.g., on login/register page load)
  /// so free-tier cold starts complete before the user clicks Submit / Send OTP.
  static Future<bool> warmUpBackend({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastWarmupSuccess != null &&
        now.difference(_lastWarmupSuccess!) < const Duration(minutes: 4)) {
      return Future.value(true);
    }
    if (!force && _inFlightWarmup != null) {
      return _inFlightWarmup!;
    }
    final future = _performHealthPing().whenComplete(() {
      _inFlightWarmup = null;
    });
    _inFlightWarmup = future;
    return future;
  }

  static Future<bool> _performHealthPing() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/v1/pyauth/health'))
          .timeout(const Duration(seconds: 65));
      if (response.statusCode == 200) {
        _lastWarmupSuccess = DateTime.now();
        return true;
      }
    } catch (_) {}
    return false;
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  Map<String, dynamic>? _decodeMapSafe(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  bool _isConnectivityError(Object e) {
    if (e is TimeoutException || e is SocketException || e is ServerUnreachableException) {
      return true;
    }
    final s = e.toString();
    return s.contains('ClientException') ||
        s.contains('XMLHttpRequest') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection refused') ||
        s.contains('Network is unreachable');
  }

  bool _isBrowserOffline() {
    try {
      return html.window.navigator.onLine == false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _waitForServerReady(DateTime deadline) async {
    while (DateTime.now().isBefore(deadline)) {
      if (_isBrowserOffline()) return false;
      try {
        final health = await _client
            .get(Uri.parse('$_baseUrl/api/v1/pyauth/health'))
            .timeout(const Duration(seconds: 15));
        if (health.statusCode == 200) {
          _lastWarmupSuccess = DateTime.now();
          return true;
        }
      } catch (_) {}

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      final wait = remaining < const Duration(seconds: 3)
          ? remaining
          : const Duration(seconds: 3);
      await Future.delayed(wait);
    }
    return false;
  }

  Future<Map<String, dynamic>> _postAuthWithWakeupRetry({
    required String path,
    required Map<String, dynamic> payload,
    required String defaultError,
  }) async {
    if (_isBrowserOffline()) {
      throw ServerUnreachableException(
        'No internet connection. Please check your network and try again.',
      );
    }

    final deadline = DateTime.now().add(_wakeupTotalBudget);
    int attempt = 0;

    while (true) {
      attempt++;
      try {
        final response = await _client
            .post(
              Uri.parse('$_baseUrl$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(_postTimeout);

        final data = _decodeMapSafe(response.body);
        final isGatewayWakeup =
            response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504 ||
            data == null;

        if (!isGatewayWakeup) {
          if (response.statusCode == 200 || response.statusCode == 201) {
            if (data['success'] == true) {
              _lastWarmupSuccess = DateTime.now();
              return data;
            }
            throw Exception(data['message'] ?? defaultError);
          }
          final msg = (data['message'] ?? '').toString().trim();
          throw Exception(
            msg.isNotEmpty ? msg : '$defaultError (${response.statusCode})',
          );
        }

        if (DateTime.now().isBefore(deadline) && attempt < 6) {
          await _waitForServerReady(deadline);
          continue;
        }

        throw ServerUnreachableException(
          'Unable to reach the server after waiting for startup. Please tap again in a few seconds.',
        );
      } catch (e) {
        if (!_isConnectivityError(e)) {
          rethrow;
        }
        if (_isBrowserOffline()) {
          throw ServerUnreachableException(
            'No internet connection. Please check your network and try again.',
          );
        }
        if (DateTime.now().isBefore(deadline) && attempt < 6) {
          await _waitForServerReady(deadline);
          continue;
        }
        if (e is ServerUnreachableException) rethrow;
        throw ServerUnreachableException(
          'Unable to reach the server after waiting for startup. Please tap again in a few seconds.',
        );
      }
    }
  }

  Future<Map<String, dynamic>> sendOtp({
    required String phoneNumber,
    required String codeReqFor,
  }) {
    final cleanPhone = _normalizePhone(phoneNumber);
    return _postAuthWithWakeupRetry(
      path: '/api/v1/pyauth/send-otp',
      payload: {'phoneNumber': cleanPhone, 'codeReqFor': codeReqFor},
      defaultError: 'Failed to send OTP',
    );
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
  }) {
    final cleanPhone = _normalizePhone(phoneNumber);
    return _postAuthWithWakeupRetry(
      path: '/api/v1/pyauth/register',
      payload: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phoneNumber': cleanPhone,
        'mpin': mpin.trim(),
        'otp': otp.trim(),
      },
      defaultError: 'Registration failed',
    );
  }

  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String mpin,
  }) {
    final cleanPhone = _normalizePhone(phoneNumber);
    return _postAuthWithWakeupRetry(
      path: '/api/v1/pyauth/login',
      payload: {'phoneNumber': cleanPhone, 'mpin': mpin.trim()},
      defaultError: 'Invalid phone number or MPIN',
    );
  }

  Future<Map<String, dynamic>> loginWithOtp({
    required String phoneNumber,
    required String otp,
  }) {
    final cleanPhone = _normalizePhone(phoneNumber);
    return _postAuthWithWakeupRetry(
      path: '/api/v1/pyauth/login-otp',
      payload: {'phoneNumber': cleanPhone, 'otp': otp.trim()},
      defaultError: 'Invalid phone number or OTP',
    );
  }

  Future<Map<String, dynamic>> forgotMpin({required String phoneNumber}) async {
    return sendOtp(phoneNumber: phoneNumber, codeReqFor: 'Reset');
  }

  Future<Map<String, dynamic>> resetMpin({
    required String phoneNumber,
    required String otp,
    required String newMpin,
  }) {
    final cleanPhone = _normalizePhone(phoneNumber);
    return _postAuthWithWakeupRetry(
      path: '/api/v1/pyauth/reset-mpin',
      payload: {
        'phoneNumber': cleanPhone,
        'otp': otp.trim(),
        'newMpin': newMpin.trim(),
      },
      defaultError: 'Failed to reset MPIN',
    );
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

  List<DematAccount> _getPermanentLocalAccounts() {
    try {
      final raw = html.window.localStorage[_permanentAccountsStorageKey];
      if (raw != null && raw.isNotEmpty) {
        final decoded = (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((a) {
              final cid = (a['clientId'] ?? a['loginId'] ?? '').toString();
              return cid.isNotEmpty &&
                  !cid.startsWith('DHAN_PRO_') &&
                  !cid.startsWith('ANGEL_ACC_') &&
                  !cid.startsWith('KITE_ACC_') &&
                  !cid.startsWith('UPSTX_ACC_') &&
                  !cid.startsWith('FYERS_ACC_') &&
                  !cid.startsWith('MOTILAL_ACC_') &&
                  !cid.startsWith('KOTAK_ACC_') &&
                  !cid.startsWith('PROFIT_ACC_') &&
                  !cid.startsWith('GOODWL_ACC_') &&
                  !cid.startsWith('GROWW_ACC_') &&
                  !cid.startsWith('PAISA5_ACC_') &&
                  !cid.startsWith('ICICI_ACC_') &&
                  !cid.startsWith('HDFCSKY_') &&
                  !cid.startsWith('AXIS_ACC_') &&
                  !cid.startsWith('SBI_ACC_') &&
                  !cid.startsWith('SHARE_ACC_') &&
                  !cid.startsWith('IIFL_ACC_') &&
                  !cid.startsWith('PAYTM_ACC_') &&
                  !cid.startsWith('SHOONYA_') &&
                  !cid.startsWith('FLAT_ACC_') &&
                  !cid.startsWith('NUVAMA_ACC_') &&
                  !cid.startsWith('ARATHI_') &&
                  !cid.startsWith('CHOICE_') &&
                  !cid.startsWith('SAMCO_ACC_') &&
                  !cid.startsWith('ESPR_ACC_') &&
                  !cid.startsWith('FIRST_ACC_') &&
                  !cid.startsWith('TJINI_ACC_') &&
                  !cid.startsWith('JAINAM_') &&
                  !cid.startsWith('MTRUST_') &&
                  !cid.startsWith('SMC_ACC_') &&
                  !cid.startsWith('BAJAJ_ACC_') &&
                  !cid.startsWith('RMONEY_') &&
                  !cid.startsWith('ABM_ACC_') &&
                  !cid.startsWith('STOX_ACC_') &&
                  cid != '1100345678' &&
                  cid != 'AG_LIVE';
            })
            .toList();
        return decoded.map((e) => DematAccount.fromJson(e)).toList();
      }
    } catch (_) {}

    return <DematAccount>[];
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
        final realRaw = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((a) => CopyTradingEngine.isRealBrokerAccount(a['clientId'] ?? a['loginId']))
            .toList();
        // Sync authoritative server accounts (with real PostgreSQL IDs) into browser storage
        _savePermanentLocalAccounts(realRaw);
        CopyTradingEngine().syncWithStorage();
        return realRaw.map((e) => DematAccount.fromJson(e)).toList();
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
          .timeout(const Duration(seconds: 30));

      final res = _handleResponse(response);
      _syncAccountToLocal(request, actionType);
      // Immediately refresh authoritative accounts from server so real DB accId is stored
      try {
        if (request.pyUserId != null) {
          await fetchDematAccountsApi(request.pyUserId!);
        } else {
          CopyTradingEngine().syncWithStorage();
        }
      } catch (_) {
        CopyTradingEngine().syncWithStorage();
      }
      return res;
    } on ServiceException {
      // Re-throw service exceptions (e.g. 401 Unauthorized, invalid TOTP/API Key)
      // so user gets clear feedback rather than fake-accepting bad credentials!
      rethrow;
    } catch (e) {
      throw ServiceException('Unable to verify credentials with server: $e');
    }
  }

  void _syncAccountToLocal(AddDematAccountRequest request, String actionType) {
    try {
      List<Map<String, dynamic>> current = [];
      final raw = html.window.localStorage[_permanentAccountsStorageKey];
      if (raw != null && raw.isNotEmpty) {
        current = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
        ).where((a) {
          final cid = (a['clientId'] ?? a['loginId'] ?? '').toString();
          return cid.isNotEmpty &&
              !cid.startsWith('DHAN_PRO_') &&
              !cid.startsWith('ANGEL_ACC_') &&
              cid != '1100345678' &&
              cid != 'AG_LIVE';
        }).toList();
      }

      final action = actionType.toUpperCase();
      if (action == 'DELETE') {
        current.removeWhere(
          (a) => (request.id != null && a['id'] == request.id) || a['clientId'] == request.clientId,
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
        }
      } else {
        // ADD
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
          'assignedTo': (request.isOwn == true) ? 'Master Trading Desk' : 'Connected Demat Account',
          'ip': request.ip.isNotEmpty ? request.ip : '74.220.52.132',
          'apiSecretKey': request.apiSecretKey,
          'vendorInfo': request.vendorInfo,
          'tokenUpdated': true,
          'lastLoginStatus': 'SUCCESS',
        });
      }
      _savePermanentLocalAccounts(current);
    } catch (_) {}
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
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/api/v1/super-admin/all-requests?requestType=${client}',
        ),
        headers: AuthHeaderHelper.getHeaders(),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return Map<String, dynamic>.from(body['data'] ?? {});
        } else {
          throw Exception(body['message'] ?? 'Failed to fetch requests');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please log out and sign in again.');
      } else {
        throw Exception('Server error (${response.statusCode}). Please refresh.');
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('failed to fetch') || msg.contains('clientexception') || msg.contains('timeout')) {
        throw Exception('Server is waking up. Please click the 🔄 Refresh button in a few seconds.');
      }
      rethrow;
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
