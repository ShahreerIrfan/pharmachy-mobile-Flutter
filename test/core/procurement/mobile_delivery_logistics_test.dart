import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_delivery_logistics_client.dart';

void main() {
  group('MobileDeliveryLogisticsClient Tests (ADR-0196 / P196)', () {
    late Map<String, MobileProcurementShipment> shipmentStore;
    late MobileDeliveryLogisticsClient managerClient;
    late MobileDeliveryLogisticsClient cashierClient;

    setUp(() {
      shipmentStore = {};

      managerClient = MobileDeliveryLogisticsClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        shipmentStore: shipmentStore,
      );

      cashierClient = MobileDeliveryLogisticsClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        shipmentStore: shipmentStore,
      );
    });

    test('01. Creates outbound shipment with carrier metadata and ETA', () {
      final eta = DateTime.now().add(const Duration(days: 2));
      final shp = managerClient.createShipment(
        purchaseOrderId: 'po-101',
        supplierId: 'sup-sq',
        supplierName: 'Square Pharmaceuticals',
        carrierType: 'SUPPLIER_FLEET',
        carrierName: 'Square Reefer Van',
        consignmentNumber: 'SQ-CONS-001',
        vehicleRegistrationNumber: 'Dhaka Metro-U-11-2233',
        driverName: 'Rafiqul Islam',
        driverPhone: '+8801711223344',
        estimatedDeliveryAt: eta,
        totalPackagesDispatched: 30,
        requiresColdChain: true,
        transitTempCelsius: 4.5,
        notes: 'Biologics and vaccines',
      );

      expect(shp.stage, equals('DISPATCHED'));
      expect(shp.totalPackagesDispatched, equals(30));
      expect(shp.requiresColdChain, isTrue);
      expect(shp.coldChainBreached, isFalse);
      expect(shp.events.length, equals(1));
      expect(shp.events.first.stage, equals('DISPATCHED'));
    });

    test('02. Transitions shipment stages and records checkpoints', () {
      final eta = DateTime.now().add(const Duration(days: 1));
      final shp = managerClient.createShipment(
        purchaseOrderId: 'po-101',
        supplierId: 'sup-sq',
        carrierName: 'SA Paribahan',
        estimatedDeliveryAt: eta,
        totalPackagesDispatched: 10,
      );

      managerClient.updateShipmentStage(
        shipmentId: shp.shipmentId,
        newStage: 'IN_TRANSIT',
        locationName: 'Central Logistics Hub',
        notes: 'Loaded on delivery van',
      );

      managerClient.updateShipmentStage(
        shipmentId: shp.shipmentId,
        newStage: 'OUT_FOR_DELIVERY',
        locationName: 'Local Distribution Center',
        notes: 'En route to pharmacy',
      );

      final delivered = managerClient.updateShipmentStage(
        shipmentId: shp.shipmentId,
        newStage: 'DELIVERED',
        locationName: 'Branch Receiving Gate',
        notes: 'Arrived at branch',
      );

      expect(delivered.stage, equals('DELIVERED'));
      expect(delivered.actualDeliveryAt, isNotNull);
      expect(delivered.events.length, equals(4));
    });

    test('03. Detects cold-chain breach when temperature exceeds limits', () {
      final eta = DateTime.now().add(const Duration(days: 1));
      final shp = managerClient.createShipment(
        purchaseOrderId: 'po-101',
        supplierId: 'sup-sq',
        carrierName: 'Square Reefer Van',
        estimatedDeliveryAt: eta,
        totalPackagesDispatched: 15,
        requiresColdChain: true,
        transitTempCelsius: 5.0,
      );

      final updated = managerClient.updateShipmentStage(
        shipmentId: shp.shipmentId,
        newStage: 'IN_TRANSIT',
        locationName: 'Sensor Checkpoint',
        transitTempCelsius: 14.5,
      );

      expect(updated.coldChainBreached, isTrue);
      expect(updated.transitTempCelsius, equals(14.5));
    });

    test('04. Confirms branch receiving without discrepancy', () {
      final eta = DateTime.now().add(const Duration(days: 1));
      final shp = managerClient.createShipment(
        purchaseOrderId: 'po-101',
        supplierId: 'sup-sq',
        carrierName: 'Square Fleet',
        estimatedDeliveryAt: eta,
        totalPackagesDispatched: 20,
      );

      final confirmed = managerClient.confirmBranchReceiving(
        shipmentId: shp.shipmentId,
        totalPackagesReceived: 20,
        damagedPackages: 0,
        missingPackages: 0,
        discrepancyNotes: 'Intact factory seal',
      );

      expect(confirmed.stage, equals('RECEIVING_CONFIRMED'));
      expect(confirmed.totalPackagesReceived, equals(20));
      expect(confirmed.damagedPackages, equals(0));
      expect(confirmed.missingPackages, equals(0));
      expect(confirmed.discrepancyType, equals('NONE'));
      expect(confirmed.confirmedBy, equals('usr-mgr-1'));
    });

    test('05. Confirms branch receiving documenting damage and shortage', () {
      final eta = DateTime.now().add(const Duration(days: 1));
      final shp = managerClient.createShipment(
        purchaseOrderId: 'po-101',
        supplierId: 'sup-sq',
        carrierName: 'Square Fleet',
        estimatedDeliveryAt: eta,
        totalPackagesDispatched: 50,
      );

      final confirmed = managerClient.confirmBranchReceiving(
        shipmentId: shp.shipmentId,
        totalPackagesReceived: 45,
        damagedPackages: 3,
        missingPackages: 5,
        discrepancyNotes: '3 boxes crushed, 5 missing',
      );

      expect(confirmed.stage, equals('RECEIVING_CONFIRMED'));
      expect(confirmed.totalPackagesReceived, equals(45));
      expect(confirmed.damagedPackages, equals(3));
      expect(confirmed.missingPackages, equals(5));
      expect(['DAMAGED', 'SHORTAGE'], contains(confirmed.discrepancyType));
    });

    test('06. Prevents modifying already confirmed shipment', () {
      final eta = DateTime.now().add(const Duration(days: 1));
      final shp = managerClient.createShipment(
        purchaseOrderId: 'po-101',
        supplierId: 'sup-sq',
        carrierName: 'Square Fleet',
        estimatedDeliveryAt: eta,
        totalPackagesDispatched: 10,
      );
      managerClient.confirmBranchReceiving(
        shipmentId: shp.shipmentId,
        totalPackagesReceived: 10,
      );

      expect(
        () => managerClient.updateShipmentStage(
          shipmentId: shp.shipmentId,
          newStage: 'IN_TRANSIT',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'detail',
            contains('ERR_SHIPMENT_ALREADY_CONFIRMED'))),
      );
    });

    test('07. Cashier role access denied', () {
      final eta = DateTime.now().add(const Duration(days: 1));
      expect(
        () => cashierClient.createShipment(
          purchaseOrderId: 'po-1',
          supplierId: 'sup-1',
          carrierName: 'Carrier',
          estimatedDeliveryAt: eta,
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'detail',
            contains('ERR_STAFF_ROLE_DENIED'))),
      );
    });
  });
}
