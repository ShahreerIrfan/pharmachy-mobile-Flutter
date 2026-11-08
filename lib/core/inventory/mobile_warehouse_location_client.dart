import 'dart:convert';

/// mobile_warehouse_location_client.dart
/// Architecture Decision: ADR-0202 (P202).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.
///
/// Mobile owner/manager client for Warehouse, Shelves, Bins, Cold-Chain Fridges,
/// Quarantine Segregation, and Controlled-Location Access Rules.

enum MobileWarehouseType {
  mainDispensary('Main Pharmacy Dispensary', 'মূল ডিসপেনসারি'),
  centralWarehouse('Central Storage Warehouse', 'কেন্দ্রীয় গুদাম'),
  coldRoom('Cold Chain Storage Room', 'কোল্ড চেইন রুম'),
  quarantineArea('Dedicated Quarantine Facility', 'কোয়ারেন্টাইন এলাকা'),
  hospitalStore('Hospital Inpatient Store', 'হাসপাতাল স্টোর');

  final String labelEn;
  final String labelBn;

  const MobileWarehouseType(this.labelEn, this.labelBn);
}

enum MobileStorageLocationType {
  shelf('Ambient Shelf / Rack', 'সাধারণ তাক / রেক'),
  bin('Medicine Bin / Compartment', 'মেডিসিন বিন / খুব'),
  fridge('Refrigerated Cold Chain (2°C - 8°C)', 'রেফ্রিজারেটর (২°C - ৮°C)'),
  freezer('Deep Freezer Unit (-20°C)', 'ডিপ ফ্রিজার (-২০°C)'),
  quarantineZone('Quarantine Holding Zone', 'কোয়ারেন্টাইন হোল্ডিং জোন'),
  narcoticsVault('Controlled Substance Locker', 'নিয়ন্ত্রিত নারকোটিক্স ভল্ট'),
  dispensaryCounter('Front Fast Counter', 'ফ্রন্ট কাউন্টার');

  final String labelEn;
  final String labelBn;

  const MobileStorageLocationType(this.labelEn, this.labelBn);
}

class MobileWarehouse {
  final String warehouseId;
  final String tenantId;
  final String branchId;
  final String code;
  final String name;
  final String nameBn;
  final MobileWarehouseType warehouseType;
  final bool isColdStorage;
  final bool isActive;

  const MobileWarehouse({
    required this.warehouseId,
    required this.tenantId,
    required this.branchId,
    required this.code,
    required this.name,
    required this.nameBn,
    required this.warehouseType,
    required this.isColdStorage,
    required this.isActive,
  });

  Map<String, dynamic> toJson() => {
        'warehouse_id': warehouseId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'code': code,
        'name': name,
        'name_bn': nameBn,
        'warehouse_type': warehouseType.name,
        'is_cold_storage': isColdStorage,
        'is_active': isActive,
      };
}

class MobileStorageLocation {
  final String locationId;
  final String tenantId;
  final String branchId;
  final String warehouseId;
  final String code;
  final String name;
  final String nameBn;
  final MobileStorageLocationType locationType;
  final int capacityPackLimit;
  int currentPackCount;
  final bool isControlledAccess;
  final double? minTempCelsius;
  final double? maxTempCelsius;
  final bool isActive;

  MobileStorageLocation({
    required this.locationId,
    required this.tenantId,
    required this.branchId,
    required this.warehouseId,
    required this.code,
    required this.name,
    required this.nameBn,
    required this.locationType,
    required this.capacityPackLimit,
    required this.currentPackCount,
    required this.isControlledAccess,
    this.minTempCelsius,
    this.maxTempCelsius,
    required this.isActive,
  });

  Map<String, dynamic> toJson() => {
        'location_id': locationId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'warehouse_id': warehouseId,
        'code': code,
        'name': name,
        'name_bn': nameBn,
        'location_type': locationType.name,
        'capacity_pack_limit': capacityPackLimit,
        'current_pack_count': currentPackCount,
        'is_controlled_access': isControlledAccess,
        'min_temp_celsius': minTempCelsius,
        'max_temp_celsius': maxTempCelsius,
        'is_active': isActive,
      };
}

class MobileBatchLocationAssignment {
  final String assignmentId;
  final String tenantId;
  final String branchId;
  final String batchId;
  final String batchNumber;
  final String locationId;
  final String locationCode;
  int quantity;
  final String assignedBy;
  final DateTime assignedAt;
  String notes;

