import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_warehouse_location_client.dart';

void main() {
  group('MobileWarehouseLocationClient Tests (ADR-0202 / P202)', () {
    late MobileWarehouseLocationClient client;
    const tenantId = 'ten-dhanmondi-01';
    const branchId = 'br-dhaka-main';

    setUp(() {
      client = MobileWarehouseLocationClient();
    });

    test('1. Create warehouse and shelf/bin hierarchy with EN/BN translations', () {
      final wh = client.createWarehouse(
        tenantId: tenantId,
        branchId: branchId,
        code: 'WH-MAIN',
        name: 'Main Dispensary Backroom',
        nameBn: 'মূল ডিসপেনসারি গুদাম',
        type: MobileWarehouseType.mainDispensary,
        isColdStorage: true,
        actorRole: 'BRANCH_MANAGER',
      );
      expect(wh.code, equals('WH-MAIN'));
      expect(wh.nameBn, equals('মূল ডিসপেনসারি গুদাম'));

      final shelf = client.createStorageLocation(
        tenantId: tenantId,
        branchId: branchId,
        warehouseId: wh.warehouseId,
        code: 'SH-01',
        name: 'Shelf 1 (Antibiotics)',
        nameBn: 'তাক ১ (অ্যান্টিবায়োটিক)',
        type: MobileStorageLocationType.shelf,
        capacityPackLimit: 120,
        actorRole: 'BRANCH_MANAGER',
      );
      expect(shelf.code, equals('SH-01'));
      expect(shelf.nameBn, equals('তাক ১ (অ্যান্টিবায়োটিক)'));
      expect(shelf.capacityPackLimit, equals(120));

      final locations = client.listLocationsByWarehouse(wh.warehouseId);
      expect(locations.length, equals(1));
    });

    test('2. Reject negative capacity and inverted temperatures', () {
      final wh = client.createWarehouse(
        tenantId: tenantId,
        branchId: branchId,
        code: 'WH-ERR',
        name: 'Error Warehouse',
        nameBn: 'ত্রুটি গুদাম',
        type: MobileWarehouseType.centralWarehouse,
        actorRole: 'PHARMACY_OWNER',
      );

      expect(
        () => client.createStorageLocation(
          tenantId: tenantId,
          branchId: branchId,
          warehouseId: wh.warehouseId,
          code: 'NEG-CAP',
          name: 'Negative Capacity',
          nameBn: 'নেতিবাচক ক্যাপাসিটি',
          type: MobileStorageLocationType.bin,
          capacityPackLimit: -15,
          actorRole: 'BRANCH_MANAGER',
        ),
        throwsArgumentError,
      );

      expect(
        () => client.createStorageLocation(
          tenantId: tenantId,
          branchId: branchId,
          warehouseId: wh.warehouseId,
          code: 'INV-TEMP',
          name: 'Inverted Temp',
          nameBn: 'উল্টো তাপমাত্রা',
          type: MobileStorageLocationType.fridge,
          minTemp: 12.0,
          maxTemp: 4.0,
          actorRole: 'BRANCH_MANAGER',
        ),
        throwsArgumentError,
      );
    });

    test('3. Reject cold-chain placement on ambient shelf', () {
      final wh = client.createWarehouse(
        tenantId: tenantId,
        branchId: branchId,
        code: 'WH-STORE',
        name: 'General Store',
        nameBn: 'সাধারণ স্টোর',
        type: MobileWarehouseType.mainDispensary,
        actorRole: 'BRANCH_MANAGER',
      );

      final shelf = client.createStorageLocation(
        tenantId: tenantId,
        branchId: branchId,
        warehouseId: wh.warehouseId,
        code: 'SH-AMB',
        name: 'Ambient Shelf',
        nameBn: 'সাধারণ তাক',
        type: MobileStorageLocationType.shelf,
        capacityPackLimit: 80,
        actorRole: 'BRANCH_MANAGER',
      );

      final fridge = client.createStorageLocation(
        tenantId: tenantId,
        branchId: branchId,
        warehouseId: wh.warehouseId,
        code: 'FRIDGE-01',
        name: 'Vaccine Refrigerator',
        nameBn: 'টিকা ফ্রিজ',
        type: MobileStorageLocationType.fridge,
        capacityPackLimit: 40,
        minTemp: 2.0,
        maxTemp: 8.0,
        actorRole: 'BRANCH_MANAGER',
      );

      // Cold chain into shelf must fail
      expect(
        () => client.assignBatchToLocation(
          tenantId: tenantId,
          branchId: branchId,
          batchId: 'bat-ins-101',
          batchNumber: 'BAT-INS-101',
          isColdChain: true,
          isQuarantined: false,
          totalBatchQty: 50,
          locationId: shelf.locationId,
          quantity: 10,
          actorRole: 'BRANCH_MANAGER',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_COLD_CHAIN_TEMPERATURE_MISMATCH'),
        )),
      );

      // Cold chain into fridge succeeds
      final assign = client.assignBatchToLocation(
        tenantId: tenantId,
        branchId: branchId,
        batchId: 'bat-ins-101',
        batchNumber: 'BAT-INS-101',
        isColdChain: true,
        isQuarantined: false,
        totalBatchQty: 50,
        locationId: fridge.locationId,
        quantity: 20,
        actorRole: 'BRANCH_MANAGER',
      );
      expect(assign.quantity, equals(20));
      expect(fridge.currentPackCount, equals(20));
    });

    test('4. Quarantine segregation enforcement', () {
      final wh = client.createWarehouse(
        tenantId: tenantId,
        branchId: branchId,
        code: 'WH-DISP',
        name: 'Dispensary',
        nameBn: 'ডিসপেনসারি',
        type: MobileWarehouseType.mainDispensary,
        actorRole: 'BRANCH_MANAGER',
      );

      final shelf = client.createStorageLocation(
        tenantId: tenantId,
        branchId: branchId,
        warehouseId: wh.warehouseId,
        code: 'SH-COMM',
        name: 'Commercial Shelf',
        nameBn: 'বাণিজ্যিক তাক',
        type: MobileStorageLocationType.shelf,
        actorRole: 'BRANCH_MANAGER',
      );

      final quarZone = client.createStorageLocation(
        tenantId: tenantId,
        branchId: branchId,
        warehouseId: wh.warehouseId,
        code: 'QUAR-Z1',
        name: 'Quarantine Holding Bay',
        nameBn: 'কোয়ারেন্টাইন এলাকা',
        type: MobileStorageLocationType.quarantineZone,
        isControlledAccess: true,
        actorRole: 'BRANCH_MANAGER',
      );

      // Quarantined stock into commercial shelf fails
      expect(
        () => client.assignBatchToLocation(
          tenantId: tenantId,
          branchId: branchId,
          batchId: 'bat-dmg-01',
          batchNumber: 'BAT-DMG-01',
          isColdChain: false,
          isQuarantined: true,
          totalBatchQty: 30,
          locationId: shelf.locationId,
          quantity: 15,
          actorRole: 'BRANCH_MANAGER',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_QUARANTINE_RESTRICTION'),
        )),
      );

      // Quarantined stock into quarantine bay succeeds
      final assign = client.assignBatchToLocation(
        tenantId: tenantId,
        branchId: branchId,
        batchId: 'bat-dmg-01',
        batchNumber: 'BAT-DMG-01',
        isColdChain: false,
        isQuarantined: true,
        totalBatchQty: 30,
        locationId: quarZone.locationId,
        quantity: 30,
        actorRole: 'BRANCH_MANAGER',
      );
      expect(assign.quantity, equals(30));
    });

    test('5. Narcotics vault rejects Cashier and enforces dual authorization', () {
      final wh = client.createWarehouse(
        tenantId: tenantId,
        branchId: branchId,
        code: 'WH-SECURE',
        name: 'Secure Storage',
        nameBn: 'সুরক্ষিত গুদাম',
        type: MobileWarehouseType.mainDispensary,
        actorRole: 'BRANCH_MANAGER',
      );

      final vault = client.createStorageLocation(
        tenantId: tenantId,
        branchId: branchId,
        warehouseId: wh.warehouseId,
        code: 'VAULT-01',
        name: 'Schedule Narcotics Locker',
        nameBn: 'নিয়ন্ত্রিত ওষুধের লকার',
        type: MobileStorageLocationType.narcoticsVault,
        isControlledAccess: true,
        actorRole: 'BRANCH_MANAGER',
      );

      // Cashier role rejected
      expect(
        () => client.assignBatchToLocation(
          tenantId: tenantId,
          branchId: branchId,
          batchId: 'bat-mor-01',
          batchNumber: 'BAT-MOR-01',
          isColdChain: false,
          isQuarantined: false,
          totalBatchQty: 40,
          locationId: vault.locationId,
          quantity: 10,
          actorRole: 'CASHIER',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_STAFF_ROLE_DENIED'),
        )),
      );

      // Without manager supervisor rejected
      expect(
        () => client.assignBatchToLocation(
          tenantId: tenantId,
          branchId: branchId,
          batchId: 'bat-mor-01',
          batchNumber: 'BAT-MOR-01',
          isColdChain: false,
          isQuarantined: false,
          totalBatchQty: 40,
          locationId: vault.locationId,
          quantity: 10,
          actorRole: 'STAFF_PHARMACIST',
          supervisorRole: null,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_DUAL_AUTH_REQUIRED'),
        )),
      );

      // Pharmacist + Branch Manager dual authorization succeeds
      final assign = client.assignBatchToLocation(
        tenantId: tenantId,
        branchId: branchId,
        batchId: 'bat-mor-01',
        batchNumber: 'BAT-MOR-01',
        isColdChain: false,
        isQuarantined: false,
        totalBatchQty: 40,
        locationId: vault.locationId,
        quantity: 15,
        actorRole: 'STAFF_PHARMACIST',
        supervisorRole: 'BRANCH_MANAGER',
      );
      expect(assign.quantity, equals(15));
    });

    test('6. Capacity overflow prevention and location-to-location stock transfer', () {
      final wh = client.createWarehouse(
        tenantId: tenantId,
        branchId: branchId,
        code: 'WH-BIN',
        name: 'Bin Storage',
        nameBn: 'বিন সংরক্ষণাগার',
        type: MobileWarehouseType.mainDispensary,
        actorRole: 'BRANCH_MANAGER',
      );

      final binA = client.createStorageLocation(
        tenantId: tenantId,
        branchId: branchId,
        warehouseId: wh.warehouseId,
        code: 'BIN-A',
        name: 'Bin A',
        nameBn: 'বিন এ',
        type: MobileStorageLocationType.bin,
        capacityPackLimit: 25,
        actorRole: 'BRANCH_MANAGER',
      );

      final binB = client.createStorageLocation(
        tenantId: tenantId,
        branchId: branchId,
        warehouseId: wh.warehouseId,
        code: 'BIN-B',
        name: 'Bin B',
        nameBn: 'বিন বি',
        type: MobileStorageLocationType.bin,
        capacityPackLimit: 25,
        actorRole: 'BRANCH_MANAGER',
      );

      // Initial placement
      client.assignBatchToLocation(
        tenantId: tenantId,
        branchId: branchId,
        batchId: 'bat-para-01',
        batchNumber: 'BAT-PARA-01',
        isColdChain: false,
        isQuarantined: false,
        totalBatchQty: 50,
        locationId: binA.locationId,
        quantity: 20,
        actorRole: 'BRANCH_MANAGER',
      );
      expect(binA.currentPackCount, equals(20));

      // Over capacity assignment rejected (20 + 10 = 30 > 25)
      expect(
        () => client.assignBatchToLocation(
          tenantId: tenantId,
          branchId: branchId,
          batchId: 'bat-para-01',
          batchNumber: 'BAT-PARA-01',
          isColdChain: false,
          isQuarantined: false,
          totalBatchQty: 50,
          locationId: binA.locationId,
          quantity: 10,
          actorRole: 'BRANCH_MANAGER',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_CAPACITY_EXCEEDED'),
        )),
      );

      // Transfer 8 units from Bin A to Bin B
      client.transferBatchStock(
        tenantId: tenantId,
        branchId: branchId,
        batchId: 'bat-para-01',
        sourceLocationId: binA.locationId,
        targetLocationId: binB.locationId,
        quantity: 8,
        actorRole: 'BRANCH_MANAGER',
      );
      expect(binA.currentPackCount, equals(12));
      expect(binB.currentPackCount, equals(8));
    });
  });
}
