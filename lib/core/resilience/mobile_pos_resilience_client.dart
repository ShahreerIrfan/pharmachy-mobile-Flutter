// mobile_pos_resilience_client.dart
// Architecture Decision: ADR-0239 (P239).
// Phase 12: POS, Sales Orders, Checkout & Returns.

enum MobilePosUiState {
  ready,
  loading,
  error,
  permissionDenied,
  offline,
}

enum MobilePosIncidentType {
  scannerFailure,
  printerDisconnected,
  stockConflict,
  networkInterrupted,
}

extension MobilePosIncidentTypeExt on MobilePosIncidentType {
  String get value {
    switch (this) {
      case MobilePosIncidentType.scannerFailure:
        return 'SCANNER_FAILURE';
      case MobilePosIncidentType.printerDisconnected:
        return 'PRINTER_DISCONNECTED';
      case MobilePosIncidentType.stockConflict:
        return 'STOCK_CONFLICT';
      case MobilePosIncidentType.networkInterrupted:
        return 'NETWORK_INTERRUPTED';
    }
  }
}

enum MobilePosRecoveryAction {
  manualSearchFallback,
  reconnectScanner,
  retryPrint,
  switchPrinterFormat,
  queuePrintOffline,
  autoFefoReallocate,
  offerAlternativeBatch,
  stageOfflineOutbox,
  retryWithIdempotency,
}

extension MobilePosRecoveryActionExt on MobilePosRecoveryAction {
  String get value {
    switch (this) {
      case MobilePosRecoveryAction.manualSearchFallback:
        return 'MANUAL_SEARCH_FALLBACK';
      case MobilePosRecoveryAction.reconnectScanner:
        return 'RECONNECT_SCANNER';
      case MobilePosRecoveryAction.retryPrint:
        return 'RETRY_PRINT';
      case MobilePosRecoveryAction.switchPrinterFormat:
        return 'SWITCH_PRINTER_FORMAT';
      case MobilePosRecoveryAction.queuePrintOffline:
        return 'QUEUE_PRINT_OFFLINE';
      case MobilePosRecoveryAction.autoFefoReallocate:
        return 'AUTO_FEFO_REALLOCATE';
      case MobilePosRecoveryAction.offerAlternativeBatch:
        return 'OFFER_ALTERNATIVE_BATCH';
      case MobilePosRecoveryAction.stageOfflineOutbox:
        return 'STAGE_OFFLINE_OUTBOX';
      case MobilePosRecoveryAction.retryWithIdempotency:
        return 'RETRY_WITH_IDEMPOTENCY';
    }
  }
}

class MobileStockAlternativeDto {
  final String batchId;
  final String batchNumber;
  final String expiryDate;
  final int availableUnits;
  final String? costUnit;
  final bool isExpired;
  final bool canFulfillRequested;

  const MobileStockAlternativeDto({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.availableUnits,
    this.costUnit,
    this.isExpired = false,
    this.canFulfillRequested = true,
  });

  factory MobileStockAlternativeDto.fromJson(Map<String, dynamic> json) {
    return MobileStockAlternativeDto(
      batchId: json['batch_id']?.toString() ?? '',
      batchNumber: json['batch_number']?.toString() ?? '',
      expiryDate: json['expiry_date']?.toString() ?? '',
      availableUnits: (json['available_units'] is num) ? (json['available_units'] as num).toInt() : 0,
      costUnit: json['cost_unit']?.toString(),
      isExpired: json['is_expired'] == true,
      canFulfillRequested: json['can_fulfill_requested'] == true,
    );
  }
}

class MobilePosErrorIncidentDto {
  final String incidentId;
  final String incidentType;
  final String errorCode;
  final String correlationId;
  final String deviceId;
  final String cashierEmail;
  final String saleOrderNumber;
  final String messageEn;
  final String messageBn;
  final String status;
  final String recoveryActionTaken;
  final bool isRetryable;
  final String createdAt;
  final String? resolvedAt;

  const MobilePosErrorIncidentDto({
    required this.incidentId,
    required this.incidentType,
    required this.errorCode,
    required this.correlationId,
    this.deviceId = '',
    this.cashierEmail = '',
    this.saleOrderNumber = '',
    this.messageEn = '',
    this.messageBn = '',
    required this.status,
    this.recoveryActionTaken = '',
    this.isRetryable = true,
    required this.createdAt,
    this.resolvedAt,
  });

  factory MobilePosErrorIncidentDto.fromJson(Map<String, dynamic> json) {
    return MobilePosErrorIncidentDto(
      incidentId: json['incident_id']?.toString() ?? '',
      incidentType: json['incident_type']?.toString() ?? '',
      errorCode: json['error_code']?.toString() ?? '',
      correlationId: json['correlation_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      cashierEmail: json['cashier_email']?.toString() ?? '',
      saleOrderNumber: json['sale_order_number']?.toString() ?? '',
      messageEn: json['message_en']?.toString() ?? '',
      messageBn: json['message_bn']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      recoveryActionTaken: json['recovery_action_taken']?.toString() ?? '',
      isRetryable: json['is_retryable'] != false,
      createdAt: json['created_at']?.toString() ?? '',
      resolvedAt: json['resolved_at']?.toString(),
    );
  }
}

class MobilePosOutcome<T> {
  final MobilePosUiState uiState;
  final T? data;
  final String? messageEn;
  final String? messageBn;
  final String? errorCode;

