import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/storage/mobile_storage_conditional_client.dart';

void main() {
  group('MobileStorageConditionalClient Tests (P155)', () {
    late MobileStorageConditionalClient client;

    setUp(() {
      client = MobileStorageConditionalClient();
    });

    test('P155-MOB-01: Valid cold chain storage validation succeeds', () {
      final result = client.validateStorageConditions(
        isColdChainRequired: true,
        minTempCelsius: 2.0,
        maxTempCelsius: 8.0,
        refrigeratorPlacement: 'SHELF_MIDDLE',
        maxExcursionHours: 24,
      );

      expect(result.isValid, isTrue);
      expect(result.errorCode, isNull);
      expect(result.isColdChainRequired, isTrue);
      expect(result.temperatureDeltaCelsius, 6.0);
    });

    test('P155-MOB-02: Non-cold-chain ambient product cleanly suppresses cold chain errors', () {
      final result = client.validateStorageConditions(
        isColdChainRequired: false,
      );

      expect(result.isValid, isTrue);
      expect(result.isColdChainRequired, isFalse);
      expect(result.temperatureDeltaCelsius, 0.0);
    });

    test('P155-MOB-03: Min temp >= max temp triggers ERR_INVALID_TEMPERATURE_RANGE', () {
      final result = client.validateStorageConditions(
        isColdChainRequired: true,
        minTempCelsius: 8.0,
        maxTempCelsius: 2.0,
        refrigeratorPlacement: 'SHELF_MIDDLE',
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_INVALID_TEMPERATURE_RANGE');
    });

    test('P155-MOB-04: Refrigerator door placement triggers ERR_PROHIBITED_DOOR_PLACEMENT', () {
      final result = client.validateStorageConditions(
        isColdChainRequired: true,
        minTempCelsius: 2.0,
        maxTempCelsius: 8.0,
        refrigeratorPlacement: 'DOOR_NOT_PERMITTED',
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_PROHIBITED_DOOR_PLACEMENT');
    });

    test('P155-MOB-05: Excursion hours exceeding 72 triggers ERR_INVALID_EXCURSION_HOURS', () {
      final result = client.validateStorageConditions(
        isColdChainRequired: true,
        minTempCelsius: 2.0,
        maxTempCelsius: 8.0,
        refrigeratorPlacement: 'SHELF_MIDDLE',
        maxExcursionHours: 90,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_INVALID_EXCURSION_HOURS');
    });

    test('P155-MOB-06: Missing temperature range triggers ERR_MISSING_TEMPERATURE_RANGE', () {
      final result = client.validateStorageConditions(
        isColdChainRequired: true,
        refrigeratorPlacement: 'SHELF_MIDDLE',
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_MISSING_TEMPERATURE_RANGE');
    });

    test('P155-MOB-07: Cashier role is restricted from mutating storage configs', () {
      expect(client.canMutateStorage('STAFF_PHARMACIST'), isTrue);
      expect(client.canMutateStorage('PHARMACY_OWNER'), isTrue);
      expect(client.canMutateStorage('SUPERADMIN'), isTrue);
      expect(client.canMutateStorage('CASHIER'), isFalse);
      expect(client.canMutateStorage(null), isFalse);
    });

    test('P155-MOB-08: Localization displays correct Bengali and English terms', () {
      expect(
        client.getPlacementDisplay('SHELF_MIDDLE', locale: 'bn'),
        'মাঝের তাক (স্থির তাপমাত্রা)',
      );
      expect(
        client.getPlacementDisplay('SHELF_MIDDLE', locale: 'en'),
        'Middle Shelf (Uniform Temperature)',
      );
      expect(
        client.getActionDisplay('QUARANTINE_IMMEDIATELY', locale: 'bn'),
        'তাত্ক্ষণিক কোয়ারেন্টাইন করুন',
      );
    });

    test('P155-MOB-09: Build cold-chain payload produces complete parameters', () {
      final payload = client.buildStoragePayload(
        productId: 'prod-ins-01',
        isColdChainRequired: true,
        minTempCelsius: 2.0,
        maxTempCelsius: 8.0,
        refrigeratorPlacement: 'SHELF_MIDDLE',
        maxExcursionHours: 24,
      );

      expect(payload['product_id'], 'prod-ins-01');
      expect(payload['is_cold_chain_required'], isTrue);
      expect(payload['min_temperature_celsius'], 2.0);
      expect(payload['max_temperature_celsius'], 8.0);
      expect(payload['refrigerator_placement'], 'SHELF_MIDDLE');
    });

    test('P155-MOB-10: Build ambient payload cleanly omits cold-chain fields', () {
      final payload = client.buildStoragePayload(
        productId: 'prod-tab-01',
        isColdChainRequired: false,
        handlingAlertNotes: 'Store in dry place',
      );

      expect(payload['product_id'], 'prod-tab-01');
      expect(payload['is_cold_chain_required'], isFalse);
      expect(payload.containsKey('min_temperature_celsius'), isFalse);
      expect(payload['handling_alert_notes'], 'Store in dry place');
    });
  });
}

