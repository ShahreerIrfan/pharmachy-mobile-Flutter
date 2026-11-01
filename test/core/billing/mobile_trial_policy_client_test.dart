// test/core/billing/mobile_trial_policy_client_test.dart
// Architecture Decision: ADR-0007, ADR-0024 & ADR-0086
// Phase 05: Basic/Standard/Pro Subscription & Billing (P086)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_trial_policy_client.dart';

void main() {
  group('P086 - Mobile Trial Policy Client Tests', () {
    test('Active trial evaluation returns activeTrial state with writes permitted', () {
      final now = DateTime.parse('2026-11-01T12:00:00Z');
      final trialEnd = now.add(const Duration(days: 12));

      final result = MobileTrialPolicyModel.evaluate(
        tenantId: 't-mob-trial-01',
        isTrial: true,
        trialEndsAt: trialEnd,
        now: now,
      );

      expect(result.isTrial, isTrue);
      expect(result.trialState, equals(MobileTrialState.activeTrial));
      expect(result.daysRemaining, equals(12));
      expect(result.isExpired, isFalse);
      expect(result.isWritePermitted, isTrue);
      expect(result.maxBranches, equals(1));
      expect(result.maxDevices, equals(2));
      expect(result.nonDestructiveGuarantee, isTrue);
    });

    test('Expiring soon (2 days left) returns expiringSoon warning state', () {
      final now = DateTime.parse('2026-11-01T12:00:00Z');
      final trialEnd = now.add(const Duration(days: 2));

      final result = MobileTrialPolicyModel.evaluate(
        tenantId: 't-mob-trial-02',
        isTrial: true,
        trialEndsAt: trialEnd,
        now: now,
      );

      expect(result.isTrial, isTrue);
      expect(result.trialState, equals(MobileTrialState.expiringSoon));
      expect(result.daysRemaining, equals(2));
      expect(result.isExpired, isFalse);
      expect(result.isWritePermitted, isTrue);
      expect(result.noticeEn, contains('Urgent'));
    });

    test('Expired trial locks writes and guarantees non-destructive retention', () {
      final now = DateTime.parse('2026-11-01T12:00:00Z');
      final trialEnd = now.subtract(const Duration(days: 1));

      final result = MobileTrialPolicyModel.evaluate(
        tenantId: 't-mob-trial-03',
        isTrial: true,
        trialEndsAt: trialEnd,
        now: now,
      );

      expect(result.isTrial, isTrue);
      expect(result.trialState, equals(MobileTrialState.expired));
      expect(result.daysRemaining, equals(0));
      expect(result.isExpired, isTrue);
      expect(result.isWritePermitted, isFalse);
      expect(result.nonDestructiveGuarantee, isTrue);
      expect(result.noticeEn, contains('locked'));
    });

    test('fromJson deserializes API response payload successfully', () {
      final json = {
        'tenant_id': 't-mob-trial-json',
        'is_trial': true,
        'trial_status': 'EXPIRING_SOON',
        'days_remaining': 1,
        'is_expired': false,
        'is_write_permitted': true,
        'notice_en': 'Urgent: Trial expires soon.',
        'notice_bn': 'জরুরি নোটিশ।',
        'quotas': {
          'max_branches': 1,
          'max_devices': 2,
          'offline_lease_hours': 24,
        },
        'non_destructive_guarantee': true,
      };

      final model = MobileTrialPolicyModel.fromJson(json);
      expect(model.tenantId, equals('t-mob-trial-json'));
      expect(model.trialState, equals(MobileTrialState.expiringSoon));
      expect(model.daysRemaining, equals(1));
      expect(model.maxBranches, equals(1));
      expect(model.maxDevices, equals(2));
      expect(model.nonDestructiveGuarantee, isTrue);
    });
  });
}
