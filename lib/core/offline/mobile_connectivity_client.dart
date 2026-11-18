// mobile_connectivity_client.dart
// Architecture Decision: ADR-0309 (P309).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

enum ConnectivityUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class DeviceConnectivityDto {
  final String snapshotId;
  final String deviceId;
  final String connectivityState;
  final bool cloudStockAuthoritative;
  final int latencyMs;
  final String packetLossPct;
  final int pendingOutboxCount;
  final String pendingOutboxBdt;
  final int pullLagEvents;
  final String? lastSuccessfulSyncAt;
  final String statusLabelEn;
  final String statusLabelBn;

  DeviceConnectivityDto({
    required this.snapshotId,
    required this.deviceId,
    required this.connectivityState,
    required this.cloudStockAuthoritative,
    required this.latencyMs,
    required this.packetLossPct,
    required this.pendingOutboxCount,
    required this.pendingOutboxBdt,
    required this.pullLagEvents,
    this.lastSuccessfulSyncAt,
    required this.statusLabelEn,
    required this.statusLabelBn,
  });

  factory DeviceConnectivityDto.fromJson(Map<String, dynamic> json) {
    return DeviceConnectivityDto(
      snapshotId: json['snapshot_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      connectivityState: json['connectivity_state']?.toString() ?? 'DISCONNECTED',
      cloudStockAuthoritative: json['cloud_stock_authoritative'] == true,
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      packetLossPct: json['packet_loss_pct']?.toString() ?? '0.00',
      pendingOutboxCount: (json['pending_outbox_count'] as num?)?.toInt() ?? 0,
      pendingOutboxBdt: json['pending_outbox_bdt']?.toString() ?? '0.00',
      pullLagEvents: (json['pull_lag_events'] as num?)?.toInt() ?? 0,
      lastSuccessfulSyncAt: json['last_successful_sync_at']?.toString(),
      statusLabelEn: json['status_label_en']?.toString() ?? '',
      statusLabelBn: json['status_label_bn']?.toString() ?? '',
    );
  }

  Map<String, String> localizedBadge() {
    switch (connectivityState.toUpperCase()) {
      case 'CONNECTED':
        return {'en': 'Connected (${latencyMs}ms)', 'bn': 'সংযুক্ত (${latencyMs}ms)'};
      case 'DEGRADED':
        return {'en': 'Degraded (${latencyMs}ms)', 'bn': 'দুর্বল নেটওয়ার্ক (${latencyMs}ms)'};
      case 'RECONNECTED':
        return {'en': 'Reconnected — Syncing', 'bn': 'পুনরায় সংযুক্ত — সিঙ্ক হচ্ছে'};
      default:
        return {'en': 'Offline ($pendingOutboxCount queued)', 'bn': 'অফলাইন ($pendingOutboxCountটি কিউতে)'};
    }
  }
}

class MobileConnectivityClient {
  ConnectivityUiState uiState = ConnectivityUiState.idle;
  List<DeviceConnectivityDto> _cached = [];
  String lastErrorEn = '';
  String lastErrorBn = '';

  List<DeviceConnectivityDto> parseSnapshotsResponse(Map<String, dynamic> json) {
    final raw = (json['snapshots'] as List<dynamic>? ?? []);
    final items = raw.map((e) => DeviceConnectivityDto.fromJson(e as Map<String, dynamic>)).toList();
    _cached = items;
    uiState = items.isEmpty ? ConnectivityUiState.empty : ConnectivityUiState.loaded;
    return items;
  }

  void handleHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      uiState = ConnectivityUiState.permissionDenied;
      lastErrorEn = 'Access denied or tenant subscription suspended.';
      lastErrorBn = 'অ্যাক্সেস অনুমোদিত নয় অথবা সাবস্ক্রিপশন স্থগিত।';
    } else {
      uiState = ConnectivityUiState.error;
      lastErrorEn = 'Unable to load connectivity status (HTTP $statusCode).';
      lastErrorBn = 'কানেক্টিভিটি স্ট্যাটাস লোড ব্যর্থ হয়েছে (HTTP $statusCode)।';
    }
  }

  List<DeviceConnectivityDto> loadOfflineFallback() {
    uiState = _cached.isEmpty ? ConnectivityUiState.empty : ConnectivityUiState.offlineCache;
    return List.unmodifiable(_cached);
  }
}
