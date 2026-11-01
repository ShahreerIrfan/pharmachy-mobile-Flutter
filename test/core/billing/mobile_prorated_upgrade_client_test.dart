// test/core/billing/mobile_prorated_upgrade_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_prorated_upgrade_client.dart';

void main() {
  group('P090 - Mobile Prorated Upgrade Client Tests', () {
    test('Status parsing and state predicates evaluate correctly', () {
      expect(MobileProratedUpgradeModel.parseStatus('QUOTED'), MobileUpgradeStatus.quoted);
      expect(MobileProratedUpgradeModel.parseStatus('PENDING_PAYMENT'), MobileUpgradeStatus.pendingPayment);
      expect(MobileProratedUpgradeModel.parseStatus('COMPLETED'), MobileUpgradeStatus.completed);
      expect(MobileProratedUpgradeModel.parseStatus('CANCELLED'), MobileUpgradeStatus.cancelled);
      expect(MobileProratedUpgradeModel.parseStatus('UNKNOWN_STATUS'), MobileUpgradeStatus.unknown);
    });

    test('JSON serialization and parsing handles full upgrade model payload', () {
      final sampleJson = {
        'upgrade_id': 'upg-9876543210abcdef',
        'tenant_id': 'tn-demo-pharmacy',
        'subscription_id': 'sub-demo-001',
        'from_plan_tier': 'BASIC',
        'from_plan_code': 'PLAN_BASIC',
        'from_billing_cycle': 'MONTHLY',
        'to_plan_tier': 'STANDARD',
        'to_plan_code': 'PLAN_STANDARD',
        'to_billing_cycle': 'MONTHLY',
        'transition_timestamp': '2026-11-01T12:00:00Z',
        'proration_days': {
          'total_days': 30,
          'used_days': 10,
          'remaining_days': 20,
        },
        'financials': {
          'current_plan_amount_bdt': 1500.0,
          'current_daily_rate_bdt': 50.0,
          'unused_credit_bdt': 1000.0,
          'target_plan_amount_bdt': 3500.0,
          'target_daily_rate_bdt': 116.6667,
          'prorated_target_gross_bdt': 2333.33,
          'tax_amount_bdt': 0.0,
          'net_payable_bdt': 1333.33,
        },
        'status': 'COMPLETED',
        'invoice_number': 'INV-UPG-202611-TN0001',
        'invoice_id': 'ren-inv-12345678',
        'immediate_entitlement_granted': true,
        'applied_entitlement_id': 'ent_abcdef0123456789',
      };

      final model = MobileProratedUpgradeModel.fromJson(sampleJson);

      expect(model.upgradeId, 'upg-9876543210abcdef');
      expect(model.fromPlanTier, 'BASIC');
      expect(model.toPlanTier, 'STANDARD');
      expect(model.prorationDays.remainingDays, 20);
      expect(model.financials.unusedCreditBdt, 1000.0);
      expect(model.financials.netPayableBdt, 1333.33);
      expect(model.isCompleted, isTrue);
      expect(model.immediateEntitlementGranted, isTrue);
    });

    test('formatBdt renders Bangladeshi Taka symbol and 2 decimal places', () {
      expect(MobileProratedUpgradeModel.formatBdt(1333.333), '৳1333.33');
      expect(MobileProratedUpgradeModel.formatBdt(0.0), '৳0.00');
    });
  });
}
