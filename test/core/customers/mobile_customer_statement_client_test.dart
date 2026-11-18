import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/customers/mobile_customer_statement_client.dart';

void main() {
  group('MobileCustomerStatementClient Tests (P267)', () {
    test('verifyStatementParity validates Opening + Charges - Payments == Closing', () {
      final valid = MobileCustomerStatementClient.verifyStatementParity(
        openingBalance: 500.0,
        totalCharges: 1200.0,
        totalPayments: 700.0,
        closingBalance: 1000.0,
      );
      expect(valid, isTrue);

      final invalid = MobileCustomerStatementClient.verifyStatementParity(
        openingBalance: 500.0,
        totalCharges: 1200.0,
        totalPayments: 700.0,
        closingBalance: 950.0,
      );
      expect(invalid, isFalse);
    });

    test('sumAgingBuckets calculates 4-tier total with penny precision', () {
      final total = MobileCustomerStatementClient.sumAgingBuckets(
        current: 300.50,
        days31To60: 200.25,
        days61To90: 100.15,
        days91Plus: 50.10,
      );
      expect(total, equals(651.00));
    });

    test('validateDateRange passes valid dates and rejects invalid or reversed ranges', () {
      expect(
        () => MobileCustomerStatementClient.validateDateRange('2026-01-01', '2026-01-31'),
        returnsNormally,
      );

      // Start after End
      expect(
        () => MobileCustomerStatementClient.validateDateRange('2026-02-01', '2026-01-15'),
        throwsA(isA<ArgumentError>()),
      );

      // Malformed date
      expect(
        () => MobileCustomerStatementClient.validateDateRange('not-a-date', '2026-01-15'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('canViewStatement checks role privileges', () {
      expect(MobileCustomerStatementClient.canViewStatement('PHARMACY_OWNER'), isTrue);
      expect(MobileCustomerStatementClient.canViewStatement('BRANCH_MANAGER'), isTrue);
      expect(MobileCustomerStatementClient.canViewStatement('CASHIER'), isTrue);
      expect(MobileCustomerStatementClient.canViewStatement('AUDITOR'), isTrue);
      expect(MobileCustomerStatementClient.canViewStatement(null), isFalse);
      expect(MobileCustomerStatementClient.canViewStatement('PATIENT_GUEST'), isFalse);
    });
  });
}
