// mobile_stock_permission_audit_client.dart
// Architecture Decision: ADR-0219 (P219).
// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.
//
// Mobile Manager Client for Role & Branch-Scoped Stock Permissions and Audits:
// - Evaluates counting, adjustment, quarantine release, transfer, and valuation permissions.
// - Enforces tenant and branch isolation for branch-bound staff.
// - Records immutable audit logs for every ALLOWED and DENIED attempt.

enum MobileStockActionScope {
  stockCounting('STOCK_COUNTING', 'Physical Cycle Counting', 'ফিজিক্যাল সাইকেল কাউন্ট'),
  stockAdjustment('STOCK_ADJUSTMENT', 'Stock Adjustment / Correction', 'স্টক অ্যাডজাস্টমেন্ট ও সংশোধন'),
  quarantineRelease('QUARANTINE_RELEASE', 'Quarantine Release', 'কোয়ারেন্টাইন থেকে রিলিজ'),
  interbranchTransfer('INTERBRANCH_TRANSFER', 'Interbranch Transfer', 'আন্তঃশাখা স্টক স্থানান্তর'),
  valuationData('VALUATION_DATA', 'Inventory Valuation Data', 'ইনভেন্টরি ভ্যালুয়েশন ও কস্টিং ডাটা');

  final String apiValue;
  final String labelEn;
  final String labelBn;

  const MobileStockActionScope(this.apiValue, this.labelEn, this.labelBn);

  static MobileStockActionScope fromApiValue(String value) {
    final normalized = value.toUpperCase();
    return MobileStockActionScope.values.firstWhere(
      (e) => e.apiValue == normalized,
      orElse: () => MobileStockActionScope.stockCounting,
    );
  }
}

enum MobilePermissionDecision {
  allowed('ALLOWED', 'Authorized / Permitted', 'অনুমোদিত'),
  denied('DENIED', 'Forbidden / Rejected', 'অনুমতি নেই');

  final String apiValue;
  final String labelEn;
  final String labelBn;

  const MobilePermissionDecision(this.apiValue, this.labelEn, this.labelBn);

  static MobilePermissionDecision fromApiValue(String value) {
    return value.toUpperCase() == 'ALLOWED'
        ? MobilePermissionDecision.allowed
        : MobilePermissionDecision.denied;
  }
}

class MobileStockPermissionAuditEntry {
  final String auditId;
  final String tenantId;
  final String targetBranchId;
  final String actorRole;
  final String actorAssignedBranchId;
  final MobileStockActionScope actionScope;
  final String resourceId;
  final MobilePermissionDecision decision;
  final String errorCode;
  final String reasonEn;
  final String reasonBn;
  final String sha256Signature;
  final DateTime createdAt;

  MobileStockPermissionAuditEntry({
    required this.auditId,
    required this.tenantId,
    required this.targetBranchId,
    required this.actorRole,
    required this.actorAssignedBranchId,
    required this.actionScope,
    required this.resourceId,
    required this.decision,
    required this.errorCode,
    required this.reasonEn,
    required this.reasonBn,
    required this.sha256Signature,
    required this.createdAt,
  });

