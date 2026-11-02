// test/core/catalog/mobile_barcode_identifier_client_test.dart
// Architecture Decision: ADR-0136
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P136)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_barcode_identifier_client.dart';

void main() {
  group('P136: MobileBarcodeIdentifierClient Unit & Integration Tests', () {
    late MobileBarcodeIdentifierClient client;
    const testTenant1 = 'tn-mob-banani-101';
    const testTenant2 = 'tn-mob-gulshan-202';

    setUp(() {
      client = MobileBarcodeIdentifierClient();
    });

    test('P136-M1: Register primary EAN-13 and secondary box GTIN-14 identifiers across packaging tiers', () {
      // 1. Primary retail unit blister barcode
      final resUnit = client.registerBarcode(
        tenantId: testTenant1,
        targetId: 'med-napa-500',
        targetEntityType: 'MEDICINE',
        targetName: 'Napa Extra 500mg',
        resolvedMrp: 2.50,
        barcodeValue: '8901234567890',
        identifierType: 'PRIMARY_EAN13_GTIN',
        packagingLevel: 'UNIT',
        priorityOrder: 1,
        packQuantityMultiplier: 1,
        description: 'Primary retail unit',
        userRole: 'BRANCH_MANAGER',
      );

      expect(resUnit.status, equals(MobileBarcodeUiStatus.success));
      expect(resUnit.data, isNotNull);
      expect(resUnit.data!.barcodeValue, equals('8901234567890'));
      expect(resUnit.data!.packagingLevel, equals('UNIT'));
      expect(resUnit.data!.priorityOrder, equals(1));
      expect(resUnit.data!.packQuantityMultiplier, equals(1));
      expect(resUnit.data!.immutableHash.length, equals(64));

      // 2. Secondary outer trade box GTIN-14
      final resBox = client.registerBarcode(
        tenantId: testTenant1,
        targetId: 'med-napa-500',
        targetEntityType: 'MEDICINE',
        targetName: 'Napa Extra 500mg',
        resolvedMrp: 250.00,
        barcodeValue: '18901234567897',
        identifierType: 'SECONDARY_BOX_GTIN14',
        packagingLevel: 'BOX',
        priorityOrder: 3,
        packQuantityMultiplier: 100,
        description: 'Outer box (10 strips x 10 tablets)',
        userRole: 'BRANCH_MANAGER',
      );

      expect(resBox.status, equals(MobileBarcodeUiStatus.success));
      expect(resBox.data, isNotNull);
      expect(resBox.data!.barcodeValue, equals('18901234567897'));
      expect(resBox.data!.packagingLevel, equals('BOX'));
      expect(resBox.data!.priorityOrder, equals(3));
      expect(resBox.data!.packQuantityMultiplier, equals(100));
    });

    test('P136-M2: Contextual uniqueness blocks duplicate active barcode for another product', () {
      final res1 = client.registerBarcode(
        tenantId: testTenant1,
        targetId: 'med-napa-500',
        targetEntityType: 'MEDICINE',
        targetName: 'Napa Extra 500mg',
        resolvedMrp: 2.50,
        barcodeValue: '8901112223334',
        identifierType: 'PRIMARY_EAN13_GTIN',
        packagingLevel: 'UNIT',
        priorityOrder: 1,
        packQuantityMultiplier: 1,
        userRole: 'BRANCH_MANAGER',
      );
      expect(res1.status, equals(MobileBarcodeUiStatus.success));

      // Attempt to register same barcode to Ace Plus 500mg in same tenant
      final res2 = client.registerBarcode(
        tenantId: testTenant1,
        targetId: 'med-ace-500',
        targetEntityType: 'MEDICINE',
        targetName: 'Ace Plus 500mg',
        resolvedMrp: 2.50,
        barcodeValue: '8901112223334',
        identifierType: 'PRIMARY_EAN13_GTIN',
        packagingLevel: 'UNIT',
        priorityOrder: 1,
        packQuantityMultiplier: 1,
        userRole: 'BRANCH_MANAGER',
      );
      expect(res2.status, equals(MobileBarcodeUiStatus.error));
      expect(res2.errorCode, equals('ERR_BARCODE_ALREADY_ASSIGNED'));
    });

    test('P136-M3: Scan prioritization resolves priority 1 unit barcode before secondary codes', () {
      // Register strip barcode (Priority 2)
      client.registerBarcode(
        tenantId: testTenant1,
        targetId: 'med-napa-500',
        targetEntityType: 'MEDICINE',
        targetName: 'Napa Extra 500mg',
        resolvedMrp: 25.00,
        barcodeValue: '8903334445556',
        identifierType: 'INTERNAL_STORE_BARCODE',
        packagingLevel: 'STRIP',
        priorityOrder: 2,
        packQuantityMultiplier: 10,
        userRole: 'BRANCH_MANAGER',
      );

      // Register box barcode (Priority 3)
      client.registerBarcode(
        tenantId: testTenant1,
        targetId: 'med-napa-500',
        targetEntityType: 'MEDICINE',
        targetName: 'Napa Extra 500mg',
        resolvedMrp: 250.00,
        barcodeValue: '18903334445553',
        identifierType: 'SECONDARY_BOX_GTIN14',
        packagingLevel: 'BOX',
        priorityOrder: 3,
        packQuantityMultiplier: 100,
        userRole: 'BRANCH_MANAGER',
      );

      // Scan box barcode -> resolves BOX level with multiplier 100
      final scanBox = client.resolveBarcode(tenantId: testTenant1, scanCode: '18903334445553');
      expect(scanBox.status, equals(MobileBarcodeUiStatus.success));
      expect(scanBox.data!.matched, isTrue);
      expect(scanBox.data!.resolvedPackagingLevel, equals('BOX'));
      expect(scanBox.data!.packQuantityMultiplier, equals(100));

      // Scan strip barcode -> resolves STRIP level with multiplier 10
      final scanStrip = client.resolveBarcode(tenantId: testTenant1, scanCode: '8903334445556');
      expect(scanStrip.status, equals(MobileBarcodeUiStatus.success));
      expect(scanStrip.data!.matched, isTrue);
      expect(scanStrip.data!.resolvedPackagingLevel, equals('STRIP'));
      expect(scanStrip.data!.packQuantityMultiplier, equals(10));
    });

    test('P136-M4: Cashier lookup permitted for checkout; cashier registration denied with ERR_STAFF_ROLE_DENIED', () {
      // Manager registers barcode
      final regRes = client.registerBarcode(
        tenantId: testTenant1,
        targetId: 'ret-thermometer-01',
        targetEntityType: 'NON_MEDICINE',
        targetName: 'Omron Digital Thermometer',
        resolvedMrp: 350.00,
        barcodeValue: '8905556667778',
        identifierType: 'PRIMARY_EAN13_GTIN',
        packagingLevel: 'UNIT',
        priorityOrder: 1,
        packQuantityMultiplier: 1,
        userRole: 'BRANCH_MANAGER',
      );
      expect(regRes.status, equals(MobileBarcodeUiStatus.success));

      // Cashier scans at checkout -> Permitted
      final scanRes = client.resolveBarcode(tenantId: testTenant1, scanCode: '8905556667778');
      expect(scanRes.status, equals(MobileBarcodeUiStatus.success));
      expect(scanRes.data!.matched, isTrue);
      expect(scanRes.data!.resolvedMrp, equals(350.00));

      // Cashier attempts to register a barcode -> Denied
      final cashierReg = client.registerBarcode(
        tenantId: testTenant1,
        targetId: 'ret-thermometer-02',
        targetEntityType: 'NON_MEDICINE',
        targetName: 'Digital Thermometer Gen 2',
        resolvedMrp: 380.00,
        barcodeValue: '8905556667779',
        identifierType: 'PRIMARY_EAN13_GTIN',
        packagingLevel: 'UNIT',
        priorityOrder: 1,
        packQuantityMultiplier: 1,
        userRole: 'CASHIER',
      );
      expect(cashierReg.status, equals(MobileBarcodeUiStatus.permissionDenied));
      expect(cashierReg.errorCode, equals('ERR_STAFF_ROLE_DENIED'));
    });

    test('P136-M5: Cross-tenant barcode update blocked with ERR_CROSS_TENANT_ACCESS', () {
      final regRes = client.registerBarcode(
        tenantId: testTenant1,
        targetId: 'med-sergel-20',
        targetEntityType: 'MEDICINE',
        targetName: 'Sergel 20mg Capsule',
        resolvedMrp: 7.00,
        barcodeValue: '8906667778889',
        identifierType: 'INTERNAL_STORE_BARCODE',
        packagingLevel: 'UNIT',
        priorityOrder: 1,
        packQuantityMultiplier: 1,
        userRole: 'BRANCH_MANAGER',
      );
      final identId = regRes.data!.identifierId;

      // Manager of Tenant 2 attempts priority mutation on Tenant 1's barcode
      final crossMutate = client.updatePriority(
        identifierId: identId,
        actorTenantId: testTenant2,
        userRole: 'BRANCH_MANAGER',
        newPriority: 5,
      );
      expect(crossMutate.status, equals(MobileBarcodeUiStatus.permissionDenied));
      expect(crossMutate.errorCode, equals('ERR_CROSS_TENANT_ACCESS'));

      // Manager of Tenant 2 attempts archival
      final crossArchive = client.archiveBarcode(
        identifierId: identId,
        actorTenantId: testTenant2,
        userRole: 'BRANCH_MANAGER',
        reason: 'Unauthorized',
      );
      expect(crossArchive.status, equals(MobileBarcodeUiStatus.permissionDenied));
      expect(crossArchive.errorCode, equals('ERR_CROSS_TENANT_ACCESS'));
    });

    test('P136-M6: Offline fallback serves cached barcode resolution with OFFLINE status', () {
      final regRes = client.registerBarcode(
        tenantId: testTenant1,
        targetId: 'med-fexo-120',
        targetEntityType: 'MEDICINE',
        targetName: 'Fexo 120mg Tablet',
        resolvedMrp: 8.00,
        barcodeValue: '8908889990001',
        identifierType: 'PRIMARY_EAN13_GTIN',
        packagingLevel: 'UNIT',
        priorityOrder: 1,
        packQuantityMultiplier: 1,
        userRole: 'BRANCH_MANAGER',
      );
      expect(regRes.status, equals(MobileBarcodeUiStatus.success));

      // Network goes down
      client.isOffline = true;

      final offlineScan = client.resolveBarcode(tenantId: testTenant1, scanCode: '8908889990001');
      expect(offlineScan.status, equals(MobileBarcodeUiStatus.offline));
      expect(offlineScan.data, isNotNull);
      expect(offlineScan.data!.matched, isTrue);
      expect(offlineScan.data!.identifierRecord!.targetName, equals('Fexo 120mg Tablet'));
      expect(offlineScan.data!.resolvedMrp, equals(8.00));
    });
  });
}
