import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_async_idempotency.dart';

void main() {
  group('ADR-0057: Mobile Async Task Idempotency & DLQ Tests', () {
    test('generates unique replay-safe idempotency keys', () {
      final key1 = MobileAsyncIdempotencyHandler.generateIdempotencyKey('sms-alert');
      final key2 = MobileAsyncIdempotencyHandler.generateIdempotencyKey('sms-alert');

      expect(key1, startsWith('sms-alert-'));
      expect(key1, isNot(equals(key2)));
    });

    test('creates and inspects mobile async task record', () {
      final record = MobileAsyncTaskRecord(
        jobId: 'job-501',
        tenantId: 'tenant-dhaka',
        idempotencyKey: 'idem-mobile-999',
        category: 'NOTIFICATION',
        taskName: 'DAILY_REVENUE_SMS',
        status: 'SUCCESS',
        isReplay: false,
        isCached: false,
        retryCount: 0,
        maxRetries: 3,
        scheduledAt: DateTime.now().toUtc(),
      );

      expect(record.jobId, equals('job-501'));
      expect(record.status, equals('SUCCESS'));
      expect(record.isCompleted, isTrue);
      expect(record.isDeadLetter, isFalse);
    });

    test('detects replay and dead-letter states correctly', () {
      expect(MobileAsyncIdempotencyHandler.isDeadLettered('DEAD_LETTER'), isTrue);
      expect(MobileAsyncIdempotencyHandler.isDeadLettered('dead_letter'), isTrue);
      expect(MobileAsyncIdempotencyHandler.isDeadLettered('SUCCESS'), isFalse);
      expect(MobileAsyncIdempotencyHandler.isExecutionComplete('DEAD_LETTER'), isTrue);
      expect(MobileAsyncIdempotencyHandler.isExecutionComplete('SUCCESS'), isTrue);
      expect(MobileAsyncIdempotencyHandler.isExecutionComplete('RETRYING'), isFalse);
    });
  });
}
