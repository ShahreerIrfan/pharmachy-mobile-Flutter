// mobile_financial_period_test.dart
// Architecture Decision: ADR-0292 (P292).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_financial_period_client.dart';

void main() {
  group('MobileFinancialPeriodClient P292 Unit Tests', () {
    const tenantId = 'ten-dhaka-pharma-01';
    const branchId = 'br-dhanmondi-main';

    test('1. Finance Officer creates a new monthly accounting period', () {
      final client = MobileFinancialPeriodClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr-fin-1',
      );

      final period = client.createPeriod(
        periodCode: '2026-11',
        periodName: 'November 2026 Monthly Period',
        startDate: '2026-11-01',
        endDate: '2026-11-30',
      );

      expect(period.periodCode, equals('2026-11'));
      expect(period.status, equals('OPEN'));
      expect(period.reopenCount, equals(0));
    });

    test('2. Integrity validation detects blocking issues when pending drafts exist', () {
      final client = MobileFinancialPeriodClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final period = client.createPeriod(
        periodCode: '2026-11',
        periodName: 'November 2026',
        startDate: '2026-11-01',
        endDate: '2026-11-30',
      );

      final report = client.validateIntegrity(period.periodId, simulatePendingDrafts: true);
      expect(report['is_ready_to_close'], isFalse);
      expect(report['blocking_issues'].length, greaterThan(0));
    });

    test('3. Finance Officer successfully closes period and seals ledger', () {
      final client = MobileFinancialPeriodClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr-fin-1',
      );

      final period = client.createPeriod(
        periodCode: '2026-10',
        periodName: 'October 2026',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
      );

      final closed = client.closePeriod(period.periodId, closingNotes: 'Standard month-end closing');
      expect(closed.status, equals('CLOSED'));
      expect(closed.closedAt, isNotNull);
      expect(closed.closingJournalId, isNotNull);
      expect(closed.netIncomeBdt, equals(150000.0));
    });

    test('4. Closing an already closed period throws validation error', () {
      final client = MobileFinancialPeriodClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final period = client.createPeriod(
        periodCode: '2026-09',
        periodName: 'September 2026',
        startDate: '2026-09-01',
        endDate: '2026-09-30',
      );

      client.closePeriod(period.periodId);

      expect(
        () => client.closePeriod(period.periodId),
        throwsA(
          isA<PeriodValidationException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ERR_PERIOD_ALREADY_CLOSED',
          ),
        ),
      );
    });

    test('5. Cashier is strictly denied from period close operations', () {
      final client = MobileFinancialPeriodClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
      );

      expect(
        () => client.createPeriod(
          periodCode: '2026-12',
          periodName: 'December 2026',
          startDate: '2026-12-01',
          endDate: '2026-12-31',
        ),
        throwsA(
          isA<PeriodPermissionException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ERR_PERIOD_CLOSE_UNAUTHORIZED',
          ),
        ),
      );
    });

    test('6. Finance Officer alone is denied from reopening; strictly Owner required', () {
      final client = MobileFinancialPeriodClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr-fin-1',
      );

      expect(
        () => client.reopenPeriod('fper-123', reopenReason: 'Audit discrepancy'),
        throwsA(
          isA<PeriodPermissionException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ERR_PERIOD_REOPEN_UNAUTHORIZED',
          ),
        ),
      );
    });

    test('7. Pharmacy Owner successfully reopens closed period with audit reason', () {
      final client = MobileFinancialPeriodClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final period = client.createPeriod(
        periodCode: '2026-08',
        periodName: 'August 2026',
        startDate: '2026-08-01',
        endDate: '2026-08-31',
      );

      client.closePeriod(period.periodId);
      final reopened = client.reopenPeriod(
        period.periodId,
        reopenReason: 'Reopen to adjust missed supplier return credit note.',
      );

      expect(reopened.status, equals('REOPENED'));
      expect(reopened.reopenCount, equals(1));
      expect(reopened.reopenReason, contains('missed supplier return'));
    });
  });
}
