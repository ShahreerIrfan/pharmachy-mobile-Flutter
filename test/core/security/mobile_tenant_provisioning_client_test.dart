import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_provisioning_client.dart';

void main() {
  group('ADR-0062: Mobile Tenant Provisioning Client Tests', () {
    test('validates valid subdomains and blocks reserved names', () {
      expect(MobileTenantProvisioningClient.isSubdomainValid('greenlife-pharma'), isTrue);
      expect(MobileTenantProvisioningClient.isSubdomainValid('al-madina-01'), isTrue);

      expect(MobileTenantProvisioningClient.isSubdomainValid('admin'), isFalse);
      expect(MobileTenantProvisioningClient.isSubdomainValid('api'), isFalse);
      expect(MobileTenantProvisioningClient.isSubdomainValid('system'), isFalse);
      expect(MobileTenantProvisioningClient.isSubdomainValid('superadmin'), isFalse);
      expect(MobileTenantProvisioningClient.isSubdomainValid('ab'), isFalse);
    });

    test('validates Bangladesh mobile numbers in E.164 format', () {
      expect(MobileTenantProvisioningClient.isOwnerPhoneValid('+8801712345678'), isTrue);
      expect(MobileTenantProvisioningClient.isOwnerPhoneValid('+8801812345678'), isTrue);

      expect(MobileTenantProvisioningClient.isOwnerPhoneValid('01712345678'), isFalse);
      expect(MobileTenantProvisioningClient.isOwnerPhoneValid('+8801112345678'), isFalse);
    });

    test('authorizes only Super Admin roles for tenant provisioning', () {
      expect(MobileTenantProvisioningClient.isProvisioningAuthorized('SUPERADMIN'), isTrue);
      expect(MobileTenantProvisioningClient.isProvisioningAuthorized('PLATFORM_OPERATOR'), isTrue);

      expect(MobileTenantProvisioningClient.isProvisioningAuthorized('PHARMACY_OWNER'), isFalse);
      expect(MobileTenantProvisioningClient.isProvisioningAuthorized('CASHIER'), isFalse);
    });

    test('validates password sufficiency', () {
      expect(MobileTenantProvisioningClient.isPasswordSufficient('SecurePass123'), isTrue);
      expect(MobileTenantProvisioningClient.isPasswordSufficient('short'), isFalse);
      expect(MobileTenantProvisioningClient.isPasswordSufficient(null), isFalse);
    });
  });
}
