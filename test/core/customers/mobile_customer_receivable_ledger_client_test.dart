import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/customers/mobile_customer_receivable_ledger_client.dart';

void main() {
  group('P265: MobileCustomerReceivableLedgerClient Tests', () {
    test('Identifies ledger adjustment admin roles accurately', () {
      expect(MobileCustomerReceivableLedgerClient.canPostAdjustment('PHARMACY_OWNER'), isTrue);
      expect(MobileCustomerReceivableLedgerClient.canPostAdjustment('BRANCH_MANAGER'), isTrue);
      expect(MobileCustomerReceivableLedgerClient.canPostAdjustment('FINANCE_OFFICER'), isTrue);
      expect(MobileCustomerReceivableLedgerClient.canPostAdjustment('CASHIER'), isFalse);
    });

    test('Calculates running AR balance with non-negative lower bound', () {
      expect(
        MobileCustomerReceivableLedgerClient.calculateRunningBalance(1000.0, 500.0, 0.0),
        equals(1500.0),
      );
      expect(
        MobileCustomerReceivableLedgerClient.calculateRunningBalance(1000.0, 0.0, 300.0),
        equals(700.0),
      );
      expect(
        MobileCustomerReceivableLedgerClient.calculateRunningBalance(100.0, 0.0, 500.0),
        equals(0.0),
      );
    });

    test('Reconciles ledger statement financial parity accurately', () {
      expect(
        MobileCustomerReceivableLedgerClient.reconcileParity(
          openingBalance: 1000.0,
          totalDebits: 2000.0,
          totalCredits: 1500.0,
          closingBalance: 1500.0,
        ),
        isTrue,
      );

      expect(
        MobileCustomerReceivableLedgerClient.reconcileParity(
          openingBalance: 1000.0,
          totalDebits: 2000.0,
          totalCredits: 1500.0,
          closingBalance: 1400.0, // Discrepancy
        ),
        isFalse,
      );
    });

    test('Validates manual adjustment arguments strictly', () {
      expect(
        () => MobileCustomerReceivableLedgerClient.validateAdjustment(
          direction: 'INVALID',
          amount: 100.0,
          reason: 'Correction',
        ),
        throwsArgumentError,
      );

      expect(
        () => MobileCustomerReceivableLedgerClient.validateAdjustment(
          direction: 'DEBIT',
          amount: 0.0,
          reason: 'Correction',
        ),
        throwsArgumentError,
      );

      expect(
        () => MobileCustomerReceivableLedgerClient.validateAdjustment(
          direction: 'CREDIT',
          amount: 100.0,
          reason: '',
        ),
        throwsArgumentError,
      );
    });
  });
}
