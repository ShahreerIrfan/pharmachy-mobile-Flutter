// test/core/billing/mobile_customer_portal_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_customer_portal_client.dart';

void main() {
  group('P097 - Mobile Customer Portal Client Tests', () {
    test('Parses MobileActivePackage correctly and verifies active state', () {
      final jsonPkg = {
        'plan_code': 'PLAN_STANDARD',
        'plan_tier': 'STANDARD',
        'plan_name': 'Standard Pharmacy Plan',
        'billing_cycle': 'MONTHLY',
        'status': 'ACTIVE',
        'price_bdt': '3500.00',
        'currency': 'BDT',
        'period_start': '2026-11-01',
        'period_end': '2026-12-01',
        'auto_renew': true,
      };

      final pkg = MobileActivePackage.fromJson(jsonPkg);

      expect(pkg.planCode, 'PLAN_STANDARD');
      expect(pkg.planTier, 'STANDARD');
      expect(pkg.isActive, isTrue);
      expect(pkg.isGracePeriod, isFalse);
      expect(pkg.autoRenew, isTrue);
      expect(pkg.priceBdt, '3500.00');
    });

    test('Parses MobileNextRenewal and detects due soon state', () {
      final renJson = {
        'renewal_date': '2026-11-05',
        'days_remaining': 4,
        'projected_amount_bdt': '3500.00',
        'auto_renew': true,
      };

      final renewal = MobileNextRenewal.fromJson(renJson);

      expect(renewal.daysRemaining, 4);
      expect(renewal.isDueSoon, isTrue);
    });

    test('Parses complete MobileCustomerPortalResponse with invariants and invoices', () {
      final responseJson = {
        'tenant_id': 'tn-portal-mob-01',
        'active_package': {
          'plan_code': 'PLAN_STANDARD',
          'plan_tier': 'STANDARD',
          'plan_name': 'Standard Plan',
          'billing_cycle': 'MONTHLY',
          'status': 'ACTIVE',
          'price_bdt': '3500.00',
          'currency': 'BDT',
          'period_start': '2026-11-01',
          'period_end': '2026-12-01',
          'auto_renew': true,
        },
        'next_renewal': {
          'renewal_date': '2026-12-01',
          'days_remaining': 30,
          'projected_amount_bdt': '3500.00',
          'auto_renew': true,
        },
        'invoices': [
          {
            'invoice_number': 'REN-INV-202611-001',
            'period_start': '2026-11-01',
            'period_end': '2026-12-01',
            'subtotal_bdt': '3333.33',
            'tax_amount_bdt': '166.67',
            'total_bdt': '3500.00',
            'status': 'PAID',
          }
        ],
        'payment_history': [
          {
            'reference': 'BKASH-TRX-998877',
            'payment_method': 'MANUAL_BKASH',
            'amount_bdt': '3500.00',
            'status': 'APPROVED',
            'paid_at': '2026-11-01',
          }
        ],
        'quota_usage': {
          'overall_status': 'OK',
          'counters': {},
        },
        'upgrade_options': [
          {
            'plan_code': 'PLAN_PRO',
            'tier': 'PRO',
            'name': 'Enterprise Plan',
            'monthly_price_bdt': '8000.00',
            'annual_price_bdt': '80000.00',
          }
        ],
        'invariants': {
          'zero_data_deleted': true,
          'safe_export_retained': true,
          'authoritative_sync': true,
        },
        'client_messaging': {
          'headline_en': 'Subscription Active',
          'headline_bn': 'সাবস্ক্রিপশন সক্রিয়',
          'details_en': 'Details',
          'details_bn': 'বিবরণ',
        },
      };

      final response = MobileCustomerPortalResponse.fromJson(responseJson);

      expect(response.tenantId, 'tn-portal-mob-01');
      expect(response.activePackage.planTier, 'STANDARD');
      expect(response.invoices.length, 1);
      expect(response.invoices[0].isPaid, isTrue);
      expect(response.paymentHistory.length, 1);
      expect(response.upgradeOptionsCount, 1);
      expect(response.zeroDataDeleted, isTrue);
      expect(response.safeExportRetained, isTrue);
      expect(response.authoritativeSync, isTrue);
      expect(response.headlineBn, contains('সাবস্ক্রিপশন সক্রিয়'));
    });
  });
}

