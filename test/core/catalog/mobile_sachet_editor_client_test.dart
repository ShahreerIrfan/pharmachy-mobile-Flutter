// test/core/catalog/mobile_sachet_editor_client_test.dart
// Unit tests for MobileSachetEditorClient (P149)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_sachet_editor_client.dart';

void main() {
  group('MobileSachetEditorClient Tests', () {
    test('validateDraftPayload accepts valid ORS sachet configuration', () {
      final payload = {
        'product_id': 'prod-001',
        'powder_category': 'ORAL_REHYDRATION_SALTS',
        'administration_route': 'ORAL',
        'grams_per_sachet': 10.25,
        'sachets_per_pack': 25,
        'total_pack_weight_grams': 256.25,
        'loose_sachet_sale_eligible': true,
        'requires_dissolution': true,
        'diluent_type': 'POTABLE_WATER',
        'diluent_volume_ml': 500.0,
      };

      final res = MobileSachetEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('validateDraftPayload rejects solid oral tablet attributes', () {
      final payload = {
        'product_id': 'prod-001',
        'powder_category': 'ORAL_REHYDRATION_SALTS',
        'administration_route': 'ORAL',
        'grams_per_sachet': 10.25,
        'sachets_per_pack': 25,
        'strips_per_box': 5, // Prohibited solid field
      };

      final res = MobileSachetEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validateDraftPayload rejects needle gauge field', () {
      final payload = {
        'product_id': 'prod-001',
        'powder_category': 'SUSPENSION_GRANULES',
        'administration_route': 'ORAL',
        'grams_per_sachet': 5.0,
        'sachets_per_pack': 10,
        'needle_gauge': '27G', // Prohibited injectable field
      };

      final res = MobileSachetEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validateDraftPayload rejects invalid powder category', () {
      final payload = {
        'product_id': 'prod-001',
        'powder_category': 'INHALER_MDI',
        'administration_route': 'ORAL',
        'grams_per_sachet': 10.0,
        'sachets_per_pack': 20,
      };

      final res = MobileSachetEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_POWDER_CATEGORY'));
    });

    test('validateDraftPayload rejects invalid administration route', () {
      final payload = {
        'product_id': 'prod-001',
        'powder_category': 'ORAL_REHYDRATION_SALTS',
        'administration_route': 'INTRAVENOUS',
        'grams_per_sachet': 10.0,
        'sachets_per_pack': 20,
      };

      final res = MobileSachetEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_ADMINISTRATION_ROUTE'));
    });

    test('validateDraftPayload rejects non-positive grams per sachet', () {
      final payload = {
        'product_id': 'prod-001',
        'powder_category': 'ORAL_REHYDRATION_SALTS',
        'administration_route': 'ORAL',
        'grams_per_sachet': 0.0,
        'sachets_per_pack': 25,
      };

      final res = MobileSachetEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_GRAMS_PER_SACHET'));
    });

    test('validateDraftPayload rejects out-of-bounds sachets per pack', () {
      final payload = {
        'product_id': 'prod-001',
        'powder_category': 'ORAL_REHYDRATION_SALTS',
        'administration_route': 'ORAL',
        'grams_per_sachet': 10.25,
        'sachets_per_pack': 0,
      };

      final res = MobileSachetEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_SACHETS_PER_PACK'));
    });

    test('validateDraftPayload rejects dimension consistency mismatch', () {
      final payload = {
        'product_id': 'prod-001',
        'powder_category': 'ORAL_REHYDRATION_SALTS',
        'administration_route': 'ORAL',
        'grams_per_sachet': 10.25,
        'sachets_per_pack': 25,
        'total_pack_weight_grams': 300.0, // 10.25 * 25 = 256.25 != 300.0
      };

      final res = MobileSachetEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_DIMENSION_CONSISTENCY_MISMATCH'));
    });

    test('validateDraftPayload enforces diluent volume when dissolution is required', () {
      final payload = {
        'product_id': 'prod-001',
        'powder_category': 'ORAL_REHYDRATION_SALTS',
        'administration_route': 'ORAL',
        'grams_per_sachet': 10.25,
        'sachets_per_pack': 25,
        'requires_dissolution': true,
        'diluent_volume_ml': null,
      };

      final res = MobileSachetEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_MISSING_DILUENT_VOLUME'));
    });

    test('MobileSachetRecord serialization and deserialization', () {
      final jsonMap = {
        'config_id': 'cfg-sachet-001',
        'product_id': 'prod-001',
        'tenant_id': 'tenant-test',
        'powder_category': 'ORAL_REHYDRATION_SALTS',
        'administration_route': 'ORAL',
        'grams_per_sachet': 10.25,
        'sachets_per_pack': 25,
        'total_pack_weight_grams': 256.25,
        'loose_sachet_sale_eligible': true,
        'requires_dissolution': true,
        'diluent_type': 'POTABLE_WATER',
        'diluent_volume_ml': 500.0,
        'reconstituted_stability_hours': 24,
        'storage_condition': 'COOL_DRY_BELOW_30',
        'patient_instructions_en': 'Dissolve in 500 mL water',
        'patient_instructions_bn': '৫০০ মিলি পানিতে গুলিয়ে নিন',
        'is_active': true,
      };

      final record = MobileSachetRecord.fromJson(jsonMap);
      expect(record.configId, equals('cfg-sachet-001'));
      expect(record.gramsPerSachet, equals(10.25));
      expect(record.sachetsPerPack, equals(25));
      expect(record.looseSachetSaleEligible, isTrue);

      final outJson = record.toJson();
      expect(outJson['powder_category'], equals('ORAL_REHYDRATION_SALTS'));
      expect(outJson['grams_per_sachet'], equals('10.25'));
      expect(outJson['sachets_per_pack'], equals(25));
    });
  });
}

