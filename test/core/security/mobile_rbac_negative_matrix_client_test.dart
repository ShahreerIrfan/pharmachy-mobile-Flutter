// test/core/security/mobile_rbac_negative_matrix_client_test.dart
// Unit tests for P120 RBAC negative matrix mobile client.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_rbac_negative_matrix_client.dart';

void main() {
  group('MobileRbacNegativeMatrixClient Tests', () {
    late MobileRbacNegativeMatrixClient client;

    setUp(() {
      client = MobileRbacNegativeMatrixClient();
    });

    test('Cashier denied branch operating settings update', () {
      final res = client.evaluateAction(
        callerRole: 'CASHIER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-1',
        targetBranchId: 'branch-1',
        actionName: 'PATCH_BRANCH_SETTINGS',
      );

      expect(res.isAllowed, isFalse);
      expect(res.httpStatusCode, 403);
      expect(res.errorCode, 'ERR_STAFF_ROLE_DENIED');
    });

    test('Cashier denied staff audit timeline access', () {
      final res = client.evaluateAction(
        callerRole: 'CASHIER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-1',
        actionName: 'GET_STAFF_TIMELINE',
      );

      expect(res.isAllowed, isFalse);
      expect(res.httpStatusCode, 403);
      expect(res.errorCode, 'ERR_STAFF_ROLE_DENIED');
    });

    test('Branch Manager denied foreign branch drawer assignment', () {
      final res = client.evaluateAction(
        callerRole: 'BRANCH_MANAGER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-1',
        targetBranchId: 'branch-2',
        actionName: 'ASSIGN_OTHER_DRAWER',
      );

      expect(res.isAllowed, isFalse);
      expect(res.httpStatusCode, 403);
      expect(res.errorCode, 'ERR_CROSS_BRANCH_VIOLATION');
    });

    test('Branch Manager denied role migration execution', () {
      final res = client.evaluateAction(
        callerRole: 'BRANCH_MANAGER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-1',
        actionName: 'ROLE_MIGRATION',
      );

      expect(res.isAllowed, isFalse);
      expect(res.httpStatusCode, 403);
      expect(res.errorCode, 'ERR_STAFF_ROLE_DENIED');
    });

    test('Cross-tenant access forbidden across any role', () {
      final res = client.evaluateAction(
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-99',
        actionName: 'GET_STAFF_TIMELINE',
      );

      expect(res.isAllowed, isFalse);
      expect(res.httpStatusCode, 403);
      expect(res.errorCode, 'ERR_CROSS_TENANT_VIOLATION');
    });

    test('Suspended subscription blocks role migration', () {
      final res = client.evaluateAction(
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        targetTenantId: 'tenant-1',
        actionName: 'ROLE_MIGRATION',
        subscriptionStatus: 'SUSPENDED',
      );

      expect(res.isAllowed, isFalse);
      expect(res.httpStatusCode, 403);
      expect(res.errorCode, 'ERR_SUBSCRIPTION_UNENTITLED_WRITE_BLOCKED');
    });
  });
}
