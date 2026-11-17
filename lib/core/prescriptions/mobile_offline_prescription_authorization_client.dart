/// P248: Conservative Offline Prescription Authorization Client (Flutter Mobile).
/// Architecture Decision: ADR-0248 (P248).
/// Enforces conservative offline prescription verification and narcotic prohibition.
library mobile_offline_prescription_authorization_client;

enum OfflineEligibilityStatus {
  eligible,
  blockedUnverifiedRx,
  forbiddenNarcotic,
  blockedRecalled;

  String getLocalizedMessage(String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (this) {
      case OfflineEligibilityStatus.eligible:
        return isBn ? 'অফলাইন সম্পন্ন করার উপযোগী' : 'Eligible for Offline Dispensing';
      case OfflineEligibilityStatus.blockedUnverifiedRx:
        return isBn
            ? 'অফলাইন ব্লক: প্রেসক্রিপশনযুক্ত ওষুধে নিবন্ধিত ফার্মাসিস্টের অনুমোদন আবশ্যক'
            : 'Offline Block: Unverified prescription/antibiotic requires registered Pharmacist approval';
      case OfflineEligibilityStatus.forbiddenNarcotic:
        return isBn
            ? 'সংবিধিবদ্ধ নিষেধাজ্ঞা: মাদক ও সিডিউল-জি ওষুধ অফলাইনে বিক্রি সম্পূর্ণ অবৈধ'
            : 'Statutory Forbidden: Narcotics/Schedule-G substances cannot be dispensed offline';
      case OfflineEligibilityStatus.blockedRecalled:
        return isBn
            ? 'নিরাপত্তা সতর্কতা: কার্টে প্রত্যাহৃত বা নিষিদ্ধ ওষুধ রয়েছে'
            : 'Safety Recall: Cart contains recalled or banned items';
    }
  }

  bool get isEligible => this == OfflineEligibilityStatus.eligible;
}

class OfflineAuthorizationRequest {
  final String saleId;
  final String pharmacistPcbNo;
  final String doctorBmdcNo;
  final String doctorName;
  final String patientToken;
  final String reviewNotes;

  const OfflineAuthorizationRequest({
    required this.saleId,
    required this.pharmacistPcbNo,
    required this.doctorBmdcNo,
    required this.doctorName,
    required this.patientToken,
    required this.reviewNotes,
  });

  Map<String, dynamic> toJson() {
    return {
      'sale_id': saleId,
      'pharmacist_pcb_no': pharmacistPcbNo,
      'doctor_bmdc_no': doctorBmdcNo,
      'doctor_name': doctorName,
      'patient_token': patientToken,
      'review_notes': reviewNotes,
    };
  }
}

class MobileOfflinePrescriptionAuthorizationClient {
  /// Evaluates offline cart eligibility conservatively under DGDA guidelines.
  static OfflineEligibilityStatus evaluateEligibility({
    required bool hasBlockedRecallOrBan,
    required bool hasNarcotic,
    required bool anyRxRequired,
    required bool allRxApproved,
  }) {
    if (hasBlockedRecallOrBan) {
      return OfflineEligibilityStatus.blockedRecalled;
    }
    if (hasNarcotic) {
      return OfflineEligibilityStatus.forbiddenNarcotic;
    }
    if (anyRxRequired && !allRxApproved) {
      return OfflineEligibilityStatus.blockedUnverifiedRx;
    }
    return OfflineEligibilityStatus.eligible;
  }

  /// Validates input credentials before submitting offline pharmacist authorization.
  static bool validatePreflight(OfflineAuthorizationRequest request) {
    if (request.saleId.trim().isEmpty) return false;
    if (request.pharmacistPcbNo.trim().length < 4) return false;
    if (request.doctorBmdcNo.trim().length < 4) return false;
    if (request.doctorName.trim().length < 2) return false;
    if (request.reviewNotes.trim().length < 5) return false;
    return true;
  }
}

