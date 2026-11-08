// test/core/procurement/mobile_purchase_return_test.dart
// Architecture Decision: ADR-0191 (P191).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_purchase_return_client.dart';

void main() {
  group('MobilePurchaseReturnClient Integration Tests (P191)', () {
    late MobilePurchaseReturnClient managerClient;
    late MobilePurchaseReturnClient cashierClient;
    late Map<String, MobilePurchaseReturn> returnStore;
    late Map<String, MobileBatchStock> batchStore;
    late Map<String, MobileSupplierLedgerEntry> ledgerStore;

    setUp(() {
      returnStore = {};
      batchStore = {};
      ledgerStore = {};

      // Seed batch stock: 100 units @ ৳450.00
      batchStore['bat-ins-1'] = MobileBatchStock(
        batchId: 'bat-ins-1',
        batchNumber: 'INSR-BATCH-2026',
        productId: 'med-ins-1',
        availableQuantity: 100,
        costPerUnit: 450.0,
        status: 'ACTIVE',
      );

      // Seed initial AP balance: ৳50,000
      ledgerStore['sup-post-init'] = MobileSupplierLedgerEntry(
        postingId: 'sup-post-init',
        supplierId: 'sup-sq',
        postingType: 'INVOICE_BILL',
        referenceNumber: 'INV-001',
        debitAmount: 0.0,
        creditAmount: 50000.0,
        balanceAfter: 50000.0,
        postedAt: DateTime.now(),
      );

      managerClient = MobilePurchaseReturnClient(
        tenantId: 'ten-sq',
        branchId: 'br-sq-1',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        returnStore: returnStore,
        batchStore: batchStore,
        ledgerStore: ledgerStore,
      );

      cashierClient = MobilePurchaseReturnClient(
        tenantId: 'ten-sq',
        branchId: 'br-sq-1',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        returnStore: returnStore,
        batchStore: batchStore,
        ledgerStore: ledgerStore,
      );
    });

    test('P191-01: Create and post purchase return decrements batch and creates AP debit note', () {
      final pret = managerClient.createPurchaseReturn(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        goodsReceiptId: 'grn-1',
        purchaseOrderId: 'po-1',
        returnReason: 'DAMAGED_DELIVERY',
        items: [
          MobilePurchaseReturnItem(
            productId: 'med-ins-1',
            productBrandName: 'Insulin Regular',
            batchStockId: 'bat-ins-1',
            batchNumber: 'INSR-BATCH-2026',
            returnQuantity: 20,
            unitCost: 450.0,
          ),
        ],
      );

      expect(pret.status, equals('DRAFT'));
      expect(pret.totalReturnQuantity, equals(20));
      expect(pret.totalDebitAmount, equals(9000.0));

      final posted = managerClient.postPurchaseReturn(pret.returnId);
      expect(posted.status, equals('POSTED_DEBIT_NOTE'));
      expect(posted.postedAt, isNotNull);

      // Verify batch decremented: 100 - 20 = 80
      expect(batchStore['bat-ins-1']!.availableQuantity, equals(80));

      // Verify AP ledger: 50,000 - 9,000 = 41,000
      final ledger = ledgerStore[posted.debitLedgerEntryId];
      expect(ledger, isNotNull);
      expect(ledger!.postingType, equals('RETURN_DEBIT_NOTE'));
      expect(ledger.debitAmount, equals(9000.0));
      expect(ledger.balanceAfter, equals(41000.0));
    });

    test('P191-02: Insufficient stock throws ArgumentError ERR_INSUFFICIENT_STOCK_FOR_RETURN', () {
      expect(
        () => managerClient.createPurchaseReturn(
          supplierId: 'sup-sq',
          supplierName: 'Square Pharma',
          items: [
            MobilePurchaseReturnItem(
              productId: 'med-ins-1',
              batchStockId: 'bat-ins-1',
              returnQuantity: 150, // Available: 100
              unitCost: 450.0,
            ),
          ],
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_INSUFFICIENT_STOCK_FOR_RETURN'),
        )),
      );
    });

    test('P191-03: Complete batch return sets batch status to DEPLETED', () {
      final pret = managerClient.createPurchaseReturn(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        items: [
          MobilePurchaseReturnItem(
            productId: 'med-ins-1',
            batchStockId: 'bat-ins-1',
            returnQuantity: 100, // 100% of stock
            unitCost: 450.0,
          ),
        ],
        autoPost: true,
      );

      expect(pret.status, equals('POSTED_DEBIT_NOTE'));
      expect(batchStore['bat-ins-1']!.availableQuantity, equals(0));
      expect(batchStore['bat-ins-1']!.status, equals('DEPLETED'));
    });

    test('P191-04: Cancel draft return transitions status to CANCELLED', () {
      final pret = managerClient.createPurchaseReturn(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        items: [
          MobilePurchaseReturnItem(
            productId: 'med-ins-1',
            batchStockId: 'bat-ins-1',
            returnQuantity: 10,
            unitCost: 450.0,
          ),
        ],
      );

      final cancelled = managerClient.cancelPurchaseReturn(pret.returnId, 'Wrong vendor');
      expect(cancelled.status, equals('CANCELLED'));
      expect(cancelled.reasonNotes, contains('Wrong vendor'));
      expect(batchStore['bat-ins-1']!.availableQuantity, equals(100)); // Unchanged
    });

    test('P191-05: Cannot cancel posted return throws StateError ERR_CANNOT_CANCEL_POSTED_RETURN', () {
      final pret = managerClient.createPurchaseReturn(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        items: [
          MobilePurchaseReturnItem(
            productId: 'med-ins-1',
            batchStockId: 'bat-ins-1',
            returnQuantity: 10,
            unitCost: 450.0,
          ),
        ],
        autoPost: true,
      );

      expect(
        () => managerClient.cancelPurchaseReturn(pret.returnId, 'Should fail'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_CANNOT_CANCEL_POSTED_RETURN'),
        )),
      );
    });

    test('P191-06: Cashier role is barred with ERR_STAFF_ROLE_DENIED', () {
      expect(
        () => cashierClient.createPurchaseReturn(
          supplierId: 'sup-sq',
          supplierName: 'Square Pharma',
          items: [
            MobilePurchaseReturnItem(
              productId: 'med-ins-1',
              batchStockId: 'bat-ins-1',
              returnQuantity: 5,
              unitCost: 450.0,
            ),
          ],
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });
  });
}
