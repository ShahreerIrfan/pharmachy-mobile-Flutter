import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_sync_checkpoint_client.dart';

void main() {
  test('P308 MobileSyncCheckpointClient parses decoupled watermarks, EN/BN badges, 403 & offline fallback', () {
    final client = MobileSyncCheckpointClient();
    final items = client.parseWatermarksResponse({
      'watermarks': [
        {
          'watermark_id': 'syncwm-1',
          'device_id': 'POS-CP-01',
          'pull_applied_sequence_no': 12,
          'push_acked_sequence_no': 5,
          'push_monetary_reconciled_bdt': '420.50',
          'recovery_epoch': 2,
          'pull_lag_events': 0,
        },
      ],
    });

    expect(client.uiState, CheckpointUiState.loaded);
    expect(items.length, 1);
    expect(items.first.pushMonetaryReconciledBdt, '420.50');
    expect(items.first.localizedHealthBadge()['en'], contains('Pull #12'));
    expect(items.first.localizedHealthBadge()['bn'], contains('পুশ #5'));

    client.handleHttpError(403);
    expect(client.uiState, CheckpointUiState.permissionDenied);
    expect(client.lastErrorBn, contains('অনুমতি নেই'));

    final fallback = client.loadOfflineFallback();
    expect(client.uiState, CheckpointUiState.offlineCache);
    expect(fallback.length, 1);
  });
}
