import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_offline_prescription_authorization_client.dart';

void main() {
  group('MobileOfflinePrescriptionAuthorizationClient Tests (P248)', () {
    test('Offline eligibility correctly allows OTC and blocks unverified Rx/narcotics/recalls', () {
      // Pure OTC
      expect(
        MobileOfflinePrescriptionAuthorizationClient.evaluateEligibility(
          hasBlockedRecallOrBan: false,
          hasNarcotic: false,
          anyRxRequired: false,
          allRxApproved: false,
        ),
        OfflineEligibilityStatus.eligible,
      );

      // Unverified Rx
      expect(
        MobileOfflinePrescriptionAuthorizationClient.evaluateEligibility(
          hasBlockedRecallOrBan: false,
          hasNarcotic: false,
          anyRxRequired: true,
          allRxApproved: false,
        ),
        OfflineEligibilityStatus.blockedUnverifiedRx,
      );

      // Verified Rx
      expect(
        MobileOfflinePrescriptionAuthorizationClient.evaluateEligibility(
          hasBlockedRecallOrBan: false,
          hasNarcotic: false,
          anyRxRequired: true,
          allRxApproved: true,
        ),
        OfflineEligibilityStatus.eligible,
      );

      // Narcotics: strictly forbidden even if claimed approved
      expect(
        MobileOfflinePrescriptionAuthorizationClient.evaluateEligibility(
          hasBlockedRecallOrBan: false,
          hasNarcotic: true,
          anyRxRequired: true,
          allRxApproved: true,
        ),
        OfflineEligibilityStatus.forbiddenNarcotic,
      );

      // Recalled product: strictly blocked
      expect(
        MobileOfflinePrescriptionAuthorizationClient.evaluateEligibility(
          hasBlockedRecallOrBan: true,
          hasNarcotic: false,
          anyRxRequired: false,
          allRxApproved: false,
        ),
        OfflineEligibilityStatus.blockedRecalled,
      );
    });

    test('Localized EN/BN error messages reflect conservative policy', () {
      const status = OfflineEligibilityStatus.forbiddenNarcotic;
      expect(
        status.getLocalizedMessage('bn'),
        'সংবিধিবদ্ধ নিষেধাজ্ঞা: মাদক ও সিডিউল-জি ওষুধ অফলাইনে বিক্রি সম্পূর্ণ অবৈধ',
      );
      expect(
        status.getLocalizedMessage('en'),
        'Statutory Forbidden: Narcotics/Schedule-G substances cannot be dispensed offline',
      );
    });

    test('Preflight validation requires valid PCB, BMDC, and notes', () {
      const validReq = OfflineAuthorizationRequest(
        saleId: 'sale-001',
        pharmacistPcbNo: 'PCB-8821',
        doctorBmdcNo: 'BMDC-7123',
        doctorName: 'Dr. Shahabuddin',
        patientToken: 'PT-99',
        reviewNotes: 'Verified physical paper prescription',
      );
      expect(MobileOfflinePrescriptionAuthorizationClient.validatePreflight(validReq), isTrue);

      // Short PCB (< 4 chars)
      const shortPcb = OfflineAuthorizationRequest(
        saleId: 'sale-001',
        pharmacistPcbNo: 'PCB',
        doctorBmdcNo: 'BMDC-7123',
        doctorName: 'Dr. Shahabuddin',
        patientToken: 'PT-99',
        reviewNotes: 'Verified physical paper prescription',
      );
      expect(MobileOfflinePrescriptionAuthorizationClient.validatePreflight(shortPcb), isFalse);

      // Short Notes (< 5 chars)
      const shortNotes = OfflineAuthorizationRequest(
        saleId: 'sale-001',
        pharmacistPcbNo: 'PCB-8821',
        doctorBmdcNo: 'BMDC-7123',
        doctorName: 'Dr. Shahabuddin',
        patientToken: 'PT-99',
        reviewNotes: 'OK',
      );
      expect(MobileOfflinePrescriptionAuthorizationClient.validatePreflight(shortNotes), isFalse);
    });
  });
}

