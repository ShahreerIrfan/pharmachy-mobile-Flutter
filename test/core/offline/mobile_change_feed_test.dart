import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_change_feed_client.dart';

void main() {
  test('P307 MobileChangeFeedClient parses incremental pull, tombstones, cursors, offline & 403 states', () {
    final client = MobileChangeFeedClient();
    final events = client.parsePullResponse({
      'events': [
        {
          'event_id': 'cfe-1',
          'sequence_no': 11,
          'entity_type': 'BATCH_STOCK',
          'entity_id': 'bat-rec-1',
          'operation': 'TOMBSTONE',
          'entity_version': 3,
          'monetary_impact_bdt': '0.00',
          'branch_id': 'br-1',
        },
        {
          'event_id': 'cfe-2',
          'sequence_no': 12,
          'entity_type': 'SALE_INVOICE',
          'entity_id': 'INV-REV-2',
          'operation': 'REVERSAL',
          'entity_version': 2,
          'monetary_impact_bdt': '-45.50',
          'branch_id': 'br-1',
        },
      ],
    });

    expect(client.uiState, ChangeFeedUiState.loaded);
    expect(events.length, 2);
    expect(events[0].localizedOperationBadge()['bn'], 'অপসারিত / রিকলকৃত');
    expect(events[1].localizedOperationBadge()['en'], 'Audited Reversal');
    expect(events[1].monetaryImpactBdt, '-45.50');

    final cursors = client.parseCursorsResponse({
      'cursors': [
        {
          'device_id': 'POS-01',
          'branch_id': 'br-1',
          'last_sequence_no': 10,
          'latest_server_sequence': 12,
          'lag_events': 2,
        },
      ],
    });
    expect(cursors.first.localizedLagStatus()['en'], '2 event(s) behind');
    expect(cursors.first.localizedLagStatus()['bn'], '2টি পরিবর্তন বাকি');

    client.handleHttpError(403);
    expect(client.uiState, ChangeFeedUiState.permissionDenied);
    expect(client.lastErrorBn, contains('অনুমতি নেই'));

    final cached = client.loadOfflineFallback();
    expect(client.uiState, ChangeFeedUiState.offlineCache);
    expect(cached.length, 2);
  });
}
