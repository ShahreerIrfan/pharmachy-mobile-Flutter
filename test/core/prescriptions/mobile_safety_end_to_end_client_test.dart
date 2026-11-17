import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_safety_end_to_end_client.dart';

void main() {
  group('P260: Mobile Safety End-to-End Client Tests', () {
    test('enforces registered pharmacist authorization gate', () {
      expect(MobileSafetyEndToEndClient.isAuthorizedPharmacist('STAFF_PHARMACIST'), isTrue);
      expect(MobileSafetyEndToEndClient.isAuthorizedPharmacist('PHARMACY_OWNER'), isTrue);
      expect(MobileSafetyEndToEndClient.isAuthorizedPharmacist('BRANCH_MANAGER'), isTrue);
      expect(MobileSafetyEndToEndClient.isAuthorizedPharmacist('SUPERADMIN'), isTrue);

      expect(MobileSafetyEndToEndClient.isAuthorizedPharmacist('CASHIER'), isFalse);
      expect(MobileSafetyEndToEndClient.isAuthorizedPharmacist(null), isFalse);
    });

    test('evaluates order finalization safety gates correctly', () {
      // 1. OTC without Rx -> Allowed
      expect(
        MobileSafetyEndToEndClient.canFinalizeOrder(
          requiresRx: false,
          isRxVerified: false,
          hasBlockedRecall: false,
        ),
        isTrue,
      );

      // 2. Rx required but not verified -> Blocked
      expect(
        MobileSafetyEndToEndClient.canFinalizeOrder(
          requiresRx: true,
          isRxVerified: false,
          hasBlockedRecall: false,
        ),
        isFalse,
      );

      // 3. Rx required and verified -> Allowed
      expect(
        MobileSafetyEndToEndClient.canFinalizeOrder(
          requiresRx: true,
          isRxVerified: true,
          hasBlockedRecall: false,
        ),
        isTrue,
      );

      // 4. Recalled batch present -> Strictly Blocked
      expect(
        MobileSafetyEndToEndClient.canFinalizeOrder(
          requiresRx: false,
          isRxVerified: true,
          hasBlockedRecall: true,
        ),
        isFalse,
      );

      // 5. Offline unverified Rx -> Strictly Blocked
      expect(
        MobileSafetyEndToEndClient.canFinalizeOrder(
          requiresRx: true,
          isRxVerified: false,
          hasBlockedRecall: false,
          isOffline: true,
        ),
        isFalse,
      );
    });

    test('detects stale classification versions and validates prescription dates', () {
      expect(
        MobileSafetyEndToEndClient.isClassificationStale(lineVersion: 1, liveVersion: 2),
        isTrue,
      );
      expect(
        MobileSafetyEndToEndClient.isClassificationStale(lineVersion: 2, liveVersion: 2),
        isFalse,
      );

      // Valid date
      expect(
        () => MobileSafetyEndToEndClient.validatePrescriptionDate(
          rxDate: '2024-06-01',
          currentDate: '2024-06-15',
        ),
        returnsNormally,
      );

      // Future date
      expect(
        () => MobileSafetyEndToEndClient.validatePrescriptionDate(
          rxDate: '2025-01-01',
          currentDate: '2024-06-15',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Too old (> 365 days)
      expect(
        () => MobileSafetyEndToEndClient.validatePrescriptionDate(
          rxDate: '2022-01-01',
          currentDate: '2024-06-15',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('formats bilingual safety alert messages accurately', () {
      final alertBn = MobileSafetyEndToEndClient.formatSafetyAlert(
        alertCode: 'ERR_BATCH_RECALLED',
        medicineName: 'Azithromycin 500mg',
        lang: 'bn',
      );
      expect(alertBn, contains('জরুরি প্রত্যাহার'));
      expect(alertBn, contains('Azithromycin 500mg'));

      final alertEn = MobileSafetyEndToEndClient.formatSafetyAlert(
        alertCode: 'ERR_RX_VERIFICATION_REQUIRED',
        medicineName: 'Amoxicillin 500mg',
        lang: 'en',
      );
      expect(alertEn, contains('ALERT: Prescription verification by a registered pharmacist'));
    });
  });
}

