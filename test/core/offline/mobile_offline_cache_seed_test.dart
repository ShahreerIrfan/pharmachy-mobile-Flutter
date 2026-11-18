// mobile_offline_cache_seed_test.dart
// Architecture Decision: ADR-0303 (P303).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_offline_cache_seed_client.dart';

void main() {
  group('P303 MobileOfflineCacheSeedClient', () {
    test('01. Parses applied seed history with localized BN badge', () {
      final client = MobileOfflineCacheSeedClient();
      final items = client.parseSeedHistory({
        'seeds': [
          {
            'seed_id': 'oseed-1',
            'device_id': 'POS-1',
            'snapshot_version': 3,
            'consistency_token': 'abc',
            'catalog_count': 250,
            'batch_stock_count': 410,
            'status': 'APPLIED',
          }
        ],
      });
      expect(items.length, 1);
      expect(items.first.localizedStatusBadge()['bn'], contains('v3'));
      expect(client.uiState, SeedUiState.loaded);
    });

    test('02. Offline fallback returns cached seeds', () {
      final client = MobileOfflineCacheSeedClient();
      client.parseSeedHistory({'seeds': [{'seed_id': 'oseed-2', 'status': 'ISSUED'}]});
      expect(client.loadOfflineFallback().length, 1);
      expect(client.uiState, SeedUiState.offlineCache);
    });
  });
}
