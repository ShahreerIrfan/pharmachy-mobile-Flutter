// mobile_double_entry_journal_test.dart
// Architecture Decision: ADR-0282 (P282).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_double_entry_journal_client.dart';

void main() {
  group('MobileDoubleEntryJournalClient Tests (P282)', () {
    const tenantId = 'ten-dhk-01';

    late MobileDoubleEntryJournalClient ownerClient;
    late MobileDoubleEntryJournalClient managerClient;
    late MobileDoubleEntryJournalClient cashierClient;

    setUp(() {
      ownerClient = MobileDoubleEntryJournalClient(
        tenantId: tenantId,
        userRole: 'PHARMACY_OWNER',
        userId: 'owner_01',
      );

      managerClient = MobileDoubleEntryJournalClient(
        tenantId: tenantId,
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_01',
      );

      cashierClient = MobileDoubleEntryJournalClient(
        tenantId: tenantId,
        userRole: 'CASHIER',
        userId: 'csh_01',
      );
    });

    test('1. Owner posts balanced double-entry journal (Rent Expense Dr, Cash Cr)', () async {
      final entry = await ownerClient.postJournal(
        lines: [
          JournalLineDto(
            accountCode: '6010',
            accountName: 'Branch Rent Expense',
            debitAmountBdt: 25000.0,
            creditAmountBdt: 0.0,
            description: 'November rent payment',
          ),
          JournalLineDto(
            accountCode: '1010',
            accountName: 'Cash on Hand',
            debitAmountBdt: 0.0,
            creditAmountBdt: 25000.0,
            description: 'Cash settlement for rent',
          ),
        ],
        narration: 'November store rent payment',
        sourceModule: 'OPERATING_EXPENSE',
      );

      expect(entry.isBalanced, isTrue);
      expect(entry.totalDebitBdt, equals('25000.00'));
      expect(entry.totalCreditBdt, equals('25000.00'));
      expect(entry.status, equals('POSTED'));
    });

    test('2. Unbalanced journal is rejected with ERR_UNBALANCED_JOURNAL_ENTRY', () async {
      expect(
        () => ownerClient.postJournal(
          lines: [
            JournalLineDto(
              accountCode: '6010',
              accountName: 'Rent',
              debitAmountBdt: 25000.0,
            ),
            JournalLineDto(
              accountCode: '1010',
              accountName: 'Cash',
              creditAmountBdt: 20000.0, // Mismatch of 5000.0
            ),
          ],
          narration: 'Unbalanced test',
        ),
        throwsA(isA<JournalValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_UNBALANCED_JOURNAL_ENTRY'),
        )),
      );
    });

    test('3. Owner can reverse journal entry with mandatory reason', () async {
      final res = await ownerClient.reverseJournal(
        journalId: 'jrn-12345',
        reason: 'Incorrect rent expense amount entered by cashier',
      );

      expect(res['success'], isTrue);
      expect(res['status'], equals('REVERSED'));
      expect(res['reversal_journal_id'], isNotNull);
    });

    test('4. Missing reversal reason triggers validation error', () async {
      expect(
        () => ownerClient.reverseJournal(
          journalId: 'jrn-12345',
          reason: '   ',
        ),
        throwsA(isA<JournalValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_MISSING_REVERSAL_REASON'),
        )),
      );
    });

    test('5. Branch Manager cannot post journal entries', () async {
      expect(
        () => managerClient.postJournal(
          lines: [
            JournalLineDto(accountCode: '6010', accountName: 'Rent', debitAmountBdt: 100.0),
            JournalLineDto(accountCode: '1010', accountName: 'Cash', creditAmountBdt: 100.0),
          ],
          narration: 'Manager test',
        ),
        throwsA(isA<JournalPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_JOURNAL_POST_UNAUTHORIZED'),
        )),
      );
    });

    test('6. Cashier is strictly denied from accessing journal engine', () {
      expect(
        () => cashierClient.assertViewAuthorized(),
        throwsA(isA<JournalPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });
  });
}
