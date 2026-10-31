import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/pipeline/mobile_smoke_diagnostic.dart';

void main() {
  group('P040: Mobile Smoke Diagnostic Probe Test Suite', () {
    test('MobileSmokeDiagnostic reports healthy status with system telemetry',
        () {
      final result = MobileSmokeDiagnostic.runDiagnostic();

      expect(result.isHealthy, isTrue);
      expect(result.dartVersion.isNotEmpty, isTrue);
      expect(result.operatingSystem.isNotEmpty, isTrue);
      expect(result.component, equals('MOBILE_MANAGER'));
      expect(result.timestamp.isNotEmpty, isTrue);

      final jsonMap = result.toJson();
      expect(jsonMap['component'], equals('MOBILE_MANAGER'));
      expect(jsonMap['is_healthy'], isTrue);
      expect(jsonMap['metadata'], isA<Map<String, dynamic>>());
    });
  });
}
