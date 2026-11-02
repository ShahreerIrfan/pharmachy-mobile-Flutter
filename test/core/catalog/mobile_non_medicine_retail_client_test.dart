// test/core/catalog/mobile_non_medicine_retail_client_test.dart
// Architecture Decision: ADR-0135
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P135)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_non_medicine_retail_client.dart';

void main() {
  group('P135: MobileNonMedicineRetailClient Unit & Integration Tests', () {
    late MobileNonMedicineRetailClient client;
    const testTenant1 = 'tn-mob-banani-101';
    const testTenant2 = 'tn-mob-gulshan-202';

    setUp(() {
      client = MobileNonMedicineRetailClient();
    });

    test('P135-M1: Create valid non-medicine retail item with non-medicine invariants', () {
      final result = client.createItem(
        tenantId: testTenant1,
        name: 'OneTouch Select Plus Test Strips 50s',
        nameBn: 'ওয়ানটাচ সিলেক্ট প্লাস টেস্ট স্ট্রিপস',
        category: 'DIAGNOSTIC_DEVICES',
        brandName: 'OneTouch',
        manufacturerOrDistributor: 'LifeScan Inc.',
        barcode: '8901112223334',
        sku: 'SKU-MOB-STRIP',
        mrp: 1250.00,
        costPrice: 1050.00,
        vatPercent: 5.00,
        unitOfMeasure: 'PACK',
        requiresColdChain: false,
        storageInstructions: 'Store in dry place 5-30 C',
        userRole: 'BRANCH_MANAGER',
      );

      expect(result.status, equals(MobileNonMedicineUiStatus.success));
      expect(result.data, isNotNull);
      expect(result.data!.tenantId, equals(testTenant1));
      expect(result.data!.isMedicine, isFalse);
      expect(result.data!.isPrescriptionOnly, isFalse);
      expect(result.data!.isAntibiotic, isFalse);
      expect(result.data!.isNarcotic, isFalse);
      expect(result.data!.versionNumber, equals(1));
      expect(result.data!.immutableHash.length, equals(64));
    });

    test('P135-M2: Regulatory invariant blocks setting prescription or antibiotic flag on retail item', () {
      final result = client.createItem(
        tenantId: testTenant1,
        name: 'Sterile Surgical Gauze Bandage',
        category: 'SURGICAL_WOUND_CARE',
        mrp: 45.00,
        costPrice: 30.00,
        attemptPrescriptionFlag: true, // Regulatory violation!
        userRole: 'BRANCH_MANAGER',
      );

      expect(result.status, equals(MobileNonMedicineUiStatus.error));
      expect(result.errorCode, equals('ERR_NON_MEDICINE_REGULATORY_RESTRICTION'));
    });

    test('P135-M3: Negative or zero MRP price rejected', () {
      final result = client.createItem(
        tenantId: testTenant1,
        name: 'Cotton Swab Pack',
        category: 'PERSONAL_HYGIENE',
        mrp: -25.00, // Invalid negative price
        costPrice: 15.00,
        userRole: 'BRANCH_MANAGER',
      );

      expect(result.status, equals(MobileNonMedicineUiStatus.error));
      expect(result.errorCode, equals('ERR_INVALID_MRP'));
    });

    test('P135-M4: Cashier can search items for checkout but is denied from creating items', () {
      // Manager creates item
      final createRes = client.createItem(
        tenantId: testTenant1,
        name: 'Pampers Baby Dry Diapers Large',
        category: 'BABY_MOTHER_CARE',
        brandName: 'Pampers',
        barcode: '8907778889990',
        mrp: 1450.00,
        costPrice: 1200.00,
        vatPercent: 5.00,
        userRole: 'BRANCH_MANAGER',
      );
      expect(createRes.status, equals(MobileNonMedicineUiStatus.success));

      // Cashier searches (Permitted)
      final searchRes = client.searchItems(tenantId: testTenant1, query: 'Pampers');
      expect(searchRes.status, equals(MobileNonMedicineUiStatus.success));
      expect(searchRes.data, isNotNull);
      expect(searchRes.data!.length, equals(1));

      // Cashier attempts create (Denied)
      final cashierCreate = client.createItem(
        tenantId: testTenant1,
        name: 'Cashier Created Syringe',
        category: 'SURGICAL_WOUND_CARE',
        mrp: 12.00,
        costPrice: 8.00,
        userRole: 'CASHIER',
      );
      expect(cashierCreate.status, equals(MobileNonMedicineUiStatus.permissionDenied));
      expect(cashierCreate.errorCode, equals('ERR_STAFF_ROLE_DENIED'));
    });

    test('P135-M5: Cross-tenant mutation is blocked with ERR_CROSS_TENANT_ACCESS', () {
      final createRes = client.createItem(
        tenantId: testTenant1,
        name: 'Tenant 1 Thermometer',
        category: 'DIAGNOSTIC_DEVICES',
        mrp: 350.00,
        costPrice: 280.00,
        userRole: 'BRANCH_MANAGER',
      );
      final itemId = createRes.data!.itemId;

      // Tenant 2 attempts mutation
      final patchRes = client.updateItem(
        itemId: itemId,
        actorTenantId: testTenant2,
        userRole: 'BRANCH_MANAGER',
        newMrp: 400.00,
      );
      expect(patchRes.status, equals(MobileNonMedicineUiStatus.permissionDenied));
      expect(patchRes.errorCode, equals('ERR_CROSS_TENANT_ACCESS'));
    });

    test('P135-M6: Offline fallback serves cached retail items safely', () {
      final createRes = client.createItem(
        tenantId: testTenant1,
        name: 'Accu-Chek Instant Meter',
        category: 'DIAGNOSTIC_DEVICES',
        brandName: 'Accu-Chek',
        barcode: '8904445556667',
        mrp: 2100.00,
        costPrice: 1750.00,
        userRole: 'BRANCH_MANAGER',
      );
      expect(createRes.status, equals(MobileNonMedicineUiStatus.success));

      client.isOffline = true;
      expect(client.isOffline, isTrue);

      final searchRes = client.searchItems(tenantId: testTenant1, query: 'Accu-Chek');
      expect(searchRes.status, equals(MobileNonMedicineUiStatus.offline));
      expect(searchRes.data, isNotNull);
      expect(searchRes.data!.length, equals(1));
      expect(searchRes.data!.first.barcode, equals('8904445556667'));
    });
  });
}
