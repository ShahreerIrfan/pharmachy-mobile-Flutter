// mobile_supplier_permissions_client_test.dart
// Architecture Decision: ADR-0271 (P271).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_supplier_permissions_client.dart';

void main() {
  group('MobileSupplierPermissionsClient Tests (P271)', () {
    const tenantId = 'ten-p271-test';

    test('Cashier is denied view and manage access', () {
      final client = MobileSupplierPermissionsClient(
        tenantId: tenantId,
        userRole: 'CASHIER',
      );

      expect(client.canView, isFalse);
      expect(client.canManage, isFalse);
      expect(client.canAdmin, isFalse);

      expect(
        () => client.listSuppliers(),
        throwsA(isA<SupplierPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          'ERR_STAFF_ROLE_DENIED',
        )),
      );

      expect(
        () => client.createSupplier(name: 'Unauthorized Depot'),
        throwsA(isA<SupplierPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          'ERR_STAFF_ROLE_DENIED',
        )),
      );
    });

    test('Staff Pharmacist can view but cannot manage or merge', () {
      final client = MobileSupplierPermissionsClient(
        tenantId: tenantId,
        userRole: 'STAFF_PHARMACIST',
      );

      expect(client.canView, isTrue);
      expect(client.canManage, isFalse);
      expect(client.canAdmin, isFalse);

      final list = client.listSuppliers();
      expect(list, isEmpty);

      expect(
        () => client.createSupplier(name: 'Pharma Depot'),
        throwsA(isA<SupplierPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          'ERR_STAFF_ROLE_DENIED',
        )),
      );

      expect(
        () => client.mergeSuppliers(sourceId: 'sup-1', targetId: 'sup-2'),
        throwsA(isA<SupplierPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          'ERR_STAFF_ROLE_DENIED',
        )),
      );
    });

    test('Pharmacy Owner can create, view, and merge duplicate suppliers', () {
      final client = MobileSupplierPermissionsClient(
        tenantId: tenantId,
        userRole: 'PHARMACY_OWNER',
      );

      expect(client.canView, isTrue);
      expect(client.canManage, isTrue);
      expect(client.canAdmin, isTrue);

      final supTarget = client.createSupplier(
        name: 'Square Pharmaceuticals Ltd.',
        phone: '01711111111',
        creditLimit: 50000.0,
      );
      final supSource = client.createSupplier(
        name: 'Square Pharma Depot (Duplicate)',
        phone: '01711111111',
        creditLimit: 10000.0,
      );

      expect(client.listSuppliers().length, 2);

      final mergeRes = client.mergeSuppliers(
        sourceId: supSource.supplierId,
        targetId: supTarget.supplierId,
        reason: 'Consolidation of duplicate vendor depot',
      );

      expect(mergeRes.isMerged, isTrue);
      expect(mergeRes.targetId, supTarget.supplierId);
      expect(supSource.isActive, isFalse);
      expect(supSource.mergedIntoId, supTarget.supplierId);
    });
  });
}
