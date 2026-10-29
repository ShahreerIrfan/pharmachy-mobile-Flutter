// test/unit/dashboard_kpi_test.dart
// Architecture Decision: ADR-0001 & ADR-0024

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/models/dashboard_kpi.dart';

void main() {
  group('DashboardKpi Model & Financial Precision', () {
    test(
        'Parses valid KPI JSON and formats currency with exact Decimal precision',
        () {
      final json = {
        'today_sales_bdt': '124850.50',
        'total_orders_count': 320,
        'gross_margin_percent': '23.8',
        'low_stock_alert_count': 5,
        'expiring_batches_count': 3,
        'pending_rx_count': 7,
        'as_of_timestamp': '2026-10-29T10:00:00Z',
      };

      final kpi = DashboardKpi.fromJson(json);

      expect(kpi.todaySalesBdt, '124850.50');
      expect(kpi.totalOrdersCount, 320);
      expect(kpi.grossMarginPercent, '23.8');
      expect(kpi.lowStockAlertCount, 5);
      expect(kpi.formattedSalesText, 'BDT 124,850.50');
    });

    test('Rejects negative sales amount with FormatException', () {
      final invalidJson = {
        'today_sales_bdt': '-500.00',
        'total_orders_count': 10,
      };

      expect(
        () => DashboardKpi.fromJson(invalidJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('Rejects negative orders count with FormatException', () {
      final invalidJson = {
        'today_sales_bdt': '1000.00',
        'total_orders_count': -3,
      };

      expect(
        () => DashboardKpi.fromJson(invalidJson),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
