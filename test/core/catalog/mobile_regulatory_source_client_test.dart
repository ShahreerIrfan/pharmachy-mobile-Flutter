// test/core/catalog/mobile_regulatory_source_client_test.dart
// Architecture Decision: ADR-0134
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P134)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_regulatory_source_client.dart';

void main() {
  group('P134: MobileRegulatorySourceClient Unit & Integration Tests', () {
    late MobileRegulatorySourceClient client;
    const testProductId = 'med-mob-insulin-001';

    setUp(() {
      client = MobileRegulatorySourceClient();
      client.registerProduct(testProductId, {
        'brand_name': 'Insulin Glargine Mobile',
        'generic_name': 'Insulin Glargine',
        'requires_cold_chain': false,
        'is_prescription_only': false,
      });
    });

    test('P134-M1: Attach regulatory source with storage rules and synchronize cold chain bounds to product', () {
      const storage = MobileStorageRuleSpecs(
        requiresColdChain: true,
        minTempCelsius: 2.0,
        maxTempCelsius: 8.0,
        protectFromLight: true,
        maxHumidityPercent: 60,
        handlingInstructions: 'Store in refrigerator 2-8 C. Protect from direct sunlight.',
      );

      const classification = MobileClassificationSpecs(
        classificationType: 'PRESCRIPTION_ONLY',
        isAntibiotic: false,
        isNarcotic: false,
        specialDispensingConditions: 'Cold-chain insulated package required',
      );

      final result = client.attachSource(
        productId: testProductId,
        sourceType: 'DGDA_GAZETTE',
        ruleTarget: 'CLASSIFICATION_AND_STORAGE',
        documentReferenceNumber: 'DGDA/DL/Gazette-2026-MOB',
        issuingAuthority: 'DGDA Bangladesh',
        effectiveDate: DateTime(2026, 6, 1),
        publicationDate: DateTime(2026, 5, 15),
        reviewCycleMonths: 24,
        nextReviewDueDate: DateTime(2028, 6, 1),
        sourceUrl: 'https://dgda.gov.bd/glargine-mob.pdf',
        storageSpecs: storage,
        classificationSpecs: classification,
        userRole: 'STAFF_PHARMACIST',
        reviewerEmail: 'pharmacist@pharma.local',
        reviewNotes: 'Verified statutory cold chain biological requirements',
      );

      expect(result.status, equals(MobileRegulatoryUiStatus.success));
      expect(result.data, isNotNull);
      expect(result.data!.productId, equals(testProductId));
      expect(result.data!.versionNumber, equals(1));
      expect(result.data!.isActive, isTrue);
      expect(result.data!.immutableSourceHash.length, equals(64));

      // Verify product attributes
      final product = client.getProduct(testProductId);
      expect(product!['requires_cold_chain'], isTrue);
      expect(product['min_temp_celsius'], equals(2.0));
      expect(product['max_temp_celsius'], equals(8.0));
      expect(product['is_prescription_only'], isTrue);
      expect(product['regulatory_source'], equals('DGDA/DL/Gazette-2026-MOB'));
    });

    test('P134-M2: Cold chain rule violation (min_temp >= max_temp) rejected', () {
      const storage = MobileStorageRuleSpecs(
        requiresColdChain: true,
        minTempCelsius: 10.0,
        maxTempCelsius: 4.0, // Inverted: min > max
      );

      final result = client.attachSource(
        productId: testProductId,
        sourceType: 'MANUFACTURER_MONOGRAPH',
        ruleTarget: 'STORAGE_CONDITION',
        documentReferenceNumber: 'INCEPTA-MOB-01',
        issuingAuthority: 'Incepta Regulatory',
        effectiveDate: DateTime(2026, 1, 1),
        storageSpecs: storage,
        userRole: 'STAFF_PHARMACIST',
      );

      expect(result.status, equals(MobileRegulatoryUiStatus.error));
      expect(result.errorCode, equals('ERR_COLD_CHAIN_BOUNDARY_VIOLATION'));
    });

    test('P134-M3: next_review_due_date earlier than effective_date rejected', () {
      final result = client.attachSource(
        productId: testProductId,
        sourceType: 'PHARMACOPOEIA',
        ruleTarget: 'CLASSIFICATION',
        documentReferenceNumber: 'BP-2026-MOB',
        issuingAuthority: 'British Pharmacopoeia',
        effectiveDate: DateTime(2026, 6, 1),
        nextReviewDueDate: DateTime(2025, 1, 1), // Invalid past review date
        userRole: 'STAFF_PHARMACIST',
      );

      expect(result.status, equals(MobileRegulatoryUiStatus.error));
      expect(result.errorCode, equals('ERR_INVALID_REVIEW_DATE'));
    });

    test('P134-M4: Revision increments version and generates distinct SHA-256 hash', () {
      const docRef = 'DGDA-CIRCULAR-MOB-500';

      final v1Res = client.attachSource(
        productId: testProductId,
        sourceType: 'DGDA_CIRCULAR',
        ruleTarget: 'CLASSIFICATION',
        documentReferenceNumber: docRef,
        issuingAuthority: 'DGDA',
        effectiveDate: DateTime(2026, 1, 1),
        userRole: 'STAFF_PHARMACIST',
      );
      expect(v1Res.status, equals(MobileRegulatoryUiStatus.success));
      expect(v1Res.data!.versionNumber, equals(1));

      final v2Res = client.attachSource(
        productId: testProductId,
        sourceType: 'DGDA_CIRCULAR',
        ruleTarget: 'CLASSIFICATION',
        documentReferenceNumber: docRef,
        issuingAuthority: 'DGDA',
        effectiveDate: DateTime(2026, 7, 1),
        userRole: 'STAFF_PHARMACIST',
      );
      expect(v2Res.status, equals(MobileRegulatoryUiStatus.success));
      expect(v2Res.data!.versionNumber, equals(2));
      expect(v1Res.data!.immutableSourceHash, isNot(equals(v2Res.data!.immutableSourceHash)));
    });

    test('P134-M5: Cashier role denied from attaching or mutating regulatory sources', () {
      final result = client.attachSource(
        productId: testProductId,
        sourceType: 'DGDA_GAZETTE',
        ruleTarget: 'STORAGE_CONDITION',
        documentReferenceNumber: 'DGDA-CASHIER-MOB',
        issuingAuthority: 'DGDA',
        effectiveDate: DateTime(2026, 1, 1),
        userRole: 'CASHIER',
      );

      expect(result.status, equals(MobileRegulatoryUiStatus.permissionDenied));
      expect(result.errorCode, equals('ERR_STAFF_ROLE_DENIED'));
    });

    test('P134-M6: Offline fallback serves cached regulatory sources safely', () {
      final attachRes = client.attachSource(
        productId: testProductId,
        sourceType: 'WHO_AWARE',
        ruleTarget: 'CLASSIFICATION',
        documentReferenceNumber: 'WHO-AWARE-MOB-2026',
        issuingAuthority: 'World Health Organization',
        effectiveDate: DateTime(2026, 3, 1),
        userRole: 'STAFF_PHARMACIST',
      );
      expect(attachRes.status, equals(MobileRegulatoryUiStatus.success));

      client.isOffline = true;
      expect(client.isOffline, isTrue);

      final searchRes = client.searchAttachments(productId: testProductId, search: 'WHO-AWARE');
      expect(searchRes.status, equals(MobileRegulatoryUiStatus.offline));
      expect(searchRes.data, isNotNull);
      expect(searchRes.data!.length, equals(1));
      expect(searchRes.data!.first.attachmentId, equals(attachRes.data!.attachmentId));
    });
  });
}
