class AddDematAccountRequest {
  final int? id;          // ← needed for UPDATE / DELETE actions
  final String clientId;
  final String apiKey;
  final String mpin;
  final String password;  // ← needed for AngelOne / other brokers
  final String totpReferenceKey;
  final String brokerType;
  final bool isAdmin;
  final bool isActive;
  final bool? isOwn;
  final List<String> childIds;
  final String nickName;
  final String ip;
  final String? dob;
  final int? pyUserId;
  // ── Motilal-specific ──────────────────────────────────────────────────────
  final String? apiSecretKey;
  final String? vendorInfo;
  final String? mobileNumber;

  AddDematAccountRequest({
    this.id,
    required this.clientId,
    required this.apiKey,
    required this.mpin,
    required this.password,
    required this.totpReferenceKey,
    required this.brokerType,
    required this.isAdmin,
    required this.mobileNumber,
    required this.isActive,
    required this.isOwn,
    required this.childIds,
    required this.nickName,
    required this.ip,
    required this.pyUserId,
    this.dob,
    this.apiSecretKey,
    this.vendorInfo,
  });

  bool get _isMotilal => brokerType.toUpperCase().contains('MOTILAL');

  Map<String, dynamic> toJson() {
    return {
      // id only sent on UPDATE / DELETE — omitted on ADD
      if (id != null) "id": id,

      "clientId": clientId,
      "apiKey": apiKey,
      "mpin": mpin,
      "totpReferenceKey": totpReferenceKey,
      "brokerType": brokerType,
      "mobileNumber": mobileNumber,
      "isAdmin": isAdmin,
      "isActive": isActive,
      "isOwn": isOwn,
      "childIds": childIds,
      "nickName": nickName,
      "ip": ip,
      "pyUserId": pyUserId,

      // password only relevant for non-Motilal brokers
      if (!_isMotilal && password.isNotEmpty) "password": password,

      // dob key differs per broker:
      // • Motilal → "twoFa"
      // • Others  → "dob"
      if (dob != null && dob!.isNotEmpty)
        (_isMotilal ? "twoFa" : "dob"): dob,

      // Sensitive broker credentials passed when provided
      if (apiSecretKey != null && apiSecretKey!.isNotEmpty)
        "apiSecretKey": apiSecretKey,
      if (_isMotilal)
        "vendorInfo": (vendorInfo?.isNotEmpty == true) ? vendorInfo : clientId
      else if (vendorInfo != null && vendorInfo!.isNotEmpty)
        "vendorInfo": vendorInfo,
    };
  }

  factory AddDematAccountRequest.fromJson(Map<String, dynamic> json) {
    return AddDematAccountRequest(
      id: json["id"],
      clientId: json["clientId"] ?? "",
      apiKey: json["apiKey"] ?? "",
      mpin: json["mpin"] ?? "",
      password: json["password"] ?? "",
      totpReferenceKey: json["totpReferenceKey"] ?? "",
      brokerType: json["brokerType"] ?? "",
      mobileNumber: json["mobileNumber"] ?? "",
      isAdmin: json["isAdmin"] ?? false,
      isActive: json["isActive"] ?? true,
      isOwn: json["isOwn"] ?? false,
      childIds: List<String>.from(json["childIds"] ?? []),
      nickName: json["nickName"] ?? "",
      ip: json["ip"] ?? "",
      pyUserId: json["pyUserId"] ?? 0,
      // Accept either key from API response
      dob: json["dob"] ?? json["twoFa"],
      apiSecretKey: json["apiSecretKey"],
      vendorInfo: json["vendorInfo"],
    );
  }

  AddDematAccountRequest copyWith({
    int? id,
    String? clientId,
    String? apiKey,
    String? mpin,
    String? password,
    String? totpReferenceKey,
    String? brokerType,
    bool? isAdmin,
    bool? isActive,
    List<String>? childIds,
    String? nickName,
    String? ip,
    int? pyUserId,
    String? dob,
    String? apiSecretKey,
    String? vendorInfo,
    String? mobileNumber,
  }) {
    return AddDematAccountRequest(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      apiKey: apiKey ?? this.apiKey,
      mpin: mpin ?? this.mpin,
      password: password ?? this.password,
      totpReferenceKey: totpReferenceKey ?? this.totpReferenceKey,
      brokerType: brokerType ?? this.brokerType,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      isAdmin: isAdmin ?? this.isAdmin,
      isActive: isActive ?? this.isActive,
      isOwn: isOwn?? this.isOwn,
      childIds: childIds ?? this.childIds,
      nickName: nickName ?? this.nickName,
      ip: ip ?? this.ip,
      pyUserId: pyUserId ?? this.pyUserId,
      dob: dob ?? this.dob,
      apiSecretKey: apiSecretKey ?? this.apiSecretKey,
      vendorInfo: vendorInfo ?? this.vendorInfo,
    );
  }
}