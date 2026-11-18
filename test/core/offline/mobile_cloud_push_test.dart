// mobile_cloud_push_test.dart
// Architecture Decision: ADR-0305 (P305).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_cloud_push_client.dart';

void main() {
  group('P305 MobileCloudPushClient', () {
    test('01. Parses signed push batch history with BN badge', () {
      final client = MobileCloudPushClient();
      final items = client.parseBatchList({
        'batches': [
          {
            'push_batch_id': 'pushb-1',
            'client_batch_id': 'cli-b-1',
            'device_id': 'POS-01',
            'event_count': 12,
            'accepted_count': 12,
            'conflict_count': 0,
            'signature_verified': true,
            'status': 'COMPLETED',
          }
        ],
      });
      expect(items.length, 1);
      expect(items.first.signatureVerified, isTrue);
      expect(items.first.localizedStatusBadge()['bn'], contains('12/12'));
      expect(client.uiState, PushMonitorUiState.loaded);
    });

    test('02. Offline fallback restores cached push batches', () {
      final client = MobileCloudPushClient();
      client.parseBatchList({
        'batches': [
          {'push_batch_id': 'pushb-2', 'status': 'PARTIAL_CONFLICT', 'conflict_count': 2}
        ],
      });
      final cached = client.loadOfflineFallback();
      expect(cached.first.localizedStatusBadge()['en'], contains('2'));
      expect(client.uiState, PushMonitorUiState.offlineCache);
    });
  });
}
