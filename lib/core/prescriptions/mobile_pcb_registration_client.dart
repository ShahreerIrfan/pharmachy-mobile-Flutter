/// P252: Pharmacy Personnel PCB Registration Tracking & Access Client (Flutter Mobile).
/// Architecture Decision: ADR-0252 (P252).
/// Tracks Pharmacy Council of Bangladesh credentials, Grade A/B/C hierarchy, and evidence privacy.
library mobile_pcb_registration_client;

enum PcbGrade {
  gradeA,
  gradeB,
  gradeC;

  static PcbGrade fromString(String? val) {
    switch (val?.toUpperCase().trim()) {
      case 'GRADE_A':
        return PcbGrade.gradeA;
      case 'GRADE_B':
        return PcbGrade.gradeB;
      case 'GRADE_C':
        return PcbGrade.gradeC;
      default:
        return PcbGrade.gradeA;
    }
  }

  String toApiString() {
    switch (this) {
      case PcbGrade.gradeA:
        return 'GRADE_A';
      case PcbGrade.gradeB:
        return 'GRADE_B';
      case PcbGrade.gradeC:
        return 'GRADE_C';
    }
  }

  String getLocalizedLabel(String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (this) {
      case PcbGrade.gradeA:
        return isBn
            ? 'এ-গ্রেড (গ্র্যাজুয়েট ফার্মাসিস্ট - বি.ফার্ম/এম.ফার্ম)'
            : 'Grade A (Graduate Pharmacist - B.Pharm/M.Pharm)';
      case PcbGrade.gradeB:
        return isBn ? 'বি-গ্রেড (ডিপ্লোমা ইন ফার্মাসি)' : 'Grade B (Diploma in Pharmacy)';
      case PcbGrade.gradeC:
        return isBn ? 'সি-গ্রেড (ফার্মাসি টেকনিশিয়ান / শিক্ষানবিস)' : 'Grade C (Pharmacy Technician / Apprentice)';
    }
  }
}

enum PcbStatus {
  active,
  pendingRenewal,
  expired,
  suspended,
  revoked;

  static PcbStatus fromString(String? val) {
    switch (val?.toUpperCase().trim()) {
      case 'ACTIVE':
        return PcbStatus.active;
      case 'PENDING_RENEWAL':
        return PcbStatus.pendingRenewal;
      case 'EXPIRED':
        return PcbStatus.expired;
      case 'SUSPENDED':
        return PcbStatus.suspended;
      case 'REVOKED':
        return PcbStatus.revoked;
      default:
        return PcbStatus.active;
    }
  }

  String toApiString() {
    switch (this) {
      case PcbStatus.active:
        return 'ACTIVE';
      case PcbStatus.pendingRenewal:
        return 'PENDING_RENEWAL';
      case PcbStatus.expired:
        return 'EXPIRED';
      case PcbStatus.suspended:
        return 'SUSPENDED';
      case PcbStatus.revoked:
        return 'REVOKED';
    }
  }
}

class MobilePcbRegistrationClient {
  static const Set<String> authorizedManageRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
  };

  /// Checks if caller is authorized to register or edit staff PCB records.
  static bool isRoleAuthorizedToManage(String? role) {
    if (role == null) return false;
    return authorizedManageRoles.contains(role.trim().toUpperCase());
  }

  /// Checks confidential evidence clearance.
  static bool canViewEvidence({required String? userRole, required bool isSelf}) {
    if (isSelf) return true;
    if (userRole == null) return false;
    final r = userRole.trim().toUpperCase();
    return r == 'SUPERADMIN' || r == 'PHARMACY_OWNER' || r == 'BRANCH_MANAGER';
  }

  /// Evaluates qualification grade authorization hierarchy.
  static bool isGradeAuthorized({
    required PcbGrade registrantGrade,
    required PcbGrade requiredGrade,
  }) {
    if (registrantGrade == PcbGrade.gradeA) return true;
    if (registrantGrade == PcbGrade.gradeB) {
      return requiredGrade == PcbGrade.gradeB || requiredGrade == PcbGrade.gradeC;
    }
    return requiredGrade == PcbGrade.gradeC;
  }

  /// Evaluates live validity status and warning messages.
  static PcbEvaluationResult evaluateRegistration({
    required PcbStatus status,
    required int daysUntilExpiry,
  }) {
    if (status == PcbStatus.suspended || status == PcbStatus.revoked) {
      return PcbEvaluationResult(
        isValid: false,
        statusCode: status.toApiString(),
        messageEn: 'PCB Registration is suspended or revoked by the Pharmacy Council.',
        messageBn: 'ফার্মেসি কাউন্সিল কর্তৃক পিসিবি রেজিস্ট্রেশন স্থগিত বা বাতিল করা হয়েছে।',
      );
    }
    if (daysUntilExpiry < 0) {
      if (status == PcbStatus.pendingRenewal) {
        return const PcbEvaluationResult(
          isValid: true,
          statusCode: 'PENDING_RENEWAL',
          messageEn: 'PCB Registration expired but renewal documentation is submitted.',
          messageBn: 'পিসিবি রেজিস্ট্রেশনের মেয়াদ শেষ হলেও নবায়ন আবেদন প্রক্রিয়াধীন।',
        );
      }
      return const PcbEvaluationResult(
        isValid: false,
        statusCode: 'EXPIRED',
        messageEn: 'PCB Registration has expired. Clinical practice is unauthorized.',
        messageBn: 'পিসিবি রেজিস্ট্রেশনের মেয়াদ উত্তীর্ণ। ক্লিনিক্যাল কার্যক্রম পরিচালনা অননুমোদিত।',
      );
    }
    if (daysUntilExpiry <= 30) {
      return PcbEvaluationResult(
        isValid: true,
        statusCode: 'EXPIRING_SOON',
        messageEn: 'PCB Registration expires in $daysUntilExpiry days. Renewal required.',
        messageBn: 'পিসিবি রেজিস্ট্রেশনের মেয়াদ আর $daysUntilExpiry দিন বাকি। জরুরি নবায়ন আবশ্যক।',
      );
    }
    return const PcbEvaluationResult(
      isValid: true,
      statusCode: 'ACTIVE',
      messageEn: 'PCB Registration is active and valid.',
      messageBn: 'পিসিবি রেজিস্ট্রেশন সক্রিয় ও বৈধ।',
    );
  }

  /// Preflight validation for PCB registration entry.
  static bool validatePreflight({
    required String registrationNo,
    required String registeredName,
    required String issueDateStr,
    required String validUntilStr,
  }) {
    if (registrationNo.trim().length < 3) return false;
    if (registeredName.trim().length < 2) return false;
    try {
      final issueDate = DateTime.parse(issueDateStr.trim());
      final validUntil = DateTime.parse(validUntilStr.trim());
      if (validUntil.isBefore(issueDate)) return false;
    } catch (_) {
      return false;
    }
    return true;
  }
}

class PcbEvaluationResult {
  final bool isValid;
  final String statusCode;
  final String messageEn;
  final String messageBn;

  const PcbEvaluationResult({
    required this.isValid,
    required this.statusCode,
    required this.messageEn,
    required this.messageBn,
  });
}

