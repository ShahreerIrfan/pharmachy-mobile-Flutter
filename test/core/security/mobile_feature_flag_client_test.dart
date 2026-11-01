import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_feature_flag_client.dart';

void main() {
  group('ADR-0072: Flutter Mobile Feature Flag Client Tests', () {
    test('Role RBAC: Only SuperAdmin and Platform Operator can mutate flags',
        () {
      expect(MobileFeatureFlagClient.canRoleMutateFlags('SUPERADMIN'), isTrue);
      expect(MobileFeatureFlagClient.canRoleMutateFlags('SUPER_ADMIN'), isTrue);
      expect(MobileFeatureFlagClient.canRoleMutateFlags('PLATFORM_OPERATOR'),
          isTrue);

      expect(MobileFeatureFlagClient.canRoleMutateFlags('PHARMACY_OWNER'),
          isFalse);
      expect(MobileFeatureFlagClient.canRoleMutateFlags('BRANCH_MANAGER'),
          isFalse);
      expect(MobileFeatureFlagClient.canRoleMutateFlags('STAFF_PHARMACIST'),
          isFalse);
      expect(MobileFeatureFlagClient.canRoleMutateFlags('CASHIER'), isFalse);
      expect(MobileFeatureFlagClient.canRoleMutateFlags(null), isFalse);
    });

    test('Flag key validation: Must match kebab/snake alphanumeric format', () {
      expect(
          MobileFeatureFlagClient.isValidFlagKey('mobile_quick_sale'), isTrue);
      expect(MobileFeatureFlagClient.isValidFlagKey('dark-mode-v2'), isTrue);

      expect(MobileFeatureFlagClient.isValidFlagKey('ab'), isFalse);
      expect(MobileFeatureFlagClient.isValidFlagKey('Invalid Key!'), isFalse);
      expect(MobileFeatureFlagClient.isValidFlagKey(null), isFalse);
    });

    test('Deterministic rollout bucket calculation', () {
      final bucket1 = MobileFeatureFlagClient.calculateRolloutBucket(
          'test_flag', 'tenant-1');
      final bucket2 = MobileFeatureFlagClient.calculateRolloutBucket(
          'test_flag', 'tenant-1');
      expect(bucket1, equals(bucket2));
      expect(bucket1 >= 0 && bucket1 < 100, isTrue);
    });

    test('Evaluation Hierarchy: Kill switch overrides all other conditions',
        () {
      final res = MobileFeatureFlagClient.evaluateLocal(
        isKillSwitchActive: true,
        tenantOverride: true,
        tenantPlanTier: 'PRO',
        minPlanTier: 'BASIC',
        rolloutPercentage: 100,
        isEnabledGlobally: true,
        defaultEnabled: true,
      );
      expect(res.isEnabled, isFalse);
      expect(res.reason, equals('KILL_SWITCH_ACTIVE'));
    });

    test(
        'Evaluation Hierarchy: Tenant override takes precedence over plan and rollout',
        () {
      final resDisabled = MobileFeatureFlagClient.evaluateLocal(
        isKillSwitchActive: false,
        tenantOverride: false,
        tenantPlanTier: 'PRO',
        minPlanTier: 'BASIC',
        rolloutPercentage: 100,
        isEnabledGlobally: true,
        defaultEnabled: true,
      );
      expect(resDisabled.isEnabled, isFalse);
      expect(resDisabled.reason, equals('TENANT_OVERRIDE'));

      final resEnabled = MobileFeatureFlagClient.evaluateLocal(
        isKillSwitchActive: false,
        tenantOverride: true,
        tenantPlanTier: 'BASIC',
        minPlanTier: 'PRO',
        rolloutPercentage: 0,
        isEnabledGlobally: false,
        defaultEnabled: false,
      );
      expect(resEnabled.isEnabled, isTrue);
      expect(resEnabled.reason, equals('TENANT_OVERRIDE'));
    });

    test('Evaluation Hierarchy: Plan Tier gate restricts insufficient plans',
        () {
      final res = MobileFeatureFlagClient.evaluateLocal(
        isKillSwitchActive: false,
        tenantPlanTier: 'BASIC',
        minPlanTier: 'PRO',
        rolloutPercentage: 100,
        isEnabledGlobally: true,
      );
      expect(res.isEnabled, isFalse);
      expect(res.reason, equals('PLAN_TIER_INSUFFICIENT'));
    });

    test(
        'Evaluation Hierarchy: Rollout, global enable and safe default fallback',
        () {
      final res100 = MobileFeatureFlagClient.evaluateLocal(
        isKillSwitchActive: false,
        tenantPlanTier: 'PRO',
        minPlanTier: 'BASIC',
        rolloutPercentage: 100,
      );
      expect(res100.isEnabled, isTrue);
      expect(res100.reason, equals('ROLLOUT_PERCENTAGE_INCLUDED'));

      final resGlobal = MobileFeatureFlagClient.evaluateLocal(
        isKillSwitchActive: false,
        tenantPlanTier: 'STANDARD',
        minPlanTier: 'BASIC',
        rolloutPercentage: 0,
        isEnabledGlobally: true,
      );
      expect(resGlobal.isEnabled, isTrue);
      expect(resGlobal.reason, equals('GLOBAL_ENABLED'));

      final resDefault = MobileFeatureFlagClient.evaluateLocal(
        isKillSwitchActive: false,
        tenantPlanTier: 'STANDARD',
        minPlanTier: 'BASIC',
        rolloutPercentage: 0,
        isEnabledGlobally: false,
        defaultEnabled: false,
      );
      expect(resDefault.isEnabled, isFalse);
      expect(resDefault.reason, equals('SAFE_DEFAULT'));
    });

    test('Builds endpoint URLs correctly', () {
      expect(MobileFeatureFlagClient.buildPlatformFlagsUrl(),
          equals('/api/v2/platform/feature-flags/'));
      expect(
        MobileFeatureFlagClient.buildPlatformFlagDetailUrl('mobile_pay'),
        equals('/api/v2/platform/feature-flags/mobile_pay/'),
      );
      expect(
        MobileFeatureFlagClient.buildKillSwitchUrl('mobile_pay'),
        equals('/api/v2/platform/feature-flags/mobile_pay/kill-switch/'),
      );
      expect(
        MobileFeatureFlagClient.buildTenantOverrideUrl('mobile_pay'),
        equals('/api/v2/platform/feature-flags/mobile_pay/tenant-override/'),
      );
      expect(
        MobileFeatureFlagClient.buildTenantEvalUrl(flagKey: 'mobile_pay'),
        equals('/api/v2/tenants/feature-flags/eval/?flag_key=mobile_pay'),
      );
      expect(
        MobileFeatureFlagClient.buildTenantEvalUrl(),
        equals('/api/v2/tenants/feature-flags/eval/'),
      );

      expect(
          () => MobileFeatureFlagClient.buildPlatformFlagDetailUrl('bad key!'),
          throwsArgumentError);
    });
  });
}
