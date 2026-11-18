// mobile_payment_status_reconciliation_client_test.dart
// Architecture Decision: ADR-0276 (P276).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_payment_status_reconciliation_client.dart';

void main() {
  group('MobilePaymentStatusReconciliationClient Tests (P276)', () {
    const tenantId = 'ten-dhk-01';
    const branchId = 'br-dhanmondi-01';

    late MobilePaymentStatusReconciliationClient managerClient;
    late MobilePaymentStatusReconciliationClient cashierClient;

    setUp(() {
      managerClient = MobilePaymentStatusReconciliationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_01',
      );

      cashierClient = MobilePaymentStatusReconciliationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'csh_01',
      );
    });

    test('1. Initiate payment and confirm with provider evidence', () {
      final initiated = cashierClient.initiatePayment(
        amountBdt: 1250.0,
        surchargeBdt: 25.0,
        tenderType: 'BKASH',
        providerName: 'bKash Merchant Pay',
        notes: 'Invoice #INV-2026-001',
      );

      expect(initiated.status, equals(MobilePaymentLifecycleStatus.pending));
      expect(initiated.amountBdt, equals(1250.0));
      expect(initiated.surchargeBdt, equals(25.0));
      expect(initiated.totalCollectedBdt, equals(1275.0));

      final confirmed = cashierClient.confirmPayment(
        recordId: initiated.recordId,
        providerReference: 'TRX998877AA',
        providerEvidence: {'wallet': '01700000000', 'channel': 'MFS_ONLINE'},
      );

      expect(confirmed.status, equals(MobilePaymentLifecycleStatus.confirmed));
      expect(confirmed.providerReference, equals('TRX998877AA'));
      expect(confirmed.evidenceHash, startsWith('SIG-'));
      expect(confirmed.verifiedById, equals('csh_01'));
    });

    test('2. Fail payment from PENDING status', () {
      final initiated = cashierClient.initiatePayment(
        amountBdt: 500.0,
        tenderType: 'CARD',
      );

      final failed = cashierClient.failPayment(
        recordId: initiated.recordId,
        failureCode: 'INSUFFICIENT_FUNDS',
        failureReason: 'Card issuer declined transaction',
      );

      expect(failed.status, equals(MobilePaymentLifecycleStatus.failed));
      expect(failed.failureCode, equals('INSUFFICIENT_FUNDS'));
    });

    test('3. Manager can refund or reverse payment, Cashier is strictly denied', () {
      final initiated = managerClient.initiatePayment(
        amountBdt: 800.0,
        tenderType: 'NAGAD',
      );
      managerClient.confirmPayment(
        recordId: initiated.recordId,
        providerReference: 'NAGAD12345',
      );

      // Cashier refund attempt denied
      expect(
        () => cashierClient.refundPayment(
          recordId: initiated.recordId,
          refundAmountBdt: 400.0,
        ),
        throwsA(isA<PaymentStatusPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );

      // Cashier reversal attempt denied
      expect(
        () => cashierClient.reversePayment(
          recordId: initiated.recordId,
          reversalReason: 'Accidental double payment',
        ),
        throwsA(isA<PaymentStatusPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );

      // Manager refund succeeds
      final refunded = managerClient.refundPayment(
        recordId: initiated.recordId,
        refundAmountBdt: 800.0,
        refundReference: 'REF-001',
        refundReason: 'Customer returned damaged medicine',
      );
      expect(refunded.status, equals(MobilePaymentLifecycleStatus.refunded));
      expect(refunded.refundAmountBdt, equals(800.0));
    });

    test('4. Invalid state transitions throw validation exception', () {
      final initiated = managerClient.initiatePayment(
        amountBdt: 350.0,
        tenderType: 'CASH',
      );
      managerClient.failPayment(recordId: initiated.recordId);

      // Cannot confirm a failed payment
      expect(
        () => managerClient.confirmPayment(
          recordId: initiated.recordId,
          providerReference: 'CASH-REC',
        ),
        throwsA(isA<PaymentStatusValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_INVALID_PAYMENT_STATE_TRANSITION'),
        )),
      );
    });

    test('5. Reconcile payment updates status to reconciled', () {
      final initiated = managerClient.initiatePayment(
        amountBdt: 2000.0,
        tenderType: 'BANK_TRANSFER',
      );
      managerClient.confirmPayment(
        recordId: initiated.recordId,
        providerReference: 'EFT-776655',
      );

      final reconciled = managerClient.reconcilePayment(
        recordId: initiated.recordId,
        reconciliationBatchId: 'BATCH-2026-11-18-01',
      );

      expect(reconciled.isReconciled, isTrue);
      expect(reconciled.reconciliationBatchId, equals('BATCH-2026-11-18-01'));
      expect(reconciled.reconciledAt, isNotNull);
    });
  });
}
