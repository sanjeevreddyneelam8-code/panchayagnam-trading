import 'dart:html' as html;

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;

  UserSession._internal() {
    _loadFromStorage();
  }

  String token = '';
  String role = '';
  String fullName = '';
  String email = '';
  String phoneNumber = '';
  int userId = 0;

  void _loadFromStorage() {
    try {
      token = html.window.sessionStorage['auth_token'] ?? '';
      role = html.window.sessionStorage['user_role'] ?? '';
      fullName = html.window.sessionStorage['user_fullName'] ?? '';
      email = html.window.sessionStorage['user_email'] ?? '';
      phoneNumber = html.window.sessionStorage['user_phoneNumber'] ?? '';
      userId = int.tryParse(html.window.sessionStorage['user_id'] ?? '0') ?? 0;
    } catch (_) {}
  }

  void set({
    required String token,
    required String role,
    required String fullName,
    required String email,
    required String phoneNumber,
    required int userId,
  }) {
    this.token = token;
    this.role = role;
    this.fullName = fullName;
    this.email = email;
    this.phoneNumber = phoneNumber;
    this.userId = userId;

    try {
      html.window.sessionStorage['auth_token'] = token;
      html.window.sessionStorage['user_role'] = role;
      html.window.sessionStorage['user_fullName'] = fullName;
      html.window.sessionStorage['user_email'] = email;
      html.window.sessionStorage['user_phoneNumber'] = phoneNumber;
      html.window.sessionStorage['user_id'] = userId.toString();
    } catch (_) {}
  }

  void clear() {
    token = '';
    role = '';
    fullName = '';
    email = '';
    phoneNumber = '';
    userId = 0;

    try {
      html.window.sessionStorage.remove('auth_token');
      html.window.sessionStorage.remove('user_role');
      html.window.sessionStorage.remove('user_fullName');
      html.window.sessionStorage.remove('user_email');
      html.window.sessionStorage.remove('user_phoneNumber');
      html.window.sessionStorage.remove('user_id');
    } catch (_) {}
  }

  bool get isLoggedIn => token.isNotEmpty;

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}