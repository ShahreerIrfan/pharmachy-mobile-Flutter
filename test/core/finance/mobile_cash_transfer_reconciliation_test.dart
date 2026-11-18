// mobile_cash_transfer_reconciliation_test.dart
// Architecture Decision: ADR-0290 (P290).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_cash_transfer_reconciliation_client.dart';

void main() {
  group('MobileCashTransferReconciliationClient P290 Unit Tests', () {
    const tenantId = 'ten_square_01';
    const branchId = 'br_dhanmondi_01';

    test('1. Execute cash-to-bank deposit transfer moves funds between asset accounts', () {
      final client = MobileCashTransferReconciliationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr_mgr_01',
      );

      client.setAccountBalance('acc_till_01', 25000.0);
      client.setAccountBalance('acc_bank_dbbl', 100000.0);

      final tx = client.executeTransfer(
        sourceAccountId: 'acc_till_01',
        sourceAccountName: 'Cash Counter Till 1',
        destinationAccountId: 'acc_bank_dbbl',
        destinationAccountName: 'DBBL Corporate Account',
        amountBdt: 20000.0,
        referenceNumber: 'DEP-SLIP-88991',
        transferType: 'CASH_TO_BANK',
      );

      expect(tx.status, equals('COMPLETED'));
      expect(tx.amountBdt, equals(20000.0));
      expect(tx.transferNumber, startsWith('TRF-'));
      expect(client.getAccountBalance('acc_till_01'), equals(5000.0));
      expect(client.getAccountBalance('acc_bank_dbbl'), equals(120000.0));
    });

    test('2. Same account transfer is strictly rejected', () {
      final client = MobileCashTransferReconciliationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr_mgr_01',
      );

      expect(
        () => client.executeTransfer(
          sourceAccountId: 'acc_till_01',
          sourceAccountName: 'Till 1',
          destinationAccountId: 'acc_till_01',
          destinationAccountName: 'Till 1',
          amountBdt: 5000.0,
        ),
        throwsA(isA<TreasuryValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_SAME_ACCOUNT_TRANSFER'),
        )),
      );
    });

    test('3. Negative or zero amount transfer is rejected', () {
      final client = MobileCashTransferReconciliationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr_mgr_01',
      );

      expect(
        () => client.executeTransfer(
          sourceAccountId: 'acc_till_01',
          sourceAccountName: 'Till 1',
          destinationAccountId: 'acc_bank_01',
          destinationAccountName: 'Bank',
          amountBdt: -500.0,
        ),
        throwsA(isA<TreasuryValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_INVALID_TRANSFER_AMOUNT'),
        )),
      );
    });

    test('4. Bank reconciliation matches balanced statement ending balance', () {
      final ownerClient = MobileCashTransferReconciliationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr_owner_01',
      );

      ownerClient.setAccountBalance('acc_bank_brac', 75000.0);

      final rec = ownerClient.runReconciliation(
        bankAccountId: 'acc_bank_brac',
        bankAccountName: 'BRAC Bank Current A/C',
        statementEndingBalance: 75000.0,
      );

      expect(rec.status, equals('RECONCILED'));
      expect(rec.differenceBdt, equals(0.0));
      expect(rec.reconciledBy, equals('usr_owner_01'));
    });

    test('5. Bank reconciliation detects discrepancy when statement balance differs', () {
      final finClient = MobileCashTransferReconciliationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr_fin_01',
      );

      finClient.setAccountBalance('acc_bank_dbbl', 50000.0);

      final rec = finClient.runReconciliation(
        bankAccountId: 'acc_bank_dbbl',
        bankAccountName: 'DBBL Current A/C',
        statementEndingBalance: 48500.0, // Variance: -1500 BDT
      );

      expect(rec.status, equals('DISCREPANCY'));
      expect(rec.differenceBdt, equals(-1500.0));
      expect(rec.reconciledBy, isNull);
    });

    test('6. Cashier is strictly denied from transfers and reconciliation', () {
      final cashierClient = MobileCashTransferReconciliationClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr_cashier_01',
      );

      expect(
        () => cashierClient.executeTransfer(
          sourceAccountId: 'acc_till',
          sourceAccountName: 'Till',
          destinationAccountId: 'acc_bank',
          destinationAccountName: 'Bank',
          amountBdt: 1000.0,
        ),
        throwsA(isA<TreasuryPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_TREASURY_MANAGE_UNAUTHORIZED'),
        )),
      );

      expect(
        () => cashierClient.runReconciliation(
          bankAccountId: 'acc_bank',
          bankAccountName: 'Bank',
          statementEndingBalance: 5000.0,
        ),
        throwsA(isA<TreasuryPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_RECONCILIATION_UNAUTHORIZED'),
        )),
      );
    });
  });
}
