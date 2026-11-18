// mobile_cash_bank_account_registry_client_test.dart
// Architecture Decision: ADR-0274 (P274).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_cash_bank_account_registry_client.dart';

void main() {
  group('MobileCashBankAccountRegistryClient Tests (P274)', () {
    const tenantId = 'ten-dhk-01';
    const branchId = 'br-dhanmondi-01';

    late MobileCashBankAccountRegistryClient managerClient;
    late MobileCashBankAccountRegistryClient cashierClient;
    late Map<String, MobileFinancialAccountDto> sharedStore;

    setUp(() {
      sharedStore = {};
      managerClient = MobileCashBankAccountRegistryClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_01',
        accountStore: sharedStore,
      );

      cashierClient = MobileCashBankAccountRegistryClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'csh_01',
        accountStore: sharedStore,
      );
    });

    test('1. Successful registration of cash register and bank account', () {
      final reg = managerClient.registerAccount(
        accountType: 'CASH_REGISTER',
        accountName: 'Counter 1 POS Till',
        accountCode: 'CR-01',
        openingBalance: 5000.0,
        isDefaultForType: true,
      );

      expect(reg.accountType, equals('CASH_REGISTER'));
      expect(reg.accountCode, equals('CR-01'));
      expect(reg.openingBalance, equals(5000.0));
      expect(reg.isDefaultForType, isTrue);

      final bank = managerClient.registerAccount(
        accountType: 'BANK_ACCOUNT',
        accountName: 'DBBL Corporate Current Account',
        accountCode: 'BA-DBBL-01',
        accountNumber: '110.120.3344',
        bankName: 'Dutch-Bangla Bank Ltd',
        branchName: 'Dhanmondi Branch',
        routingNumber: '090271234',
        openingBalance: 150000.0,
      );

      expect(bank.accountType, equals('BANK_ACCOUNT'));
      expect(bank.bankName, equals('Dutch-Bangla Bank Ltd'));
      expect(bank.accountNumber, equals('110.120.3344'));
    });

    test('2. Missing bank details throws validation exception', () {
      expect(
        () => managerClient.registerAccount(
          accountType: 'BANK_ACCOUNT',
          accountName: 'Incomplete Bank Account',
          accountNumber: '',
          bankName: '',
        ),
        throwsA(isA<FinancialAccountValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_MISSING_BANK_DETAILS'),
        )),
      );
    });

    test('3. Cashier is barred from registering or configuring financial accounts', () {
      expect(
        () => cashierClient.registerAccount(
          accountType: 'CASH_REGISTER',
          accountName: 'Cashier Attempt',
        ),
        throwsA(isA<FinancialAccountPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });

    test('4. Cashier listAccounts only returns CASH_REGISTER accounts', () {
      managerClient.registerAccount(
        accountType: 'CASH_REGISTER',
        accountName: 'Counter 1',
        accountCode: 'CR-C1',
      );
      managerClient.registerAccount(
        accountType: 'BANK_ACCOUNT',
        accountName: 'Secret Operating Bank',
        accountCode: 'BA-SEC',
        accountNumber: '99887766',
        bankName: 'BRAC Bank',
      );

      final cashierList = cashierClient.listAccounts();
      expect(cashierList.length, equals(1));
      expect(cashierList.first.accountType, equals('CASH_REGISTER'));
    });

    test('5. Lifecycle transitions: Freeze, unfreeze, and close', () {
      final acc = managerClient.registerAccount(
        accountType: 'MFS_CLEARING',
        accountName: 'bKash Merchant Till',
        accountCode: 'MFS-BKASH-01',
      );

      final frozen = managerClient.freezeAccount(acc.accountId, reason: 'Suspected reconciliation discrepancy');
      expect(frozen.status, equals('FROZEN'));

      final unfrozen = managerClient.unfreezeAccount(acc.accountId, reason: 'Audit passed');
      expect(unfrozen.status, equals('ACTIVE'));

      final closed = managerClient.closeAccount(acc.accountId, reason: 'Switched to new terminal');
      expect(closed.status, equals('CLOSED'));
      expect(closed.isActive, isFalse);

      expect(
        () => managerClient.freezeAccount(acc.accountId),
        throwsA(isA<FinancialAccountValidationException>()),
      );
    });
  });
}
