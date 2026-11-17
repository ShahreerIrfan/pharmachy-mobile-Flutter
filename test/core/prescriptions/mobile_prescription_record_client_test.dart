/// mobile/test/core/prescriptions/mobile_prescription_record_client_test.dart
/// Architecture Decision: ADR-0241 (P241).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_prescription_record_client.dart';

void main() {
  group('P241: Mobile Prescription Record Client Tests', () {
    test('P241-Mobile-1: Bilingual status localization and state parsing', () {
      expect(MobilePrescriptionStatus.pending.getLocalized('en'), 'Pending Verification');
      expect(MobilePrescriptionStatus.pending.getLocalized('bn'), 'অনুমোদনের অপেক্ষায়');

      expect(MobilePrescriptionStatus.verified.getLocalized('en'), 'Verified by Pharmacist');
      expect(MobilePrescriptionStatus.verified.getLocalized('bn'), 'ফার্মাসিস্ট দ্বারা যাচাইকৃত');

      expect(MobilePrescriptionStatus.partiallyDispensed.getLocalized('en'), 'Partially Dispensed');
      expect(MobilePrescriptionStatus.partiallyDispensed.getLocalized('bn'), 'আংশিক প্রদানকৃত');

      expect(MobilePrescriptionStatus.expired.getLocalized('en'), 'Expired');
      expect(MobilePrescriptionStatus.expired.getLocalized('bn'), 'মেয়াদোত্তীর্ণ');

      expect(
        MobilePrescriptionStatus.fromString('PARTIALLY_DISPENSED'),
        MobilePrescriptionStatus.partiallyDispensed,
      );
    });

    test('P241-Mobile-2: JSON serialization, expiry checks, and dispensing constraints', () {
      final jsonPayload = {
        'prescription_id': 'rx-20261117-abc12345',
        'prescription_number': 'RX-20261117-ABC12345',
        'doctor_name': 'Dr. Sharmin Akter',
        'doctor_bmdc_no': 'BMDC-98765',
        'doctor_workplace': 'Square Hospital Dhaka',
        'patient_token': 'PT-998877AABB',
        'patient_age': 42,
        'patient_gender': 'FEMALE',
        'diagnosis': 'Pneumonia and Bacterial Infection',
        'status': 'VERIFIED',
        'pharmacist_pcb_no': 'PCB-443322',
        'prescription_date': '2026-11-10',
        'expiry_date': '2026-12-10',
        'items': [
          {
            'id': 101,
            'product_id': 'prod-amox-500',
            'product_brand': 'Moxacil 500mg',
            'dosage_instructions': '1+1+1 for 7 days',
            'duration_days': 7,
            'quantity_prescribed': 21,
            'quantity_dispensed': 7,
            'is_dispensed': false,
          },
          {
            'id': 102,
            'product_id': 'prod-parac-500',
            'product_brand': 'Napa 500mg',
            'dosage_instructions': '1+0+1 as needed',
            'duration_days': 5,
            'quantity_prescribed': 10,
            'quantity_dispensed': 10,
            'is_dispensed': true,
          }
        ]
      };

      final dto = MobilePrescriptionDto.fromJson(jsonPayload);

      expect(dto.prescriptionId, 'rx-20261117-abc12345');
      expect(dto.status, MobilePrescriptionStatus.verified);
      expect(dto.isExpired, isFalse);
      expect(dto.canDispense, isTrue);
      expect(dto.items.length, 2);
      expect(dto.items[0].remainingQuantity, 14);
      expect(dto.items[0].isDispensed, isFalse);
      expect(dto.items[1].remainingQuantity, 0);
      expect(dto.items[1].isDispensed, isTrue);
      expect(dto.totalPrescribedUnits, 31);
      expect(dto.totalDispensedUnits, 17);
    });
  });
}
