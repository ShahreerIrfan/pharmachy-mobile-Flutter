// lib/core/security/mobile_staff_offline_auth_client.dart
// Architecture Decision: ADR-0113 (P113)
// Phase 06: Milestone M03 - Offline-First Desktop POS & Owner Visibility.

enum MobileStaffOfflineUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileRiskLimits {
  final double maxOfflineDiscountPercent;
  final double maxOfflineSaleAmount;
  final bool allowCreditSales;
  final bool requireSupervisorRefund;

  const MobileRiskLimits({
    required this.maxOfflineDiscountPercent,
    required this.maxOfflineSaleAmount,
    required this.allowCreditSales,
    required this.requireSupervisorRefund,
  });

  factory MobileRiskLimits.fromJson(Map<String, dynamic> json) {
    return MobileRiskLimits(
      maxOfflineDiscountPercent: (json['max_offline_discount_percent'] as num?)?.toDouble() ?? 5.0,
      maxOfflineSaleAmount: double.tryParse(json['max_offline_sale_amount']?.toString() ?? '25000.0') ?? 25000.0,
      allowCreditSales: json['allow_credit_sales'] == true,
      requireSupervisorRefund: json['require_supervisor_refund'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'max_offline_discount_percent': maxOfflineDiscountPercent,
    'max_offline_sale_amount': maxOfflineSaleAmount.toStringAsFixed(2),
    'allow_credit_sales': allowCreditSales,
    'require_supervisor_refund': requireSupervisorRefund,
  };
}

class MobileStaffOfflineRecord {
  final String authorizationId;
  final String tenantId;
  final String? branchId;
  final String staffId;
  final String username;
  final String fullName;
  final String role;
  final String deviceId;
  final String credentialSalt;
  final String credentialHash;
  final List<String> permittedActions;
  final List<String> deniedActions;
  final MobileRiskLimits riskLimits;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String signature;
  final bool isRevoked;

  const MobileStaffOfflineRecord({
    required this.authorizationId,
    required this.tenantId,
    this.branchId,
    required this.staffId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.deviceId,
    required this.credentialSalt,
    required this.credentialHash,
    required this.permittedActions,
    required this.deniedActions,
    required this.riskLimits,
    required this.issuedAt,
    required this.expiresAt,
    required this.signature,
    required this.isRevoked,
  });

  factory MobileStaffOfflineRecord.fromJson(Map<String, dynamic> json) {
    return MobileStaffOfflineRecord(
      authorizationId: json['authorization_id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      staffId: json['staff_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'CASHIER',
      deviceId: json['device_id']?.toString() ?? '',
      credentialSalt: json['credential_salt']?.toString() ?? '',
      credentialHash: json['credential_hash']?.toString() ?? '',
      permittedActions: (json['permitted_actions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      deniedActions: (json['denied_actions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      riskLimits: MobileRiskLimits.fromJson(json['risk_limits'] is Map<String, dynamic> ? json['risk_limits'] : {}),
      issuedAt: DateTime.tryParse(json['issued_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '') ?? DateTime.now().add(const Duration(hours: 72)),
      signature: json['signature']?.toString() ?? '',
      isRevoked: json['is_revoked'] == true,
    );
  }
}

class MobileOfflineVerificationResult {
  final bool isAuthorized;
  final String? staffId;
  final String? username;
  final String? role;
  final List<String> permittedActions;
  final MobileRiskLimits? riskLimits;
  final MobileStaffOfflineUiStatus uiStatus;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileOfflineVerificationResult({
    required this.isAuthorized,
    this.staffId,
    this.username,
    this.role,
    this.permittedActions = const [],
    this.riskLimits,
    required this.uiStatus,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileOfflineVerificationResult.success(MobileStaffOfflineRecord record) {
    return MobileOfflineVerificationResult(
      isAuthorized: true,
      staffId: record.staffId,
      username: record.username,
      role: record.role,
      permittedActions: record.permittedActions,
      riskLimits: record.riskLimits,
      uiStatus: MobileStaffOfflineUiStatus.offline,
      messageEn: 'Offline staff authorization successful.',
      messageBn: 'অফলাইন স্টাফ অনুমোদন সফল হয়েছে।',
    );
  }

  factory MobileOfflineVerificationResult.error({
    required MobileStaffOfflineUiStatus status,
    required String errorCode,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileOfflineVerificationResult(
      isAuthorized: false,
      uiStatus: status,
      errorCode: errorCode,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileStaffOfflineAuthClient {
  final String localDeviceId;
  final Map<String, MobileStaffOfflineRecord> _cachedRecords = {};

  MobileStaffOfflineAuthClient({required this.localDeviceId});

  void cacheAuthorization(MobileStaffOfflineRecord record) {
    _cachedRecords[record.staffId] = record;
  }

  int get cachedCount => _cachedRecords.length;

  MobileOfflineVerificationResult verifyOffline({
    required String staffId,
    required String pin,
    DateTime? verificationTime,
  }) {
    if (staffId.trim().isEmpty || pin.trim().isEmpty) {
      return MobileOfflineVerificationResult.error(
        status: MobileStaffOfflineUiStatus.error,
        errorCode: 'ERR_INVALID_OFFLINE_AUTH_INPUT',
        msgEn: 'Missing staff ID or offline PIN.',
        msgBn: 'স্টাফ আইডি অথবা অফলাইন পিন প্রদান করা হয়নি।',
      );
    }

    final record = _cachedRecords[staffId];
    if (record == null) {
      return MobileOfflineVerificationResult.error(
        status: MobileStaffOfflineUiStatus.permissionDenied,
        errorCode: 'ERR_STAFF_NOT_FOUND_OFFLINE',
        msgEn: 'No cached offline authorization found for this staff member.',
        msgBn: 'এই স্টাফের জন্য কোনো সংরক্ষিত অফলাইন অনুমোদন পাওয়া যায়নি।',
      );
    }

    if (record.isRevoked) {
      return MobileOfflineVerificationResult.error(
        status: MobileStaffOfflineUiStatus.permissionDenied,
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        msgEn: 'This offline staff authorization has been revoked.',
        msgBn: 'এই অফলাইন স্টাফ অনুমোদনটি বাতিল করা হয়েছে।',
      );
    }

    // 1. Device check
    if (record.deviceId != localDeviceId) {
      return MobileOfflineVerificationResult.error(
        status: MobileStaffOfflineUiStatus.permissionDenied,
        errorCode: 'ERR_OFFLINE_DEVICE_MISMATCH',
        msgEn: 'Enrolled device mismatch. Offline lease is bound to device ${record.deviceId}',
        msgBn: 'ডিভাইস অমিল। এই অফলাইন অনুমোদনটি অন্য ডিভাইসের জন্য নির্ধারিত।',
      );
    }

    // 2. Expiry check
    final now = verificationTime ?? DateTime.now();
    if (now.isAfter(record.expiresAt)) {
      return MobileOfflineVerificationResult.error(
        status: MobileStaffOfflineUiStatus.permissionDenied,
        errorCode: 'ERR_OFFLINE_AUTH_EXPIRED',
        msgEn: 'Offline authorization expired at ${record.expiresAt.toIso8601String()}',
        msgBn: 'অফলাইন অনুমোদনের মেয়াদ উত্তীর্ণ হয়েছে।',
      );
    }

    return MobileOfflineVerificationResult.success(record);
  }

  bool canPerformAction(String staffId, String action) {
    final record = _cachedRecords[staffId];
    if (record == null || record.isRevoked) return false;
    if (record.permittedActions.contains('*')) return true;
    if (record.deniedActions.contains(action)) return false;
    return record.permittedActions.contains(action);
  }

  bool isDiscountPermitted(String staffId, double discountPercent) {
    final record = _cachedRecords[staffId];
    if (record == null) return false;
    return discountPercent <= record.riskLimits.maxOfflineDiscountPercent;
  }

  bool isSaleAmountPermitted(String staffId, double amount) {
    final record = _cachedRecords[staffId];
    if (record == null) return false;
    return amount <= record.riskLimits.maxOfflineSaleAmount;
  }
}

