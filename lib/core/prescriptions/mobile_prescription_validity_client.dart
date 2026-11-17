/// mobile/lib/core/prescriptions/mobile_prescription_validity_client.dart
/// Architecture Decision: ADR-0244 (P244).
/// Phase 13: Prescriptions, Antibiotic Register & Compliance Safety.

import 'package:flutter/foundation.dart';

enum MobileValidityStatus {
  pendingCheck('Pending Check', 'যাচাই প্রক্রিয়াধীন'),
  valid('Valid', 'বৈধ ও প্রস্তুত'),
  expired('Expired', 'মেয়াদোত্তীর্ণ'),
  incompleteCredentials('Incomplete Credentials', 'চিকিৎসকের তথ্যে ঘাটতি'),
  missingDocuments('Missing Documents', 'প্রেসক্রিপশন স্ক্যান নেই'),
  invalidDates('Invalid Dates', 'তারিখের ত্রুটি'),
  revoked('Revoked', 'বাতিলকৃত');

  final String enLabel;
  final String bnLabel;

  const MobileValidityStatus(this.enLabel, this.bnLabel);

  String getLocalized(String lang) => lang.toLowerCase() == 'bn' ? bnLabel : enLabel;
}

@immutable
class MobileValidityReportDto {
  final String prescriptionId;
  final String prescriptionNumber;
  final MobileValidityStatus validityStatus;
  final bool isValid;
  final bool isExpired;
  final bool hasValidAttachment;
  final bool requiresDocument;
  final bool canDispense;
  final List<String> errors;

  const MobileValidityReportDto({
    required this.prescriptionId,
    required this.prescriptionNumber,
    required this.validityStatus,
    required this.isValid,
    required this.isExpired,
    required this.hasValidAttachment,
    required this.requiresDocument,
    required this.canDispense,
    required this.errors,
  });

  factory MobileValidityReportDto.fromJson(Map<String, dynamic> json) {
    MobileValidityStatus status = MobileValidityStatus.pendingCheck;
    final rawStatus = json['validity_status'] as String? ?? 'PENDING_CHECK';
    switch (rawStatus) {
      case 'VALID':
        status = MobileValidityStatus.valid;
        break;
      case 'EXPIRED':
        status = MobileValidityStatus.expired;
        break;
      case 'INCOMPLETE_CREDENTIALS':
        status = MobileValidityStatus.incompleteCredentials;
        break;
      case 'MISSING_DOCUMENTS':
        status = MobileValidityStatus.missingDocuments;
        break;
      case 'INVALID_DATES':
        status = MobileValidityStatus.invalidDates;
        break;
      case 'REVOKED':
        status = MobileValidityStatus.revoked;
        break;
      default:
        status = MobileValidityStatus.pendingCheck;
    }

    final temporal = json['temporal_check'] as Map<String, dynamic>? ?? {};
    final docCheck = json['supporting_document_check'] as Map<String, dynamic>? ?? {};
    final rawErrors = json['overall_errors'] as List<dynamic>? ?? [];

    return MobileValidityReportDto(
      prescriptionId: json['prescription_id'] as String? ?? '',
      prescriptionNumber: json['prescription_number'] as String? ?? '',
      validityStatus: status,
      isValid: json['is_valid'] as bool? ?? false,
      isExpired: temporal['is_expired'] as bool? ?? false,
      hasValidAttachment: docCheck['has_valid_attachment'] as bool? ?? false,
      requiresDocument: docCheck['requires_document'] as bool? ?? false,
      canDispense: json['can_dispense'] as bool? ?? false,
      errors: rawErrors.map((e) => e.toString()).toList(),
    );
  }
}

class MobilePrescriptionValidityClient {
  /// Evaluates preflight validity on mobile client before submission.
  static MobileValidityReportDto evaluatePreflight({
    required String prescriptionId,
    required String doctorName,
    required String doctorBmdcNo,
    required DateTime prescriptionDate,
    DateTime? expiryDate,
    required bool hasAttachment,
    required bool containsAntibiotic,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final errors = <String>[];

    // Prescriber check
    if (doctorName.trim().length < 3) {
      errors.add('Doctor name must be at least 3 characters.');
    }
    final cleanBmdc = doctorBmdcNo.trim().toUpperCase();
    if (cleanBmdc.length < 4 || ['NONE', 'NA', 'TEST', '0000'].contains(cleanBmdc)) {
      errors.add('Valid BMDC registration number is required.');
    }

    // Temporal check
    bool isExpired = false;
    if (prescriptionDate.isAfter(now)) {
      errors.add('Prescription date cannot be in the future.');
    }
    if (expiryDate != null) {
      if (expiryDate.isBefore(prescriptionDate)) {
        errors.add('Expiry date cannot precede issued date.');
      } else if (expiryDate.isBefore(now)) {
        isExpired = true;
        errors.add('Prescription has expired.');
      }
    }

    // Document check
    if (containsAntibiotic && !hasAttachment) {
      errors.add('Supporting prescription scan is mandatory for antibiotics.');
    }

    MobileValidityStatus status;
    if (isExpired) {
      status = MobileValidityStatus.expired;
    } else if (containsAntibiotic && !hasAttachment) {
      status = MobileValidityStatus.missingDocuments;
    } else if (errors.isNotEmpty) {
      status = MobileValidityStatus.incompleteCredentials;
    } else {
      status = MobileValidityStatus.valid;
    }

    final isValid = errors.isEmpty && status == MobileValidityStatus.valid;

    return MobileValidityReportDto(
      prescriptionId: prescriptionId,
      prescriptionNumber: 'RX-M-PREFLIGHT',
      validityStatus: status,
      isValid: isValid,
      isExpired: isExpired,
      hasValidAttachment: hasAttachment,
      requiresDocument: containsAntibiotic,
      canDispense: isValid,
      errors: errors,
    );
  }
}

