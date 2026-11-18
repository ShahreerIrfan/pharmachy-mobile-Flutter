// mobile_supplier_permissions_client.dart
// Architecture Decision: ADR-0271 (P271).
// Phase 14: Customers, Suppliers, Dues & Payments.
//
// Flutter mobile client governing Supplier Master role-based access control,
// tenant boundaries, and controlled duplicate merges.

class SupplierPermissionException implements Exception {
  final String errorCode;
  final String message;

  SupplierPermissionException(this.errorCode, this.message);

  @override
  String toString() => '$errorCode: $message';
}

class SupplierValidationException implements Exception {
  final String errorCode;
  final String message;

  SupplierValidationException(this.errorCode, this.message);

  @override
  String toString() => '$errorCode: $message';
}

class MobileSupplierRecord {
  final String supplierId;
  final String tenantId;
  String name;
  String phone;
  String dlNumber;
  double creditLimit;
  double currentBalance;
  bool isActive;
  String? mergedIntoId;
  String? mergeReason;
  DateTime createdAt;

  MobileSupplierRecord({
    required this.supplierId,
    required this.tenantId,
    required this.name,
    this.phone = '',
    this.dlNumber = '',
    this.creditLimit = 0.0,
    this.currentBalance = 0.0,
    this.isActive = true,
    this.mergedIntoId,
    this.mergeReason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'supplier_id': supplierId,
        'tenant_id': tenantId,
        'name': name,
        'phone': phone,
        'dl_number': dlNumber,
        'credit_limit': creditLimit.toStringAsFixed(4),
        'current_balance': currentBalance.toStringAsFixed(4),
        'is_active': isActive,
        'merged_into_id': mergedIntoId,
        'merge_reason': mergeReason,
        'created_at': createdAt.toIso8601String(),
      };
}

class MobileSupplierMergeResult {
  final String sourceId;
  final String targetId;
  final String targetName;
  final bool isMerged;
  final String mergeReason;
  final DateTime mergedAt;

  MobileSupplierMergeResult({
    required this.sourceId,
    required this.targetId,
    required this.targetName,
    required this.isMerged,
    required this.mergeReason,
    required this.mergedAt,
  });

  Map<String, dynamic> toJson() => {
        'source_id': sourceId,
        'target_id': targetId,
        'target_name': targetName,
        'is_merged': isMerged,
        'merge_reason': mergeReason,
        'merged_at': mergedAt.toIso8601String(),
      };
}

class MobileSupplierPermissionsClient {
  final String tenantId;
  final String userRole;
  final String userId;
  final Map<String, MobileSupplierRecord> supplierStore;

  static const Set<String> viewRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
    'INVENTORY_CLERK',
    'FINANCE_OFFICER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
    'PROCUREMENT_OFFICER',
  };

  static const Set<String> manageRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'INVENTORY_CLERK',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
    'PROCUREMENT_OFFICER',
  };

  static const Set<String> adminRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  MobileSupplierPermissionsClient({
    required this.tenantId,
    required String userRole,
    this.userId = 'user_anon',
    Map<String, MobileSupplierRecord>? supplierStore,
  })  : userRole = userRole.toUpperCase(),
        supplierStore = supplierStore ?? {};

  bool get canView => viewRoles.contains(userRole);
  bool get canManage => manageRoles.contains(userRole);
  bool get canAdmin => adminRoles.contains(userRole);

  List<MobileSupplierRecord> listSuppliers({String? query}) {
    if (!canView) {
      throw SupplierPermissionException(
        'ERR_STAFF_ROLE_DENIED',
        'Role $userRole is not permitted to view supplier master.',
      );
    }
    final results = supplierStore.values.where((s) {
      if (s.tenantId != tenantId) return false;
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        return s.name.toLowerCase().contains(q) ||
            s.phone.contains(q) ||
            s.dlNumber.toLowerCase().contains(q);
      }
      return true;
    }).toList();
    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  MobileSupplierRecord getSupplier(String supplierId) {
    if (!canView) {
      throw SupplierPermissionException(
        'ERR_STAFF_ROLE_DENIED',
        'Role $userRole is not permitted to view supplier details.',
      );
    }
    final s = supplierStore[supplierId];
    if (s == null) {
      throw SupplierValidationException('ERR_SUPPLIER_NOT_FOUND', 'Supplier not found.');
    }
    if (s.tenantId != tenantId) {
      throw SupplierPermissionException('ERR_CROSS_TENANT_ACCESS', 'Cross-tenant access forbidden.');
    }
    return s;
  }

  static int _idCounter = 1;

  MobileSupplierRecord createSupplier({
    required String name,
    String phone = '',
    String dlNumber = '',
    double creditLimit = 0.0,
  }) {
    if (!canManage) {
      throw SupplierPermissionException(
        'ERR_STAFF_ROLE_DENIED',
        'Role $userRole cannot register suppliers.',
      );
    }
    if (name.trim().isEmpty) {
      throw SupplierValidationException('ERR_MISSING_SUPPLIER_NAME', 'Supplier name required.');
    }
    if (creditLimit < 0) {
      throw SupplierValidationException('ERR_INVALID_CREDIT_LIMIT', 'Credit limit cannot be negative.');
    }
    final supId = 'sup-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
    final s = MobileSupplierRecord(
      supplierId: supId,
      tenantId: tenantId,
      name: name.trim(),
      phone: phone.trim(),
      dlNumber: dlNumber.trim(),
      creditLimit: creditLimit,
    );
    supplierStore[supId] = s;
    return s;
  }

  MobileSupplierMergeResult mergeSuppliers({
    required String sourceId,
    required String targetId,
    String reason = 'Consolidation of duplicate supplier entries',
  }) {
    if (!canAdmin) {
      throw SupplierPermissionException(
        'ERR_STAFF_ROLE_DENIED',
        'Only pharmacy owners and branch managers are permitted to merge suppliers.',
      );
    }
    if (sourceId == targetId) {
      throw SupplierValidationException('ERR_CANNOT_MERGE_SELF', 'Cannot merge supplier into itself.');
    }
    final source = supplierStore[sourceId];
    if (source == null) {
      throw SupplierValidationException('ERR_SOURCE_NOT_FOUND', 'Source supplier not found.');
    }
    final target = supplierStore[targetId];
    if (target == null) {
      throw SupplierValidationException('ERR_TARGET_NOT_FOUND', 'Target supplier not found.');
    }
    if (source.tenantId != tenantId || target.tenantId != tenantId) {
      throw SupplierPermissionException('ERR_CROSS_TENANT_ACCESS', 'Cross-tenant merge prohibited.');
    }
    if (!target.isActive || target.mergedIntoId != null) {
      throw SupplierValidationException(
        'ERR_TARGET_ALREADY_MERGED',
        'Target supplier is inactive or already merged.',
      );
    }

    target.currentBalance += source.currentBalance;
    source.isActive = false;
    source.mergedIntoId = target.supplierId;
    source.mergeReason = reason;
    source.currentBalance = 0.0;

    return MobileSupplierMergeResult(
      sourceId: source.supplierId,
      targetId: target.supplierId,
      targetName: target.name,
      isMerged: true,
      mergeReason: reason,
      mergedAt: DateTime.now(),
    );
  }
}
