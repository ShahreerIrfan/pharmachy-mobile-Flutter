// mobile_inventory_valuation_test.dart
// Architecture Decision: ADR-0295 (P295).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_inventory_valuation_client.dart';

void main() {
  group('MobileInventoryValuationClient P295 Unit Tests', () {
    const tenantId = 'ten-dhaka-pharma-01';
    const branchId = 'br-dhanmondi-main';

    test('1. Pharmacy Owner generates inventory valuation report with balanced reconciliation', () {
      final client = MobileInventoryValuationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final report = client.generateValuationReport(
        sellableUnits: 5000,
        sellableValue: 250000.00,
        quarantinedUnits: 100,
        quarantinedValue: 5000.00,
        expiredUnits: 50,
        expiredLossValue: 2500.00,
        glBookValue: 255000.00,
      );

      // Total Physical: 250k + 5k = 255k.
      expect(report.physicalInventory.totalPhysicalValuationBdt, equals(255000.00));
      expect(report.physicalInventory.totalOnHandUnits, equals(5100));

      // GL Book Value: 255k.
      expect(report.accountingGl.glBookValueBdt, equals(255000.00));

      // Variance = 0.00, isBalanced = true.
      expect(report.reconciliation.valuationVarianceBdt, equals(0.00));
      expect(report.reconciliation.isBalanced, isTrue);
      expect(report.reconciliation.status, equals('BALANCED'));
    });

    test('2. Discrepancy between GL and physical lots detects VARIANCE_DETECTED', () {
      final client = MobileInventoryValuationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr-fin-1',
      );

      final report = client.generateValuationReport(
        sellableValue: 240000.00, // Shortage of 15k vs GL
        glBookValue: 255000.00,
      );

      expect(report.reconciliation.isBalanced, isFalse);
      expect(report.reconciliation.status, equals('VARIANCE_DETECTED'));
      expect(report.reconciliation.valuationVarianceBdt, equals(10000.00)); // 255k - 245k = 10k
    });

    test('3. Pharmacy Owner posts audited valuation write-down adjustment', () {
      final client = MobileInventoryValuationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final adj = client.postValuationAdjustment(
        adjustmentType: 'WRITE_DOWN',
        amountBdt: 10000.00,
        reason: 'Physical cycle count shrinkage reconciliation',
        auditNotes: 'Verified against DGDA audited register',
      );

      expect(adj.status, equals('ADJUSTMENT_POSTED'));
      expect(adj.adjustmentType, equals('WRITE_DOWN'));
      expect(adj.amountBdt, equals(10000.00));
      expect(adj.adjustmentId, startsWith('ivadj-'));
    });

    test('4. Cashier is blocked with ERR_INVENTORY_VALUATION_UNAUTHORIZED', () {
      final client = MobileInventoryValuationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr-cashier-1',
      );

      expect(
        () => client.generateValuationReport(),
        throwsA(
          isA<InventoryValuationPermissionException>().having((e) => e.errorCode, 'errorCode', equals('ERR_INVENTORY_VALUATION_UNAUTHORIZED')),
        ),
      );
    });

    test('5. Branch Manager is blocked from posting valuation adjustments', () {
      final client = MobileInventoryValuationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-bm-1',
      );

      expect(
        () => client.postValuationAdjustment(
          adjustmentType: 'WRITE_DOWN',
          amountBdt: 500.00,
          reason: 'Unauthorized branch adjustment',
        ),
        throwsA(
          isA<InventoryValuationPermissionException>().having((e) => e.errorCode, 'errorCode', equals('ERR_VALUATION_ADJUST_FORBIDDEN')),
        ),
      );
    });

    test('6. Branch Manager attempting to view other branch is blocked with ERR_BRANCH_ACCESS_DENIED', () {
      final client = MobileInventoryValuationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-bm-1',
      );

      expect(
        () => client.generateValuationReport(queryBranchId: 'br-other-branch'),
        throwsA(
          isA<InventoryValuationPermissionException>().having((e) => e.errorCode, 'errorCode', equals('ERR_BRANCH_ACCESS_DENIED')),
        ),
      );
    });

    test('7. Suspended tenant is blocked with ERR_TENANT_SUSPENDED', () {
      final client = MobileInventoryValuationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
        isSuspended: true,
      );

      expect(
        () => client.generateValuationReport(),
        throwsA(
          isA<InventoryValuationPermissionException>().having((e) => e.errorCode, 'errorCode', equals('ERR_TENANT_SUSPENDED')),
        ),
      );
    });

    test('8. Non-positive adjustment amount throws ERR_INVALID_AMOUNT', () {
      final client = MobileInventoryValuationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      expect(
        () => client.postValuationAdjustment(
          adjustmentType: 'WRITE_DOWN',
          amountBdt: 0.00,
          reason: 'Zero amount test',
        ),
        throwsA(
          isA<InventoryValuationValidationException>().having((e) => e.errorCode, 'errorCode', equals('ERR_INVALID_AMOUNT')),
        ),
      );
    });

    test('9. CSV export generates valid statement with headers and valuation lines', () {
      final client = MobileInventoryValuationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final report = client.generateValuationReport();
      final csv = client.exportValuationCsv(report);

      expect(csv, contains('INVENTORY COST VALUATION & GL RECONCILIATION'));
      expect(csv, contains('PHYSICAL,Total On-Hand Units'));
      expect(csv, contains('PHYSICAL,Total Physical Valuation BDT'));
      expect(csv, contains('GL_1030,GL Book Value BDT'));
      expect(csv, contains('RECONCILIATION,Valuation Variance BDT'));
      expect(csv, contains('RECONCILIATION,Status,BALANCED'));
    });
  });
}
