// test/core/catalog/mobile_bulk_import_wizard_client_test.dart
// Architecture Decision: ADR-0132
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P132)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_bulk_import_wizard_client.dart';

void main() {
  group('MobileBulkImportWizardClient Tests (P132)', () {
    late MobileBulkImportWizardClient client;

    setUp(() {
      client = MobileBulkImportWizardClient();
    });

    test('P132-M1: Upload valid CSV; auto-mapping maps headers and previews first rows', () {
      const csv = 'Trade Name,Molecule,Form,Strength,MRP,Manufacturer,Barcode\n'
          'Napa 500,Paracetamol,Tablet,500mg,1.20,Beximco,890123456\n'
          'Seclo 20,Omeprazole,Capsule,20mg,6.00,Square,890654321\n';

      final result = client.uploadCsv(
        actorRole: 'PHARMACY_OWNER',
        fileName: 'catalog.csv',
        csvContent: csv,
        duplicatePolicy: 'SKIP',
      );

      expect(result.status, equals(MobileBulkImportUiStatus.success));
      expect(result.data, isNotNull);
      expect(result.data!.fileName, equals('catalog.csv'));
      expect(result.data!.totalRows, equals(2));
      expect(result.data!.previewRows.length, equals(2));

      final mapping = result.data!.fieldMapping;
      expect(mapping['Trade Name'], equals('brand_name'));
      expect(mapping['Molecule'], equals('generic_name'));
      expect(mapping['MRP'], equals('mrp_unit'));
    });

    test('P132-M2: Custom field mapping and pre-flight validation detects row errors on negative prices', () {
      const csv = 'CUSTOM_BRAND,CUSTOM_PRICE\n'
          'Valid Drug,10.00\n'
          'Negative Drug,-5.00\n'
          ',15.00\n';

      final uploadRes = client.uploadCsv(
        actorRole: 'BRANCH_MANAGER',
        fileName: 'custom.csv',
        csvContent: csv,
        duplicatePolicy: 'SKIP',
      );
      expect(uploadRes.status, equals(MobileBulkImportUiStatus.success));
      final sessionId = uploadRes.data!.sessionId;

      final mapping = {
        'CUSTOM_BRAND': 'brand_name',
        'CUSTOM_PRICE': 'mrp_unit',
      };

      final valRes = client.applyMappingAndValidate(
        sessionId: sessionId,
        fieldMapping: mapping,
        duplicatePolicy: 'SKIP',
      );
      expect(valRes.status, equals(MobileBulkImportUiStatus.success));
      expect(valRes.data!.status, equals('VALIDATED'));
      expect(valRes.data!.validRows, equals(1));
      expect(valRes.data!.invalidRows, equals(2));
      expect(valRes.data!.validationErrors.length, equals(2));
    });

    test('P132-M3: Duplicate detection with SKIP policy increments duplicate counter without failing batch', () {
      client.registerExistingCatalogBarcode('890111222');

      const csv = 'Brand,MRP,Barcode\n'
          'Existing Product,20.00,890111222\n'
          'New Product,30.00,890999888\n';

      final uploadRes = client.uploadCsv(
        actorRole: 'PHARMACY_OWNER',
        fileName: 'dup_test.csv',
        csvContent: csv,
        duplicatePolicy: 'SKIP',
      );
      expect(uploadRes.status, equals(MobileBulkImportUiStatus.success));
      expect(uploadRes.data!.duplicateRows, equals(1));
      expect(uploadRes.data!.validRows, equals(1));
    });

    test('P132-M4: Atomic commit creates products and transitions session status to COMMITTED', () {
      const csv = 'Brand,MRP\n'
          'Drug A,10.00\n'
          'Drug B,20.00\n';

      final uploadRes = client.uploadCsv(
        actorRole: 'PHARMACY_OWNER',
        fileName: 'commit_test.csv',
        csvContent: csv,
        duplicatePolicy: 'SKIP',
      );
      final sessionId = uploadRes.data!.sessionId;

      final commitRes = client.commitImport(sessionId);
      expect(commitRes.status, equals(MobileBulkImportUiStatus.success));
      expect(commitRes.data!.status, equals('COMMITTED'));
      expect(commitRes.data!.committedAt, isNotNull);
      expect(commitRes.data!.createdProductIds.length, equals(2));

      final repeatRes = client.commitImport(sessionId);
      expect(repeatRes.status, equals(MobileBulkImportUiStatus.error));
      expect(repeatRes.errorCode, equals('ERR_IMPORT_ALREADY_COMMITTED'));
    });

    test('P132-M5: Single-click rollback reverses created products and marks session ROLLED_BACK', () {
      const csv = 'Brand,MRP\nDefective Drug,100.00\n';

      final uploadRes = client.uploadCsv(
        actorRole: 'PHARMACY_OWNER',
        fileName: 'rollback_test.csv',
        csvContent: csv,
        duplicatePolicy: 'SKIP',
      );
      final sessionId = uploadRes.data!.sessionId;

      client.commitImport(sessionId);
      expect(client.getSession(sessionId)!.status, equals('COMMITTED'));

      final rollbackRes = client.rollbackImport(sessionId);
      expect(rollbackRes.status, equals(MobileBulkImportUiStatus.success));
      expect(rollbackRes.data!.status, equals('ROLLED_BACK'));
      expect(rollbackRes.data!.rolledBackAt, isNotNull);
      expect(rollbackRes.data!.createdProductIds.isEmpty, isTrue);

      final repeatRollback = client.rollbackImport(sessionId);
      expect(repeatRollback.status, equals(MobileBulkImportUiStatus.error));
      expect(repeatRollback.errorCode, equals('ERR_IMPORT_ALREADY_ROLLED_BACK'));
    });

    test('P132-M6: Cashier role blocked from uploading CSV', () {
      final result = client.uploadCsv(
        actorRole: 'CASHIER',
        fileName: 'cashier.csv',
        csvContent: 'Col1,Col2\nVal1,Val2\n',
        duplicatePolicy: 'SKIP',
      );

      expect(result.status, equals(MobileBulkImportUiStatus.permissionDenied));
      expect(result.errorCode, equals('ERR_STAFF_ROLE_DENIED'));
      expect(result.messageBn, isNotEmpty);
    });
  });
}
