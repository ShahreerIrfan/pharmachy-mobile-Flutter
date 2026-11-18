import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_stock_allocation_policy_client.dart';

void main() {
  test('P310 MobileStockAllocationPolicyClient parses oversell disputes, EN/BN badges, 403 & offline fallback', () {
    final client = MobileStockAllocationPolicyClient();
    final items = client.parseDisputesResponse({
      'disputes': [
        {
          'dispute_id': 'osdisp-1',
          'device_id': 'POS-02',
          'batch_id': 'bat-1',
          'available_units_at_reconcile': 3,
          'requested_units': 6,
          'oversell_shortage_units': 3,
          'disputed_cost_bdt': '13.50',
          'status': 'OPEN',
          'posted_records_preserved': true,
        },
        {
          'dispute_id': 'osdisp-2',
          'device_id': 'POS-03',
          'batch_id': 'bat-2',
          'available_units_at_reconcile': 0,
          'requested_units': 2,
          'oversell_shortage_units': 2,
          'disputed_cost_bdt': '9.00',
          'status': 'RESOLVED_AUDITED_REVERSAL',
          'posted_records_preserved': true,
        },
      ],
    });

    expect(client.uiState, StockPolicyUiState.loaded);
    expect(items.length, 2);
    expect(items[0].postedRecordsPreserved, true);
    expect(items[0].localizedStatusBadge()['bn'], contains('ডিসপুট ওপেন'));
    expect(items[1].localizedStatusBadge()['en'], 'Resolved — Audited Reversal');

    client.handleHttpError(403);
    expect(client.uiState, StockPolicyUiState.permissionDenied);
    expect(client.lastErrorBn, contains('ম্যানেজার অনুমতি'));

    final fallback = client.loadOfflineFallback();
    expect(client.uiState, StockPolicyUiState.offlineCache);
    expect(fallback.length, 2);
  });
}
