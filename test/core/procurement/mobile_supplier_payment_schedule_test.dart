// test/core/procurement/mobile_supplier_payment_schedule_test.dart
// Architecture Decision: ADR-0193 (P193).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_supplier_payment_schedule_client.dart';

void main() {
  group('MobileSupplierPaymentScheduleClient Integration Tests (P193)', () {
    late MobileSupplierPaymentScheduleClient managerClient;
    late MobileSupplierPaymentScheduleClient cashierClient;
    late Map<String, MobilePaymentSchedule> scheduleStore;
    late Map<String, MobileSupplierLedgerEntry> ledgerStore;

    setUp(() {
      scheduleStore = {};
      ledgerStore = {};

      // Seed initial AP balance: ৳80,000
      ledgerStore['sup-post-init'] = MobileSupplierLedgerEntry(
        postingId: 'sup-post-init',
        supplierId: 'sup-sq',
        postingType: 'GRN_INVOICE',
        referenceNumber: 'INV-001',
        debitAmount: 0.0,
        creditAmount: 80000.0,
        balanceAfter: 80000.0,
        postedAt: DateTime.now(),
      );

      managerClient = MobileSupplierPaymentScheduleClient(
        tenantId: 'ten-sq',
        branchId: 'br-sq-1',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        scheduleStore: scheduleStore,
        ledgerStore: ledgerStore,
      );

      cashierClient = MobileSupplierPaymentScheduleClient(
        tenantId: 'ten-sq',
        branchId: 'br-sq-1',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        scheduleStore: scheduleStore,
        ledgerStore: ledgerStore,
      );
    });

    test('P193-01: Create and disburse partial & full installments with AP ledger update', () {
      final sps = managerClient.createSchedule(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        dueDate: DateTime.now().add(const Duration(days: 14)),
        plannedAmount: 50000.0,
        priority: 'HIGH',
      );

      expect(sps.status, equals('SCHEDULED'));
      expect(sps.plannedAmount, equals(50000.0));
      expect(sps.remainingAmount, equals(50000.0));

      // 1st Installment: ৳20,000
      final part = managerClient.recordInstallmentPayment(
        scheduleId: sps.scheduleId,
        amountPaid: 20000.0,
        paymentReference: 'EFT-001',
      );
      expect(part.status, equals('PARTIALLY_SETTLED'));
      expect(part.settledAmount, equals(20000.0));
      expect(part.remainingAmount, equals(30000.0));

      // AP Ledger: 80,000 - 20,000 = 60,000
      final e1 = ledgerStore[part.installments.first.ledgerEntryId];
      expect(e1, isNotNull);
      expect(e1!.postingType, equals('PAYMENT'));
      expect(e1.debitAmount, equals(20000.0));
      expect(e1.balanceAfter, equals(60000.0));

      // 2nd Installment: ৳30,000 (final)
      final full = managerClient.recordInstallmentPayment(
        scheduleId: sps.scheduleId,
        amountPaid: 30000.0,
        paymentReference: 'EFT-002',
      );
      expect(full.status, equals('SETTLED'));
      expect(full.settledAmount, equals(50000.0));
      expect(full.remainingAmount, equals(0.0));

      // AP Ledger: 60,000 - 30,000 = 30,000
      final e2 = ledgerStore[full.installments.last.ledgerEntryId];
      expect(e2!.balanceAfter, equals(30000.0));
    });

    test('P193-02: Overpayment guard throws ArgumentError ERR_EXCEEDS_SCHEDULED_DUE', () {
      final sps = managerClient.createSchedule(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        plannedAmount: 10000.0,
      );

      expect(
        () => managerClient.recordInstallmentPayment(
          scheduleId: sps.scheduleId,
          amountPaid: 15000.0,
          paymentReference: 'ERR-OVER',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_EXCEEDS_SCHEDULED_DUE'),
        )),
      );
    });

    test('P193-03: Cannot disburse against a SETTLED schedule', () {
      final sps = managerClient.createSchedule(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        plannedAmount: 5000.0,
      );
      managerClient.recordInstallmentPayment(
        scheduleId: sps.scheduleId,
        amountPaid: 5000.0,
        paymentReference: 'FULL',
      );

      expect(
        () => managerClient.recordInstallmentPayment(
          scheduleId: sps.scheduleId,
          amountPaid: 1000.0,
          paymentReference: 'EXTRA',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_SCHEDULE_NOT_PAYABLE'),
        )),
      );
    });

    test('P193-04: Audited reschedule updates due date and counter', () {
      final sps = managerClient.createSchedule(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        plannedAmount: 20000.0,
      );

      final newDate = DateTime.now().add(const Duration(days: 21));
      final resched = managerClient.reschedule(
        scheduleId: sps.scheduleId,
        newDueDate: newDate,
        reason: 'Monthly alignment',
      );

      expect(resched.dueDate, equals(newDate));
      expect(resched.rescheduleCount, equals(1));
      expect(resched.lastRescheduleReason, equals('Monthly alignment'));
    });

    test('P193-05: Reschedule without reason throws ArgumentError ERR_RESCHEDULE_REASON_REQUIRED', () {
      final sps = managerClient.createSchedule(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        plannedAmount: 10000.0,
      );

      expect(
        () => managerClient.reschedule(
          scheduleId: sps.scheduleId,
          newDueDate: DateTime.now().add(const Duration(days: 14)),
          reason: '   ',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_RESCHEDULE_REASON_REQUIRED'),
        )),
      );
    });

    test('P193-06: Cannot cancel schedule with settled funds', () {
      final sps = managerClient.createSchedule(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        plannedAmount: 20000.0,
      );
      managerClient.recordInstallmentPayment(
        scheduleId: sps.scheduleId,
        amountPaid: 5000.0,
        paymentReference: 'PART',
      );

      expect(
        () => managerClient.cancelSchedule(sps.scheduleId, 'Cancel'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_CANNOT_CANCEL_DISBURSED_SCHEDULE'),
        )),
      );
    });

    test('P193-07: Cashier role is barred with ERR_STAFF_ROLE_DENIED', () {
      expect(
        () => cashierClient.createSchedule(
          supplierId: 'sup-sq',
          supplierName: 'Square Pharma',
          dueDate: DateTime.now().add(const Duration(days: 7)),
          plannedAmount: 10000.0,
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
