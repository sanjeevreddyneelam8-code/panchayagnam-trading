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
            users[entry.key] = RegisteredUser.fromJson(Map<String, dynamic>.from(entry.value));
          }
        }
      }
    } catch (_) {}
    return users;
  }

  static RegisteredUser? findUser(String phoneNumber) {
    final users = getAllUsers();
    return users[phoneNumber.trim()];
  }

  static void saveUser(RegisteredUser user) {
    final users = getAllUsers();
    users[user.phoneNumber.trim()] = user;
    final jsonMap = users.map((k, v) => MapEntry(k, v.toJson()));
    try {
      html.window.localStorage[_storageKey] = jsonEncode(jsonMap);
    } catch (_) {}
  }

  static bool updateMpin(String phoneNumber, String newMpin) {
    final users = getAllUsers();
    final user = users[phoneNumber.trim()];
    if (user != null) {
      final updated = RegisteredUser(
        phoneNumber: user.phoneNumber,
        mpin: newMpin.trim(),
        fullName: user.fullName,
        email: user.email,
        role: user.role,
        userId: user.userId,
      );
      users[user.phoneNumber] = updated;
      final jsonMap = users.map((k, v) => MapEntry(k, v.toJson()));
      try {
        html.window.localStorage[_storageKey] = jsonEncode(jsonMap);
      } catch (_) {}
      return true;
    }
    return false;
  }
}
