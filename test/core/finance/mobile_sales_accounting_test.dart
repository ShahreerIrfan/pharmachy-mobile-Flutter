// mobile_sales_accounting_test.dart
// Architecture Decision: ADR-0283 (P283).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_sales_accounting_client.dart';

void main() {
  group('MobileSalesAccountingClient P283 Unit Tests', () {
    const tenantId = 'ten_square_01';
    const branchId = 'br_dhanmondi_01';

    test('1. Cashier posts valid cash sales accounting with COGS and profit calculation', () {
      final client = MobileSalesAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr_cashier_01',
      );

      final posting = client.postSaleAccounting(
        invoiceNumber: 'INV-202611-001',
        grossSalesBdt: 1200.0,
        discountBdt: 100.0,
        taxVatBdt: 50.0,
        netSettledBdt: 1150.0, // 1200 - 100 + 50
        receivableDueBdt: 0.0,
        totalCogsBdt: 800.0,
      );

      expect(posting.status, equals('POSTED'));
      expect(posting.grossSalesBdt, equals(1200.0));
      expect(posting.discountBdt, equals(100.0));
      expect(posting.totalCogsBdt, equals(800.0));
      expect(posting.grossProfitBdt, equals(300.0)); // (1200 - 100) - 800
      expect(posting.grossMarginPct, closeTo(27.27, 0.05));
      expect(posting.isReversed, isFalse);
    });

    test('2. Due credit sale records receivable without crashing profit margin', () {
      final client = MobileSalesAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr_mgr_01',
      );

      final posting = client.postSaleAccounting(
        invoiceNumber: 'INV-202611-002',
        grossSalesBdt: 5000.0,
        discountBdt: 0.0,
        netSettledBdt: 0.0,
        receivableDueBdt: 5000.0,
        totalCogsBdt: 3500.0,
      );

      expect(posting.receivableDueBdt, equals(5000.0));
      expect(posting.netSettledBdt, equals(0.0));
      expect(posting.grossProfitBdt, equals(1500.0));
      expect(posting.grossMarginPct, equals(30.0));
    });

    test('3. Idempotent key replay returns existing posting without duplicate journal allocation', () {
      final client = MobileSalesAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr_cashier_01',
      );

      final p1 = client.postSaleAccounting(
        invoiceNumber: 'INV-IDEM-001',
        grossSalesBdt: 2000.0,
        totalCogsBdt: 1400.0,
        idempotencyKey: 'idem_sale_abc_123',
      );
      expect(p1.isIdempotentReplay, isFalse);

      final p2 = client.postSaleAccounting(
        invoiceNumber: 'INV-IDEM-001',
        grossSalesBdt: 2000.0,
        totalCogsBdt: 1400.0,
        idempotencyKey: 'idem_sale_abc_123',
      );
      expect(p2.isIdempotentReplay, isTrue);
      expect(p2.postingId, equals(p1.postingId));
    });

    test('4. Pharmacy Owner can reverse sales accounting with mandatory reason', () {
      final client = MobileSalesAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      final posting = client.postSaleAccounting(
        invoiceNumber: 'INV-REV-001',
        grossSalesBdt: 1000.0,
        totalCogsBdt: 600.0,
      );

      final result = client.reverseSaleAccounting(
        posting.postingId,
        'Customer returned unopened prescription within 30 minutes',
      );

      expect(result['success'], isTrue);
      expect(result['status'], equals('REVERSED'));
    });

    test('5. Cashier role is strictly denied from reversing sales accounting', () {
      final cashierClient = MobileSalesAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr_cashier_01',
      );

      final posting = cashierClient.postSaleAccounting(
        invoiceNumber: 'INV-CASH-001',
        grossSalesBdt: 1500.0,
        totalCogsBdt: 1000.0,
      );

      expect(
        () => cashierClient.reverseSaleAccounting(posting.postingId, 'Cashier trying to reverse'),
        throwsA(isA<SalesAccountingPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_SALES_ACCOUNTING_REVERSE_UNAUTHORIZED'),
        )),
      );
    });

    test('6. Multi-branch profitability summary aggregates only active sales', () {
      final ownerClient = MobileSalesAccountingClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      // Sale 1: Gross 1000, Disc 100, COGS 600 -> Profit 300
      ownerClient.postSaleAccounting(
        invoiceNumber: 'INV-SUM-001',
        grossSalesBdt: 1000.0,
        discountBdt: 100.0,
        totalCogsBdt: 600.0,
      );

      // Sale 2: Gross 2000, Disc 0, COGS 1200 -> Profit 800
      final p2 = ownerClient.postSaleAccounting(
        invoiceNumber: 'INV-SUM-002',
        grossSalesBdt: 2000.0,
        discountBdt: 0.0,
        totalCogsBdt: 1200.0,
      );

      // Reverse Sale 2
      ownerClient.reverseSaleAccounting(p2.postingId, 'Voided mistake');

      final summary = ownerClient.getProfitabilitySummary();
      expect(summary.totalSalesCount, equals(1)); // Only Sale 1 active
      expect(summary.grossSalesBdt, equals(1000.0));
      expect(summary.totalDiscountBdt, equals(100.0));
      expect(summary.netSalesBdt, equals(900.0));
      expect(summary.totalCogsBdt, equals(600.0));
      expect(summary.grossProfitBdt, equals(300.0));
      expect(summary.isProfitable, isTrue);
    });
  });
}
