/// P247: OTC & Prescription Status Versioning Client (Flutter Mobile).
/// Architecture Decision: ADR-0247 (P247).
/// Provides dynamic classification resolution and versioning display.
library mobile_otc_rx_classification_client;

enum ClassificationType {
  otc,
  prescriptionOnly,
  narcoticScheduled,
  antimicrobialAccess,
  antimicrobialWatch,
  antimicrobialReserve,
  recalled,
  banned;

  static ClassificationType fromString(String val) {
    switch (val.toUpperCase().trim()) {
      case 'OTC':
        return ClassificationType.otc;
      case 'PRESCRIPTION_ONLY':
        return ClassificationType.prescriptionOnly;
      case 'NARCOTIC_SCHEDULED':
        return ClassificationType.narcoticScheduled;
      case 'ANTIMICROBIAL_ACCESS':
        return ClassificationType.antimicrobialAccess;
      case 'ANTIMICROBIAL_WATCH':
        return ClassificationType.antimicrobialWatch;
      case 'ANTIMICROBIAL_RESERVE':
        return ClassificationType.antimicrobialReserve;
      case 'RECALLED':
        return ClassificationType.recalled;
      case 'BANNED':
        return ClassificationType.banned;
      default:
        return ClassificationType.prescriptionOnly;
    }
  }

  String toApiString() {
    switch (this) {
      case ClassificationType.otc:
        return 'OTC';
      case ClassificationType.prescriptionOnly:
        return 'PRESCRIPTION_ONLY';
      case ClassificationType.narcoticScheduled:
        return 'NARCOTIC_SCHEDULED';
      case ClassificationType.antimicrobialAccess:
        return 'ANTIMICROBIAL_ACCESS';
      case ClassificationType.antimicrobialWatch:
        return 'ANTIMICROBIAL_WATCH';
      case ClassificationType.antimicrobialReserve:
        return 'ANTIMICROBIAL_RESERVE';
      case ClassificationType.recalled:
        return 'RECALLED';
      case ClassificationType.banned:
        return 'BANNED';
    }
  }

  String getLocalizedLabel(String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (this) {
      case ClassificationType.otc:
        return isBn ? 'প্রেসক্রিপশন ব্যতীত বিক্রয়যোগ্য (OTC)' : 'Over-The-Counter (OTC)';
      case ClassificationType.prescriptionOnly:
        return isBn ? 'প্রেসক্রিপশন আবশ্যক (POM)' : 'Prescription-Only Medicine (POM)';
      case ClassificationType.narcoticScheduled:
        return isBn ? 'নিয়ন্ত্রিত মাদক / সিডিউল-জি ওষুধ' : 'Narcotic / Controlled Substance (Schedule-G)';
      case ClassificationType.antimicrobialAccess:
        return isBn ? 'অ্যান্টিমাইক্রোবিয়াল - অ্যাক্সেস গ্রুপ' : 'Antimicrobial AWaRe - Access';
      case ClassificationType.antimicrobialWatch:
        return isBn ? 'অ্যান্টিমাইক্রোবিয়াল - ওয়াচ গ্রুপ' : 'Antimicrobial AWaRe - Watch';
      case ClassificationType.antimicrobialReserve:
        return isBn ? 'অ্যান্টিমাইক্রোবিয়াল - রিজার্ভ গ্রুপ' : 'Antimicrobial AWaRe - Reserve';
      case ClassificationType.recalled:
        return isBn ? 'ডিজিডিএ প্রত্যাহারকৃত ওষুধ (বিক্রয় নিষিদ্ধ)' : 'DGDA Statutory Safety Recall';
      case ClassificationType.banned:
        return isBn ? 'নিষিদ্ধ ওষুধ (বিক্রয় সম্পূর্ণ অবৈধ)' : 'Banned & Prohibited';
    }
  }

  bool get requiresPrescription => this != ClassificationType.otc;

  bool get isDispensingBlocked =>
      this == ClassificationType.recalled || this == ClassificationType.banned;
}

class ClassificationSnapshotDto {
  final String snapshotId;
  final String productId;
  final int versionNumber;
  final ClassificationType classificationType;
  final String regulatorySource;
  final String effectiveFrom;
  final String? effectiveTo;
  final bool isCurrent;
  final bool isDispensingBlocked;
  final String reviewNotes;
  final String immutableHash;

  const ClassificationSnapshotDto({
    required this.snapshotId,
    required this.productId,
    required this.versionNumber,
    required this.classificationType,
    required this.regulatorySource,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.isCurrent,
    required this.isDispensingBlocked,
    required this.reviewNotes,
    required this.immutableHash,
  });

  factory ClassificationSnapshotDto.fromJson(Map<String, dynamic> json) {
    return ClassificationSnapshotDto(
      snapshotId: json['snapshot_id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      classificationType: ClassificationType.fromString(
        json['classification_type'] as String? ?? 'OTC',
      ),
      regulatorySource: json['regulatory_source'] as String? ?? '',
      effectiveFrom: json['effective_from'] as String? ?? '',
      effectiveTo: json['effective_to'] as String?,
      isCurrent: json['is_current'] as bool? ?? false,
      isDispensingBlocked: json['is_dispensing_blocked'] as bool? ?? false,
      reviewNotes: json['review_notes'] as String? ?? '',
      immutableHash: json['immutable_hash'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'snapshot_id': snapshotId,
      'product_id': productId,
      'version_number': versionNumber,
      'classification_type': classificationType.toApiString(),
      'regulatory_source': regulatorySource,
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
      'is_current': isCurrent,
      'is_dispensing_blocked': isDispensingBlocked,
      'review_notes': reviewNotes,
      'immutable_hash': immutableHash,
    };
  }

  bool get requiresPrescription => classificationType.requiresPrescription;
}

class MobileOtcRxClassificationClient {
  /// Validates preflight parameters before creating or changing regulatory classification.
  static bool validatePreflight({
    required String productId,
    required ClassificationType type,
    required String source,
    required String notes,
  }) {
    if (productId.trim().isEmpty) return false;
    if (source.trim().length < 3) return false;
    if (notes.trim().length < 5) return false;
    return true;
  }

  /// Determines whether a given snapshot was effective at [targetIsoDateTime].
  static bool isEffectiveAt(ClassificationSnapshotDto snapshot, String targetIsoDateTime) {
    if (snapshot.effectiveFrom.isNotEmpty &&
        targetIsoDateTime.compareTo(snapshot.effectiveFrom) < 0) {
      return false;
    }
    if (snapshot.effectiveTo != null &&
        snapshot.effectiveTo!.isNotEmpty &&
        targetIsoDateTime.compareTo(snapshot.effectiveTo!) >= 0) {
      return false;
    }
    return true;
  }
}

