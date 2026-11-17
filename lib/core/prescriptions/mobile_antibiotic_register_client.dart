/// mobile/lib/core/prescriptions/mobile_antibiotic_register_client.dart
/// Architecture Decision: ADR-0246 (P246).
/// Phase 13: Prescriptions, Antibiotic Register & Compliance Safety.

import 'package:flutter/foundation.dart';

enum MobileAntibioticRegisterStatus {
  active('Active Dispense', 'সক্রিয় সরবরাহ'),
  partiallyReturned('Partially Returned', 'আংশিক ফেরত'),
  reversed('Reversed / Voided', 'সম্পূর্ণ বাতিল / প্রত্যাহারকৃত');

  final String enLabel;
  final String bnLabel;

  const MobileAntibioticRegisterStatus(this.enLabel, this.bnLabel);

  String getLocalized(String lang) => lang.toLowerCase() == 'bn' ? bnLabel : enLabel;
}

@immutable
class MobileAntibioticRegisterEntryDto {
  final String registerEntryId;
  final String orderNumber;
  final String prescriptionNumber;
  final String brandName;
  final String genericName;
  final String classificationTier;
  final int dispensedBaseUnits;
  final int returnedBaseUnits;
  final String doctorBmdcNo;
  final String pharmacistPcbNo;
  final MobileAntibioticRegisterStatus status;
  final String sha256Hash;
  final String dispensedAt;

  const MobileAntibioticRegisterEntryDto({
    required this.registerEntryId,
    required this.orderNumber,
    required this.prescriptionNumber,
    required this.brandName,
    required this.genericName,
    required this.classificationTier,
    required this.dispensedBaseUnits,
    required this.returnedBaseUnits,
    required this.doctorBmdcNo,
    required this.pharmacistPcbNo,
    required this.status,
    required this.sha256Hash,
    required this.dispensedAt,
  });

  int get netUnits => (dispensedBaseUnits - returnedBaseUnits).clamp(0, dispensedBaseUnits);

  factory MobileAntibioticRegisterEntryDto.fromJson(Map<String, dynamic> json) {
    MobileAntibioticRegisterStatus st = MobileAntibioticRegisterStatus.active;
    final raw = json['status'] as String? ?? 'ACTIVE';
    if (raw == 'PARTIALLY_RETURNED') {
      st = MobileAntibioticRegisterStatus.partiallyReturned;
    } else if (raw == 'REVERSED') {
      st = MobileAntibioticRegisterStatus.reversed;
    }

    return MobileAntibioticRegisterEntryDto(
      registerEntryId: json['register_entry_id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      prescriptionNumber: json['prescription_number'] as String? ??
          json['rx_reference_code'] as String? ??
          '',
      brandName: json['product_name'] as String? ?? json['brand_name'] as String? ?? '',
      genericName: json['generic_name'] as String? ?? '',
      classificationTier: json['classification_tier'] as String? ?? 'ANTIMICROBIAL_ACCESS',
      dispensedBaseUnits: json['dispensed_base_units'] as int? ?? 0,
      returnedBaseUnits: json['returned_base_units'] as int? ?? 0,
      doctorBmdcNo: json['doctor_bmdc_no'] as String? ?? '',
      pharmacistPcbNo: json['pharmacist_pcb_no'] as String? ??
          json['approving_pharmacist_pcb_no'] as String? ??
          '',
      status: st,
      sha256Hash: json['sha256_hash'] as String? ?? '',
      dispensedAt: json['dispensed_at'] as String? ?? '',
    );
  }
}

@immutable
class MobileDgdaLedgerExportDto {
  final String tenantId;
  final String branchId;
  final int totalRecords;
  final int totalDispensedUnits;
  final int totalReturnedUnits;
  final int netActiveUnits;
  final Map<String, int> awareTierBreakdown;
  final List<MobileAntibioticRegisterEntryDto> records;

  const MobileDgdaLedgerExportDto({
    required this.tenantId,
    required this.branchId,
    required this.totalRecords,
    required this.totalDispensedUnits,
    required this.totalReturnedUnits,
    required this.netActiveUnits,
    required this.awareTierBreakdown,
    required this.records,
  });

  factory MobileDgdaLedgerExportDto.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as List<dynamic>? ?? [];
    final rawTiers = json['aware_tier_breakdown'] as Map<String, dynamic>? ?? {};

    return MobileDgdaLedgerExportDto(
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      totalRecords: json['total_records'] as int? ?? 0,
      totalDispensedUnits: json['total_dispensed_units'] as int? ?? 0,
      totalReturnedUnits: json['total_returned_units'] as int? ?? 0,
      netActiveUnits: json['net_active_units'] as int? ?? 0,
      awareTierBreakdown: rawTiers.map((k, v) => MapEntry(k, (v as num).toInt())),
      records: rawRecords
          .map((r) => MobileAntibioticRegisterEntryDto.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

