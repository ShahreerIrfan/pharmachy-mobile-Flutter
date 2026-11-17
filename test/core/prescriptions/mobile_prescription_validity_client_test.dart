/// mobile/test/core/prescriptions/mobile_prescription_validity_client_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_prescription_validity_client.dart';

void main() {
  group('MobilePrescriptionValidityClient Tests', () {
    test('Valid prescription preflight passes all criteria', () {
      final now = DateTime(2026, 11, 17);
      final report = MobilePrescriptionValidityClient.evaluatePreflight(
        prescriptionId: 'rx-mob-001',
        doctorName: 'Dr. Shah Alam',
        doctorBmdcNo: 'A-22910',
        prescriptionDate: now.subtract(const Duration(days: 2)),
        expiryDate: now.add(const Duration(days: 20)),
        hasAttachment: true,
        containsAntibiotic: true,
        referenceDate: now,
      );

      expect(report.isValid, isTrue);
      expect(report.validityStatus, equals(MobileValidityStatus.valid));
      expect(report.isExpired, isFalse);
      expect(report.canDispense, isTrue);
      expect(report.errors, isEmpty);
      expect(report.validityStatus.getLocalized('bn'), equals('বৈধ ও প্রস্তুত'));
    });

    test('Expired prescription detected and flagged', () {
      final now = DateTime(2026, 11, 17);
      final report = MobilePrescriptionValidityClient.evaluatePreflight(
        prescriptionId: 'rx-mob-expired',
        doctorName: 'Dr. Shah Alam',
        doctorBmdcNo: 'A-22910',
        prescriptionDate: now.subtract(const Duration(days: 35)),
        expiryDate: now.subtract(const Duration(days: 5)),
        hasAttachment: true,
        containsAntibiotic: false,
        referenceDate: now,
      );

      expect(report.isValid, isFalse);
      expect(report.validityStatus, equals(MobileValidityStatus.expired));
      expect(report.isExpired, isTrue);
      expect(report.canDispense, isFalse);
      expect(report.validityStatus.getLocalized('bn'), equals('মেয়াদোত্তীর্ণ'));
    });

    test('Missing attachment for antibiotic flagged as missingDocuments', () {
      final now = DateTime(2026, 11, 17);
      final report = MobilePrescriptionValidityClient.evaluatePreflight(
        prescriptionId: 'rx-mob-no-att',
        doctorName: 'Dr. Nusrat Jahan',
        doctorBmdcNo: 'BMDC-99120',
        prescriptionDate: now.subtract(const Duration(days: 1)),
        expiryDate: now.add(const Duration(days: 5)),
        hasAttachment: false, // No attachment
        containsAntibiotic: true, // Requires document
        referenceDate: now,
      );

      expect(report.isValid, isFalse);
      expect(report.validityStatus, equals(MobileValidityStatus.missingDocuments));
      expect(report.requiresDocument, isTrue);
      expect(report.hasValidAttachment, isFalse);
    });

    test('Json parsing maps API response correctly', () {
      final json = {
        'prescription_id': 'rx-api-123',
        'prescription_number': 'RX-20261117-ABC',
        'validity_status': 'EXPIRED',
        'is_valid': false,
        'can_dispense': false,
        'temporal_check': {
          'status': 'FAIL',
          'is_expired': true,
        },
        'supporting_document_check': {
          'status': 'PASS',
          'has_valid_attachment': true,
          'requires_document': false,
        },
        'overall_errors': ['Prescription has expired on 2026-11-10'],
      };

      final report = MobileValidityReportDto.fromJson(json);
      expect(report.prescriptionId, equals('rx-api-123'));
      expect(report.validityStatus, equals(MobileValidityStatus.expired));
      expect(report.isExpired, isTrue);
      expect(report.isValid, isFalse);
      expect(report.errors.length, equals(1));
    });
  });
}