  MobileBatchLocationAssignment({
    required this.assignmentId,
    required this.tenantId,
    required this.branchId,
    required this.batchId,
    required this.batchNumber,
    required this.locationId,
    required this.locationCode,
    required this.quantity,
    required this.assignedBy,
    required this.assignedAt,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'assignment_id': assignmentId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'batch_id': batchId,
        'batch_number': batchNumber,
        'location_id': locationId,
        'location_code': locationCode,
        'quantity': quantity,
        'assigned_by': assignedBy,
        'assigned_at': assignedAt.toIso8601String(),
        'notes': notes,
      };
}

class MobileWarehouseLocationClient {
  static int _counter = 0;
  static String _nextId(String prefix) => '$prefix-${DateTime.now().millisecondsSinceEpoch}-${++_counter}';

  final Map<String, MobileWarehouse> warehouses = {};
  final Map<String, MobileStorageLocation> locations = {};
  final Map<String, MobileBatchLocationAssignment> assignments = {};

  MobileWarehouse createWarehouse({
    required String tenantId,
    required String branchId,
    required String code,
    required String name,
    required String nameBn,
    required MobileWarehouseType type,
    bool isColdStorage = false,
    required String actorRole,
  }) {
    if (actorRole.toUpperCase() == 'CASHIER') {
      throw StateError('ERR_WAREHOUSE_CONFIG_DENIED: Cashiers cannot configure warehouses.');
    }
    final id = _nextId('wh');
    final wh = MobileWarehouse(
      warehouseId: id,
      tenantId: tenantId,
      branchId: branchId,
      code: code.toUpperCase(),
      name: name,
      nameBn: nameBn,
      warehouseType: type,
      isColdStorage: isColdStorage,
      isActive: true,
    );
    warehouses[wh.warehouseId] = wh;
    return wh;
  }

  MobileStorageLocation createStorageLocation({
    required String tenantId,
    required String branchId,
    required String warehouseId,
    required String code,
    required String name,
    required String nameBn,
    required MobileStorageLocationType type,
    int capacityPackLimit = 0,
    bool isControlledAccess = false,
    double? minTemp,
    double? maxTemp,
    required String actorRole,
  }) {
    if (actorRole.toUpperCase() == 'CASHIER') {
      throw StateError('ERR_WAREHOUSE_CONFIG_DENIED: Cashiers cannot configure storage locations.');
    }
    if (capacityPackLimit < 0) {
      throw ArgumentError('ERR_INVALID_CAPACITY: Capacity limit cannot be negative.');
    }
    if (minTemp != null && maxTemp != null && minTemp > maxTemp) {
      throw ArgumentError('ERR_INVALID_TEMPERATURE: Min temp cannot exceed max temp.');
    }

    final id = _nextId('loc');
    final loc = MobileStorageLocation(
      locationId: id,
      tenantId: tenantId,
      branchId: branchId,
      warehouseId: warehouseId,
      code: code.toUpperCase(),
      name: name,
      nameBn: nameBn,
      locationType: type,
      capacityPackLimit: capacityPackLimit,
      currentPackCount: 0,
      isControlledAccess: isControlledAccess,
      minTempCelsius: minTemp,
      maxTempCelsius: maxTemp,
      isActive: true,
    );
    locations[loc.locationId] = loc;
    return loc;
  }

