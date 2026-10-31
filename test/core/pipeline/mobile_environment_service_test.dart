import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/pipeline/mobile_environment_service.dart';

void main() {
  group('P041: Mobile Environment Service Test Suite', () {
    test('Development profile allows HTTP and points to local emulator host',
        () {
      final config =
          MobileEnvironmentService.resolveConfig(MobileEnvironment.development);

      expect(config.environment, equals(MobileEnvironment.development));
      expect(config.isHttpsEnforced, isFalse);
      expect(config.apiBaseUrl, contains('10.0.2.2'));
    });

    test('Production profile enforces HTTPS with cloud authority domain', () {
      final config =
          MobileEnvironmentService.resolveConfig(MobileEnvironment.production);

      expect(config.environment, equals(MobileEnvironment.production));
      expect(config.isHttpsEnforced, isTrue);
      expect(config.apiBaseUrl, startsWith('https://'));
      expect(config.apiBaseUrl, contains('api.pharmacy.bd'));
    });
  });
}
