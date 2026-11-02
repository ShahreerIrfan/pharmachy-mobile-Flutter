// lib/core/staff/mobile_staff_lifecycle_client.dart
// Architecture Decision: ADR-0106
// Phase 06: Milestone M03 - Staff Lifecycle Management (P106)

enum MobileStaffLifecycleUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileStaffLifecycleRecord {
  final String staffId;
  final String tenantId;
  final String? branchId;
  final String? branchName;
  final String username;
  final String? email;
  final String fullName;
  final String role;
  final String mobileNumber;
  final String pcbRegistrationNo;
  final String lifecycleStatus;
  final bool isActive;
  final bool mfaEnabled;
  final int activeSessionsCount;
  final int activeLeasesCount;
  final String createdAt;
  final String? deactivatedAt;
  final String? terminatedAt;
  final String? lastCredentialResetAt;
  final String? lastMfaResetAt;

  const MobileStaffLifecycleRecord({
    required this.staffId,
    required this.tenantId,
    this.branchId,
    this.branchName,
    required this.username,
    this.email,
    required this.fullName,
    required this.role,
    required this.mobileNumber,
    required this.pcbRegistrationNo,
    required this.lifecycleStatus,
    required this.isActive,
    required this.mfaEnabled,
    required this.activeSessionsCount,
    required this.activeLeasesCount,
    required this.createdAt,
    this.deactivatedAt,
    this.terminatedAt,
    this.lastCredentialResetAt,
    this.lastMfaResetAt,
  });

