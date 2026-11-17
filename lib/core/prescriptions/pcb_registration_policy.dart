/// P252: Pharmacy Personnel PCB Registration Tracking Policy (Flutter Mobile).
/// Architecture Decision: ADR-0252 (P252).
/// Enforces PCB qualification grades, statutory validity, and confidential evidence access.
library pcb_registration_policy;

class PcbRegistrationPolicy {
  static const String gradeA = 'GRADE_A';
  static const String gradeB = 'GRADE_B';
  static const String gradeC = 'GRADE_C';

  static const String statusActive = 'ACTIVE';
  static const String statusPendingRenewal = 'PENDING_RENEWAL';
  static const String statusExpired = 'EXPIRED';
  static const String statusSuspended = 'SUSPENDED';
  static const String statusRevoked = 'REVOKED';

  static const Set<String> privilegedEvidenceRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
  };

  /// Translates PCB grade to localized display string.
  static String getGradeDisplay(String? grade, {String lang = 'en'}) {
    final isBn = lang.toLowerCase() == 'bn';
    if (grade == null) return isBn ? 'অনির্ধারিত' : 'Unspecified';

    switch (grade.trim().toUpperCase()) {
      case gradeA:
        return isBn ? 'এ-গ্রেড (গ্র্যাজুয়েট ফার্মাসিস্ট)' : 'Grade A (Graduate Pharmacist)';
      case gradeB:
        return isBn ? 'বি-গ্রেড (ডিপ্লোমা ফার্মাসিস্ট)' : 'Grade B (Diploma Pharmacist)';
      case gradeC:
        return isBn ? 'সি-গ্রেড (ফার্মাসি টেকনিশিয়ান)' : 'Grade C (Pharmacy Technician)';
      default:
        return grade;
    }
  }

  /// Translates PCB status to localized display string.
  static String getStatusDisplay(String? status, {String lang = 'en'}) {
    final isBn = lang.toLowerCase() == 'bn';
    if (status == null) return isBn ? 'অজানা' : 'Unknown';

    switch (status.trim().toUpperCase()) {
      case statusActive:
        return isBn ? 'সক্রিয় ও বৈধ' : 'Active Valid';
      case statusPendingRenewal:
        return isBn ? 'নবায়ন প্রক্রিয়াধীন' : 'Renewal Pending';
      case statusExpired:
        return isBn ? 'মেয়াদ উত্তীর্ণ' : 'Expired';
      case statusSuspended:
        return isBn ? 'স্থগিত' : 'Suspended';
      case statusRevoked:
        return isBn ? 'বাতিল' : 'Revoked';
      default:
        return status;
    }
  }

  /// Determines whether user can access confidential evidence certificate.
  static bool canAccessEvidence({
    required String? userRole,
    required bool isSelf,
    required bool isOwnBranch,
  }) {
    if (isSelf) return true;
    if (userRole == null) return false;

    final role = userRole.trim().toUpperCase();
    if (privilegedEvidenceRoles.contains(role)) {
      return true;
    }
    return role == 'BRANCH_MANAGER' && isOwnBranch;
  }

  /// Checks if registrant has active Grade A credential required for clinical overrides.
  static bool isAuthorizedForClinicalOverrides({
    required String? grade,
    required String? status,
  }) {
    if (grade == null || status == null) return false;
    final isA = grade.trim().toUpperCase() == gradeA;
    final st = status.trim().toUpperCase();
    final isValid = st == statusActive || st == statusPendingRenewal;
    return isA && isValid;
  }

  /// Calculates days until expiry date.
  static int daysUntilExpiry(DateTime validUntil, DateTime currentDate) {
    return validUntil.difference(currentDate).inDays;
  }

  /// Identifies if credential is close to expiration (within 30 days).
  static bool isExpiringSoon(int daysRemaining) {
    return daysRemaining >= 0 && daysRemaining <= 30;
  }
}

