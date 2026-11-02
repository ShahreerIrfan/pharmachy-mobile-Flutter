// lib/core/audit/mobile_staff_audit_timeline_client.dart
// Architecture Decision: ADR-0118
// Phase 06: Milestone M03 - Staff Audit Timeline & Attribution (P118)

enum MobileTimelineUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileTimelineItem {
  final String timelineId;
  final String timestamp;
  final String tenantId;
  final String? branchId;
  final String eventCategory;
  final String action;
  final String status;
  final String actorId;
  final String actorEmail;
  final String actorRole;
  final String? deviceId;
  final String? ipAddress;
  final String? targetStaffId;
  final String? targetStaffName;
  final String summaryEn;
  final String summaryBn;
  final Map<String, dynamic> metadata;

  const MobileTimelineItem({
    required this.timelineId,
    required this.timestamp,
    required this.tenantId,
    this.branchId,
    required this.eventCategory,
    required this.action,
    required this.status,
    required this.actorId,
    required this.actorEmail,
    required this.actorRole,
    this.deviceId,
    this.ipAddress,
    this.targetStaffId,
    this.targetStaffName,
    required this.summaryEn,
    required this.summaryBn,
    this.metadata = const {},
  });

  factory MobileTimelineItem.fromJson(Map<String, dynamic> json) {
    return MobileTimelineItem(
      timelineId: json['timeline_id'] ?? json['id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'],
      eventCategory: json['event_category'] ?? 'SYSTEM_AUDIT',
      action: json['action'] ?? '',
      status: json['status'] ?? 'SUCCESS',
      actorId: json['actor_id'] ?? '',
      actorEmail: json['actor_email'] ?? '',
      actorRole: json['actor_role'] ?? 'STAFF',
      deviceId: json['device_id'],
      ipAddress: json['ip_address'],
      targetStaffId: json['target_staff_id'],
      targetStaffName: json['target_staff_name'],
      summaryEn: json['summary_en'] ?? '',
      summaryBn: json['summary_bn'] ?? '',
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] : {},
    );
  }
}

class MobileTimelineResult {
  final MobileTimelineUiStatus uiStatus;
  final List<MobileTimelineItem> items;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileTimelineResult({
    required this.uiStatus,
    this.items = const [],
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileTimelineResult.success(List<MobileTimelineItem> items) {
    if (items.isEmpty) {
      return const MobileTimelineResult(
        uiStatus: MobileTimelineUiStatus.empty,
        items: [],
        messageEn: 'No audit events found.',
        messageBn: 'কোনো অডিট ইভেন্ট পাওয়া যায়নি।',
      );
    }
    return MobileTimelineResult(
      uiStatus: MobileTimelineUiStatus.success,
      items: items,
      messageEn: 'Loaded ${items.length} event(s).',
      messageBn: '${items.length} টি অডিট ইভেন্ট লোড হয়েছে।',
    );
  }

  factory MobileTimelineResult.error({
    required MobileTimelineUiStatus status,
    required String code,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileTimelineResult(
      uiStatus: status,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileStaffAuditTimelineClient {
  static const Set<String> authorizedRoles = {
    'PHARMACY_OWNER',
    'OWNER',
    'TENANT_OWNER',
    'BRANCH_MANAGER',
    'MANAGER',
    'AUDITOR',
    'SUPERADMIN',
  };

  MobileTimelineResult filterTimeline({
    required List<MobileTimelineItem> items,
    required String callerRole,
    required String callerTenantId,
    required String callerBranchId,
    required String targetTenantId,
    String? targetBranchId,
    String? filterStaffId,
    String? filterCategory,
    String? filterDeviceId,
  }) {
    // 1. Role Authorization
    if (!authorizedRoles.contains(callerRole.toUpperCase())) {
      return MobileTimelineResult.error(
        status: MobileTimelineUiStatus.permissionDenied,
        code: 'ERR_STAFF_ROLE_DENIED',
        msgEn: 'Only Owners, Managers, and Auditors may access the staff audit timeline.',
        msgBn: 'শুধুমাত্র মালিক, শাখা ব্যবস্থাপক এবং অডিটরগণ স্টাফ অডিট টাইমলাইন দেখতে পারেন।',
      );
    }

    // 2. Cross-Tenant Check
    if (callerTenantId != targetTenantId && callerRole.toUpperCase() != 'SUPERADMIN') {
      return MobileTimelineResult.error(
        status: MobileTimelineUiStatus.permissionDenied,
        code: 'ERR_CROSS_TENANT_VIOLATION',
        msgEn: 'Cross-tenant timeline inspection is strictly forbidden.',
        msgBn: 'অন্য টেন্যান্টের অডিট টাইমলাইন দেখতে পারবেন না।',
      );
    }

    // 3. Branch Manager Scoping
    final isManager = callerRole.toUpperCase() == 'BRANCH_MANAGER' || callerRole.toUpperCase() == 'MANAGER';
    final isOwner = callerRole.toUpperCase() == 'PHARMACY_OWNER' || callerRole.toUpperCase() == 'SUPERADMIN';

    if (isManager && !isOwner) {
      if (targetBranchId != null && callerBranchId != targetBranchId) {
        return MobileTimelineResult.error(
          status: MobileTimelineUiStatus.permissionDenied,
          code: 'ERR_CROSS_BRANCH_VIOLATION',
          msgEn: 'Branch managers cannot inspect audit logs outside their assigned branch.',
          msgBn: 'শাখা ব্যবস্থাপক অন্য শাখার অডিট রেকর্ড দেখতে পারেন না।',
        );
      }
    }

    final effectiveBranch = isManager ? callerBranchId : targetBranchId;

    final filtered = items.where((item) {
      if (item.tenantId != targetTenantId) return false;
      if (effectiveBranch != null && item.branchId != effectiveBranch) return false;
      if (filterStaffId != null && item.actorId != filterStaffId && item.targetStaffId != filterStaffId) {
        return false;
      }
      if (filterCategory != null && item.eventCategory != filterCategory) return false;
      if (filterDeviceId != null && item.deviceId != filterDeviceId) return false;
      return true;
    }).toList();

    return MobileTimelineResult.success(filtered);
  }
}
