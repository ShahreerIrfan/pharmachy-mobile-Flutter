import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';

void main() {
  group('P234 - Mobile POS Sale Return and Safety Disposition Tests', () {
    test('MobileSaleReturnDto correctly parses JSON with restockable line', () {
      final json = {
        'return_id': 'ret-uuid-001',
        'return_number': 'RET-202611-0001',
        'original_sale_id': 'sale-uuid-999',
        'original_order_number': 'POS-202611-0042',
        'shift_id': 'shift-uuid-555',
        'status': 'COMPLETED',
        'refund_method': 'CASH',
        'total_refund_amount_bdt': '150.00',
        'reason': 'Patient purchased wrong dosage',
        'customer_name': 'Rahim Uddin',
        'customer_phone': '01711000000',
        'processed_by_name': 'Admin Pharmacist',
        'created_at': '2026-11-16T10:00:00Z',
        'lines': [
          {
            'return_line_id': 'line-uuid-01',
            'sale_line_id': 'sale-line-01',
            'product_id': 'prod-01',
            'product_brand_name': 'Napa Extra 500mg',
            'generic_name': 'Paracetamol + Caffeine',
            'original_batch_id': 'batch-01',
            'batch_number': 'BX-2026-09',
            'packaging_unit': 'STRIP',
            'conversion_factor': 10,
            'quantity_units': 1,
            'base_units_returned': 10,
            'unit_price_bdt': '150.00',
            'refund_amount_bdt': '150.00',
            'safety_disposition': 'RESTOCKABLE',
            'disposition_notes': 'Unopened blister packaging verified by pharmacist',
            'restocked_to_inventory': true,
          }
        ],
      };

      final dto = MobileSaleReturnDto.fromJson(json);

      expect(dto.returnId, equals('ret-uuid-001'));
      expect(dto.returnNumber, equals('RET-202611-0001'));
      expect(dto.refundMethod, equals('CASH'));
      expect(dto.totalRefundAmountBdt, equals('150.00'));
      expect(dto.lines.length, equals(1));

      final line = dto.lines.first;
      expect(line.productBrandName, equals('Napa Extra 500mg'));
      expect(line.batchNumber, equals('BX-2026-09'));
      expect(line.packagingUnit, equals('STRIP'));
      expect(line.baseUnitsReturned, equals(10));
      expect(line.safetyDisposition, equals('RESTOCKABLE'));
      expect(line.restockedToInventory, isTrue);
    });

    test('MobileSaleReturnDto correctly parses quarantined/damaged disposition', () {
      final json = {
        'return_id': 'ret-uuid-002',
        'return_number': 'RET-202611-0002',
        'original_sale_id': 'sale-uuid-999',
        'original_order_number': 'POS-202611-0042',
        'status': 'COMPLETED',
        'refund_method': 'BKASH',
        'total_refund_amount_bdt': '80.00',
        'created_at': '2026-11-16T10:15:00Z',
        'lines': [
          {
            'return_line_id': 'line-uuid-02',
            'sale_line_id': 'sale-line-02',
            'product_id': 'prod-02',
            'product_brand_name': 'Ace Plus',
            'generic_name': 'Paracetamol',
            'batch_number': 'ACE-881',
            'packaging_unit': 'TABLET',
            'conversion_factor': 1,
            'quantity_units': 5,
            'base_units_returned': 5,
            'unit_price_bdt': '16.00',
            'refund_amount_bdt': '80.00',
            'safety_disposition': 'DAMAGED_DESTROYED',
            'disposition_notes': 'Broken seal reported by customer',
            'restocked_to_inventory': false,
          }
        ],
      };

      final dto = MobileSaleReturnDto.fromJson(json);
      expect(dto.refundMethod, equals('BKASH'));
      expect(dto.lines.first.safetyDisposition, equals('DAMAGED_DESTROYED'));
      expect(dto.lines.first.restockedToInventory, isFalse);
    });
  });
}
