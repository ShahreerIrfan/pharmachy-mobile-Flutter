// test/core/catalog/mobile_medicine_form_template_client_test.dart
// Architecture Decision: ADR-0131
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P131)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_medicine_form_template_client.dart';

void main() {
  group('MobileMedicineFormTemplateClient Tests (P131)', () {
    late MobileMedicineFormTemplateClient client;

    setUp(() {
      client = MobileMedicineFormTemplateClient();
    });

    test('P131-M1: Queries default TABLET template; verifies 12-column grid and box/strip/unit hierarchy', () {
      final result = client.getTemplate('TABLET');

      expect(result.status, equals(MobileFormTemplateUiStatus.success));
      expect(result.data, isNotNull);
      expect(result.data!.dosageFormCode, equals('TABLET'));
      expect(result.data!.templateCode, equals('TABLET_STANDARD'));
      expect(result.data!.templateVersion, equals('v1.0'));
      expect(result.data!.isDefault, isTrue);
      expect(result.data!.layoutRules.gridColumns, equals(12));

      final sections = result.data!.layoutRules.sections;
      expect(sections.any((s) => s.sectionId == 'packaging_hierarchy'), isTrue);

      final allowed = result.data!.allowedValues;
      expect(allowed.strengthUnits.contains('mg'), isTrue);
      expect(allowed.containerTypes.contains('STRIP'), isTrue);
      expect(result.data!.immutableVersionHash.length, equals(64));
    });

    test('P131-M2: Queries SYRUP template; verifies liquid volume (mL) and concentration units (mg/5mL)', () {
      final result = client.getTemplate('SYRUP');

      expect(result.status, equals(MobileFormTemplateUiStatus.success));
      expect(result.data, isNotNull);
      expect(result.data!.dosageFormCode, equals('SYRUP'));
      expect(result.data!.templateCode, equals('SYRUP_LIQUID'));

      final sections = result.data!.layoutRules.sections;
      expect(sections.any((s) => s.sectionId == 'liquid_volume_spec'), isTrue);
      expect(result.data!.allowedValues.strengthUnits.contains('mg/5mL'), isTrue);
      expect(result.data!.allowedValues.containerTypes.contains('PET_BOTTLE'), isTrue);
    });

    test('P131-M3: Queries INJECTION template; verifies cold-chain temperature thresholds and vial/ampoule packaging', () {
      final result = client.getTemplate('INJECTION');

      expect(result.status, equals(MobileFormTemplateUiStatus.success));
      expect(result.data, isNotNull);
      expect(result.data!.dosageFormCode, equals('INJECTION'));

      final sections = result.data!.layoutRules.sections;
      expect(sections.any((s) => s.sectionId == 'cold_chain_spec'), isTrue);

      final allowed = result.data!.allowedValues;
      expect(allowed.containerTypes.contains('VIAL'), isTrue);
      expect(allowed.containerTypes.contains('AMPOULE'), isTrue);
      expect(allowed.storageConditions.contains('COLD_CHAIN_2_8C'), isTrue);
      expect(allowed.administrationRoutes.contains('Intravenous (IV)'), isTrue);
    });

    test('P131-M4: Allowed-values resolution returns domain enums for frontend dropdowns', () {
      final result = client.getAllowedValues('TABLET');

      expect(result.status, equals(MobileFormTemplateUiStatus.success));
      expect(result.data, isNotNull);
      expect(result.data!.strengthUnits.contains('mg'), isTrue);
      expect(result.data!.strengthUnits.contains('mcg'), isTrue);
      expect(result.data!.administrationRoutes.contains('Oral'), isTrue);

      final emptyRes = client.getAllowedValues('NON_EXISTENT_FORM');
      expect(emptyRes.status, equals(MobileFormTemplateUiStatus.empty));
    });

    test('P131-M5: Tenant owner or cashier denied mutating form templates', () {
      const dummyLayout = MobileLayoutRules(
        gridColumns: 12,
        sections: [
          MobileLayoutSection(sectionId: 'sec1', titleEn: 'Title', titleBn: 'শিরোনাম', displayOrder: 1),
        ],
      );
      const dummyAllowed = MobileAllowedValues(
        strengthUnits: ['mg'],
        administrationRoutes: ['Oral'],
        containerTypes: ['STRIP'],
        storageConditions: ['ROOM_TEMPERATURE'],
        dispensingUnits: ['Tablet'],
      );

      // Pharmacy Owner attempt
      final rOwner = client.createTemplate(
        actorRole: 'PHARMACY_OWNER',
        dosageFormCode: 'TABLET',
        templateCode: 'TENANT_TAB',
        titleEn: 'Custom Tab',
        titleBn: 'কাস্টম ট্যাব',
        layoutRules: dummyLayout,
        allowedValues: dummyAllowed,
      );
      expect(rOwner.status, equals(MobileFormTemplateUiStatus.permissionDenied));
      expect(rOwner.errorCode, equals('PLATFORM_CATALOG_OWNERSHIP_PROTECTED'));
      expect(rOwner.messageBn, isNotEmpty);

      // Cashier attempt
      final rCashier = client.createTemplate(
        actorRole: 'CASHIER',
        dosageFormCode: 'TABLET',
        templateCode: 'CASHIER_TAB',
        titleEn: 'Cashier Tab',
        titleBn: 'ক্যাশিয়ার ট্যাব',
        layoutRules: dummyLayout,
        allowedValues: dummyAllowed,
      );
      expect(rCashier.status, equals(MobileFormTemplateUiStatus.permissionDenied));
      expect(rCashier.errorCode, equals('PLATFORM_CATALOG_OWNERSHIP_PROTECTED'));
    });

    test('P131-M6: Offline fallback resolves cached dosage-form template safely during network disconnection', () {
      client.setOfflineMode(true);
      expect(client.isOfflineMode(), isTrue);

      final result = client.getTemplate('TABLET');
      expect(result.status, equals(MobileFormTemplateUiStatus.offline));
      expect(result.data, isNotNull);
      expect(result.data!.dosageFormCode, equals('TABLET'));
      expect(result.errorCode, equals('STATUS_OFFLINE_CACHE'));

      final unknown = client.getTemplate('UNKNOWN_OFFLINE_999');
      expect(unknown.status, equals(MobileFormTemplateUiStatus.empty));
    });
  });
}
