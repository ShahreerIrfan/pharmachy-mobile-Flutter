// mobile_payroll_expense_test.dart
// Architecture Decision: ADR-0291 (P291).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_payroll_expense_client.dart';

void main() {
  group('MobilePayrollExpenseClient P291 Unit Tests', () {
    const tenantId = 'ten-dhaka-pharmacy-01';
    const branchId = 'br-dhanmondi-main';

    test('1. Ordinary expense entry for category SALARIES is blocked by payroll boundary', () {
      final client = MobilePayrollExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
      );

      expect(
        () => client.validateOrdinaryExpenseCategory('SALARIES'),
        throwsA(
          isA<PayrollValidationException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ERR_PAYROLL_EXPENSE_BOUNDARY_ENFORCED',
          ),
        ),
      );
    });

    test('2. Owner successfully creates draft payroll batch with multiple slips', () {
      final client = MobilePayrollExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final slips = [
        {
          'staff_member_id': 'staff-1',
          'staff_name': 'Tariq Pharmacist',
          'staff_role': 'STAFF_PHARMACIST',
          'base_salary_bdt': 35000.0,
          'allowances_bdt': 5000.0,
          'bonus_bdt': 2000.0,
          'deductions_bdt': 1500.0,
        },
        {
          'staff_member_id': 'staff-2',
          'staff_name': 'Rahim Cashier',
          'staff_role': 'CASHIER',
          'base_salary_bdt': 18000.0,
          'allowances_bdt': 2000.0,
          'bonus_bdt': 0.0,
          'deductions_bdt': 500.0,
        },
      ];

      final run = client.createPayrollRun(
        periodStart: '2026-11-01',
        periodEnd: '2026-11-30',
        paymentMethod: 'BANK_TRANSFER',
        slips: slips,
      );

      expect(run.status, equals('DRAFT'));
      expect(run.totalGrossBdt, equals(53000.0));
      expect(run.totalAllowancesBdt, equals(7000.0));
      expect(run.totalBonusesBdt, equals(2000.0));
      expect(run.totalDeductionsBdt, equals(2000.0));
      // Net: (35000+5000+2000-1500=40500) + (18000+2000-500=19500) = 60000.0
      expect(run.totalNetPayableBdt, equals(60000.0));
      expect(run.slips.length, equals(2));
      expect(run.isConfidential, isTrue);
    });

    test('3. Deductions exceeding earnings rejected with negative net salary error', () {
      final client = MobilePayrollExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr-fin-1',
      );

      final slips = [
        {
          'staff_member_id': 'staff-1',
          'base_salary_bdt': 20000.0,
          'deductions_bdt': 25000.0, // Exceeds earnings
        },
      ];

      expect(
        () => client.createPayrollRun(
          periodStart: '2026-11-01',
          periodEnd: '2026-11-30',
          slips: slips,
        ),
        throwsA(
          isA<PayrollValidationException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ERR_NEGATIVE_NET_SALARY',
          ),
        ),
      );
    });

    test('4. Senior finance officer approves and posts payroll to GL', () {
      final client = MobilePayrollExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr-fin-1',
      );

      final run = client.createPayrollRun(
        periodStart: '2026-11-01',
        periodEnd: '2026-11-30',
        slips: [
          {
            'staff_member_id': 'staff-1',
            'base_salary_bdt': 30000.0,
          },
        ],
      );

      final posted = client.approveAndPostPayroll(run.runId);
      expect(posted.status, equals('POSTED'));
      expect(posted.postedJournalId, isNotNull);
      expect(posted.slips.first.paymentStatus, equals('PAID'));
    });

    test('5. Re-approving already posted payroll is rejected', () {
      final client = MobilePayrollExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final run = client.createPayrollRun(
        periodStart: '2026-11-01',
        periodEnd: '2026-11-30',
        slips: [
          {'staff_member_id': 'staff-1', 'base_salary_bdt': 25000.0},
        ],
      );

      client.approveAndPostPayroll(run.runId);

      expect(
        () => client.approveAndPostPayroll(run.runId),
        throwsA(
          isA<PayrollValidationException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ERR_PAYROLL_ALREADY_POSTED',
          ),
        ),
      );
    });

    test('6. POS cashier is strictly unauthorized from payroll operations', () {
      final client = MobilePayrollExpenseClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
      );

      expect(
        () => client.createPayrollRun(
          periodStart: '2026-11-01',
          periodEnd: '2026-11-30',
          slips: [
            {'staff_member_id': 'staff-1', 'base_salary_bdt': 25000.0},
          ],
        ),
        throwsA(
          isA<PayrollPermissionException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ERR_PAYROLL_MANAGE_UNAUTHORIZED',
          ),
        ),
      );
    });
  });
}
