/// mobile_temperature_log_client.dart
/// Architecture Decision: ADR-0211 (P211).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

import 'dart:convert';
import 'package:crypto/crypto.dart';

enum MobileSensorDeviceType {
  iotWireless('IoT Wireless / Continuous Sensor', 'আইওটি ওয়্যারলেস সেন্সর'),
  usbDataLogger('USB Temperature Data Logger', 'ইউএসবি টেম্পারেচার ডেটা লগার'),
  bluetoothBeacon('Bluetooth BLE Cold-Chain Logger', 'ব্লুটুথ কোল্ড-চেইন লগার'),
  manualDigital('Manual Calibrated Digital Thermometer', 'ম্যানুয়াল ডিজিটাল থার্মোমিটার'),
  analogHygrometer('Manual Dial Hygrometer', 'ডায়াল হাইগ্রোমিটার / থার্মোমিটার');

  final String labelEn;
  final String labelBn;

  const MobileSensorDeviceType(this.labelEn, this.labelBn);
}

enum MobileTemperatureSourceType {
  manualEntry('Manual Staff Entry', 'ম্যানুয়াল এন্ট্রি'),
  sensorImport('Automated / Sensor Data Import', 'সেন্সর ডেটা ইম্পোর্ট'),
  iotTelemetry('Live IoT Stream Telemetry', 'লাইভ আইওটি স্ট্রীম'),
  usbLoggerBatch('USB Logger File Batch Import', 'ইউএসবি লগার ফাইল ব্যাচ ইম্পোর্ট');

  final String labelEn;
  final String labelBn;

  const MobileTemperatureSourceType(this.labelEn, this.labelBn);
}

enum MobileExcursionSeverity {
  none('Normal / Safe Range', 'স্বাভাবিক ও নিরাপদ'),
  warning('Borderline Warning', 'সতর্কতামূলক বিচ্যুতি'),
  critical('Critical Excursion Out of Safe Range', 'মারাত্মক তাপমাত্রা বিচ্যুতি');

  final String labelEn;
  final String labelBn;

  const MobileExcursionSeverity(this.labelEn, this.labelBn);
}

class MobileTemperatureDevice {
  final String deviceId;
  final String branchId;
  final String storageLocationId;
  final String deviceName;
  final MobileSensorDeviceType deviceType;
  final String serialNumber;
  bool isActive;

  MobileTemperatureDevice({
    required this.deviceId,
    required this.branchId,
    required this.storageLocationId,
    required this.deviceName,
    this.deviceType = MobileSensorDeviceType.manualDigital,
    this.serialNumber = '',
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'branch_id': branchId,
    'storage_location_id': storageLocationId,
    'device_name': deviceName,
    'device_type': deviceType.name,
    'serial_number': serialNumber,
    'is_active': isActive,
  };
}

class MobileTemperatureReading {
  final String logId;
  final String branchId;
  final String storageLocationId;
  final String? deviceId;
  final MobileTemperatureSourceType sourceType;
  final DateTime recordedAt;
  final double temperatureCelsius;
  final double? humidityPercentage;
  final double minThresholdCelsius;
  final double maxThresholdCelsius;
  final bool isExcursion;
  final MobileExcursionSeverity excursionSeverity;
  final String notes;
  final String? recordedBy;
  final String auditHash;

  MobileTemperatureReading({
    required this.logId,
    required this.branchId,
    required this.storageLocationId,
    this.deviceId,
    this.sourceType = MobileTemperatureSourceType.manualEntry,
    required this.recordedAt,
    required this.temperatureCelsius,
    this.humidityPercentage,
    this.minThresholdCelsius = 2.0,
    this.maxThresholdCelsius = 8.0,
    required this.isExcursion,
    required this.excursionSeverity,
    this.notes = '',
    this.recordedBy,
    required this.auditHash,
  });

  Map<String, dynamic> toJson() => {
    'log_id': logId,
    'branch_id': branchId,
    'storage_location_id': storageLocationId,
    'device_id': deviceId,
    'source_type': sourceType.name,
    'recorded_at': recordedAt.toIso8601String(),
    'temperature_celsius': temperatureCelsius,
    'humidity_percentage': humidityPercentage,
    'min_threshold_celsius': minThresholdCelsius,
    'max_threshold_celsius': maxThresholdCelsius,
    'is_excursion': isExcursion,
    'excursion_severity': excursionSeverity.name,
    'notes': notes,
    'recorded_by': recordedBy,
    'audit_hash': auditHash,
  };
}

class MobileTemperatureLogClient {
  final Map<String, MobileTemperatureDevice> _devices = {};
  final List<MobileTemperatureReading> _readings = [];

