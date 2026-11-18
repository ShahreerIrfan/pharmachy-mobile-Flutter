// mobile_customer_due_collection_test.dart
// Architecture Decision: ADR-0277 (P277).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_customer_due_collection_client.dart';

void main() {
  group('MobileCustomerDueCollectionClient Tests (P277)', () {
    const tenantId = 'ten-dhk-01';
    const branchId = 'br-dhanmondi-01';

    late MobileCustomerDueCollectionClient ownerClient;
    late MobileCustomerDueCollectionClient cashierClient;

    setUp(() {
      ownerClient = MobileCustomerDueCollectionClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'owner_01',
      );

      cashierClient = MobileCustomerDueCollectionClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'csh_01',
      );
    });

    test('1. Owner can list dues and inspect summary metrics', () {
      ownerClient.seedDueRecord(MobileOutstandingDueDto(
        dueId: 'DUE-001',
        tenantId: tenantId,
        branchId: branchId,
        customerName: 'Rahim Uddin',
        customerPhone: '01711000111',
        invoiceNumber: 'INV-2026-001',
        totalDueBdt: 1500.0,
        remainingDueBdt: 1500.0,
        status: 'OUTSTANDING',
      ));

      ownerClient.seedDueRecord(MobileOutstandingDueDto(
        dueId: 'DUE-002',
        tenantId: tenantId,
        branchId: branchId,
        customerName: 'Karim Ullah',
        customerPhone: '01811000222',
        invoiceNumber: 'INV-2026-002',
        totalDueBdt: 2000.0,
        remainingDueBdt: 500.0,
        status: 'PARTIAL',
      ));

      final dues = ownerClient.listOutstandingDues();
      expect(dues.length, equals(2));

      final summary = ownerClient.getDueSummary();
      expect(summary.totalOutstandingDueBdt, equals(2000.0));
      expect(summary.totalDueAccountsCount, equals(2));
    });

    test('2. Successful partial and full due collection with digital receipt', () {
      ownerClient.seedDueRecord(MobileOutstandingDueDto(
        dueId: 'DUE-003',
        tenantId: tenantId,
        branchId: branchId,
        customerName: 'Shakil Ahmed',
        customerPhone: '01911000333',
        invoiceNumber: 'INV-2026-003',
        totalDueBdt: 1000.0,
        remainingDueBdt: 1000.0,
      ));

      // Partial collection of 400 BDT via bKash
      final partialReceipt = ownerClient.recordDueCollection(
        dueId: 'DUE-003',
        amountBdt: 400.0,
        tenderType: 'BKASH',
        gatewayReference: 'TRX998877AA',
        notes: 'Partial installment',
      );

      expect(partialReceipt.amountCollectedBdt, equals(400.0));
      expect(partialReceipt.remainingDueBdt, equals(600.0));
      expect(partialReceipt.dueStatus, equals('PARTIAL'));
      expect(partialReceipt.receiptNumber, startsWith('REC-DUE-'));

      // Settle remaining 600 BDT via Cash
      final settleReceipt = ownerClient.recordDueCollection(
        dueId: 'DUE-003',
        amountBdt: 600.0,
        tenderType: 'CASH',
      );

      expect(settleReceipt.amountCollectedBdt, equals(600.0));
      expect(settleReceipt.remainingDueBdt, equals(0.0));
      expect(settleReceipt.dueStatus, equals('SETTLED'));
    });

    test('3. Overpayment is strictly rejected (ERR_DUE_OVERPAYMENT)', () {
      ownerClient.seedDueRecord(MobileOutstandingDueDto(
        dueId: 'DUE-004',
        tenantId: tenantId,
        branchId: branchId,
        customerName: 'Tanvir Hossain',
        customerPhone: '01611000444',
        invoiceNumber: 'INV-2026-004',
        totalDueBdt: 500.0,
        remainingDueBdt: 500.0,
      ));

      expect(
        () => ownerClient.recordDueCollection(
          dueId: 'DUE-004',
          amountBdt: 600.0,
          tenderType: 'CASH',
        ),
        throwsA(isA<MobileDueValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_DUE_OVERPAYMENT'),
        )),
      );
    });

    test('4. Settled due record rejects further collections (ERR_DUE_ALREADY_SETTLED)', () {
      ownerClient.seedDueRecord(MobileOutstandingDueDto(
        dueId: 'DUE-005',
        tenantId: tenantId,
        branchId: branchId,
        customerName: 'Jannat Ara',
        customerPhone: '01511000555',
        invoiceNumber: 'INV-2026-005',
        totalDueBdt: 300.0,
        remainingDueBdt: 0.0,
        status: 'SETTLED',
      ));

      expect(
        () => ownerClient.recordDueCollection(
          dueId: 'DUE-005',
          amountBdt: 100.0,
          tenderType: 'CASH',
        ),
        throwsA(isA<MobileDueValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_DUE_ALREADY_SETTLED'),
        )),
      );
    });

    test('5. Offline attempt is rejected (ERR_OFFLINE_UNAVAILABLE)', () {
      ownerClient.seedDueRecord(MobileOutstandingDueDto(
        dueId: 'DUE-006',
        tenantId: tenantId,
        branchId: branchId,
        customerName: 'Kamal Mia',
        customerPhone: '01711000666',
        invoiceNumber: 'INV-2026-006',
        totalDueBdt: 800.0,
        remainingDueBdt: 800.0,
      ));

      expect(
        () => ownerClient.recordDueCollection(
          dueId: 'DUE-006',
          amountBdt: 200.0,
          isOffline: true,
        ),
        throwsA(isA<MobileDueOfflineException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_OFFLINE_UNAVAILABLE'),
        )),
      );
    });

    test('6. Role enforcement: Cashier is strictly denied (ERR_STAFF_ROLE_DENIED)', () {
      expect(
        () => cashierClient.listOutstandingDues(),
        throwsA(isA<MobileDuePermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );

      expect(
        () => cashierClient.recordDueCollection(
          dueId: 'DUE-001',
          amountBdt: 100.0,
        ),
        throwsA(isA<MobileDuePermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });

    test('7. Digital tenders require valid gateway transaction reference', () {
      ownerClient.seedDueRecord(MobileOutstandingDueDto(
        dueId: 'DUE-007',
        tenantId: tenantId,
        branchId: branchId,
        customerName: 'Farhana Kabir',
        customerPhone: '01711000777',
        invoiceNumber: 'INV-2026-007',
        totalDueBdt: 700.0,
        remainingDueBdt: 700.0,
      ));

      // Missing gateway reference on Nagad
      expect(
        () => ownerClient.recordDueCollection(
          dueId: 'DUE-007',
          amountBdt: 300.0,
          tenderType: 'NAGAD',
          gatewayReference: '',
        ),
        throwsA(isA<MobileDueValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_MISSING_GATEWAY_REFERENCE'),
        )),
      );
    });
  });
}
