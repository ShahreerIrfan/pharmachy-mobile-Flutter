// test/core/catalog/mobile_drops_editor_client_test.dart
// Unit tests for MobileDropsEditorClient (P147)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_drops_editor_client.dart';

void main() {
  group('MobileDropsEditorClient Tests', () {
    test('validateDraftPayload accepts valid ophthalmic dropper bottle', () {
      final payload = {
        'route': 'OPHTHALMIC',
        'container_type': 'DROPPER_BOTTLE',
        'volume_ml': 5.0,
        'concentration_value': 0.5,
        'concentration_unit': 'PERCENT_W_V',
        'opened_shelf_life_days': 28,
        'storage_temp': 'ROOM_15_25',
      };

      final res = MobileDropsEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('validateDraftPayload rejects solid oral packaging attributes', () {
      final payload = {
        'route': 'OPHTHALMIC',
        'container_type': 'DROPPER_BOTTLE',
        'volume_ml': 5.0,
        'opened_shelf_life_days': 28,
        'strips_per_box': 10, // Prohibited solid field
      };

      final res = MobileDropsEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validateDraftPayload rejects needle gauge field', () {
      final payload = {
        'route': 'OTIC',
        'container_type': 'DROPPER_BOTTLE',
        'volume_ml': 10.0,
        'opened_shelf_life_days': 28,
        'needle_gauge': '27G', // Prohibited injectable field
      };

      final res = MobileDropsEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validateDraftPayload rejects invalid route (e.g. ORAL or INTRAVENOUS)', () {
      final payload = {
        'route': 'ORAL',
        'container_type': 'DROPPER_BOTTLE',
        'volume_ml': 5.0,
        'opened_shelf_life_days': 28,
      };

      final res = MobileDropsEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_DROPS_ROUTE'));
    });

    test('validateDraftPayload rejects invalid container type', () {
      final payload = {
        'route': 'NASAL',
        'container_type': 'AMPOULE',
        'volume_ml': 15.0,
        'opened_shelf_life_days': 30,
      };

      final res = MobileDropsEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_CONTAINER_TYPE'));
    });

    test('validateDraftPayload rejects volume <= 0', () {
      final payload = {
        'route': 'OPHTHALMIC',
        'container_type': 'DROPPER_BOTTLE',
        'volume_ml': 0.0,
        'opened_shelf_life_days': 28,
      };

      final res = MobileDropsEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_VOLUME'));
    });

    test('validateDraftPayload rejects out-of-bounds opened_shelf_life_days (< 1 or > 60)', () {
      final payloadLow = {
        'route': 'OPHTHALMIC',
        'container_type': 'DROPPER_BOTTLE',
        'volume_ml': 5.0,
        'opened_shelf_life_days': 0,
      };
      expect(MobileDropsEditorClient.validateDraftPayload(payloadLow).errorCode, equals('ERR_INVALID_OPENED_SHELF_LIFE'));

      final payloadHigh = {
        'route': 'OPHTHALMIC',
        'container_type': 'DROPPER_BOTTLE',
        'volume_ml': 5.0,
        'opened_shelf_life_days': 90,
      };
      expect(MobileDropsEditorClient.validateDraftPayload(payloadHigh).errorCode, equals('ERR_INVALID_OPENED_SHELF_LIFE'));
    });

    test('validateDraftPayload enforces single-dose minim 1-day discard rule', () {
      final payloadInvalidMinim = {
        'route': 'OPHTHALMIC',
        'container_type': 'SINGLE_DOSE_MINIM',
        'volume_ml': 0.5,
        'opened_shelf_life_days': 7, // Minim cannot have 7 days BUD!
      };
      final resInvalid = MobileDropsEditorClient.validateDraftPayload(payloadInvalidMinim);
      expect(resInvalid.isValid, isFalse);
      expect(resInvalid.errorCode, equals('ERR_SINGLE_DOSE_MINIM_EXPIRY'));

      final payloadValidMinim = {
        'route': 'OPHTHALMIC',
        'container_type': 'SINGLE_DOSE_MINIM',
        'volume_ml': 0.5,
        'opened_shelf_life_days': 1, // Correct!
      };
      final resValid = MobileDropsEditorClient.validateDraftPayload(payloadValidMinim);
      expect(resValid.isValid, isTrue);
    });

    test('MobileDropsRecord serialization and deserialization', () {
      final jsonMap = {
        'config_id': 'cfg-001',
        'product_id': 'prod-001',
        'tenant_id': 'tenant-test',
        'route': 'OPHTHALMIC',
        'container_type': 'DROPPER_BOTTLE',
        'volume_ml': 5.0,
        'concentration_value': 0.5,
        'concentration_unit': 'PERCENT_W_V',
        'is_preservative_free': false,
        'preservative_name': 'Benzalkonium chloride 0.01%',
        'opened_shelf_life_days': 28,
        'storage_temp': 'ROOM_15_25',
        'patient_instructions_en': 'Instill 1 drop in eye(s). Discard after 28 days.',
        'patient_instructions_bn': 'চোখে ১ ফোঁটা দিন। খোলার ২৮ দিন পর ফেলে দিন।',
        'is_active': true,
      };

      final record = MobileDropsRecord.fromJson(jsonMap);
      expect(record.configId, equals('cfg-001'));
      expect(record.volumeMl, equals(5.0));
      expect(record.openedShelfLifeDays, equals(28));
      expect(record.preservativeName, equals('Benzalkonium chloride 0.01%'));

      final outJson = record.toJson();
      expect(outJson['route'], equals('OPHTHALMIC'));
      expect(outJson['opened_shelf_life_days'], equals(28));
      expect(outJson['container_type'], equals('DROPPER_BOTTLE'));
    });
  });
}

