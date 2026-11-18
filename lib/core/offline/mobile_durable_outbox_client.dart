// mobile_durable_outbox_client.dart
// Architecture Decision: ADR-0304 (P304).

enum OutboxUiState { idle, loading, loaded, empty, offlineCache, error }

class OutboxReceiptDto {
  final String receiptId;
  final String deviceId;
  final int clientSequence;
  final String commandType;
  final String aggregateRef;
  final String monetaryTotalBdt;
  final String syncStatus;
  final String conflictReason;

  OutboxReceiptDto({
    required this.receiptId,
    required this.deviceId,
    required this.clientSequence,
    required this.commandType,
    required this.aggregateRef,
    required this.monetaryTotalBdt,
    required this.syncStatus,
    required this.conflictReason,
  });

  factory OutboxReceiptDto.fromJson(Map<String, dynamic> json) {
    return OutboxReceiptDto(
      receiptId: json['receipt_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      clientSequence: (json['client_sequence'] as num?)?.toInt() ?? 1,
      commandType: json['command_type']?.toString() ?? '',
      aggregateRef: json['aggregate_ref']?.toString() ?? '',
      monetaryTotalBdt: json['monetary_total_bdt']?.toString() ?? '0.00',
      syncStatus: json['sync_status']?.toString() ?? 'ACCEPTED',
      conflictReason: json['conflict_reason']?.toString() ?? '',
    );
  }

  Map<String, String> localizedSyncBadge() {
    switch (syncStatus.toUpperCase()) {
      case 'CONFLICT_NEEDS_REVIEW':
        return {'en': 'Conflict — Needs Review', 'bn': 'কনফ্লিক্ট — পর্যালোচনা প্রয়োজন'};
      case 'REJECTED':
        return {'en': 'Rejected', 'bn': 'প্রত্যাখ্যাত'};
      case 'DUPLICATE_REPLAY':
        return {'en': 'Duplicate Replay Ignored', 'bn': 'ডুপ্লিকেট রিপ্লে উপেক্ষিত'};
      default:
        return {'en': 'Synced to Cloud', 'bn': 'ক্লাউডে সিঙ্ক সম্পন্ন'};
    }
  }
}

class MobileDurableOutboxClient {
  OutboxUiState uiState = OutboxUiState.idle;
  List<OutboxReceiptDto> _cache = [];

  List<OutboxReceiptDto> parseReceipts(Map<String, dynamic> json) {
    final raw = (json['receipts'] as List<dynamic>? ?? []);
    final items = raw.map((e) => OutboxReceiptDto.fromJson(e as Map<String, dynamic>)).toList();
    _cache = items;
    uiState = items.isEmpty ? OutboxUiState.empty : OutboxUiState.loaded;
    return items;
  }

  int openConflictCount() => _cache.where((r) => r.syncStatus == 'CONFLICT_NEEDS_REVIEW').length;

  List<OutboxReceiptDto> loadOfflineFallback() {
    uiState = _cache.isEmpty ? OutboxUiState.empty : OutboxUiState.offlineCache;
    return List.unmodifiable(_cache);
  }
}
