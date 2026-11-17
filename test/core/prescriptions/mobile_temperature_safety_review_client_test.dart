import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_temperature_safety_review_client.dart';

void main() {
  group('P257: Mobile Temperature Safety Review Client Tests', () {
    test('Role authorization gates for temperature safety review', () {
      expect(MobileTemperatureSafetyReviewClient.canReviewExcursion('STAFF_PHARMACIST'), isTrue);
      expect(MobileTemperatureSafetyReviewClient.canReviewExcursion('BRANCH_MANAGER'), isTrue);
      expect(MobileTemperatureSafetyReviewClient.canReviewExcursion('PHARMACY_OWNER'), isTrue);
      expect(MobileTemperatureSafetyReviewClient.canReviewExcursion('SUPERADMIN'), isTrue);

      expect(MobileTemperatureSafetyReviewClient.canReviewExcursion('CASHIER'), isFalse);
      expect(MobileTemperatureSafetyReviewClient.canReviewExcursion('SALES_REP'), isFalse);
      expect(MobileTemperatureSafetyReviewClient.canReviewExcursion(null), isFalse);
    });

    test('Dispensing gate blocks quarantined lots unless approved for active release', () {
      // Normal active lot
      expect(
        MobileTemperatureSafetyReviewClient.isDispensingAllowed(
          isQuarantined: false,
          batchStatus: 'ACTIVE',
          latestDecision: null,
        ),
        isTrue,
      );

      // Quarantined lot with no approval
      expect(
        MobileTemperatureSafetyReviewClient.isDispensingAllowed(
          isQuarantined: true,
          batchStatus: 'QUARANTINED',
          latestDecision: null,
        ),
        isFalse,
      );

      // Quarantined lot approved for active release
      expect(
        MobileTemperatureSafetyReviewClient.isDispensingAllowed(
          isQuarantined: true,
          batchStatus: 'QUARANTINED',
          latestDecision: 'RELEASE_TO_ACTIVE',
        ),
        isTrue,
      );

      // Condemned lot
      expect(
        MobileTemperatureSafetyReviewClient.isDispensingAllowed(
          isQuarantined: true,
          batchStatus: 'ARCHIVED',
          latestDecision: 'CONDEMN_DISPOSAL',
        ),
        isFalse,
      );
    });

    test('Preflight validation rules and expired batch block', () {
      // Valid release
      expect(
        () => MobileTemperatureSafetyReviewClient.validatePreflight(
          batchNumber: 'BT-TEMP-001',
          decision: 'RELEASE_TO_ACTIVE',
          maxExposedTemp: 12.5,
          clinicalJustification: 'Stability testing confirms integrity at 12C for 4 hours.',
          isExpired: false,
        ),
        returnsNormally,
      );

      // Short justification fails
      expect(
        () => MobileTemperatureSafetyReviewClient.validatePreflight(
          batchNumber: 'BT-TEMP-001',
          decision: 'RELEASE_TO_ACTIVE',
          maxExposedTemp: 12.5,
          clinicalJustification: 'Too short',
          isExpired: false,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Expired batch release fails with StateError
      expect(
        () => MobileTemperatureSafetyReviewClient.validatePreflight(
          batchNumber: 'BT-TEMP-001',
          decision: 'RELEASE_TO_ACTIVE',
          maxExposedTemp: 12.5,
          clinicalJustification: 'Stability testing confirms integrity at 12C for 4 hours.',
          isExpired: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Localization and clinical summary formatting', () {
      final summaryEn = MobileTemperatureSafetyReviewClient.formatClinicalSummary(
        batchNumber: 'BT-INS-01',
        productName: 'Insulin Aspart 100IU',
        decision: 'CONDEMN_DISPOSAL',
        totalExposedValue: 4500.0,
        lang: 'en',
      );
      expect(summaryEn, contains('Insulin Aspart 100IU'));
      expect(summaryEn, contains('Condemn & Disposal'));
      expect(summaryEn, contains('4500.00 BDT'));

      final summaryBn = MobileTemperatureSafetyReviewClient.formatClinicalSummary(
        batchNumber: 'BT-INS-01',
        productName: 'Insulin Aspart 100IU',
        decision: 'CONDEMN_DISPOSAL',
        totalExposedValue: 4500.0,
        lang: 'bn',
      );
      expect(summaryBn, contains('Insulin Aspart 100IU'));
      expect(summaryBn, contains('বিনষ্ট ও বর্জন'));
      expect(summaryBn, contains('4500.00 ৳'));
    });
  });
}
