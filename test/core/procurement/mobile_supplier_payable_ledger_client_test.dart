// mobile_supplier_payable_ledger_client_test.dart
// Architecture Decision: ADR-0272 (P272).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_supplier_payable_ledger_client.dart';

void main() {
  group('MobileSupplierPayableLedgerClient Tests (P272)', () {
    const tenantId = 'ten-p272-test';
    const supplierId = 'sup-001';

    Map<String, dynamic> createSupplierStore() => {
          supplierId: {
            'supplier_id': supplierId,
            'tenant_id': tenantId,
            'name': 'Beximco Pharmaceuticals Ltd.',
            'current_balance': 0.0,
          }
        };

    test('Cashier is denied viewing and posting to AP ledger', () {
      final client = MobileSupplierPayableLedgerClient(
        tenantId: tenantId,
        userRole: 'CASHIER',
        supplierStore: createSupplierStore(),
      );

      expect(client.canView, isFalse);
      expect(client.canPost, isFalse);

      expect(
        () => client.listEntries(supplierId),
        throwsA(isA<LedgerPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          'ERR_STAFF_ROLE_DENIED',
        )),
      );

      expect(
        () => client.postEntry(
          supplierId: supplierId,
          postingType: 'PAYMENT',
          referenceNumber: 'PAY-100',
          debitAmount: 1000.0,
        ),
        throwsA(isA<LedgerPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          'ERR_STAFF_ROLE_DENIED',
        )),
      );
    });

    test('Pharmacy Owner executes full chronological AP cycle and reconciles balance', () {
      final store = createSupplierStore();
      final client = MobileSupplierPayableLedgerClient(
        tenantId: tenantId,
        userRole: 'PHARMACY_OWNER',
        supplierStore: store,
      );

      // 1. Goods Received Note (Liability Credit of 5000 BDT)
      final p1 = client.postEntry(
        supplierId: supplierId,
        postingType: 'GRN_INVOICE',
        referenceNumber: 'GRN-9001',
        creditAmount: 5000.0,
      );
      expect(p1.balanceAfter, 5000.0);
      expect(store[supplierId]['current_balance'], 5000.0);

      // 2. Partial Payment (Liability Debit of 2000 BDT)
      final p2 = client.postEntry(
        supplierId: supplierId,
        postingType: 'PAYMENT',
        referenceNumber: 'PAY-3001',
        debitAmount: 2000.0,
      );
      expect(p2.balanceAfter, 3000.0);
      expect(store[supplierId]['current_balance'], 3000.0);

      // 3. Supplier Credit Note (Liability Debit of 500 BDT)
      final p3 = client.postEntry(
        supplierId: supplierId,
        postingType: 'SUPPLIER_CREDIT_NOTE',
        referenceNumber: 'SCN-101',
        debitAmount: 500.0,
      );
      expect(p3.balanceAfter, 2500.0);
      expect(store[supplierId]['current_balance'], 2500.0);

      // 4. Reconcile
      final rec = client.reconcile(supplierId);
      expect(rec.isReconciled, isTrue);
      expect(rec.totalCredits, 5000.0);
      expect(rec.totalDebits, 2500.0);
      expect(rec.calculatedClosing, 2500.0);
      expect(rec.currentBalance, 2500.0);
      expect(rec.totalPostings, 3);
    });

    test('Compensating reversal inverts posting and updates balance', () {
      final store = createSupplierStore();
      final client = MobileSupplierPayableLedgerClient(
        tenantId: tenantId,
        userRole: 'PHARMACY_OWNER',
        supplierStore: store,
      );

      // Post invoice 1000 BDT
      final p1 = client.postEntry(
        supplierId: supplierId,
        postingType: 'INVOICE',
        referenceNumber: 'INV-400',
        creditAmount: 1000.0,
      );
      expect(store[supplierId]['current_balance'], 1000.0);

      // Reverse invoice
      final rev = client.reverseEntry(
        supplierId: supplierId,
        postingId: p1.postingId,
        reason: 'Duplicate invoice billed in error',
      );
      expect(rev.debitAmount, 1000.0);
      expect(rev.creditAmount, 0.0);
      expect(store[supplierId]['current_balance'], 0.0);

      // Attempt second reversal fails
      expect(
        () => client.reverseEntry(
          supplierId: supplierId,
          postingId: p1.postingId,
          reason: 'Attempt double reverse',
        ),
        throwsA(isA<LedgerValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          'ERR_ALREADY_REVERSED',
        )),
      );
    });
  });
}
