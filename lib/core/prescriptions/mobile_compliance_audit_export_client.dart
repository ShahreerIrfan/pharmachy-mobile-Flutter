/// mobile/lib/core/prescriptions/mobile_compliance_audit_export_client.dart
/// Architecture Decision: ADR-0258 (P258).
/// Phase 13: Prescriptions, Antibiotic Register & Compliance Safety.
///
/// Mobile client for DGDA Statutory Compliance Audit Package Exports,
/// role authorization checks, PHI privacy redactions, and manifest integrity.

class MobileComplianceAuditExportClient {
  static const List<String> validScopes = [
    'FULL_REGULATORY_BUNDLE',
    'ANTIBIOTIC_STEWARDSHIP',
    'COLD_CHAIN_TEMPERATURE',
    'PRESCRIPTION_VERIFICATION',
    'INCIDENT_CORRECTION',
  ];

  static bool canExportAuditPackage(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' ||
        r == 'PHARMACY_OWNER' ||
        r == 'BRANCH_MANAGER' ||
        r == 'STAFF_PHARMACIST';
  }

  static String maskPatientName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'P-ANONYMOUS';
    }
    final parts = name.trim().split(RegExp(r'\s+'));
    final masked = parts.map((p) {
      if (p.length <= 1) return '$p***';
      return '${p[0]}***';
    }).join(' ');
    return masked;
  }

  static String maskPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) return 'N/A';
    final clean = phone.trim();
    if (clean.length >= 10) {
      return '${clean.substring(0, 6)}****${clean.substring(clean.length - 4)}';
    }
    return '${clean.substring(0, clean.length >= 2 ? 2 : clean.length)}****';
  }

  static void validateDateRange(String? startDate, String? endDate) {
    if (startDate == null || startDate.trim().isEmpty) {
      throw ArgumentError('startDate is required.');
    }
    if (endDate == null || endDate.trim().isEmpty) {
      throw ArgumentError('endDate is required.');
    }
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('startDate cannot be later than endDate.');
    }
  }

  static String formatScopeDisplay(String? scope, {String lang = 'en'}) {
    if (scope == null) return '';
    final isBn = lang.toLowerCase() == 'bn';
    switch (scope.trim().toUpperCase()) {
      case 'FULL_REGULATORY_BUNDLE':
        return isBn ? 'ডিজিডিএ সামগ্রিক রেগুলেটরি বান্ডেল' : 'Full DGDA Regulatory Bundle';
      case 'ANTIBIOTIC_STEWARDSHIP':
        return isBn ? 'অ্যান্টিবায়োটিক রেজিস্টার অডিট' : 'Antibiotic Register Audit';
      case 'COLD_CHAIN_TEMPERATURE':
        return isBn ? 'কোল্ড-চেইন ও তাপমাত্রা অডিট' : 'Cold-Chain & Temperature Audit';
      case 'PRESCRIPTION_VERIFICATION':
        return isBn ? 'প্রেসক্রিপশন বিতরণ অডিট' : 'Prescription Dispensing Audit';
      case 'INCIDENT_CORRECTION':
        return isBn ? 'ইনসিডেন্ট ও প্রতিকার অডিট' : 'Incident & Correction Audit';
      default:
        return scope;
    }
  }
}
