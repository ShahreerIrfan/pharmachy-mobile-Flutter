import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_health_prober.dart';

void main() {
  group('ADR-0058: Mobile Health & Readiness Prober Tests', () {
    test('detects sensitive leaked credentials in health response', () {
      const cleanJson = '{"status":"READY","checks":{"database":"UP","redis":"UP"}}';
      expect(MobileHealthProber.containsSensitiveLeak(cleanJson), isFalse);

      const leakedJson1 = '{"database_url":"postgres://root:secret_password@db:5432"}';
      expect(MobileHealthProber.containsSensitiveLeak(leakedJson1), isTrue);

      const leakedJson2 = '{"jwt_secret_key":"test-key-leaked"}';
      expect(MobileHealthProber.containsSensitiveLeak(leakedJson2), isTrue);
    });

    test('evaluates system readiness correctly', () {
      expect(
        MobileHealthProber.isReady('READY', {'database': 'UP', 'redis': 'UP'}),
        isTrue,
      );
      expect(
        MobileHealthProber.isReady('NOT_READY', {'database': 'DOWN', 'redis': 'UP'}),
        isFalse,
      );
    });

    test('creates and inspects mobile health report', () {
      final report = MobileHealthReport(
        service: 'pharmacy-saas-cloud-api',
        status: 'READY',
        isReady: true,
        componentChecks: const {'database': 'UP', 'storage': 'UP'},
        timestamp: DateTime.now().toUtc(),
      );

      expect(report.service, equals('pharmacy-saas-cloud-api'));
      expect(report.status, equals('READY'));
      expect(report.isReady, isTrue);
      expect(report.componentChecks['database'], equals('UP'));
    });
  });
}
