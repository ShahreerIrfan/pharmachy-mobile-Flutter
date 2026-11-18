// mobile_cloud_push_client.dart
// Architecture Decision: ADR-0305 (P305).

enum PushMonitorUiState { idle, loading, loaded, empty, offlineCache, error }

class CloudPushBatchDto {
  final String pushBatchId;
  final String clientBatchId;
  final String deviceId;
  final int eventCount;
  final int acceptedCount;
  final int conflictCount;
  final bool signatureVerified;
  final String status;

  CloudPushBatchDto({
    required this.pushBatchId,
    required this.clientBatchId,
    required this.deviceId,
    required this.eventCount,
    required this.acceptedCount,
    required this.conflictCount,
    required this.signatureVerified,
    required this.status,
  });

  factory CloudPushBatchDto.fromJson(Map<String, dynamic> json) {
    return CloudPushBatchDto(
      pushBatchId: json['push_batch_id']?.toString() ?? '',
      clientBatchId: json['client_batch_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      eventCount: (json['event_count'] as num?)?.toInt() ?? 0,
      acceptedCount: (json['accepted_count'] as num?)?.toInt() ?? 0,
      conflictCount: (json['conflict_count'] as num?)?.toInt() ?? 0,
      signatureVerified: json['signature_verified'] as bool? ?? false,
      status: json['status']?.toString() ?? 'COMPLETED',
    );
  }

  Map<String, String> localizedStatusBadge() {
    switch (status.toUpperCase()) {
      case 'PARTIAL_CONFLICT':
        return {'en': 'Synced with Conflicts ($conflictCount)', 'bn': 'কনফ্লিক্টসহ সিঙ্ক ($conflictCount)'};
      case 'REJECTED':
        return {'en': 'Rejected', 'bn': 'প্রত্যাখ্যাত'};
      default:
        return {'en': 'Signed & Synced ($acceptedCount/$eventCount)', 'bn': 'সাইনড ও সিঙ্ক সম্পন্ন ($acceptedCount/$eventCount)'};
    }
  }
}

class MobileCloudPushClient {
  PushMonitorUiState uiState = PushMonitorUiState.idle;
  List<CloudPushBatchDto> _cache = [];

  List<CloudPushBatchDto> parseBatchList(Map<String, dynamic> json) {
    final raw = (json['batches'] as List<dynamic>? ?? []);
    final items = raw.map((e) => CloudPushBatchDto.fromJson(e as Map<String, dynamic>)).toList();
    _cache = items;
    uiState = items.isEmpty ? PushMonitorUiState.empty : PushMonitorUiState.loaded;
    return items;
  }

  List<CloudPushBatchDto> loadOfflineFallback() {
    uiState = _cache.isEmpty ? PushMonitorUiState.empty : PushMonitorUiState.offlineCache;
    return List.unmodifiable(_cache);
  }
}