  factory MobileStaffLifecycleRecord.fromJson(Map<String, dynamic> json) {
    return MobileStaffLifecycleRecord(
      staffId: json['staff_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String?,
      branchName: json['branch_name'] as String?,
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      fullName: json['full_name'] as String? ?? '',
      role: (json['role'] as String? ?? 'CASHIER').toUpperCase(),
      mobileNumber: json['mobile_number'] as String? ?? '',
      pcbRegistrationNo: json['pcb_registration_no'] as String? ?? '',
      lifecycleStatus: (json['lifecycle_status'] as String? ?? 'ACTIVE').toUpperCase(),
      isActive: json['is_active'] as bool? ?? true,
      mfaEnabled: json['mfa_enabled'] as bool? ?? false,
      activeSessionsCount: json['active_sessions_count'] as int? ?? 0,
      activeLeasesCount: json['active_leases_count'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      deactivatedAt: json['deactivated_at'] as String?,
      terminatedAt: json['terminated_at'] as String?,
      lastCredentialResetAt: json['last_credential_reset_at'] as String?,
      lastMfaResetAt: json['last_mfa_reset_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staff_id': staffId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'branch_name': branchName,
      'username': username,
      'email': email,
      'full_name': fullName,
      'role': role,
      'mobile_number': mobileNumber,
      'pcb_registration_no': pcbRegistrationNo,
      'lifecycle_status': lifecycleStatus,
      'is_active': isActive,
      'mfa_enabled': mfaEnabled,
      'active_sessions_count': activeSessionsCount,
      'active_leases_count': activeLeasesCount,
      'created_at': createdAt,
      'deactivated_at': deactivatedAt,
      'terminated_at': terminatedAt,
      'last_credential_reset_at': lastCredentialResetAt,
      'last_mfa_reset_at': lastMfaResetAt,
    };
  }
}

class MobileStaffLifecycleEvent {
  final String eventId;
  final String eventType;
  final String performedBy;
  final String reason;
  final String createdAt;

  const MobileStaffLifecycleEvent({
    required this.eventId,
    required this.eventType,
    required this.performedBy,
    required this.reason,
    required this.createdAt,
  });

  factory MobileStaffLifecycleEvent.fromJson(Map<String, dynamic> json) {
    return MobileStaffLifecycleEvent(
      eventId: json['event_id'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      performedBy: json['performed_by'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class MobileStaffLifecycleValidationResult {
  final bool isValid;
  final String errorCode;
  final String messageEn;
  final String messageBn;

  const MobileStaffLifecycleValidationResult({
    required this.isValid,
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileStaffLifecycleValidationResult.ok() =>
      const MobileStaffLifecycleValidationResult(
        isValid: true,
        errorCode: '',
        messageEn: '',
        messageBn: '',
      );

  factory MobileStaffLifecycleValidationResult.fail(
          String code, String en, String bn) =>
      MobileStaffLifecycleValidationResult(
        isValid: false,
        errorCode: code,
        messageEn: en,
        messageBn: bn,
      );
}

class MobileStaffLifecycleViewState {
  final MobileStaffLifecycleUiStatus status;
  final MobileStaffLifecycleRecord? record;
  final List<MobileStaffLifecycleEvent> events;
  final String errorMessageEn;
  final String errorMessageBn;
  final bool isOffline;

  const MobileStaffLifecycleViewState({
    required this.status,
    this.record,
    this.events = const [],
    this.errorMessageEn = '',
    this.errorMessageBn = '',
    this.isOffline = false,
  });
}

class MobileStaffLifecycleClient {
  final Map<String, MobileStaffLifecycleRecord> _cache = {};
  final Map<String, List<MobileStaffLifecycleEvent>> _eventCache = {};

  bool _isSuperUserOrOwner(String role) {
    final clean = role.toUpperCase();
    return clean == 'SUPERADMIN' ||
        clean == 'SUPER_ADMIN' ||
        clean == 'PLATFORM_OPERATOR' ||
        clean == 'PLATFORM_SUPER_ADMIN' ||
        clean == 'PHARMACY_OWNER' ||
        clean == 'TENANT_OWNER';
  }

  MobileStaffLifecycleValidationResult validateDirectCreation({
    required String tenantId,
    required String username,
    required String email,
    required String fullName,
    required String role,
    required String actorRole,
  }) {
    if (!_isSuperUserOrOwner(actorRole)) {
      return MobileStaffLifecycleValidationResult.fail(
        'ERR_PERMISSION_DENIED',
        'Only pharmacy owners or administrators can create staff accounts.',
        'শুধুমাত্র ফার্মেসি মালিক বা অ্যাডমিন নতুন স্টাফ অ্যাকাউন্ট তৈরি করতে পারেন।',
      );
    }
    if (tenantId.trim().isEmpty) {
      return MobileStaffLifecycleValidationResult.fail(
        'ERR_INVALID_TENANT',
        'Tenant ID is required.',
        'টেন্যান্ট আইডি আবশ্যক।',
      );
    }
    if (username.trim().length < 3) {
      return MobileStaffLifecycleValidationResult.fail(
        'ERR_INVALID_USERNAME',
        'Username must be at least 3 characters.',
        'ইউজারনেম কমপক্ষে ৩ অক্ষরের হতে হবে।',
      );
    }
    if (!email.contains('@') || !email.contains('.')) {
      return MobileStaffLifecycleValidationResult.fail(
        'ERR_INVALID_EMAIL',
        'Valid email address is required.',
        'সঠিক ইমেইল ঠিকানা প্রদান করুন।',
      );
    }
    if (fullName.trim().length < 2) {
      return MobileStaffLifecycleValidationResult.fail(
        'ERR_INVALID_FULL_NAME',
        'Full name must be at least 2 characters.',
        'সম্পূর্ণ নাম কমপক্ষে ২ অক্ষরের হতে হবে।',
      );
    }
    if (role.trim().isEmpty) {
      return MobileStaffLifecycleValidationResult.fail(
        'ERR_INVALID_ROLE',
        'Staff role is required.',
        'স্টাফের ভূমিকা আবশ্যক।',
      );
    }
    return MobileStaffLifecycleValidationResult.ok();
  }

  MobileStaffLifecycleValidationResult validateTermination({
    required String staffId,
    required String reason,
    required String actorRole,
  }) {
    if (!_isSuperUserOrOwner(actorRole)) {
      return MobileStaffLifecycleValidationResult.fail(
        'ERR_PERMISSION_DENIED',
        'Only pharmacy owners or administrators can terminate staff accounts.',
        'শুধুমাত্র ফার্মেসি মালিক বা অ্যাডমিন কোনো স্টাফের চাকরি সমাপ্ত করতে পারেন।',
      );
    }
    if (reason.trim().length < 4) {
      return MobileStaffLifecycleValidationResult.fail(
        'ERR_TERMINATION_REASON_REQUIRED',
        'A detailed termination reason (minimum 4 characters) is mandatory.',
        'চাকরি সমাপ্তির বিস্তারিত কারণ (কমপক্ষে ৪ অক্ষর) আবশ্যক।',
      );
    }
    return MobileStaffLifecycleValidationResult.ok();
  }

  MobileStaffLifecycleValidationResult validateMfaRecovery({
    required String actorRole,
  }) {
    if (!_isSuperUserOrOwner(actorRole)) {
      return MobileStaffLifecycleValidationResult.fail(
        'ERR_PERMISSION_DENIED',
        'Only pharmacy owners or administrators can perform MFA recovery.',
        'শুধুমাত্র ফার্মেসি মালিক বা অ্যাডমিন এমএফএ রিকভারি করতে পারেন।',
      );
    }
    return MobileStaffLifecycleValidationResult.ok();
  }

  void cacheRecord(MobileStaffLifecycleRecord record) {
    _cache[record.staffId] = record;
  }

  MobileStaffLifecycleRecord? getCachedRecord(String staffId) => _cache[staffId];

  void recordEvent(String staffId, String eventType, String actor, String reason) {
    final event = MobileStaffLifecycleEvent(
      eventId: 'evt-${DateTime.now().millisecondsSinceEpoch}',
      eventType: eventType,
      performedBy: actor,
      reason: reason,
      createdAt: DateTime.now().toIso8601String(),
    );
    _eventCache.putIfAbsent(staffId, () => []).insert(0, event);
  }

  List<MobileStaffLifecycleEvent> getEvents(String staffId) =>
      _eventCache[staffId] ?? const [];

  MobileStaffLifecycleViewState applyDeactivation(
    MobileStaffLifecycleRecord current,
    String reason,
    String actor,
  ) {
    final updated = MobileStaffLifecycleRecord(
      staffId: current.staffId,
      tenantId: current.tenantId,
      branchId: current.branchId,
      branchName: current.branchName,
      username: current.username,
      email: current.email,
      fullName: current.fullName,
      role: current.role,
      mobileNumber: current.mobileNumber,
      pcbRegistrationNo: current.pcbRegistrationNo,
      lifecycleStatus: 'DEACTIVATED',
      isActive: false,
      mfaEnabled: current.mfaEnabled,
      activeSessionsCount: 0,
      activeLeasesCount: current.activeLeasesCount,
      createdAt: current.createdAt,
      deactivatedAt: DateTime.now().toIso8601String(),
      terminatedAt: current.terminatedAt,
      lastCredentialResetAt: current.lastCredentialResetAt,
      lastMfaResetAt: current.lastMfaResetAt,
    );
    cacheRecord(updated);
    recordEvent(current.staffId, 'DEACTIVATED', actor, reason);
    return MobileStaffLifecycleViewState(
      status: MobileStaffLifecycleUiStatus.success,
      record: updated,
      events: getEvents(current.staffId),
    );
  }

  MobileStaffLifecycleViewState applyTermination(
    MobileStaffLifecycleRecord current,
    String reason,
    String actor,
  ) {
    final updated = MobileStaffLifecycleRecord(
      staffId: current.staffId,
      tenantId: current.tenantId,
      branchId: current.branchId,
      branchName: current.branchName,
      username: current.username,
      email: current.email,
      fullName: current.fullName,
      role: current.role,
      mobileNumber: current.mobileNumber,
      pcbRegistrationNo: current.pcbRegistrationNo,
      lifecycleStatus: 'TERMINATED',
      isActive: false,
      mfaEnabled: false,
      activeSessionsCount: 0,
      activeLeasesCount: 0,
      createdAt: current.createdAt,
      deactivatedAt: current.deactivatedAt,
      terminatedAt: DateTime.now().toIso8601String(),
      lastCredentialResetAt: current.lastCredentialResetAt,
      lastMfaResetAt: current.lastMfaResetAt,
    );
    cacheRecord(updated);
    recordEvent(current.staffId, 'TERMINATED', actor, reason);
    return MobileStaffLifecycleViewState(
      status: MobileStaffLifecycleUiStatus.success,
      record: updated,
      events: getEvents(current.staffId),
    );
  }

  MobileStaffLifecycleViewState toOfflineState(String staffId) {
    final cached = getCachedRecord(staffId);
    if (cached != null) {
      return MobileStaffLifecycleViewState(
        status: MobileStaffLifecycleUiStatus.offline,
        record: cached,
        events: getEvents(staffId),
        errorMessageEn: 'Offline mode: viewing locally cached staff profile.',
        errorMessageBn: 'অফলাইন মোড: ক্যাশ করা স্টাফ প্রোফাইল প্রদর্শিত হচ্ছে।',
        isOffline: true,
      );
    }
    return const MobileStaffLifecycleViewState(
      status: MobileStaffLifecycleUiStatus.empty,
      errorMessageEn: 'No cached staff profile available offline.',
      errorMessageBn: 'অফলাইনে প্রদর্শনের জন্য কোনো ক্যাশ করা স্টাফ তথ্য নেই।',
      isOffline: true,
    );
  }
}

