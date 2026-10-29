// lib/services/mobile_security_service.dart
// Architecture Decision: ADR-0005, ADR-0022 & ADR-0024

import '../models/tenant_session.dart';

class MobileSecurityService {
  static const Set<String> managerRoles = {
    'TENANT_OWNER',
    'BRANCH_MANAGER',
    'PLATFORM_SUPER_ADMIN',
  };

  void assertCanAccessManagerApp(TenantSession session) {
    if (!managerRoles.contains(session.userRole)) {
      throw SecurityException(
        'Security Violation: Cashier role is not authorized to access the Mobile Manager App. '
        'Executive privileges required (ADR-0005, ADR-0024).',
      );
    }
  }

  void assertTenantMatch(TenantSession session, String targetTenantId) {
    if (session.tenantId != targetTenantId) {
      throw SecurityException(
        'Cross-Tenant Violation: Active session tenant "${session.tenantId}" '
        'cannot access foreign tenant "$targetTenantId".',
      );
    }
  }

  void assertBranchAccess(TenantSession session, String targetBranchId) {
    if (session.isSuperAdmin || session.isOwner) {
      return; // Owners and super-admins can switch across branches in their tenant
    }
    if (session.branchId != targetBranchId) {
      throw SecurityException(
        'Cross-Branch Violation: Branch manager of "${session.branchId}" '
        'cannot inspect foreign branch "$targetBranchId".',
      );
    }
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => message;
}
