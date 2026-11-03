// test/core/catalog/mobile_catalogue_service_contract_client_test.dart
// Architecture Decision: ADR-0140
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P140)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_catalogue_service_contract_client.dart';

void main() {
  group('P140: MobileCatalogueServiceContractClient Unit & Integration Tests', () {
    late MobileCatalogueServiceContractClient client;
    const testTenant1 = 'tn-mob-dhanmondi-101';
    const testTenant2 = 'tn-mob-gulshan-202';

    setUp(() {
      client = MobileCatalogueServiceContractClient();
    });

    test('P140-M1: Valid contract suite audit runs successfully, generating 64-char hash and all 6 phase gates', () {
      final res = client.runAudit(
        targetTenantId: testTenant1,
        callerTenantId: testTenant1,
        userRole: 'STAFF_PHARMACIST',
        planTier: 'STANDARD',
        productCount: 140,
        historicalDispenseCount: 420,
      );

      expect(res.status, equals(MobileContractUiStatus.success));
      expect(res.data, isNotNull);
      expect(res.data!.status, equals('PASSED'));
      expect(res.data!.auditHash.length, equals(64));
      expect(res.data!.phaseGates.length, equals(6));
      expect(res.data!.phaseGates['historical_immutability'], isTrue);
      expect(res.data!.phaseGates['multilingual_search'], isTrue);
      expect(res.data!.phaseGates['deduplication'], isTrue);
    });

    test('P140-M2: Verifies all nine required catalogue operations are certified PASS', () {
      final res = client.runAudit(
        targetTenantId: testTenant1,
        callerTenantId: testTenant1,
        userRole: 'PHARMACY_OWNER',
        planTier: 'STANDARD',
        productCount: 90,
        historicalDispenseCount: 270,
      );

      expect(res.status, equals(MobileContractUiStatus.success));
      expect(res.data!.verifiedOperations.length, equals(9));
      for (final op in res.data!.verifiedOperations) {
        expect(op.status, equals('PASS'));
      }
    });

    test('P140-M3: Cashier role is denied contract suite audit execution', () {
      final res = client.runAudit(
        targetTenantId: testTenant1,
        callerTenantId: testTenant1,
        userRole: 'CASHIER',
        planTier: 'STANDARD',
      );

      expect(res.status, equals(MobileContractUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_PERMISSION_DENIED'));
    });

    test('P140-M4: Unentitled Basic subscription plan is blocked from running audit', () {
      final res = client.runAudit(
        targetTenantId: testTenant1,
        callerTenantId: testTenant1,
        userRole: 'PHARMACY_OWNER',
        planTier: 'BASIC',
      );

      expect(res.status, equals(MobileContractUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_SUBSCRIPTION_UNENTITLED'));
    });

    test('P140-M5: Cross-tenant audit access is strictly prohibited', () {
      final res = client.runAudit(
        targetTenantId: testTenant1,
        callerTenantId: testTenant2,
        userRole: 'PHARMACY_OWNER',
        planTier: 'STANDARD',
      );

      expect(res.status, equals(MobileContractUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_CROSS_TENANT_ACCESS'));
    });

    test('P140-M6: Offline client serves cached contract audit with MobileContractUiStatus.offline', () {
      final created = client.runAudit(
        targetTenantId: testTenant1,
        callerTenantId: testTenant1,
        userRole: 'STAFF_PHARMACIST',
        planTier: 'STANDARD',
        productCount: 75,
        historicalDispenseCount: 225,
      );
      final suiteId = created.data!.suiteId;

      client.setOffline(true);
      final offlineRes = client.queryAudit(suiteId);
      expect(offlineRes.status, equals(MobileContractUiStatus.offline));
      expect(offlineRes.data, isNotNull);
      expect(offlineRes.data!.suiteId, equals(suiteId));
    });
  });
}
