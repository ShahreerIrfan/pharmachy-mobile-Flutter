/// mobile_temperature_log_test.dart
/// Architecture Decision: ADR-0211 (P211).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_temperature_log_client.dart';

void main() {
  group('MobileTemperatureLogClient Tests (P211)', () {
    late MobileTemperatureLogClient client;

    setUp(() {
      client = MobileTemperatureLogClient();
    });

    test('Record single manual reading in safe range generates hash and safe status', () {
      final dev = client.registerDevice(
        branchId: 'branch-dhanmondi',
        storageLocationId: 'FRIDGE-01',
        deviceName: 'Elitech RC-5 Logger',
        deviceType: MobileSensorDeviceType.usbDataLogger,
        serialNumber: 'SN-ELITECH-2026',
        staffRole: 'PHARMACIST',
      );
      expect(dev.deviceId, startsWith('dev-'));

      final reading = client.recordReading(
        branchId: 'branch-dhanmondi',
        storageLocationId: 'FRIDGE-01',
        temperatureCelsius: 4.5,
        humidityPercentage: 55.0,
        minThresholdCelsius: 2.0,
        maxThresholdCelsius: 8.0,
        deviceId: dev.deviceId,
        sourceType: MobileTemperatureSourceType.manualEntry,
        notes: 'Routine manual check',
        recordedBy: 'usr-pharm',
        staffRole: 'PHARMACIST',
      );

      expect(reading.isExcursion, isFalse);
      expect(reading.excursionSeverity, equals(MobileExcursionSeverity.none));
      expect(reading.auditHash.length, equals(64));
    });

    test('Import batch classifies warning and critical excursions', () {
      final readings = client.importBatch(
        branchId: 'branch-dhanmondi',
        storageLocationId: 'FRIDGE-01',
        temperatures: [4.0, 9.5, 18.0],
        minThreshold: 2.0,
        maxThreshold: 8.0,
        batchNotes: 'USB batch sync',
        recordedBy: 'usr-mgr',
        staffRole: 'BRANCH_MANAGER',
      );

      expect(readings.length, equals(3));
      expect(readings[0].isExcursion, isFalse);
      expect(readings[0].excursionSeverity, equals(MobileExcursionSeverity.none));

      expect(readings[1].isExcursion, isTrue);
      expect(readings[1].excursionSeverity, equals(MobileExcursionSeverity.warning));

      expect(readings[2].isExcursion, isTrue);
      expect(readings[2].excursionSeverity, equals(MobileExcursionSeverity.critical));

      final excursions = client.getExcursions('FRIDGE-01');
      expect(excursions.length, equals(2));
    });

    test('Inverted thresholds throw ArgumentError', () {
      expect(
        () => client.recordReading(
          branchId: 'branch-dhanmondi',
          storageLocationId: 'FRIDGE-01',
          temperatureCelsius: 5.0,
          minThresholdCelsius: 10.0,
          maxThresholdCelsius: 4.0,
          staffRole: 'PHARMACIST',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Cashier role throws StateError', () {
      expect(
        () => client.recordReading(
          branchId: 'branch-dhanmondi',
          storageLocationId: 'FRIDGE-01',
          temperatureCelsius: 5.0,
          staffRole: 'CASHIER',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

