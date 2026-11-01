// test/core/billing/mobile_downgrade_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_downgrade_client.dart';

void main() {
  group('P091 - Mobile Downgrade Client Tests', () {
    test('Status parsing and state predicates evaluate correctly', () {
      expect(MobileSubscriptionDowngradeModel.parseStatus('SCHEDULED'), MobileDowngradeStatus.scheduled);
      expect(MobileSubscriptionDowngradeModel.parseStatus('APPLIED'), MobileDowngradeStatus.applied);
      expect(MobileSubscriptionDowngradeModel.parseStatus('CANCELLED'), MobileDowngradeStatus.cancelled);
      expect(MobileSubscriptionDowngradeModel.parseStatus('UNKNOWN'), MobileDowngradeStatus.unknown);
    });

    test('JSON serialization and parsing handles full downgrade model payload', () {
      final sampleJson = {
        'downgrade_id': 'dwn-0123456789abcdef',
        'tenant_id': 'tn-test-pharmacy',
        'subscription_id': 'sub-test-001',
        'from_plan_tier': 'PRO',
        'from_plan_code': 'PLAN_PRO',
        'to_plan_tier': 'BASIC',
        'to_plan_code': 'PLAN_BASIC',
        'effective_mode': 'IMMEDIATE',
        'quota_assessment': {
          'current_active_branches': 3,
          'target_allowed_branches': 1,
          'is_over_quota': true,
          'retained_branch_ids': ['branch-01'],
          'locked_branch_ids': ['branch-02', 'branch-03'],
        },
        'data_retention_guarantee': {
          'zero_data_deleted': true,
          'historical_sales_readable': true,
          'stock_ledger_preserved': true,
        },
        'status': 'APPLIED',
        'applied_entitlement_id': 'ent_fedcba9876543210',
        'created_at': '2026-11-01T12:00:00Z',
        'executed_at': '2026-11-01T12:00:01Z',
      };

      final model = MobileSubscriptionDowngradeModel.fromJson(sampleJson);

      expect(model.downgradeId, 'dwn-0123456789abcdef');
      expect(model.fromPlanTier, 'PRO');
      expect(model.toPlanTier, 'BASIC');
      expect(model.isApplied, isTrue);
      expect(model.isOverQuota, isTrue);
      expect(model.quotaAssessment.lockedBranchIds.length, 2);
      expect(model.dataRetentionGuarantee.zeroDataDeleted, isTrue);
      expect(model.dataRetentionGuarantee.historicalSalesReadable, isTrue);
    });
  });
}
