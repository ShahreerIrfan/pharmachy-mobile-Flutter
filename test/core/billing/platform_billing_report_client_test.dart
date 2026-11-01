// test/core/billing/platform_billing_report_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/platform_billing_report_client.dart';

void main() {
  group('MobilePlatformBillingReportClient Tests', () {
    test('parses MobileMrrSummary correctly from json', () {
      final json = {
        'total_mrr_bdt': '50000.00',
        'total_arr_bdt': '600000.00',
        'arpu_bdt': '2500.00',
        'active_subscriptions_count': 20,
        'paying_tenants_count': 20,
        'tier_breakdown': {
          'BASIC': '10000.00',
          'STANDARD': '20000.00',
          'PRO': '20000.00',
        },
      };

      final mrr = MobileMrrSummary.fromJson(json);
      expect(mrr.totalMrrBdt, '50000.00');
      expect(mrr.totalArrBdt, '600000.00');
      expect(mrr.arpuBdt, '2500.00');
      expect(mrr.activeSubscriptionsCount, 20);
      expect(mrr.payingTenantsCount, 20);
      expect(mrr.basicMrrBdt, '10000.00');
      expect(mrr.standardMrrBdt, '20000.00');
      expect(mrr.proMrrBdt, '20000.00');
    });

    test('evaluates MobileOutstandingSummary overdue risk correctly', () {
      final lowRisk = MobileOutstandingSummary.fromJson({
        'total_outstanding_bdt': '5000.00',
        'outstanding_invoices_count': 2,
        'aging_brackets': {
          'current': {'count': 2, 'amount_bdt': '5000.00'},
        },
        'at_risk_tenants_count': 0,
      });
      expect(lowRisk.hasOverdueRisk, isFalse);

      final highRisk = MobileOutstandingSummary.fromJson({
        'total_outstanding_bdt': '25000.00',
        'outstanding_invoices_count': 5,
        'aging_brackets': {
          'days_61_90': {'count': 2, 'amount_bdt': '20000.00'},
        },
        'at_risk_tenants_count': 2,
      });
      expect(highRisk.hasOverdueRisk, isTrue);
    });

    test('creates offline and permissionDenied UI states correctly', () {
      final denied = MobileBillingReportState.permissionDenied('CASHIER');
      expect(denied.status, MobileBillingUiStatus.permissionDenied);
      expect(denied.errorMessageEn, contains("Access denied for role 'CASHIER'"));
      expect(denied.errorMessageBn, contains('বিলিং রিপোর্ট দেখার অনুমতি নেই'));

      final offline = MobileBillingReportState.offline();
      expect(offline.status, MobileBillingUiStatus.offline);
      expect(offline.errorMessageEn, contains('offline'));
      expect(offline.errorMessageBn, contains('অফলাইনে আছে'));
    });
  });
}
