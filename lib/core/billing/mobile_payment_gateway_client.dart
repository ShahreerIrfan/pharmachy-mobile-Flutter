// lib/core/billing/mobile_payment_gateway_client.dart
// Architecture Decision: ADR-0007, ADR-0024 & ADR-0089
// Phase 05: Basic/Standard/Pro Subscription & Billing (P089)

enum MobileGatewayEventStatus {
  received,
  processed,
  duplicate,
  failed,
  signatureInvalid,
}

class MobileGatewayWebhookEventModel {
  final String eventId;
  final String gatewayName;
  final String eventType;
  final String idempotencyKey;
  final String gatewayPaymentId;
  final String invoiceNumber;
  final double amountBdt;
  final String currency;
  final MobileGatewayEventStatus status;
  final bool signatureVerified;
  final DateTime timestamp;
  final String? errorMessage;

  const MobileGatewayWebhookEventModel({
    required this.eventId,
    required this.gatewayName,
    required this.eventType,
    required this.idempotencyKey,
    required this.gatewayPaymentId,
    required this.invoiceNumber,
    required this.amountBdt,
    this.currency = 'BDT',
    required this.status,
    required this.signatureVerified,
    required this.timestamp,
    this.errorMessage,
  });

  bool get isProcessed => status == MobileGatewayEventStatus.processed;
  bool get isDuplicate => status == MobileGatewayEventStatus.duplicate;
  bool get isFailed => status == MobileGatewayEventStatus.failed || status == MobileGatewayEventStatus.signatureInvalid;

  static MobileGatewayEventStatus parseStatus(String? statusStr) {
    final clean = (statusStr ?? '').toUpperCase().trim();
    switch (clean) {
      case 'PROCESSED':
        return MobileGatewayEventStatus.processed;
      case 'DUPLICATE':
        return MobileGatewayEventStatus.duplicate;
      case 'FAILED':
        return MobileGatewayEventStatus.failed;
      case 'SIGNATURE_INVALID':
        return MobileGatewayEventStatus.signatureInvalid;
      case 'RECEIVED':
      default:
        return MobileGatewayEventStatus.received;
    }
  }

  static String statusToString(MobileGatewayEventStatus status) {
    switch (status) {
      case MobileGatewayEventStatus.processed:
        return 'PROCESSED';
      case MobileGatewayEventStatus.duplicate:
        return 'DUPLICATE';
      case MobileGatewayEventStatus.failed:
        return 'FAILED';
      case MobileGatewayEventStatus.signatureInvalid:
        return 'SIGNATURE_INVALID';
      case MobileGatewayEventStatus.received:
      default:
        return 'RECEIVED';
    }
  }

  static String formatBdt(double amount) {
    return '৳ ${amount.toStringAsFixed(2)}';
  }

  factory MobileGatewayWebhookEventModel.fromJson(Map<String, dynamic> json) {
    return MobileGatewayWebhookEventModel(
      eventId: json['event_id'] ?? '',
      gatewayName: json['gateway_name'] ?? 'BKASH',
      eventType: json['event_type'] ?? 'PAYMENT_COMPLETED',
      idempotencyKey: json['idempotency_key'] ?? '',
      gatewayPaymentId: json['gateway_payment_id'] ?? '',
      invoiceNumber: json['invoice_number'] ?? '',
      amountBdt: double.parse((json['amount_bdt'] ?? 0.0).toString()),
      currency: json['currency'] ?? 'BDT',
      status: parseStatus(json['status']?.toString()),
      signatureVerified: json['signature_verified'] ?? false,
      timestamp: DateTime.parse(json['timestamp'] ?? '1970-01-01T00:00:00Z'),
      errorMessage: json['error_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'gateway_name': gatewayName,
      'event_type': eventType,
      'idempotency_key': idempotencyKey,
      'gateway_payment_id': gatewayPaymentId,
      'invoice_number': invoiceNumber,
      'amount_bdt': amountBdt.toStringAsFixed(2),
      'currency': currency,
      'status': statusToString(status),
      'signature_verified': signatureVerified,
      'timestamp': timestamp.toIso8601String(),
      'error_message': errorMessage,
    };
  }
}
