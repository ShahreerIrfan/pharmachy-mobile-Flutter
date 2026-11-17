import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';

void main() {
  group('P231: Mobile POS Invoice Number Policy & Sequence Preview', () {
    test('1. Client previews next formatted branch/device invoice number', () async {
      final client = MobilePosDomainClient(
        baseUrl: 'http://localhost:8000',
        transport: (method, path, {body, bearerToken}) async {
          if (method == 'GET' && path.contains('/api/v2/pos/invoice-policies/preview-next/')) {
            return const MobilePosHttpResponse(
              statusCode: 200,
              data: <String, dynamic>{
                'invoice_number': 'INV-DHK01-MOB01-20261116-0001',
                'policy_id': 'pol-dhk-01',
                'sequence': 1,
                'period_key': '20261116',
                'branch_code': 'DHK01',
                'device_code': 'MOB01',
                'is_reserved': false,
              },
            );
          }
          return const MobilePosHttpResponse(
            statusCode: 404,
            data: <String, dynamic>{'error_code': 'ERR_NOT_FOUND'},
          );
        },
      );

      final outcome = await client.previewNextInvoiceNumber(
        branchId: 'br-dhk',
        deviceNs: 'MOB01',
      );

      expect(outcome.uiState, MobilePosUiState.ready);
      expect(outcome.data, isNotNull);
      expect(outcome.data!.invoiceNumber, 'INV-DHK01-MOB01-20261116-0001');
      expect(outcome.data!.sequence, 1);
      expect(outcome.data!.branchCode, 'DHK01');
      expect(outcome.data!.deviceCode, 'MOB01');
      expect(outcome.data!.isReserved, isFalse);
    });
  });
}
