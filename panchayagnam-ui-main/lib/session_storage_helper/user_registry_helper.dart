import 'dart:convert';
import 'dart:html' as html;

class RegisteredUser {
  final String phoneNumber;
  final String mpin;
  final String fullName;
  final String email;
  final String role;
  final int userId;
  final String registeredAt;

  RegisteredUser({
    required this.phoneNumber,
    required this.mpin,
    required this.fullName,
    required this.email,
    this.role = 'PRO_TRADER',
    required this.userId,
    String? registeredAt,
  }) : registeredAt = registeredAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => {
    'phoneNumber': phoneNumber,
    'mpin': mpin,
    'fullName': fullName,
    'email': email,
    'role': role,
    'userId': userId,
    'registeredAt': registeredAt,
  };

  factory RegisteredUser.fromJson(Map<String, dynamic> json) => RegisteredUser(
    phoneNumber: (json['phoneNumber'] ?? '').toString().trim(),
    mpin: (json['mpin'] ?? '').toString().trim(),
    fullName: (json['fullName'] ?? '').toString().trim(),
    email: (json['email'] ?? '').toString().trim(),
    role: (json['role'] ?? 'PRO_TRADER').toString(),
    userId: json['userId'] is int
        ? json['userId']
        : int.tryParse(json['userId']?.toString() ?? '') ?? 1001,
    registeredAt: json['registeredAt']?.toString(),
  );
}

class UserRegistryHelper {
  static const String _storageKey = 'panchayagnam_registered_users_db_v2';
  static const String _otpStorageKey = 'panchayagnam_pending_otps_v1';

  /// Normalizes any Indian mobile input (e.g. "+91 98765 43210", "09876543210")
  /// down to its canonical 10-digit form when 10 or more digits are present.
  static String normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Extracts a 6-digit OTP code from server trial/demo status messages.
  static String? extractOtp(String? message) {
    if (message == null || message.isEmpty) return null;
    final match = RegExp(r'\b(\d{6})\b').firstMatch(message);
    return match?.group(1);
  }

  static String generateTrialOtp() {
    final code = 100000 + (DateTime.now().millisecondsSinceEpoch % 899999);
    return code.toString();
  }

  static void savePendingOtp(String phoneNumber, String otp) {
    final normalized = normalizePhone(phoneNumber);
    if (normalized.isEmpty || otp.trim().isEmpty) return;
    try {
      final raw = html.window.localStorage[_otpStorageKey];
      final Map<String, dynamic> otps = raw != null && raw.trim().isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : {};
      otps[normalized] = {
        'otp': otp.trim(),
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch,
      };
      html.window.localStorage[_otpStorageKey] = jsonEncode(otps);
    } catch (_) {}
  }

  static bool verifyPendingOtp(String phoneNumber, String otp) {
    final normalized = normalizePhone(phoneNumber);
    final entered = otp.trim();
    if (entered.length != 6) return false;
    try {
      final raw = html.window.localStorage[_otpStorageKey];
      if (raw == null || raw.trim().isEmpty) return false;
      final otps = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = otps[normalized];
      if (entry is Map) {
        final savedOtp = (entry['otp'] ?? '').toString().trim();
        final expiresAt = entry['expiresAt'] is int
            ? entry['expiresAt'] as int
            : int.tryParse(entry['expiresAt']?.toString() ?? '') ?? 0;
        if (savedOtp == entered &&
            DateTime.now().millisecondsSinceEpoch <= expiresAt) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // Seed / Administrator account
  static final Map<String, RegisteredUser> _seedUsers = {
    '9390076827': RegisteredUser(
      phoneNumber: '9390076827',
      mpin: '1234',
      fullName: 'Sanjeev Reddy',
      email: 'support@panchayagnam.com',
      role: 'PRO_TRADER',
      userId: 1001,
    ),
  };

  static Map<String, RegisteredUser> getAllUsers() {
    final Map<String, RegisteredUser> users = Map<String, RegisteredUser>.from(_seedUsers);
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map) {
            final parsed = RegisteredUser.fromJson(
              Map<String, dynamic>.from(entry.value),
            );
            final key = normalizePhone(
              parsed.phoneNumber.isNotEmpty ? parsed.phoneNumber : entry.key,
            );
            if (key.isNotEmpty) {
              users[key] = RegisteredUser(
                phoneNumber: key,
                mpin: parsed.mpin,
                fullName: parsed.fullName,
                email: parsed.email,
                role: parsed.role,
                userId: parsed.userId,
                registeredAt: parsed.registeredAt,
              );
            }
          }
        }
      }
    } catch (_) {}
    return users;
  }

  static RegisteredUser? findUser(String phoneNumber) {
    final users = getAllUsers();
    final key = normalizePhone(phoneNumber);
    return users[key] ?? users[phoneNumber.trim()];
  }

  static void saveUser(RegisteredUser user) {
    final users = getAllUsers();
    final key = normalizePhone(user.phoneNumber);
    final normalizedUser = RegisteredUser(
      phoneNumber: key.isNotEmpty ? key : user.phoneNumber.trim(),
      mpin: user.mpin.trim(),
      fullName: user.fullName.trim(),
      email: user.email.trim(),
      role: user.role,
      userId: user.userId,
      registeredAt: user.registeredAt,
    );
    users[normalizedUser.phoneNumber] = normalizedUser;
    final jsonMap = users.map((k, v) => MapEntry(k, v.toJson()));
    try {
      html.window.localStorage[_storageKey] = jsonEncode(jsonMap);
    } catch (_) {}
  }

  static bool updateMpin(String phoneNumber, String newMpin) {
    final users = getAllUsers();
    final key = normalizePhone(phoneNumber);
    final user = users[key] ?? users[phoneNumber.trim()];
    if (user != null) {
      final updated = RegisteredUser(
        phoneNumber: key.isNotEmpty ? key : user.phoneNumber,
        mpin: newMpin.trim(),
        fullName: user.fullName,
        email: user.email,
        role: user.role,
        userId: user.userId,
      );
      users[updated.phoneNumber] = updated;
      final jsonMap = users.map((k, v) => MapEntry(k, v.toJson()));
      try {
        html.window.localStorage[_storageKey] = jsonEncode(jsonMap);
      } catch (_) {}
      return true;
    }
    return false;
  }
}
