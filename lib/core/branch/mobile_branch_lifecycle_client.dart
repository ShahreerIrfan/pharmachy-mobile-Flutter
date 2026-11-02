// lib/core/branch/mobile_branch_lifecycle_client.dart
// Architecture Decision: ADR-0107
// Phase 06: Milestone M03 - Branch Lifecycle Management (P107)

enum MobileBranchLifecycleUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileBranchLifecycleRecord {
  final String branchId;
  final String tenantId;
  final String name;
  final String branchCode;
  final String licenseNumber;
  final String address;
  final String phoneNumber;
  final String? email;
  final String managerName;
  final bool isMainBranch;
  final String status;
  final bool isActive;
  final bool isOverQuotaLocked;
  final int activeStaffCount;
  final int activeDevicesCount;
  final int historicalInvoicesCount;
  final int historicalStockBatchesCount;
  final String createdAt;
  final String? closedAt;
  final String? closureReason;

  const MobileBranchLifecycleRecord({
    required this.branchId,
    required this.tenantId,
    required this.name,
    required this.branchCode,
    required this.licenseNumber,
    required this.address,
    required this.phoneNumber,
    this.email,
    required this.managerName,
    required this.isMainBranch,
    required this.status,
    required this.isActive,
    required this.isOverQuotaLocked,
    required this.activeStaffCount,
    required this.activeDevicesCount,
    required this.historicalInvoicesCount,
    required this.historicalStockBatchesCount,
    required this.createdAt,
    this.closedAt,
    this.closureReason,
  });

