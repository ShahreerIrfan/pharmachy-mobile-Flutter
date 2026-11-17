/// mobile/lib/core/prescriptions/mobile_safety_end_to_end_client.dart
/// Architecture Decision: ADR-0260 (P260).
/// Phase 13: Prescriptions, Antibiotic Register & Compliance Safety.
///
/// Mobile client helper for end-to-end clinical safety verification:
/// - Prohibited non-Rx dispensing gate enforcement.
/// - Stale classification invalidation alerts.
/// - Recalled batch dispensing blocking alerts.
/// - Expired prescription validity validation.
/// - Credentialed pharmacist verification role gates.

class MobileSafetyEndToEndClient {
  static const List<String> pharmacistRoles = [
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
  ];

  static bool isAuthorizedPharmacist(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return pharmacistRoles.contains(r);
  }

  static bool canFinalizeOrder({
    required bool requiresRx,
    required bool isRxVerified,
    required bool hasBlockedRecall,
    bool isOffline = false,
  }) {
    if (hasBlockedRecall) {
      return false;
    }
    if (requiresRx) {
      if (isOffline) {
        return false;
      }
      return isRxVerified;
    }
    return true;
  }

  static bool isClassificationStale({
    required int lineVersion,
    required int liveVersion,
  }) {
    return liveVersion > lineVersion;
  }

  static void validatePrescriptionDate({
    required String? rxDate,
    required String? currentDate,
  }) {
    if (rxDate == null || rxDate.trim().isEmpty) {
      throw ArgumentError('Prescription date is required.');
    }
    if (currentDate == null || currentDate.trim().isEmpty) {
      throw ArgumentError('Current date is required.');
    }
    if (rxDate.compareTo(currentDate) > 0) {
      throw ArgumentError('Prescription date cannot be in the future.');
    }

    final rxParts = rxDate.split('-');
    final curParts = currentDate.split('-');
    if (rxParts.length == 3 && curParts.length == 3) {
      final rxYear = int.tryParse(rxParts[0]) ?? 0;
      final curYear = int.tryParse(curParts[0]) ?? 0;
      if (curYear - rxYear > 1) {
        throw ArgumentError('Prescription is older than 365 days.');
      }
    }
  }

  static String formatSafetyAlert({
    required String alertCode,
    required String medicineName,
    String lang = 'en',
  }) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (alertCode) {
      case 'ERR_RX_VERIFICATION_REQUIRED':
        return isBn
            ? 'সতর্কতা: $medicineName-এর জন্য নিবন্ধিত ফার্মাসিস্ট কর্তৃক প্রেসক্রিপশন যাচাইকরণ আবশ্যক।'
            : 'ALERT: Prescription verification by a registered pharmacist is required for $medicineName.';
      case 'ERR_BATCH_RECALLED':
        return isBn
            ? 'জরুরি প্রত্যাহার: $medicineName-এর এই ব্যাচটি ডিজিডিএ প্রত্যাহার তালিকার অন্তর্ভুক্ত! বিতরণ নিষিদ্ধ।'
            : 'RECALL ALERT: This batch of $medicineName is under active DGDA recall! Dispensing is strictly prohibited.';
      case 'ERR_STALE_CLASSIFICATION':
        return isBn
            ? 'পুনঃযাচাইকরণ প্রয়োজন: $medicineName-এর রেগুলেটরি শ্রেণিবিভাগ হালনাগাদ হয়েছে।'
            : 'RE-VERIFICATION REQUIRED: Regulatory classification for $medicineName was updated. Re-verification required.';
      default:
        return isBn
            ? 'নিরাপত্তা সতর্কতা [$alertCode]: $medicineName'
            : 'Safety Alert [$alertCode]: $medicineName';
    }
  }
}

