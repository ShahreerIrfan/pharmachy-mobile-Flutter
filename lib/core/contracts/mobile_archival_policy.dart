/// Architecture Decision: ADR-0056
/// Mobile Client implementation of Regulatory Archival and Soft-Deletion:
/// - Prohibits destructive physical deletes on posted sales, prescriptions, and audits
/// - Supports soft-archival lifecycle for mutable master catalogs
library;

class MobileArchivalPolicyManager {
  static const Set<String> immutableTypes = {
    'SALE_INVOICE',
    'PRESCRIPTION_RECORD',
    'AUDIT_LOG_ENTRY',
    'PAYMENT_TRANSACTION',
  };

  static const Set<String> softArchivableTypes = {
    'MEDICINE_CATALOG',
    'STAFF_MEMBER',
    'BRANCH_CONFIG',
  };

  static bool isImmutable(String resourceType) {
    return immutableTypes.contains(resourceType.toUpperCase().trim());
  }

  static bool isSoftArchivable(String resourceType) {
    return softArchivableTypes.contains(resourceType.toUpperCase().trim());
  }

  static bool canDestructivelyDelete(String resourceType) {
    // Under ADR-0056, destructive physical deletion is forbidden
    return false;
  }

  static void validateDeletionPermitted(String resourceType, String resourceId) {
    final upper = resourceType.toUpperCase().trim();
    if (isImmutable(upper)) {
      throw StateError(
        'Destructive deletion is strictly prohibited for immutable record '
        "'$upper:$resourceId'. Use audited reversal or status transitions.",
      );
    }
  }

  static MobileArchivedResource createArchivalRecord({
    required String resourceType,
    required String resourceId,
    required String userId,
    required String reason,
  }) {
    validateDeletionPermitted(resourceType, resourceId);
    if (reason.trim().length < 5) {
      throw ArgumentError('Archival reason must be at least 5 characters long.');
    }

    return MobileArchivedResource(
      resourceType: resourceType.toUpperCase().trim(),
      resourceId: resourceId.trim(),
      isArchived: true,
      archivedAt: DateTime.now().toUtc(),
      archivedBy: userId,
      archivalReason: reason.trim(),
    );
  }
}

class MobileArchivedResource {
  final String resourceType;
  final String resourceId;
  final bool isArchived;
  final DateTime archivedAt;
  final String archivedBy;
  final String archivalReason;

  const MobileArchivedResource({
    required this.resourceType,
    required this.resourceId,
    required this.isArchived,
    required this.archivedAt,
    required this.archivedBy,
    required this.archivalReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'resource_type': resourceType,
      'resource_id': resourceId,
      'is_archived': isArchived,
      'archived_at': archivedAt.toIso8601String(),
      'archived_by': archivedBy,
      'archival_reason': archivalReason,
    };
  }
}
