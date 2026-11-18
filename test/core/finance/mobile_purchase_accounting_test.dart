// mobile_purchase_accounting_test.dart
// Architecture Decision: ADR-0284 (P284).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_purchase_accounting_client.dart';

void main() {
  group('MobilePurchaseAccountingClient P284 Unit Tests', () {
    const tenantId = 'ten_square_01';
    const branchId = 'br_dhanmondi_01';

    test('1. Branch Manager posts GRN invoice recognition capitalizes inventory and records AP', () {
      final client = MobilePurchaseAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr_mgr_01',
      );

      final posting = client.postGrnInvoiceRecognition(
        grnId: 'grn_001',
        supplierId: 'sup_beximco_01',
        supplierName: 'Beximco Pharmaceuticals Ltd',
        totalCostBdt: 50000.0,
        paidCashBdt: 10000.0,
        paidBankBdt: 0.0,
      );

      expect(posting.status, equals('POSTED'));
      expect(posting.totalInventoryCostBdt, equals(50000.0));
      expect(posting.settledCashBdt, equals(10000.0));
      expect(posting.liabilityApBdt, equals(40000.0)); // 50000 - 10000
      expect(posting.isOperatingExpense, isFalse); // Invariant: Not an operating expense
      expect(posting.isReversed, isFalse);
    });

    test('2. Finance Officer disburses supplier payment settling accounts payable', () {
      final client = MobilePurchaseAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr_fin_01',
      );

      final pmt = client.postSupplierPayment(
        supplierId: 'sup_square_01',
        supplierName: 'Square Pharmaceuticals Ltd',
        paymentAmountBdt: 25000.0,
        paymentMode: 'BANK',
      );

      expect(pmt.status, equals('POSTED'));
      expect(pmt.postingType, equals('SUPPLIER_PAYMENT'));
      expect(pmt.settledBankBdt, equals(25000.0));
      expect(pmt.isOperatingExpense, isFalse);
    });

    test('3. Idempotent key replay returns existing posting without duplicate AP entry', () {
      final client = MobilePurchaseAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr_mgr_01',
      );

      final p1 = client.postGrnInvoiceRecognition(
        supplierName: 'Incepta Pharma',
        totalCostBdt: 30000.0,
        idempotencyKey: 'idem_grn_abc_999',
      );
      expect(p1.isIdempotentReplay, isFalse);

      final p2 = client.postGrnInvoiceRecognition(
        supplierName: 'Incepta Pharma',
        totalCostBdt: 30000.0,
        idempotencyKey: 'idem_grn_abc_999',
      );
      expect(p2.isIdempotentReplay, isTrue);
      expect(p2.postingId, equals(p1.postingId));
    });

    test('4. Cashier is strictly denied from disbursing supplier payment', () {
      final client = MobilePurchaseAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr_cashier_01',
      );

      expect(
        () => client.postSupplierPayment(
          supplierId: 'sup_beximco_01',
          supplierName: 'Beximco',
          paymentAmountBdt: 5000.0,
        ),
        throwsA(isA<PurchaseAccountingPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_SUPPLIER_PAYMENT_UNAUTHORIZED'),
        )),
      );
    });

    test('5. Pharmacy Owner can reverse purchase accounting with valid reason', () {
      final client = MobilePurchaseAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final posting = client.postGrnInvoiceRecognition(
        supplierName: 'Renata Ltd',
        totalCostBdt: 15000.0,
      );

      final result = client.reversePurchaseAccounting(
        posting.postingId,
        'Damaged shipment returned upon depot inspection',
      );

      expect(result['success'], isTrue);
      expect(result['status'], equals('REVERSED'));
    });

    test('6. Summary confirms zero operating expense impact from raw inventory purchases', () {
      final client = MobilePurchaseAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      // GRN 1: 50,000 cost, 10,000 cash paid, 40,000 AP
      client.postGrnInvoiceRecognition(
        supplierName: 'Square Pharma',
        totalCostBdt: 50000.0,
        paidCashBdt: 10000.0,
      );

      // Supplier Payment: 15,000 bank paid
      client.postSupplierPayment(
        supplierId: 'sup_square',
        supplierName: 'Square Pharma',
        paymentAmountBdt: 15000.0,
      );

      final summary = client.getPurchaseSummary();
      expect(summary.totalInventoryCapitalizedBdt, equals(50000.0));
      expect(summary.totalApRecognizedBdt, equals(40000.0));
      expect(summary.totalSupplierPaymentsDisbursedBdt, equals(15000.0));
      expect(summary.netOutstandingApLiabilityBdt, equals(25000.0)); // 40000 - 15000
      expect(summary.totalOperatingExpensesBdt, equals(0.0)); // CRITICAL INVARIANT VERIFIED
      expect(summary.isOperatingExpense, isFalse);
    });
  });
}
