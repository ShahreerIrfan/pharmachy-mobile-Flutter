// mobile_vendor_payment_allocation_client_test.dart
// Architecture Decision: ADR-0273 (P273).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_vendor_payment_allocation_client.dart';

void main() {
  group('MobileVendorPaymentAllocationClient Tests', () {
    const tenantId = 'tenant_dhaka_01';
    const supplierId = 'sup_square_pharma';

    late MobileVendorPaymentAllocationClient client;

    setUp(() {
      client = MobileVendorPaymentAllocationClient(
        tenantId: tenantId,
        branchId: 'branch_main',
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_01',
      );

      client.registerInvoice(
        MobileInvoiceBalanceDto(
          invoiceId: 'inv_001',
          invoiceNumber: 'INV-2026-001',
          supplierId: supplierId,
          totalAmount: 5000.0,
        ),
      );

      client.registerInvoice(
        MobileInvoiceBalanceDto(
          invoiceId: 'inv_002',
          invoiceNumber: 'INV-2026-002',
          supplierId: supplierId,
          totalAmount: 3000.0,
        ),
      );
    });

    test('1. Successful allocation across invoices with unapplied advance balance', () {
      final payment = client.disburseAndAllocate(
        supplierId: supplierId,
        totalAmount: 10000.0,
        paymentMethod: 'BANK_TRANSFER',
        referenceNumber: 'TXN-998877',
        idempotencyKey: 'idem_key_001',
        allocations: [
          {'invoice_id': 'inv_001', 'allocated_amount': 4000.0, 'notes': 'Partial pay'},
          {'invoice_id': 'inv_002', 'allocated_amount': 3000.0, 'notes': 'Full settlement'},
        ],
      );

      expect(payment.totalAmount, equals(10000.0));
      expect(payment.allocatedAmount, equals(7000.0));
      expect(payment.unallocatedAmount, equals(3000.0));
      expect(payment.status, equals('PARTIALLY_ALLOCATED'));
      expect(payment.allocations.length, equals(2));
      expect(payment.allocations[0].remainingUnpaidAmount, equals(1000.0));
      expect(payment.allocations[1].remainingUnpaidAmount, equals(0.0));
    });

    test('2. Anti-overpayment: Reject allocation exceeding invoice unpaid balance', () {
      expect(
        () => client.disburseAndAllocate(
          supplierId: supplierId,
          totalAmount: 6000.0,
          allocations: [
            {'invoice_id': 'inv_001', 'allocated_amount': 5500.0},
          ],
        ),
        throwsA(isA<VendorPaymentValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_ALLOCATION_EXCEEDS_INVOICE_BALANCE'),
        )),
      );
    });

    test('3. Anti-overpayment: Reject allocations exceeding total payment disbursement', () {
      expect(
        () => client.disburseAndAllocate(
          supplierId: supplierId,
          totalAmount: 4000.0,
          allocations: [
            {'invoice_id': 'inv_001', 'allocated_amount': 3000.0},
            {'invoice_id': 'inv_002', 'allocated_amount': 2000.0},
          ],
        ),
        throwsA(isA<VendorPaymentValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_TOTAL_ALLOCATION_EXCEEDS_PAYMENT'),
        )),
      );
    });

    test('4. Role enforcement: Cashier is denied disbursement and allocation', () {
      final cashierClient = MobileVendorPaymentAllocationClient(
        tenantId: tenantId,
        userRole: 'CASHIER',
        userId: 'cashier_01',
      );

      expect(
        () => cashierClient.disburseAndAllocate(
          supplierId: supplierId,
          totalAmount: 1000.0,
          allocations: [],
        ),
        throwsA(isA<VendorPaymentPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });

    test('5. Idempotent replay returns same payment without double deduction', () {
      final p1 = client.disburseAndAllocate(
        supplierId: supplierId,
        totalAmount: 2000.0,
        idempotencyKey: 'idem_replay_test',
        allocations: [
          {'invoice_id': 'inv_001', 'allocated_amount': 1000.0},
        ],
      );

      final p2 = client.disburseAndAllocate(
        supplierId: supplierId,
        totalAmount: 2000.0,
        idempotencyKey: 'idem_replay_test',
        allocations: [
          {'invoice_id': 'inv_001', 'allocated_amount': 1000.0},
        ],
      );

      expect(p1.paymentId, equals(p2.paymentId));
      expect(p1.paymentNumber, equals(p2.paymentNumber));
    });
  });
}
