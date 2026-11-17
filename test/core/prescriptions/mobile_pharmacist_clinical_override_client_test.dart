import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_pharmacist_clinical_override_client.dart';

void main() {
  group('MobilePharmacistClinicalOverrideClient Tests (P249)', () {
    test('Eligibility correctly forbids narcotics and recalled/banned medicines', () {
      // Normal Rx medicine
      expect(
        MobilePharmacistClinicalOverrideClient.isEligibleForOverride(
          isNarcotic: false,
          isRecalledOrBanned: false,
        ),
        isTrue,
      );

      // Narcotic substance: strictly forbidden
      expect(
        MobilePharmacistClinicalOverrideClient.isEligibleForOverride(
          isNarcotic: true,
          isRecalledOrBanned: false,
        ),
        isFalse,
      );

      // Recalled or banned drug: strictly forbidden
      expect(
        MobilePharmacistClinicalOverrideClient.isEligibleForOverride(
          isNarcotic: false,
          isRecalledOrBanned: true,
        ),
        isFalse,
      );

      // Both narcotic and recalled
      expect(
        MobilePharmacistClinicalOverrideClient.isEligibleForOverride(
          isNarcotic: true,
          isRecalledOrBanned: true,
        ),
        isFalse,
      );
    });

    test('Preflight input validation checks required fields and lengths', () {
      const validReq = ClinicalOverrideRequest(
        saleId: 'sale-uuid-001',
        productId: 'prod-uuid-001',
        pharmacistPcbNo: 'PCB-12345',
        category: OverrideCategory.emergencyChronicContinuation,
        policyReference: 'DGDA Good Pharmacy Practice 2024 Sec 8.3',
        consentType: ConsentType.informedVerbal,
        consentNotes: 'Patient regular on Amlodipine 5mg; doctor visit scheduled tomorrow',
        clinicalJustification: 'Hypertension maintenance emergency continuation approved for 3 days',
        approvedUnits: 3,
      );

      expect(MobilePharmacistClinicalOverrideClient.validatePreflight(validReq), isTrue);

      // Short PCB
      expect(
        MobilePharmacistClinicalOverrideClient.validatePreflight(
          const ClinicalOverrideRequest(
            saleId: 'sale-uuid-001',
            productId: 'prod-uuid-001',
            pharmacistPcbNo: 'PCB',
            category: OverrideCategory.emergencyChronicContinuation,
            policyReference: 'DGDA Guideline Sec 8.3',
            consentType: ConsentType.informedVerbal,
            consentNotes: 'Patient consented verbally',
            clinicalJustification: 'Chronic continuation',
            approvedUnits: 3,
          ),
        ),
        isFalse,
      );

      // Zero or negative units
      expect(
        MobilePharmacistClinicalOverrideClient.validatePreflight(
          const ClinicalOverrideRequest(
            saleId: 'sale-uuid-001',
            productId: 'prod-uuid-001',
            pharmacistPcbNo: 'PCB-12345',
            category: OverrideCategory.emergencyChronicContinuation,
            policyReference: 'DGDA Guideline Sec 8.3',
            consentType: ConsentType.informedVerbal,
            consentNotes: 'Patient consented verbally',
            clinicalJustification: 'Chronic continuation',
            approvedUnits: 0,
          ),
        ),
        isFalse,
      );

      // Missing saleId
      expect(
        MobilePharmacistClinicalOverrideClient.validatePreflight(
          const ClinicalOverrideRequest(
            saleId: '   ',
            productId: 'prod-uuid-001',
            pharmacistPcbNo: 'PCB-12345',
            category: OverrideCategory.emergencyChronicContinuation,
            policyReference: 'DGDA Guideline Sec 8.3',
            consentType: ConsentType.informedVerbal,
            consentNotes: 'Patient consented verbally',
            clinicalJustification: 'Chronic continuation',
            approvedUnits: 3,
          ),
        ),
        isFalse,
      );
    });

    test('Enum serialization and localization (BN/EN)', () {
      expect(OverrideCategory.fromString('EMERGENCY_CHRONIC_CONTINUATION'), OverrideCategory.emergencyChronicContinuation);
      expect(OverrideCategory.fromString('PACKAGE_SPLIT_PARTIAL_COURSE'), OverrideCategory.packageSplitPartialCourse);
      expect(OverrideCategory.emergencyChronicContinuation.toApiString(), 'EMERGENCY_CHRONIC_CONTINUATION');
      expect(OverrideCategory.emergencyChronicContinuation.getLocalizedLabel('bn'), contains('জরুরি'));
      expect(OverrideCategory.emergencyChronicContinuation.getLocalizedLabel('en'), contains('Emergency'));

      expect(ConsentType.fromString('INFORMED_VERBAL'), ConsentType.informedVerbal);
      expect(ConsentType.fromString('SMS_OTP'), ConsentType.smsOtp);
      expect(ConsentType.informedVerbal.toApiString(), 'INFORMED_VERBAL');
      expect(ConsentType.informedVerbal.getLocalizedLabel('bn'), contains('মৌখিক'));
      expect(ConsentType.informedVerbal.getLocalizedLabel('en'), contains('Verbal'));

      const req = ClinicalOverrideRequest(
        saleId: 's-1',
        productId: 'p-1',
        pharmacistPcbNo: 'PCB-99',
        category: OverrideCategory.outOfStockGenericDispense,
        policyReference: 'DGDA Generic Equivalency Guide',
        consentType: ConsentType.signedPhysical,
        consentNotes: 'Signed paper form attached',
        clinicalJustification: 'Brand stockout substitution to exact INN',
        approvedUnits: 10,
      );
      final json = req.toJson();
      expect(json['override_category'], 'OUT_OF_STOCK_GENERIC_DISPENSE');
      expect(json['consent_type'], 'SIGNED_PHYSICAL');
      expect(json['approved_base_units'], 10);
    });
  });
}

