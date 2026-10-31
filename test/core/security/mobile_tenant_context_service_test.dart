import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_context_service.dart';

void main() {
  group('P049: Mobile Manager Tenant Context & Trusted Claims Tests', () {
    setUp(() {
      MobileTenantContextService.clear();
    });

    test(
        '1. Parses server context response into MobileTenantContext with claims',
        () {
      final json = {
        'tenant_id': 'tenant-dhanmondi-care',
        'tenant_name': 'Dhanmondi Care Pharmacy',
        'subdomain': 'dhanmondi-care',
        'plan_tier': 'PRO',
        'branch_id': 'b-dhanmondi-01',
        'branch_name': 'Main Branch',
        'user_id': 'usr-uuid-1234',
        'user_role': 'PHARMACY_OWNER',
        'resolution_source': 'JWT_SIGNED_CLAIMS',
        'is_active': true,
      };

      final context = MobileTenantContext.fromJson(json);

      expect(context.tenantId, 'tenant-dhanmondi-care');
      expect(context.tenantName, 'Dhanmondi Care Pharmacy');
      expect(context.subdomain, 'dhanmondi-care');
      expect(context.planTier, 'PRO');
      expect(context.branchId, 'b-dhanmondi-01');
      expect(context.branchName, 'Main Branch');
      expect(context.userId, 'usr-uuid-1234');
      expect(context.userRole, 'PHARMACY_OWNER');
      expect(context.resolutionSource, 'JWT_SIGNED_CLAIMS');
      expect(context.isActive, true);
    });

    test(
        '2. Validates tenant integrity: matching succeeds, foreign tenant rejected',
        () {
      const context = MobileTenantContext(
        tenantId: 'tenant-dhanmondi-care',
        tenantName: 'Dhanmondi Care Pharmacy',
        subdomain: 'dhanmondi-care',
        planTier: 'STANDARD',
      );

      expect(
        MobileTenantContextService.validateTenantIntegrity(
          context: context,
          requestedTenantId: 'tenant-dhanmondi-care',
        ),
        true,
      );
      expect(
        MobileTenantContextService.validateTenantIntegrity(
          context: context,
          requestedTenantId: 'tenant-uttara-pharma',
        ),
        false,
      );
    });

    test('3. Validates branch integrity against active tenant context', () {
      const context = MobileTenantContext(
        tenantId: 'tenant-dhanmondi-care',
        tenantName: 'Dhanmondi Care Pharmacy',
        subdomain: 'dhanmondi-care',
        planTier: 'STANDARD',
        branchId: 'b-dhanmondi-01',
      );

      expect(
        MobileTenantContextService.validateBranchIntegrity(
          context: context,
          requestedBranchId: 'b-dhanmondi-01',
        ),
        true,
      );
      expect(
        MobileTenantContextService.validateBranchIntegrity(
          context: context,
          requestedBranchId: 'b-uttara-01',
        ),
        false,
      );
    });

    test(
        '4. Bilingual error message resolution for cross-tenant and inactive tenant',
        () {
      final crossTenantMsg =
          MobileTenantContextService.getBilingualErrorMessage(
              'ERR_CROSS_TENANT_VIOLATION');
      expect(crossTenantMsg['en'], contains('Cross-tenant access violation'));
      expect(
          crossTenantMsg['bn'], contains('অন্য ফার্মেসির তথ্যে প্রবেশাধিকার'));

      final inactiveMsg = MobileTenantContextService.getBilingualErrorMessage(
          'ERR_TENANT_INACTIVE');
      expect(inactiveMsg['en'], contains('inactive or suspended'));
      expect(inactiveMsg['bn'], contains('নিষ্ক্রিয় বা স্থগিত'));
    });

    test('5. Maps security error codes to MobileUiState.permissionDenied', () {
      expect(
        MobileTenantContextService.resolveUiState('ERR_CROSS_TENANT_VIOLATION'),
        MobileUiState.permissionDenied,
      );
      expect(
        MobileTenantContextService.resolveUiState('ERR_TENANT_INACTIVE'),
        MobileUiState.permissionDenied,
      );
      expect(
        MobileTenantContextService.resolveUiState('ERR_BRANCH_NOT_FOUND'),
        MobileUiState.permissionDenied,
      );
      expect(
        MobileTenantContextService.resolveUiState('ERR_GENERIC'),
        MobileUiState.error,
      );
    });
  });
}
