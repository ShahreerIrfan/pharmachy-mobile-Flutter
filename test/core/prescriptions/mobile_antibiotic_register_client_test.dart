/// mobile/test/core/prescriptions/mobile_antibiotic_register_client_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_antibiotic_register_client.dart';

void main() {
  group('MobileAntibioticRegisterClient Tests', () {
    test('Bilingual status translations', () {
      expect(
          MobileAntibioticRegisterStatus.active.getLocalized('en'), equals('Active Dispense'));
      expect(
          MobileAntibioticRegisterStatus.active.getLocalized('bn'), equals('সক্রিয় সরবরাহ'));
      expect(MobileAntibioticRegisterStatus.partiallyReturned.getLocalized('bn'),
          equals('আংশিক ফেরত'));
      expect(MobileAntibioticRegisterStatus.reversed.getLocalized('bn'),
          equals('সম্পূর্ণ বাতিল / প্রত্যাহারকৃত'));
    });

    test('JSON DTO parsing of single register entry', () {
      final json = {
        'register_entry_id': 'abx-mob-001',
        'order_number': 'ORD-202611-001',
        'rx_reference_code': 'RX-202611-001',
        'brand_name': 'Moxacil 500mg',
        'generic_name': 'Amoxicillin',
        'classification_tier': 'ANTIMICROBIAL_ACCESS',
        'dispensed_base_units': 15,
        'returned_base_units': 5,
        'doctor_bmdc_no': 'BMDC-44210',
        'approving_pharmacist_pcb_no': 'PCB-8812',
        'status': 'PARTIALLY_RETURNED',
        'sha256_hash': 'sha256mock12345',
        'dispensed_at': '2026-11-17T11:00:00Z',
      };

      final dto = MobileAntibioticRegisterEntryDto.fromJson(json);
      expect(dto.registerEntryId, equals('abx-mob-001'));
      expect(dto.brandName, equals('Moxacil 500mg'));
      expect(dto.dispensedBaseUnits, equals(15));
      expect(dto.returnedBaseUnits, equals(5));
      expect(dto.netUnits, equals(10));
      expect(dto.status, equals(MobileAntibioticRegisterStatus.partiallyReturned));
      expect(dto.doctorBmdcNo, equals('BMDC-44210'));
      expect(dto.pharmacistPcbNo, equals('PCB-8812'));
    });

    test('JSON DTO parsing of DGDA compliance export', () {
      final json = {
        'tenant_id': 'ten-test-01',
        'branch_id': 'ALL',
        'total_records': 1,
        'total_dispensed_units': 20,
        'total_returned_units': 5,
        'net_active_units': 15,
        'aware_tier_breakdown': {
          'ANTIMICROBIAL_ACCESS': 1,
          'ANTIMICROBIAL_WATCH': 0,
          'ANTIMICROBIAL_RESERVE': 0,
        },
        'records': [
          {
            'register_entry_id': 'abx-mob-002',
            'product_name': 'Cef-3 200mg',
            'generic_name': 'Cefixime',
            'classification_tier': 'ANTIMICROBIAL_ACCESS',
            'dispensed_base_units': 20,
            'returned_base_units': 5,
            'status': 'ACTIVE',
          }
        ],
      };

      final exportDto = MobileDgdaLedgerExportDto.fromJson(json);
      expect(exportDto.totalRecords, equals(1));
      expect(exportDto.totalDispensedUnits, equals(20));
      expect(exportDto.netActiveUnits, equals(15));
      expect(exportDto.awareTierBreakdown['ANTIMICROBIAL_ACCESS'], equals(1));
      expect(exportDto.records.length, equals(1));
      expect(exportDto.records.first.brandName, equals('Cef-3 200mg'));
    });
  });
}