  const MobilePosOutcome({
    required this.uiState,
    this.data,
    this.messageEn,
    this.messageBn,
    this.errorCode,
  });

  bool get isSuccess => uiState == MobilePosUiState.ready && data != null;
}

class MobileApiResponse {
  final int statusCode;
  final dynamic data;
  const MobileApiResponse(this.statusCode, this.data);
}

typedef MobileHttpTransport = Future<MobileApiResponse> Function(
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? bearerToken,
});

class MobilePosResilienceClient {
  final String baseUrl;
  final MobileHttpTransport _transport;

  MobilePosResilienceClient(
    this.baseUrl, {
    required MobileHttpTransport transport,
  }) : _transport = transport;

  Future<MobilePosOutcome<MobilePosErrorIncidentDto>> reportIncident({
    required MobilePosIncidentType type,
    String? errorCode,
    String? deviceId,
    String? saleId,
    String? messageEn,
    String? messageBn,
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/error-incidents/report/',
        body: {
          'incident_type': type.value,
          if (errorCode != null) 'error_code': errorCode,
          if (deviceId != null) 'device_id': deviceId,
          if (saleId != null) 'sale_id': saleId,
          if (messageEn != null) 'message_en': messageEn,
          if (messageBn != null) 'message_bn': messageBn,
        },
        bearerToken: bearerToken,
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = res.data is Map ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};
        final dto = MobilePosErrorIncidentDto.fromJson(data);
        return MobilePosOutcome(
          uiState: MobilePosUiState.ready,
          data: dto,
          messageEn: dto.messageEn,
          messageBn: dto.messageBn,
        );
      } else if (res.statusCode == 403) {
        return const MobilePosOutcome(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: 'ERR_PERMISSION_DENIED',
          messageEn: 'Permission denied to report incident.',
          messageBn: 'ত্রুটি রিপোর্ট করার অনুমতি নেই।',
        );
      } else {
        return MobilePosOutcome(
          uiState: MobilePosUiState.error,
          errorCode: 'ERR_HTTP_${res.statusCode}',
          messageEn: 'Incident report failed with status ${res.statusCode}',
          messageBn: 'ত্রুটি রিপোর্ট প্রক্রিয়া ব্যর্থ হয়েছে।',
        );
      }
    } catch (e) {
      return MobilePosOutcome(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network unreachable: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosErrorIncidentDto>> resolveIncident({
    required String incidentId,
    required MobilePosRecoveryAction action,
    Map<String, dynamic>? recoveryPayload,
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/error-incidents/$incidentId/resolve/',
        body: {
          'recovery_action': action.value,
          'recovery_payload': recoveryPayload ?? {},
        },
        bearerToken: bearerToken,
      );

      if (res.statusCode == 200) {
        final data = res.data is Map ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};
        final dto = MobilePosErrorIncidentDto.fromJson(data);
        return MobilePosOutcome(
          uiState: MobilePosUiState.ready,
          data: dto,
          messageEn: 'Incident resolved via ${action.value}',
          messageBn: 'সমস্যা সফলভাবে সমাধান করা হয়েছে।',
        );
      } else if (res.statusCode == 403) {
        return const MobilePosOutcome(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: 'ERR_PERMISSION_DENIED',
          messageEn: 'Permission denied to resolve incident.',
          messageBn: 'ত্রুটি সমাধান করার অনুমতি নেই।',
        );
      } else {
        return MobilePosOutcome(
          uiState: MobilePosUiState.error,
          errorCode: 'ERR_HTTP_${res.statusCode}',
          messageEn: 'Failed to resolve incident',
          messageBn: 'ত্রুটি সমাধান প্রক্রিয়া ব্যর্থ হয়েছে।',
        );
      }
    } catch (e) {
      return MobilePosOutcome(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network unreachable: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<List<MobileStockAlternativeDto>>> fetchStockAlternatives({
    required String productId,
    int requestedQuantity = 1,
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'GET',
        '/api/v2/pos/error-incidents/stock-alternatives/?product_id=$productId&requested_quantity=$requestedQuantity',
        bearerToken: bearerToken,
      );

      if (res.statusCode == 200) {
        final data = res.data is Map ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};
        final list = (data['alternatives'] as List<dynamic>? ?? [])
            .map((e) => MobileStockAlternativeDto.fromJson(e as Map<String, dynamic>))
            .toList();
        return MobilePosOutcome(
          uiState: MobilePosUiState.ready,
          data: list,
          messageEn: 'Found ${list.length} alternative batch(es)',
          messageBn: '${list.length} টি বিকল্প ব্যাচ পাওয়া গেছে',
        );
      } else {
        return MobilePosOutcome(
          uiState: MobilePosUiState.error,
          errorCode: 'ERR_HTTP_${res.statusCode}',
          messageEn: 'Could not fetch alternatives',
          messageBn: 'বিকল্প ব্যাচ অনুসন্ধান ব্যর্থ হয়েছে',
        );
      }
    } catch (e) {
      return MobilePosOutcome(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network unreachable: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }
}
