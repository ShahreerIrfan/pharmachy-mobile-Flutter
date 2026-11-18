import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_connectivity_client.dart';

void main() {
  test('P309 MobileConnectivityClient parses disconnected/degraded/reconnected states, EN/BN badges & 403', () {
    final client = MobileConnectivityClient();
    final items = client.parseSnapshotsResponse({
      'snapshots': [
        {
          'snapshot_id': 'conn-1',
          'device_id': 'POS-01',
          'connectivity_state': 'DISCONNECTED',
          'cloud_stock_authoritative': false,
          'latency_ms': 0,
          'packet_loss_pct': '100.00',
          'pending_outbox_count': 4,
          'pending_outbox_bdt': '650.25',
          'pull_lag_events': 3,
          'last_successful_sync_at': '2026-11-18T11:00:00Z',
          'status_label_en': 'Offline — Local Queue Active (4 pending)',
          'status_label_bn': 'অফলাইন — লোকাল কিউ সক্রিয় (4টি পেন্ডিং)',
        },
        {
          'snapshot_id': 'conn-2',
          'device_id': 'POS-02',
          'connectivity_state': 'DEGRADED',
          'cloud_stock_authoritative': false,
          'latency_ms': 2100,
          'packet_loss_pct': '14.50',
          'pending_outbox_count': 1,
          'pending_outbox_bdt': '120.00',
          'pull_lag_events': 0,
          'status_label_en': 'Degraded Network — Sync Delayed (1 pending)',
          'status_label_bn': 'দুর্বল নেটওয়ার্ক — সিঙ্ক বিলম্বিত (1টি পেন্ডিং)',
        },
      ],
    });

    expect(client.uiState, ConnectivityUiState.loaded);
    expect(items.length, 2);
    expect(items[0].cloudStockAuthoritative, false);
    expect(items[0].localizedBadge()['bn'], 'অফলাইন (4টি কিউতে)');
    expect(items[1].localizedBadge()['en'], 'Degraded (2100ms)');

    client.handleHttpError(403);
    expect(client.uiState, ConnectivityUiState.permissionDenied);
    expect(client.lastErrorBn, contains('অ্যাক্সেস অনুমোদিত নয়'));

    final cached = client.loadOfflineFallback();
    expect(client.uiState, ConnectivityUiState.offlineCache);
    expect(cached.length, 2);
  });
}
