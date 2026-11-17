/// mobile/lib/core/prescriptions/mobile_prescription_record_client.dart
/// Architecture Decision: ADR-0241 (P241).
/// Phase 13: Prescriptions, Antibiotic Register & Compliance Safety.

import 'package:flutter/foundation.dart';

enum MobilePrescriptionStatus {
  pending('Pending Verification', 'অনুমোদনের অপেক্ষায়'),
  verified('Verified by Pharmacist', 'ফার্মাসিস্ট দ্বারা যাচাইকৃত'),
  partiallyDispensed('Partially Dispensed', 'আংশিক প্রদানকৃত'),
  dispensed('Dispensed', 'সম্পূর্ণ প্রদানকৃত'),
  rejected('Rejected', 'প্রত্যাখ্যাত'),
  cancelled('Cancelled', 'বাতিলকৃত'),
  expired('Expired', 'মেয়াদোত্তীর্ণ');

  final String enLabel;
  final String bnLabel;

  const MobilePrescriptionStatus(this.enLabel, this.bnLabel);

  String getLocalized(String lang) => lang.toLowerCase() == 'bn' ? bnLabel : enLabel;

  static MobilePrescriptionStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'VERIFIED':
        return MobilePrescriptionStatus.verified;
      case 'PARTIALLY_DISPENSED':
        return MobilePrescriptionStatus.partiallyDispensed;
      case 'DISPENSED':
        return MobilePrescriptionStatus.dispensed;
      case 'REJECTED':
        return MobilePrescriptionStatus.rejected;
      case 'CANCELLED':
        return MobilePrescriptionStatus.cancelled;
      case 'EXPIRED':
        return MobilePrescriptionStatus.expired;
      case 'PENDING':
      default:
        return MobilePrescriptionStatus.pending;
    }
  }
}

enum MobileUiState {
  loading,
  ready,
  empty,
  error,
  offline,
  permissionDenied,
}

@immutable
class MobilePrescriptionItemDto {
  final int id;
  final String productId;
  final String productBrand;
  final String dosageInstructions;
  final int durationDays;
  final int quantityPrescribed;
  final int quantityDispensed;
  final bool isDispensed;

  const MobilePrescriptionItemDto({
    required this.id,
    required this.productId,
    required this.productBrand,
    required this.dosageInstructions,
    required this.durationDays,
    required this.quantityPrescribed,
    required this.quantityDispensed,
    required this.isDispensed,
  });

  int get remainingQuantity => (quantityPrescribed - quantityDispensed) > 0
      ? (quantityPrescribed - quantityDispensed)
      : 0;

  factory MobilePrescriptionItemDto.fromJson(Map<String, dynamic> json) {
    return MobilePrescriptionItemDto(
      id: json['id'] as int? ?? 0,
      productId: json['product'] as String? ?? json['product_id'] as String? ?? '',
      productBrand: json['product_brand'] as String? ?? '',
      dosageInstructions: json['dosage_instructions'] as String? ?? '',
      durationDays: json['duration_days'] as int? ?? 7,
      quantityPrescribed: json['quantity_prescribed'] as int? ?? 1,
      quantityDispensed: json['quantity_dispensed'] as int? ?? 0,
      isDispensed: json['is_dispensed'] as bool? ?? false,
    );
  }
}

@immutable
class MobilePrescriptionDto {
  final String prescriptionId;
  final String prescriptionNumber;
  final String doctorName;
  final String doctorBmdcNo;
  final String doctorWorkplace;
  final String patientToken;
  final int? patientAge;
  final String patientGender;
  final String diagnosis;
  final MobilePrescriptionStatus status;
  final String pharmacistPcbNo;
  final DateTime prescriptionDate;
  final DateTime? expiryDate;
  final List<MobilePrescriptionItemDto> items;

  const MobilePrescriptionDto({
    required this.prescriptionId,
    required this.prescriptionNumber,
    required this.doctorName,
    required this.doctorBmdcNo,
    required this.doctorWorkplace,
    required this.patientToken,
    this.patientAge,
    required this.patientGender,
    required this.diagnosis,
    required this.status,
    required this.pharmacistPcbNo,
    required this.prescriptionDate,
    this.expiryDate,
    required this.items,
  });

  bool get isExpired {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return today.isAfter(exp);
  }

  bool get canDispense {
    if (isExpired) return false;
    return status == MobilePrescriptionStatus.verified ||
        status == MobilePrescriptionStatus.partiallyDispensed;
  }

  int get totalPrescribedUnits =>
      items.fold(0, (sum, it) => sum + it.quantityPrescribed);

  int get totalDispensedUnits =>
      items.fold(0, (sum, it) => sum + it.quantityDispensed);

  factory MobilePrescriptionDto.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((e) => MobilePrescriptionItemDto.fromJson(e as Map<String, dynamic>))
        .toList();

    return MobilePrescriptionDto(
      prescriptionId: json['prescription_id'] as String? ?? '',
      prescriptionNumber: json['prescription_number'] as String? ?? '',
      doctorName: json['doctor_name'] as String? ?? '',
      doctorBmdcNo: json['doctor_bmdc_no'] as String? ?? '',
      doctorWorkplace: json['doctor_workplace'] as String? ?? '',
      patientToken: json['patient_token'] as String? ?? '',
      patientAge: json['patient_age'] as int?,
      patientGender: json['patient_gender'] as String? ?? 'UNKNOWN',
      diagnosis: json['diagnosis'] as String? ?? '',
      status: MobilePrescriptionStatus.fromString(json['status'] as String?),
      pharmacistPcbNo: json['pharmacist_pcb_no'] as String? ?? '',
      prescriptionDate: json['prescription_date'] != null
          ? DateTime.parse(json['prescription_date'] as String)
          : DateTime.now(),
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      items: itemsList,
    );
  }
}
