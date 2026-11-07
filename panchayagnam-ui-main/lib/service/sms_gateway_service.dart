/// Server-Side SMS Gateway Architecture
/// 
/// Security Policy:
/// 1. FAST2SMS_API_KEY is stored strictly as a server environment variable.
/// 2. No API keys or SMS secrets are stored or handled in Flutter Web or browser localStorage.
/// 3. All OTP dispatches and verifications are processed via the Spring Boot backend (/api/v1/pyauth/send-otp).
library;

class SmsGatewayResult {
  final bool success;
  final String message;
  final String? otp;

  const SmsGatewayResult({
    required this.success,
    required this.message,
    this.otp,
  });
}
