// mobile_canonical_ack_test.dart
// Architecture Decision: ADR-0306 (P306).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_canonical_ack_client.dart';

void main() {
  group('P306 MobileCanonicalAckClient', () {
    test('01. Parses committed & replay-safe acks with EN/BN labels', () {
      final client = MobileCanonicalAckClient();
      final items = client.parseAcks({
        'acknowledgments': [
          {
            'ack_id': 'cack-1',
            'idempotency_key': 'idem-1',
            'local_aggregate_ref': 'OFF-1',
            'canonical_entity_id': 'SRV-INV-01',
            'disposition': 'COMMITTED',
            'monetary_total_bdt': '120.00',
            'replay_count': 0,
          },
          {
            'ack_id': 'cack-2',
            'idempotency_key': 'idem-2',
            'local_aggregate_ref': 'OFF-2',
            'canonical_entity_id': 'SRV-INV-02',
            'disposition': 'REPLAY_IDEMPOTENT',
            'monetary_total_bdt': '80.00',
            'replay_count': 2,
          },
        ],
      });
      expect(items.length, 2);
      expect(items[0].localizedDispositionBadge()['bn'], contains('SRV-INV-01'));
      expect(items[1].localizedDispositionBadge()['bn'], 'রিপ্লে-নিরাপদ নিশ্চিত');
      expect(client.uiState, AckUiState.loaded);
    });
  });
}
