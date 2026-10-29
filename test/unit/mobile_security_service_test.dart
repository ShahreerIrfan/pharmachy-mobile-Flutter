// test/unit/mobile_security_service_test.dart
// Architecture Decision: ADR-0005, ADR-0022 & ADR-0024

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/models/tenant_session.dart';
import 'package:pharmacy_mobile_manager/services/mobile_security_service.dart';

void main() {
  group('MobileSecurityService RBAC & Isolation Boundaries', () {
    late MobileSecurityService securityService;

    setUp(() {
      securityService = MobileSecurityService();
    });

    test('Tenant Owner is authorized to access manager app', () {
      const ownerSession = TenantSession(
        tenantId: 'tenant-dhaka-01',
        branchId: 'branch-dhanmondi',
        userId: 'user-owner-01',
        userRole: 'TENANT_OWNER',
        authToken: 'token-xyz',
      );

      expect(() => securityService.assertCanAccessManagerApp(ownerSession),
          returnsNormally);
    });

    test('Branch Manager is authorized to access manager app', () {
      const managerSession = TenantSession(
        tenantId: 'tenant-dhaka-01',
        branchId: 'branch-dhanmondi',
        userId: 'user-mgr-01',
        userRole: 'BRANCH_MANAGER',
        authToken: 'token-xyz',
      );

      expect(() => securityService.assertCanAccessManagerApp(managerSession),
          returnsNormally);
    });

    test('Cashier is strictly forbidden from accessing manager app', () {
      const cashierSession = TenantSession(
        tenantId: 'tenant-dhaka-01',
        branchId: 'branch-dhanmondi',
        userId: 'user-cashier-01',
        userRole: 'CASHIER',
        authToken: 'token-xyz',
      );

      expect(
        () => securityService.assertCanAccessManagerApp(cashierSession),
        throwsA(isA<SecurityException>().having(
          (e) => e.message,
          'message',
          contains('Cashier role is not authorized'),
        )),
      );
    });

    test('Cross-tenant inspection is blocked with SecurityException', () {
      const session = TenantSession(
        tenantId: 'tenant-dhaka-01',
        branchId: 'branch-dhanmondi',
        userId: 'user-owner-01',
        userRole: 'TENANT_OWNER',
        authToken: 'token-xyz',
      );

      expect(
        () => securityService.assertTenantMatch(session, 'foreign-tenant-02'),
        throwsA(isA<SecurityException>().having(
          (e) => e.message,
          'message',
          contains('Cross-Tenant Violation'),
        )),
      );
    });

    test('Branch Manager cannot inspect foreign branch within tenant', () {
      const session = TenantSession(
        tenantId: 'tenant-dhaka-01',
        branchId: 'branch-dhanmondi',
        userId: 'user-mgr-01',
        userRole: 'BRANCH_MANAGER',
        authToken: 'token-xyz',
      );

      expect(
        () => securityService.assertBranchAccess(
            session, 'foreign-branch-uttara'),
        throwsA(isA<SecurityException>().having(
          (e) => e.message,
          'message',
          contains('Cross-Branch Violation'),
        )),
      );
    });
  });
}
