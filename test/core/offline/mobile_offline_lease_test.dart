import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_offline_lease_client.dart';

void main() {
  test('P312 MobileOfflineLeaseClient parses clock-quarantined/expired recovery states, EN/BN badges & 403', () {
    final client = MobileOfflineLeaseClient();
    final items = client.parseLeasesResponse({
      'leases': [
        {
          'lease_id': 'sol-1',
          'device_id': 'POS-01',
          'plan_tier': 'PRO',
          'status': 'CLOCK_TAMPER_QUARANTINED',
          'new_offline_sales_allowed': false,
          'protected_sync_recovery_allowed': true,
          'pending_recovery_count': 4,
          'pending_recovery_bdt': '1475.80',
          'expires_at': '2026-11-20T00:00:00Z',
        },
        {
          'lease_id': 'sol-2',
          'device_id': 'POS-02',
          'plan_tier': 'STANDARD',
          'status': 'EXPIRED_RECOVERY_ONLY',
          'new_offline_sales_allowed': false,
          'protected_sync_recovery_allowed': true,
          'pending_recovery_count': 2,
          'pending_recovery_bdt': '320.00',
          'expires_at': '2026-11-17T00:00:00Z',
        },
      ],
    });

    expect(client.uiState, OfflineLeaseUiState.loaded);
    expect(items.length, 2);
    expect(items[0].newOfflineSalesAllowed, false);
    expect(items[0].protectedSyncRecoveryAllowed, true);
    expect(items[0].localizedStatusBadge()['bn'], contains('ঘড়ি পরিবর্তন শনাক্ত'));
    expect(items[1].localizedStatusBadge()['en'], contains('Protected Sync Recovery'));

    client.handleHttpError(403);
    expect(client.uiState, OfflineLeaseUiState.permissionDenied);

    final fallback = client.loadOfflineFallback();
    expect(client.uiState, OfflineLeaseUiState.offlineCache);
    expect(fallback.length, 2);
  });
}
