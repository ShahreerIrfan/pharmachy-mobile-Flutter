import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_sync_backpressure_client.dart';

void main() {
  group('P317 MobileSyncBackpressureClient Tests', () {
    late MobileSyncBackpressureClient client;

    setUp(() {
      client = MobileSyncBackpressureClient(
        maxBatchSize: 50,
        maxPayloadBytes: 2048,
        baseDelayMs: 1000,
        maxDelayMs: 60000,
      );
    });

    test('Slices records and restricts batch size during active POS checkout', () {
      final records = List.generate(
        35,
        (i) => {'command_id': 'CMD-$i', 'data': 'pos_event_$i'},
      );

      // Normal slicing
      final normalBatches = client.sliceBatches(records, isPosCheckoutActive: false);
      expect(normalBatches.isNotEmpty, true);

      // POS Active slicing: each batch must be <= 10 items
      final posBatches = client.sliceBatches(records, isPosCheckoutActive: true);
      for (final b in posBatches) {
        expect(b.length <= 10, true);
      }
    });

    test('Computes exponential backoff correctly', () {
      expect(client.computeBackoffDelayMs(0), 0);
      expect(client.computeBackoffDelayMs(1), 1000);
      expect(client.computeBackoffDelayMs(2), 2000);
      expect(client.computeBackoffDelayMs(3), 4000);
      expect(client.computeBackoffDelayMs(10), 60000);
    });

    test('Cancellation flag immediately halts slicing', () {
      final records = List.generate(
        10,
        (i) => {'command_id': 'CMD-$i'},
      );

      final batches = client.sliceBatches(records, isCancelled: true);
      expect(batches.isEmpty, true);
    });

    test('Calculates progress percentage accurately', () {
      expect(client.calculateProgress(100, 25), 25.0);
      expect(client.calculateProgress(3, 1), 33.33);
      expect(client.calculateProgress(0, 0), 100.0);
    });
  });
}
