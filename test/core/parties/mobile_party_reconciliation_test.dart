// mobile_party_reconciliation_test.dart
// Architecture Decision: ADR-0280 (P280).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/parties/mobile_party_reconciliation_client.dart';

void main() {
  group('MobilePartyReconciliationClient Tests (P280)', () {
    const tenantId = 'ten-dhk-01';

    late MobilePartyReconciliationClient ownerClient;
    late MobilePartyReconciliationClient managerClient;
    late MobilePartyReconciliationClient cashierClient;

    setUp(() {
      ownerClient = MobilePartyReconciliationClient(
        tenantId: tenantId,
        userRole: 'PHARMACY_OWNER',
        userId: 'owner_01',
      );

      managerClient = MobilePartyReconciliationClient(
        tenantId: tenantId,
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_01',
      );

      cashierClient = MobilePartyReconciliationClient(
        tenantId: tenantId,
        userRole: 'CASHIER',
        userId: 'csh_01',
      );
    });

    test('1. Manager reconciles balanced Customer AR cycle with zero variance', () async {
      final res = await managerClient.reconcileCustomerAr(
        customerId: 'cust-101',
        customerName: 'Kazi Nazrul',
        sourceInvoices: 5000.0,
        collections: 3000.0,
        refunds: 500.0,
        recordedDue: 1500.0,
      );

      expect(res.success, isTrue);
      expect(res.status, equals('BALANCED'));
      expect(res.isBalanced, isTrue);
      expect(res.calculatedBalanceBdt, equals('1500.00'));
      expect(res.varianceBdt, equals('0.00'));
      expect(res.discrepancies, isEmpty);
    });

    test('2. Discrepancy detected when customer recorded due drifts from AR ledger', () async {
      final res = await managerClient.reconcileCustomerAr(
        customerId: 'cust-102',
        customerName: 'Jasim Uddin',
        sourceInvoices: 5000.0,
        collections: 3000.0,
        refunds: 500.0,
        recordedDue: 1200.0, // Should be 1500.0
      );

      expect(res.success, isTrue);
      expect(res.status, equals('DISCREPANCY_DETECTED'));
      expect(res.isBalanced, isFalse);
      expect(res.varianceBdt, equals('300.00'));
      expect(res.discrepancies.length, equals(1));
    });

    test('3. Manager attempting auto-adjust is blocked with ERR_AUTO_ADJUST_UNAUTHORIZED', () async {
      expect(
        () => managerClient.reconcileCustomerAr(
          customerId: 'cust-102',
          customerName: 'Jasim Uddin',
          sourceInvoices: 5000.0,
          collections: 3000.0,
          refunds: 500.0,
          recordedDue: 1200.0,
          autoAdjust: true,
          adjustmentReason: 'Routine manager adjustment',
        ),
        throwsA(isA<PartyReconciliationPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_AUTO_ADJUST_UNAUTHORIZED'),
        )),
      );
    });

    test('4. Owner can perform auto-adjustment with reason', () async {
      final res = await ownerClient.reconcileCustomerAr(
        customerId: 'cust-102',
        customerName: 'Jasim Uddin',
        sourceInvoices: 5000.0,
        collections: 3000.0,
        refunds: 500.0,
        recordedDue: 1200.0,
        autoAdjust: true,
        adjustmentReason: 'Compensating variance for unrecorded manual receipt',
      );

      expect(res.success, isTrue);
      expect(res.status, equals('RECONCILED_WITH_ADJUSTMENT'));
      expect(res.isBalanced, isTrue);
      expect(res.varianceBdt, equals('0.00'));
    });

    test('5. Supplier AP reconciliation works for balanced cycle', () async {
      final res = await managerClient.reconcileSupplierAp(
        supplierId: 'sup-201',
        supplierName: 'Square Pharma Depot',
        bills: 25000.0,
        payments: 15000.0,
        creditNotes: 2000.0,
        recordedBalance: 8000.0,
      );

      expect(res.success, isTrue);
      expect(res.status, equals('BALANCED'));
      expect(res.isBalanced, isTrue);
      expect(res.varianceBdt, equals('0.00'));
    });

    test('6. Cashier is strictly denied all reconciliation endpoints', () async {
      expect(
        () => cashierClient.reconcileCustomerAr(
          customerId: 'cust-101',
          customerName: 'Test',
          sourceInvoices: 1000.0,
          collections: 500.0,
          refunds: 0.0,
          recordedDue: 500.0,
        ),
        throwsA(isA<PartyReconciliationPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });
  });
}
