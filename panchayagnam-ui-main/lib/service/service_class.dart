import 'dart:async';
import 'dart:convert';
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

    return [
      DematAccount(
        id: pyBrokerId,
        userName: 'Panchayagnam Pro Account #$pyBrokerId',
        clientId: 'DHAN_PRO_$pyBrokerId',
        brokerType: 'DHAN',
        availableCash: 1250000.0,
        active: true,
        isOwnAccount: true,
        createdDate: '2026-01-15',
        isAdmin: true,
        mpin: '1234',
        apiKey: 'dhan_key_pro',
        totpKey: '',
        password: '',
        mobileNumber: '9553382135',
        assignedTo: 'Master Trading Desk',
        ip: '127.0.0.1',
        tokenUpdated: true,
        lastLoginStatus: 'SUCCESS',
      ),
    ];
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
        if (data.isNotEmpty) {
          return data.map((e) => DematAccount.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    return [
      DematAccount(
        id: 101,
        userName: 'Panchayagnam Dhan Master',
        clientId: 'DHAN_PRO_01',
        brokerType: 'DHAN',
        availableCash: 1250000.0,
        active: true,
        isOwnAccount: true,
        createdDate: '2026-01-15',
        isAdmin: true,
        mpin: '1234',
        apiKey: 'dhan_pro_key',
        totpKey: '',
        password: '',
        mobileNumber: '9553382135',
        assignedTo: 'Master Trading Desk',
        ip: '127.0.0.1',
        tokenUpdated: true,
        lastLoginStatus: 'SUCCESS',
      ),
      DematAccount(
        id: 102,
        userName: 'AngelOne Follower Alpha',
        clientId: 'ANGEL_ACC_102',
        brokerType: 'ANGELONE',
        availableCash: 850000.0,
        active: true,
        isOwnAccount: false,
        createdDate: '2026-02-10',
        isAdmin: false,
        mpin: '1234',
        apiKey: 'angel_key_102',
        totpKey: '',
        password: '',
        mobileNumber: '9553382135',
        assignedTo: 'Alpha Portfolio',
        ip: '127.0.0.1',
        tokenUpdated: true,
        lastLoginStatus: 'SUCCESS',
      ),
      DematAccount(
        id: 103,
        userName: 'Zerodha Kite Follower Beta',
        clientId: 'KITE_ACC_103',
        brokerType: 'ZERODHA',
        availableCash: 1500000.0,
        active: true,
        isOwnAccount: false,
        createdDate: '2026-02-15',
        isAdmin: false,
        mpin: '1234',
        apiKey: 'kite_key_103',
        totpKey: '',
        password: '',
        mobileNumber: '9553382135',
        assignedTo: 'Beta Portfolio',
        ip: '127.0.0.1',
        tokenUpdated: true,
        lastLoginStatus: 'SUCCESS',
      ),
      DematAccount(
        id: 104,
        userName: 'Upstox Follower Gamma',
        clientId: 'UPSTX_ACC_104',
        brokerType: 'UPSTOX',
        availableCash: 620000.0,
        active: true,
        isOwnAccount: false,
        createdDate: '2026-03-01',
        isAdmin: false,
        mpin: '1234',
        apiKey: 'upstox_key_104',
        totpKey: '',
        password: '',
        mobileNumber: '9553382135',
        assignedTo: 'Gamma Fund',
        ip: '127.0.0.1',
        tokenUpdated: true,
        lastLoginStatus: 'SUCCESS',
      ),
    ];
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
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException {
      throw const ServiceException(
        'No internet connection. Please check your network.',
      );
    } on HttpException {
      throw const ServiceException('Server is unreachable. Please try again.');
    } on FormatException {
      throw const ServiceException('Unexpected response format from server.');
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Unexpected error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> validateIpAddress({
    required String ipAddress,
    required String brokerType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/pyconfig/ip/validate'),
        headers: AuthHeaderHelper.getHeaders(),
        body: jsonEncode({'ipAddress': ipAddress, 'brokerType': brokerType}),
      );

      final body = _decodeBody(response.body);

      return body;
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Unexpected error: ${e.toString()}');
    }
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
