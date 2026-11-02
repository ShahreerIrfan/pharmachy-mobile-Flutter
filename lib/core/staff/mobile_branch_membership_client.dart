// lib/core/staff/mobile_branch_membership_client.dart
// Architecture Decision: ADR-0105
// Phase 06: Milestone M03 - Branch-Specific Membership (P105)

enum MobileBranchMembershipUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileBranchMembershipRecord {
  final String membershipId;
  final String tenantId;
  final String staffMemberId;
  final String staffName;
  final String staffUsername;
  final String branchId;
  final String branchName;
  final String role;
  final String customRoleCode;
  final String customRoleTitle;
  final bool isPrimary;
  final bool isActive;
  final String? assignedAt;
  final String assignedByUsername;
  final String? revokedAt;
  final String revocationReason;

  const MobileBranchMembershipRecord({
    required this.membershipId,
    required this.tenantId,
    required this.staffMemberId,
    required this.staffName,
    required this.staffUsername,
    required this.branchId,
    required this.branchName,
    required this.role,
    required this.customRoleCode,
    required this.customRoleTitle,
    required this.isPrimary,
    required this.isActive,
    this.assignedAt,
    required this.assignedByUsername,
    this.revokedAt,
    required this.revocationReason,
  });

  factory MobileBranchMembershipRecord.fromJson(Map<String, dynamic> json) {
    return MobileBranchMembershipRecord(
      membershipId: json['membership_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      staffMemberId: json['staff_member_id'] as String? ?? '',
      staffName: json['staff_name'] as String? ?? '',
      staffUsername: json['staff_username'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      role: (json['role'] as String? ?? 'CASHIER').toUpperCase(),
      customRoleCode: json['custom_role_code'] as String? ?? '',
      customRoleTitle: json['custom_role_title'] as String? ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      assignedAt: json['assigned_at'] as String?,
      assignedByUsername: json['assigned_by_username'] as String? ?? '',
      revokedAt: json['revoked_at'] as String?,
      revocationReason: json['revocation_reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'membership_id': membershipId,
      'tenant_id': tenantId,
      'staff_member_id': staffMemberId,
      'staff_name': staffName,
      'staff_username': staffUsername,
      'branch_id': branchId,
      'branch_name': branchName,
      'role': role,
      'custom_role_code': customRoleCode,
      'custom_role_title': customRoleTitle,
      'is_primary': isPrimary,
      'is_active': isActive,
      'assigned_at': assignedAt,
      'assigned_by_username': assignedByUsername,
      'revoked_at': revokedAt,
      'revocation_reason': revocationReason,
    };
  }
}

class MobileBranchMembershipViewState {
  final MobileBranchMembershipUiStatus status;
  final List<MobileBranchMembershipRecord> memberships;
  final String messageEn;
  final String messageBn;

  const MobileBranchMembershipViewState({
    required this.status,
    required this.memberships,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileBranchMembershipViewState.loading() =>
      const MobileBranchMembershipViewState(
        status: MobileBranchMembershipUiStatus.loading,
        memberships: [],
        messageEn: 'Loading branch memberships...',
        messageBn: 'ব্রাঞ্চ মেম্বারশিপ লোড হচ্ছে...',
      );

  factory MobileBranchMembershipViewState.success(
    List<MobileBranchMembershipRecord> list,
  ) {
    if (list.isEmpty) {
      return const MobileBranchMembershipViewState(
        status: MobileBranchMembershipUiStatus.empty,
        memberships: [],
        messageEn: 'No branch assignments found.',
        messageBn: 'কোনো ব্রাঞ্চ মেম্বারশিপ পাওয়া যায়নি।',
      );
    }
    return MobileBranchMembershipViewState(
      status: MobileBranchMembershipUiStatus.success,
      memberships: list,
      messageEn: 'Branch assignments synchronized.',
      messageBn: 'ব্রাঞ্চ মেম্বারশিপ সিঙ্ক হয়েছে।',
    );
  }

  factory MobileBranchMembershipViewState.offline(
    List<MobileBranchMembershipRecord> cached,
  ) =>
      MobileBranchMembershipViewState(
        status: MobileBranchMembershipUiStatus.offline,
        memberships: cached,
        messageEn: 'Operating offline with cached assignments.',
        messageBn: 'অফলাইনে ক্যাশ করা ব্রাঞ্চ ডেটা নিয়ে চলছে।',
      );

  factory MobileBranchMembershipViewState.denied(String en, String bn) =>
      MobileBranchMembershipViewState(
        status: MobileBranchMembershipUiStatus.permissionDenied,
        memberships: [],
        messageEn: en,
        messageBn: bn,
      );

  factory MobileBranchMembershipViewState.error(String en, String bn) =>
      MobileBranchMembershipViewState(
        status: MobileBranchMembershipUiStatus.error,
        memberships: [],
        messageEn: en,
        messageBn: bn,
      );
}

class MobileBranchMembershipClient {
  static MobileBranchMembershipRecord? resolveEffectiveRole(
    List<MobileBranchMembershipRecord> assignments,
    String branchId,
  ) {
    for (final rec in assignments) {
      if (rec.isActive && rec.branchId == branchId) {
        return rec;
      }
    }
    return null;
  }

  static Map<String, dynamic> validateAssignment({
    required String callerRole,
    String? callerBranchId,
    required String targetBranchId,
    required String targetRole,
  }) {
    final cr = callerRole.toUpperCase();
    final tr = targetRole.toUpperCase();

    if (['PHARMACY_OWNER', 'SUPERADMIN'].contains(cr)) {
      return {'isValid': true, 'errorCode': null};
    }

    if (cr == 'BRANCH_MANAGER') {
      if (callerBranchId != null && callerBranchId != targetBranchId) {
        return {
          'isValid': false,
          'errorCode': 'ERR_BRANCH_ACCESS_DENIED',
          'messageEn': 'Branch Manager cannot assign staff to other branches.',
          'messageBn': 'ব্রাঞ্চ ম্যানেজার অন্য ব্রাঞ্চে কর্মী নিয়োগ করতে পারেন না.',
        };
      }
      if (['PHARMACY_OWNER', 'BRANCH_MANAGER', 'SUPERADMIN'].contains(tr)) {
        return {
          'isValid': false,
          'errorCode': 'ERR_PERMISSION_DENIED',
          'messageEn': 'Branch Manager cannot assign managerial or owner roles.',
          'messageBn': 'ব্রাঞ্চ ম্যানেজার ওনার বা ম্যানেজার রোল প্রদান করতে পারেন না.',
        };
      }
      return {'isValid': true, 'errorCode': null};
    }

    return {
      'isValid': false,
      'errorCode': 'ERR_PERMISSION_DENIED',
      'messageEn': 'Only Pharmacy Owner or Branch Manager can assign branch memberships.',
      'messageBn': 'শুধুমাত্র ওনার বা ব্রাঞ্চ ম্যানেজার ব্রাঞ্চ মেম্বারশিপ পরিচালনা করতে পারেন.',
    };
  }

  static MobileBranchMembershipRecord createOfflineFallback({
    required String staffMemberId,
    required String staffName,
    required String branchId,
    required String branchName,
    required String role,
  }) {
    return MobileBranchMembershipRecord(
      membershipId: 'bsm-offline-$branchId',
      tenantId: 'tenant-default',
      staffMemberId: staffMemberId,
      staffName: staffName,
      staffUsername: '$staffMemberId@pharmacy.local',
      branchId: branchId,
      branchName: branchName,
      role: role.toUpperCase(),
      customRoleCode: '',
      customRoleTitle: '',
      isPrimary: true,
      isActive: true,
      assignedAt: null,
      assignedByUsername: 'offline_cached',
      revokedAt: null,
      revocationReason: '',
    );
  }
}
