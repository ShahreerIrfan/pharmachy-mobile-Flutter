import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';

void main() {
  group('P236 - Mobile POS Discount Approval & Offline Boundaries Tests', () {
    test('approveDiscount rejects short reasons (< 3 chars)', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://127.0.0.1:8000',
        transport: (method, path, {body, bearerToken}) async {
          return MobilePosHttpResponse(statusCode: 200, data: {});
        },
      );

      final outcome = await client.approveDiscount(
        saleId: 'sale-001',
        discountReason: 'no',
      );

      expect(outcome.uiState, equals(MobilePosUiState.error));
      expect(outcome.errorCode, equals('ERR_REASON_REQUIRED'));
      expect(outcome.messageBn, contains('কমপক্ষে ৩ অক্ষরের কারণ'));
    });

    test('approveDiscount rejects offline discount exceeding 20% ceiling', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://127.0.0.1:8000',
        transport: (method, path, {body, bearerToken}) async {
          return MobilePosHttpResponse(statusCode: 200, data: {});
        },
      );

      final outcome = await client.approveDiscount(
        saleId: 'sale-001',
        discountReason: 'VIP loyal customer clearance discount',
        discountRatePct: '25.00',
        isOffline: true,
      );

      expect(outcome.uiState, equals(MobilePosUiState.error));
      expect(outcome.errorCode, equals('ERR_OFFLINE_DISCOUNT_CEILING_EXCEEDED'));
      expect(outcome.messageBn, contains('অফলাইনে ২০%-এর বেশি'));
    });

    test('approveDiscount succeeds with valid manager approval', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://127.0.0.1:8000',
        transport: (method, path, {body, bearerToken}) async {
          expect(method, equals('POST'));
          expect(path, contains('/api/v2/pos/sales/sale-101/approve-discount/'));
          expect((body as Map)['discount_rate_pct'], equals('12.50'));
          return MobilePosHttpResponse(
            statusCode: 200,
            data: {
              'sale': {
                'sale_id': 'sale-101',
                'order_number': 'POS-20261116-0001',
                'lifecycle_state': 'DRAFT',
                'discount_type': 'PERCENTAGE',
                'discount_rate_pct': '12.50',
                'subtotal_bdt': '200.00',
                'grand_total_bdt': '175.00',
                'lines': [],
              }
            },
          );
        },
      );

      final outcome = await client.approveDiscount(
        saleId: 'sale-101',
        discountReason: 'Management authorized clinic courtesy',
        discountRatePct: '12.50',
      );

      expect(outcome.uiState, equals(MobilePosUiState.ready));
      expect(outcome.data, isNotNull);
      expect(outcome.data!.grandTotalBdt, equals('175.00'));
    });
  });
}
