// lib/core/staff/mobile_staff_invitation_client.dart
// Architecture Decision: ADR-0102
// Phase 06: Milestone M03 - Staff Onboarding & Multi-Branch Scopes (P102)
// Requirement Trace: FR-031, FR-032, FR-049, FR-082

enum MobileStaffUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileStaffInvitation {
  final String invitationId;
  final String tenantId;
  final String? branchId;
  final String? branchName;
  final String email;
  final String fullName;
  final String role;
  final String customRoleTitle;
  final String status;
  final String expiresAt;
  final int resendCount;

  const MobileStaffInvitation({
    required this.invitationId,
    required this.tenantId,
    this.branchId,
    this.branchName,
    required this.email,
    required this.fullName,
    required this.role,
    required this.customRoleTitle,
    required this.status,
    required this.expiresAt,
    required this.resendCount,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';
  bool get isRevoked => status.toUpperCase() == 'REVOKED';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';

  factory MobileStaffInvitation.fromJson(Map<String, dynamic> json) {
    return MobileStaffInvitation(
      invitationId: json['invitation_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String?,
      branchName: json['branch_name'] as String?,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      customRoleTitle: json['custom_role_title'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      expiresAt: json['expires_at'] as String? ?? '',
      resendCount: json['resend_count'] as int? ?? 0,
    );
  }
}

class MobileStaffMembership {
  final String membershipId;
  final String tenantId;
  final String staffId;
  final String username;
  final String fullName;
  final String? primaryBranchId;
  final String? primaryBranchName;
  final List<String> assignedBranchIds;
  final String role;
  final String customRoleTitle;
  final bool isActive;
  final String joinedAt;

  const MobileStaffMembership({
    required this.membershipId,
    required this.tenantId,
    required this.staffId,
    required this.username,
    required this.fullName,
    this.primaryBranchId,
    this.primaryBranchName,
    required this.assignedBranchIds,
    required this.role,
    required this.customRoleTitle,
    required this.isActive,
    required this.joinedAt,
  });

  factory MobileStaffMembership.fromJson(Map<String, dynamic> json) {
    final rawBranches = json['assigned_branch_ids'] as List<dynamic>? ?? [];
    return MobileStaffMembership(
      membershipId: json['membership_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      staffId: json['staff_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      primaryBranchId: json['primary_branch_id'] as String?,
      primaryBranchName: json['primary_branch_name'] as String?,
      assignedBranchIds: rawBranches.map((e) => e.toString()).toList(),
      role: json['role'] as String? ?? '',
      customRoleTitle: json['custom_role_title'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      joinedAt: json['joined_at'] as String? ?? '',
    );
  }
}

class MobileStaffState {
  final MobileStaffUiStatus uiStatus;
  final List<MobileStaffInvitation> invitations;
  final List<MobileStaffMembership> memberships;
  final String messageEn;
  final String messageBn;

  const MobileStaffState({
    required this.uiStatus,
    required this.invitations,
    required this.memberships,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileStaffState.fromPayload({
    required List<dynamic> rawInvitations,
    required List<dynamic> rawMemberships,
  }) {
    final invs = rawInvitations
        .map((e) => MobileStaffInvitation.fromJson(e as Map<String, dynamic>))
        .toList();
    final mems = rawMemberships
        .map((e) => MobileStaffMembership.fromJson(e as Map<String, dynamic>))
        .toList();
    final isEmpty = invs.isEmpty && mems.isEmpty;

    return MobileStaffState(
      uiStatus: isEmpty ? MobileStaffUiStatus.empty : MobileStaffUiStatus.success,
      invitations: invs,
      memberships: mems,
      messageEn: isEmpty ? 'No staff records found.' : 'Staff and invitations loaded.',
      messageBn: isEmpty ? 'কোন স্টাফ বা আমন্ত্রণ পাওয়া যায়নি।' : 'স্টাফ ও আমন্ত্রণ সফলভাবে লোড হয়েছে।',
    );
  }

  factory MobileStaffState.offline({
    List<MobileStaffInvitation> cachedInvs = const [],
    List<MobileStaffMembership> cachedMems = const [],
  }) {
    return MobileStaffState(
      uiStatus: MobileStaffUiStatus.offline,
      invitations: cachedInvs,
      memberships: cachedMems,
      messageEn: 'Offline mode: showing local cached staff roster.',
      messageBn: 'অফলাইন মোড: স্থানীয়ভাবে ক্যাশ করা স্টাফ তালিকা প্রদর্শিত হচ্ছে।',
    );
  }

  factory MobileStaffState.permissionDenied(String role) {
    return MobileStaffState(
      uiStatus: MobileStaffUiStatus.permissionDenied,
      invitations: const [],
      memberships: const [],
      messageEn: "Role '$role' lacks permission to manage staff invitations.",
      messageBn: "আপনার রোলে ('$role') স্টাফ আমন্ত্রণ পরিচালনার অনুমতি নেই।",
    );
  }
}
