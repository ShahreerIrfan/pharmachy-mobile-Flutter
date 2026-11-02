// lib/core/roles/mobile_role_migration_client.dart
// Architecture Decision: ADR-0119
// Phase 06: Milestone M03 - Role Migration & Grants Versioning (P119)

enum MobileMigrationUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileRoleMigrationRecord {
  final String migrationId;
  final String tenantId;
  final String roleId;
  final String roleCode;
  final int previousVersion;
  final int newVersion;
  final String reason;
  final List<String> previousPermissions;
  final List<String> retainedPermissions;
  final List<String> removedPermissions;
  final List<String> forbiddenGrantsBlocked;
  final bool isDryRun;
  final String appliedAt;

  const MobileRoleMigrationRecord({
    required this.migrationId,
    required this.tenantId,
    required this.roleId,
    required this.roleCode,
    required this.previousVersion,
    required this.newVersion,
    required this.reason,
    required this.previousPermissions,
    required this.retainedPermissions,
    required this.removedPermissions,
    required this.forbiddenGrantsBlocked,
    required this.isDryRun,
    required this.appliedAt,
  });

  factory MobileRoleMigrationRecord.fromJson(Map<String, dynamic> json) {
    return MobileRoleMigrationRecord(
      migrationId: json['migration_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      roleId: json['role_id'] ?? '',
      roleCode: json['role_code'] ?? '',
      previousVersion: json['previous_version'] ?? 1,
      newVersion: json['new_version'] ?? 2,
      reason: json['reason'] ?? 'PLAN_DOWNGRADE',
      previousPermissions: List<String>.from(json['previous_permissions'] ?? []),
      retainedPermissions: List<String>.from(json['retained_permissions'] ?? []),
      removedPermissions: List<String>.from(json['removed_permissions'] ?? []),
      forbiddenGrantsBlocked: List<String>.from(json['forbidden_grants_blocked'] ?? []),
      isDryRun: json['is_dry_run'] ?? false,
      appliedAt: json['applied_at'] ?? '',
    );
  }
}

class MobileMigrationResult {
  final MobileMigrationUiStatus uiStatus;
  final MobileRoleMigrationRecord? record;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileMigrationResult({
    required this.uiStatus,
    this.record,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileMigrationResult.success(MobileRoleMigrationRecord record) {
    return MobileMigrationResult(
      uiStatus: MobileMigrationUiStatus.success,
      record: record,
      messageEn: 'Role grants versioned to ${record.newVersion}.',
      messageBn: 'রোল গ্রান্টস সফলভাবে সংস্করণ ${record.newVersion}-এ উন্নীত হয়েছে।',
    );
  }

  factory MobileMigrationResult.error({
    required MobileMigrationUiStatus status,
    required String code,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileMigrationResult(
      uiStatus: status,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileRoleMigrationClient {
  static const Set<String> forbiddenPermissions = {
    'system:hard_delete',
    'stock:dispense_expired',
    'auth:bypass_tenant_isolation',
  };

  static const Set<String> basicAllowed = {
    'sales:checkout',
    'sales:view_reports',
    'cash:shift_close',
    'inventory:view_stock',
    'finance:due_repayment',
  };

  MobileMigrationResult reconcileRole({
    required String callerRole,
    required String callerTenantId,
    required String targetTenantId,
    required String planTier,
    required String roleId,
    required String roleCode,
    required int currentVersion,
    required List<String> currentPermissions,
    required String reason,
    bool isDryRun = false,
  }) {
    // 1. Role Authorization
    if (callerRole.toUpperCase() != 'PHARMACY_OWNER' && callerRole.toUpperCase() != 'SUPERADMIN') {
      return MobileMigrationResult.error(
        status: MobileMigrationUiStatus.permissionDenied,
        code: 'ERR_STAFF_ROLE_DENIED',
        msgEn: 'Only Pharmacy Owners or Superadmins may execute or preview role migrations.',
        msgBn: 'শুধুমাত্র ফার্মেসি মালিক অথবা সুপারঅ্যাডমিন রোল মাইগ্রেশন সম্পাদন করতে পারেন।',
      );
    }

    // 2. Cross-Tenant Check
    if (callerTenantId != targetTenantId && callerRole.toUpperCase() != 'SUPERADMIN') {
      return MobileMigrationResult.error(
        status: MobileMigrationUiStatus.permissionDenied,
        code: 'ERR_CROSS_TENANT_VIOLATION',
        msgEn: 'Cross-tenant role migration is strictly forbidden.',
        msgBn: 'অন্য টেন্যান্টের রোল মাইগ্রেশন করা যাবে না।',
      );
    }

    // 3. Pruning
    final retained = <String>[];
    final removed = <String>[];
    final forbiddenBlocked = <String>[];

    final isBasic = planTier.toUpperCase() == 'BASIC';

    for (final perm in currentPermissions) {
      if (forbiddenPermissions.contains(perm)) {
        forbiddenBlocked.add(perm);
        removed.add(perm);
      } else if (isBasic && !basicAllowed.contains(perm)) {
        removed.add(perm);
      } else {
        retained.add(perm);
      }
    }

    final newVersion = currentVersion + 1;
    final record = MobileRoleMigrationRecord(
      migrationId: 'rmig-mob-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: targetTenantId,
      roleId: roleId,
      roleCode: roleCode,
      previousVersion: currentVersion,
      newVersion: newVersion,
      reason: reason,
      previousPermissions: List.from(currentPermissions),
      retainedPermissions: retained,
      removedPermissions: removed,
      forbiddenGrantsBlocked: forbiddenBlocked,
      isDryRun: isDryRun,
      appliedAt: DateTime.now().toIso8601String(),
    );

    return MobileMigrationResult.success(record);
  }
}
