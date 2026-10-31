import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_audit_event_service.dart';

void main() {
  group('P050: Mobile Manager Audit Event Foundation & Immutability Tests', () {
    test('1. Parses server audit event with before/after state and retention',
        () {
      final json = {
        'entry_id': '89b21f98-4444-4cb4-a14a-f3d6dbf43c32',
        'timestamp': '2026-10-31T08:00:00Z',
        'tenant_id': 'tenant-dhanmondi-care',
        'branch_id': 'b-dhanmondi-01',
        'user_id': 'usr-owner-01',
        'actor_email': 'owner@dhanmondi.com',
        'actor_role': 'PHARMACY_OWNER',
        'device_id': 'mobile-iphone-15',
        'action': 'STAFF_ROLE_CHANGE',
        'resource_type': 'PHARMACY_USER',
        'resource_id': 'usr-cashier-02',
        'status': 'SUCCESS',
        'before_state': {'role': 'CASHIER'},
        'after_state': {'role': 'STAFF_PHARMACIST'},
        'retention_until': '2028-10-31T08:00:00Z',
        'is_immutable': true,
      };

      final event = MobileAuditEvent.fromJson(json);

      expect(event.entryId, '89b21f98-4444-4cb4-a14a-f3d6dbf43c32');
      expect(event.tenantId, 'tenant-dhanmondi-care');
      expect(event.actorRole, 'PHARMACY_OWNER');
      expect(event.action, 'STAFF_ROLE_CHANGE');
      expect(event.beforeState['role'], 'CASHIER');
      expect(event.afterState['role'], 'STAFF_PHARMACIST');
      expect(event.retentionUntil, '2028-10-31T08:00:00Z');
      expect(event.isImmutable, true);
    });

    test(
        '2. Role-based audit query authorization: permits Owner/Auditor, denies Cashier',
        () {
      expect(
          MobileAuditEventService.isAuthorizedAuditor('PHARMACY_OWNER'), true);
      expect(
          MobileAuditEventService.isAuthorizedAuditor('BRANCH_MANAGER'), true);
      expect(MobileAuditEventService.isAuthorizedAuditor('AUDITOR'), true);
      expect(MobileAuditEventService.isAuthorizedAuditor('COMPLIANCE_OFFICER'),
          true);
      expect(MobileAuditEventService.isAuthorizedAuditor('SUPERADMIN'), true);
      expect(MobileAuditEventService.isAuthorizedAuditor('CASHIER'), false);
      expect(MobileAuditEventService.isAuthorizedAuditor('INVENTORY_CLERK'),
          false);
    });

    test(
        '3. Validates event integrity: valid passes, blank action/tenant fails',
        () {
      const validEvent = MobileAuditEvent(
        entryId: 'ev-1',
        timestamp: '2026-10-31T08:00:00Z',
        tenantId: 'tenant-dhanmondi-care',
        actorRole: 'PHARMACY_OWNER',
        action: 'INVOICE_VOID',
        resourceType: 'SALE_INVOICE',
      );
      expect(MobileAuditEventService.validateEvent(validEvent), true);

      const invalidEvent = MobileAuditEvent(
        entryId: 'ev-2',
        timestamp: '2026-10-31T08:00:00Z',
        tenantId: '',
        actorRole: 'PHARMACY_OWNER',
        action: '',
        resourceType: 'SALE_INVOICE',
      );
      expect(MobileAuditEventService.validateEvent(invalidEvent), false);
    });

    test(
        '4. Bilingual error message resolution for immutability and permission',
        () {
      final immutabilityMsg = MobileAuditEventService.getBilingualErrorMessage(
          'ERR_AUDIT_IMMUTABLE');
      expect(immutabilityMsg['en'], contains('immutable and append-only'));
      expect(immutabilityMsg['bn'], contains('অডিট লগ রেকর্ড অপরিবর্তনযোগ্য'));

      final permMsg = MobileAuditEventService.getBilingualErrorMessage(
          'ERR_PERMISSION_DENIED');
      expect(permMsg['en'], contains('Manager or Owner privileges'));
      expect(permMsg['bn'], contains('ম্যানেজার বা মালিকের অনুমতি'));
    });

    test('5. Maps audit error codes to MobileUiState.permissionDenied', () {
      expect(
        MobileAuditEventService.resolveUiState('ERR_AUDIT_IMMUTABLE'),
        MobileUiState.permissionDenied,
      );
      expect(
        MobileAuditEventService.resolveUiState('ERR_CROSS_TENANT_VIOLATION'),
        MobileUiState.permissionDenied,
      );
      expect(
        MobileAuditEventService.resolveUiState('ERR_PERMISSION_DENIED'),
        MobileUiState.permissionDenied,
      );
      expect(
        MobileAuditEventService.resolveUiState('ERR_SERVER'),
        MobileUiState.error,
      );
    });
  });
}
