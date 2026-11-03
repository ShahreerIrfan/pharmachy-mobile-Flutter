// test/core/catalog/mobile_form_template_migration_client_test.dart
// Architecture Decision: ADR-0139
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P139)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_form_template_migration_client.dart';

void main() {
  group('P139: MobileFormTemplateMigrationClient Unit & Integration Tests', () {
    late MobileFormTemplateMigrationClient client;
    const testTenant1 = 'tn-mob-dhanmondi-101';
    const testTenant2 = 'tn-mob-gulshan-202';

    setUp(() {
      client = MobileFormTemplateMigrationClient();
    });

    test('P139-M1: Valid plan creation generates 64-char SHA-256 hash and DRAFT state', () {
      final res = client.createPlan(
        tenantId: testTenant1,
        planName: 'Tablet v1.0 to v2.0 Mobile Upgrade',
        fromTemplateId: 'tmpl-tablet-v1',
        toTemplateId: 'tmpl-tablet-v2',
        strategy: 'COERCE_SAFE',
        fieldMappings: {'scored_tablet': true},
        userRole: 'STAFF_PHARMACIST',
        planTier: 'STANDARD',
      );

      expect(res.status, equals(MobileMigrationUiStatus.success));
      expect(res.data, isNotNull);
      expect(res.data!.status, equals(MobileMigrationPlanStatus.draft));
      expect(res.data!.planHash.length, equals(64));
      expect(res.data!.fromTemplateId, equals('tmpl-tablet-v1'));
      expect(res.data!.toTemplateId, equals('tmpl-tablet-v2'));
    });

    test('P139-M2: Dry-run validation audits historical immutability and sets VALIDATED status', () {
      final created = client.createPlan(
        tenantId: testTenant1,
        planName: 'Dry Run Validation Plan',
        fromTemplateId: 'tmpl-tablet-v1',
        toTemplateId: 'tmpl-tablet-v2',
        userRole: 'PHARMACY_OWNER',
      );
      final planId = created.data!.planId;

      final dryRes = client.validateDryRun(
        planId: planId,
        userRole: 'PHARMACY_OWNER',
        requestTenantId: testTenant1,
        simulatedMedicineCount: 35,
        simulatedDispenseCount: 140,
      );

      expect(dryRes.status, equals(MobileMigrationUiStatus.success));
      expect(dryRes.data!.status, equals(MobileMigrationPlanStatus.validated));
      expect(dryRes.data!.affectedMedicineCount, equals(35));
      expect(dryRes.data!.historicalDispensingAuditedCount, equals(140));
      expect(dryRes.data!.dryRunSummary['historical_immutability_certified'], isTrue);
    });

    test('P139-M3: Execution updates plan to COMPLETED, records execution timestamp, blocks double execution', () {
      final created = client.createPlan(
        tenantId: testTenant1,
        planName: 'Execution Test Plan',
        fromTemplateId: 'tmpl-tablet-v1',
        toTemplateId: 'tmpl-tablet-v2',
        userRole: 'PHARMACY_OWNER',
      );
      final planId = created.data!.planId;

      client.validateDryRun(
        planId: planId,
        userRole: 'PHARMACY_OWNER',
        requestTenantId: testTenant1,
        simulatedMedicineCount: 12,
        simulatedDispenseCount: 48,
      );

      final execRes = client.executePlan(
        planId: planId,
        userRole: 'PHARMACY_OWNER',
        requestTenantId: testTenant1,
      );

      expect(execRes.status, equals(MobileMigrationUiStatus.success));
      expect(execRes.data!.status, equals(MobileMigrationPlanStatus.completed));
      expect(execRes.data!.executedAt, isNotNull);
      expect(execRes.data!.migratedMedicineCount, equals(12));

      // Attempt double execution
      final reExec = client.executePlan(
        planId: planId,
        userRole: 'PHARMACY_OWNER',
        requestTenantId: testTenant1,
      );
      expect(reExec.status, equals(MobileMigrationUiStatus.error));
      expect(reExec.errorCode, equals('ERR_ALREADY_EXECUTED'));
    });

    test('P139-M4: Rollback safely reverts COMPLETED plan to ROLLED_BACK using stored snapshot', () {
      final created = client.createPlan(
        tenantId: testTenant1,
        planName: 'Rollback Test Plan',
        fromTemplateId: 'tmpl-tablet-v1',
        toTemplateId: 'tmpl-tablet-v2',
        userRole: 'PHARMACY_OWNER',
      );
      final planId = created.data!.planId;

      client.validateDryRun(
        planId: planId,
        userRole: 'PHARMACY_OWNER',
        requestTenantId: testTenant1,
        simulatedMedicineCount: 10,
        simulatedDispenseCount: 30,
      );
      client.executePlan(
        planId: planId,
        userRole: 'PHARMACY_OWNER',
        requestTenantId: testTenant1,
      );

      final rollbackRes = client.rollbackPlan(
        planId: planId,
        userRole: 'PHARMACY_OWNER',
        requestTenantId: testTenant1,
      );

      expect(rollbackRes.status, equals(MobileMigrationUiStatus.success));
      expect(rollbackRes.data!.status, equals(MobileMigrationPlanStatus.rolledBack));
      expect(rollbackRes.data!.rolledBackAt, isNotNull);
    });

    test('P139-M5: Cashier role and unentitled Basic plan are blocked with PERMISSION_DENIED', () {
      // Cashier denied
      final cashierRes = client.createPlan(
        tenantId: testTenant1,
        planName: 'Cashier Attempt',
        fromTemplateId: 'tmpl-tablet-v1',
        toTemplateId: 'tmpl-tablet-v2',
        userRole: 'CASHIER',
      );
      expect(cashierRes.status, equals(MobileMigrationUiStatus.permissionDenied));
      expect(cashierRes.errorCode, equals('ERR_PERMISSION_DENIED'));

      // Basic tier denied
      final basicRes = client.createPlan(
        tenantId: testTenant1,
        planName: 'Basic Tier Attempt',
        fromTemplateId: 'tmpl-tablet-v1',
        toTemplateId: 'tmpl-tablet-v2',
        userRole: 'PHARMACY_OWNER',
        planTier: 'BASIC',
      );
      expect(basicRes.status, equals(MobileMigrationUiStatus.permissionDenied));
      expect(basicRes.errorCode, equals('ERR_SUBSCRIPTION_UNENTITLED'));
    });

    test('P139-M6: Cross-tenant access is blocked and offline query serves from local cache', () {
      final created = client.createPlan(
        tenantId: testTenant1,
        planName: 'Tenant 1 Exclusive Plan',
        fromTemplateId: 'tmpl-tablet-v1',
        toTemplateId: 'tmpl-tablet-v2',
        userRole: 'PHARMACY_OWNER',
      );
      final planId = created.data!.planId;

      // Cross-tenant execution denied
      final crossExec = client.executePlan(
        planId: planId,
        userRole: 'PHARMACY_OWNER',
        requestTenantId: testTenant2,
      );
      expect(crossExec.status, equals(MobileMigrationUiStatus.permissionDenied));
      expect(crossExec.errorCode, equals('ERR_CROSS_TENANT_ACCESS'));

      // Offline query serves cached plan
      client.setOffline(true);
      final offlineQuery = client.queryPlan(
        planId: planId,
        requestTenantId: testTenant1,
      );
      expect(offlineQuery.status, equals(MobileMigrationUiStatus.offline));
      expect(offlineQuery.data, isNotNull);
      expect(offlineQuery.data!.planId, equals(planId));
    });
  });
}
