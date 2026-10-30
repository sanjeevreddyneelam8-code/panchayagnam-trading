class DematAccount {
  final int id;
  final String userName;
  final String clientId;
  final String brokerType;
  final double availableCash;
  final bool active;
  final bool isOwnAccount;
  final String createdDate;
  final bool isAdmin;
  final String mpin;
  final String apiKey;
  final String totpKey;
  final String password;
  final String mobileNumber;
  final String? dob;
  final List<String>? childIds;
  final String? assignedTo;
  final String? ip;
  // ── Motilal-specific ──────────────────────────────────────────────────────
  final String? apiSecretKey;
  final String? vendorInfo;
  final bool? tokenUpdated;
  // ── Connection Status ─────────────────────────────────────────────────────
  final String? lastLoginStatus;
  final String? lastLoginError;
  final String? lastLoginAttempt;

  DematAccount({
    required this.id,
    required this.userName,
    required this.clientId,
    required this.brokerType,
    required this.availableCash,
    required this.active,
    required this.isOwnAccount,
    required this.createdDate,
    required this.isAdmin,
    required this.mpin,
    required this.apiKey,
    required this.mobileNumber,
    required this.totpKey,
    required this.password,
    required this.assignedTo,
    required this.ip,
    required this.tokenUpdated,
    this.lastLoginStatus,
    this.lastLoginError,
    this.lastLoginAttempt,
    this.dob,
    this.childIds,
    this.apiSecretKey,
    this.vendorInfo,
  });

  factory DematAccount.fromJson(Map<String, dynamic> json) => DematAccount(
    id: json['id'] ?? 0,
    userName: json['userName'] ?? '',
    clientId: json['clientId'] ?? '',
    brokerType: json['brokerType'] ?? '',
    mobileNumber: json['mobileNumber'] ?? '',
    availableCash: (json['availableCash'] ?? 0).toDouble(),
    active: json['active'] ?? false,
    isOwnAccount: json['isOwnAccount'] ?? false,
    createdDate: json['createdDate'] ?? '',
    isAdmin: json['isAdmin'] ?? false,
    mpin: json['mpin'] ?? '',
    apiKey: json['apiKey'] ?? '',
    totpKey: json['totpKey'] ?? '',
    password: json['password'] ?? '',
    assignedTo: json['assignedTo'] ?? '',
    ip: json['ip'] ?? '',
    lastLoginStatus: json['lastLoginStatus'],
    lastLoginError: json['lastLoginError'],
    lastLoginAttempt: json['lastLoginAttempt']?.toString(),
    // dob comes back as "dob" for AngelOne, "twoFa" for Motilal
    dob: json['dob'] ?? json['twoFa'],
    childIds: json['childIds'] != null
        ? List<String>.from(json['childIds'])
        : null,
    // Motilal-specific — null for other brokers
    apiSecretKey: json['apiSecretKey'],
    vendorInfo: json['vendorInfo'],
    tokenUpdated: json['tokenUpdated'],
  );

  /// Real connection verification: Active and authenticated by broker API
  bool get isConnected => active && (lastLoginStatus == 'SUCCESS' || lastLoginStatus == null && active);
  bool get isAuthFailed => active && lastLoginStatus == 'FAILED';

  /// Convenience getter so callers don't need to know the broker
  bool get isMotilal => brokerType.toUpperCase().contains('MOTILAL');
}
