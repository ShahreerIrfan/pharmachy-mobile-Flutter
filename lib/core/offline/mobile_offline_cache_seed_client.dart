// mobile_offline_cache_seed_client.dart
// Architecture Decision: ADR-0303 (P303).

enum SeedUiState { idle, loading, loaded, empty, offlineCache, error }

class OfflineCacheSeedDto {
  final String seedId;
  final String deviceId;
  final int snapshotVersion;
  final String consistencyToken;
  final int catalogCount;
  final int batchStockCount;
  final String status;

  OfflineCacheSeedDto({
    required this.seedId,
    required this.deviceId,
    required this.snapshotVersion,
    required this.consistencyToken,
    required this.catalogCount,
    required this.batchStockCount,
    required this.status,
  });

  factory OfflineCacheSeedDto.fromJson(Map<String, dynamic> json) {
    return OfflineCacheSeedDto(
      seedId: json['seed_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      snapshotVersion: (json['snapshot_version'] as num?)?.toInt() ?? 1,
      consistencyToken: json['consistency_token']?.toString() ?? '',
      catalogCount: (json['catalog_count'] as num?)?.toInt() ?? 0,
      batchStockCount: (json['batch_stock_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'ISSUED',
    );
  }

  Map<String, String> localizedStatusBadge() {
    switch (status.toUpperCase()) {
      case 'APPLIED':
        return {'en': 'Synced & Applied (v$snapshotVersion)', 'bn': 'সিঙ্ক ও অ্যাপ্লাই সম্পন্ন (v$snapshotVersion)'};
      case 'SUPERSEDED':
        return {'en': 'Superseded', 'bn': 'পুরোনো ভার্সন'};
      default:
        return {'en': 'Issued (Pending Device Ack)', 'bn': 'ইস্যুকৃত (ডিভাইস নিশ্চিতকরণের অপেক্ষায়)'};
    }
  }
}

class MobileOfflineCacheSeedClient {
  SeedUiState uiState = SeedUiState.idle;
  List<OfflineCacheSeedDto> _cache = [];

  List<OfflineCacheSeedDto> parseSeedHistory(Map<String, dynamic> json) {
    final raw = (json['seeds'] as List<dynamic>? ?? []);
    final items = raw.map((e) => OfflineCacheSeedDto.fromJson(e as Map<String, dynamic>)).toList();
    _cache = items;
    uiState = items.isEmpty ? SeedUiState.empty : SeedUiState.loaded;
    return items;
  }

  List<OfflineCacheSeedDto> loadOfflineFallback() {
    uiState = _cache.isEmpty ? SeedUiState.empty : SeedUiState.offlineCache;
    return List.unmodifiable(_cache);
  }
}
