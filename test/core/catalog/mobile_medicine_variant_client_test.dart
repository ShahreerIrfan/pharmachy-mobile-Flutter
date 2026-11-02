import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_medicine_variant_client.dart';

void main() {
  group('P126 Mobile Medicine Variant Tests', () {
    late MobileMedicineVariantClient client;
    late MobileMedicineVariantRecord sampleVariant;

    setUp(() {
      client = MobileMedicineVariantClient();
      sampleVariant = const MobileMedicineVariantRecord(
        variantId: 'var-napa-500-100b',
        productId: 'med-napa-paracetamol',
        sku: 'SKU-BEX-NAPA-500-100B',
        variantName: 'Napa 500mg Tablet (Box of 100)',
        brandName: 'Napa',
        genericName: 'Paracetamol',
        dosageForm: 'TABLET',
        manufacturer: 'Beximco Pharmaceuticals Ltd.',
        strength: '500 mg',
        packSize: 'Box of 100',
        packSizeNumeric: 100,
        route: 'Oral',
        containerType: 'BLISTER_PACK',
        barcode: '8941100123456',
        mrpUnit: 1.20,
        costUnit: 1.00,
        mrpPack: 120.00,
        costPack: 100.00,
        isPrescriptionRequired: false,
        isNarcotic: false,
        isAntibiotic: false,
        isColdChain: false,
        isActive: true,
      );
      client.registerVariant(sampleVariant);
    });

    test('P126-M1: Barcode lookup accurately resolves commercial SKU presentation', () {
      final res = client.lookupByBarcode('8941100123456');
      expect(res.uiStatus, MobileVariantUiStatus.success);
      expect(res.variants.length, 1);
      expect(res.variants[0].sku, 'SKU-BEX-NAPA-500-100B');
      expect(res.variants[0].packSizeNumeric, 100);
    });

    test('P126-M2: SKU lookup resolves pack size and unit/pack prices', () {
      final res = client.lookupBySku('SKU-BEX-NAPA-500-100B');
      expect(res.uiStatus, MobileVariantUiStatus.success);
      expect(res.variants.length, 1);
      expect(res.variants[0].variantName, 'Napa 500mg Tablet (Box of 100)');
      expect(res.variants[0].mrpPack, 120.00);
    });

    test('P126-M3: Query search matches across brand, generic, and SKU keywords', () {
      final res = client.searchVariants('Paracetamol');
      expect(res.uiStatus, MobileVariantUiStatus.success);
      expect(res.variants.length, 1);
      expect(res.variants[0].brandName, 'Napa');
    });

    test('P126-M4: Regulatory classifications reflect parent drug clinical constraints', () {
      final res = client.lookupBySku('SKU-BEX-NAPA-500-100B');
      final rec = res.variants[0];
      expect(rec.isPrescriptionRequired, isFalse);
      expect(rec.isNarcotic, isFalse);
      expect(rec.isAntibiotic, isFalse);
      expect(rec.isColdChain, isFalse);
    });

    test('P126-M5: Pharmacy owner mutation blocked with PLATFORM_CATALOG_OWNERSHIP_PROTECTED', () {
      final res = client.attemptCreateVariant(
        callerRole: 'PHARMACY_OWNER',
        variant: sampleVariant,
      );
      expect(res.uiStatus, MobileVariantUiStatus.permissionDenied);
      expect(res.errorCode, 'PLATFORM_CATALOG_OWNERSHIP_PROTECTED');
    });

    test('P126-M6: Superadmin can create and register commercial variants', () {
      final res = client.attemptCreateVariant(
        callerRole: 'SUPERADMIN',
        variant: sampleVariant,
      );
      expect(res.uiStatus, MobileVariantUiStatus.success);
      expect(res.variants.length, 1);
    });
  });
}
