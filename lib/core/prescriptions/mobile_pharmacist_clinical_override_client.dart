/// P249: Credentialed Pharmacist Clinical Override Client (Flutter Mobile).
/// Architecture Decision: ADR-0249 (P249).
/// Enforces mandatory PCB credentials, statutory policy, patient consent, and narcotic prohibition.
library mobile_pharmacist_clinical_override_client;

enum OverrideCategory {
  emergencyChronicContinuation,
  packageSplitPartialCourse,
  outOfStockGenericDispense,
  prescriberUnavailableEmergency;

  static OverrideCategory fromString(String val) {
    switch (val.toUpperCase().trim()) {
      case 'EMERGENCY_CHRONIC_CONTINUATION':
        return OverrideCategory.emergencyChronicContinuation;
      case 'PACKAGE_SPLIT_PARTIAL_COURSE':
        return OverrideCategory.packageSplitPartialCourse;
      case 'OUT_OF_STOCK_GENERIC_DISPENSE':
        return OverrideCategory.outOfStockGenericDispense;
      case 'PRESCRIBER_UNAVAILABLE_EMERGENCY':
        return OverrideCategory.prescriberUnavailableEmergency;
      default:
        return OverrideCategory.emergencyChronicContinuation;
    }
  }

  String toApiString() {
    switch (this) {
      case OverrideCategory.emergencyChronicContinuation:
        return 'EMERGENCY_CHRONIC_CONTINUATION';
      case OverrideCategory.packageSplitPartialCourse:
        return 'PACKAGE_SPLIT_PARTIAL_COURSE';
      case OverrideCategory.outOfStockGenericDispense:
        return 'OUT_OF_STOCK_GENERIC_DISPENSE';
      case OverrideCategory.prescriberUnavailableEmergency:
        return 'PRESCRIBER_UNAVAILABLE_EMERGENCY';
    }
  }

  String getLocalizedLabel(String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (this) {
      case OverrideCategory.emergencyChronicContinuation:
        return isBn
            ? 'জরুরি দীর্ঘমেয়াদী চিকিৎসার ধারাবাহিকতা রক্ষা'
            : 'Emergency Chronic Care Continuation';
      case OverrideCategory.packageSplitPartialCourse:
        return isBn
            ? 'প্যাকেজ বিভাজন / আংশিক কোর্স সরবরাহ'
            : 'Package Split / Partial Acute Course';
      case OverrideCategory.outOfStockGenericDispense:
        return isBn
            ? 'স্টক ঘাটতিতে সমতুল্য জেনেরিক বিকল্প সরবরাহ'
            : 'Out-of-Stock Manual Generic Equivalency';
      case OverrideCategory.prescriberUnavailableEmergency:
        return isBn
            ? 'চিকিৎসক অনুপস্থিতিকালীন জরুরি সরবরাহ'
            : 'Prescriber Unavailable Acute Emergency';
    }
  }
}

enum ConsentType {
  informedVerbal,
  signedPhysical,
  smsOtp,
  recordedAttendant;

  static ConsentType fromString(String val) {
    switch (val.toUpperCase().trim()) {
      case 'INFORMED_VERBAL':
        return ConsentType.informedVerbal;
      case 'SIGNED_PHYSICAL':
        return ConsentType.signedPhysical;
      case 'SMS_OTP':
        return ConsentType.smsOtp;
      case 'RECORDED_ATTENDANT':
        return ConsentType.recordedAttendant;
      default:
        return ConsentType.informedVerbal;
    }
  }

  String toApiString() {
    switch (this) {
      case ConsentType.informedVerbal:
        return 'INFORMED_VERBAL';
      case ConsentType.signedPhysical:
        return 'SIGNED_PHYSICAL';
      case ConsentType.smsOtp:
        return 'SMS_OTP';
      case ConsentType.recordedAttendant:
        return 'RECORDED_ATTENDANT';
    }
  }

  String getLocalizedLabel(String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (this) {
      case ConsentType.informedVerbal:
        return isBn ? 'অবহিত মৌখিক সম্মতি' : 'Informed Verbal Consent';
      case ConsentType.signedPhysical:
        return isBn ? 'স্বাক্ষরিত লিখিত সম্মতিপত্র' : 'Signed Paper Consent Form';
      case ConsentType.smsOtp:
        return isBn ? 'এসএমএস ওটিপি ডিজিটাল সম্মতি' : 'SMS OTP Digital Consent';
      case ConsentType.recordedAttendant:
        return isBn ? 'অভিভাবক / প্রতিনিধির নথিবদ্ধ সম্মতি' : 'Recorded Attendant Consent';
    }
  }
}

class ClinicalOverrideRequest {
  final String saleId;
  final String productId;
  final String pharmacistPcbNo;
  final OverrideCategory category;
  final String policyReference;
  final ConsentType consentType;
  final String consentNotes;
  final String clinicalJustification;
  final int approvedUnits;

  const ClinicalOverrideRequest({
    required this.saleId,
    required this.productId,
    required this.pharmacistPcbNo,
    required this.category,
    required this.policyReference,
    required this.consentType,
    required this.consentNotes,
    required this.clinicalJustification,
    required this.approvedUnits,
  });

  Map<String, dynamic> toJson() {
    return {
      'sale_id': saleId,
      'product_id': productId,
      'pharmacist_pcb_no': pharmacistPcbNo,
      'override_category': category.toApiString(),
      'statutory_policy_reference': policyReference,
      'consent_type': consentType.toApiString(),
      'consent_evidence_notes': consentNotes,
      'clinical_justification': clinicalJustification,
      'approved_base_units': approvedUnits,
    };
  }
}

class MobilePharmacistClinicalOverrideClient {
  /// Checks if medicine is legally eligible for clinical exception.
  static bool isEligibleForOverride({
    required bool isNarcotic,
    required bool isRecalledOrBanned,
  }) {
    if (isNarcotic || isRecalledOrBanned) return false;
    return true;
  }

  /// Validates preflight inputs.
  static bool validatePreflight(ClinicalOverrideRequest request) {
    if (request.saleId.trim().isEmpty) return false;
    if (request.productId.trim().isEmpty) return false;
    if (request.pharmacistPcbNo.trim().length < 4) return false;
    if (request.policyReference.trim().length < 5) return false;
    if (request.consentNotes.trim().length < 5) return false;
    if (request.clinicalJustification.trim().length < 5) return false;
    if (request.approvedUnits < 1) return false;
    return true;
  }
}

