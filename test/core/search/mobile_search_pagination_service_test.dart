import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_cursor_page.dart';
import 'package:pharmacy_mobile_manager/core/search/mobile_search_pagination_service.dart';
import 'package:pharmacy_mobile_manager/services/mobile_security_service.dart';

void main() {
  group(
      'P053: Mobile Manager Safe Pagination & Unicode Search Tests (ADR-0053)',
      () {
    test(
        '1. Bounded Page Sizes: clamps oversized requests and rejects non-positive values',
        () {
      expect(MobileSearchPaginationService.boundPageSize(20), equals(20));
      expect(MobileSearchPaginationService.boundPageSize(1), equals(1));
      expect(MobileSearchPaginationService.boundPageSize(100), equals(100));

      // Clamps oversized page sizes to max 100
      expect(MobileSearchPaginationService.boundPageSize(500), equals(100));
      expect(MobileSearchPaginationService.boundPageSize(999999), equals(100));

      // Rejects zero or negative values with FormatException
      expect(
        () => MobileSearchPaginationService.boundPageSize(0),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MobileSearchPaginationService.boundPageSize(-10),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        '2. Unicode Search Normalization: strips zero-width chars and normalizes Bangla/English',
        () {
      // Bengali query with zero-width characters
      const rawBn = '  নাপা\u200C এক্সট্রা  ';
      final normBn = MobileSearchPaginationService.normalizeSearchQuery(rawBn);
      expect(normBn, equals('নাপা এক্সট্রা'));

      // English query
      const rawEn = '  Napa Extra 500mg  ';
      final normEn = MobileSearchPaginationService.normalizeSearchQuery(rawEn);
      expect(normEn, equals('napa extra 500mg'));

      // Null and blank query
      expect(
          MobileSearchPaginationService.normalizeSearchQuery(null), equals(''));
      expect(MobileSearchPaginationService.normalizeSearchQuery('   '),
          equals(''));
    });

    test(
        '3. Filter Parameter Whitelist: permits whitelisted keys and rejects ORM lookups and probes',
        () {
      final allowed = {
        'brand_name',
        'generic_name',
        'search',
        'cursor',
        'page_size'
      };

      // Whitelisted valid query parameters
      final valid = {
        'brand_name': 'Napa',
        'search': 'নাপা',
        'page_size': '20',
      };
      expect(
          MobileSearchPaginationService.validateFilterParameters(
              valid, allowed),
          isTrue);

      // Direct ORM lookup probe (__)
      final ormProbe = {'tenant__secret_key': 'probe'};
      expect(
        () => MobileSearchPaginationService.validateFilterParameters(
            ormProbe, allowed),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('Direct ORM lookup probe'))),
      );

      // Sensitive attribute probe (password)
      final secretProbe = {'user_password': '123'};
      expect(
        () => MobileSearchPaginationService.validateFilterParameters(
            secretProbe, allowed),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            contains('sensitive internal attribute'))),
      );

      // Unwhitelisted parameter
      final unwhitelisted = {'unexpected_param': 'test'};
      expect(
        () => MobileSearchPaginationService.validateFilterParameters(
            unwhitelisted, allowed),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            contains('Unrecognized or forbidden'))),
      );
    });

    test(
        '4. Tenant Boundary Protection: matching tenant succeeds; cross-tenant query throws SecurityException',
        () {
      const activeTenant = 'tenant-dhanmondi-care';

      expect(
        MobileSearchPaginationService.verifyTenantBoundary(
          activeTenantId: activeTenant,
          requestedTenantId: 'tenant-dhanmondi-care',
        ),
        isTrue,
      );
      expect(
        MobileSearchPaginationService.verifyTenantBoundary(
          activeTenantId: activeTenant,
          requestedTenantId: null,
        ),
        isTrue,
      );

      // Cross-tenant access blocked
      expect(
        () => MobileSearchPaginationService.verifyTenantBoundary(
          activeTenantId: activeTenant,
          requestedTenantId: 'tenant-uttara-pharma',
        ),
        throwsA(isA<SecurityException>().having((e) => e.message, 'message',
            contains('ERR_CROSS_TENANT_VIOLATION'))),
      );
    });

    test('5. Cursor Response Parsing, Bilingual Messages & UI State Resolution',
        () {
      final json = {
        'success': true,
        'code': 'CURSOR_PAGINATED_RESULTS',
        'request_id': 'req-mobile-test-01',
        'data': [
          {'product_id': 'PROD-01', 'brand_name': 'Napa 500mg'},
          {'product_id': 'PROD-02', 'brand_name': 'Ace 500mg'},
        ],
        'meta': {
          'pagination': {
            'type': 'cursor',
            'page_size': 20,
            'has_next': true,
            'has_previous': false,
            'next_cursor': 'token_next_mobile',
          },
          'filters': {'search': 'নাপা'},
        },
        'message_en': 'Retrieved 2 records via cursor pagination.',
        'message_bn': 'কার্সার পেজিনেশনের মাধ্যমে ২ টি রেকর্ড লোড হয়েছে।',
      };

      final MobileCursorPage<Map<String, dynamic>> page =
          MobileSearchPaginationService.parseCursorResponse<
              Map<String, dynamic>>(
        json,
        (item) => Map<String, dynamic>.from(item as Map),
      );

      expect(page.count, equals(2));
      expect(page.isEmpty, isFalse);
      expect(page.pagination.hasNext, isTrue);
      expect(page.pagination.hasPrevious, isFalse);
      expect(page.pagination.nextCursor, equals('token_next_mobile'));
      expect(page.requestId, equals('req-mobile-test-01'));
      expect(page.filters['search'], equals('নাপা'));

      // Bilingual messages
      final invalidCursorMsg =
          MobileSearchPaginationService.getBilingualErrorMessage(
              'ERR_INVALID_CURSOR');
      expect(
          invalidCursorMsg['en'], contains('invalid, expired, or malformed'));
      expect(invalidCursorMsg['bn'], contains('কার্সারটি অবৈধ'));

      final crossTenantMsg =
          MobileSearchPaginationService.getBilingualErrorMessage(
              'ERR_CROSS_TENANT_VIOLATION');
      expect(crossTenantMsg['en'], contains('Cross-tenant'));
      expect(crossTenantMsg['bn'], contains('অনুসন্ধান কঠোরভাবে নিষিদ্ধ'));

      // UI state derivation
      expect(
          MobileSearchPaginationService.resolveUiState(
              'ERR_CROSS_TENANT_VIOLATION'),
          equals(MobileUiState.permissionDenied));
      expect(MobileSearchPaginationService.resolveUiState('ERR_INVALID_CURSOR'),
          equals(MobileUiState.error));
    });
  });
}
