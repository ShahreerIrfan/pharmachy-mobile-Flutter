/// mobile/lib/core/prescriptions/mobile_recall_dispensing_client.dart
/// Architecture Decision: ADR-0256 (P256).
/// Mobile recall alert & dispensing lock client for DGDA compliance,
/// reservation eviction, and historical sales lookup without altering history.

class MobileRecallDispensingClient {
  static const List<String> validClasses = [
    'CLASS_I',
    'CLASS_II',
    'CLASS_III',
  ];

  static const List<String> validSources = [
    'DGDA_MANDATORY',
    'MANUFACTURER_VOLUNTARY',
    'INTERNAL_PHARMACY',
  ];

  static bool canManageRecall(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' ||
        r == 'PHARMACY_OWNER' ||
        r == 'BRANCH_MANAGER' ||
        r == 'STAFF_PHARMACIST';
  }

  static bool canDispenseBatch({
    required bool isRecalled,
    required String? status,
  }) {
    if (isRecalled) return false;
    if (status == null) return false;
    return status.trim().toUpperCase() == 'ACTIVE';
  }

  static void validatePreflight({
    required String? batchNumber,
    required String? productName,
    required String? recallReason,
    required String? recallClass,
  }) {
    if (batchNumber == null || batchNumber.trim().length < 2) {
      throw ArgumentError('batchNumber must be at least 2 characters.');
    }
    if (productName == null || productName.trim().isEmpty) {
      throw ArgumentError('productName is required.');
    }
    if (recallReason == null || recallReason.trim().isEmpty) {
      throw ArgumentError('recallReason is required.');
    }
    if (recallClass == null ||
        !validClasses.contains(recallClass.trim().toUpperCase())) {
      throw ArgumentError('Invalid recallClass: $recallClass');
    }
  }

  static String getRecallClassDisplay(String? recallClass, {String lang = 'en'}) {
    if (recallClass == null) return '';
    final isBn = lang.toLowerCase() == 'bn';
    switch (recallClass.trim().toUpperCase()) {
      case 'CLASS_I':
        return isBn
            ? 'ক্লাস ১ (মারাত্মক / জীবন বিপন্নকারী ঝুঁকি)'
            : 'Class I (Dangerous / Life-threatening)';
      case 'CLASS_II':
        return isBn
            ? 'ক্লাস ২ (অস্থায়ী বা চিকিৎসাযোগ্য ঝুঁকি)'
            : 'Class II (Temporary / Reversible defect)';
      case 'CLASS_III':
        return isBn
            ? 'ক্লাস ৩ (লেবেলিং / কারিগরি ত্রুটি)'
            : 'Class III (Technical / Labeling defect)';
      default:
        return recallClass;
    }
  }

  static String formatHistoricalImpactSummary({
    required int totalInvoices,
    required String totalUnitsSold,
    required String totalValueBdt,
    String lang = 'en',
  }) {
    final isBn = lang.toLowerCase() == 'bn';
    if (isBn) {
      return 'রিকল অডিট ট্র্যাকিং: মোট $totalInvoicesটি ইনভয়েস প্রভাবিত, বিক্রিত ওষুধ $totalUnitsSold ইউনিট, মোট মূল্য ৳$totalValueBdt (অতীত সেলস রেকর্ড অপরিবর্তিত)';
    } else {
      return 'Recall Historical Audit: $totalInvoices invoices impacted, $totalUnitsSold units sold, Total value: ৳$totalValueBdt (Past sales history unmodified)';
    }
  }
}

