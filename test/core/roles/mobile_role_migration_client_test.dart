// test/core/roles/mobile_role_migration_client_test.dart
// Unit tests for P119 Role Migration and Grants mobile client.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/roles/mobile_role_migration_client.dart';

void main() {
  group('MobileRoleMigrationClient Tests', () {
    late MobileRoleMigrationClient client;

    setUp(() {
      client = MobileRoleMigrationClient();
    });

    test('Owner executes role grant migration on plan downgrade to Basic', () {
      final res = client.reconcileRole(
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        targetTenantId: 'tenant-1',
        planTier: 'BASIC',
        roleId: 'role-1',
        roleCode: 'SR_CASHIER',
        currentVersion: 1,
        currentPermissions: [
          'sales:checkout',
          'inventory:view_stock',
          'audit:export', // unentitled in basic
        ],
        reason: 'PLAN_DOWNGRADE',
      );

      expect(res.uiStatus, MobileMigrationUiStatus.success);
      expect(res.record, isNotNull);
      expect(res.record!.previousVersion, 1);
      expect(res.record!.newVersion, 2);
      expect(res.record!.retainedPermissions, contains('sales:checkout'));
      expect(res.record!.retainedPermissions, contains('inventory:view_stock'));
      expect(res.record!.removedPermissions, contains('audit:export'));
    });

    test('Forbidden permissions are blocked and removed from retained set', () {
      final res = client.reconcileRole(
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        targetTenantId: 'tenant-1',
        planTier: 'BASIC',
        roleId: 'role-2',
        roleCode: 'DISPENSER',
        currentVersion: 2,
        currentPermissions: [
          'sales:checkout',
          'stock:dispense_expired',
        ],
        reason: 'COMPLIANCE_PRUNING',
      );

      expect(res.uiStatus, MobileMigrationUiStatus.success);
      expect(res.record!.forbiddenGrantsBlocked, contains('stock:dispense_expired'));
      expect(res.record!.retainedPermissions.contains('stock:dispense_expired'), isFalse);
    });

    test('Dry run flag is recorded on preview', () {
      final res = client.reconcileRole(
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        targetTenantId: 'tenant-1',
        planTier: 'BASIC',
        roleId: 'role-1',
        roleCode: 'SR_CASHIER',
        currentVersion: 3,
        currentPermissions: ['sales:checkout'],
        reason: 'TEMPLATE_EVOLUTION',
        isDryRun: true,
      );

      expect(res.uiStatus, MobileMigrationUiStatus.success);
      expect(res.record!.isDryRun, isTrue);
      expect(res.record!.newVersion, 4);
    });

    test('Branch Manager access is denied', () {
      final res = client.reconcileRole(
        callerRole: 'BRANCH_MANAGER',
        callerTenantId: 'tenant-1',
        targetTenantId: 'tenant-1',
        planTier: 'BASIC',
        roleId: 'role-1',
        roleCode: 'SR_CASHIER',
        currentVersion: 1,
        currentPermissions: ['sales:checkout'],
        reason: 'PLAN_DOWNGRADE',
      );

      expect(res.uiStatus, MobileMigrationUiStatus.permissionDenied);
      expect(res.errorCode, 'ERR_STAFF_ROLE_DENIED');
    });

    test('Cashier access is denied', () {
      final res = client.reconcileRole(
        callerRole: 'CASHIER',
        callerTenantId: 'tenant-1',
        targetTenantId: 'tenant-1',
        planTier: 'BASIC',
        roleId: 'role-1',
        roleCode: 'SR_CASHIER',
        currentVersion: 1,
        currentPermissions: ['sales:checkout'],
        reason: 'PLAN_DOWNGRADE',
      );

      expect(res.uiStatus, MobileMigrationUiStatus.permissionDenied);
      expect(res.errorCode, 'ERR_STAFF_ROLE_DENIED');
    });

    test('Cross tenant role migration is forbidden', () {
      final res = client.reconcileRole(
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        targetTenantId: 'tenant-2',
        planTier: 'BASIC',
        roleId: 'role-1',
        roleCode: 'SR_CASHIER',
        currentVersion: 1,
        currentPermissions: ['sales:checkout'],
        reason: 'PLAN_DOWNGRADE',
      );

      expect(res.uiStatus, MobileMigrationUiStatus.permissionDenied);
      expect(res.errorCode, 'ERR_CROSS_TENANT_VIOLATION');
    });
  });
}
