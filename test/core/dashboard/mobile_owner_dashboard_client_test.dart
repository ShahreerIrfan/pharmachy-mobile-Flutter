// test/core/dashboard/mobile_owner_dashboard_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/dashboard/mobile_owner_dashboard_client.dart';

void main() {
  group('MobileOwnerDashboardClient Tests', () {
    test('parses MobileOwnerDashboardData correctly from JSON payload', () {
      final jsonPayload = {
        'tenant_id': 'tn-dhaka-01',
        'tenant_name': 'Dhaka Central Pharma',
        'branch_filter': 'br-main',
        'sales_summary': {
          'today_sales_bdt': '35400.00',
          'period_sales_bdt': '35400.00',
          'total_orders_count': 62,
          'average_order_value_bdt': '570.97',
        },
        'profitability_summary': {
          'gross_sales_bdt': '36000.00',
          'cogs_bdt': '27000.00',
          'gross_profit_bdt': '8400.00',
          'gross_margin_percent': '23.73',
          'discounts_bdt': '600.00',
          'net_profit_bdt': '8400.00',
        },
        'customer_dues_summary': {
          'total_dues_bdt': '5200.00',
          'outstanding_customers_count': 3,
          'overdue_invoices_count': 1,
        },
        'inventory_summary': {
          'total_stock_value_bdt': '980000.00',
          'active_batches_count': 220,
          'low_stock_items_count': 4,
          'out_of_stock_items_count': 1,
        },
        'expiry_summary': {
          'expiring_in_30_days_count': 2,
          'expiring_in_90_days_count': 8,
          'expired_batches_count': 0,
          'expired_stock_value_bdt': '0.00',
        },
        'sync_health_summary': {
          'enrolled_devices_count': 2,
          'active_leases_count': 2,
          'unreconciled_held_count': 0,
          'sync_status': 'HEALTHY',
          'last_sync_at': '2026-11-01T15:00:00Z',
        },
        'as_of_timestamp': '2026-11-01T15:30:00Z',
      };

      final data = MobileOwnerDashboardData.fromJson(jsonPayload);
      expect(data.tenantId, 'tn-dhaka-01');
      expect(data.sales.todaySalesBdt, '35400.00');
      expect(data.sales.totalOrdersCount, 62);
      expect(data.profitability.grossProfitBdt, '8400.00');
      expect(data.profitability.cogsBdt, '27000.00');
      expect(data.dues.totalDuesBdt, '5200.00');
      expect(data.inventory.hasStockShortage, isTrue);
      expect(data.expiry.hasCriticalExpiryRisk, isTrue);
      expect(data.syncHealth.isHealthy, isTrue);
    });

    test('creates permission-denied and offline UI states properly', () {
      final denied = MobileOwnerDashboardState.permissionDenied('CASHIER');
      expect(denied.status, MobileDashboardUiStatus.permissionDenied);
      expect(denied.errorMessageEn, contains("Access denied for role 'CASHIER'"));
      expect(denied.errorMessageBn, contains('এক্সিকিউটিভ ড্যাশবোর্ড দেখার অনুমতি নেই'));

      final offline = MobileOwnerDashboardState.offline();
      expect(offline.status, MobileDashboardUiStatus.offline);
      expect(offline.errorMessageEn, contains('offline'));
      expect(offline.errorMessageBn, contains('অফলাইনে আছে'));
    });
  });
}
