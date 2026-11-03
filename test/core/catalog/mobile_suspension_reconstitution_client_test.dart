// test/core/catalog/mobile_suspension_reconstitution_client_test.dart
// Unit tests for MobileSuspensionReconstitutionClient (P143)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_suspension_reconstitution_client.dart';

void main() {
  group('MobileSuspensionReconstitutionClient Tests', () {
    late MobileSuspensionReconstitutionClient client;

    setUp(() {
      client = MobileSuspensionReconstitutionClient();
    });

    test('validatePayload accepts valid suspension reconstitution configuration', () {
      final payload = {
        'dosage_form': 'DRY_SYRUP_RECONSTITUTED',
        'reconstitution_diluent': 'BOILED_COOLED_WATER',
        'water_volume_ml': 35.0,
        'final_volume_ml': 50.0,
        'shelf_life_days': 7,
        'instructions_en': 'Add 35 mL boiled and cooled water in two parts and shake well.',
        'storage_policy': 'REFRIGERATE_2_8C_AFTER_RECONSTITUTION',
      };

      final res = client.validatePayload(payload, userRole: 'STAFF_PHARMACIST');
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('validatePayload rejects volume dimension consistency mismatch (final < water)', () {
      final payload = {
        'dosage_form': 'DRY_SYRUP_RECONSTITUTED',
        'reconstitution_diluent': 'BOILED_COOLED_WATER',
        'water_volume_ml': 60.0, // Water exceeds final volume
        'final_volume_ml': 50.0,
        'shelf_life_days': 7,
        'instructions_en': 'Add 60 mL water.',
        'storage_policy': 'REFRIGERATE_2_8C_AFTER_RECONSTITUTION',
      };

      final res = client.validatePayload(payload, userRole: 'STAFF_PHARMACIST');
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_DIMENSION_CONSISTENCY_MISMATCH'));
    });

    test('validatePayload rejects solid oral packaging attributes', () {
      final payload = {
        'dosage_form': 'DRY_SYRUP_RECONSTITUTED',
        'reconstitution_diluent': 'BOILED_COOLED_WATER',
        'water_volume_ml': 35.0,
        'final_volume_ml': 50.0,
        'shelf_life_days': 7,
        'instructions_en': 'Add 35 mL water.',
        'storage_policy': 'REFRIGERATE_2_8C_AFTER_RECONSTITUTION',
        'tablets_per_strip': 10, // Hidden solid field
      };

      final res = client.validatePayload(payload, userRole: 'STAFF_PHARMACIST');
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('calculateBeyondUseDate computes accurate target date', () {
      final openDate = DateTime(2026, 11, 3);
      final bud = client.calculateBeyondUseDate(openDate, 7);
      expect(bud, equals(DateTime(2026, 11, 10)));
    });

    test('validatePayload rejects BUD preceding opening date', () {
      final payload = {
        'dosage_form': 'DRY_SYRUP_RECONSTITUTED',
        'reconstitution_diluent': 'BOILED_COOLED_WATER',
        'water_volume_ml': 35.0,
        'final_volume_ml': 50.0,
        'shelf_life_days': 7,
        'opening_date': '2026-11-03',
        'beyond_use_date': '2026-11-02', // Preceding opening date
        'instructions_en': 'Add 35 mL water.',
        'storage_policy': 'REFRIGERATE_2_8C_AFTER_RECONSTITUTION',
      };

      final res = client.validatePayload(payload, userRole: 'STAFF_PHARMACIST');
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_BEYOND_USE_DATE'));
    });

    test('validatePayload rejects BUD exceeding stability shelf life', () {
      final payload = {
        'dosage_form': 'DRY_SYRUP_RECONSTITUTED',
        'reconstitution_diluent': 'BOILED_COOLED_WATER',
        'water_volume_ml': 35.0,
        'final_volume_ml': 50.0,
        'shelf_life_days': 7,
        'opening_date': '2026-11-03',
        'beyond_use_date': '2026-11-15', // Exceeds 7-day shelf life
        'instructions_en': 'Add 35 mL water.',
        'storage_policy': 'REFRIGERATE_2_8C_AFTER_RECONSTITUTION',
      };

      final res = client.validatePayload(payload, userRole: 'STAFF_PHARMACIST');
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_BEYOND_USE_DATE'));
    });

    test('pharmacist review authorization checks roles correctly', () {
      final payload = {
        'dosage_form': 'DRY_SYRUP_RECONSTITUTED',
        'reconstitution_diluent': 'BOILED_COOLED_WATER',
        'water_volume_ml': 35.0,
        'final_volume_ml': 50.0,
        'shelf_life_days': 7,
        'instructions_en': 'Add 35 mL water.',
        'storage_policy': 'REFRIGERATE_2_8C_AFTER_RECONSTITUTION',
        'is_pharmacist_reviewed': true,
      };

      // Pharmacist passes
      final res1 = client.validatePayload(payload, userRole: 'STAFF_PHARMACIST');
      expect(res1.isValid, isTrue);

      // Pharmacy Owner passes
      final res2 = client.validatePayload(payload, userRole: 'PHARMACY_OWNER');
      expect(res2.isValid, isTrue);

      // Cashier is denied
      final res3 = client.validatePayload(payload, userRole: 'CASHIER');
      expect(res3.isValid, isFalse);
      expect(res3.errorCode, equals('ERR_PHARMACIST_REVIEW_REQUIRED'));
    });

    test('local caching and retrieval functions correctly', () {
      final config = MobileSuspensionReconstitutionConfig(
        configId: 'src-mox-1',
        productId: 'prod-mox-1',
        brandName: 'Moxacil Dry Syrup',
        genericName: 'Amoxicillin',
        tenantId: 'tn-1',
        dosageForm: 'DRY_SYRUP_RECONSTITUTED',
        reconstitutionDiluent: 'BOILED_COOLED_WATER',
        waterVolumeMl: 40.0,
        finalVolumeMl: 60.0,
        shelfLifeDays: 7,
        openingDate: '2026-11-03',
        beyondUseDate: '2026-11-10',
        storagePolicy: 'REFRIGERATE_2_8C_AFTER_RECONSTITUTION',
        instructionsEn: 'Add 40 mL water.',
        instructionsBn: '৪০ মি.লি. পানি মেশান।',
        handlingGuidanceEn: 'Refrigerate after mixing.',
        handlingGuidanceBn: 'মিশ্রণের পর রেফ্রিজারেটরে রাখুন।',
        isPharmacistReviewed: true,
        reviewedById: 'usr-pharm-1',
        reviewedByName: 'Pharmacist Kabir',
        reviewerNotes: 'Verified with DGDA monograph.',
        isActive: true,
      );

      client.putCache('src-mox-1', config);
      expect(client.getFromCache('src-mox-1'), isNotNull);
      expect(client.getFromCache('src-mox-1')!.brandName, equals('Moxacil Dry Syrup'));
      expect(client.getAllCached().length, equals(1));

      client.clearCache();
      expect(client.getFromCache('src-mox-1'), isNull);
    });

    test('bilingual label helper returns expected strings', () {
      expect(client.getLabel('reconstitution_diluent', 'en'), equals('Reconstitution Diluent'));
      expect(client.getLabel('reconstitution_diluent', 'bn'), equals('প্রস্তুতকারক পানি / দ্রাবক'));
      expect(client.getLabel('beyond_use_date', 'en'), equals('Beyond-Use Date (BUD)'));
      expect(client.getLabel('beyond_use_date', 'bn'), equals('ব্যবহারের শেষ তারিখ (বিইউডি)'));
    });

    test('toJson and fromJson maintain data integrity', () {
      final map = {
        'config_id': 'src-123',
        'product_id': 'prod-123',
        'brand_name': 'Cef-3 50mL',
        'generic_name': 'Cefixime',
        'tenant_id': 'tn-1',
        'dosage_form': 'DRY_SYRUP_RECONSTITUTED',
        'reconstitution_diluent': 'BOILED_COOLED_WATER',
        'water_volume_ml': 35.0,
        'final_volume_ml': 50.0,
        'shelf_life_days': 10,
        'storage_policy': 'REFRIGERATE_2_8C_AFTER_RECONSTITUTION',
        'instructions_en': 'Boil water, let cool, add 35 mL.',
        'instructions_bn': '',
        'handling_guidance_en': '',
        'handling_guidance_bn': '',
        'is_pharmacist_reviewed': true,
        'is_active': true,
      };

      final config = MobileSuspensionReconstitutionConfig.fromJson(map);
      expect(config.configId, equals('src-123'));
      expect(config.waterVolumeMl, equals(35.0));
      expect(config.finalVolumeMl, equals(50.0));
      expect(config.shelfLifeDays, equals(10));

      final serialized = config.toJson();
      expect(serialized['config_id'], equals('src-123'));
      expect(serialized['water_volume_ml'], equals(35.0));
    });
  });
}
