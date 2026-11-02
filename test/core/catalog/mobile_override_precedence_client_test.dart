// test/core/catalog/mobile_override_precedence_client_test.dart
// Architecture Decision: ADR-0128 (P128)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_override_precedence_client.dart';

void main() {
  group('P128 Mobile Override Precedence Client Tests', () {
    late MobileOverridePrecedenceClient client;

    setUp(() {
      client = MobileOverridePrecedenceClient();

      // Master 1: Napa 500mg (OTC, standard MRP 1.20 BDT)
      client.registerMaster(const MobileMasterMedicine(
        productId: 'prod-napa-500',
        brandName: 'Napa 500mg',
        genericName: 'Paracetamol',
        dosageForm: 'Tablet',
        strength: '500mg',
        mrpUnit: 1.20,
        costUnit: 0.90,
        isPrescriptionOnly: false,
      ));

      // Master 2: Seclo 20mg (Prescription-only POM, standard MRP 6.00 BDT)
      client.registerMaster(const MobileMasterMedicine(
        productId: 'prod-seclo-20',
        brandName: 'Seclo 20mg',
        genericName: 'Omeprazole',
        dosageForm: 'Capsule',
        strength: '20mg',
        mrpUnit: 6.00,
        costUnit: 4.80,
        isPrescriptionOnly: true,
      ));
    });

    test('P128-M1: Master values take effect when no tenant override exists', () {
      final res = client.resolvePrecedence(
        callerTenantId: 'tenant-uttara',
        targetTenantId: 'tenant-uttara',
        productId: 'prod-napa-500',
        isOnline: true,
      );

      expect(res.status, equals(MobilePrecedenceUiStatus.success));
      expect(res.data, isNotNull);
      expect(res.data!.effectiveBrandName, equals('Napa 500mg'));
      expect(res.data!.effectiveMrpUnit, equals(1.20));
      expect(res.data!.isOverridden, isFalse);
      expect(res.data!.provenance['brand_name']!.source, equals('GLOBAL_MASTER'));
      expect(res.data!.provenance['mrp_unit']!.source, equals('GLOBAL_MASTER'));
      expect(res.data!.provenance['mrp_unit']!.rule, equals('MASTER_DEFAULT'));
    });

    test('P128-M2: Approved tenant brand and MRP override take precedence', () {
      final res = client.proposeOverride(
        callerTenantId: 'tenant-uttara',
        targetTenantId: 'tenant-uttara',
        userRole: 'PHARMACY_OWNER',
        productId: 'prod-napa-500',
        localBrandName: 'নাপা ৫০০ মিগ্রা (উত্তরা ব্রাঞ্চ)',
        customMrp: 1.50,
      );

      expect(res.status, equals(MobilePrecedenceUiStatus.success));
      expect(res.data, isNotNull);
      expect(res.data!.effectiveBrandName, equals('নাপা ৫০০ মিগ্রা (উত্তরা ব্রাঞ্চ)'));
      expect(res.data!.effectiveMrpUnit, equals(1.50));
      expect(res.data!.isOverridden, isTrue);
      expect(res.data!.moderationStatus, equals('APPROVED'));
      expect(res.data!.provenance['brand_name']!.source, equals('TENANT_OVERRIDE'));
      expect(res.data!.provenance['mrp_unit']!.source, equals('TENANT_OVERRIDE'));
    });

    test('P128-M3: Excessive price hike (>50%) is placed in PENDING_REVIEW and falls back to GLOBAL_MASTER MRP', () {
      // Master is 1.20. Propose 3.00 (> 1.20 * 1.50 = 1.80)
      final res = client.proposeOverride(
        callerTenantId: 'tenant-uttara',
        targetTenantId: 'tenant-uttara',
        userRole: 'BRANCH_MANAGER',
        productId: 'prod-napa-500',
        localBrandName: 'Napa Premium',
        customMrp: 3.00,
      );

      expect(res.status, equals(MobilePrecedenceUiStatus.success));
      expect(res.data, isNotNull);
      expect(res.data!.isOverridden, isTrue);
      expect(res.data!.moderationStatus, equals('PENDING_REVIEW'));
      // Precedence fallback to canonical master MRP 1.20
      expect(res.data!.effectiveMrpUnit, equals(1.20));
      expect(res.data!.provenance['mrp_unit']!.source, equals('GLOBAL_MASTER'));
      expect(res.data!.provenance['mrp_unit']!.rule, equals('MODERATION_PENDING_FALLBACK'));
    });

    test('P128-M4: Regulatory prescription non-relaxation is strictly rejected', () {
      final res = client.proposeOverride(
        callerTenantId: 'tenant-uttara',
        targetTenantId: 'tenant-uttara',
        userRole: 'PHARMACY_OWNER',
        productId: 'prod-seclo-20',
        localBrandName: 'Seclo OTC',
        customMrp: 6.00,
        requiresPrescriptionOverride: false, // Attempt to relax POM
      );

      expect(res.status, equals(MobilePrecedenceUiStatus.error));
      expect(res.errorCode, equals('ERR_REGULATORY_RELAXATION_FORBIDDEN'));
    });

    test('P128-M5: Cashier role is denied override mutation with ERR_STAFF_ROLE_DENIED', () {
      final res = client.proposeOverride(
        callerTenantId: 'tenant-uttara',
        targetTenantId: 'tenant-uttara',
        userRole: 'CASHIER',
        productId: 'prod-napa-500',
        localBrandName: 'Cashier Napa',
        customMrp: 1.30,
      );

      expect(res.status, equals(MobilePrecedenceUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_STAFF_ROLE_DENIED'));
    });

    test('P128-M6: Cross-tenant resolution or mutation is denied with ERR_CROSS_TENANT_ACCESS', () {
      final res = client.resolvePrecedence(
        callerTenantId: 'tenant-mirpur',
        targetTenantId: 'tenant-uttara', // Foreign tenant
        productId: 'prod-napa-500',
        isOnline: true,
      );

      expect(res.status, equals(MobilePrecedenceUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_CROSS_TENANT_ACCESS'));
    });
  });
}
