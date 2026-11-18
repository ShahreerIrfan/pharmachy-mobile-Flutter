import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_offline_rx_policy_client.dart';

void main() {
  test('P311 MobileOfflineRxPolicyClient parses antimicrobial/revoked tokens, EN/BN badges, 403 & offline cache', () {
    final client = MobileOfflineRxPolicyClient();
    final items = client.parseTokensResponse({
      'tokens': [
        {
          'token_id': 'orxtok-1',
          'device_id': 'POS-01',
          'product_id': 'med-abx',
          'rx_category': 'ANTIMICROBIAL_RX',
          'approved_max_units': 6,
          'dispensed_units': 4,
          'remaining_units': 2,
          'authorized_total_bdt': '210.00',
          'status': 'ACTIVE',
          'antimicrobial_register_required': true,
        },
        {
          'token_id': 'orxtok-2',
          'device_id': 'POS-01',
          'product_id': 'med-rx',
          'rx_category': 'STANDARD_RX',
          'approved_max_units': 10,
          'dispensed_units': 0,
          'remaining_units': 10,
          'authorized_total_bdt': '55.00',
          'status': 'REVOKED',
          'antimicrobial_register_required': false,
        },
      ],
    });

    expect(client.uiState, OfflineRxPolicyUiState.loaded);
    expect(items.length, 2);
    expect(items[0].localizedStatusBadge()['bn'], contains('রেজিস্টার আবশ্যক'));
    expect(items[1].localizedStatusBadge()['en'], 'Revoked — Blocked Offline');

    client.handleHttpError(403);
    expect(client.uiState, OfflineRxPolicyUiState.permissionDenied);
    expect(client.lastErrorBn, contains('ফার্মাসিস্ট/ম্যানেজার অনুমতি'));

    final fallback = client.loadOfflineFallback();
    expect(client.uiState, OfflineRxPolicyUiState.offlineCache);
    expect(fallback.length, 2);
  });
}
