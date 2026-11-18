// mobile_chart_of_accounts_test.dart
// Architecture Decision: ADR-0281 (P281).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_chart_of_accounts_client.dart';

void main() {
  group('MobileChartOfAccountsClient Tests (P281)', () {
    const tenantId = 'ten-dhk-01';

    late MobileChartOfAccountsClient ownerClient;
    late MobileChartOfAccountsClient managerClient;
    late MobileChartOfAccountsClient cashierClient;

    setUp(() {
      ownerClient = MobileChartOfAccountsClient(
        tenantId: tenantId,
        userRole: 'PHARMACY_OWNER',
        userId: 'owner_01',
      );

      managerClient = MobileChartOfAccountsClient(
        tenantId: tenantId,
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_01',
      );

      cashierClient = MobileChartOfAccountsClient(
        tenantId: tenantId,
        userRole: 'CASHIER',
        userId: 'csh_01',
      );
    });

    test('1. Manager can view standard seeded pharmacy accounts', () {
      final accounts = managerClient.getDefaultPharmacyAccounts();
      expect(accounts.length, greaterThanOrEqualTo(8));
      expect(accounts.any((a) => a.accountCode == '1010'), isTrue); // Cash
      expect(accounts.any((a) => a.accountCode == '1040'), isTrue); // Inventory
      expect(accounts.any((a) => a.accountCode == '2010'), isTrue); // AP
      expect(accounts.any((a) => a.accountCode == '4010'), isTrue); // Sales
      expect(accounts.any((a) => a.accountCode == '5010'), isTrue); // COGS
    });

    test('2. Owner can create custom operating expense account', () async {
      final acc = await ownerClient.createAccount(
        accountCode: '6070',
        accountName: 'Generator Diesel & Fuel Expense',
        category: 'EXPENSE',
        description: 'Backup electricity generator fuel',
      );

      expect(acc.accountCode, equals('6070'));
      expect(acc.accountName, equals('Generator Diesel & Fuel Expense'));
      expect(acc.category, equals('EXPENSE'));
      expect(acc.normalBalance, equals('DEBIT'));
    });

    test('3. Branch Manager attempting account creation is blocked', () async {
      expect(
        () => managerClient.createAccount(
          accountCode: '6080',
          accountName: 'Unauthorized Account',
          category: 'EXPENSE',
        ),
        throwsA(isA<ChartOfAccountsPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_COA_MANAGE_UNAUTHORIZED'),
        )),
      );
    });

    test('4. Cashier is strictly denied from accessing chart of accounts', () {
      expect(
        () => cashierClient.getDefaultPharmacyAccounts(),
        throwsA(isA<ChartOfAccountsPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });

    test('5. Missing account code or name triggers validation error', () async {
      expect(
        () => ownerClient.createAccount(
          accountCode: '',
          accountName: 'Invalid Account',
          category: 'EXPENSE',
        ),
        throwsA(isA<ChartOfAccountsValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_MISSING_ACCOUNT_CODE'),
        )),
      );
    });
  });
}
