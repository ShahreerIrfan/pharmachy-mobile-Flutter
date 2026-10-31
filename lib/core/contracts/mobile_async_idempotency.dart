/// Architecture Decision: ADR-0057
/// Mobile Client implementation of Async Task Idempotency and DLQ handling:
/// - Replay-safe idempotency key generation
/// - Cached response inspection (avoiding duplicate notifications or UI double-submits)
/// - Dead-letter queue tracking
library;

class MobileAsyncIdempotencyHandler {
  static const int defaultMaxRetries = 3;
  static int _seq = 0;

  static String generateIdempotencyKey([String prefix = 'mobile-task']) {
    _seq++;
    final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    final seqSuffix = (_seq % 100000).toString().padLeft(5, '0');
    return '$prefix-$timestamp-$seqSuffix';
  }

  static bool isDeadLettered(String status) {
    return status.toUpperCase().trim() == 'DEAD_LETTER';
  }

  static bool isExecutionComplete(String status) {
    final s = status.toUpperCase().trim();
    return s == 'SUCCESS' || s == 'DEAD_LETTER';
  }
}

class MobileAsyncTaskRecord {
  final String jobId;
  final String tenantId;
  final String idempotencyKey;
  final String category;
  final String taskName;
  final String status;
  final bool isReplay;
  final bool isCached;
  final int retryCount;
  final int maxRetries;
  final String? deadLetterReason;
  final DateTime scheduledAt;

  const MobileAsyncTaskRecord({
    required this.jobId,
    required this.tenantId,
    required this.idempotencyKey,
    required this.category,
    required this.taskName,
    required this.status,
    required this.isReplay,
    required this.isCached,
    required this.retryCount,
    required this.maxRetries,
    this.deadLetterReason,
    required this.scheduledAt,
  });

  bool get isCompleted =>
      MobileAsyncIdempotencyHandler.isExecutionComplete(status);

  bool get isDeadLetter =>
      MobileAsyncIdempotencyHandler.isDeadLettered(status);

  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'tenant_id': tenantId,
      'idempotency_key': idempotencyKey,
      'category': category,
      'task_name': taskName,
      'status': status,
      'is_replay': isReplay,
      'is_cached': isCached,
      'retry_count': retryCount,
      'max_retries': maxRetries,
      'dead_letter_reason': deadLetterReason,
      'scheduled_at': scheduledAt.toIso8601String(),
    };
  }
}
