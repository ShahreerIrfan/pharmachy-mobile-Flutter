/// mobile/lib/core/prescriptions/mobile_pharmacist_queue_client.dart
/// Architecture Decision: ADR-0243 (P243).
/// Phase 13: Prescriptions, Antibiotic Register & Compliance Safety.

import 'package:flutter/foundation.dart';

enum MobileReviewDecision {
  verify('Approve & Verify', 'অনুমোদন ও যাচাই করুন'),
  reject('Reject Prescription', 'প্রেসক্রিপশন প্রত্যাখ্যান করুন'),
  requestClarification('Request Clarification', 'ব্যাখ্যা বা স্পষ্টীকরণ চান'),
  resolveClarification('Resolve Clarification', 'ব্যাখ্যার উত্তর লিপিবদ্ধ করুন');

  final String enLabel;
  final String bnLabel;

  const MobileReviewDecision(this.enLabel, this.bnLabel);

  String getLocalized(String lang) => lang.toLowerCase() == 'bn' ? bnLabel : enLabel;
}

@immutable
class MobileQueueItemDto {
  final String prescriptionId;
  final String prescriptionNumber;
  final String doctorName;
  final String doctorBmdcNo;
  final String patientToken;
  final String status;
  final bool hasAntibiotics;
  final int itemCount;

  const MobileQueueItemDto({
    required this.prescriptionId,
    required this.prescriptionNumber,
    required this.doctorName,
    required this.doctorBmdcNo,
    required this.patientToken,
    required this.status,
    required this.hasAntibiotics,
    required this.itemCount,
  });

  bool get isPriority => hasAntibiotics;

  factory MobileQueueItemDto.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? [];
    final bool containsAntibiotic = items.any((it) {
      if (it is Map<String, dynamic>) {
        final prod = it['product_brand'] as String? ?? '';
        return prod.toLowerCase().contains('cillin') ||
            prod.toLowerCase().contains('mycin') ||
            prod.toLowerCase().contains('floxacin');
      }
      return false;
    });

    return MobileQueueItemDto(
      prescriptionId: json['prescription_id'] as String? ?? '',
      prescriptionNumber: json['prescription_number'] as String? ?? '',
      doctorName: json['doctor_name'] as String? ?? '',
      doctorBmdcNo: json['doctor_bmdc_no'] as String? ?? '',
      patientToken: json['patient_token'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      hasAntibiotics: containsAntibiotic,
      itemCount: items.length,
    );
  }
}

@immutable
class MobileClinicalAuditDto {
  final String auditId;
  final String prescriptionId;
  final String action;
  final String fromStatus;
  final String toStatus;
  final String pharmacistPcbNo;
  final String? clinicalNotes;
  final String? clarificationQuery;
  final String? clarificationResponse;
  final DateTime createdAt;

  const MobileClinicalAuditDto({
    required this.auditId,
    required this.prescriptionId,
    required this.action,
    required this.fromStatus,
    required this.toStatus,
    required this.pharmacistPcbNo,
    this.clinicalNotes,
    this.clarificationQuery,
    this.clarificationResponse,
    required this.createdAt,
  });

  factory MobileClinicalAuditDto.fromJson(Map<String, dynamic> json) {
    return MobileClinicalAuditDto(
      auditId: json['audit_id'] as String? ?? '',
      prescriptionId: json['prescription'] as String? ?? json['prescription_id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      fromStatus: json['from_status'] as String? ?? '',
      toStatus: json['to_status'] as String? ?? '',
      pharmacistPcbNo: json['pharmacist_pcb_no'] as String? ?? '',
      clinicalNotes: json['clinical_notes'] as String?,
      clarificationQuery: json['clarification_query'] as String?,
      clarificationResponse: json['clarification_response'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

