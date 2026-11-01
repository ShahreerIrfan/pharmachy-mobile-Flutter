// test/core/billing/mobile_quota_usage_counter_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_quota_usage_counter_client.dart';

void main() {
  group('P095 - Mobile Quota Usage Counter Client Tests', () {
    test('Calculates utilization percentage and resource status correctly', () {
      expect(MobileQuotaUsageEvaluator.calculateUtilizationPct(0, 0), 0.0);
      expect(MobileQuotaUsageEvaluator.calculateUtilizationPct(4, 5), 80.0);
      expect(MobileQuotaUsageEvaluator.calculateUtilizationPct(1, 3), 33.3);

      expect(MobileQuotaUsageEvaluator.evaluateResourceStatus(3, 10), 'NORMAL');
      expect(MobileQuotaUsageEvaluator.evaluateResourceStatus(8, 10), 'WARNING');
      expect(MobileQuotaUsageEvaluator.evaluateResourceStatus(10, 10), 'LIMIT_REACHED');
      expect(MobileQuotaUsageEvaluator.evaluateResourceStatus(11, 10), 'OVER_QUOTA');
    });

    test('Parses Quota Usage Report from JSON accurately with invariants', () {
      final jsonPayload = {
        'tenant_id': 'tn-p095-mob',
        'plan_code': 'PLAN_PRO',
        'plan_tier': 'PRO',
        'overall_status': 'NEAR_LIMIT',
        'counters': {
          'BRANCHES': {
            'resource_type': 'BRANCHES',
            'current_used': 2,
            'max_limit': 10,
            'remaining': 8,
            'utilization_pct': 20.0,
            'is_over_quota': false,
            'status': 'NORMAL',
          },
          'STAFF_SEATS': {
            'resource_type': 'STAFF_SEATS',
            'current_used': 20,
            'max_limit': 25,
            'remaining': 5,
            'utilization_pct': 80.0,
            'is_over_quota': false,
            'status': 'WARNING',
          },
          'DEVICES': {
            'resource_type': 'DEVICES',
            'current_used': 6,
            'max_limit': 15,
            'remaining': 9,
            'utilization_pct': 40.0,
            'is_over_quota': false,
            'status': 'NORMAL',
          },
        },
        'invariants': {
          'zero_data_deleted': true,
          'race_condition_safe': true,
          'authoritative_locking': true,
        },
        'client_messaging': {
          'headline_en': 'Plan Quota Near Capacity',
          'headline_bn': 'কোটা ধারণক্ষমতার কাছাকাছি পৌঁছেছে',
          'details_en': 'Resource usage is above 80% of allowed plan limits.',
          'details_bn': 'রিসোর্স ব্যবহার অনুমোদিত সীমার ৮০% এর বেশি পৌঁছেছে।',
        },
      };

      final report = MobileQuotaUsageReport.fromJson(jsonPayload);

      expect(report.tenantId, 'tn-p095-mob');
      expect(report.planTier, 'PRO');
      expect(report.overallStatus, 'NEAR_LIMIT');
      expect(report.isNearLimit, isTrue);
      expect(report.isOverQuota, isFalse);
      expect(report.zeroDataDeleted, isTrue);
      expect(report.raceConditionSafe, isTrue);
      expect(report.authoritativeLocking, isTrue);

      final staff = report.counters['STAFF_SEATS']!;
      expect(staff.currentUsed, 20);
      expect(staff.maxLimit, 25);
      expect(staff.remaining, 5);
      expect(staff.utilizationPct, 80.0);
      expect(staff.status, 'WARNING');

      expect(report.headlineBn, contains('কাছাকাছি পৌঁছেছে'));
    });

    test('Evaluates quota summary states and bilingual messaging', () {
      // 1. OK state
      final ok = MobileQuotaUsageEvaluator.evaluateSummary(
        tenantId: 'tn-01',
        planTier: 'STANDARD',
        branchesUsed: 1,
        branchesLimit: 3,
        staffUsed: 4,
        staffLimit: 10,
        devicesUsed: 2,
        devicesLimit: 5,
      );
      expect(ok.isOk, isTrue);
      expect(ok.headlineEn, contains('Good Standing'));
      expect(ok.headlineBn, contains('স্বাভাবিক রয়েছে'));

      // 2. Limit reached
      final limitReached = MobileQuotaUsageEvaluator.evaluateSummary(
        tenantId: 'tn-01',
        planTier: 'STANDARD',
        branchesUsed: 3,
        branchesLimit: 3,
        staffUsed: 4,
        staffLimit: 10,
        devicesUsed: 2,
        devicesLimit: 5,
      );
      expect(limitReached.isLimitReached, isTrue);
      expect(limitReached.headlineBn, contains('কোটা সীমা পূর্ণ হয়েছে'));

      // 3. Over quota
      final overQuota = MobileQuotaUsageEvaluator.evaluateSummary(
        tenantId: 'tn-01',
        planTier: 'STANDARD',
        branchesUsed: 4,
        branchesLimit: 3,
        staffUsed: 4,
        staffLimit: 10,
        devicesUsed: 2,
        devicesLimit: 5,
      );
      expect(overQuota.isOverQuota, isTrue);
      expect(overQuota.headlineEn, contains('Plan Quota Exceeded'));
      expect(overQuota.headlineBn, contains('সাবস্ক্রিপশন কোটা অতিক্রম করেছে'));
    });
  });
}

