import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_cross_tenant_metrics_client.dart';

void main() {
  group('ADR-0075: Flutter Mobile Cross-Tenant Metrics Client Tests', () {
    test('Role RBAC: Only SuperAdmin and Platform Operator can manage platform metrics', () {
      expect(MobileCrossTenantMetricsClient.canRoleManagePlatformMetrics('SUPERADMIN'), isTrue);
      expect(MobileCrossTenantMetricsClient.canRoleManagePlatformMetrics('SUPER_ADMIN'), isTrue);
      expect(MobileCrossTenantMetricsClient.canRoleManagePlatformMetrics('PLATFORM_OPERATOR'), isTrue);

      expect(MobileCrossTenantMetricsClient.canRoleManagePlatformMetrics('PHARMACY_OWNER'), isFalse);
      expect(MobileCrossTenantMetricsClient.canRoleManagePlatformMetrics('BRANCH_MANAGER'), isFalse);
      expect(MobileCrossTenantMetricsClient.canRoleManagePlatformMetrics('CASHIER'), isFalse);
      expect(MobileCrossTenantMetricsClient.canRoleManagePlatformMetrics(null), isFalse);
    });

    test('Role RBAC: Pharmacy Owner and Managers can view benchmarks; Cashier blocked', () {
      expect(MobileCrossTenantMetricsClient.canRoleViewBenchmarks('SUPERADMIN'), isTrue);
      expect(MobileCrossTenantMetricsClient.canRoleViewBenchmarks('PHARMACY_OWNER'), isTrue);
      expect(MobileCrossTenantMetricsClient.canRoleViewBenchmarks('BRANCH_MANAGER'), isTrue);
      expect(MobileCrossTenantMetricsClient.canRoleViewBenchmarks('STORE_MANAGER'), isTrue);
      expect(MobileCrossTenantMetricsClient.canRoleViewBenchmarks('ADMIN'), isTrue);

      expect(MobileCrossTenantMetricsClient.canRoleViewBenchmarks('CASHIER'), isFalse);
      expect(MobileCrossTenantMetricsClient.canRoleViewBenchmarks('STAFF_PHARMACIST'), isFalse);
      expect(MobileCrossTenantMetricsClient.canRoleViewBenchmarks(null), isFalse);
    });

    test('Snapshot ID syntax: Must match ctm- prefix and 8-64 alphanumeric chars', () {
      expect(MobileCrossTenantMetricsClient.isValidSnapshotId('ctm-a1b2c3d4e5f6'), isTrue);
      expect(MobileCrossTenantMetricsClient.isValidSnapshotId('ctm-october-metrics-2026'), isTrue);

      expect(MobileCrossTenantMetricsClient.isValidSnapshotId('invalid-prefix-12345'), isFalse);
      expect(MobileCrossTenantMetricsClient.isValidSnapshotId('ctm-short'), isFalse);
      expect(MobileCrossTenantMetricsClient.isValidSnapshotId(null), isFalse);
      expect(MobileCrossTenantMetricsClient.isValidSnapshotId(''), isFalse);
    });

    test('k-Anonymity: Cohorts with fewer tenants than threshold must be suppressed', () {
      expect(MobileCrossTenantMetricsClient.isCohortSuppressed(1, 3), isTrue);
      expect(MobileCrossTenantMetricsClient.isCohortSuppressed(2, 3), isTrue);
      expect(MobileCrossTenantMetricsClient.isCohortSuppressed(3, 3), isFalse);
      expect(MobileCrossTenantMetricsClient.isCohortSuppressed(10, 3), isFalse);

      expect(MobileCrossTenantMetricsClient.isCohortSuppressed(4, 5), isTrue);
      expect(MobileCrossTenantMetricsClient.isCohortSuppressed(5, 5), isFalse);
    });

    test('Zero-PHI Guarantee: Detects and rejects payloads containing patient identifiers', () {
      const cleanJson = '{"clinical_metrics": {"total_prescriptions": 500, "antibiotic_ratio_pct": "12.50"}}';
      expect(MobileCrossTenantMetricsClient.validateZeroPhiGuaranteed(cleanJson), isTrue);

      const dirtyJson1 = '{"clinical_metrics": {"patient_name": "Mr. Rahim", "total": 500}}';
      expect(MobileCrossTenantMetricsClient.validateZeroPhiGuaranteed(dirtyJson1), isFalse);

      const dirtyJson2 = '{"data": {"patient_phone": "01700000000"}}'; // synthetic-fixture
      expect(MobileCrossTenantMetricsClient.validateZeroPhiGuaranteed(dirtyJson2), isFalse);

      const dirtyJson3 = '{"doctor_license": "BMDC-12345"}';
      expect(MobileCrossTenantMetricsClient.validateZeroPhiGuaranteed(dirtyJson3), isFalse);
    });

    test('Lifecycle State Machine: Strict transitions for metric snapshots', () {
      expect(MobileCrossTenantMetricsClient.isValidStateTransition('DRAFT', 'PUBLISHED'), isTrue);
      expect(MobileCrossTenantMetricsClient.isValidStateTransition('DRAFT', 'ARCHIVED'), isTrue);
      expect(MobileCrossTenantMetricsClient.isValidStateTransition('PUBLISHED', 'ARCHIVED'), isTrue);
      expect(MobileCrossTenantMetricsClient.isValidStateTransition('PUBLISHED', 'PUBLISHED'), isTrue);

      expect(MobileCrossTenantMetricsClient.isValidStateTransition('ARCHIVED', 'PUBLISHED'), isFalse);
      expect(MobileCrossTenantMetricsClient.isValidStateTransition('ARCHIVED', 'DRAFT'), isFalse);
      expect(MobileCrossTenantMetricsClient.isValidStateTransition(null, 'DRAFT'), isFalse);
    });

    test('URL Builders: Accurately format platform and tenant REST endpoints', () {
      final platformList = MobileCrossTenantMetricsClient.buildPlatformMetricsUrl('https://api.pharmacy.bd');
      expect(platformList, equals('https://api.pharmacy.bd/api/v2/platform/cross-tenant-metrics/'));

      final platformDetail = MobileCrossTenantMetricsClient.buildPlatformMetricsUrl('https://api.pharmacy.bd', 'ctm-a1b2c3d4e5f6');
      expect(platformDetail, equals('https://api.pharmacy.bd/api/v2/platform/cross-tenant-metrics/ctm-a1b2c3d4e5f6/'));

      final benchmarkUrl = MobileCrossTenantMetricsClient.buildTenantBenchmarkUrl('https://api.pharmacy.bd', 'tenant-dhaka-01');
      expect(benchmarkUrl, equals('https://api.pharmacy.bd/api/v2/analytics/platform-benchmarks/?tenant_id=tenant-dhaka-01'));

      expect(() => MobileCrossTenantMetricsClient.buildPlatformMetricsUrl('https://api.pharmacy.bd', 'bad-id'),
          throwsArgumentError);
    });

    test('Localization: Returns non-empty EN and BN suppression messages', () {
      final en = MobileCrossTenantMetricsClient.getLocalizedSuppressionMessage(false);
      final bn = MobileCrossTenantMetricsClient.getLocalizedSuppressionMessage(true);

      expect(en, contains('Privacy Guardrail'));
      expect(bn, contains('গোপনীয়তা'));
    });
  });
}
