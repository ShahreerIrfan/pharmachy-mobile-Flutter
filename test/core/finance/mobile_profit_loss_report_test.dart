// mobile_profit_loss_report_test.dart
// Architecture Decision: ADR-0293 (P293).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_profit_loss_report_client.dart';

void main() {
  group('MobileProfitLossReportClient P293 Unit Tests', () {
    const tenantId = 'ten-dhaka-pharma-01';
    const branchId = 'br-dhanmondi-main';

    test('1. Pharmacy Owner generates consolidated Profit & Loss report with accurate calculations', () {
      final client = MobileProfitLossReportClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final report = client.generateProfitAndLossReport(
        grossMedicineSales: 150000.00,
        grossOtcSales: 50000.00,
        discounts: 5000.00,
        lotPurchasesCogs: 120000.00,
        expiryWriteOffs: 2000.00,
        rentExpense: 15000.00,
        electricityExpense: 4500.00,
        salariesExpense: 30000.00,
        internetExpense: 1500.00,
        transportExpense: 1000.00,
        miscExpense: 500.00,
      );

      // Gross: 150000 + 50000 = 200000. Less discounts 5000 = 195000.
      expect(report.revenue.grossRevenueBdt, equals(200000.00));
      expect(report.revenue.contraDiscountsBdt, equals(5000.00));
      expect(report.revenue.netRevenueBdt, equals(195000.00));

      // COGS: 120000 + 2000 = 122000.
      expect(report.cogs.totalCogsBdt, equals(122000.00));

      // Gross Profit: 195000 - 122000 = 73000. Margin: 73000 / 195000 = 37.44%
      expect(report.grossProfit.grossProfitBdt, equals(73000.00));
      expect(report.grossProfit.grossMarginPct, equals(37.44));
      expect(report.grossProfit.isProfitable, isTrue);

      // OpEx: 15000 + 4500 + 30000 + 1500 + 1000 + 500 = 52500.
      expect(report.operatingExpenses.totalOperatingExpensesBdt, equals(52500.00));

      // Net Operating Profit: 73000 - 52500 = 20500. Net Margin: 20500 / 195000 = 10.51%
      expect(report.netOperatingProfit.netOperatingProfitBdt, equals(20500.00));
      expect(report.netOperatingProfit.netMarginPct, equals(10.51));
      expect(report.netOperatingProfit.isProfitable, isTrue);
    });

    test('2. Cashier is rejected with ERR_PL_REPORT_UNAUTHORIZED', () {
      final client = MobileProfitLossReportClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'usr-cashier-1',
      );

      expect(
        () => client.generateProfitAndLossReport(),
        throwsA(
          isA<ProfitLossPermissionException>().having((e) => e.errorCode, 'errorCode', equals('ERR_PL_REPORT_UNAUTHORIZED')),
        ),
      );
    });

    test('3. Branch Manager attempting to view other branch is rejected with ERR_BRANCH_ACCESS_DENIED', () {
      final client = MobileProfitLossReportClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-bm-1',
      );

      expect(
        () => client.generateProfitAndLossReport(queryBranchId: 'br-foreign-branch'),
        throwsA(
          isA<ProfitLossPermissionException>().having((e) => e.errorCode, 'errorCode', equals('ERR_BRANCH_ACCESS_DENIED')),
        ),
      );
    });

    test('4. Suspended tenant is rejected with ERR_TENANT_SUSPENDED', () {
      final client = MobileProfitLossReportClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
        isSuspended: true,
      );

      expect(
        () => client.generateProfitAndLossReport(),
        throwsA(
          isA<ProfitLossPermissionException>().having((e) => e.errorCode, 'errorCode', equals('ERR_TENANT_SUSPENDED')),
        ),
      );
    });

    test('5. Invalid date range throws ERR_INVALID_DATE_RANGE', () {
      final client = MobileProfitLossReportClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'FINANCE_OFFICER',
        userId: 'usr-fin-1',
      );

      expect(
        () => client.generateProfitAndLossReport(
          startDate: '2026-12-01',
          endDate: '2026-11-01',
        ),
        throwsA(
          isA<ProfitLossValidationException>().having((e) => e.errorCode, 'errorCode', equals('ERR_INVALID_DATE_RANGE')),
        ),
      );
    });

    test('6. CSV export generates valid statement with headers and rows', () {
      final client = MobileProfitLossReportClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-own-1',
      );

      final report = client.generateProfitAndLossReport();
      final csv = client.exportProfitAndLossCsv(report);

      expect(csv, contains('PROFIT & LOSS STATEMENT (INCOME STATEMENT)'));
      expect(csv, contains('Revenue,4010,"Medicine Sales Revenue",150000.00'));
      expect(csv, contains('COGS,5010,"Cost of Goods Sold - Lot Purchase",120000.00'));
      expect(csv, contains('Summary,GROSS_PROFIT,"Gross Profit",73000.00'));
      expect(csv, contains('Summary,NET_PROFIT,"Net Operating Profit",20500.00'));
    });
  });
}
