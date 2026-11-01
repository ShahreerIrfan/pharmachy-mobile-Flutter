import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_medicine_config_client.dart';

void main() {
  group('ADR-0071: Mobile Tenant-Specific Medicine Configuration Client Tests', () {
    test('authorizes store leadership roles; strictly bars cashiers from mutation', () {
      expect(MobileTenantMedicineConfigClient.canRoleModifyTenantConfig('SUPERADMIN'), isTrue);
      expect(MobileTenantMedicineConfigClient.canRoleModifyTenantConfig('PHARMACY_OWNER'), isTrue);
      expect(MobileTenantMedicineConfigClient.canRoleModifyTenantConfig('BRANCH_MANAGER'), isTrue);
      expect(MobileTenantMedicineConfigClient.canRoleModifyTenantConfig('STAFF_PHARMACIST'), isTrue);

      expect(MobileTenantMedicineConfigClient.canRoleModifyTenantConfig('CASHIER'), isFalse);
      expect(MobileTenantMedicineConfigClient.canRoleModifyTenantConfig('UNAUTHORIZED'), isFalse);
      expect(MobileTenantMedicineConfigClient.canRoleModifyTenantConfig(null), isFalse);
    });

    test('resolves effective brand name with local override fallback', () {
      expect(MobileTenantMedicineConfigClient.resolveEffectiveBrandName('নাপা ৫০০', 'Napa'), 'নাপা ৫০০');
      expect(MobileTenantMedicineConfigClient.resolveEffectiveBrandName('', 'Napa'), 'Napa');
      expect(MobileTenantMedicineConfigClient.resolveEffectiveBrandName(null, 'Napa'), 'Napa');
    });

    test('resolves effective retail price with custom MRP fallback', () {
      expect(MobileTenantMedicineConfigClient.resolveEffectivePrice('3.50', '2.50'), '3.50');
      expect(MobileTenantMedicineConfigClient.resolveEffectivePrice('', '2.50'), '2.50');
      expect(MobileTenantMedicineConfigClient.resolveEffectivePrice(null, '2.50'), '2.50');
    });

    test('preserves global DGDA POM/narcotic/antibiotic mandatory prescription rule', () {
      // 1. Master POM -> Always True
      expect(
        MobileTenantMedicineConfigClient.isPrescriptionMandatory(
          masterPom: true,
          tenantOverride: false,
        ),
        isTrue,
      );
      // 2. Master Narcotic -> Always True
      expect(
        MobileTenantMedicineConfigClient.isPrescriptionMandatory(
          masterNarcotic: true,
          tenantOverride: false,
        ),
        isTrue,
      );
      // 3. Master Antibiotic -> Always True
      expect(
        MobileTenantMedicineConfigClient.isPrescriptionMandatory(
          masterAntibiotic: true,
          tenantOverride: false,
        ),
        isTrue,
      );
      // 4. Master OTC with strict tenant override -> True
      expect(
        MobileTenantMedicineConfigClient.isPrescriptionMandatory(
          masterPom: false,
          tenantOverride: true,
        ),
        isTrue,
      );
      // 5. Master OTC without override -> False
      expect(
        MobileTenantMedicineConfigClient.isPrescriptionMandatory(
          masterPom: false,
          tenantOverride: false,
        ),
        isFalse,
      );
    });

    test('validates custom MRP bounds', () {
      expect(MobileTenantMedicineConfigClient.isValidCustomMrp('0.01'), isTrue);
      expect(MobileTenantMedicineConfigClient.isValidCustomMrp('45.50'), isTrue);
      expect(MobileTenantMedicineConfigClient.isValidCustomMrp(''), isTrue);
      expect(MobileTenantMedicineConfigClient.isValidCustomMrp(null), isTrue);

      expect(MobileTenantMedicineConfigClient.isValidCustomMrp('0.00'), isFalse);
      expect(MobileTenantMedicineConfigClient.isValidCustomMrp('-2.00'), isFalse);
      expect(MobileTenantMedicineConfigClient.isValidCustomMrp('not-a-number'), isFalse);
    });

    test('builds browse and detail endpoint URLs with validation guardrails', () {
      expect(
        MobileTenantMedicineConfigClient.buildConfigListUrl(
          page: 1,
          pageSize: 20,
          search: 'Napa',
          isVisible: true,
        ),
        '/api/v2/tenants/medicine-configs/?page=1&page_size=20&search=Napa&is_visible=true',
      );
      expect(
        MobileTenantMedicineConfigClient.buildConfigListUrl(page: 0, pageSize: 0),
        '/api/v2/tenants/medicine-configs/?page=1&page_size=20',
      );
      expect(
        MobileTenantMedicineConfigClient.buildConfigByProductUrl('prod-napa-500'),
        '/api/v2/tenants/medicine-configs/by-product/prod-napa-500/',
      );
      expect(
        MobileTenantMedicineConfigClient.buildConfigDetailUrl('tmc-12345678'),
        '/api/v2/tenants/medicine-configs/tmc-12345678/',
      );

      expect(
        () => MobileTenantMedicineConfigClient.buildConfigByProductUrl('bad id!'),
        throwsArgumentError,
      );
      expect(
        () => MobileTenantMedicineConfigClient.buildConfigDetailUrl('bad config!'),
        throwsArgumentError,
      );
    });
  });
}

