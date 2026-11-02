import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_manufacturer_supplier_client.dart';

void main() {
  group('P127 Mobile Manufacturer & Supplier Catalog Tests', () {
    late MobileManufacturerSupplierClient client;

    setUp(() {
      client = MobileManufacturerSupplierClient();

      // Manufacturers
      client.registerManufacturer(const MobileManufacturerRecord(
        manufacturerId: 'mfr-square',
        name: 'Square Pharmaceuticals Ltd.',
        nameBn: 'স্কয়ার',
        code: 'SQUARE',
        dgdaLicenseNo: 'DGDA-001',
        isActive: true,
      ));
      client.registerManufacturer(const MobileManufacturerRecord(
        manufacturerId: 'mfr-sq-pharma',
        name: 'Square Pharma (Duplicate)',
        nameBn: 'স্কয়ার',
        code: 'SQ_DUP',
        dgdaLicenseNo: 'DGDA-001',
        isActive: false,
        mergedIntoId: 'mfr-square',
      ));

      // Suppliers
      client.registerSupplier(MobileSupplierRecord(
        supplierId: 'sup-t1-main',
        tenantId: 'tn-1',
        name: 'Square Dhanmondi Depot',
        contactPerson: 'Mr. Kamal',
        phone: '01711111111',
        email: 'dhanmondi@square.com',
        dlNumber: 'DL-101',
        isActive: true,
      ));
      client.registerSupplier(MobileSupplierRecord(
        supplierId: 'sup-t1-dup',
        tenantId: 'tn-1',
        name: 'Square Depot Dhanmondi (Duplicate)',
        contactPerson: 'Mr. Kamal',
        phone: '01711111111',
        email: 'dhanmondi@square.com',
        dlNumber: 'DL-101',
        isActive: true,
      ));
      client.registerSupplier(MobileSupplierRecord(
        supplierId: 'sup-t2-main',
        tenantId: 'tn-2',
        name: 'Beximco Tejgaon Depot',
        contactPerson: 'Mr. Rahim',
        phone: '01822222222',
        email: 'tejgaon@beximco.com',
        dlNumber: 'DL-202',
        isActive: true,
      ));
    });

    test('P127-M1: Active manufacturers list excludes merged duplicate entities', () {
      final list = client.listActiveManufacturers();
      expect(list.length, 1);
      expect(list[0].name, 'Square Pharmaceuticals Ltd.');
    });

    test('P127-M2: Successfully merges duplicate supplier into canonical target', () {
      final res = client.mergeSuppliers(
        tenantId: 'tn-1',
        callerRole: 'PHARMACY_OWNER',
        sourceId: 'sup-t1-dup',
        targetId: 'sup-t1-main',
      );
      expect(res.isMerged, isTrue);
      expect(res.uiStatus, MobileMergeUiStatus.success);
      expect(res.targetName, 'Square Dhanmondi Depot');

      final active = client.listActiveSuppliers('tn-1');
      expect(active.length, 1);
      expect(active[0].supplierId, 'sup-t1-main');
    });

    test('P127-M3: Self-merge is strictly prevented with ERR_CANNOT_MERGE_SELF', () {
      final res = client.mergeSuppliers(
        tenantId: 'tn-1',
        callerRole: 'PHARMACY_OWNER',
        sourceId: 'sup-t1-main',
        targetId: 'sup-t1-main',
      );
      expect(res.isMerged, isFalse);
      expect(res.errorCode, 'ERR_CANNOT_MERGE_SELF');
    });

    test('P127-M4: Cross-tenant supplier merge is strictly blocked', () {
      final res = client.mergeSuppliers(
        tenantId: 'tn-1',
        callerRole: 'PHARMACY_OWNER',
        sourceId: 'sup-t1-main',
        targetId: 'sup-t2-main',
      );
      expect(res.isMerged, isFalse);
      expect(res.uiStatus, MobileMergeUiStatus.permissionDenied);
      expect(res.errorCode, 'ERR_CROSS_TENANT_ACCESS');
    });

    test('P127-M5: Cashier role is denied supplier merge with ERR_STAFF_ROLE_DENIED', () {
      final res = client.mergeSuppliers(
        tenantId: 'tn-1',
        callerRole: 'CASHIER',
        sourceId: 'sup-t1-dup',
        targetId: 'sup-t1-main',
      );
      expect(res.isMerged, isFalse);
      expect(res.uiStatus, MobileMergeUiStatus.permissionDenied);
      expect(res.errorCode, 'ERR_STAFF_ROLE_DENIED');
    });

    test('P127-M6: Pharmacy owner blocked from manufacturer mutation with PLATFORM_CATALOG_OWNERSHIP_PROTECTED', () {
      final res = client.attemptCreateManufacturer(
        callerRole: 'PHARMACY_OWNER',
        record: const MobileManufacturerRecord(
          manufacturerId: 'mfr-test',
          name: 'Test Pharma',
          nameBn: 'টেস্ট',
          code: 'TEST',
        ),
      );
      expect(res.isMerged, isFalse);
      expect(res.uiStatus, MobileMergeUiStatus.permissionDenied);
      expect(res.errorCode, 'PLATFORM_CATALOG_OWNERSHIP_PROTECTED');
    });
  });
}
