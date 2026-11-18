// mobile_offline_rx_policy_client.dart
// Architecture Decision: ADR-0311 (P311).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

enum OfflineRxPolicyUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class OfflineRxTokenDto {
  final String tokenId;
  final String deviceId;
  final String productId;
  final String rxCategory;
  final int approvedMaxUnits;
  final int dispensedUnits;
  final int remainingUnits;
  final String authorizedTotalBdt;
  final String status;
  final bool antimicrobialRegisterRequired;

  OfflineRxTokenDto({
    required this.tokenId,
    required this.deviceId,
    required this.productId,
    required this.rxCategory,
    required this.approvedMaxUnits,
    required this.dispensedUnits,
    required this.remainingUnits,
    required this.authorizedTotalBdt,
    required this.status,
    required this.antimicrobialRegisterRequired,
  });

  factory OfflineRxTokenDto.fromJson(Map<String, dynamic> json) {
    return OfflineRxTokenDto(
      tokenId: json['token_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      rxCategory: json['rx_category']?.toString() ?? 'STANDARD_RX',
      approvedMaxUnits: (json['approved_max_units'] as num?)?.toInt() ?? 0,
      dispensedUnits: (json['dispensed_units'] as num?)?.toInt() ?? 0,
      remainingUnits: (json['remaining_units'] as num?)?.toInt() ?? 0,
      authorizedTotalBdt: json['authorized_total_bdt']?.toString() ?? '0.00',
      status: json['status']?.toString() ?? 'ACTIVE',
      antimicrobialRegisterRequired: json['antimicrobial_register_required'] == true,
    );
  }

  Map<String, String> localizedStatusBadge() {
    switch (status.toUpperCase()) {
      case 'REVOKED':
        return {'en': 'Revoked — Blocked Offline', 'bn': 'বাতিল — অফলাইনে ব্লকড'};
      case 'EXPIRED':
        return {'en': 'Expired — Online Rx Required', 'bn': 'মেয়াদোত্তীর্ণ — অনলাইন যাচাই প্রয়োজন'};
      case 'CONSUMED':
        return {'en': 'Fully Dispensed', 'bn': 'সম্পূর্ণ ডিস্পেন্সকৃত'};
      default:
        return {
          'en': antimicrobialRegisterRequired
              ? 'Active Antimicrobial ($remainingUnits left • Register Req)'
              : 'Active Pre-Verified Rx ($remainingUnits left)',
          'bn': antimicrobialRegisterRequired
              ? 'সক্রিয় অ্যান্টিবায়োটিক ($remainingUnits বাকি • রেজিস্টার আবশ্যক)'
              : 'সক্রিয় পূর্ব-যাচাইকৃত Rx ($remainingUnits বাকি)',
        };
    }
  }
}

class MobileOfflineRxPolicyClient {
  OfflineRxPolicyUiState uiState = OfflineRxPolicyUiState.idle;
  List<OfflineRxTokenDto> _cached = [];
  String lastErrorEn = '';
  String lastErrorBn = '';

  List<OfflineRxTokenDto> parseTokensResponse(Map<String, dynamic> json) {
    final raw = (json['tokens'] as List<dynamic>? ?? []);
    final items = raw.map((e) => OfflineRxTokenDto.fromJson(e as Map<String, dynamic>)).toList();
    _cached = items;
    uiState = items.isEmpty ? OfflineRxPolicyUiState.empty : OfflineRxPolicyUiState.loaded;
    return items;
  }

  void handleHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      uiState = OfflineRxPolicyUiState.permissionDenied;
      lastErrorEn = 'Pharmacist/Manager permission required or subscription suspended.';
      lastErrorBn = 'ফার্মাসিস্ট/ম্যানেজার অনুমতি প্রয়োজন অথবা সাবস্ক্রিপশন স্থগিত।';
    } else {
      uiState = OfflineRxPolicyUiState.error;
      lastErrorEn = 'Offline Rx policy sync failed (HTTP $statusCode).';
      lastErrorBn = 'অফলাইন প্রেসক্রিপশন পলিসি সিঙ্ক ব্যর্থ হয়েছে (HTTP $statusCode)।';
    }
  }

  List<OfflineRxTokenDto> loadOfflineFallback() {
    uiState = _cached.isEmpty ? OfflineRxPolicyUiState.empty : OfflineRxPolicyUiState.offlineCache;
    return List.unmodifiable(_cached);
  }
}
