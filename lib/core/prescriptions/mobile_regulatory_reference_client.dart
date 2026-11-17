/// mobile/lib/core/prescriptions/mobile_regulatory_reference_client.dart
/// Architecture Decision: ADR-0259 (P259).
/// Phase 13: Prescriptions, Antibiotic Register & Compliance Safety.
///
/// Mobile helper for maintaining reviewed statutory and clinical regulatory references,
/// scheduling compliance review dates, and verifying document digest seals.

class MobileRegulatoryReferenceClient {
  static const List<String> validJurisdictions = [
    'DGDA_BANGLADESH',
    'PCB_BANGLADESH',
    'WHO_INTERNATIONAL',
    'MOHFW_BANGLADESH',
    'OTHER',
  ];

  static const List<String> validStatuses = [
    'ACTIVE',
    'UNDER_REVIEW',
    'SUPERSEDED',
    'ARCHIVED',
  ];

  static bool canManageReference(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' ||
        r == 'PHARMACY_OWNER' ||
        r == 'BRANCH_MANAGER' ||
        r == 'STAFF_PHARMACIST';
  }

  static bool canViewReference(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' ||
        r == 'PHARMACY_OWNER' ||
        r == 'BRANCH_MANAGER' ||
        r == 'STAFF_PHARMACIST' ||
        r == 'CASHIER';
  }

  static void validateReferenceData({
    required String? title,
    required String? sourceUri,
    required String? version,
    required String? effectiveDate,
    required String? nextReviewDate,
  }) {
    if (title == null || title.trim().length < 3) {
      throw ArgumentError('Title must be at least 3 characters.');
    }
    if (sourceUri == null ||
        (!sourceUri.startsWith('http://') &&
            !sourceUri.startsWith('https://') &&
            !sourceUri.startsWith('ftp://'))) {
      throw ArgumentError('sourceUri must be a valid URL (http:// or https://).');
    }
    if (version == null || version.trim().isEmpty) {
      throw ArgumentError('version is required.');
    }
    if (effectiveDate == null || effectiveDate.trim().isEmpty) {
      throw ArgumentError('effectiveDate is required (YYYY-MM-DD).');
    }
    if (nextReviewDate == null || nextReviewDate.trim().isEmpty) {
      throw ArgumentError('nextReviewDate is required (YYYY-MM-DD).');
    }
    if (effectiveDate.compareTo(nextReviewDate) > 0) {
      throw ArgumentError('nextReviewDate cannot be earlier than effectiveDate.');
    }
  }

  static bool isReviewOverdue(String? nextReviewDate, String? currentDate) {
    if (nextReviewDate == null || currentDate == null) return false;
    return nextReviewDate.compareTo(currentDate) < 0;
  }

  static String formatJurisdictionDisplay(String? jurisdiction, {String lang = 'en'}) {
    if (jurisdiction == null) return '';
    final isBn = lang.toLowerCase() == 'bn';
    switch (jurisdiction.trim().toUpperCase()) {
      case 'DGDA_BANGLADESH':
        return isBn ? 'ডিজিডিএ (বাংলাদেশ)' : 'DGDA (Bangladesh)';
      case 'PCB_BANGLADESH':
        return isBn ? 'ফার্মেসি কাউন্সিল (পিসিবি)' : 'Pharmacy Council (PCB)';
      case 'WHO_INTERNATIONAL':
        return isBn ? 'বিশ্ব স্বাস্থ্য সংস্থা (WHO)' : 'WHO International';
      case 'MOHFW_BANGLADESH':
        return isBn ? 'স্বাস্থ্য ও পরিবার কল্যাণ মন্ত্রণালয়' : 'MOHFW Bangladesh';
      default:
        return jurisdiction;
    }
  }

  static String formatStatusBadge({
    required String jurisdiction,
    required String version,
    required String status,
    bool isOverdue = false,
    String lang = 'en',
  }) {
    final isBn = lang.toLowerCase() == 'bn';
    final jurLabel = formatJurisdictionDisplay(jurisdiction, lang: lang);

    if (isOverdue) {
      return isBn
          ? '[মেয়াদোত্তীর্ণ পর্যালোচনা] $jurLabel v$version'
          : '[REVIEW OVERDUE] $jurLabel v$version';
    }

    return isBn
        ? '[$status] $jurLabel v$version'
        : '[$status] $jurLabel v$version';
  }
}