  factory MobileBranchLifecycleRecord.fromJson(Map<String, dynamic> json) {
    return MobileBranchLifecycleRecord(
      branchId: json['branch_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      branchCode: json['branch_code'] as String? ?? '',
      licenseNumber: json['license_number'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      email: json['email'] as String?,
      managerName: json['manager_name'] as String? ?? '',
      isMainBranch: json['is_main_branch'] as bool? ?? false,
      status: (json['status'] as String? ?? 'ACTIVE').toUpperCase(),
      isActive: json['is_active'] as bool? ?? true,
      isOverQuotaLocked: json['is_over_quota_locked'] as bool? ?? false,
      activeStaffCount: json['active_staff_count'] as int? ?? 0,
      activeDevicesCount: json['active_devices_count'] as int? ?? 0,
      historicalInvoicesCount: json['historical_invoices_count'] as int? ?? 0,
      historicalStockBatchesCount: json['historical_stock_batches_count'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      closedAt: json['closed_at'] as String?,
      closureReason: json['closure_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branch_id': branchId,
      'tenant_id': tenantId,
      'name': name,
      'branch_code': branchCode,
      'license_number': licenseNumber,
      'address': address,
      'phone_number': phoneNumber,
      'email': email,
      'manager_name': managerName,
      'is_main_branch': isMainBranch,
      'status': status,
      'is_active': isActive,
      'is_over_quota_locked': isOverQuotaLocked,
      'active_staff_count': activeStaffCount,
      'active_devices_count': activeDevicesCount,
      'historical_invoices_count': historicalInvoicesCount,
      'historical_stock_batches_count': historicalStockBatchesCount,
      'created_at': createdAt,
      'closed_at': closedAt,
      'closure_reason': closureReason,
    };
  }
}

class MobileBranchLifecycleEvent {
  final String eventId;
  final String eventType;
  final String performedBy;
  final String reason;
  final String createdAt;

  const MobileBranchLifecycleEvent({
    required this.eventId,
    required this.eventType,
    required this.performedBy,
    required this.reason,
    required this.createdAt,
  });

  factory MobileBranchLifecycleEvent.fromJson(Map<String, dynamic> json) {
    return MobileBranchLifecycleEvent(
      eventId: json['event_id'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      performedBy: json['performed_by'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class MobileBranchLifecycleValidationResult {
  final bool isValid;
  final String errorCode;
  final String messageEn;
  final String messageBn;

  const MobileBranchLifecycleValidationResult({
    required this.isValid,
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileBranchLifecycleValidationResult.ok() =>
      const MobileBranchLifecycleValidationResult(
        isValid: true,
        errorCode: '',
        messageEn: '',
        messageBn: '',
      );

  factory MobileBranchLifecycleValidationResult.fail(
          String code, String en, String bn) =>
      MobileBranchLifecycleValidationResult(
        isValid: false,
        errorCode: code,
        messageEn: en,
        messageBn: bn,
      );
}

class MobileBranchLifecycleViewState {
  final MobileBranchLifecycleUiStatus status;
  final MobileBranchLifecycleRecord? record;
  final List<MobileBranchLifecycleEvent> events;
  final String errorMessageEn;
  final String errorMessageBn;
  final bool isOffline;

  const MobileBranchLifecycleViewState({
    required this.status,
    this.record,
    this.events = const [],
    this.errorMessageEn = '',
    this.errorMessageBn = '',
    this.isOffline = false,
  });
}

class MobileBranchLifecycleClient {
  final Map<String, MobileBranchLifecycleRecord> _cache = {};
  final Map<String, List<MobileBranchLifecycleEvent>> _eventCache = {};

  bool _isSuperUserOrOwner(String role) {
    final clean = role.toUpperCase();
    return clean == 'SUPERADMIN' ||
        clean == 'SUPER_ADMIN' ||
        clean == 'PLATFORM_OPERATOR' ||
        clean == 'PLATFORM_SUPER_ADMIN' ||
        clean == 'PHARMACY_OWNER' ||
        clean == 'TENANT_OWNER';
  }

  MobileBranchLifecycleValidationResult validateBranchCreation({
    required String tenantId,
    required String name,
    required String licenseNumber,
    required String actorRole,
  }) {
    if (!_isSuperUserOrOwner(actorRole)) {
      return MobileBranchLifecycleValidationResult.fail(
        'ERR_PERMISSION_DENIED',
        'Only pharmacy owners or administrators can create branch stores.',
        'শুধুমাত্র ফার্মেসি মালিক বা অ্যাডমিন নতুন ব্রাঞ্চ তৈরি করতে পারেন।',
      );
    }
    if (tenantId.trim().isEmpty) {
      return MobileBranchLifecycleValidationResult.fail(
        'ERR_INVALID_TENANT',
        'Tenant ID is required.',
        'টেন্যান্ট আইডি আবশ্যক।',
      );
    }
    if (name.trim().length < 2) {
      return MobileBranchLifecycleValidationResult.fail(
        'ERR_INVALID_BRANCH_NAME',
        'Branch name must be at least 2 characters.',
        'ব্রাঞ্চের নাম কমপক্ষে ২ অক্ষরের হতে হবে।',
      );
    }
    if (licenseNumber.trim().length < 3) {
      return MobileBranchLifecycleValidationResult.fail(
        'ERR_INVALID_LICENSE',
        'DGDA drug license number must be at least 3 characters.',
        'ডিজিডিএ ড্রাগ লাইসেন্স নম্বর আবশ্যক।',
      );
    }
    return MobileBranchLifecycleValidationResult.ok();
  }

  MobileBranchLifecycleValidationResult validateBranchClosure({
    required String branchId,
    required String reason,
    required String actorRole,
  }) {
    if (!_isSuperUserOrOwner(actorRole)) {
      return MobileBranchLifecycleValidationResult.fail(
        'ERR_PERMISSION_DENIED',
        'Only pharmacy owners or administrators can close branch stores.',
        'শুধুমাত্র ফার্মেসি মালিক বা অ্যাডমিন ব্রাঞ্চ বন্ধ করতে পারেন।',
      );
    }
    if (reason.trim().length < 4) {
      return MobileBranchLifecycleValidationResult.fail(
        'ERR_CLOSURE_REASON_REQUIRED',
        'A detailed closure reason (minimum 4 characters) is mandatory.',
        'ব্রাঞ্চ বন্ধের বিস্তারিত কারণ (কমপক্ষে ৪ অক্ষর) আবশ্যক।',
      );
    }
    return MobileBranchLifecycleValidationResult.ok();
  }

  void cacheRecord(MobileBranchLifecycleRecord record) {
    _cache[record.branchId] = record;
  }

  MobileBranchLifecycleRecord? getCachedRecord(String branchId) => _cache[branchId];

  void recordEvent(String branchId, String eventType, String actor, String reason) {
    final event = MobileBranchLifecycleEvent(
      eventId: 'evt-br-${DateTime.now().millisecondsSinceEpoch}',
      eventType: eventType,
      performedBy: actor,
      reason: reason,
      createdAt: DateTime.now().toIso8601String(),
    );
    _eventCache.putIfAbsent(branchId, () => []).insert(0, event);
  }

  List<MobileBranchLifecycleEvent> getEvents(String branchId) =>
      _eventCache[branchId] ?? const [];

  MobileBranchLifecycleViewState applySuspension(
    MobileBranchLifecycleRecord current,
    String reason,
    String actor,
  ) {
    final updated = MobileBranchLifecycleRecord(
      branchId: current.branchId,
      tenantId: current.tenantId,
      name: current.name,
      branchCode: current.branchCode,
      licenseNumber: current.licenseNumber,
      address: current.address,
      phoneNumber: current.phoneNumber,
      email: current.email,
      managerName: current.managerName,
      isMainBranch: current.isMainBranch,
      status: 'SUSPENDED',
      isActive: false,
      isOverQuotaLocked: current.isOverQuotaLocked,
      activeStaffCount: current.activeStaffCount,
      activeDevicesCount: 0,
      historicalInvoicesCount: current.historicalInvoicesCount,
      historicalStockBatchesCount: current.historicalStockBatchesCount,
      createdAt: current.createdAt,
      closedAt: current.closedAt,
      closureReason: current.closureReason,
    );
    cacheRecord(updated);
    recordEvent(current.branchId, 'SUSPENDED', actor, reason);
    return MobileBranchLifecycleViewState(
      status: MobileBranchLifecycleUiStatus.success,
      record: updated,
      events: getEvents(current.branchId),
    );
  }

  MobileBranchLifecycleViewState applyClosure(
    MobileBranchLifecycleRecord current,
    String reason,
    String actor,
  ) {
    final updated = MobileBranchLifecycleRecord(
      branchId: current.branchId,
      tenantId: current.tenantId,
      name: current.name,
      branchCode: current.branchCode,
      licenseNumber: current.licenseNumber,
      address: current.address,
      phoneNumber: current.phoneNumber,
      email: current.email,
      managerName: current.managerName,
      isMainBranch: false,
      status: 'CLOSED',
      isActive: false,
      isOverQuotaLocked: false,
      activeStaffCount: 0,
      activeDevicesCount: 0,
      historicalInvoicesCount: current.historicalInvoicesCount, // Preserved!
      historicalStockBatchesCount: current.historicalStockBatchesCount, // Preserved!
      createdAt: current.createdAt,
      closedAt: DateTime.now().toIso8601String(),
      closureReason: reason,
    );
    cacheRecord(updated);
    recordEvent(current.branchId, 'CLOSED', actor, reason);
    return MobileBranchLifecycleViewState(
      status: MobileBranchLifecycleUiStatus.success,
      record: updated,
      events: getEvents(current.branchId),
    );
  }

  MobileBranchLifecycleViewState toOfflineState(String branchId) {
    final cached = getCachedRecord(branchId);
    if (cached != null) {
      return MobileBranchLifecycleViewState(
        status: MobileBranchLifecycleUiStatus.offline,
        record: cached,
        events: getEvents(branchId),
        errorMessageEn: 'Offline mode: viewing locally cached branch profile.',
        errorMessageBn: 'অফলাইন মোড: ক্যাশ করা ব্রাঞ্চ প্রোফাইল প্রদর্শিত হচ্ছে।',
        isOffline: true,
      );
    }
    return const MobileBranchLifecycleViewState(
      status: MobileBranchLifecycleUiStatus.empty,
      errorMessageEn: 'No cached branch profile available offline.',
      errorMessageBn: 'অফলাইনে প্রদর্শনের জন্য কোনো ক্যাশ করা ব্রাঞ্চ তথ্য নেই।',
      isOffline: true,
    );
  }
}
