import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_global_medicine_catalog_client.dart';

void main() {
  group('ADR-0070: Mobile Global Medicine Master Catalogue Client Tests', () {
    test('authorizes only platform curation roles to modify master catalog', () {
      expect(MobileGlobalMedicineCatalogClient.canRoleModifyGlobalCatalog('SUPERADMIN'), isTrue);
      expect(MobileGlobalMedicineCatalogClient.canRoleModifyGlobalCatalog('SUPER_ADMIN'), isTrue);
      expect(MobileGlobalMedicineCatalogClient.canRoleModifyGlobalCatalog('PLATFORM_OPERATOR'), isTrue);

      expect(MobileGlobalMedicineCatalogClient.canRoleModifyGlobalCatalog('PHARMACY_OWNER'), isFalse);
      expect(MobileGlobalMedicineCatalogClient.canRoleModifyGlobalCatalog('BRANCH_MANAGER'), isFalse);
      expect(MobileGlobalMedicineCatalogClient.canRoleModifyGlobalCatalog('STAFF_PHARMACIST'), isFalse);
      expect(MobileGlobalMedicineCatalogClient.canRoleModifyGlobalCatalog('CASHIER'), isFalse);
      expect(MobileGlobalMedicineCatalogClient.canRoleModifyGlobalCatalog(null), isFalse);
    });

    test('recalled product detection blocks sales', () {
      expect(MobileGlobalMedicineCatalogClient.isProductRecalled('RECALLED'), isTrue);
      expect(MobileGlobalMedicineCatalogClient.isProductRecalled('recalled'), isTrue);

      expect(MobileGlobalMedicineCatalogClient.isProductRecalled('APPROVED'), isFalse);
      expect(MobileGlobalMedicineCatalogClient.isProductRecalled('UNDER_REVIEW'), isFalse);
      expect(MobileGlobalMedicineCatalogClient.isProductRecalled(null), isFalse);
    });

    test('prescriptions are mandatory for POM, narcotic, or antibiotic classifications', () {
      expect(MobileGlobalMedicineCatalogClient.isPrescriptionMandatory(isPrescriptionOnly: true), isTrue);
      expect(MobileGlobalMedicineCatalogClient.isPrescriptionMandatory(isNarcotic: true), isTrue);
      expect(MobileGlobalMedicineCatalogClient.isPrescriptionMandatory(isAntibiotic: true), isTrue);
      expect(
        MobileGlobalMedicineCatalogClient.isPrescriptionMandatory(
          isPrescriptionOnly: true,
          isNarcotic: true,
          isAntibiotic: true,
        ),
        isTrue,
      );

      expect(MobileGlobalMedicineCatalogClient.isPrescriptionMandatory(), isFalse);
    });

    test('resolves curation status badge tone accurately', () {
      expect(MobileGlobalMedicineCatalogClient.resolveStatusTone('APPROVED'), 'success');
      expect(MobileGlobalMedicineCatalogClient.resolveStatusTone('UNDER_REVIEW'), 'warning');
      expect(MobileGlobalMedicineCatalogClient.resolveStatusTone('RECALLED'), 'danger');
      expect(MobileGlobalMedicineCatalogClient.resolveStatusTone('DRAFT'), 'info');
      expect(MobileGlobalMedicineCatalogClient.resolveStatusTone('DEPRECATED'), 'neutral');
      expect(MobileGlobalMedicineCatalogClient.resolveStatusTone(null), 'neutral');
    });

    test('validates DGDA DAR number pattern', () {
      expect(MobileGlobalMedicineCatalogClient.isValidDarNumber('DAR-024-0012'), isTrue);
      expect(MobileGlobalMedicineCatalogClient.isValidDarNumber('DAR-NAPA-500'), isTrue);
      expect(MobileGlobalMedicineCatalogClient.isValidDarNumber('NOT-DAR'), isFalse);
      expect(MobileGlobalMedicineCatalogClient.isValidDarNumber(''), isFalse);
      expect(MobileGlobalMedicineCatalogClient.isValidDarNumber(null), isFalse);
    });

    test('builds browse and detail endpoint URLs with validation', () {
      expect(
        MobileGlobalMedicineCatalogClient.buildCatalogQueryUrl(page: 2, pageSize: 15, search: 'Paracetamol'),
        '/api/v2/products/?page=2&page_size=15&search=Paracetamol',
      );
      expect(
        MobileGlobalMedicineCatalogClient.buildCatalogQueryUrl(),
        '/api/v2/products/?page=1&page_size=20',
      );
      expect(
        MobileGlobalMedicineCatalogClient.buildProductDetailUrl('prod-12345'),
        '/api/v2/products/prod-12345/',
      );

      expect(
        () => MobileGlobalMedicineCatalogClient.buildProductDetailUrl('invalid id!'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
