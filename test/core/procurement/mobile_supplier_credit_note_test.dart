// test/core/procurement/mobile_supplier_credit_note_test.dart
// Architecture Decision: ADR-0192 (P192).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_supplier_credit_note_client.dart';

void main() {
  group('MobileSupplierCreditNoteClient Integration Tests (P192)', () {
    late MobileSupplierCreditNoteClient managerClient;
    late MobileSupplierCreditNoteClient cashierClient;
    late Map<String, MobileSupplierCreditNote> noteStore;
    late Map<String, MobileSupplierLedgerEntry> ledgerStore;

    setUp(() {
      noteStore = {};
      ledgerStore = {};

      // Seed initial AP balance: ৳30,000
      ledgerStore['sup-post-init'] = MobileSupplierLedgerEntry(
        postingId: 'sup-post-init',
        supplierId: 'sup-sq',
        postingType: 'GRN_INVOICE',
        referenceNumber: 'INV-001',
        debitAmount: 0.0,
        creditAmount: 30000.0,
        balanceAfter: 30000.0,
        postedAt: DateTime.now(),
      );

      managerClient = MobileSupplierCreditNoteClient(
        tenantId: 'ten-sq',
        branchId: 'br-sq-1',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        noteStore: noteStore,
        ledgerStore: ledgerStore,
      );

      cashierClient = MobileSupplierCreditNoteClient(
        tenantId: 'ten-sq',
        branchId: 'br-sq-1',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        noteStore: noteStore,
        ledgerStore: ledgerStore,
      );
    });

    test('P192-01: Create and post credit note reduces AP balance', () {
      final scn = managerClient.createCreditNote(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        vendorRef: 'VCN-MOB-001',
        reason: 'PRICE_DIFFERENCE',
        items: [
          MobileSupplierCreditNoteItem(
            productId: 'med-1',
            productName: 'Seclo 20mg',
            quantity: 100,
            unitCreditRate: 0.50,
            taxPercentage: 5.0,
          ),
        ],
      );

      expect(scn.status, equals('DRAFT'));
      expect(scn.subtotalAmount, equals(50.0));
      expect(scn.taxAmount, equals(2.50));
      expect(scn.totalCreditAmount, equals(52.50));

      final posted = managerClient.postCreditNote(scn.noteId);
      expect(posted.status, equals('POSTED'));
      expect(posted.postedAt, isNotNull);

      // Verify AP ledger: 30,000 - 52.50 = 29,947.50
      final ledger = ledgerStore[posted.debitLedgerEntryId];
      expect(ledger, isNotNull);
      expect(ledger!.postingType, equals('SUPPLIER_CREDIT_NOTE'));
      expect(ledger.debitAmount, equals(52.50));
      expect(ledger.balanceAfter, equals(29947.50));
    });

    test('P192-02: Non-destructive reversal restores AP balance', () {
      final scn = managerClient.createCreditNote(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        vendorRef: 'VCN-MOB-REV',
        reason: 'VOLUME_REBATE',
        explicitTotal: 5000.0,
        autoPost: true,
      );

      expect(scn.status, equals('POSTED'));
      // AP balance after posting: 30,000 - 5,000 = 25,000

      final reversed = managerClient.reverseCreditNote(
        scn.noteId,
        'Applied to wrong billing entity',
      );

      expect(reversed.status, equals('REVERSED'));
      expect(reversed.reversalReason, equals('Applied to wrong billing entity'));
      expect(reversed.reversalPostedAt, isNotNull);

      // Verify AP ledger: 25,000 + 5,000 = 30,000
      final revEntry = ledgerStore[reversed.reversalLedgerEntryId];
      expect(revEntry, isNotNull);
      expect(revEntry!.postingType, equals('CREDIT_NOTE_REVERSAL'));
      expect(revEntry.creditAmount, equals(5000.0));
      expect(revEntry.balanceAfter, equals(30000.0));
    });

    test('P192-03: Duplicate vendor reference throws ArgumentError ERR_DUPLICATE_CREDIT_NOTE_REF', () {
      managerClient.createCreditNote(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        vendorRef: 'VCN-DUP',
        explicitTotal: 100.0,
      );

      expect(
        () => managerClient.createCreditNote(
          supplierId: 'sup-sq',
          supplierName: 'Square Pharma',
          vendorRef: 'VCN-DUP',
          explicitTotal: 200.0,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_DUPLICATE_CREDIT_NOTE_REF'),
        )),
      );
    });

    test('P192-04: Reversal requires mandatory reason', () {
      final scn = managerClient.createCreditNote(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        vendorRef: 'VCN-NOREAS',
        explicitTotal: 100.0,
        autoPost: true,
      );

      expect(
        () => managerClient.reverseCreditNote(scn.noteId, '   '),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_REVERSAL_REASON_REQUIRED'),
        )),
      );
    });

    test('P192-05: Cannot reverse unposted draft credit note', () {
      final scn = managerClient.createCreditNote(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        vendorRef: 'VCN-DRAFT',
        explicitTotal: 100.0,
      );

      expect(
        () => managerClient.reverseCreditNote(scn.noteId, 'Should fail'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_CANNOT_REVERSE_UNPOSTED'),
        )),
      );
    });

    test('P192-06: Cannot cancel posted credit note directly', () {
      final scn = managerClient.createCreditNote(
        supplierId: 'sup-sq',
        supplierName: 'Square Pharma',
        vendorRef: 'VCN-POSTED-CAN',
        explicitTotal: 100.0,
        autoPost: true,
      );

      expect(
        () => managerClient.cancelCreditNote(scn.noteId, 'Direct cancel'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_CANNOT_CANCEL_POSTED_CREDIT_NOTE'),
        )),
      );
    });

    test('P192-07: Cashier role is barred with ERR_STAFF_ROLE_DENIED', () {
      expect(
        () => cashierClient.createCreditNote(
          supplierId: 'sup-sq',
          supplierName: 'Square Pharma',
          vendorRef: 'VCN-CSH',
          explicitTotal: 100.0,
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

