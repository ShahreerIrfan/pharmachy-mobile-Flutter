import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/sales/mobile_pos_domain_client.dart';

void main() {
  group('Mobile POS Cashier Shift Tests (P233)', () {
    test('MobileCashierShiftDto parses open shift with float and expected drawer', () {
      final json = {
        'shift_id': 'shf-m-001',
        'shift_number': 'SHF-DHK01-20261116-M001',
        'device_code': 'TAB01',
        'status': 'OPEN',
        'opening_float_bdt': '1500.00',
        'total_cash_sales_bdt': '3500.00',
        'total_payouts_bdt': '500.00',
        'expected_drawer_cash_bdt': '4500.00',
        'requires_manager_approval': false,
        'opened_at': '2026-11-16T08:30:00Z',
        'cash_movements': [
          {
            'movement_id': 'shm-01',
            'shift_id': 'shf-m-001',
            'movement_type': 'PAYOUT_EXPENSE',
            'amount_bdt': '500.00',
            'reason': 'Cleaning supplies',
            'created_at': '2026-11-16T10:00:00Z',
          }
        ],
      };

      final shift = MobileCashierShiftDto.fromJson(json);

      expect(shift.shiftId, 'shf-m-001');
      expect(shift.shiftNumber, 'SHF-DHK01-20261116-M001');
      expect(shift.status, 'OPEN');
      expect(shift.openingFloatBdt, '1500.00');
      expect(shift.totalCashSalesBdt, '3500.00');
      expect(shift.totalPayoutsBdt, '500.00');
      expect(shift.expectedDrawerCashBdt, '4500.00');
      expect(shift.requiresManagerApproval, isFalse);
      expect(shift.cashMovements.length, 1);
      expect(shift.cashMovements.first.amountBdt, '500.00');
      expect(shift.cashMovements.first.reason, 'Cleaning supplies');
    });

    test('MobileCashierShiftDto parses closed shift with variance requiring manager approval', () {
      final json = {
        'shift_id': 'shf-m-002',
        'shift_number': 'SHF-DHK01-20261116-M002',
        'device_code': 'TAB01',
        'status': 'PENDING_MANAGER_APPROVAL',
        'opening_float_bdt': '1500.00',
        'total_cash_sales_bdt': '3500.00',
        'total_payouts_bdt': '500.00',
        'expected_drawer_cash_bdt': '4500.00',
        'closing_cash_counted_bdt': '4400.00',
        'variance_bdt': '-100.00',
        'variance_reason': 'Cash drawer short by 100 BDT note',
        'requires_manager_approval': true,
        'opened_at': '2026-11-16T08:30:00Z',
        'closed_at': '2026-11-16T16:30:00Z',
      };

      final shift = MobileCashierShiftDto.fromJson(json);

      expect(shift.status, 'PENDING_MANAGER_APPROVAL');
      expect(shift.closingCashCountedBdt, '4400.00');
      expect(shift.varianceBdt, '-100.00');
      expect(shift.varianceReason, contains('short'));
      expect(shift.requiresManagerApproval, isTrue);
    });
  });
}
