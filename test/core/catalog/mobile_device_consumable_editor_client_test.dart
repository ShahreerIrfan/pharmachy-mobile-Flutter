import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_device_consumable_editor_client.dart';

void main() {
  group('MobileDeviceConsumableEditorClient Tests (P151)', () {
    late MobileDeviceConsumableEditorClient client;
    late Map<String, dynamic> needlePayload;
    late Map<String, dynamic> stripPayload;

    setUp(() {
      client = MobileDeviceConsumableEditorClient();

      needlePayload = {
        'product_id': 'prod-needle-31g-001',
        'device_category': 'NEEDLE_OR_SYRINGE',
        'brand_name': 'BD Ultra-Fine',
        'model_number': 'UF-31G-5MM',
        'needle_gauge': '31G',
        'needle_length_mm': 5.0,
        'is_sterile': true,
        'is_single_use': true,
        'storage_temperature_celsius_min': 2.0,
        'storage_temperature_celsius_max': 30.0,
      };

      stripPayload = {
        'product_id': 'prod-accuchek-strip-50',
        'device_category': 'DIAGNOSTIC_TEST_STRIP',
        'brand_name': 'Accu-Chek Instant',
        'meter_compatibility': 'Accu-Chek Instant Meter',
        'strip_count_per_pack': 50,
        'sample_volume_microliter': 0.6,
        'test_time_seconds': 4,
        'is_sterile': false,
        'is_single_use': true,
      };
    });

    test('1. Valid needle payload passes client validation', () {
      final res = client.validateDraftPayload(needlePayload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('2. Valid diagnostic strip payload passes client validation', () {
      final res = client.validateDraftPayload(stripPayload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('3. Rejects medicine-only fields (ERR_MEDICINE_FIELD_REJECTED)', () {
      needlePayload['dosage_form'] = 'TABLET';
      final res = client.validateDraftPayload(needlePayload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_MEDICINE_FIELD_REJECTED'));

      needlePayload.remove('dosage_form');
      needlePayload['is_antibiotic'] = true;
      final res2 = client.validateDraftPayload(needlePayload);
      expect(res2.isValid, isFalse);
      expect(res2.errorCode, equals('ERR_MEDICINE_FIELD_REJECTED'));
    });

    test('4. Rejects invalid device category', () {
      needlePayload['device_category'] = 'ORAL_LIQUID';
      final res = client.validateDraftPayload(needlePayload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_DEVICE_CATEGORY'));
    });

    test('5. Rejects empty brand name', () {
      needlePayload['brand_name'] = ' ';
      final res = client.validateDraftPayload(needlePayload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_BRAND_NAME'));
    });

    test('6. Rejects needle without specified gauge', () {
      needlePayload['needle_gauge'] = 'NA';
      final res = client.validateDraftPayload(needlePayload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_NEEDLE_GAUGE'));
    });

    test('7. Rejects needle with non-positive length', () {
      needlePayload['needle_length_mm'] = 0.0;
      final res = client.validateDraftPayload(needlePayload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_NEEDLE_LENGTH'));
    });

    test('8. Rejects diagnostic strip missing meter compatibility', () {
      stripPayload['meter_compatibility'] = '';
      final res = client.validateDraftPayload(stripPayload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_MISSING_METER_COMPATIBILITY'));
    });

    test('9. Rejects invalid strip count per pack', () {
      stripPayload['strip_count_per_pack'] = 0;
      final res = client.validateDraftPayload(stripPayload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_STRIP_COUNT'));
    });

    test('10. Rejects min storage temperature greater than max', () {
      needlePayload['storage_temperature_celsius_min'] = 35.0;
      needlePayload['storage_temperature_celsius_max'] = 20.0;
      final res = client.validateDraftPayload(needlePayload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_TEMPERATURE_RANGE'));
    });

    test('11. Serialization and deserialization preserves all fields', () {
      const record = MobileDeviceConsumableRecord(
        id: 'cfg-dev-001',
        productId: 'prod-needle-001',
        deviceCategory: 'NEEDLE_OR_SYRINGE',
        brandName: 'BD Ultra-Fine PRO',
        modelNumber: 'UF-31G-4MM',
        needleGauge: '31G',
        needleLengthMm: 4.0,
        isSterile: true,
        isSingleUse: true,
      );

      final json = record.toJson();
      expect(json['id'], equals('cfg-dev-001'));
      expect(json['needle_gauge'], equals('31G'));
      expect(json['needle_length_mm'], equals(4.0));
      expect(json['is_sterile'], isTrue);

      final deserialized = MobileDeviceConsumableRecord.fromJson(json);
      expect(deserialized.id, equals(record.id));
      expect(deserialized.needleGauge, equals(record.needleGauge));
      expect(deserialized.needleLengthMm, equals(record.needleLengthMm));
      expect(deserialized.isSterile, equals(record.isSterile));
    });
  });
}
