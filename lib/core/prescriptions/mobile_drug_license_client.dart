/// P251: Branch Drug License Client & Expiration Evaluator (Flutter Mobile).
/// Architecture Decision: ADR-0251 (P251).
/// Tracks branch DGDA drug licenses, validity status, and renewal warning states.
library mobile_drug_license_client;

enum DrugLicenseStatus {
  active,
  renewalPending,
  expired,
  suspended,
  revoked;

  static DrugLicenseStatus fromString(String? val) {
    switch (val?.toUpperCase().trim()) {
      case 'ACTIVE':
        return DrugLicenseStatus.active;
      case 'RENEWAL_PENDING':
        return DrugLicenseStatus.renewalPending;
      case 'EXPIRED':
        return DrugLicenseStatus.expired;
      case 'SUSPENDED':
        return DrugLicenseStatus.suspended;
      case 'REVOKED':
        return DrugLicenseStatus.revoked;
      default:
        return DrugLicenseStatus.active;
    }
  }

  String toApiString() {
    switch (this) {
      case DrugLicenseStatus.active:
        return 'ACTIVE';
      case DrugLicenseStatus.renewalPending:
        return 'RENEWAL_PENDING';
      case DrugLicenseStatus.expired:
        return 'EXPIRED';
      case DrugLicenseStatus.suspended:
        return 'SUSPENDED';
      case DrugLicenseStatus.revoked:
        return 'REVOKED';
    }
  }
}

enum DrugLicenseType {
  form20Retail,
  form20aBiological,
  form21Wholesale;

  String getLocalizedLabel(String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (this) {
      case DrugLicenseType.form20Retail:
        return isBn ? 'ফরম ২০ - খুচরা ড্রাগ লাইসেন্স' : 'Form 20 - Retail Drug License';
      case DrugLicenseType.form20aBiological:
        return isBn ? 'ফরম ২০এ - বায়োলজিক্যাল ড্রাগ লাইসেন্স' : 'Form 20A - Biological Drug License';
      case DrugLicenseType.form21Wholesale:
        return isBn ? 'ফরম ২১ - পাইকারি ড্রাগ লাইসেন্স' : 'Form 21 - Wholesale Drug License';
    }
  }
}

class MobileDrugLicenseClient {
  static const Set<String> authorizedManageRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
  };

  /// Checks if user role is authorized to register or update drug licenses.
  static bool isRoleAuthorizedToManage(String? role) {
    if (role == null) return false;
    return authorizedManageRoles.contains(role.trim().toUpperCase());
  }

  /// Evaluates license validity and warning states based on days until expiry.
  static LicenseEvaluationResult evaluateLicense({
    required DrugLicenseStatus status,
    required int daysUntilExpiry,
  }) {
    if (status == DrugLicenseStatus.suspended || status == DrugLicenseStatus.revoked) {
      return LicenseEvaluationResult(
        isValid: false,
        statusCode: status.toApiString(),
        messageEn: 'Drug license is suspended or revoked by DGDA. Sales are legally restricted.',
        messageBn: 'ডিজিডিএ কর্তৃক ড্রাগ লাইসেন্স স্থগিত বা বাতিল করা হয়েছে।',
      );
    }
    if (daysUntilExpiry < 0) {
      if (status == DrugLicenseStatus.renewalPending) {
        return const LicenseEvaluationResult(
          isValid: true,
          statusCode: 'RENEWAL_PENDING',
          messageEn: 'License expired but renewal application is submitted.',
          messageBn: 'ড্রাগ লাইসেন্সের মেয়াদ শেষ হলেও নবায়ন আবেদন প্রক্রিয়াধীন।',
        );
      }
      return const LicenseEvaluationResult(
        isValid: false,
        statusCode: 'EXPIRED',
        messageEn: 'Drug license has expired. Dispensing regulated drugs is legally prohibited.',
        messageBn: 'ড্রাগ লাইসেন্সের মেয়াদ উত্তীর্ণ। নবায়ন ব্যতীত কার্যক্রম বেআইনি।',
      );
    }
    if (daysUntilExpiry <= 30) {
      return LicenseEvaluationResult(
        isValid: true,
        statusCode: 'EXPIRING_SOON',
        messageEn: 'Drug license expires in $daysUntilExpiry days. Immediate renewal required.',
        messageBn: 'ড্রাগ লাইসেন্সের মেয়াদ আর $daysUntilExpiry দিন বাকি। জরুরি নবায়ন আবশ্যক।',
      );
    }
    return const LicenseEvaluationResult(
      isValid: true,
      statusCode: 'ACTIVE',
      messageEn: 'Drug license is active and valid.',
      messageBn: 'ড্রাগ লাইসেন্স সক্রিয় ও বৈধ।',
    );
  }

  /// Preflight validation for drug license registration inputs.
  static bool validatePreflight({
    required String licenseNumber,
    required String issuingAuthority,
    required String issueDateStr,
    required String expiryDateStr,
  }) {
    if (licenseNumber.trim().length < 4) return false;
    if (issuingAuthority.trim().length < 3) return false;
    try {
      final issueDate = DateTime.parse(issueDateStr.trim());
      final expiryDate = DateTime.parse(expiryDateStr.trim());
      if (!expiryDate.isAfter(issueDate)) return false;
    } catch (_) {
      return false;
    }
    return true;
  }
}

class LicenseEvaluationResult {
  final bool isValid;
  final String statusCode;
  final String messageEn;
  final String messageBn;

  const LicenseEvaluationResult({
    required this.isValid,
    required this.statusCode,
    required this.messageEn,
    required this.messageBn,
  });
}

