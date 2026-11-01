// test/core/billing/mobile_payment_gateway_client_test.dart
// Architecture Decision: ADR-0007, ADR-0024 & ADR-0089
// Phase 05: Basic/Standard/Pro Subscription & Billing (P089)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_payment_gateway_client.dart';

void main() {
  group('P089 - Mobile Payment Gateway Client Tests', () {
    test('Status parsing and state predicates evaluate correctly', () {
      final now = DateTime.utc(2026, 11, 1);

      final processedEvent = MobileGatewayWebhookEventModel(
        eventId: 'evt-001',
        gatewayName: 'BKASH',
        eventType: 'PAYMENT_COMPLETED',
        idempotencyKey: 'idemp-001',
        gatewayPaymentId: 'trx-001',
        invoiceNumber: 'INV-REN-202611-DHAKA-1029',
        amountBdt: 6825.00,
        status: MobileGatewayEventStatus.processed,
        signatureVerified: true,
        timestamp: now,
      );

      expect(processedEvent.isProcessed, isTrue);
      expect(processedEvent.isDuplicate, isFalse);
      expect(processedEvent.isFailed, isFalse);

      final duplicateEvent = MobileGatewayWebhookEventModel(
        eventId: 'evt-002',
        gatewayName: 'BKASH',
        eventType: 'PAYMENT_COMPLETED',
        idempotencyKey: 'idemp-001',
        gatewayPaymentId: 'trx-001',
        invoiceNumber: 'INV-REN-202611-DHAKA-1029',
        amountBdt: 6825.00,
        status: MobileGatewayEventStatus.duplicate,
        signatureVerified: true,
        timestamp: now,
      );

      expect(duplicateEvent.isDuplicate, isTrue);
      expect(duplicateEvent.isProcessed, isFalse);
    });

    test('JSON serialization and parsing handles full webhook event payload', () {
      final jsonMap = {
        'event_id': 'evt-ssl-9988',
        'gateway_name': 'SSLCOMMERZ',
        'event_type': 'PAYMENT_COMPLETED',
        'idempotency_key': 'idemp-ssl-7766',
        'gateway_payment_id': 'ssl-val-5544',
        'invoice_number': 'INV-REN-202611-CTG-8821',
        'amount_bdt': '157500.00',
        'currency': 'BDT',
        'status': 'PROCESSED',
        'signature_verified': true,
        'timestamp': '2026-11-01T12:00:00.000Z',
        'error_message': null,
      };

      final event = MobileGatewayWebhookEventModel.fromJson(jsonMap);
      expect(event.eventId, equals('evt-ssl-9988'));
      expect(event.gatewayName, equals('SSLCOMMERZ'));
      expect(event.amountBdt, equals(157500.00));
      expect(event.currency, equals('BDT'));
      expect(event.status, equals(MobileGatewayEventStatus.processed));
      expect(event.signatureVerified, isTrue);

      final serialized = event.toJson();
      expect(serialized['status'], equals('PROCESSED'));
      expect(serialized['amount_bdt'], equals('157500.00'));
    });

    test('formatBdt renders BDT symbol and 2 decimal places', () {
      expect(MobileGatewayWebhookEventModel.formatBdt(157500.0), equals('৳ 157500.00'));
    });
  });
}