  void _checkStaffRole(String role) {
    final allowed = ['PHARMACIST', 'BRANCH_MANAGER', 'PHARMACY_OWNER', 'OWNER', 'ADMIN', 'SUPERADMIN'];
    if (!allowed.contains(role.toUpperCase())) {
      throw StateError('ERR_STAFF_ROLE_DENIED: Role $role is not authorized to log temperature telemetry.');
    }
  }

  MobileTemperatureDevice registerDevice({
    required String branchId,
    required String storageLocationId,
    required String deviceName,
    MobileSensorDeviceType deviceType = MobileSensorDeviceType.manualDigital,
    String serialNumber = '',
    required String staffRole,
  }) {
    _checkStaffRole(staffRole);
    final id = 'dev-${DateTime.now().millisecondsSinceEpoch}';
    final dev = MobileTemperatureDevice(
      deviceId: id,
      branchId: branchId,
      storageLocationId: storageLocationId,
      deviceName: deviceName,
      deviceType: deviceType,
      serialNumber: serialNumber,
    );
    _devices[id] = dev;
    return dev;
  }

  MobileTemperatureReading recordReading({
    required String branchId,
    required String storageLocationId,
    required double temperatureCelsius,
    double? humidityPercentage,
    double minThresholdCelsius = 2.0,
    double maxThresholdCelsius = 8.0,
    String? deviceId,
    MobileTemperatureSourceType sourceType = MobileTemperatureSourceType.manualEntry,
    String notes = '',
    String? recordedBy,
    required String staffRole,
  }) {
    _checkStaffRole(staffRole);

    if (minThresholdCelsius >= maxThresholdCelsius) {
      throw ArgumentError('ERR_INVALID_THRESHOLDS: Min threshold must be strictly less than max threshold.');
    }

    final id = 'tlog-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    bool isExcursion = false;
    MobileExcursionSeverity severity = MobileExcursionSeverity.none;

    if (temperatureCelsius < minThresholdCelsius || temperatureCelsius > maxThresholdCelsius) {
      isExcursion = true;
      final diff = temperatureCelsius > maxThresholdCelsius
          ? (temperatureCelsius - maxThresholdCelsius)
          : (minThresholdCelsius - temperatureCelsius);

      if (diff >= 5.0 || temperatureCelsius >= 15.0) {
        severity = MobileExcursionSeverity.critical;
      } else {
        severity = MobileExcursionSeverity.warning;
      }
    }

    final raw = '$id|$branchId|$storageLocationId|${now.toIso8601String()}|$temperatureCelsius|$minThresholdCelsius|$maxThresholdCelsius|$isExcursion';
    final hash = sha256.convert(utf8.encode(raw)).toString();

    final reading = MobileTemperatureReading(
      logId: id,
      branchId: branchId,
      storageLocationId: storageLocationId,
      deviceId: deviceId,
      sourceType: sourceType,
      recordedAt: now,
      temperatureCelsius: temperatureCelsius,
      humidityPercentage: humidityPercentage,
      minThresholdCelsius: minThresholdCelsius,
      maxThresholdCelsius: maxThresholdCelsius,
      isExcursion: isExcursion,
      excursionSeverity: severity,
      notes: notes,
      recordedBy: recordedBy,
      auditHash: hash,
    );
    _readings.add(reading);
    return reading;
  }

  List<MobileTemperatureReading> importBatch({
    required String branchId,
    required String storageLocationId,
    String? deviceId,
    required List<double> temperatures,
    double minThreshold = 2.0,
    double maxThreshold = 8.0,
    String batchNotes = '',
    String? recordedBy,
    required String staffRole,
  }) {
    _checkStaffRole(staffRole);
    if (temperatures.isEmpty) {
      throw ArgumentError('ERR_EMPTY_BATCH: At least one temperature reading is required.');
    }

    final results = <MobileTemperatureReading>[];
    for (final temp in temperatures) {
      final r = recordReading(
        branchId: branchId,
        storageLocationId: storageLocationId,
        temperatureCelsius: temp,
        minThresholdCelsius: minThreshold,
        maxThresholdCelsius: maxThreshold,
        deviceId: deviceId,
        sourceType: MobileTemperatureSourceType.usbLoggerBatch,
        notes: batchNotes,
        recordedBy: recordedBy,
        staffRole: staffRole,
      );
      results.add(r);
    }
    return results;
  }

  List<MobileTemperatureReading> getExcursions(String storageLocationId) {
    return _readings.where((r) => r.isExcursion && r.storageLocationId == storageLocationId).toList();
  }
}

