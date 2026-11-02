// test/core/catalog/mobile_classification_snapshot_client_test.dart
// Architecture Decision: ADR-0130
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P130)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_classification_snapshot_client.dart';

void main() {
  group('MobileClassificationSnapshotClient Tests (P130)', () {
    late MobileClassificationSnapshotClient client;
    late MobileMasterMedicine napaProduct;
    late MobileMasterMedicine ciproProduct;

    setUp(() {
      client = MobileClassificationSnapshotClient();

      napaProduct = MobileMasterMedicine(
        productId: 'prod-napa-500',
        brandName: 'Napa 500mg',
        genericName: 'Paracetamol',
        isPrescriptionOnly: false,
        isNarcotic: false,
        isAntibiotic: false,
        curationStatus: 'APPROVED',
      );

      ciproProduct = MobileMasterMedicine(
        productId: 'prod-cipro-500',
        brandName: 'Ciprocin 500mg',
        genericName: 'Ciprofloxacin',
        isPrescriptionOnly: true,
        isNarcotic: false,
        isAntibiotic: false,
        curationStatus: 'APPROVED',
      );

      client.registerMasterMedicine(napaProduct);
      client.registerMasterMedicine(ciproProduct);
    });

    test('P130-M1: Superadmin creates initial OTC classification snapshot with SHA-256 hash', () {
      final now = DateTime.now();
      final result = client.createSnapshot(
        actorRole: 'SUPERADMIN',
        actorEmail: 'superadmin@platform.gov.bd',
        productId: 'prod-napa-500',
        type: MobileClassificationType.otc,
        regulatorySource: 'DGDA Over-The-Counter Schedule 2024',
        effectiveFrom: now,
        reviewNotes: 'Initial regulatory registration as general sale OTC medicine.',
      );

      expect(result.status, equals(MobileClassificationUiStatus.success));
      expect(result.data, isNotNull);
      expect(result.data!.versionNumber, equals(1));
      expect(result.data!.classificationType, equals(MobileClassificationType.otc));
      expect(result.data!.isCurrent, isTrue);
      expect(result.data!.isDispensingBlocked, isFalse);
      expect(result.data!.effectiveTo, isNull);
      expect(result.data!.immutableHash.length, equals(64));
      expect(napaProduct.isPrescriptionOnly, isFalse);
    });

    test('P130-M2: Superseding snapshot (OTC -> POM) sets effectiveTo on preceding snapshot and updates current', () {
      final t1 = DateTime.now().subtract(const Duration(days: 30));
      final t2 = DateTime.now();

      // 1. Initial OTC snapshot
      final r1 = client.createSnapshot(
        actorRole: 'PLATFORM_OPERATOR',
        actorEmail: 'operator@platform.gov.bd',
        productId: 'prod-napa-500',
        type: MobileClassificationType.otc,
        regulatorySource: 'Initial OTC Schedule',
        effectiveFrom: t1,
        reviewNotes: 'Initial OTC approval.',
      );
      expect(r1.status, equals(MobileClassificationUiStatus.success));

      // 2. Reclassified to POM
      final r2 = client.createSnapshot(
        actorRole: 'SUPERADMIN',
        actorEmail: 'superadmin@platform.gov.bd',
        productId: 'prod-napa-500',
        type: MobileClassificationType.prescriptionOnly,
        regulatorySource: 'DGDA POM Directive 2026/08',
        effectiveFrom: t2,
        reviewNotes: 'Reclassified to prescription-only due to dosage strength reassessment.',
      );
      expect(r2.status, equals(MobileClassificationUiStatus.success));
      expect(r2.data!.versionNumber, equals(2));
      expect(r2.data!.isCurrent, isTrue);

      final history = client.getSnapshotHistory('prod-napa-500');
      expect(history.length, equals(2));

      final s1 = history.firstWhere((s) => s.versionNumber == 1);
      expect(s1.isCurrent, isFalse);
      expect(s1.effectiveTo, equals(t2));

      // Master medicine synchronized to POM
      expect(napaProduct.isPrescriptionOnly, isTrue);
    });

    test('P130-M3: RECALLED snapshot triggers zero-override POS hard block', () {
      final result = client.createSnapshot(
        actorRole: 'SUPERADMIN',
        actorEmail: 'superadmin@dgda.gov.bd',
        productId: 'prod-napa-500',
        type: MobileClassificationType.recalled,
        regulatorySource: 'DGDA Statutory Safety Recall Notice 44/2026',
        effectiveFrom: DateTime.now(),
        reviewNotes: 'Critical safety alert: Suspected contamination in active raw material batch.',
      );

      expect(result.status, equals(MobileClassificationUiStatus.success));
      expect(result.data!.isDispensingBlocked, isTrue);
      expect(napaProduct.curationStatus, equals('RECALLED'));

      final isBlocked = client.isDispensingBlocked('prod-napa-500');
      expect(isBlocked, isTrue);
    });

    test('P130-M4: Point-in-time temporal resolution accurately returns historical OTC snapshot for past sales', () {
      final jan1 = DateTime.utc(2026, 1, 1);
      final jun1 = DateTime.utc(2026, 6, 1);

      // Jan: OTC
      client.createSnapshot(
        actorRole: 'SUPERADMIN',
        actorEmail: 'admin@dgda.gov.bd',
        productId: 'prod-napa-500',
        type: MobileClassificationType.otc,
        regulatorySource: 'Schedule Jan 2026',
        effectiveFrom: jan1,
        reviewNotes: 'OTC status early 2026.',
      );

      // Jun: POM
      client.createSnapshot(
        actorRole: 'SUPERADMIN',
        actorEmail: 'admin@dgda.gov.bd',
        productId: 'prod-napa-500',
        type: MobileClassificationType.prescriptionOnly,
        regulatorySource: 'Schedule Jun 2026',
        effectiveFrom: jun1,
        reviewNotes: 'Prescription required from June 2026.',
      );

      // Past sale on March 15: Must resolve to OTC (Version 1)
      final march15 = DateTime.utc(2026, 3, 15, 10, 30);
      final resMarch = client.getPointInTimeSnapshot('prod-napa-500', march15);
      expect(resMarch.status, equals(MobileClassificationUiStatus.success));
      expect(resMarch.data, isNotNull);
      expect(resMarch.data!.versionNumber, equals(1));
      expect(resMarch.data!.classificationType, equals(MobileClassificationType.otc));

      // Sale on August 1: Must resolve to POM (Version 2)
      final aug1 = DateTime.utc(2026, 8, 1, 15, 0);
      final resAug = client.getPointInTimeSnapshot('prod-napa-500', aug1);
      expect(resAug.status, equals(MobileClassificationUiStatus.success));
      expect(resAug.data, isNotNull);
      expect(resAug.data!.versionNumber, equals(2));
      expect(resAug.data!.classificationType, equals(MobileClassificationType.prescriptionOnly));
    });

    test('P130-M5: Tenant owner or cashier blocked from creating classification snapshots', () {
      final rOwner = client.createSnapshot(
        actorRole: 'PHARMACY_OWNER',
        actorEmail: 'owner@uttara.com',
        productId: 'prod-napa-500',
        type: MobileClassificationType.otc,
        regulatorySource: 'Store Preference',
        effectiveFrom: DateTime.now(),
        reviewNotes: 'Store owner trying to mark drug as OTC.',
      );
      expect(rOwner.status, equals(MobileClassificationUiStatus.permissionDenied));
      expect(rOwner.errorCode, equals('PLATFORM_CATALOG_OWNERSHIP_PROTECTED'));
      expect(rOwner.messageBn, isNotEmpty);

      final rCashier = client.createSnapshot(
        actorRole: 'CASHIER',
        actorEmail: 'cashier@uttara.com',
        productId: 'prod-napa-500',
        type: MobileClassificationType.otc,
        regulatorySource: 'Cashier Attempt',
        effectiveFrom: DateTime.now(),
        reviewNotes: 'Cashier cannot modify catalog.',
      );
      expect(rCashier.status, equals(MobileClassificationUiStatus.permissionDenied));
      expect(rCashier.errorCode, equals('PLATFORM_CATALOG_OWNERSHIP_PROTECTED'));
    });

    test('P130-M6: Offline fallback resolves cached classification snapshot safely', () {
      client.createSnapshot(
        actorRole: 'SUPERADMIN',
        actorEmail: 'admin@dgda.gov.bd',
        productId: 'prod-napa-500',
        type: MobileClassificationType.otc,
        regulatorySource: 'DGDA Schedule 2026',
        effectiveFrom: DateTime.now(),
        reviewNotes: 'Verified online registration.',
      );

      client.setOfflineMode(true);
      expect(client.isOfflineMode(), isTrue);

      final current = client.getCurrentSnapshot('prod-napa-500');
      expect(current.status, equals(MobileClassificationUiStatus.offline));
      expect(current.data, isNotNull);
      expect(current.data!.productId, equals('prod-napa-500'));
      expect(current.data!.classificationType, equals(MobileClassificationType.otc));
      expect(current.errorCode, equals('STATUS_OFFLINE_CACHE'));

      final unknown = client.getCurrentSnapshot('prod-unknown-999');
      expect(unknown.status, equals(MobileClassificationUiStatus.empty));
    });
  });
}
