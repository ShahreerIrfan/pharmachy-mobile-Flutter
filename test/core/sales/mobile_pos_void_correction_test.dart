import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';

void main() {
  group('P235 - Mobile POS Voids, Corrections & Deletion Prohibition Tests', () {
    test('voidSale rejects execution client-side when reason is empty', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://127.0.0.1:8000',
        transport: (method, path, {body, bearerToken}) async {
          return MobilePosHttpResponse(statusCode: 200, data: {});
        },
      );

      final outcome = await client.voidSale(
        saleId: 'sale-001',
        reason: '   ',
      );

      expect(outcome.uiState, equals(MobilePosUiState.error));
      expect(outcome.errorCode, equals('ERR_REASON_REQUIRED'));
      expect(outcome.messageBn, contains('সুনির্দিষ্ট কারণ'));
    });

    test('correctSale rejects execution client-side when reason is empty', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://127.0.0.1:8000',
        transport: (method, path, {body, bearerToken}) async {
          return MobilePosHttpResponse(statusCode: 200, data: {});
        },
      );

      final outcome = await client.correctSale(
        saleId: 'sale-001',
        reason: '',
      );

      expect(outcome.uiState, equals(MobilePosUiState.error));
      expect(outcome.errorCode, equals('ERR_REASON_REQUIRED'));
    });

    test('voidSale returns ready outcome on successful server response', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://127.0.0.1:8000',
        transport: (method, path, {body, bearerToken}) async {
          expect(method, equals('POST'));
          expect(path, contains('/api/v2/pos/sales/sale-101/void/'));
          expect((body as Map)['reason'], equals('Customer walked out before payment'));
          return MobilePosHttpResponse(
            statusCode: 200,
            data: {
              'sale_id': 'sale-101',
              'order_number': 'POS-20261116-0001',
              'lifecycle_state': 'VOIDED',
              'subtotal_bdt': '250.00',
              'grand_total_bdt': '250.00',
              'paid_amount_bdt': '0.00',
              'due_amount_bdt': '0.00',
              'lines': [],
            },
          );
        },
      );

      final outcome = await client.voidSale(
        saleId: 'sale-101',
        reason: 'Customer walked out before payment',
      );

      expect(outcome.uiState, equals(MobilePosUiState.ready));
      expect(outcome.data, isNotNull);
      expect(outcome.data!.saleId, equals('sale-101'));
      expect(outcome.data!.lifecycleState, equals(MobilePosLifecycleState.voided));
    });
  });
}
