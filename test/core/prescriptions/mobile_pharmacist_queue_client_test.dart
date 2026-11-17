/// mobile/test/core/prescriptions/mobile_pharmacist_queue_client_test.dart
/// Architecture Decision: ADR-0243 (P243).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_pharmacist_queue_client.dart';

void main() {
  group('P243: Mobile Pharmacist Review Queue Tests', () {
    test('P243-Mobile-1: Bilingual decision actions localization', () {
      expect(MobileReviewDecision.verify.getLocalized('en'), 'Approve & Verify');
      expect(MobileReviewDecision.verify.getLocalized('bn'), 'অনুমোদন ও যাচাই করুন');

      expect(MobileReviewDecision.reject.getLocalized('en'), 'Reject Prescription');
      expect(MobileReviewDecision.reject.getLocalized('bn'), 'প্রেসক্রিপশন প্রত্যাখ্যান করুন');

      expect(MobileReviewDecision.requestClarification.getLocalized('en'), 'Request Clarification');
      expect(MobileReviewDecision.requestClarification.getLocalized('bn'), 'ব্যাখ্যা বা স্পষ্টীকরণ চান');

      expect(MobileReviewDecision.resolveClarification.getLocalized('en'), 'Resolve Clarification');
      expect(MobileReviewDecision.resolveClarification.getLocalized('bn'), 'ব্যাখ্যার উত্তর লিপিবদ্ধ করুন');
    });

    test('P243-Mobile-2: Queue priority detection & Clinical audit DTO parsing', () {
      final queueJson = {
        'prescription_id': 'rx-202611-p01',
        'prescription_number': 'RX-202611-P01',
        'doctor_name': 'Dr. M. R. Khan',
        'doctor_bmdc_no': 'BMDC-67123',
        'patient_token': 'PT-ANTIBIOTIC-01',
        'status': 'PENDING',
        'items': [
          {'product_brand': 'Amoxicillin 500mg'},
          {'product_brand': 'Paracetamol 500mg'}
        ]
      };

      final queueDto = MobileQueueItemDto.fromJson(queueJson);
      expect(queueDto.prescriptionId, 'rx-202611-p01');
      expect(queueDto.hasAntibiotics, isTrue);
      expect(queueDto.isPriority, isTrue);
      expect(queueDto.itemCount, 2);

      final auditJson = {
        'audit_id': 'pva-998811',
        'prescription_id': 'rx-202611-p01',
        'action': 'REQUEST_CLARIFICATION',
        'from_status': 'PENDING',
        'to_status': 'CLARIFICATION_REQUESTED',
        'pharmacist_pcb_no': 'PCB-B99214',
        'clarification_query': 'Patient has penicillin allergy history. Confirm substitution.',
        'created_at': '2026-11-17T11:00:00Z',
      };

      final auditDto = MobileClinicalAuditDto.fromJson(auditJson);
      expect(auditDto.auditId, 'pva-998811');
      expect(auditDto.action, 'REQUEST_CLARIFICATION');
      expect(auditDto.toStatus, 'CLARIFICATION_REQUESTED');
      expect(auditDto.pharmacistPcbNo, 'PCB-B99214');
      expect(auditDto.clarificationQuery, contains('penicillin allergy'));
    });
  });
}

