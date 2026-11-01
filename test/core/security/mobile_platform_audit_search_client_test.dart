import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_platform_audit_search_client.dart';

void main() {
  group('ADR-0078: Flutter Mobile Platform Audit Search Client Tests', () {
    test('Role RBAC: Platform Roles Allowed, Tenant Roles Strictly Denied', () {
      expect(MobilePlatformAuditSearchClient.canSearchPlatformAudit('SUPERADMIN'), isTrue);
      expect(MobilePlatformAuditSearchClient.canSearchPlatformAudit('SUPER_ADMIN'), isTrue);
      expect(MobilePlatformAuditSearchClient.canSearchPlatformAudit('PLATFORM_OPERATOR'), isTrue);
      expect(MobilePlatformAuditSearchClient.canSearchPlatformAudit('PLATFORM_AUDITOR'), isTrue);

      expect(MobilePlatformAuditSearchClient.canSearchPlatformAudit('PHARMACY_OWNER'), isFalse);
      expect(MobilePlatformAuditSearchClient.canSearchPlatformAudit('BRANCH_MANAGER'), isFalse);
      expect(MobilePlatformAuditSearchClient.canSearchPlatformAudit('STAFF_PHARMACIST'), isFalse);
      expect(MobilePlatformAuditSearchClient.canSearchPlatformAudit('CASHIER'), isFalse);
      expect(MobilePlatformAuditSearchClient.canSearchPlatformAudit(null), isFalse);
    });

    test('Forbidden Payload Key Detection', () {
      expect(MobilePlatformAuditSearchClient.isForbiddenPayloadKey('password'), isTrue);
      expect(MobilePlatformAuditSearchClient.isForbiddenPayloadKey('secret_key'), isTrue);
      expect(MobilePlatformAuditSearchClient.isForbiddenPayloadKey('access_token'), isTrue);
      expect(MobilePlatformAuditSearchClient.isForbiddenPayloadKey('otp'), isTrue);
      expect(MobilePlatformAuditSearchClient.isForbiddenPayloadKey('bkash_pin'), isTrue);
      expect(MobilePlatformAuditSearchClient.isForbiddenPayloadKey('clinical_notes'), isTrue);

      expect(MobilePlatformAuditSearchClient.isForbiddenPayloadKey('user_id'), isFalse);
      expect(MobilePlatformAuditSearchClient.isForbiddenPayloadKey('tenant_id'), isFalse);
      expect(MobilePlatformAuditSearchClient.isForbiddenPayloadKey('action'), isFalse);
    });

    test('Payload Sanitization: Masks forbidden keys with [REDACTED]', () {
      final raw = <String, dynamic>{
        'action': 'LOGIN_ATTEMPT',
        'user_id': 'usr-1',
        'password': 'RawPassword123!',
        'otp': '123456',
        'meta': <String, dynamic>{
          'secret': 'jwt-secret',
          'client': 'flutter-app',
        },
      };

      final sanitized = MobilePlatformAuditSearchClient.sanitizePayload(raw);

      expect(sanitized['action'], equals('LOGIN_ATTEMPT'));
      expect(sanitized['user_id'], equals('usr-1'));
      expect(sanitized['password'], equals('[REDACTED]'));
      expect(sanitized['otp'], equals('[REDACTED]'));

      final nested = sanitized['meta'] as Map<String, dynamic>;
      expect(nested['secret'], equals('[REDACTED]'));
      expect(nested['client'], equals('flutter-app'));
    });

    test('Date Range Validation', () {
      expect(
        MobilePlatformAuditSearchClient.validateDateRange(
          '2026-11-01T00:00:00Z',
          '2026-11-01T12:00:00Z',
        ),
        isTrue,
      );

      expect(
        MobilePlatformAuditSearchClient.validateDateRange(
          '2026-11-02T00:00:00Z',
          '2026-11-01T00:00:00Z',
        ),
        isFalse,
      );

      expect(
        MobilePlatformAuditSearchClient.validateDateRange('bad-date', '2026-11-01T00:00:00Z'),
        isFalse,
      );
    });

    test('URL Builders and Entry ID Validation', () {
      const validId = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
      expect(MobilePlatformAuditSearchClient.isValidEntryId(validId), isTrue);
      expect(MobilePlatformAuditSearchClient.isValidEntryId('bad-id'), isFalse);

      expect(MobilePlatformAuditSearchClient.getSearchUrl(), equals('/api/v2/platform/audit-search/'));
      expect(MobilePlatformAuditSearchClient.getDetailUrl(validId), equals('/api/v2/platform/audit-search/$validId/'));
      expect(MobilePlatformAuditSearchClient.getExportUrl(), equals('/api/v2/platform/audit-search/export/'));
    });

    test('UI Boundary Invariant: Platform audit search never visible in mobile app', () {
      expect(MobilePlatformAuditSearchClient.isAuditSearchVisibleInMobile(), isFalse);
    });
  });
}
