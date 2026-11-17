import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';

void main() {
  group('P237 - Mobile POS Daily Sales Close Tests', () {
    test('submitDailyClose parses successfully and returns ready state', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://127.0.0.1:8000',
        transport: (method, path, {body, bearerToken}) async {
          expect(method, equals('POST'));
          expect(path, contains('/api/v2/pos/daily-close/submit/'));
          expect((body as Map)['actual_drawer_cash_bdt'], equals('5000.00'));
          return MobilePosHttpResponse(
            statusCode: 201,
            data: {
              'close_id': 'dcl-101',
              'close_number': 'DCL-BR01-20261116-XYZ1',
              'status': 'SUBMITTED',
              'gross_sales_bdt': '8000.00',
              'net_sales_bdt': '7600.00',
              'cash_sales_bdt': '5000.00',
              'digital_sales_bdt': '2600.00',
              'due_sales_bdt': '0.00',
              'expected_drawer_cash_bdt': '5000.00',
              'actual_drawer_cash_bdt': '5000.00',
              'cash_variance_bdt': '0.00',
              'is_ledger_balanced': true,
            },
          );
        },
      );

      final outcome = await client.submitDailyClose(
        closingDate: '2026-11-16',
        actualDrawerCashBdt: '5000.00',
        notes: 'Cashier end of day physical drawer count',
      );

      expect(outcome.uiState, equals(MobilePosUiState.ready));
      expect(outcome.data, isNotNull);
      expect(outcome.data!.closeId, equals('dcl-101'));
      expect(outcome.data!.status, equals('SUBMITTED'));
      expect(outcome.data!.netSalesBdt, equals('7600.00'));
      expect(outcome.data!.isLedgerBalanced, isTrue);
    });

    test('approveDailyClose handles manager sign-off and seals digest', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://127.0.0.1:8000',
        transport: (method, path, {body, bearerToken}) async {
          expect(method, equals('POST'));
          expect(path, contains('/api/v2/pos/daily-close/dcl-101/approve/'));
          return MobilePosHttpResponse(
            statusCode: 200,
            data: {
              'close_id': 'dcl-101',
              'close_number': 'DCL-BR01-20261116-XYZ1',
              'status': 'APPROVED',
              'sha256_hash': 'feedbeef0123456789abcdef0123456789abcdef0123456789abcdef01234567',
              'is_ledger_balanced': true,
            },
          );
        },
      );

      final outcome = await client.approveDailyClose(
        closeId: 'dcl-101',
        managerNotes: 'Manager drawer verified and approved',
      );

      expect(outcome.uiState, equals(MobilePosUiState.ready));
      expect(outcome.data, isNotNull);
      expect(outcome.data!.status, equals('APPROVED'));
      expect(outcome.data!.sha256Hash, isNotEmpty);
    });

    test('approveDailyClose maps 403 to permissionDenied state', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://127.0.0.1:8000',
        transport: (method, path, {body, bearerToken}) async {
          return MobilePosHttpResponse(
            statusCode: 403,
            data: {
              'error_code': 'ERR_PERMISSION_DENIED',
              'message_en': 'Only Branch Managers or Pharmacy Owners can approve daily sales close.',
            },
          );
        },
      );

      final outcome = await client.approveDailyClose(
        closeId: 'dcl-101',
      );

      expect(outcome.uiState, equals(MobilePosUiState.permissionDenied));
      expect(outcome.errorCode, equals('ERR_PERMISSION_DENIED'));
    });
  });
}
