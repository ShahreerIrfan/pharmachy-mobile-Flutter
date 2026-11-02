// lib/core/roles/mobile_custom_role_client.dart
// Architecture Decision: ADR-0103
// Phase 06: Milestone M03 - Staff Onboarding & Multi-Branch Scopes (P103)
// Requirement Trace: FR-005, FR-031, FR-049, FR-082

enum MobileRoleUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileCustomRole {
  final String roleId;
  final String tenantId;
  final String roleCode;
  final String displayName;
  final String description;
  final String baseRole;
  final List<String> permissionKeys;
  final bool requiresPcbRegistration;
  final bool isSystemProtected;
  final bool isArchived;
  final String? clonedFromId;

  const MobileCustomRole({
    required this.roleId,
    required this.tenantId,
    required this.roleCode,
    required this.displayName,
    required this.description,
    required this.baseRole,
    required this.permissionKeys,
    required this.requiresPcbRegistration,
    required this.isSystemProtected,
    required this.isArchived,
    this.clonedFromId,
  });

  bool get allowsClinicalDispensing =>
      permissionKeys.contains('dispense:rx_antibiotics') && requiresPcbRegistration;

  factory MobileCustomRole.fromJson(Map<String, dynamic> json) {
    final rawKeys = json['permission_keys'] as List<dynamic>? ?? [];
    return MobileCustomRole(
      roleId: json['role_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      roleCode: json['role_code'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      baseRole: json['base_role'] as String? ?? 'CASHIER',
      permissionKeys: rawKeys.map((e) => e.toString()).toList(),
      requiresPcbRegistration: json['requires_pcb_registration'] as bool? ?? false,
      isSystemProtected: json['is_system_protected'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      clonedFromId: json['cloned_from_id'] as String?,
    );
  }
}

class MobileRoleValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileRoleValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  static MobileRoleValidationResult validate({
    required String roleCode,
    required String displayName,
    required List<String> permissions,
    required bool requiresPcbRegistration,
  }) {
    final cleanCode = roleCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9_]{3,64}$').hasMatch(cleanCode)) {
      return const MobileRoleValidationResult(
        isValid: false,
        errorCode: 'ERR_INVALID_ROLE_CODE',
        messageEn: 'Role code must be 3-64 uppercase letters, numbers, or underscores.',
        messageBn: 'রোল কোড অবশ্যই ৩-৬৪ অক্ষরের ক্যাপিটাল লেটার বা নম্বর হতে হবে।',
      );
    }

    if (displayName.trim().length < 2) {
      return const MobileRoleValidationResult(
        isValid: false,
        errorCode: 'ERR_INVALID_DISPLAY_NAME',
        messageEn: 'Display name must be at least 2 characters.',
        messageBn: 'প্রদর্শনী নাম কমপক্ষে ২ অক্ষরের হতে হবে।',
      );
    }

    if (permissions.isEmpty) {
      return const MobileRoleValidationResult(
        isValid: false,
        errorCode: 'ERR_EMPTY_PERMISSIONS',
        messageEn: 'At least one permission is required.',
        messageBn: 'কমপক্ষে একটি পারমিশন নির্বাচন করতে হবে।',
      );
    }

    if (permissions.contains('system:hard_delete') || permissions.contains('stock:dispense_expired')) {
      return const MobileRoleValidationResult(
        isValid: false,
        errorCode: 'ERR_BLOCKED_PERMISSION',
        messageEn: 'Absolute danger action cannot be granted in any custom role.',
        messageBn: 'বিপজ্জনক অ্যাকশন কোনো কাস্টম রোলে অন্তর্ভুক্ত করা যাবে না।',
      );
    }

    if (permissions.contains('dispense:rx_antibiotics') && !requiresPcbRegistration) {
      return const MobileRoleValidationResult(
        isValid: false,
        errorCode: 'ERR_SAFETY_MINIMUM_PCB_REQUIRED',
        messageEn: 'Prescription dispensing requires verified PCB registration.',
        messageBn: 'প্রেসক্রিপশন বিতরণের জন্য পিসিবি রেজিস্ট্রেশন বাধ্যতামূলক।',
      );
    }

    return const MobileRoleValidationResult(
      isValid: true,
      messageEn: 'Role passes safety minimums.',
      messageBn: 'রোল নিরাপত্তা শর্ত পূরণ করেছে।',
    );
  }
}

class MobileRoleState {
  final MobileRoleUiStatus uiStatus;
  final List<MobileCustomRole> roles;
  final String messageEn;
  final String messageBn;

  const MobileRoleState({
    required this.uiStatus,
    required this.roles,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileRoleState.fromPayload(List<dynamic> rawList) {
    final roles = rawList
        .map((e) => MobileCustomRole.fromJson(e as Map<String, dynamic>))
        .toList();
    final isEmpty = roles.isEmpty;

    return MobileRoleState(
      uiStatus: isEmpty ? MobileRoleUiStatus.empty : MobileRoleUiStatus.success,
      roles: roles,
      messageEn: isEmpty ? 'No custom roles found.' : 'Custom roles loaded.',
      messageBn: isEmpty ? 'কোন কাস্টম রোল পাওয়া যায়নি।' : 'কাস্টম রোলসমূহ সফলভাবে লোড হয়েছে।',
    );
  }

  factory MobileRoleState.offline({List<MobileCustomRole> cachedRoles = const []}) {
    return MobileRoleState(
      uiStatus: MobileRoleUiStatus.offline,
      roles: cachedRoles,
      messageEn: 'Offline mode: displaying cached custom roles.',
      messageBn: 'অফলাইন মোড: ক্যাশ করা কাস্টম রোলসমূহ প্রদর্শিত হচ্ছে।',
    );
  }

  factory MobileRoleState.permissionDenied(String role) {
    return MobileRoleState(
      uiStatus: MobileRoleUiStatus.permissionDenied,
      roles: const [],
      messageEn: "Role '$role' lacks permission to manage custom roles.",
      messageBn: "আপনার রোলে ('$role') কাস্টম রোল পরিচালনার অনুমতি নেই।",
    );
  }
}
