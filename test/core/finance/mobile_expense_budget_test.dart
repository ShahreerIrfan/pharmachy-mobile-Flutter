// mobile_expense_budget_test.dart
// Architecture Decision: ADR-0296 (P296).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_expense_budget_client.dart';

void main() {
  group('P296 MobileExpenseBudgetClient', () {
    test('01. Owner parses budget list and updates loaded state', () {
      final client = MobileExpenseBudgetClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'PHARMACY_OWNER',
      );

      final items = client.parseBudgetListResponse({
        'count': 1,
        'budgets': [
          {
            'budget_id': 'ebud-101',
            'tenant_id': 'ten-1',
            'branch_id': 'br-1',
            'branch_name': 'Dhanmondi Branch',
            'category_id': 'cat-rent',
            'category_code': 'RENT',
            'category_name': 'Branch Rent',
            'period_type': 'MONTHLY',
            'fiscal_year': 2026,
            'fiscal_month': 11,
            'planned_amount_bdt': '50000.00',
            'actual_spent_bdt': '42500.00',
            'remaining_bdt': '7500.00',
            'utilization_pct': '85.00',
            'warning_threshold_pct': '80.00',
            'critical_threshold_pct': '100.00',
            'enforcement_mode': 'REQUIRE_APPROVAL',
            'require_manager_approval_on_exceed': true,
            'health_status': 'WARNING',
            'status': 'ACTIVE',
          }
        ],
      });

      expect(items.length, 1);
      expect(items.first.healthStatus, 'WARNING');
      expect(items.first.localizedBadge()['bn'], 'সীমার কাছাকাছি');
      expect(client.uiState, BudgetUiState.loaded);
    });

    test('02. Empty response sets empty UI state', () {
      final client = MobileExpenseBudgetClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'PHARMACY_OWNER',
      );
      final items = client.parseBudgetListResponse({'count': 0, 'budgets': []});
      expect(items, isEmpty);
      expect(client.uiState, BudgetUiState.empty);
    });

    test('03. Offline fallback returns cached items and marks offlineCache state', () {
      final client = MobileExpenseBudgetClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'FINANCE_OFFICER',
      );
      client.parseBudgetListResponse({
        'budgets': [
          {
            'budget_id': 'ebud-202',
            'tenant_id': 'ten-1',
            'planned_amount_bdt': '25000.00',
            'actual_spent_bdt': '30000.00',
            'health_status': 'EXCEEDED',
          }
        ],
      });

      final cached = client.loadOfflineFallback();
      expect(cached.length, 1);
      expect(cached.first.localizedBadge()['en'], 'Budget Exceeded');
      expect(client.uiState, BudgetUiState.offlineCache);
    });

    test('04. Cashier is denied access with permissionDenied state', () {
      final client = MobileExpenseBudgetClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'CASHIER',
      );

      expect(
        () => client.parseBudgetListResponse({'budgets': []}),
        throwsA(isA<ExpenseBudgetPermissionException>()),
      );
      expect(client.uiState, BudgetUiState.permissionDenied);
    });

    test('05. Branch Manager restricted from other branches and blocked from creating budgets', () {
      final client = MobileExpenseBudgetClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'BRANCH_MANAGER',
      );

      expect(client.canView(targetBranchId: 'br-1'), isTrue);
      expect(client.canView(targetBranchId: 'br-2'), isFalse);
      expect(
        () => client.buildCreatePayload(
          fiscalYear: 2026,
          fiscalMonth: 11,
          plannedAmountBdt: '10000.00',
        ),
        throwsA(isA<ExpenseBudgetPermissionException>()),
      );
    });

    test('06. Invalid planned amount or enforcement mode throws validation exception', () {
      final client = MobileExpenseBudgetClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'PHARMACY_OWNER',
      );

      expect(
        () => client.buildCreatePayload(
          fiscalYear: 2026,
          fiscalMonth: 11,
          plannedAmountBdt: '-500.00',
        ),
        throwsA(isA<ExpenseBudgetValidationException>()),
      );

      expect(
        () => client.buildCreatePayload(
          fiscalYear: 2026,
          fiscalMonth: 11,
          plannedAmountBdt: '5000.00',
          enforcementMode: 'UNKNOWN_MODE',
        ),
        throwsA(isA<ExpenseBudgetValidationException>()),
      );
    });

    test('07. Evaluation DTO parses hard stop and senior override flags accurately', () {
      final dto = ExpenseBudgetEvaluationDto.fromJson({
        'overall_status': 'REQUIRES_SENIOR_APPROVAL',
        'hard_blocked': false,
        'requires_senior_override': true,
        'matched_budget_count': 2,
      });

      expect(dto.overallStatus, 'REQUIRES_SENIOR_APPROVAL');
      expect(dto.hardBlocked, isFalse);
      expect(dto.requiresSeniorOverride, isTrue);
      expect(dto.matchedBudgetCount, 2);
    });
  });
}
