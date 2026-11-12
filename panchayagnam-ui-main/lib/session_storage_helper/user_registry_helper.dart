import 'dart:html' as html;

/// Client-side phone/OTP formatting helpers.
/// Security note: Credentials, MPINs, and OTP verification live strictly on the backend.
class UserRegistryHelper {
  static const String _legacyUsersStorageKey = 'panchayagnam_registered_users_db_v2';
  static const String _legacyOtpStorageKey = 'panchayagnam_pending_otps_v1';

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

  /// Purges any legacy plaintext credential/OTP entries left in browser localStorage.
  static void purgeLegacySensitiveStorage() {
    try {
      html.window.localStorage.remove(_legacyUsersStorageKey);
      html.window.localStorage.remove(_legacyOtpStorageKey);
    } catch (_) {}
  }
}
