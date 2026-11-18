// mobile_cash_flow_test.dart
// Architecture Decision: ADR-0294 (P294).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_cash_flow_client.dart';

void main() {
  group('MobileCashFlowClient P294 Unit Tests', () {
    const tenantId = 'ten-dhaka-pharma-01';
    const branchId = 'br-dhanmondi-main';

    test('1. Pharmacy Owner generates cash flow overview with accurate liquid balance math', () {
      final client = MobileCashFlowClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final report = client.generateCashFlowOverview(
        openingBalance: 50000.00,
        posSales: 200000.00,
        arCollections: 20000.00,
        otherInflows: 5000.00,
        operatingExpenses: 45000.00,
        supplierAp: 100000.00,
        payroll: 30000.00,
        otherOutflows: 2000.00,
        transfersIn: 40000.00,
        transfersOut: 40000.00,
      );

      // Inflows: 200000 + 20000 + 5000 = 225000.
      expect(report.operatingInflows.totalOperatingInflowsBdt, equals(225000.00));

      // Outflows: 45000 + 100000 + 30000 + 2000 = 177000.
      expect(report.operatingOutflows.totalOperatingOutflowsBdt, equals(177000.00));

      // Net Operating Cash Flow: 225000 - 177000 = 48000.
      expect(report.netOperatingCashFlowBdt, equals(48000.00));

      // Transfers Net = 40000 - 40000 = 0.00.
      expect(report.treasuryTransfers.netTransfersBdt, equals(0.00));

      // Net Overall Cash Flow = 48000.
      expect(report.netCashFlowBdt, equals(48000.00));
      expect(report.isPositiveCashFlow, isTrue);

      // Closing Balance = 50000 + 48000 = 98000.
      expect(report.closingBalanceBdt, equals(98000.00));
    });

    test('2. Accrual vs cash flow reconciliation demonstrates timing variance', () {
      final client = MobileCashFlowClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr-fin-1',
      );

      final report = client.generateCashFlowOverview(
        posSales: 200000.00,
        arCollections: 20000.00,
        otherInflows: 0.00,
        accrualNetRevenue: 250000.00, // 30k was credit dues
        operatingExpenses: 50000.00,
        supplierAp: 70000.00,
        payroll: 30000.00,
        otherOutflows: 0.00,
        accrualExpenses: 180000.00,
      );

      // Accrual Revenue: 250000 vs Cash Inflows: 220000 -> Variance 30000
      expect(report.accrualReconciliation.accrualNetRevenueBdt, equals(250000.00));
      expect(report.accrualReconciliation.cashOperatingInflowsBdt, equals(220000.00));
      expect(report.accrualReconciliation.revenueTimingVarianceBdt, equals(30000.00));
    });

    test('3. Cashier is blocked with ERR_CASH_FLOW_UNAUTHORIZED', () {
      final client = MobileCashFlowClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr-cashier-1',
      );

      expect(
        () => client.generateCashFlowOverview(),
        throwsA(
          isA<CashFlowPermissionException>().having((e) => e.errorCode, 'errorCode', equals('ERR_CASH_FLOW_UNAUTHORIZED')),
        ),
      );
    });

    test('4. Branch Manager attempting to access other branch is blocked with ERR_BRANCH_ACCESS_DENIED', () {
      final client = MobileCashFlowClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-bm-1',
      );

      expect(
        () => client.generateCashFlowOverview(queryBranchId: 'br-foreign-branch'),
        throwsA(
          isA<CashFlowPermissionException>().having((e) => e.errorCode, 'errorCode', equals('ERR_BRANCH_ACCESS_DENIED')),
        ),
      );
    });

    test('5. Suspended tenant is blocked with ERR_TENANT_SUSPENDED', () {
      final client = MobileCashFlowClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
        isSuspended: true,
      );

      expect(
        () => client.generateCashFlowOverview(),
        throwsA(
          isA<CashFlowPermissionException>().having((e) => e.errorCode, 'errorCode', equals('ERR_TENANT_SUSPENDED')),
        ),
      );
    });

    test('6. Invalid date range throws ERR_INVALID_DATE_RANGE', () {
      final client = MobileCashFlowClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      expect(
        () => client.generateCashFlowOverview(
          startDate: '2026-12-01',
          endDate: '2026-11-01',
        ),
        throwsA(
          isA<CashFlowValidationException>().having((e) => e.errorCode, 'errorCode', equals('ERR_INVALID_DATE_RANGE')),
        ),
      );
    });

    test('7. CSV export produces valid headers and cash flow rows', () {
      final client = MobileCashFlowClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final report = client.generateCashFlowOverview();
      final csv = client.exportCashFlowCsv(report);

      expect(csv, contains('CASH FLOW STATEMENT (DIRECT METHOD)'));
      expect(csv, contains('BALANCE,Opening Liquid Cash & Bank Balance'));
      expect(csv, contains('OPERATING_INFLOW,POS Counter Sales Collections'));
      expect(csv, contains('OPERATING_OUTFLOW,Supplier AP Paid'));
      expect(csv, contains('SUMMARY,Net Operating Cash Flow'));
      expect(csv, contains('BALANCE,Closing Liquid Cash & Bank Balance'));
    });
  });
}
