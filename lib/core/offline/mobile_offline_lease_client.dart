// mobile_offline_lease_client.dart
// Architecture Decision: ADR-0312 (P312).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

enum OfflineLeaseUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class SignedOfflineLeaseDto {
  final String leaseId;
  final String deviceId;
  final String planTier;
  final String status;
  final bool newOfflineSalesAllowed;
  final bool protectedSyncRecoveryAllowed;
  final int pendingRecoveryCount;
  final String pendingRecoveryBdt;
  final String expiresAt;

  SignedOfflineLeaseDto({
    required this.leaseId,
    required this.deviceId,
    required this.planTier,
    required this.status,
    required this.newOfflineSalesAllowed,
    required this.protectedSyncRecoveryAllowed,
    required this.pendingRecoveryCount,
    required this.pendingRecoveryBdt,
    required this.expiresAt,
  });

  factory SignedOfflineLeaseDto.fromJson(Map<String, dynamic> json) {
    return SignedOfflineLeaseDto(
      leaseId: json['lease_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      planTier: json['plan_tier']?.toString() ?? 'STANDARD',
      status: json['status']?.toString() ?? 'EXPIRED_RECOVERY_ONLY',
      newOfflineSalesAllowed: json['new_offline_sales_allowed'] == true,
      protectedSyncRecoveryAllowed: json['protected_sync_recovery_allowed'] != false,
      pendingRecoveryCount: (json['pending_recovery_count'] as num?)?.toInt() ?? 0,
      pendingRecoveryBdt: json['pending_recovery_bdt']?.toString() ?? '0.00',
      expiresAt: json['expires_at']?.toString() ?? '',
    );
  }

  Map<String, String> localizedStatusBadge() {
    switch (status.toUpperCase()) {
      case 'CLOCK_TAMPER_QUARANTINED':
        return {'en': 'Clock Tamper Quarantined — Recovery Only', 'bn': 'ঘড়ি পরিবর্তন শনাক্ত — শুধু রিকভারি চালু'};
      case 'EXPIRED_RECOVERY_ONLY':
        return {'en': 'Expired — Protected Sync Recovery Only', 'bn': 'মেয়াদোত্তীর্ণ — সুরক্ষিত রিকভারি সিঙ্ক চালু'};
      case 'REVOKED':
        return {'en': 'Revoked', 'bn': 'বাতিলকৃত'};
      default:
        return {'en': 'Active Lease ($planTier)', 'bn': 'সক্রিয় লিজ ($planTier)'};
    }
  }
}

class MobileOfflineLeaseClient {
  OfflineLeaseUiState uiState = OfflineLeaseUiState.idle;
  List<SignedOfflineLeaseDto> _cached = [];
  String lastErrorEn = '';
  String lastErrorBn = '';

  List<SignedOfflineLeaseDto> parseLeasesResponse(Map<String, dynamic> json) {
    final raw = (json['leases'] as List<dynamic>? ?? []);
    final items = raw.map((e) => SignedOfflineLeaseDto.fromJson(e as Map<String, dynamic>)).toList();
    _cached = items;
    uiState = items.isEmpty ? OfflineLeaseUiState.empty : OfflineLeaseUiState.loaded;
    return items;
  }

  void handleHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      uiState = OfflineLeaseUiState.permissionDenied;
      lastErrorEn = 'Owner/Manager permission required or lease blocked.';
      lastErrorBn = 'মালিক/ম্যানেজার অনুমতি প্রয়োজন অথবা লিজ ব্লকড।';
    } else {
      uiState = OfflineLeaseUiState.error;
      lastErrorEn = 'Failed to fetch offline leases (HTTP $statusCode).';
      lastErrorBn = 'অফলাইন লিজ লোড ব্যর্থ হয়েছে (HTTP $statusCode)।';
    }
  }

  List<SignedOfflineLeaseDto> loadOfflineFallback() {
    uiState = _cached.isEmpty ? OfflineLeaseUiState.empty : OfflineLeaseUiState.offlineCache;
    return List.unmodifiable(_cached);
  }
}
