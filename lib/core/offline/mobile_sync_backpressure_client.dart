import 'dart:convert';
import 'dart:math';

/// MobileSyncBackpressureClient
/// Architecture Decision: ADR-0317 (P317).
/// Phase 16: JavaFX SQLite Offline Store and Reliable Cloud Sync.
///
/// Handles mobile sync backpressure, exponential retry backoff,
/// payload caps, cancellation token handling, and non-blocking outbox progress.
class MobileSyncBackpressureClient {
  final int maxBatchSize;
  final int maxPayloadBytes;
  final int baseDelayMs;
  final int maxDelayMs;
  final Random _random = Random();

  MobileSyncBackpressureClient({
    this.maxBatchSize = 50,
    this.maxPayloadBytes = 512 * 1024,
    this.baseDelayMs = 1000,
    this.maxDelayMs = 60000,
  });

  /// Slices records taking into account item count cap, byte size cap, and cooperative POS checkout.
  List<List<Map<String, dynamic>>> sliceBatches(
    List<Map<String, dynamic>> records, {
    bool isPosCheckoutActive = false,
    bool isCancelled = false,
  }) {
    if (records.isEmpty || isCancelled) return [];

    final effectiveMaxItems = isPosCheckoutActive
        ? min(10, max(1, maxBatchSize ~/ 4))
        : maxBatchSize;

    final List<List<Map<String, dynamic>>> batches = [];
    List<Map<String, dynamic>> currentBatch = [];
    int currentBytes = 0;

    for (final record in records) {
      if (isCancelled) break;

      final recordBytes = utf8.encode(jsonEncode(record)).length;
      if (recordBytes > maxPayloadBytes) {
        throw ArgumentError(
          'ERR_SINGLE_RECORD_EXCEEDS_PAYLOAD_CAP: $recordBytes > $maxPayloadBytes',
        );
      }

      if (currentBatch.length >= effectiveMaxItems ||
          (currentBytes + recordBytes > maxPayloadBytes && currentBatch.isNotEmpty)) {
        batches.add(List.from(currentBatch));
        currentBatch.clear();
        currentBytes = 0;
      }

      currentBatch.add(record);
      currentBytes += recordBytes;
    }

    if (currentBatch.isNotEmpty && !isCancelled) {
      batches.add(currentBatch);
    }

    return batches;
  }

  /// Calculates exponential backoff with jitter
  int computeBackoffDelayMs(int consecutiveFailures, [double jitterFactor = 0.0]) {
    if (consecutiveFailures <= 0) return 0;
    final factor = 1 << min(20, consecutiveFailures - 1);
    final rawBackoff = min(maxDelayMs, baseDelayMs * factor);

    final jitterRange = (rawBackoff * jitterFactor.clamp(0.0, 1.0)).toInt();
    final jitter = jitterRange > 0 ? _random.nextInt(jitterRange) : 0;

    return min(maxDelayMs * 2, rawBackoff + jitter);
  }

  /// Evaluates progress percentage
  double calculateProgress(int totalEnqueued, int processedCount) {
    if (totalEnqueued <= 0) return 100.0;
    return double.parse(((processedCount / totalEnqueued) * 100).toStringAsFixed(2));
  }
}
