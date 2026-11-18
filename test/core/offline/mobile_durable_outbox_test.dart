// mobile_durable_outbox_test.dart
// Architecture Decision: ADR-0304 (P304).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_durable_outbox_client.dart';

void main() {
  group('P304 MobileDurableOutboxClient', () {
    test('01. Parses receipts and counts open conflicts with BN label', () {
      final client = MobileDurableOutboxClient();
      final items = client.parseReceipts({
        'receipts': [
          {'receipt_id': 'obrc-1', 'sync_status': 'ACCEPTED', 'monetary_total_bdt': '150.00'},
          {
            'receipt_id': 'obrc-2',
            'sync_status': 'CONFLICT_NEEDS_REVIEW',
            'conflict_reason': 'ERR_TWO_DEVICE_STOCK_CONFLICT',
            'monetary_total_bdt': '300.00',
          },
        ],
      });
      expect(items.length, 2);
      expect(client.openConflictCount(), 1);
      expect(items[1].localizedSyncBadge()['bn'], 'কনফ্লিক্ট — পর্যালোচনা প্রয়োজন');
      expect(client.uiState, OutboxUiState.loaded);
    });
  });
}
