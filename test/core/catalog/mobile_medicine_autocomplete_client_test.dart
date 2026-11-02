// test/core/catalog/mobile_medicine_autocomplete_client_test.dart
// Architecture Decision: ADR-0129 (P129)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_medicine_autocomplete_client.dart';

void main() {
  group('P129 Mobile Medicine Search Autocomplete Tests', () {
    late MobileMedicineAutocompleteClient client;

    setUp(() {
      client = MobileMedicineAutocompleteClient();

      // Item 1: Napa 500mg (OTC with local override)
      client.addEntry(
        'tenant-uttara',
        const MobileCatalogEntry(
          productId: 'prod-napa-500',
          brandNameEn: 'Napa',
          brandNameBn: 'নাপা',
          genericName: 'Paracetamol',
          dosageForm: 'Tablet',
          strength: '500mg',
          manufacturer: 'Beximco Pharmaceuticals Ltd.',
          barcode: '890123400001',
          mrpUnit: 1.20,
          isPrescriptionOnly: false,
          localBrandName: 'নাপা ৫০০ (উত্তরা স্পেশাল)',
          customMrpUnit: 1.50,
          localSku: 'SKU-UTT-NAPA-01',
        ),
      );

      // Item 2: Seclo 20mg (POM)
      client.addEntry(
        'tenant-uttara',
        const MobileCatalogEntry(
          productId: 'prod-seclo-20',
          brandNameEn: 'Seclo',
          brandNameBn: 'সেকলো',
          genericName: 'Omeprazole',
          dosageForm: 'Capsule',
          strength: '20mg',
          manufacturer: 'Square Pharmaceuticals PLC',
          barcode: '890123400002',
          mrpUnit: 6.00,
          isPrescriptionOnly: true,
        ),
      );

      // Item 3: Hidden Medicine
      client.addEntry(
        'tenant-uttara',
        const MobileCatalogEntry(
          productId: 'prod-hidden-drug',
          brandNameEn: 'Hidden Drug',
          genericName: 'Secret Molecule',
          mrpUnit: 100.00,
          isVisible: false, // Hidden from counter search
        ),
      );
    });

    test('P129-M1: Exact barcode scan match ranks #1 with score 100', () {
      final res = client.autocomplete(
        callerTenantId: 'tenant-uttara',
        targetTenantId: 'tenant-uttara',
        query: '890123400001',
      );

      expect(res.status, equals(MobileAutocompleteUiStatus.success));
      expect(res.matches, isNotEmpty);
      final top = res.matches.first;
      expect(top.productId, equals('prod-napa-500'));
      expect(top.rankScore, equals(100));
      expect(top.matchType, equals('BARCODE_EXACT'));
      expect(top.effectiveMrpUnit, equals(1.50));
      expect(top.displayName, contains('নাপা ৫০০ (উত্তরা স্পেশাল)'));
    });

    test('P129-M2: Brand prefix match ranks high with score 90', () {
      final res = client.autocomplete(
        callerTenantId: 'tenant-uttara',
        targetTenantId: 'tenant-uttara',
        query: 'sec',
      );

      expect(res.status, equals(MobileAutocompleteUiStatus.success));
      expect(res.matches, isNotEmpty);
      final match = res.matches.first;
      expect(match.productId, equals('prod-seclo-20'));
      expect(match.rankScore, equals(90));
      expect(match.matchType, equals('BRAND_PREFIX'));
      expect(match.effectiveRequiresPrescription, isTrue);
    });

    test('P129-M3: Bengali transliteration query matches English brand with score 75', () {
      final res = client.autocomplete(
        callerTenantId: 'tenant-uttara',
        targetTenantId: 'tenant-uttara',
        query: 'নাপা',
      );

      expect(res.status, equals(MobileAutocompleteUiStatus.success));
      expect(res.matches, isNotEmpty);
      final match = res.matches.first;
      expect(match.productId, equals('prod-napa-500'));
      expect(match.rankScore, greaterThanOrEqualTo(75));
    });

    test('P129-M4: Excludes hidden items where is_visible == false', () {
      final res = client.autocomplete(
        callerTenantId: 'tenant-uttara',
        targetTenantId: 'tenant-uttara',
        query: 'Hidden',
      );

      expect(res.status, equals(MobileAutocompleteUiStatus.success));
      expect(res.matches.any((m) => m.productId == 'prod-hidden-drug'), isFalse);
    });

    test('P129-M5: Cross-tenant search is strictly blocked with ERR_CROSS_TENANT_ACCESS', () {
      final res = client.autocomplete(
        callerTenantId: 'tenant-banani',
        targetTenantId: 'tenant-uttara',
        query: 'napa',
      );

      expect(res.status, equals(MobileAutocompleteUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_CROSS_TENANT_ACCESS'));
    });

    test('P129-M6: Offline index search resolves results within sub-50ms latency target', () {
      final res = client.autocomplete(
        callerTenantId: 'tenant-uttara',
        targetTenantId: 'tenant-uttara',
        query: 'napa',
        isOnline: false,
      );

      expect(res.status, equals(MobileAutocompleteUiStatus.offline));
      expect(res.matches, isNotEmpty);
      expect(res.latencyMs, lessThan(50.0));
    });
  });
}
