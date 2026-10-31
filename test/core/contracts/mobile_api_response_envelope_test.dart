import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';

void main() {
  group('P047: Mobile Manager API Response Conventions Tests', () {
    test(
        '1. Parses success JSON with pagination metadata, active filters, and request ID',
        () {
      final json = {
        'success': true,
        'code': 'PAGINATED_RESULTS',
        'request_id': 'req-dhk-mob-001',
        'timestamp': '2026-10-31T07:35:00.000Z',
        'data': [
          {'brand_name': 'Napa 500mg', 'mrp': '12.00'},
          {'brand_name': 'Seclo 20mg', 'mrp': '80.00'},
        ],
        'meta': {
          'pagination': {
            'page': 1,
            'page_size': 20,
            'total_count': 48,
            'total_pages': 3,
            'has_next': true,
            'has_previous': false,
            'next_page': 2,
            'previous_page': null,
          },
          'filters': {
            'search': 'Napa',
            'ordering': 'brand_name',
          },
        },
        'message_en': 'Retrieved page 1 of 3 (48 total records).',
        'message_bn':
            'পৃষ্ঠা ১/৩ এর তথ্য সফলভাবে লোড হয়েছে (মোট ৪৮ টি রেকর্ড)।',
      };

      final envelope =
          MobileApiResponseEnvelope<List<Map<String, dynamic>>>.fromSuccessJson(
        json,
        (data) => (data as List).cast<Map<String, dynamic>>(),
      );

      expect(envelope.success, isTrue);
      expect(envelope.code, equals('PAGINATED_RESULTS'));
      expect(envelope.requestId, equals('req-dhk-mob-001'));
      expect(envelope.data!.length, equals(2));
      expect(envelope.pagination, isNotNull);
      expect(envelope.pagination!.page, equals(1));
      expect(envelope.pagination!.totalCount, equals(48));
      expect(envelope.pagination!.totalPages, equals(3));
      expect(envelope.pagination!.hasNext, isTrue);
      expect(envelope.pagination!.hasPrevious, isFalse);
      expect(envelope.pagination!.nextPage, equals(2));
      expect(envelope.pagination!.previousPage, isNull);
      expect(envelope.filters['search'], equals('Napa'));
      expect(envelope.deriveUiState(isOffline: false),
          equals(MobileUiState.success));
    });

    test(
        '2. Parses error JSON with machine error code, field errors, and recovery action',
        () {
      final json = {
        'success': false,
        'error_code': 'ERR_VALIDATION_FAILED',
        'code': 'ERR_VALIDATION_FAILED',
        'request_id': 'req-err-mob-422',
        'http_status': 422,
        'is_retryable': false,
        'message_en': 'One or more input fields failed validation.',
        'message_bn': 'এক বা একাধিক তথ্যের মান সঠিক নয়।',
        'recovery_action': 'CORRECT_INPUT_FIELDS',
        'field_errors': {
          'quantity': ['Quantity must be strictly positive (>0).'],
        },
      };

      final envelope = MobileApiResponseEnvelope<dynamic>.fromErrorJson(json,
          statusCode: 422);

      expect(envelope.success, isFalse);
      expect(envelope.errorCode, equals('ERR_VALIDATION_FAILED'));
      expect(envelope.httpStatus, equals(422));
      expect(envelope.isRetryable, isFalse);
      expect(envelope.recoveryAction, equals('CORRECT_INPUT_FIELDS'));
      expect(envelope.fieldErrors['quantity'],
          contains('Quantity must be strictly positive (>0).'));
      expect(envelope.deriveUiState(isOffline: false),
          equals(MobileUiState.error));
    });

    test(
        '3. Derives correct UI states across OFFLINE, PERMISSION_DENIED, and EMPTY',
        () {
      // Offline state takes priority
      final successEnv = MobileApiResponseEnvelope<String>(
        success: true,
        code: 'OK',
        requestId: 'req-01',
        timestamp: DateTime.now().toIso8601String(),
        data: 'DATA',
        messageEn: 'OK',
        messageBn: 'ঠিক আছে',
      );
      expect(successEnv.deriveUiState(isOffline: true),
          equals(MobileUiState.offline));

      // Permission denied state on 403
      final forbiddenEnv = MobileApiResponseEnvelope<void>(
        success: false,
        code: 'ERR_PERMISSION_DENIED',
        errorCode: 'ERR_PERMISSION_DENIED',
        requestId: 'req-02',
        timestamp: DateTime.now().toIso8601String(),
        httpStatus: 403,
        messageEn: 'Access denied.',
        messageBn: 'প্রবেশাধিকার নিষিদ্ধ।',
      );
      expect(forbiddenEnv.deriveUiState(isOffline: false),
          equals(MobileUiState.permissionDenied));

      // Empty state on zero total count
      final emptyEnv = MobileApiResponseEnvelope<List<dynamic>>(
        success: true,
        code: 'PAGINATED_RESULTS',
        requestId: 'req-03',
        timestamp: DateTime.now().toIso8601String(),
        data: [],
        pagination: const MobilePaginationMeta(
          page: 1,
          pageSize: 20,
          totalCount: 0,
          totalPages: 0,
          hasNext: false,
          hasPrevious: false,
        ),
        messageEn: 'No records found.',
        messageBn: 'কোন তথ্য পাওয়া যায়নি।',
      );
      expect(emptyEnv.deriveUiState(isOffline: false),
          equals(MobileUiState.empty));
    });

    test('4. Bilingual message resolution returns correct localized strings',
        () {
      final envelope = MobileApiResponseEnvelope<String>(
        success: true,
        code: 'OK',
        requestId: 'req-04',
        timestamp: DateTime.now().toIso8601String(),
        data: 'HELLO',
        messageEn: 'Profile loaded.',
        messageBn: 'প্রোফাইল লোড করা হয়েছে।',
      );

      expect(envelope.getLocalizedMessage('bn'),
          equals('প্রোফাইল লোড করা হয়েছে।'));
      expect(envelope.getLocalizedMessage('en'), equals('Profile loaded.'));
      expect(envelope.getLocalizedMessage('de'), equals('Profile loaded.'));
    });
  });
}
