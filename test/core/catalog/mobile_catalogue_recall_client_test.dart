// test/core/catalog/mobile_catalogue_recall_client_test.dart
// Architecture Decision: ADR-0137
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P137)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_catalogue_recall_client.dart';

void main() {
  group('P137: MobileCatalogueRecallClient Unit & Integration Tests', () {
    late MobileCatalogueRecallClient client;
    const testTenant1 = 'tn-mob-banani-101';
    const testTenant2 = 'tn-mob-gulshan-202';

    setUp(() {
      client = MobileCatalogueRecallClient();
    });

    test('P137-M1: Publish statutory DGDA safety recall hard-blocks dispensing and sets blocked flag', () {
      final res = client.publishNotice(
        tenantId: testTenant1,
        productId: 'med-paracip-120',
        targetName: 'Paracip 120mg Syrup',
        lifecycleStatus: 'RECALLED',
        recallScope: 'NATIONWIDE_ALL_BATCHES',
        regulatoryAuthority: 'DGDA',
        noticeNumber: 'DGDA/DR/2026/RC-901',
        reason: 'DEG impurity detected in oral liquid formulation.',
        actionRequired: 'Immediately quarantine and halt all dispensing.',
        userRole: 'STAFF_PHARMACIST',
      );

      expect(res.status, equals(MobileRecallUiStatus.success));
      expect(res.data, isNotNull);
      expect(res.data!.noticeNumber, equals('DGDA/DR/2026/RC-901'));
      expect(res.data!.lifecycleStatus, equals('RECALLED'));
      expect(res.data!.isDispensingBlocked, isTrue);
      expect(res.data!.isActive, isTrue);
      expect(res.data!.immutableHash.length, equals(64));
    });

    test('P137-M2: Validate dispense returns error ERR_PRODUCT_RECALLED_DISPENSING_BLOCKED on recalled product', () {
      // Publish recall
      client.publishNotice(
        tenantId: testTenant1,
        productId: 'med-paracip-120',
        targetName: 'Paracip 120mg Syrup',
        lifecycleStatus: 'RECALLED',
        recallScope: 'NATIONWIDE_ALL_BATCHES',
        regulatoryAuthority: 'DGDA',
        noticeNumber: 'DGDA/DR/2026/RC-902',
        reason: 'Sub-potent active ingredient batches.',
        actionRequired: 'Quarantine stock.',
        userRole: 'BRANCH_MANAGER',
      );

      // Attempt cashier checkout dispense validation
      final dispenseRes = client.validateDispense(
        tenantId: testTenant1,
        productId: 'med-paracip-120',
        batchNumber: 'BATCH-01',
      );
      expect(dispenseRes.status, equals(MobileRecallUiStatus.error));
      expect(dispenseRes.errorCode, equals('ERR_PRODUCT_RECALLED_DISPENSING_BLOCKED'));
    });

    test('P137-M3: Specific batch recall blocks only affected batch lots', () {
      client.publishNotice(
        tenantId: testTenant1,
        productId: 'med-cefix-200',
        targetName: 'Cefix 200mg Capsule',
        lifecycleStatus: 'RECALLED',
        recallScope: 'SPECIFIC_BATCHES',
        affectedBatchNumbers: ['BATCH-CONTAM-X'],
        regulatoryAuthority: 'Manufacturer QA',
        noticeNumber: 'MFR-RC-881',
        reason: 'Moisture ingress in batch packaging.',
        actionRequired: 'Quarantine contaminated batch only.',
        userRole: 'STAFF_PHARMACIST',
      );

      // Contaminated batch -> Blocked
      final contamCheck = client.checkRecallStatus(
        tenantId: testTenant1,
        productId: 'med-cefix-200',
        batchNumber: 'BATCH-CONTAM-X',
      );
      expect(contamCheck.status, equals(MobileRecallUiStatus.success));
      expect(contamCheck.data!.blocked, isTrue);

      // Safe batch -> Allowed
      final safeCheck = client.checkRecallStatus(
        tenantId: testTenant1,
        productId: 'med-cefix-200',
        batchNumber: 'BATCH-SAFE-Y',
      );
      expect(safeCheck.status, equals(MobileRecallUiStatus.success));
      expect(safeCheck.data!.blocked, isFalse);
    });

    test('P137-M4: Discontinued product flags item but allows depleting existing stock', () {
      client.publishNotice(
        tenantId: testTenant1,
        productId: 'med-oldbrand-500',
        targetName: 'OldBrand 500mg',
        lifecycleStatus: 'DISCONTINUED',
        recallScope: 'NATIONWIDE_ALL_BATCHES',
        regulatoryAuthority: 'Pharma Corp',
        noticeNumber: 'DISC-2026-001',
        reason: 'Brand discontinued; replaced by newer formulation.',
        actionRequired: 'Deplete remaining branch inventory.',
        userRole: 'BRANCH_MANAGER',
      );

      final checkRes = client.checkRecallStatus(
        tenantId: testTenant1,
        productId: 'med-oldbrand-500',
      );
      expect(checkRes.status, equals(MobileRecallUiStatus.success));
      expect(checkRes.data!.blocked, isFalse);
      expect(checkRes.data!.lifecycleStatus, equals('DISCONTINUED'));

      final valDispense = client.validateDispense(
        tenantId: testTenant1,
        productId: 'med-oldbrand-500',
      );
      expect(valDispense.status, equals(MobileRecallUiStatus.success));
      expect(valDispense.data!.blocked, isFalse);
    });

    test('P137-M5: Cashier can query recall status for checkout safety check but cannot publish or lift recalls', () {
      // Cashier check safe item -> Permitted
      final safeCheck = client.checkRecallStatus(
        tenantId: testTenant1,
        productId: 'med-safe-item',
      );
      expect(safeCheck.status, equals(MobileRecallUiStatus.success));
      expect(safeCheck.data!.blocked, isFalse);

      // Cashier attempts to publish notice -> Denied
      final cashierPub = client.publishNotice(
        tenantId: testTenant1,
        productId: 'med-some-item',
        targetName: 'Some Item',
        lifecycleStatus: 'RECALLED',
        regulatoryAuthority: 'Unauthorized Cashier',
        noticeNumber: 'UNAUTH-RC-01',
        reason: 'Unauthorized cashier attempt.',
        userRole: 'CASHIER',
      );
      expect(cashierPub.status, equals(MobileRecallUiStatus.permissionDenied));
      expect(cashierPub.errorCode, equals('ERR_STAFF_ROLE_DENIED'));
    });

    test('P137-M6: Cross-tenant recall lift blocked with ERR_CROSS_TENANT_ACCESS and offline mode serves cached status', () {
      final pubRes = client.publishNotice(
        tenantId: testTenant1,
        productId: 'med-hold-item',
        targetName: 'Hold Item',
        lifecycleStatus: 'QUARANTINED',
        recallScope: 'TENANT_QUARANTINE',
        regulatoryAuthority: 'Tenant 1 QA',
        noticeNumber: 'T1-HOLD-01',
        reason: 'Suspicious discoloration in batch lot.',
        actionRequired: 'Hold in quarantine room.',
        userRole: 'BRANCH_MANAGER',
      );
      final noticeId = pubRes.data!.noticeId;

      // Tenant 2 attempts to lift Tenant 1's quarantine -> Denied
      final crossLift = client.liftNotice(
        noticeId: noticeId,
        actorTenantId: testTenant2,
        userRole: 'BRANCH_MANAGER',
        resolutionNotes: 'Malicious lift',
      );
      expect(crossLift.status, equals(MobileRecallUiStatus.permissionDenied));
      expect(crossLift.errorCode, equals('ERR_CROSS_TENANT_ACCESS'));

      // Disconnect to offline mode
      client.isOffline = true;

      // Offline status check serves cached recall status with OFFLINE ui state
      final offlineCheck = client.checkRecallStatus(
        tenantId: testTenant1,
        productId: 'med-hold-item',
      );
      expect(offlineCheck.status, equals(MobileRecallUiStatus.offline));
      expect(offlineCheck.data, isNotNull);
      expect(offlineCheck.data!.blocked, isTrue);
      expect(offlineCheck.data!.noticeNumber, equals('T1-HOLD-01'));
    });
  });
}
