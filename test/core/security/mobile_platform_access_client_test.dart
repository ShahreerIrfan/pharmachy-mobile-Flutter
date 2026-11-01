import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_platform_access_client.dart';

void main() {
  group('ADR-0077: Flutter Mobile Platform Access Client Tests', () {
    test('Role RBAC: Platform Roles Allowed, Tenant Roles Strictly Denied', () {
      expect(MobilePlatformAccessClient.canAccessPlatformApis('SUPERADMIN'), isTrue);
      expect(MobilePlatformAccessClient.canAccessPlatformApis('SUPER_ADMIN'), isTrue);
      expect(MobilePlatformAccessClient.canAccessPlatformApis('PLATFORM_OPERATOR'), isTrue);
      expect(MobilePlatformAccessClient.canAccessPlatformApis('PLATFORM_AUDITOR'), isTrue);

      expect(MobilePlatformAccessClient.canAccessPlatformApis('PHARMACY_OWNER'), isFalse);
      expect(MobilePlatformAccessClient.canAccessPlatformApis('BRANCH_MANAGER'), isFalse);
      expect(MobilePlatformAccessClient.canAccessPlatformApis('STAFF_PHARMACIST'), isFalse);
      expect(MobilePlatformAccessClient.canAccessPlatformApis('CASHIER'), isFalse);
      expect(MobilePlatformAccessClient.canAccessPlatformApis(null), isFalse);
    });

    test('Least Privilege: Only SuperAdmin can mutate security policies', () {
      expect(MobilePlatformAccessClient.canMutateSecurityPolicies('SUPERADMIN'), isTrue);
      expect(MobilePlatformAccessClient.canMutateSecurityPolicies('PLATFORM_OPERATOR'), isFalse);
      expect(MobilePlatformAccessClient.canMutateSecurityPolicies('PLATFORM_AUDITOR'), isFalse);
      expect(MobilePlatformAccessClient.canMutateSecurityPolicies('CASHIER'), isFalse);
    });

    test('Zero Implicit Tenant Access: Platform Admin Blocked without Support Grant', () {
      expect(
        () => MobilePlatformAccessClient.enforceZeroImplicitTenantAccess(
          role: 'SUPERADMIN',
          targetPath: '/api/v2/tenants/t-1/orders/',
          supportGrantToken: null,
        ),
        throwsA(isA<PlatformPolicySecurityException>()),
      );

      expect(
        MobilePlatformAccessClient.enforceZeroImplicitTenantAccess(
          role: 'SUPERADMIN',
          targetPath: '/api/v2/tenants/t-1/orders/',
          supportGrantToken: 'valid-grant-token',
        ),
        isTrue,
      );

      expect(
        MobilePlatformAccessClient.enforceZeroImplicitTenantAccess(
          role: 'SUPERADMIN',
          targetPath: '/api/v2/tenants/announcements/',
          supportGrantToken: null,
        ),
        isTrue,
      );
    });

    test('Syntax Validation: Policy ID and TOTP Codes', () {
      expect(MobilePlatformAccessClient.isValidPolicyId('pol-security-123'), isTrue);
      expect(MobilePlatformAccessClient.isValidPolicyId('invalid-pol'), isFalse);
      expect(MobilePlatformAccessClient.isValidPolicyId(null), isFalse);

      expect(MobilePlatformAccessClient.isValidTotpCode('123456'), isTrue);
      expect(MobilePlatformAccessClient.isValidTotpCode('12345'), isFalse);
      expect(MobilePlatformAccessClient.isValidTotpCode('abcdef'), isFalse);
    });

    test('Header Builder: Builds headers with MFA and step-up codes', () {
      final headers = MobilePlatformAccessClient.buildPlatformHeaders(
        role: 'SUPERADMIN',
        mfaSessionToken: 'session-token-abc',
        stepUpCode: '654321',
        supportGrantToken: 'grant-token-xyz',
      );

      expect(headers['X-Platform-Role'], equals('SUPERADMIN'));
      expect(headers['X-MFA-Session-Token'], equals('session-token-abc'));
      expect(headers['X-MFA-Verified'], equals('true'));
      expect(headers['X-MFA-Code'], equals('654321'));
      expect(headers['X-Support-Grant-Token'], equals('grant-token-xyz'));

      expect(
        () => MobilePlatformAccessClient.buildPlatformHeaders(role: 'CASHIER'),
        throwsA(isA<PlatformPolicySecurityException>()),
      );
    });

    test('UI Boundary Invariant: Platform policy controls never visible in Mobile Manager', () {
      expect(MobilePlatformAccessClient.isPlatformPolicyManagerVisibleInMobile(), isFalse);
    });
  });
}