  MobileBatchLocationAssignment assignBatchToLocation({
    required String tenantId,
    required String branchId,
    required String batchId,
    required String batchNumber,
    required bool isColdChain,
    required bool isQuarantined,
    required int totalBatchQty,
    required String locationId,
    required int quantity,
    required String actorRole,
    String? supervisorRole,
  }) {
    if (actorRole.toUpperCase() == 'CASHIER') {
      throw StateError('ERR_STAFF_ROLE_DENIED: Cashiers cannot assign stock to bins.');
    }
    if (quantity <= 0) {
      throw ArgumentError('ERR_INVALID_QUANTITY: Quantity must be positive.');
    }
    if (quantity > totalBatchQty) {
      throw ArgumentError('ERR_INSUFFICIENT_BATCH_STOCK: Quantity exceeds batch total.');
    }

    final loc = locations[locationId];
    if (loc == null || loc.tenantId != tenantId || loc.branchId != branchId) {
      throw StateError('ERR_LOCATION_NOT_FOUND: Storage location not found for branch.');
    }

    // Controlled location check
    if (loc.isControlledAccess) {
      if (loc.locationType == MobileStorageLocationType.narcoticsVault) {
        if (supervisorRole == null || !RegExp(r'BRANCH_MANAGER|PHARMACY_OWNER', caseSensitive: false).hasMatch(supervisorRole)) {
          throw StateError('ERR_DUAL_AUTH_REQUIRED: Dual manager sign-off required for narcotics vault.');
        }
      }
    }

    // Cold chain check
    if (isColdChain) {
      if (loc.locationType != MobileStorageLocationType.fridge && loc.locationType != MobileStorageLocationType.freezer) {
        throw StateError('ERR_COLD_CHAIN_TEMPERATURE_MISMATCH: Cold chain items must be placed in FRIDGE or FREEZER.');
      }
    }

    // Quarantine check
    if (isQuarantined) {
      if (loc.locationType != MobileStorageLocationType.quarantineZone) {
        throw StateError('ERR_QUARANTINE_RESTRICTION: Quarantined stock must be stored in QUARANTINE_ZONE.');
      }
    } else {
      if (loc.locationType == MobileStorageLocationType.quarantineZone) {
        throw StateError('ERR_ACTIVE_STOCK_IN_QUARANTINE: Active stock cannot be placed in quarantine zone.');
      }
    }

    // Capacity limit check
    if (loc.capacityPackLimit > 0 && (loc.currentPackCount + quantity > loc.capacityPackLimit)) {
      throw StateError('ERR_CAPACITY_EXCEEDED: Location capacity limit exceeded.');
    }

    final key = '$batchId@$locationId';
    var assign = assignments[key];
    if (assign == null) {
      assign = MobileBatchLocationAssignment(
        assignmentId: _nextId('bla'),
        tenantId: tenantId,
        branchId: branchId,
        batchId: batchId,
        batchNumber: batchNumber,
        locationId: locationId,
        locationCode: loc.code,
        quantity: quantity,
        assignedBy: actorRole,
        assignedAt: DateTime.now(),
        notes: 'Assigned via Flutter Mobile Manager',
      );
      assignments[key] = assign;
    } else {
      assign.quantity += quantity;
    }

    loc.currentPackCount += quantity;
    return assign;
  }

  void transferBatchStock({
    required String tenantId,
    required String branchId,
    required String batchId,
    required String sourceLocationId,
    required String targetLocationId,
    required int quantity,
    required String actorRole,
  }) {
    if (actorRole.toUpperCase() == 'CASHIER') {
      throw StateError('ERR_STAFF_ROLE_DENIED: Cashiers cannot transfer stock.');
    }
    final srcLoc = locations[sourceLocationId];
    final dstLoc = locations[targetLocationId];
    if (srcLoc == null || dstLoc == null) {
      throw StateError('ERR_LOCATION_NOT_FOUND');
    }

    final srcKey = '$batchId@$sourceLocationId';
    final srcAssign = assignments[srcKey];
    if (srcAssign == null || srcAssign.quantity < quantity) {
      throw ArgumentError('ERR_INSUFFICIENT_STOCK_AT_SOURCE');
    }

    if (dstLoc.capacityPackLimit > 0 && (dstLoc.currentPackCount + quantity > dstLoc.capacityPackLimit)) {
      throw StateError('ERR_CAPACITY_EXCEEDED: Target location capacity exceeded.');
    }

    srcAssign.quantity -= quantity;
    srcLoc.currentPackCount -= quantity;

    final dstKey = '$batchId@$targetLocationId';
    var dstAssign = assignments[dstKey];
    if (dstAssign == null) {
      dstAssign = MobileBatchLocationAssignment(
        assignmentId: _nextId('bla'),
        tenantId: tenantId,
        branchId: branchId,
        batchId: batchId,
        batchNumber: srcAssign.batchNumber,
        locationId: targetLocationId,
        locationCode: dstLoc.code,
        quantity: quantity,
        assignedBy: actorRole,
        assignedAt: DateTime.now(),
        notes: 'Transferred stock',
      );
      assignments[dstKey] = dstAssign;
    } else {
      dstAssign.quantity += quantity;
    }
    dstLoc.currentPackCount += quantity;
  }

  List<MobileStorageLocation> listLocationsByWarehouse(String warehouseId) {
    return locations.values.where((l) => l.warehouseId == warehouseId).toList();
  }
}
