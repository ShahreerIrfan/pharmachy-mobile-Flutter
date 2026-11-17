/// P250: No Automated Substitution, Clinical Advice or Prescriber Impersonation Policy (Flutter Mobile).
/// Architecture Decision: ADR-0250 (P250).
/// Strictly disallows autonomous machine substitution, AI diagnosis, and prescriber impersonation.
library no_automated_substitution_policy;

class NoAutomatedSubstitutionPolicy {
  static const String disclaimerEn =
      'Pharmacy ERP is an administrative workflow system and does not provide medical diagnoses, '
      'automated prescription substitutions, or clinical dosage advice. All clinical decisions must be '
      'made by qualified registered medical practitioners (BMDC) or licensed pharmacists (PCB).';

  static const String disclaimerBn =
      'ফার্মাসি ইআরপি একটি প্রশাসনিক ওয়ার্কফ্লো সিস্টেম। এটি কোনো চিকিৎসাগত রোগ নির্ণয়, '
      'স্বয়ংক্রিয় ওষুধ পরিবর্তন বা ক্লিনিক্যাল ডোজের পরামর্শ প্রদান করে না। সকল ক্লিনিক্যাল সিদ্ধান্ত '
      'অবশ্যই বিএমডিসি নিবন্ধিত চিকিৎসক বা পিসিবি নিবন্ধিত ফার্মাসিস্ট কর্তৃক গৃহীত হতে হবে।';

  static const Set<String> authorizedRoles = {
    'STAFF_PHARMACIST',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'SUPERADMIN',
  };

  /// Returns statutory disclaimer text based on language code.
  static String getDisclaimer(String lang) {
    if (lang.toLowerCase() == 'bn') {
      return disclaimerBn;
    }
    return disclaimerEn;
  }

  /// Verifies role authorization for manual brand substitution.
  static bool isRoleAuthorized(String? role) {
    if (role == null) return false;
    return authorizedRoles.contains(role.trim().toUpperCase());
  }

  /// Checks drug eligibility for substitution. Narcotics and recalled/banned items are blocked.
  static bool isEligibleForSubstitution({
    required bool isNarcotic,
    required bool isRecalledOrBanned,
  }) {
    if (isNarcotic || isRecalledOrBanned) return false;
    return true;
  }

  /// Preflight validation for manual substitution requests.
  /// Rejects autonomous machine requests with ERR_AUTOMATED_SUBSTITUTION_FORBIDDEN.
  static SubstitutionValidationResult validateManualSubstitution({
    required String originalProductId,
    required String replacementProductId,
    required String pharmacistPcbNo,
    required String clinicalRationale,
    required bool isAutonomousMachineRequest,
  }) {
    if (isAutonomousMachineRequest) {
      return const SubstitutionValidationResult(
        isValid: false,
        errorCode: 'ERR_AUTOMATED_SUBSTITUTION_FORBIDDEN',
        errorMessage:
            'Autonomous or automated brand substitution is strictly prohibited by law. Every substitution requires human clinical evaluation and approval by a licensed pharmacist.',
      );
    }
    if (originalProductId.trim().isEmpty) {
      return const SubstitutionValidationResult(
        isValid: false,
        errorCode: 'ERR_ORIGINAL_PRODUCT_REQUIRED',
        errorMessage: 'Original product ID is required.',
      );
    }
    if (replacementProductId.trim().isEmpty) {
      return const SubstitutionValidationResult(
        isValid: false,
        errorCode: 'ERR_REPLACEMENT_PRODUCT_REQUIRED',
        errorMessage: 'Replacement product ID is required.',
      );
    }
    if (originalProductId.trim() == replacementProductId.trim()) {
      return const SubstitutionValidationResult(
        isValid: false,
        errorCode: 'ERR_IDENTICAL_PRODUCTS',
        errorMessage: 'Original and replacement products must be distinct.',
      );
    }
    if (pharmacistPcbNo.trim().length < 4) {
      return const SubstitutionValidationResult(
        isValid: false,
        errorCode: 'ERR_INVALID_PCB',
        errorMessage: 'A valid Pharmacist PCB registration number (minimum 4 characters) is required.',
      );
    }
    if (clinicalRationale.trim().length < 5) {
      return const SubstitutionValidationResult(
        isValid: false,
        errorCode: 'ERR_INVALID_RATIONALE',
        errorMessage: 'Clinical rationale (minimum 5 characters) is mandatory.',
      );
    }
    return const SubstitutionValidationResult(isValid: true);
  }
}

class SubstitutionValidationResult {
  final bool isValid;
  final String? errorCode;
  final String? errorMessage;

  const SubstitutionValidationResult({
    required this.isValid,
    this.errorCode,
    this.errorMessage,
  });
}

