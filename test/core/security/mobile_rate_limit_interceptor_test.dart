import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_rate_limit_interceptor.dart';

void main() {
  group('P048: Mobile Manager Rate Limiting Interceptor Tests', () {
    late MobileRateLimitManager manager;

    setUp(() {
      manager = MobileRateLimitManager();
    });

    test(
        '1. Recording a rate limit activates cooldown window and remaining seconds',
        () {
      manager.recordThrottle('auth_login', 30);

      expect(manager.isThrottled('auth_login'), isTrue);
      final remaining = manager.getRemainingWaitSeconds('auth_login');
      expect(remaining, greaterThanOrEqualTo(29));
      expect(remaining, lessThanOrEqualTo(30));
    });

    test(
        '2. Bilingual warnings format correct wait duration in English and Bangla',
        () {
      manager.recordThrottle('sensitive_mutation', 45);

      final warningEn = manager.getLocalizedWarning('sensitive_mutation', 'en');
      final warningBn = manager.getLocalizedWarning('sensitive_mutation', 'bn');

      expect(warningEn,
          contains('Request rate limit exceeded. Please retry after'));
      expect(warningBn, contains('অনুরোধের সীমা অতিক্রম করেছে। অনুগ্রহ করে'));
      expect(warningBn, contains('সেকেন্ড পর পুনরায় চেষ্টা করুন।'));
    });

    test('3. Unthrottled route returns false and zero seconds', () {
      expect(manager.isThrottled('unknown_route'), isFalse);
      expect(manager.getRemainingWaitSeconds('unknown_route'), equals(0));
    });

    test('4. Clearing throttle restores immediate access', () {
      manager.recordThrottle('data_export', 60);
      expect(manager.isThrottled('data_export'), isTrue);

      manager.clearThrottle('data_export');
      expect(manager.isThrottled('data_export'), isFalse);
      expect(manager.getRemainingWaitSeconds('data_export'), equals(0));
    });

    test('5. Empty routeKey throws ArgumentError', () {
      expect(() => manager.recordThrottle('', 30), throwsArgumentError);
    });
  });
}
