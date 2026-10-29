import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/models/structured_log_entry.dart';

void main() {
  group('StructuredLogEntry (ADR-0035)', () {
    test('produces valid JSON and correlation headers', () {
      final entry = StructuredLogEntry(
        level: 'INFO',
        logger: 'pharmacy_mobile.dashboard',
        message: 'Loaded owner KPIs successfully',
        requestId: 'req-mob-98765',
        tenantId: 'tenant-dhaka-central',
        deviceId: 'mob-device-s24',
        operationId: 'op-kpi-refresh',
        userId: 'usr-owner-01',
      );

      final json = entry.toJson();
      expect(json['level'], 'INFO');
      expect(json['service'], 'pharmacy-mobile-manager');
      expect(json['context']['request_id'], 'req-mob-98765');
      expect(json['context']['tenant_id'], 'tenant-dhaka-central');

      final headers = entry.toCorrelationHeaders();
      expect(headers['X-Request-ID'], 'req-mob-98765');
      expect(headers['X-Tenant-ID'], 'tenant-dhaka-central');
      expect(headers['X-Device-ID'], 'mob-device-s24');
    });
  });
}
