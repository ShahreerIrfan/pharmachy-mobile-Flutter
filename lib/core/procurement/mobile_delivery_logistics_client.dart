// mobile_delivery_logistics_client.dart
// Architecture Decision: ADR-0196 (P196).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing Delivery and Logistics Tracking:
// - Tracks shipment lifecycles from depot dispatch to branch gate delivery.
// - Carrier consignment, vehicle plates, driver contacts, and live ETAs.
// - Cold-chain temperature telemetry and excursion breach detection.
// - Branch receiving confirmation, package counts, and discrepancy reports.

class MobileShipmentEvent {
  final String eventId;
  final String stage;
  final String locationName;
  final String notes;
  final String recordedBy;
  final DateTime recordedAt;

  MobileShipmentEvent({
    String? eventId,
    required this.stage,
    this.locationName = '',
    this.notes = '',
    this.recordedBy = '',
    DateTime? recordedAt,
  })  : eventId = eventId ??
            'she-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}',
        recordedAt = recordedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'stage': stage,
        'location_name': locationName,
        'notes': notes,
        'recorded_by': recordedBy,
        'recorded_at': recordedAt.toIso8601String(),
      };
}

class MobileProcurementShipment {
  final String shipmentId;
  final String trackingNumber;
  final String tenantId;
  final String branchId;
  final String purchaseOrderId;
  final String supplierId;
  final String supplierName;
  final String carrierType;
  final String carrierName;
  final String consignmentNumber;
  final String vehicleRegistrationNumber;
  final String driverName;
  final String driverPhone;
  String stage; // DISPATCHED, IN_TRANSIT, OUT_FOR_DELIVERY, DELIVERED, RECEIVING_CONFIRMED, EXCEPTION, CANCELLED
  final DateTime dispatchedAt;
  final DateTime estimatedDeliveryAt;
  DateTime? actualDeliveryAt;
  final int totalPackagesDispatched;
  int totalPackagesReceived;
  int damagedPackages;
  int missingPackages;
  String discrepancyType; // NONE, SHORTAGE, DAMAGED, OVERAGE, TEMPERATURE_BREACH, REJECTED
  String discrepancyNotes;
  final bool requiresColdChain;
  double? transitTempCelsius;
  bool coldChainBreached;
  String? confirmedBy;
  DateTime? confirmedAt;
  final String notes;
  final List<MobileShipmentEvent> events;

  MobileProcurementShipment({
    required this.shipmentId,
    required this.trackingNumber,
    required this.tenantId,
    required this.branchId,
    required this.purchaseOrderId,
    required this.supplierId,
    this.supplierName = '',
    this.carrierType = 'SUPPLIER_FLEET',
    required this.carrierName,
    this.consignmentNumber = '',
    this.vehicleRegistrationNumber = '',
    this.driverName = '',
    this.driverPhone = '',
    this.stage = 'DISPATCHED',
    DateTime? dispatchedAt,
    required this.estimatedDeliveryAt,
    this.actualDeliveryAt,
    this.totalPackagesDispatched = 1,
    this.totalPackagesReceived = 0,
    this.damagedPackages = 0,
    this.missingPackages = 0,
    this.discrepancyType = 'NONE',
    this.discrepancyNotes = '',
    this.requiresColdChain = false,
    this.transitTempCelsius,
    this.coldChainBreached = false,
    this.confirmedBy,
    this.confirmedAt,
    this.notes = '',
    List<MobileShipmentEvent>? events,
  })  : dispatchedAt = dispatchedAt ?? DateTime.now(),
        events = events ?? [];

  Map<String, dynamic> toJson() => {
        'shipment_id': shipmentId,
        'tracking_number': trackingNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'purchase_order_id': purchaseOrderId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'carrier_type': carrierType,
        'carrier_name': carrierName,
        'consignment_number': consignmentNumber,
        'vehicle_registration_number': vehicleRegistrationNumber,
        'driver_name': driverName,
        'driver_phone': driverPhone,
        'stage': stage,
        'dispatched_at': dispatchedAt.toIso8601String(),
        'estimated_delivery_at': estimatedDeliveryAt.toIso8601String(),
        'actual_delivery_at': actualDeliveryAt?.toIso8601String(),
        'total_packages_dispatched': totalPackagesDispatched,
        'total_packages_received': totalPackagesReceived,
        'damaged_packages': damagedPackages,
        'missing_packages': missingPackages,
        'discrepancy_type': discrepancyType,
        'discrepancy_notes': discrepancyNotes,
        'requires_cold_chain': requiresColdChain,
        'transit_temp_celsius': transitTempCelsius?.toStringAsFixed(2),
        'cold_chain_breached': coldChainBreached,
        'confirmed_by': confirmedBy,
        'confirmed_at': confirmedAt?.toIso8601String(),
        'notes': notes,
        'events': events.map((e) => e.toJson()).toList(),
      };
}

class MobileDeliveryLogisticsClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileProcurementShipment> shipmentStore;

  static const Set<String> _allowedProcurementRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
    'AUDITOR',
  };

  static const Set<String> _allowedReceivingRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'INVENTORY_CLERK',
    'PROCUREMENT_OFFICER',
  };

  MobileDeliveryLogisticsClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileProcurementShipment>? shipmentStore,
  }) : shipmentStore = shipmentStore ?? {};

  void _assertProcurementRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedProcurementRoles.contains(userRole.toUpperCase())) {
      throw Exception(
          'ERR_STAFF_ROLE_DENIED: Staff role $userRole cannot access logistics tracking.');
    }
  }

  void _assertReceivingRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedReceivingRoles.contains(userRole.toUpperCase())) {
      throw Exception(
          'ERR_STAFF_ROLE_DENIED: Staff role $userRole cannot confirm receiving.');
    }
  }

  MobileProcurementShipment createShipment({
    required String purchaseOrderId,
    required String supplierId,
    String supplierName = '',
    String carrierType = 'SUPPLIER_FLEET',
    required String carrierName,
    String consignmentNumber = '',
    String vehicleRegistrationNumber = '',
    String driverName = '',
    String driverPhone = '',
    required DateTime estimatedDeliveryAt,
    int totalPackagesDispatched = 1,
    bool requiresColdChain = false,
    double? transitTempCelsius,
    String notes = '',
  }) {
    _assertProcurementRole();

    if (carrierName.trim().isEmpty) {
      throw Exception('ERR_CARRIER_REQUIRED: Carrier name is required.');
    }

    final now = DateTime.now();
    if (estimatedDeliveryAt.isBefore(now.subtract(const Duration(minutes: 5)))) {
      throw Exception('ERR_INVALID_ETA: Estimated delivery time cannot be in the past.');
    }

    bool coldBreached = false;
    if (requiresColdChain && transitTempCelsius != null) {
      if (transitTempCelsius > 8.0 || transitTempCelsius < 2.0) {
        coldBreached = true;
      }
    }

    final shpId =
        'shp-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final trackingNum = 'SHP-${DateTime.now().millisecondsSinceEpoch}';

    final initialEvent = MobileShipmentEvent(
      stage: 'DISPATCHED',
      locationName: supplierName.isNotEmpty ? supplierName : 'Supplier Hub',
      notes: 'Shipment dispatched with $totalPackagesDispatched package(s). Carrier: $carrierName',
      recordedBy: userId,
      recordedAt: now,
    );

    final shipment = MobileProcurementShipment(
      shipmentId: shpId,
      trackingNumber: trackingNum,
      tenantId: tenantId,
      branchId: branchId,
      purchaseOrderId: purchaseOrderId,
      supplierId: supplierId,
      supplierName: supplierName,
      carrierType: carrierType,
      carrierName: carrierName,
      consignmentNumber: consignmentNumber,
      vehicleRegistrationNumber: vehicleRegistrationNumber,
      driverName: driverName,
      driverPhone: driverPhone,
      stage: 'DISPATCHED',
      dispatchedAt: now,
      estimatedDeliveryAt: estimatedDeliveryAt,
      totalPackagesDispatched: totalPackagesDispatched > 0 ? totalPackagesDispatched : 1,
      requiresColdChain: requiresColdChain,
      transitTempCelsius: transitTempCelsius,
      coldChainBreached: coldBreached,
      notes: notes,
      events: [initialEvent],
    );

    shipmentStore[shpId] = shipment;
    return shipment;
  }

  MobileProcurementShipment updateShipmentStage({
    required String shipmentId,
    required String newStage,
    String locationName = '',
    double? transitTempCelsius,
    String notes = '',
  }) {
    _assertProcurementRole();

    final shipment = shipmentStore[shipmentId];
    if (shipment == null) {
      throw Exception('ERR_SHIPMENT_NOT_FOUND: Shipment $shipmentId not found.');
    }

    if (shipment.stage == 'RECEIVING_CONFIRMED') {
      throw Exception(
          'ERR_SHIPMENT_ALREADY_CONFIRMED: Cannot update stage on confirmed shipment.');
    }

    final now = DateTime.now();
    shipment.stage = newStage;

    if (transitTempCelsius != null) {
      shipment.transitTempCelsius = transitTempCelsius;
      if (shipment.requiresColdChain) {
        if (transitTempCelsius > 8.0 || transitTempCelsius < 2.0) {
          shipment.coldChainBreached = true;
        }
      }
    }

    if (newStage == 'DELIVERED' && shipment.actualDeliveryAt == null) {
      shipment.actualDeliveryAt = now;
    }

    shipment.events.add(MobileShipmentEvent(
      stage: newStage,
      locationName: locationName,
      notes: notes,
      recordedBy: userId,
      recordedAt: now,
    ));

    return shipment;
  }

  MobileProcurementShipment confirmBranchReceiving({
    required String shipmentId,
    required int totalPackagesReceived,
    int damagedPackages = 0,
    int missingPackages = 0,
    double? transitTempCelsius,
    String discrepancyNotes = '',
  }) {
    _assertReceivingRole();

    final shipment = shipmentStore[shipmentId];
    if (shipment == null) {
      throw Exception('ERR_SHIPMENT_NOT_FOUND: Shipment $shipmentId not found.');
    }

    if (shipment.stage == 'RECEIVING_CONFIRMED') {
      throw Exception(
          'ERR_SHIPMENT_ALREADY_CONFIRMED: Shipment already confirmed.');
    }

    final now = DateTime.now();
    final int recv = totalPackagesReceived >= 0 ? totalPackagesReceived : 0;
    final int dmg = damagedPackages >= 0 ? damagedPackages : 0;
    int miss = missingPackages >= 0 ? missingPackages : 0;

    if ((recv + miss) < shipment.totalPackagesDispatched && miss == 0) {
      miss = shipment.totalPackagesDispatched - recv;
    }

    bool coldBreached = shipment.coldChainBreached;
    if (transitTempCelsius != null) {
      shipment.transitTempCelsius = transitTempCelsius;
      if (shipment.requiresColdChain && (transitTempCelsius > 8.0 || transitTempCelsius < 2.0)) {
        coldBreached = true;
      }
    }
    shipment.coldChainBreached = coldBreached;

    String discType = 'NONE';
    if (coldBreached) {
      discType = 'TEMPERATURE_BREACH';
    } else if (dmg > 0) {
      discType = 'DAMAGED';
    } else if (miss > 0) {
      discType = 'SHORTAGE';
    } else if (recv > shipment.totalPackagesDispatched) {
      discType = 'OVERAGE';
    }

    shipment.stage = 'RECEIVING_CONFIRMED';
    shipment.totalPackagesReceived = recv;
    shipment.damagedPackages = dmg;
    shipment.missingPackages = miss;
    shipment.discrepancyType = discType;
    shipment.discrepancyNotes = discrepancyNotes;
    shipment.confirmedBy = userId;
    shipment.confirmedAt = now;
    if (shipment.actualDeliveryAt == null) {
      shipment.actualDeliveryAt = now;
    }

    shipment.events.add(MobileShipmentEvent(
      stage: 'RECEIVING_CONFIRMED',
      locationName: 'Branch Receiving Dock',
      notes: 'Confirmed: $recv received, $dmg damaged, $miss missing. Discrepancy: $discType',
      recordedBy: userId,
      recordedAt: now,
    ));

    return shipment;
  }

  MobileProcurementShipment getShipment(String shipmentId) {
    final shipment = shipmentStore[shipmentId];
    if (shipment == null) {
      throw Exception('ERR_SHIPMENT_NOT_FOUND: Shipment $shipmentId not found.');
    }
    return shipment;
  }

  List<MobileProcurementShipment> listShipments({String? stageFilter}) {
    final list = shipmentStore.values.toList();
    if (stageFilter == null || stageFilter.isEmpty) return list;
    return list
        .where((s) => s.stage.toUpperCase() == stageFilter.toUpperCase())
        .toList();
  }
}
