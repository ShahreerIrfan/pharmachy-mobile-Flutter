// mobile_stock_allocation_policy_client.dart
// Architecture Decision: ADR-0310 (P310).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

enum StockPolicyUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class OversellDisputeDto {
  final String disputeId;
  final String deviceId;
  final String batchId;
  final int availableUnitsAtReconcile;
  final int requestedUnits;
  final int oversellShortageUnits;
  final String disputedCostBdt;
  final String status;
  final bool postedRecordsPreserved;

  OversellDisputeDto({
    required this.disputeId,
    required this.deviceId,
    required this.batchId,
    required this.availableUnitsAtReconcile,
    required this.requestedUnits,
    required this.oversellShortageUnits,
    required this.disputedCostBdt,
    required this.status,
    required this.postedRecordsPreserved,
  });

  factory OversellDisputeDto.fromJson(Map<String, dynamic> json) {
    return OversellDisputeDto(
      disputeId: json['dispute_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      batchId: json['batch_id']?.toString() ?? '',
      availableUnitsAtReconcile: (json['available_units_at_reconcile'] as num?)?.toInt() ?? 0,
      requestedUnits: (json['requested_units'] as num?)?.toInt() ?? 0,
      oversellShortageUnits: (json['oversell_shortage_units'] as num?)?.toInt() ?? 0,
      disputedCostBdt: json['disputed_cost_bdt']?.toString() ?? '0.00',
      status: json['status']?.toString() ?? 'OPEN',
      postedRecordsPreserved: json['posted_records_preserved'] != false,
    );
  }

  Map<String, String> localizedStatusBadge() {
    switch (status.toUpperCase()) {
      case 'RESOLVED_AUDITED_REVERSAL':
        return {'en': 'Resolved — Audited Reversal', 'bn': 'সমাধানকৃত — অডিটেড রিভার্সাল'};
      case 'RESOLVED_STOCK_ADJUSTMENT':
        return {'en': 'Resolved — Stock Adjustment', 'bn': 'সমাধানকৃত — স্টক সমন্বয়'};
      case 'RESOLVED_SHORTAGE_LOGGED':
        return {'en': 'Resolved — Shortage Logged', 'bn': 'সমাধানকৃত — ঘাটতি নথিভুক্ত'};
      default:
        return {
          'en': 'Open Dispute ($oversellShortageUnits short • ৳$disputedCostBdt)',
          'bn': 'ডিসপুট ওপেন ($oversellShortageUnits ঘাটতি • ৳$disputedCostBdt)',
        };
    }
  }
}

class MobileStockAllocationPolicyClient {
  StockPolicyUiState uiState = StockPolicyUiState.idle;
  List<OversellDisputeDto> _cachedDisputes = [];
  String lastErrorEn = '';
  String lastErrorBn = '';

  List<OversellDisputeDto> parseDisputesResponse(Map<String, dynamic> json) {
    final raw = (json['disputes'] as List<dynamic>? ?? []);
    final items = raw.map((e) => OversellDisputeDto.fromJson(e as Map<String, dynamic>)).toList();
    _cachedDisputes = items;
    uiState = items.isEmpty ? StockPolicyUiState.empty : StockPolicyUiState.loaded;
    return items;
  }

  void handleHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      uiState = StockPolicyUiState.permissionDenied;
      lastErrorEn = 'Manager permission required or subscription suspended.';
      lastErrorBn = 'ম্যানেজার অনুমতি প্রয়োজন অথবা সাবস্ক্রিপশন স্থগিত।';
    } else {
      uiState = StockPolicyUiState.error;
      lastErrorEn = 'Failed to load oversell disputes (HTTP $statusCode).';
      lastErrorBn = 'ওভারসেল ডিসপুট লোড ব্যর্থ হয়েছে (HTTP $statusCode)।';
    }
  }

  List<OversellDisputeDto> loadOfflineFallback() {
    uiState = _cachedDisputes.isEmpty ? StockPolicyUiState.empty : StockPolicyUiState.offlineCache;
    return List.unmodifiable(_cachedDisputes);
  }
}
