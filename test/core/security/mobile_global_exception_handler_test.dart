import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_global_exception_handler.dart';

void main() {
  group('P054: Flutter Mobile Global Exception Handler Tests (ADR-0054)', () {
    test(
        '1. Resolves validation error to MobileUiState.error with field details',
        () {
      final json = {
        'success': false,
        'code': 'ERR_VALIDATION_FAILED',
        'error_code': 'ERR_VALIDATION_FAILED',
        'request_id': 'req-mobile-val-01',
        'timestamp': '2026-10-31T15:30:00Z',
        'http_status': 422,
        'retryable': false,
        'recovery_action': 'CORRECT_INPUT_FIELDS',
        'message_en': 'One or more input fields failed validation.',
        'message_bn': 'এক বা একাধিক তথ্যের মান সঠিক নয়।',
        'field_errors': {
          'dispense_quantity': ['Quantity must be positive.']
        }
      };

      final envelope =
          MobileApiResponseEnvelope.fromErrorJson(json, statusCode: 422);
      final resolvedBn = MobileGlobalExceptionHandler.resolveEnvelope(envelope,
          language: 'bn');

      expect(resolvedBn.uiState, MobileUiState.error);
      expect(resolvedBn.errorCode, 'ERR_VALIDATION_FAILED');
      expect(resolvedBn.requestId, 'req-mobile-val-01');
      expect(resolvedBn.httpStatus, 422);
      expect(resolvedBn.isRetryable, false);
      expect(resolvedBn.recoveryAction, 'CORRECT_INPUT_FIELDS');
      expect(resolvedBn.localizedMessage, contains('সঠিক নয়'));
      expect(resolvedBn.fieldErrors.containsKey('dispense_quantity'), true);

      final resolvedEn = MobileGlobalExceptionHandler.resolveEnvelope(envelope,
          language: 'en');
      expect(resolvedEn.localizedMessage, contains('failed validation'));
    });

    test(
        '2. Resolves cross-tenant and unauthorized to MobileUiState.permissionDenied',
        () {
      final crossTenantJson = {
        'success': false,
        'code': 'ERR_CROSS_TENANT_VIOLATION',
        'request_id': 'req-cross-02',
        'timestamp': '2026-10-31T15:30:00Z',
        'http_status': 403,
        'retryable': false,
        'recovery_action': 'ABORT_SECURITY_INCIDENT',
        'message_en':
            'Access to foreign pharmacy tenant resources is strictly forbidden.',
        'message_bn': 'অন্য ফার্মেসির তথ্যে প্রবেশাধিকার কঠোরভাবে নিষিদ্ধ।',
      };

      final envelope = MobileApiResponseEnvelope.fromErrorJson(crossTenantJson,
          statusCode: 403);
      final resolved = MobileGlobalExceptionHandler.resolveEnvelope(envelope,
          language: 'bn');

      expect(resolved.uiState, MobileUiState.permissionDenied);
      expect(resolved.errorCode, 'ERR_CROSS_TENANT_VIOLATION');
      expect(resolved.localizedMessage, contains('অন্য ফার্মেসির তথ্যে'));

      final rawAuth = MobileGlobalExceptionHandler.resolveRawHttp(401,
          language: 'en', requestId: 'req-auth');
      expect(rawAuth.uiState, MobileUiState.permissionDenied);
      expect(rawAuth.errorCode, 'ERR_UNAUTHORIZED');
    });

    test(
        '3. Resolves database integrity conflict to MobileUiState.error with safe description',
        () {
      final json = {
        'success': false,
        'code': 'ERR_DATABASE_INTEGRITY',
        'request_id': 'req-db-03',
        'timestamp': '2026-10-31T15:30:00Z',
        'http_status': 409,
        'retryable': false,
        'recovery_action': 'CORRECT_INPUT_FIELDS',
        'message_en':
            'A database integrity constraint or duplicate record conflict occurred.',
        'message_bn':
            'একটি ডেটাবেজ ইন্টিগ্রিটি বা ডুপ্লিকেট রেকর্ড দ্বন্দ্ব তৈরি হয়েছে।',
      };

      final envelope =
          MobileApiResponseEnvelope.fromErrorJson(json, statusCode: 409);
      final resolved = MobileGlobalExceptionHandler.resolveEnvelope(envelope,
          language: 'bn');

      expect(resolved.uiState, MobileUiState.error);
      expect(resolved.errorCode, 'ERR_DATABASE_INTEGRITY');
      expect(resolved.isRetryable, false);
      expect(resolved.localizedMessage, contains('ডেটাবেজ ইন্টিগ্রিটি'));
    });

    test(
        '4. Resolves database unavailable to MobileUiState.offline with retryable flag',
        () {
      final json = {
        'success': false,
        'code': 'ERR_DATABASE_UNAVAILABLE',
        'request_id': 'req-db-04',
        'timestamp': '2026-10-31T15:30:00Z',
        'http_status': 503,
        'retryable': true,
        'recovery_action': 'RETRY_AFTER_BACKOFF',
        'message_en':
            'Database service is temporarily unavailable or locked. Safe to retry.',
        'message_bn':
            'ডেটাবেজ সেবা সাময়িকভাবে অনুপলব্ধ বা লক করা আছে। কিছুক্ষণ পর পুনরায় চেষ্টা করুন।',
      };

      final envelope =
          MobileApiResponseEnvelope.fromErrorJson(json, statusCode: 503);
      final resolved = MobileGlobalExceptionHandler.resolveEnvelope(envelope,
          language: 'en');

      expect(resolved.uiState, MobileUiState.offline);
      expect(resolved.errorCode, 'ERR_DATABASE_UNAVAILABLE');
      expect(resolved.isRetryable, true);
      expect(resolved.recoveryAction, 'RETRY_AFTER_BACKOFF');
    });

    test(
        '5. Resolves unhandled internal server error preserving correlation ID',
        () {
      final json = {
        'success': false,
        'code': 'ERR_INTERNAL_SERVER_ERROR',
        'request_id': 'req-trace-9999',
        'timestamp': '2026-10-31T15:30:00Z',
        'http_status': 500,
        'retryable': false,
        'recovery_action': 'RETRY_AFTER_BACKOFF',
        'message_en':
            'An internal server error occurred. Please contact support with the request ID.',
        'message_bn':
            'একটি অভ্যন্তরীণ সমস্যা দেখা দিয়েছে। অনুগ্রহ করে রিকোয়েস্ট আইডি সহ সাপোর্ট টিমের সাথে যোগাযোগ করুন।',
      };

      final envelope =
          MobileApiResponseEnvelope.fromErrorJson(json, statusCode: 500);
      final resolved = MobileGlobalExceptionHandler.resolveEnvelope(envelope,
          language: 'bn');

      expect(resolved.uiState, MobileUiState.error);
      expect(resolved.errorCode, 'ERR_INTERNAL_SERVER_ERROR');
      expect(resolved.requestId, 'req-trace-9999');
      expect(resolved.localizedMessage, contains('সাপোর্ট টিমের'));
      expect(resolved.fieldErrors.isEmpty, true);
    });
  });
}
