// mobile_sync_checkpoint_client.dart
// Architecture Decision: ADR-0308 (P308).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

enum CheckpointUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class DeviceSyncWatermarkDto {
  final String watermarkId;
  final String deviceId;
  final int pullAppliedSequenceNo;
  final int pushAckedSequenceNo;
  final String pushMonetaryReconciledBdt;
  final int recoveryEpoch;
  final int pullLagEvents;

  DeviceSyncWatermarkDto({
    required this.watermarkId,
    required this.deviceId,
    required this.pullAppliedSequenceNo,
    required this.pushAckedSequenceNo,
    required this.pushMonetaryReconciledBdt,
    required this.recoveryEpoch,
    required this.pullLagEvents,
  });

  factory DeviceSyncWatermarkDto.fromJson(Map<String, dynamic> json) {
    return DeviceSyncWatermarkDto(
      watermarkId: json['watermark_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      pullAppliedSequenceNo: (json['pull_applied_sequence_no'] as num?)?.toInt() ?? 0,
      pushAckedSequenceNo: (json['push_acked_sequence_no'] as num?)?.toInt() ?? 0,
      pushMonetaryReconciledBdt: json['push_monetary_reconciled_bdt']?.toString() ?? '0.00',
      recoveryEpoch: (json['recovery_epoch'] as num?)?.toInt() ?? 1,
      pullLagEvents: (json['pull_lag_events'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, String> localizedHealthBadge() {
    if (pullLagEvents == 0) {
      return {
        'en': 'Checkpointed (Pull #$pullAppliedSequenceNo • Push #$pushAckedSequenceNo)',
        'bn': 'চেকপয়েন্ট সম্পন্ন (পুল #$pullAppliedSequenceNo • পুশ #$pushAckedSequenceNo)',
      };
    }
    return {
      'en': 'Lag: $pullLagEvents pull event(s) (Epoch $recoveryEpoch)',
      'bn': 'পুল বাকি: $pullLagEventsটি (Epoch $recoveryEpoch)',
    };
  }
}

class MobileSyncCheckpointClient {
  CheckpointUiState uiState = CheckpointUiState.idle;
  List<DeviceSyncWatermarkDto> _cached = [];
  String lastErrorEn = '';
  String lastErrorBn = '';

  List<DeviceSyncWatermarkDto> parseWatermarksResponse(Map<String, dynamic> json) {
    final raw = (json['watermarks'] as List<dynamic>? ?? []);
    final items = raw.map((e) => DeviceSyncWatermarkDto.fromJson(e as Map<String, dynamic>)).toList();
    _cached = items;
    uiState = items.isEmpty ? CheckpointUiState.empty : CheckpointUiState.loaded;
    return items;
  }

  void handleHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      uiState = CheckpointUiState.permissionDenied;
      lastErrorEn = 'Unauthorized or suspended tenant.';
      lastErrorBn = 'অনুমতি নেই অথবা সাবস্ক্রিপশন স্থগিত আছে।';
    } else {
      uiState = CheckpointUiState.error;
      lastErrorEn = 'Checkpoint sync failed (HTTP $statusCode).';
      lastErrorBn = 'চেকপয়েন্ট সিঙ্ক ব্যর্থ হয়েছে (HTTP $statusCode)।';
    }
  }

  List<DeviceSyncWatermarkDto> loadOfflineFallback() {
    uiState = _cached.isEmpty ? CheckpointUiState.empty : CheckpointUiState.offlineCache;
    return List.unmodifiable(_cached);
  }
}
