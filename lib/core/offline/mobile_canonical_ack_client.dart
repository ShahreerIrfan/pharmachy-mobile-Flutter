// mobile_canonical_ack_client.dart
// Architecture Decision: ADR-0306 (P306).

enum AckUiState { idle, loading, loaded, empty, offlineCache, error }

class CanonicalAckDto {
  final String ackId;
  final String idempotencyKey;
  final String localAggregateRef;
  final String canonicalEntityId;
  final String disposition;
  final String monetaryTotalBdt;
  final int replayCount;

  CanonicalAckDto({
    required this.ackId,
    required this.idempotencyKey,
    required this.localAggregateRef,
    required this.canonicalEntityId,
    required this.disposition,
    required this.monetaryTotalBdt,
    required this.replayCount,
  });

  factory CanonicalAckDto.fromJson(Map<String, dynamic> json) {
    return CanonicalAckDto(
      ackId: json['ack_id']?.toString() ?? '',
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
      localAggregateRef: json['local_aggregate_ref']?.toString() ?? '',
      canonicalEntityId: json['canonical_entity_id']?.toString() ?? '',
      disposition: json['disposition']?.toString() ?? 'COMMITTED',
      monetaryTotalBdt: json['monetary_total_bdt']?.toString() ?? '0.00',
      replayCount: (json['replay_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, String> localizedDispositionBadge() {
    switch (disposition.toUpperCase()) {
      case 'REPLAY_IDEMPOTENT':
        return {'en': 'Replay-Safe Confirmed', 'bn': 'রিপ্লে-নিরাপদ নিশ্চিত'};
      case 'TERMINAL_CONFLICT':
        return {'en': 'Conflict — Needs Review', 'bn': 'কনফ্লিক্ট — পর্যালোচনা প্রয়োজন'};
      default:
        return {'en': 'Committed ($canonicalEntityId)', 'bn': 'কমিটেড ($canonicalEntityId)'};
    }
  }
}

class MobileCanonicalAckClient {
  AckUiState uiState = AckUiState.idle;
  List<CanonicalAckDto> _cache = [];

  List<CanonicalAckDto> parseAcks(Map<String, dynamic> json) {
    final raw = (json['acknowledgments'] as List<dynamic>? ?? []);
    final items = raw.map((e) => CanonicalAckDto.fromJson(e as Map<String, dynamic>)).toList();
    _cache = items;
    uiState = items.isEmpty ? AckUiState.empty : AckUiState.loaded;
    return items;
  }

  List<CanonicalAckDto> loadOfflineFallback() {
    uiState = _cache.isEmpty ? AckUiState.empty : AckUiState.offlineCache;
    return List.unmodifiable(_cache);
  }
}
