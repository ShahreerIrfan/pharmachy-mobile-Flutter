// mobile_change_feed_client.dart
// Architecture Decision: ADR-0307 (P307).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

enum ChangeFeedUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class ChangeFeedEventDto {
  final String eventId;
  final int sequenceNo;
  final String entityType;
  final String entityId;
  final String operation;
  final int entityVersion;
  final String monetaryImpactBdt;
  final String? branchId;

  ChangeFeedEventDto({
    required this.eventId,
    required this.sequenceNo,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.entityVersion,
    required this.monetaryImpactBdt,
    this.branchId,
  });

  factory ChangeFeedEventDto.fromJson(Map<String, dynamic> json) {
    return ChangeFeedEventDto(
      eventId: json['event_id']?.toString() ?? '',
      sequenceNo: (json['sequence_no'] as num?)?.toInt() ?? 0,
      entityType: json['entity_type']?.toString() ?? 'MEDICINE_CATALOG',
      entityId: json['entity_id']?.toString() ?? '',
      operation: json['operation']?.toString() ?? 'UPSERT',
      entityVersion: (json['entity_version'] as num?)?.toInt() ?? 1,
      monetaryImpactBdt: json['monetary_impact_bdt']?.toString() ?? '0.00',
      branchId: json['branch_id']?.toString(),
    );
  }

  Map<String, String> localizedOperationBadge() {
    switch (operation.toUpperCase()) {
      case 'TOMBSTONE':
        return {'en': 'Removed / Recalled', 'bn': 'অপসারিত / রিকলকৃত'};
      case 'REVERSAL':
        return {'en': 'Audited Reversal', 'bn': 'অডিটেড রিভার্সাল'};
      default:
        return {'en': 'Updated (v$entityVersion)', 'bn': 'আপডেটেড (v$entityVersion)'};
    }
  }
}

class DeviceSyncCursorDto {
  final String deviceId;
  final String branchId;
  final int lastSequenceNo;
  final int latestServerSequence;
  final int lagEvents;

  DeviceSyncCursorDto({
    required this.deviceId,
    required this.branchId,
    required this.lastSequenceNo,
    required this.latestServerSequence,
    required this.lagEvents,
  });

  factory DeviceSyncCursorDto.fromJson(Map<String, dynamic> json) {
    return DeviceSyncCursorDto(
      deviceId: json['device_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      lastSequenceNo: (json['last_sequence_no'] as num?)?.toInt() ?? 0,
      latestServerSequence: (json['latest_server_sequence'] as num?)?.toInt() ?? 0,
      lagEvents: (json['lag_events'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, String> localizedLagStatus() {
    if (lagEvents <= 0) {
      return {'en': 'Caught Up', 'bn': 'আপ-টু-ডেট'};
    }
    return {'en': '$lagEvents event(s) behind', 'bn': '$lagEventsটি পরিবর্তন বাকি'};
  }
}

class MobileChangeFeedClient {
  ChangeFeedUiState uiState = ChangeFeedUiState.idle;
  List<ChangeFeedEventDto> _cachedEvents = [];
  List<DeviceSyncCursorDto> _cachedCursors = [];
  String lastErrorEn = '';
  String lastErrorBn = '';

  List<ChangeFeedEventDto> parsePullResponse(Map<String, dynamic> json) {
    final raw = (json['events'] as List<dynamic>? ?? []);
    final items = raw.map((e) => ChangeFeedEventDto.fromJson(e as Map<String, dynamic>)).toList();
    _cachedEvents = items;
    uiState = items.isEmpty ? ChangeFeedUiState.empty : ChangeFeedUiState.loaded;
    return items;
  }

  List<DeviceSyncCursorDto> parseCursorsResponse(Map<String, dynamic> json) {
    final raw = (json['cursors'] as List<dynamic>? ?? []);
    final items = raw.map((e) => DeviceSyncCursorDto.fromJson(e as Map<String, dynamic>)).toList();
    _cachedCursors = items;
    uiState = items.isEmpty ? ChangeFeedUiState.empty : ChangeFeedUiState.loaded;
    return items;
  }

  void handleHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      uiState = ChangeFeedUiState.permissionDenied;
      lastErrorEn = 'Permission denied or subscription suspended.';
      lastErrorBn = 'অনুমতি নেই অথবা সাবস্ক্রিপশন স্থগিত আছে।';
    } else {
      uiState = ChangeFeedUiState.error;
      lastErrorEn = 'Failed to sync change feed (HTTP $statusCode).';
      lastErrorBn = 'চেঞ্জ ফিড সিঙ্ক ব্যর্থ হয়েছে (HTTP $statusCode)।';
    }
  }

  List<ChangeFeedEventDto> loadOfflineFallback() {
    uiState = _cachedEvents.isEmpty ? ChangeFeedUiState.empty : ChangeFeedUiState.offlineCache;
    return List.unmodifiable(_cachedEvents);
  }

  List<DeviceSyncCursorDto> get cachedCursors => List.unmodifiable(_cachedCursors);
}
