import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_stock_permission_audit_client.dart';

void main() {
  group('P219: MobileStockPermissionAuditClient Tests', () {
    late MobileStockPermissionAuditClient client;

    setUp(() {
      client = MobileStockPermissionAuditClient();
    });

    test('1. Valid role authorization and tenant-wide multi-branch access', () {
      final phRelease = client.assertAuthorized(
        actorRole: 'STAFF_PHARMACIST',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        actionScope: MobileStockActionScope.quarantineRelease,
        resourceId: 'bat-001',
      );
      expect(phRelease.decision, MobilePermissionDecision.allowed);
      expect(phRelease.errorCode, isEmpty);

      final clkCount = client.assertAuthorized(
        actorRole: 'INVENTORY_CLERK',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        actionScope: MobileStockActionScope.stockCounting,
        resourceId: 'cnt-001',
      );
      expect(clkCount.decision, MobilePermissionDecision.allowed);

      final ownerTransfer = client.assertAuthorized(
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a2',
        actionScope: MobileStockActionScope.interbranchTransfer,
        resourceId: 'trf-001',
      );
      expect(ownerTransfer.decision, MobilePermissionDecision.allowed);

      final financeValuation = client.assertAuthorized(
        actorRole: 'FINANCE_OFFICER',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a2',
        actionScope: MobileStockActionScope.valuationData,
        resourceId: 'val-001',
      );
      expect(financeValuation.decision, MobilePermissionDecision.allowed);
    });

    test('2. Strict role denials logged and rejected for restricted actions', () {
      final clerkQuarantine = client.evaluatePermission(
        actorRole: 'INVENTORY_CLERK',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        actionScope: MobileStockActionScope.quarantineRelease,
        resourceId: 'bat-002',
      );
      expect(clerkQuarantine.decision, MobilePermissionDecision.denied);
      expect(clerkQuarantine.errorCode, 'ERR_ROLE_NOT_AUTHORIZED');
      expect(clerkQuarantine.reasonBn, contains('নিষিদ্ধ'));

      expect(
        () => client.assertAuthorized(
          actorRole: 'INVENTORY_CLERK',
          actorTenantId: 'ten-a',
          actorAssignedBranchId: 'br-a',
          targetTenantId: 'ten-a',
          targetBranchId: 'br-a',
          actionScope: MobileStockActionScope.valuationData,
          resourceId: 'val-002',
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        () => client.assertAuthorized(
          actorRole: 'CASHIER',
          actorTenantId: 'ten-a',
          actorAssignedBranchId: 'br-a',
          targetTenantId: 'ten-a',
          targetBranchId: 'br-a',
          actionScope: MobileStockActionScope.stockCounting,
          resourceId: 'cnt-002',
        ),
        throwsA(isA<StateError>()),
      );

      final deniedLogs = client.getAuditLogs(decision: MobilePermissionDecision.denied);
      expect(deniedLogs.length, 3);
    });

    test('3. Cross-branch isolation blocks branch-bound staff from sibling branch', () {
      final entry = client.evaluatePermission(
        actorRole: 'STAFF_PHARMACIST',
        actorTenantId: 'ten-a',
        actorAssignedBranchId: 'br-a',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a2',
        actionScope: MobileStockActionScope.stockAdjustment,
        resourceId: 'adj-x1',
      );
      expect(entry.decision, MobilePermissionDecision.denied);
      expect(entry.errorCode, 'ERR_CROSS_BRANCH_ACCESS_DENIED');
      expect(entry.reasonBn, contains('শাখার সীমানা লঙ্ঘন'));

      expect(
        () => client.assertAuthorized(
          actorRole: 'BRANCH_MANAGER',
          actorTenantId: 'ten-a',
          actorAssignedBranchId: 'br-a',
          targetTenantId: 'ten-a',
          targetBranchId: 'br-a2',
          actionScope: MobileStockActionScope.stockCounting,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('4. Cross-tenant isolation and immutable audit logs with JSON serialization', () {
      final crossTenant = client.evaluatePermission(
        actorRole: 'PHARMACY_OWNER',
        actorTenantId: 'ten-b',
        actorAssignedBranchId: 'br-b',
        targetTenantId: 'ten-a',
        targetBranchId: 'br-a',
        actionScope: MobileStockActionScope.valuationData,
      );
      expect(crossTenant.decision, MobilePermissionDecision.denied);
      expect(crossTenant.errorCode, 'ERR_CROSS_TENANT_ACCESS_DENIED');

      final roundTrip = MobileStockPermissionAuditEntry.fromJson(crossTenant.toJson());
      expect(roundTrip.auditId, crossTenant.auditId);
      expect(roundTrip.actionScope, MobileStockActionScope.valuationData);
      expect(roundTrip.decision, MobilePermissionDecision.denied);
      expect(roundTrip.errorCode, 'ERR_CROSS_TENANT_ACCESS_DENIED');

      final logs = client.getAuditLogs();
      expect(logs.length, 1);
      expect(() => logs.add(crossTenant), throwsUnsupportedError);
    });
  });
}
