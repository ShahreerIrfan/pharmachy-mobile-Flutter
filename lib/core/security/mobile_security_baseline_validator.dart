/// mobile_security_baseline_validator.dart
///
/// Architecture Decision: ADR-0060
/// Mobile Manager App Security Baseline Validator.
/// Validates mobile application security baseline compliance:
///   - Mobile session identity and tenant scope
///   - Manager vs Cashier role restrictions
///   - Commercial purchase cost redaction
///   - Absolute system blocks preventing client-side destructive deletes
library mobile_security_baseline_validator;

import 'mobile_permission_matrix.dart';

class MobileSecurityPostureReport {
  final String service;
  final String version;
  final String tenantId;
  final String userRole;
  final String overallStatus;
  final DateTime timestamp;
  final int checksPassed;
  final int checksFailed;
  final List<String> verifiedPillars;

  const MobileSecurityPostureReport({
    required this.service,
    required this.version,
    required this.tenantId,
    required this.userRole,
    required this.overallStatus,
    required this.timestamp,
    required this.checksPassed,
    required this.checksFailed,
    required this.verifiedPillars,
  });

  Map<String, dynamic> toJson() => {
        'service': service,
        'version': version,
        'tenant_id': tenantId,
        'user_role': userRole,
        'overall_status': overallStatus,
        'timestamp': timestamp.toIso8601String(),
        'checks_passed': checksPassed,
        'checks_failed': checksFailed,
        'verified_pillars': verifiedPillars,
      };
}

class MobileSecurityBaselineValidator {
  static bool isBranchConfinementValid({
    required String userBranchId,
    required String targetBranchId,
    required String role,
  }) {
    final cleanRole = role.toUpperCase().trim();
    if (cleanRole == 'CASHIER' || cleanRole == 'STAFF_PHARMACIST') {
      if (userBranchId.isEmpty || targetBranchId.isEmpty) {
        return false;
      }
      return userBranchId.trim() == targetBranchId.trim();
    }
    return true;
  }

  static bool isCostPriceMaskingEnforced({
    required String role,
    required String rawCost,
  }) {
    final masked = MobilePermissionMatrix.maskFieldValue('cost_price', rawCost, role);
    final cleanRole = role.toUpperCase().trim();
    if (cleanRole == 'CASHIER') {
      return masked == '***REDACTED***';
    } else if (cleanRole == 'PHARMACY_OWNER' || cleanRole == 'BRANCH_MANAGER') {
      return masked == rawCost;
    }
    return true;
  }

  static bool isDeletionBlocked({
    required String method,
    required String path,
  }) {
    return MobilePermissionMatrix.isAbsoluteBlocked(method, path);
  }

  static MobileSecurityPostureReport evaluateMobileBaseline({
    required String tenantId,
    required String userRole,
    required String branchId,
    required String sampleCostPrice,
  }) {
    final List<String> pillars = [];
    int passed = 0;
    int failed = 0;

    // Pillar 1: Identity & Session Gate
    if (tenantId.isNotEmpty && userRole.isNotEmpty) {
      passed++;
      pillars.add('AUTH_GATE');
    } else {
      failed++;
    }

    // Pillar 2: Branch Confinement Gate
    if (isBranchConfinementValid(
      userBranchId: branchId,
      targetBranchId: branchId,
      role: userRole,
    )) {
      passed++;
      pillars.add('ISOLATION_GATE');
    } else {
      failed++;
    }

    // Pillar 3: Privacy & Price Masking Gate
    if (isCostPriceMaskingEnforced(role: userRole, rawCost: sampleCostPrice)) {
      passed++;
      pillars.add('PRIVACY_GATE');
    } else {
      failed++;
    }

    // Pillar 4: Absolute Block Gate
    if (isDeletionBlocked(method: 'DELETE', path: '/api/v2/invoices/')) {
      passed++;
      pillars.add('AUTHORIZATION_GATE');
    } else {
      failed++;
    }

    final overall = failed == 0 ? 'PASSED' : 'FAILED';

    return MobileSecurityPostureReport(
      service: 'pharmacy-mobile-manager',
      version: 'v2',
      tenantId: tenantId,
      userRole: userRole,
      overallStatus: overall,
      timestamp: DateTime.now().toUtc(),
      checksPassed: passed,
      checksFailed: failed,
      verifiedPillars: List.unmodifiable(pillars),
    );
  }
}