  factory MobileStockPermissionAuditEntry.fromJson(Map<String, dynamic> json) {
    return MobileStockPermissionAuditEntry(
      auditId: (json['audit_id'] ?? '') as String,
      tenantId: (json['tenant_id'] ?? '') as String,
      targetBranchId: (json['branch_id'] ?? '') as String,
      actorRole: (json['actor_role'] ?? 'UNKNOWN') as String,
      actorAssignedBranchId: (json['actor_assigned_branch_id'] ?? '') as String,
      actionScope: MobileStockActionScope.fromApiValue((json['action_scope'] ?? '') as String),
      resourceId: (json['resource_id'] ?? '') as String,
      decision: MobilePermissionDecision.fromApiValue((json['decision'] ?? 'DENIED') as String),
      errorCode: (json['error_code'] ?? '') as String,
      reasonEn: (json['reason_en'] ?? '') as String,
      reasonBn: (json['reason_bn'] ?? '') as String,
      sha256Signature: (json['sha256_signature'] ?? '') as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'audit_id': auditId,
        'tenant_id': tenantId,
        'branch_id': targetBranchId,
        'actor_role': actorRole,
        'actor_assigned_branch_id': actorAssignedBranchId,
        'action_scope': actionScope.apiValue,
        'resource_id': resourceId,
        'decision': decision.apiValue,
        'error_code': errorCode,
        'reason_en': reasonEn,
        'reason_bn': reasonBn,
        'sha256_signature': sha256Signature,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

class MobileStockPermissionAuditClient {
  static const Set<String> _tenantWideRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'AUDITOR',
  };

  static const Map<MobileStockActionScope, Set<String>> _permissionMatrix = {
    MobileStockActionScope.stockCounting: {
      'SUPERADMIN',
      'PHARMACY_OWNER',
      'BRANCH_MANAGER',
      'STAFF_PHARMACIST',
      'INVENTORY_CLERK',
    },
    MobileStockActionScope.stockAdjustment: {
      'SUPERADMIN',
      'PHARMACY_OWNER',
      'BRANCH_MANAGER',
      'STAFF_PHARMACIST',
    },
    MobileStockActionScope.quarantineRelease: {
      'SUPERADMIN',
      'PHARMACY_OWNER',
      'BRANCH_MANAGER',
      'STAFF_PHARMACIST',
    },
    MobileStockActionScope.interbranchTransfer: {
      'SUPERADMIN',
      'PHARMACY_OWNER',
      'BRANCH_MANAGER',
      'STAFF_PHARMACIST',
    },
    MobileStockActionScope.valuationData: {
      'SUPERADMIN',
      'PHARMACY_OWNER',
      'BRANCH_MANAGER',
      'STAFF_PHARMACIST',
      'FINANCE_OFFICER',
      'AUDITOR',
    },
  };

  final List<MobileStockPermissionAuditEntry> _auditLogs = [];
  int _seqCounter = 0;

  Map<String, List<String>> getRoleMatrixSummary() {
    return {
      for (final entry in _permissionMatrix.entries)
        entry.key.apiValue: entry.value.toList()..sort(),
    };
  }

  MobileStockPermissionAuditEntry evaluatePermission({
    required String actorRole,
    required String actorTenantId,
    required String actorAssignedBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required MobileStockActionScope actionScope,
    String resourceId = '',
  }) {
    final roleUpper = actorRole.trim().toUpperCase();
    _seqCounter += 1;
    final auditId = 'paudit-mob-$_seqCounter';
    final now = DateTime.now().toUtc();

    // 1. Multi-Tenant Isolation Check
    if (roleUpper != 'SUPERADMIN' && actorTenantId != targetTenantId) {
      final entry = MobileStockPermissionAuditEntry(
        auditId: auditId,
        tenantId: targetTenantId,
        targetBranchId: targetBranchId,
        actorRole: roleUpper,
        actorAssignedBranchId: actorAssignedBranchId,
        actionScope: actionScope,
        resourceId: resourceId,
        decision: MobilePermissionDecision.denied,
        errorCode: 'ERR_CROSS_TENANT_ACCESS_DENIED',
        reasonEn: 'Cross-tenant stock action blocked.',
        reasonBn: 'অন্য টেন্যান্টের শাখায় স্টক অপারেশন অনুমোদিত নয়।',
        sha256Signature: '',
        createdAt: now,
      );
      _auditLogs.add(entry);
      return entry;
    }

    // 2. Strict Branch Isolation Check
    if (!_tenantWideRoles.contains(roleUpper) && actorAssignedBranchId != targetBranchId) {
      final entry = MobileStockPermissionAuditEntry(
        auditId: auditId,
        tenantId: targetTenantId,
        targetBranchId: targetBranchId,
        actorRole: roleUpper,
        actorAssignedBranchId: actorAssignedBranchId,
        actionScope: actionScope,
        resourceId: resourceId,
        decision: MobilePermissionDecision.denied,
        errorCode: 'ERR_CROSS_BRANCH_ACCESS_DENIED',
        reasonEn:
            'Cross-branch violation: $roleUpper assigned to $actorAssignedBranchId cannot act in $targetBranchId',
        reasonBn:
            'শাখার সীমানা লঙ্ঘন: অন্য শাখার ব্যবহারকারী এই শাখায় কাজ করতে পারবেন না।',
        sha256Signature: '',
        createdAt: now,
      );
      _auditLogs.add(entry);
      return entry;
    }

    // 3. Role Matrix Check
    final allowedRoles = _permissionMatrix[actionScope] ?? const <String>{};
    if (!allowedRoles.contains(roleUpper)) {
      final entry = MobileStockPermissionAuditEntry(
        auditId: auditId,
        tenantId: targetTenantId,
        targetBranchId: targetBranchId,
        actorRole: roleUpper,
        actorAssignedBranchId: actorAssignedBranchId,
        actionScope: actionScope,
        resourceId: resourceId,
        decision: MobilePermissionDecision.denied,
        errorCode: 'ERR_ROLE_NOT_AUTHORIZED',
        reasonEn: 'Role $roleUpper is forbidden from ${actionScope.apiValue}.',
        reasonBn: '$roleUpper রোল-এর জন্য এই অ্যাকশন নিষিদ্ধ।',
        sha256Signature: '',
        createdAt: now,
      );
      _auditLogs.add(entry);
      return entry;
    }

    // 4. Allowed
    final entry = MobileStockPermissionAuditEntry(
      auditId: auditId,
      tenantId: targetTenantId,
      targetBranchId: targetBranchId,
      actorRole: roleUpper,
      actorAssignedBranchId: actorAssignedBranchId,
      actionScope: actionScope,
      resourceId: resourceId,
      decision: MobilePermissionDecision.allowed,
      errorCode: '',
      reasonEn: 'Authorized: $roleUpper permitted for ${actionScope.apiValue}.',
      reasonBn: 'অনুমোদিত।',
      sha256Signature: '',
      createdAt: now,
    );
    _auditLogs.add(entry);
    return entry;
  }

  MobileStockPermissionAuditEntry assertAuthorized({
    required String actorRole,
    required String actorTenantId,
    required String actorAssignedBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required MobileStockActionScope actionScope,
    String resourceId = '',
  }) {
    final entry = evaluatePermission(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorAssignedBranchId: actorAssignedBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      actionScope: actionScope,
      resourceId: resourceId,
    );
    if (entry.decision == MobilePermissionDecision.denied) {
      throw StateError('${entry.errorCode}: ${entry.reasonEn}');
    }
    return entry;
  }

  List<MobileStockPermissionAuditEntry> getAuditLogs({
    String? branchId,
    MobilePermissionDecision? decision,
  }) {
    final filtered = _auditLogs.where((entry) {
      if (branchId != null && entry.targetBranchId != branchId) return false;
      if (decision != null && entry.decision != decision) return false;
      return true;
    }).toList();
    return List.unmodifiable(filtered);
  }
}
