// test/core/billing/mobile_cancellation_grace_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_cancellation_grace_client.dart';

void main() {
  group('P092 - Mobile Cancellation and Grace Client Tests', () {
    test('Status parsing accurately resolves all subscription lifecycle states', () {
      expect(MobileSubscriptionLifecycleModel.parseStatus('ACTIVE'), MobileSubscriptionLifecycleStatus.active);
      expect(MobileSubscriptionLifecycleModel.parseStatus('GRACE_PERIOD'), MobileSubscriptionLifecycleStatus.gracePeriod);
      expect(MobileSubscriptionLifecycleModel.parseStatus('EXPIRED'), MobileSubscriptionLifecycleStatus.expired);
      expect(MobileSubscriptionLifecycleModel.parseStatus('CANCELLED'), MobileSubscriptionLifecycleStatus.cancelled);
      expect(MobileSubscriptionLifecycleModel.parseStatus('SUSPENDED'), MobileSubscriptionLifecycleStatus.suspended);
      expect(MobileSubscriptionLifecycleModel.parseStatus('UNKNOWN'), MobileSubscriptionLifecycleStatus.unknown);
    });

    test('JSON serialization and parsing handles full lifecycle status payload', () {
      final sampleJson = {
        'tenant_id': 'tn-demo-pharmacy',
        'subscription_id': 'sub-demo-1234',
        'plan_tier': 'STANDARD',
        'status': 'GRACE_PERIOD',
        'lifecycle_details': {
          'renewal_date': '2026-10-31',
          'in_grace_period': true,
          'grace_period_days_remaining': 12,
          'grace_period_end_date': '2026-11-15',
          'is_auto_renew': false,
          'cancel_at_period_end': false,
          'cancellation_reason': null,
        },
        'owner_messaging': {
          'headline_en': 'Grace Period Active (12 Days Remaining)',
          'headline_bn': 'গ্রেস পিরিয়ড কার্যকর রয়েছে (অবশিষ্ট ১২ দিন)',
          'details_en': 'Billing lapsed. Operational sales continue to protect patient care.',
          'details_bn': 'সাবস্ক্রিপশনের মেয়াদ শেষ হয়েছে। রোগীর সেবা নিশ্চিত করতে বিক্রয় সচল রয়েছে।',
          'action_required': 'PAY_RENEWAL_INVOICE',
        },
        'permissions': {
          'can_dispense_sales': true,
          'can_read_historical_data': true,
          'can_export_tenant_data': true,
          'zero_data_deleted': true,
        },
      };

      final model = MobileSubscriptionLifecycleModel.fromJson(sampleJson);

      expect(model.tenantId, 'tn-demo-pharmacy');
      expect(model.status, MobileSubscriptionLifecycleStatus.gracePeriod);
      expect(model.inGracePeriod, isTrue);
      expect(model.canDispense, isTrue);
      expect(model.permissions.canReadHistoricalData, isTrue);
      expect(model.permissions.canExportTenantData, isTrue);
      expect(model.permissions.zeroDataDeleted, isTrue);
      expect(model.lifecycleDetails.gracePeriodDaysRemaining, 12);
    });
  });
}
