// test/core/catalog/mobile_medicine_master_client_test.dart
// Unit tests for P121 Medicine Global Master mobile client.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_medicine_master_client.dart';

void main() {
  group('MobileMedicineMasterClient Tests', () {
    late MobileMedicineMasterClient client;
    late List<MobileMedicineRecord> sampleMedicines;

    setUp(() {
      client = MobileMedicineMasterClient();
      sampleMedicines = [
        const MobileMedicineRecord(
          productId: 'prod-1',
          brandName: 'Napa 500',
          genericName: 'Paracetamol',
          dosageForm: 'Tablet',
          strength: '500mg',
          manufacturer: 'Beximco',
          route: 'Oral',
          barcode: '8901234567890',
          mrpUnit: 1.20,
          curationStatus: 'APPROVED',
        ),
        const MobileMedicineRecord(
          productId: 'prod-2',
          brandName: 'Ceevit',
          genericName: 'Ascorbic Acid',
          dosageForm: 'Chewable Tablet',
          strength: '250mg',
          manufacturer: 'Square',
          route: 'Oral',
          barcode: '8901234567891',
          mrpUnit: 2.00,
          curationStatus: 'APPROVED',
        ),
        const MobileMedicineRecord(
          productId: 'prod-3',
          brandName: 'Recalled Drug',
          genericName: 'Chemical X',
          dosageForm: 'Syrup',
          strength: '10mg',
          manufacturer: 'Fake Pharma',
          route: 'Oral',
          mrpUnit: 10.00,
          curationStatus: 'RECALLED',
        ),
      ];
    });

    test('Search by exact barcode match', () {
      final res = client.searchCatalog(
        catalog: sampleMedicines,
        query: '8901234567890',
      );

      expect(res.uiStatus, MobileCatalogUiStatus.success);
      expect(res.medicines.length, 1);
      expect(res.medicines.first.brandName, 'Napa 500');
    });

    test('Search by generic name', () {
      final res = client.searchCatalog(
        catalog: sampleMedicines,
        query: 'Ascorbic Acid',
      );

      expect(res.uiStatus, MobileCatalogUiStatus.success);
      expect(res.medicines.length, 1);
      expect(res.medicines.first.brandName, 'Ceevit');
    });

    test('Non-approved products are filtered out from search', () {
      final res = client.searchCatalog(
        catalog: sampleMedicines,
        query: '',
      );

      expect(res.uiStatus, MobileCatalogUiStatus.success);
      expect(res.medicines.length, 2);
      expect(res.medicines.any((m) => m.curationStatus == 'RECALLED'), isFalse);
    });

    test('Tenant manager cannot mutate global master catalog', () {
      final res = client.attemptMutateMaster(
        callerRole: 'BRANCH_MANAGER',
        item: sampleMedicines.first,
      );

      expect(res.uiStatus, MobileCatalogUiStatus.permissionDenied);
      expect(res.errorCode, 'PLATFORM_CATALOG_OWNERSHIP_PROTECTED');
    });

    test('Platform Superadmin operator can mutate master catalog', () {
      final res = client.attemptMutateMaster(
        callerRole: 'SUPERADMIN',
        item: sampleMedicines.first,
      );

      expect(res.uiStatus, MobileCatalogUiStatus.success);
      expect(res.medicines.length, 1);
    });
  });
}
