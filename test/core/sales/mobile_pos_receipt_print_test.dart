import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';

void main() {
  group('Mobile POS Receipt Print DTO & Tests (P232)', () {
    test('MobileReceiptPrintResponse parsed correctly with duplicate watermark and printer status', () {
      final json = {
        'print_log_id': 'log-001',
        'sale_id': 'sale-123',
        'invoice_number': 'INV-DHK-202611-0001',
        'jobType': 'REPRINT_DUPLICATE',
        'format': '80MM',
        'reprint_sequence': 1,
        'reprint_reason': 'Customer requested copy for insurance',
        'watermark_text': '*** DUPLICATE RECEIPT / পুনর্মুদ্রণ কপি #1 ***',
        'printer_status': 'READY',
        'raw_text': '=== INVOICE ===\n*** DUPLICATE RECEIPT ***\nTotal: 100.00 BDT',
        'printed_at': '2026-11-16T14:30:00Z',
        'payload': {
          'invoice_number': 'INV-DHK-202611-0001',
          'total_bdt': '100.00',
        },
      };

      final response = MobileReceiptPrintResponse.fromJson(json);

      expect(response.printLogId, 'log-001');
      expect(response.saleId, 'sale-123');
      expect(response.invoiceNumber, 'INV-DHK-202611-0001');
      expect(response.format, '80MM');
      expect(response.reprintSequence, 1);
      expect(response.reprintReason, 'Customer requested copy for insurance');
      expect(response.watermarkText, contains('DUPLICATE RECEIPT'));
      expect(response.printerStatus, 'READY');
      expect(response.rawText, contains('DUPLICATE RECEIPT'));
      expect(response.payload['total_bdt'], '100.00');
    });

    test('MobileReceiptPrintResponse parsed for offline pending sync receipt', () {
      final json = {
        'print_log_id': 'log-002',
        'sale_id': 'sale-off-456',
        'invoice_number': 'INV-OFF-202611-0002',
        'job_type': 'ORIGINAL_PRINT',
        'format': '58MM',
        'reprint_sequence': 0,
        'watermark_text': '*** PENDING CLOUD CONFIRMATION / ক্লাউড কনফার্মেশন অপেক্ষমান ***',
        'printer_status': 'READY',
        'raw_text': '*** PENDING CLOUD CONFIRMATION ***\nTotal: 50.00 BDT',
        'printed_at': '2026-11-16T14:35:00Z',
      };

      final response = MobileReceiptPrintResponse.fromJson(json);

      expect(response.format, '58MM');
      expect(response.reprintSequence, 0);
      expect(response.watermarkText, contains('PENDING CLOUD CONFIRMATION'));
    });
  });
}
