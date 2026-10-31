import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_data_privacy_service.dart';

void main() {
  group('P052: Mobile Manager Data Privacy Operations Tests', () {
    test(
        '1. Validates DSR input: accepts valid identifiers and rejects malformed inputs',
        () {
      expect(
          MobileDataPrivacyService.validateRequestInput(
              'PT-99881', 'DATA_EXPORT'),
          isTrue);
      expect(
          MobileDataPrivacyService.validateRequestInput(
              '+8801711223344', 'DATA_CORRECTION'),
          isTrue);
      expect(
          MobileDataPrivacyService.validateRequestInput(
              'PT-DEL-001', 'DATA_DELETION'),
          isTrue);

      // Malformed inputs
      expect(MobileDataPrivacyService.validateRequestInput('AB', 'DATA_EXPORT'),
          isFalse);
      expect(MobileDataPrivacyService.validateRequestInput('', 'DATA_EXPORT'),
          isFalse);
      expect(
          MobileDataPrivacyService.validateRequestInput(
              'PT-99881', 'INVALID_TYPE'),
          isFalse);
    });

    test(
        '2. Role authorization allows Owner/Manager/Auditor and denies Cashier',
        () {
      expect(
          MobileDataPrivacyService.isAuthorizedForPrivacyOperations(
              'PHARMACY_OWNER'),
          isTrue);
      expect(
          MobileDataPrivacyService.isAuthorizedForPrivacyOperations(
              'BRANCH_MANAGER'),
          isTrue);
      expect(
          MobileDataPrivacyService.isAuthorizedForPrivacyOperations('AUDITOR'),
          isTrue);
      expect(
          MobileDataPrivacyService.isAuthorizedForPrivacyOperations(
              'SUPERADMIN'),
          isTrue);

      // Cashiers forbidden
      expect(
          MobileDataPrivacyService.isAuthorizedForPrivacyOperations('CASHIER'),
          isFalse);
      expect(MobileDataPrivacyService.isAuthorizedForPrivacyOperations('GUEST'),
          isFalse);
    });

    test(
        '3. Statutory retention conflict correctly flags active 730-day prescriptions',
        () {
      expect(MobileDataPrivacyService.hasStatutoryRetentionConflict(true, 100),
          isTrue);
      expect(MobileDataPrivacyService.hasStatutoryRetentionConflict(true, 729),
          isTrue);

      // Older than 730 days or no prescriptions
      expect(MobileDataPrivacyService.hasStatutoryRetentionConflict(true, 731),
          isFalse);
      expect(MobileDataPrivacyService.hasStatutoryRetentionConflict(false, 50),
          isFalse);
    });

    test('4. Parses server response JSON into MobilePrivacyRequest model', () {
      final json = {
        'request_id': '550e8400-e29b-41d4-a716-446655440002',
        'tenant_id': 'tenant-dhanmondi-test',
        'branch_id': 'branch-01',
        'subject_type': 'PATIENT',
        'subject_identifier': 'PT-54321',
        'request_type': 'DATA_DELETION',
        'status': 'ANONYMIZED',
        'reason': 'Patient requested erasure',
        'retention_conflict_detected': true,
        'retention_horizon_days': 730,
        'export_artifact_url': '',
        'assessed_by_email': 'owner@dhanmondi.com',
        'assessed_at': '2026-10-31T14:30:00Z',
        'created_at': '2026-10-31T14:00:00Z',
      };

      final req = MobilePrivacyRequest.fromJson(json);
      expect(req.requestId, '550e8400-e29b-41d4-a716-446655440002');
      expect(req.subjectIdentifier, 'PT-54321');
      expect(req.requestType, 'DATA_DELETION');
      expect(req.status, 'ANONYMIZED');
      expect(req.hasRetentionHold, isTrue);
      expect(req.retentionHorizonDays, 730);
    });

    test('5. Error codes map to expected MobileUiState and bilingual messages',
        () {
      expect(
        MobileDataPrivacyService.resolveUiState('ERR_PERMISSION_DENIED'),
        equals(MobileUiState.permissionDenied),
      );
      expect(
        MobileDataPrivacyService.resolveUiState('ERR_CROSS_TENANT_VIOLATION'),
        equals(MobileUiState.permissionDenied),
      );
      expect(
        MobileDataPrivacyService.resolveUiState(
            'ERR_PRIVACY_RETENTION_CONFLICT'),
        equals(MobileUiState.error),
      );

      final conflictMsg = MobileDataPrivacyService.getBilingualErrorMessage(
          'ERR_PRIVACY_RETENTION_CONFLICT');
      expect(conflictMsg['en'], contains('statutory retention'));
      expect(conflictMsg['bn'], contains('রিটেনশন মেয়াদ'));

      final deniedMsg = MobileDataPrivacyService.getBilingualErrorMessage(
          'ERR_PERMISSION_DENIED');
      expect(deniedMsg['en'], contains('Access denied'));
      expect(deniedMsg['bn'], contains('প্রবেশাধিকার প্রত্যাখ্যাত'));
    });
  });
}
