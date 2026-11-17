/// mobile/lib/core/prescriptions/mobile_temperature_safety_review_client.dart
/// Architecture Decision: ADR-0257 (P257).
/// Phase 13: Prescriptions, Antibiotic Register & Compliance Safety.
///
/// Mobile client for Temperature Excursion Safety Reviews,
/// pharmacist disposition authorization, and clinical safety checks.

class MobileTemperatureSafetyReviewClient {
  static const List<String> validDecisions = [
    'RELEASE_TO_ACTIVE',
    'RETURN_TO_SUPPLIER',
    'CONDEMN_DISPOSAL',
  ];

  static const List<String> validSeverities = [
    'MINOR',
    'MODERATE',
    'CRITICAL',
  ];

  static bool canReviewExcursion(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' ||
        r == 'PHARMACY_OWNER' ||
        r == 'BRANCH_MANAGER' ||
        r == 'STAFF_PHARMACIST';
  }

  static bool isDispensingAllowed({
    required bool isQuarantined,
    required String? batchStatus,
    required String? latestDecision,
  }) {
    if (!isQuarantined && (batchStatus?.toUpperCase() == 'ACTIVE')) {
      return true;
    }
    return latestDecision?.toUpperCase() == 'RELEASE_TO_ACTIVE';
  }

  static void validatePreflight({
    required String? batchNumber,
    required String? decision,
    required double? maxExposedTemp,
    required String? clinicalJustification,
    required bool isExpired,
  }) {
    if (batchNumber == null || batchNumber.trim().isEmpty) {
      throw ArgumentError('batchNumber is required.');
    }
    if (decision == null || !validDecisions.contains(decision.trim().toUpperCase())) {
      throw ArgumentError('Valid decision is required: $validDecisions');
    }
    if (maxExposedTemp == null) {
      throw ArgumentError('maxExposedTemp is required.');
    }

    final normDecision = decision.trim().toUpperCase();
    if (normDecision == 'RELEASE_TO_ACTIVE') {
      if (clinicalJustification == null || clinicalJustification.trim().length < 15) {
        throw ArgumentError(
            'Clinical justification must be at least 15 characters for release to active stock.');
      }
      if (isExpired) {
        throw StateError(
            'Statutory Safety Violation: Expired medicine batch cannot be released to active sellable stock.');
      }
    }
  }

  static String getDecisionDisplay(String? decision, {String lang = 'en'}) {
    if (decision == null) return '';
    final isBn = lang.toLowerCase() == 'bn';
    switch (decision.trim().toUpperCase()) {
      case 'RELEASE_TO_ACTIVE':
        return isBn ? 'সক্রিয় স্টকে ফেরত' : 'Release to Active Sellable';
      case 'RETURN_TO_SUPPLIER':
        return isBn ? 'সরবরাহকারীকে ফেরত' : 'Return to Supplier';
      case 'CONDEMN_DISPOSAL':
        return isBn ? 'বিনষ্ট ও বর্জন' : 'Condemn & Disposal';
      default:
        return decision;
    }
  }

  static String formatClinicalSummary({
    required String batchNumber,
    required String productName,
    required String decision,
    required double totalExposedValue,
    String lang = 'en',
  }) {
    final isBn = lang.toLowerCase() == 'bn';
    final valStr = totalExposedValue.toStringAsFixed(2);
    if (isBn) {
      return '$productName (ব্যাচ: $batchNumber) - সিদ্ধান্ত: ${getDecisionDisplay(decision, lang: 'bn')}, আনুমানিক মূল্য: $valStr ৳';
    }
    return '$productName (Batch: $batchNumber) - Decision: ${getDecisionDisplay(decision, lang: 'en')}, Exposed Value: $valStr BDT';
  }
}
