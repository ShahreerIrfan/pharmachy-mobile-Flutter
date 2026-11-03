import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/qa/mobile_dosage_form_qa_fixture_client.dart';

void main() {
  late MobileDosageFormQaFixtureClient client;

  setUp(() {
    client = MobileDosageFormQaFixtureClient();
  });

  Map<String, dynamic> createBaseAttributes({
    required String brand,
    required String generic,
    required String dar,
    required String cost,
    required String mrp,
  }) {
    return {
      'brand_name': brand,
      'generic_name': generic,
      'dar_number': dar,
      'cost_unit': cost,
      'mrp_unit': mrp,
      'vat_percentage': '2.5',
      'is_prescription_only': false,
      'is_antibiotic': false,
      'is_narcotic': false,
      'requires_cold_chain': false,
      'storage_condition': 'ROOM_TEMPERATURE',
    };
  }

  group('MobileDosageFormQaFixtureClient - Positive Fixtures', () {
    test('1. Positive: TABLET_CAPSULE packaging fixture passes validation', () {
      final attrs = createBaseAttributes(
        brand: 'Napa Extra',
        generic: 'Paracetamol + Caffeine',
        dar: '012-345-678',
        cost: '2.10',
        mrp: '3.00',
      )..addAll({
          'pieces_per_strip': 10,
          'strips_per_pack': 10,
          'total_pieces_per_pack': 100,
          'capsule_shell_type': 'FILM_COATED_TABLET',
          'is_delayed_release': false,
        });

      final result = client.runPositiveFixture(
        fixtureId: 'POS-001-TABLET-CAPSULE',
        schemaVersion: '2026.01',
        dosageFormFamily: 'TABLET_CAPSULE',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isTrue);
      expect(result.report.errorCount, 0);
    });

    test('2. Positive: SYRUP_SUSPENSION liquid fixture passes validation', () {
      final attrs = createBaseAttributes(
        brand: 'Tofen Syrup',
        generic: 'Ketotifen',
        dar: '015-889-112',
        cost: '55.00',
        mrp: '70.00',
      )..addAll({
          'bottle_size_ml': 100,
          'is_dry_powder': false,
          'reconstituted_expiry_days': 30,
        });

      final result = client.runPositiveFixture(
        fixtureId: 'POS-002-SYRUP-LIQUID',
        schemaVersion: '2026.01',
        dosageFormFamily: 'SYRUP_SUSPENSION',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isTrue);
      expect(result.report.errorCount, 0);
    });

    test('3. Positive: INJECTION_INFUSION vial fixture passes validation', () {
      final attrs = createBaseAttributes(
        brand: 'Rocephin 1g IV',
        generic: 'Ceftriaxone',
        dar: '018-990-234',
        cost: '150.00',
        mrp: '190.00',
      )..addAll({
          'is_prescription_only': true,
          'is_antibiotic': true,
          'vial_volume_ml': 10,
          'is_lyophilized': true,
          'diluent_required': true,
        });

      final result = client.runPositiveFixture(
        fixtureId: 'POS-004-INJECTION-VIAL',
        schemaVersion: '2026.01',
        dosageFormFamily: 'INJECTION_INFUSION',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isTrue);
      expect(result.report.errorCount, 0);
    });

    test('4. Positive: INHALER respiratory fixture passes validation', () {
      final attrs = createBaseAttributes(
        brand: 'Ventolin Evohaler',
        generic: 'Salbutamol',
        dar: '033-112-998',
        cost: '180.00',
        mrp: '225.00',
      )..addAll({
          'dose_per_actuation': '100mcg',
          'actuations_per_device': 200,
          'canister_type': 'ALUMINIUM_MDI',
        });

      final result = client.runPositiveFixture(
        fixtureId: 'POS-006-INHALER-RESPIRATORY',
        schemaVersion: '2026.01',
        dosageFormFamily: 'INHALER',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isTrue);
      expect(result.report.errorCount, 0);
    });

    test('5. Positive: TOPICAL_CREAM dermatological fixture passes validation', () {
      final attrs = createBaseAttributes(
        brand: 'Dermovate Cream',
        generic: 'Clobetasol Propionate',
        dar: '044-556-778',
        cost: '85.00',
        mrp: '110.00',
      )..addAll({
          'tube_size_grams': 20.0,
          'application_site': 'SKIN_LESIONS',
          'vehicle_base': 'CREAM_WATER_WASHABLE',
        });

      final result = client.runPositiveFixture(
        fixtureId: 'POS-007-TOPICAL-DERMATOLOGICAL',
        schemaVersion: '2026.01',
        dosageFormFamily: 'TOPICAL_CREAM',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isTrue);
      expect(result.report.errorCount, 0);
    });

    test('6. Positive: DROPS ophthalmic fixture passes validation', () {
      final attrs = createBaseAttributes(
        brand: 'Tobrex Ophthalmic Solution',
        generic: 'Tobramycin',
        dar: '055-667-889',
        cost: '120.00',
        mrp: '150.00',
      )..addAll({
          'volume_ml': 5.0,
          'drop_category': 'EYE_DROPS',
          'is_preservative_free': false,
        });

      final result = client.runPositiveFixture(
        fixtureId: 'POS-008-DROPS-OPHTHALMIC',
        schemaVersion: '2026.01',
        dosageFormFamily: 'DROPS',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isTrue);
      expect(result.report.errorCount, 0);
    });

    test('7. Positive: SACHET_POWDER oral rehydration fixture passes validation', () {
      final attrs = createBaseAttributes(
        brand: 'Oral Rehydration Salts (ORS)',
        generic: 'Electrolyte Formula',
        dar: '066-778-990',
        cost: '5.00',
        mrp: '6.50',
      )..addAll({
          'grams_per_sachet': 10.2,
          'sachets_per_pack': 25,
          'reconstitution_guidance': 'Dissolve in 500ml fresh drinking water',
        });

      final result = client.runPositiveFixture(
        fixtureId: 'POS-009-SACHET-POWDER',
        schemaVersion: '2026.01',
        dosageFormFamily: 'SACHET_POWDER',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isTrue);
      expect(result.report.errorCount, 0);
    });

    test('8. Positive: SUPPOSITORY fixture passes validation', () {
      final attrs = createBaseAttributes(
        brand: 'Napa 125 Suppository',
        generic: 'Paracetamol',
        dar: '077-889-001',
        cost: '8.00',
        mrp: '10.00',
      )..addAll({
          'piece_count': 5,
          'administration_route': 'RECTAL',
          'suppository_base_type': 'WITEPSOL',
        });

      final result = client.runPositiveFixture(
        fixtureId: 'POS-010-SUPPOSITORY-PESSARY',
        schemaVersion: '2026.01',
        dosageFormFamily: 'SUPPOSITORY',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isTrue);
      expect(result.report.errorCount, 0);
    });

    test('9. Positive: DEVICE_CONSUMABLE fixture passes validation', () {
      final attrs = createBaseAttributes(
        brand: 'Dispovan 5ml Syringe',
        generic: 'Medical Disposable Syringe',
        dar: '088-990-112',
        cost: '6.00',
        mrp: '8.00',
      )..addAll({
          'device_type': 'DISPOSABLE_SYRINGE_5ML',
          'is_sterile': true,
          'gauge_size': '22G_X_1_25',
        });

      final result = client.runPositiveFixture(
        fixtureId: 'POS-011-DEVICE-CONSUMABLE',
        schemaVersion: '2026.01',
        dosageFormFamily: 'DEVICE_CONSUMABLE',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isTrue);
      expect(result.report.errorCount, 0);
    });
  });

  group('MobileDosageFormQaFixtureClient - Negative Fixtures & Rejections', () {
    test('10. Negative: Negative cost is rejected with ERR_NEGATIVE_COST', () {
      final attrs = createBaseAttributes(
        brand: 'Faulty Tablet',
        generic: 'Sample',
        dar: '999-001-001',
        cost: '-10.00',
        mrp: '15.00',
      )..addAll({
          'pieces_per_strip': 10,
          'strips_per_pack': 10,
          'total_pieces_per_pack': 100,
        });

      final result = client.runNegativeFixture(
        fixtureId: 'NEG-001-NEGATIVE-COST',
        expectedErrorCode: 'ERR_NEGATIVE_COST',
        schemaVersion: '2026.01',
        dosageFormFamily: 'TABLET_CAPSULE',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isFalse);
    });

    test('11. Negative: MRP below cost is rejected with ERR_MRP_BELOW_COST', () {
      final attrs = createBaseAttributes(
        brand: 'Loss Leader',
        generic: 'Sample',
        dar: '999-003-003',
        cost: '100.00',
        mrp: '80.00',
      )..addAll({
          'pieces_per_strip': 10,
          'strips_per_pack': 10,
          'total_pieces_per_pack': 100,
        });

      final result = client.runNegativeFixture(
        fixtureId: 'NEG-003-MRP-BELOW-COST',
        expectedErrorCode: 'ERR_MRP_BELOW_COST',
        schemaVersion: '2026.01',
        dosageFormFamily: 'TABLET_CAPSULE',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isFalse);
    });

    test('12. Negative: Temperature range inversion is rejected with ERR_INVALID_TEMPERATURE_RANGE', () {
      final attrs = createBaseAttributes(
        brand: 'Cold Inverted',
        generic: 'Sample',
        dar: '999-005-005',
        cost: '100.00',
        mrp: '120.00',
      )..addAll({
          'pieces_per_strip': 10,
          'strips_per_pack': 10,
          'total_pieces_per_pack': 100,
          'storage_temperature_celsius_min': 25.0,
          'storage_temperature_celsius_max': 15.0,
        });

      final result = client.runNegativeFixture(
        fixtureId: 'NEG-005-TEMP-INVERSION',
        expectedErrorCode: 'ERR_INVALID_TEMPERATURE_RANGE',
        schemaVersion: '2026.01',
        dosageFormFamily: 'TABLET_CAPSULE',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isFalse);
    });

    test('13. Negative: Incompatible form parameter is rejected with ERR_INCOMPATIBLE_FIELD', () {
      final attrs = createBaseAttributes(
        brand: 'Mismatched Inhaler',
        generic: 'Salbutamol',
        dar: '999-006-006',
        cost: '180.00',
        mrp: '225.00',
      )..addAll({
          'dose_per_actuation': '100mcg',
          'actuations_per_device': 200,
          'pieces_per_strip': 10, // Incompatible
        });

      final result = client.runNegativeFixture(
        fixtureId: 'NEG-006-INCOMPATIBLE-FIELD',
        expectedErrorCode: 'ERR_INCOMPATIBLE_FIELD',
        schemaVersion: '2026.01',
        dosageFormFamily: 'INHALER',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isFalse);
    });

    test('14. Negative: Unknown schema field is rejected with ERR_UNKNOWN_FIELD', () {
      final attrs = createBaseAttributes(
        brand: 'Random Drug',
        generic: 'Sample',
        dar: '999-007-007',
        cost: '50.00',
        mrp: '65.00',
      )..addAll({
          'pieces_per_strip': 10,
          'strips_per_pack': 10,
          'total_pieces_per_pack': 100,
          'hologram_serial_uuid': 'HOLO-999-123', // Unknown field
        });

      final result = client.runNegativeFixture(
        fixtureId: 'NEG-007-UNKNOWN-FIELD',
        expectedErrorCode: 'ERR_UNKNOWN_FIELD',
        schemaVersion: '2026.01',
        dosageFormFamily: 'TABLET_CAPSULE',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isFalse);
    });

    test('15. Negative: Unsupported schema version is rejected with ERR_PAYLOAD_VERSION_UNSUPPORTED', () {
      final attrs = createBaseAttributes(
        brand: 'Legacy Schema',
        generic: 'Sample',
        dar: '999-008-008',
        cost: '50.00',
        mrp: '65.00',
      );

      final result = client.runNegativeFixture(
        fixtureId: 'NEG-008-UNSUPPORTED-VERSION',
        expectedErrorCode: 'ERR_PAYLOAD_VERSION_UNSUPPORTED',
        schemaVersion: '1999.01',
        dosageFormFamily: 'TABLET_CAPSULE',
        attributes: attrs,
      );

      expect(result.passed, isTrue);
      expect(result.report.isValid, isFalse);
    });

    test('16. Authorization: Cashier blocked from seeding catalog', () {
      expect(client.canSeedCatalog('OWNER'), isTrue);
      expect(client.canSeedCatalog('MANAGER'), isTrue);
      expect(client.canSeedCatalog('PHARMACIST'), isTrue);
      expect(client.canSeedCatalog('CASHIER'), isFalse);
      expect(client.canSeedCatalog(null), isFalse);
      expect(client.canSeedCatalog(''), isFalse);
    });
  });
}
