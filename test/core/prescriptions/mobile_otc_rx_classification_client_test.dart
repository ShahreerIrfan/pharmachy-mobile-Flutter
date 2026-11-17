import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_otc_rx_classification_client.dart';

void main() {
  group('MobileOtcRxClassificationClient Tests (P247)', () {
    test('ClassificationType resolves correctly from strings and sets Rx requirement', () {
      final otc = ClassificationType.fromString('OTC');
      expect(otc, ClassificationType.otc);
      expect(otc.requiresPrescription, isFalse);
      expect(otc.isDispensingBlocked, isFalse);

      final pom = ClassificationType.fromString('PRESCRIPTION_ONLY');
      expect(pom, ClassificationType.prescriptionOnly);
      expect(pom.requiresPrescription, isTrue);

      final recall = ClassificationType.fromString('RECALLED');
      expect(recall, ClassificationType.recalled);
      expect(recall.isDispensingBlocked, isTrue);
    });

    test('Localized EN/BN labels render properly', () {
      final otc = ClassificationType.otc;
      expect(otc.getLocalizedLabel('bn'), 'প্রেসক্রিপশন ব্যতীত বিক্রয়যোগ্য (OTC)');
      expect(otc.getLocalizedLabel('en'), 'Over-The-Counter (OTC)');

      final pom = ClassificationType.prescriptionOnly;
      expect(pom.getLocalizedLabel('bn'), 'প্রেসক্রিপশন আবশ্যক (POM)');
    });

    test('Preflight validation checks mandatory fields', () {
      expect(
        MobileOtcRxClassificationClient.validatePreflight(
          productId: 'prod-001',
          type: ClassificationType.prescriptionOnly,
          source: 'DGDA Notification 42/2026',
          notes: 'Reclassified as POM after clinical committee review',
        ),
        isTrue,
      );

      // Missing product id
      expect(
        MobileOtcRxClassificationClient.validatePreflight(
          productId: '',
          type: ClassificationType.prescriptionOnly,
          source: 'DGDA Notification 42/2026',
          notes: 'Valid notes',
        ),
        isFalse,
      );

      // Source too short
      expect(
        MobileOtcRxClassificationClient.validatePreflight(
          productId: 'prod-001',
          type: ClassificationType.prescriptionOnly,
          source: 'DG',
          notes: 'Valid notes',
        ),
        isFalse,
      );
    });

    test('Point-in-time resolution distinguishes effective date ranges', () {
      final snapV1 = ClassificationSnapshotDto(
        snapshotId: 'mcs-11',
        productId: 'prod-001',
        versionNumber: 1,
        classificationType: ClassificationType.otc,
        regulatorySource: 'DGDA Initial',
        effectiveFrom: '2026-01-01T00:00:00Z',
        effectiveTo: '2026-06-01T00:00:00Z',
        isCurrent: false,
        isDispensingBlocked: false,
        reviewNotes: 'Initial OTC approval',
        immutableHash: 'hash1',
      );

      final snapV2 = ClassificationSnapshotDto(
        snapshotId: 'mcs-12',
        productId: 'prod-001',
        versionNumber: 2,
        classificationType: ClassificationType.prescriptionOnly,
        regulatorySource: 'DGDA S.R.O. 42/2026',
        effectiveFrom: '2026-06-01T00:00:00Z',
        effectiveTo: null,
        isCurrent: true,
        isDispensingBlocked: false,
        reviewNotes: 'Elevated to POM',
        immutableHash: 'hash2',
      );

      expect(
        MobileOtcRxClassificationClient.isEffectiveAt(snapV1, '2026-04-01T00:00:00Z'),
        isTrue,
      );
      expect(
        MobileOtcRxClassificationClient.isEffectiveAt(snapV2, '2026-04-01T00:00:00Z'),
        isFalse,
      );

      expect(
        MobileOtcRxClassificationClient.isEffectiveAt(snapV1, '2026-07-01T00:00:00Z'),
        isFalse,
      );
      expect(
        MobileOtcRxClassificationClient.isEffectiveAt(snapV2, '2026-07-01T00:00:00Z'),
        isTrue,
      );
    });
  });
}
