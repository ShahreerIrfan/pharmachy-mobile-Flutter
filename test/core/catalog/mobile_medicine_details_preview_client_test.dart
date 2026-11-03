// test/core/catalog/mobile_medicine_details_preview_client_test.dart
// Architecture Decision: ADR-0138
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P138)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_medicine_details_preview_client.dart';

void main() {
  group('P138: MobileMedicineDetailsPreviewClient Unit & Integration Tests', () {
    late MobileMedicineDetailsPreviewClient client;
    const testTenant1 = 'tn-mob-banani-101';
    const testTenant2 = 'tn-mob-gulshan-202';

    setUp(() {
      client = MobileMedicineDetailsPreviewClient();

      // Seed Napa 500mg
      final napaTiers = [
        MobilePackagingTier(packagingLevel: 'UNIT', multiplier: 1, barcodeValue: '8901112223334', priorityOrder: 1),
        MobilePackagingTier(packagingLevel: 'STRIP', multiplier: 10, priorityOrder: 2),
        MobilePackagingTier(packagingLevel: 'BOX', multiplier: 100, barcodeValue: '18901112223331', priorityOrder: 3),
      ];
      final napaVariants = [
        MobileVariantSummary(
          variantId: 'var-napa-100',
          sku: 'SKU-NAPA-100',
          variantName: 'Napa 500mg Box 100s',
          strength: '500 mg',
          packSize: 'Box of 100',
          packSizeNumeric: 100,
          containerType: 'BLISTER_PACK',
          mrpPack: 120.00,
          costPack: 95.00,
          barcode: '18901112223331',
        ),
      ];

      final napa = MobileMedicinePreviewRecord(
        productId: 'med-napa-500',
        brandName: 'Napa 500mg',
        brandNameBn: 'নাপা ৫০০ মি.গ্রা.',
        genericName: 'Paracetamol',
        genericNameBn: 'প্যারাসিটামল',
        manufacturer: 'Beximco Pharmaceuticals Ltd.',
        dgdaDarNumber: 'DAR-012-334',
        curationStatus: 'APPROVED',
        dosageForm: 'Tablet',
        strength: '500 mg',
        strengthNumeric: 500.0,
        strengthUnit: 'mg',
        strengthUnitFamily: 'MASS',
        route: 'Oral',
        primaryBarcode: '8901112223334',
        mrpUnit: 1.20,
        costUnit: 0.95,
        effectiveMrpUnit: 1.20,
        hasTenantOverride: false,
        localBrandName: '',
        shelfLocation: '',
        isPrescriptionOnly: false,
        isNarcotic: false,
        isAntibiotic: false,
        antimicrobialClassification: 'NONE',
        rxClassificationLabel: 'Over-The-Counter (OTC)',
        rxClassificationLabelBn: 'ওভার-দ্য-কাউন্টার (OTC)',
        requiresColdChain: false,
        minTempCelsius: 15.0,
        maxTempCelsius: 30.0,
        storageInstructions: 'Store below 30°C in a dry place.',
        storageInstructionsBn: '৩০°সে এর নিচে শুষ্ক স্থানে সংরক্ষণ করুন।',
        packagingHierarchy: napaTiers,
        variants: napaVariants,
        isRecalled: false,
        isDiscontinued: false,
        isDispensingBlocked: false,
        activeRecallNotice: null,
        immutablePreviewHash: 'hash-dummy-01',
      );
      client.registerMedicine(napa);

      // Seed Insulin Injection
      final insulin = MobileMedicinePreviewRecord(
        productId: 'med-insulin-100',
        brandName: 'Glaritus 100 IU',
        brandNameBn: 'গ্ল্যারিটাস ১০০ আইইউ',
        genericName: 'Insulin Glargine',
        genericNameBn: 'ইনসুলিন গ্লার্জিন',
        manufacturer: 'Wockhardt Ltd.',
        dgdaDarNumber: 'DAR-INS-901',
        curationStatus: 'APPROVED',
        dosageForm: 'Injection',
        strength: '100 IU/mL',
        strengthNumeric: 100.0,
        strengthUnit: 'IU/mL',
        strengthUnitFamily: 'BIOLOGICAL',
        route: 'Subcutaneous',
        primaryBarcode: '8904445556667',
        mrpUnit: 450.00,
        costUnit: 380.00,
        effectiveMrpUnit: 450.00,
        hasTenantOverride: false,
        localBrandName: '',
        shelfLocation: '',
        isPrescriptionOnly: true,
        isNarcotic: false,
        isAntibiotic: false,
        antimicrobialClassification: 'NONE',
        rxClassificationLabel: 'Prescription-Only Medicine (POM)',
        rxClassificationLabelBn: 'প্রেসক্রিপশন আবশ্যক (POM)',
        requiresColdChain: true,
        minTempCelsius: 2.0,
        maxTempCelsius: 8.0,
        storageInstructions: 'Store in refrigerator between 2.0°C and 8.0°C. Do not freeze.',
        storageInstructionsBn: '২.০°সে থেকে ৮.০°সে তাপমাত্রায় রেফ্রিজারেটরে সংরক্ষণ করুন।',
        packagingHierarchy: const [],
        variants: const [],
        isRecalled: false,
        isDiscontinued: false,
        isDispensingBlocked: false,
        activeRecallNotice: null,
        immutablePreviewHash: 'hash-dummy-02',
      );
      client.registerMedicine(insulin);
    });

    test('P138-M1: Complete medicine preview returns dosage form, strength, route, and packaging hierarchy', () {
      final res = client.getMedicinePreview(
        targetTenantId: testTenant1,
        actorTenantId: testTenant1,
        productId: 'med-napa-500',
        userRole: 'BRANCH_MANAGER',
      );

      expect(res.status, equals(MobilePreviewUiStatus.success));
      expect(res.data, isNotNull);
      expect(res.data!.brandName, equals('Napa 500mg'));
      expect(res.data!.dosageForm, equals('Tablet'));
      expect(res.data!.strength, equals('500 mg'));
      expect(res.data!.route, equals('Oral'));
      expect(res.data!.mrpUnit, equals(1.20));
      expect(res.data!.packagingHierarchy.length, equals(3));
      expect(res.data!.variants.length, equals(1));
      expect(res.data!.immutablePreviewHash.length, equals(64));
    });

    test('P138-M2: Cold chain injection displays temperature bounds (2-8 C) and refrigerator instructions', () {
      final res = client.getMedicinePreview(
        targetTenantId: testTenant1,
        actorTenantId: testTenant1,
        productId: 'med-insulin-100',
        userRole: 'STAFF_PHARMACIST',
      );

      expect(res.status, equals(MobilePreviewUiStatus.success));
      expect(res.data!.requiresColdChain, isTrue);
      expect(res.data!.minTempCelsius, equals(2.0));
      expect(res.data!.maxTempCelsius, equals(8.0));
      expect(res.data!.isPrescriptionOnly, isTrue);
      expect(res.data!.storageInstructions.contains('refrigerator'), isTrue);
      expect(res.data!.storageInstructionsBn.contains('রেফ্রিজারেটরে'), isTrue);
    });

    test('P138-M3: Prescription and antimicrobial classification indicators accurately represented', () {
      final res = client.getMedicinePreview(
        targetTenantId: testTenant1,
        actorTenantId: testTenant1,
        productId: 'med-insulin-100',
        userRole: 'STAFF_PHARMACIST',
      );

      expect(res.status, equals(MobilePreviewUiStatus.success));
      expect(res.data!.isPrescriptionOnly, isTrue);
      expect(res.data!.rxClassificationLabel, equals('Prescription-Only Medicine (POM)'));
      expect(res.data!.isNarcotic, isFalse);
    });

    test('P138-M4: Tenant store overrides and shelf location accurately integrated', () {
      client.setTenantOverride(
        tenantId: testTenant1,
        productId: 'med-napa-500',
        customMrp: 1.50,
        localBrand: 'Fast Action Napa',
        shelf: 'Rack B-2',
      );

      // Tenant 1 preview reflects override
      final res1 = client.getMedicinePreview(
        targetTenantId: testTenant1,
        actorTenantId: testTenant1,
        productId: 'med-napa-500',
        userRole: 'BRANCH_MANAGER',
      );
      expect(res1.status, equals(MobilePreviewUiStatus.success));
      expect(res1.data!.hasTenantOverride, isTrue);
      expect(res1.data!.effectiveMrpUnit, equals(1.50));
      expect(res1.data!.localBrandName, equals('Fast Action Napa'));
      expect(res1.data!.shelfLocation, equals('Rack B-2'));

      // Tenant 2 preview shows standard master price without Tenant 1 override
      final res2 = client.getMedicinePreview(
        targetTenantId: testTenant2,
        actorTenantId: testTenant2,
        productId: 'med-napa-500',
        userRole: 'BRANCH_MANAGER',
      );
      expect(res2.status, equals(MobilePreviewUiStatus.success));
      expect(res2.data!.hasTenantOverride, isFalse);
      expect(res2.data!.effectiveMrpUnit, equals(1.20));
    });

    test('P138-M5: Cashier can preview medicine details, but wholesale cost price is masked to null', () {
      // Cashier role -> costUnit is null
      final cashierRes = client.getMedicinePreview(
        targetTenantId: testTenant1,
        actorTenantId: testTenant1,
        productId: 'med-napa-500',
        userRole: 'CASHIER',
      );
      expect(cashierRes.status, equals(MobilePreviewUiStatus.success));
      expect(cashierRes.data!.costUnit, isNull);
      expect(cashierRes.data!.mrpUnit, equals(1.20));

      // Manager role -> costUnit is visible
      final mgrRes = client.getMedicinePreview(
        targetTenantId: testTenant1,
        actorTenantId: testTenant1,
        productId: 'med-napa-500',
        userRole: 'BRANCH_MANAGER',
      );
      expect(mgrRes.status, equals(MobilePreviewUiStatus.success));
      expect(mgrRes.data!.costUnit, equals(0.95));
    });

    test('P138-M6: Cross-tenant override query blocked with ERR_CROSS_TENANT_ACCESS and offline mode serves cached preview', () {
      // Tenant 2 attempts to query Tenant 1's overrides -> Denied
      final crossRes = client.getMedicinePreview(
        targetTenantId: testTenant1,
        actorTenantId: testTenant2,
        productId: 'med-napa-500',
        userRole: 'BRANCH_MANAGER',
      );
      expect(crossRes.status, equals(MobilePreviewUiStatus.permissionDenied));
      expect(crossRes.errorCode, equals('ERR_CROSS_TENANT_ACCESS'));

      // Enter offline mode
      client.isOffline = true;
      expect(client.isOffline, isTrue);

      final offlineRes = client.getMedicinePreview(
        targetTenantId: testTenant1,
        actorTenantId: testTenant1,
        productId: 'med-napa-500',
        userRole: 'BRANCH_MANAGER',
      );
      expect(offlineRes.status, equals(MobilePreviewUiStatus.offline));
      expect(offlineRes.data, isNotNull);
      expect(offlineRes.data!.brandName, equals('Napa 500mg'));
    });
  });
}
