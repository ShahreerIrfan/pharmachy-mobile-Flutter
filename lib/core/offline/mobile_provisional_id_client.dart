// mobile_provisional_id_client.dart
// Architecture Decision: ADR-0315 (P315).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

enum MobileProvisionalUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class MobileProvisionalMappingDto {
  final String mappingId;
  final String tenantId;
  final String branchId;
  final String deviceId;
  final String entityType;
  final String provisionalId;
  final String canonicalId;
  final String idempotencyKey;
  final String reconciliationStatus;
  final String mappedAt;

  MobileProvisionalMappingDto({
    required this.mappingId,
    required this.tenantId,
    required this.branchId,
    required this.deviceId,
    required this.entityType,
    required this.provisionalId,
    required this.canonicalId,
    required this.idempotencyKey,
    required this.reconciliationStatus,
    required this.mappedAt,
  });

  factory MobileProvisionalMappingDto.fromJson(Map<String, dynamic> json) {
    return MobileProvisionalMappingDto(
      mappingId: json['mapping_id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? 'INVOICE',
      provisionalId: json['provisional_id']?.toString() ?? '',
      canonicalId: json['canonical_id']?.toString() ?? '',
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
      reconciliationStatus: json['reconciliation_status']?.toString() ?? 'RECONCILED',
      mappedAt: json['mapped_at']?.toString() ?? '',
    );
  }

  Map<String, String> localizedTypeBadge() {
    switch (entityType.toUpperCase()) {
      case 'INVOICE':
        return {'en': 'Sale Invoice', 'bn': 'বিক্রয় চালান'};
      case 'CUSTOMER':
        return {'en': 'Customer', 'bn': 'ক্রেতা'};
      case 'PAYMENT':
        return {'en': 'Payment', 'bn': 'পরিশোধ'};
      case 'PRESCRIPTION':
        return {'en': 'Prescription', 'bn': 'প্রেসক্রিপশন'};
      case 'RETURN_RECEIPT':
        return {'en': 'Return Receipt', 'bn': 'ফেরত রসিদ'};
      default:
        return {'en': entityType, 'bn': entityType};
    }
  }
}

class MobileProvisionalIdClient {
  MobileProvisionalUiState uiState = MobileProvisionalUiState.idle;
  List<MobileProvisionalMappingDto> _cachedMappings = [];
  String lastErrorEn = '';
  String lastErrorBn = '';

  List<MobileProvisionalMappingDto> parseMappingsResponse(Map<String, dynamic> json) {
    final raw = (json['results'] as List<dynamic>? ?? []);
    final items = raw.map((e) => MobileProvisionalMappingDto.fromJson(e as Map<String, dynamic>)).toList();
    _cachedMappings = items;
    uiState = items.isEmpty ? MobileProvisionalUiState.empty : MobileProvisionalUiState.loaded;
    return items;
  }

  MobileProvisionalMappingDto? lookupLocally(String anyId) {
    final needle = anyId.trim().toUpperCase();
    for (final m in _cachedMappings) {
      if (m.provisionalId.toUpperCase() == needle || m.canonicalId.toUpperCase() == needle) {
        return m;
      }
    }
    return null;
  }

  void handleHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      uiState = MobileProvisionalUiState.permissionDenied;
      lastErrorEn = 'Authentication or branch access required.';
      lastErrorBn = 'লগইন বা ব্রাঞ্চ অনুমতি প্রয়োজন।';
    } else {
      uiState = MobileProvisionalUiState.error;
      lastErrorEn = 'Failed to load provisional ID mappings (HTTP $statusCode).';
      lastErrorBn = 'প্রভিশনাল আইডি ম্যাপিং লোড ব্যর্থ হয়েছে (HTTP $statusCode)।';
    }
  }

  List<MobileProvisionalMappingDto> loadOfflineFallback() {
    uiState = _cachedMappings.isEmpty ? MobileProvisionalUiState.empty : MobileProvisionalUiState.offlineCache;
    return List.unmodifiable(_cachedMappings);
  }
}
