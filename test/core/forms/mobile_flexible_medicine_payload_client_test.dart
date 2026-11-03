/// mobile_flexible_medicine_payload_client_test.dart
/// Architecture Decision: ADR-0159 (P159).
/// Phase 08: Specialized Item & Multi-Tier Packaging Formulation Editors.
///
/// Unit tests for Flutter flexible medicine payload client.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/forms/mobile_flexible_medicine_payload_client.dart';

void main() {
  group('MobileFlexibleMedicinePayloadClient Tests (P159)', () {
    late MobileFlexibleMedicinePayloadClient client;

    setUp(() {
      client = MobileFlexibleMedicinePayloadClient();
    });

    test('1. Valid scenario: Typed versioned INHALER payload is accepted', () {
      final attrs = {
        'brand_name': 'Ventolin Evohaler',
        'generic_name': 'Salbutamol',
        'dar_number': '001-223-445',
        'cost_unit': 180.00,
        'mrp_unit': 225.00,
        'dose_per_actuation': '100mcg',
        'actuations_per_device': 200,
      };

      final report = client.validatePayload(
        schemaVersion: '2026.01',
        dosageFormFamily: 'INHALER',
        attributes: attrs,
      );

      expect(report.isValid, isTrue);
      expect(report.errorCount, equals(0));
    });

    test('2. Incompatible field rejected: Tablet packaging field injected into INHALER payload', () {
      final attrs = {
        'brand_name': 'Seretide',
        'generic_name': 'Salmeterol',
        'dar_number': '002-334-556',
        'cost_unit': 400.00,
        'mrp_unit': 500.00,
        'dose_per_actuation': '125mcg',
        'actuations_per_device': 120,
        // Incompatible
        'pieces_per_strip': 10,
      };

      final report = client.validatePayload(
        schemaVersion: '2026.01',
        dosageFormFamily: 'INHALER',
        attributes: attrs,
      );

      expect(report.isValid, isFalse);
      expect(report.errors.any((e) => e.field == 'pieces_per_strip' && e.errorCode == 'ERR_INCOMPATIBLE_FIELD'), isTrue);
    });

    test('3. Unknown field rejected: Arbitrary parameter rejected with ERR_UNKNOWN_FIELD', () {
      final attrs = {
        'brand_name': 'Napa 500',
        'generic_name': 'Paracetamol',
        'dar_number': '001-001-001',
        'cost_unit': 1.00,
        'mrp_unit': 1.50,
        'unknown_random_field': 'injected_val',
      };

      final report = client.validatePayload(
        schemaVersion: '2026.01',
        dosageFormFamily: 'TABLET_CAPSULE',
        attributes: attrs,
      );

      expect(report.isValid, isFalse);
      expect(report.errors.any((e) => e.field == 'unknown_random_field' && e.errorCode == 'ERR_UNKNOWN_FIELD'), isTrue);
    });

    test('4. Unsupported schema version rejected', () {
      final attrs = {
        'brand_name': 'Napa 500',
        'generic_name': 'Paracetamol',
        'dar_number': '001-001-001',
        'cost_unit': 1.00,
        'mrp_unit': 1.50,
      };

      final report = client.validatePayload(
        schemaVersion: 'v0.9-experimental',
        dosageFormFamily: 'TABLET_CAPSULE',
        attributes: attrs,
      );

      expect(report.isValid, isFalse);
      expect(report.errors.any((e) => e.errorCode == 'ERR_PAYLOAD_VERSION_UNSUPPORTED'), isTrue);
    });

    test('5. Mandatory common attributes missing detected', () {
      final attrs = {
        'brand_name': 'Azithromycin',
        // Missing generic_name, dar_number, cost_unit, mrp_unit
      };

      final report = client.validatePayload(
        schemaVersion: '2026.01',
        dosageFormFamily: 'TABLET_CAPSULE',
        attributes: attrs,
      );

      expect(report.isValid, isFalse);
      final fields = report.errors.map((e) => e.field).toList();
      expect(fields, contains('generic_name'));
      expect(fields, contains('dar_number'));
      expect(fields, contains('cost_unit'));
      expect(fields, contains('mrp_unit'));
    });

    test('6. Pricing validation detects negative cost and MRP below purchase cost', () {
      final attrs = {
        'brand_name': 'Seclo 20',
        'generic_name': 'Omeprazole',
        'dar_number': '001-222-333',
        'cost_unit': 10.00,
        'mrp_unit': 8.00, // MRP < Cost
      };

      final report = client.validatePayload(
        schemaVersion: '2026.01',
        dosageFormFamily: 'TABLET_CAPSULE',
        attributes: attrs,
      );

      expect(report.isValid, isFalse);
      expect(report.errors.any((e) => e.errorCode == 'ERR_MRP_BELOW_COST'), isTrue);
    });

    test('7. Role-Based Access Control: Cashier denied mutation', () {
      expect(client.canMutate('CASHIER'), isFalse);
      expect(client.canMutate('cashier'), isFalse);
      expect(client.canMutate(null), isFalse);
      expect(client.canMutate('STAFF_PHARMACIST'), isTrue);
      expect(client.canMutate('BRANCH_MANAGER'), isTrue);
      expect(client.canMutate('OWNER'), isTrue);
    });
  });
}

