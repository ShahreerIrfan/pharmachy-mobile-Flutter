/// mobile/lib/core/prescriptions/mobile_inspection_evidence_client.dart
/// Architecture Decision: ADR-0254 (P254).
/// Mobile inspection evidence repository client for DGDA compliance,
/// cold-chain monitoring, staff training records, expired stock disposal, and audit package exports.

class MobileInspectionEvidenceClient {
  static const List<String> validEvidenceTypes = [
    'REFRIGERATOR_TEMPERATURE_LOG',
    'STAFF_TRAINING_PROOF',
    'EXPIRED_STOCK_DISPOSAL',
    'PEST_CONTROL_SANITATION',
    'DGDA_INSPECTION_MEMO',
    'EQUIPMENT_CALIBRATION',
  ];

  static const List<String> validAccessLevels = [
    'PUBLIC',
    'INTERNAL',
    'CONFIDENTIAL',
    'RESTRICTED',
  ];

  static bool canManageEvidence(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' ||
        r == 'PHARMACY_OWNER' ||
        r == 'BRANCH_MANAGER' ||
        r == 'STAFF_PHARMACIST';
  }

  static bool canExportAuditPackage(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' || r == 'PHARMACY_OWNER' || r == 'BRANCH_MANAGER';
  }

  static bool canAccessDocument({
    required String? role,
    required String? accessLevel,
    required String? userBranchId,
    required String? recordBranchId,
  }) {
    if (role == null || accessLevel == null) return false;
    final r = role.trim().toUpperCase();
    final lvl = accessLevel.trim().toUpperCase();

    if (r == 'SUPERADMIN' || r == 'PHARMACY_OWNER') {
      return true;
    }

    if (r == 'BRANCH_MANAGER') {
      return userBranchId != null && userBranchId == recordBranchId;
    }

    if (r == 'STAFF_PHARMACIST') {
      if (userBranchId == null || userBranchId != recordBranchId) {
        return false;
      }
      return lvl != 'RESTRICTED';
    }

    if (r == 'CASHIER') {
      return lvl == 'PUBLIC';
    }

    return false;
  }

  static bool isColdChainExcursion({
    required double minTempCelsius,
    required double maxTempCelsius,
  }) {
    return minTempCelsius < 2.0 || maxTempCelsius > 8.0;
  }

  static void validatePreflight({
    required String? title,
    required String? evidenceType,
    required DateTime? logDate,
    required String? documentUri,
    String? sha256Hash,
  }) {
    if (title == null || title.trim().length < 3) {
      throw ArgumentError('Evidence title must be at least 3 characters.');
    }
    if (evidenceType == null ||
        !validEvidenceTypes.contains(evidenceType.trim().toUpperCase())) {
      throw ArgumentError('Invalid evidence type: $evidenceType');
    }
    if (logDate == null) {
      throw ArgumentError('logDate is required.');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDay = DateTime(logDate.year, logDate.month, logDate.day);
    if (logDay.isAfter(today)) {
      throw ArgumentError('logDate cannot be in the future.');
    }
    if (documentUri == null || documentUri.trim().isEmpty) {
      throw ArgumentError('documentUri is required.');
    }
    if (sha256Hash != null && sha256Hash.trim().isNotEmpty) {
      if (sha256Hash.trim().length != 64) {
        throw ArgumentError('sha256Hash must be 64 characters long.');
      }
    }
  }

  static String getEvidenceTypeDisplay(String? type, {String lang = 'en'}) {
    if (type == null) return '';
    final isBn = lang.toLowerCase() == 'bn';
    switch (type.trim().toUpperCase()) {
      case 'REFRIGERATOR_TEMPERATURE_LOG':
        return isBn
            ? 'রেফ্রিজারেটর তাপমাত্রা লগ (কোল্ড-চেইন)'
            : 'Refrigerator Temperature Log (Cold-Chain)';
      case 'STAFF_TRAINING_PROOF':
        return isBn
            ? 'কর্মী প্রশিক্ষণ প্রমাণপত্র'
            : 'Staff Training Proof / Certification';
      case 'EXPIRED_STOCK_DISPOSAL':
        return isBn
            ? 'মেয়াদোত্তীর্ণ ওষুধ বিনষ্টকরণ নথি'
            : 'Expired Stock Disposal Record';
      case 'PEST_CONTROL_SANITATION':
        return isBn
            ? 'কীটপতঙ্গ নিয়ন্ত্রণ ও স্যানিটেশন লগ'
            : 'Pest Control & Sanitation Record';
      case 'DGDA_INSPECTION_MEMO':
        return isBn
            ? 'ডিজিডিএ পরিদর্শন মেমো / পর্যবেক্ষণ'
            : 'DGDA Inspection Memo / Finding';
      case 'EQUIPMENT_CALIBRATION':
        return isBn
            ? 'যন্ত্রপাতি ক্যালিব্রেশন রেকর্ড'
            : 'Equipment Calibration Record';
      default:
        return type;
    }
  }

  static String formatAuditPackageSummary({
    required int totalRecords,
    required int excursionCount,
    required String disposalBdt,
    String lang = 'en',
  }) {
    final isBn = lang.toLowerCase() == 'bn';
    if (isBn) {
      return 'ডিজিডিএ অডিট প্যাকেজ: মোট $totalRecordsটি রেকর্ড, $excursionCountটি কোল্ড-চেইন বিচ্যুতি, বিনষ্ট ওষুধের মূল্য ৳$disposalBdt';
    } else {
      return 'DGDA Audit Package: $totalRecords records, $excursionCount cold-chain excursions, Expired stock value: ৳$disposalBdt';
    }
  }
}

