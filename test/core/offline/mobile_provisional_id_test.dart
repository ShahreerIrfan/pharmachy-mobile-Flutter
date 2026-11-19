import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_provisional_id_client.dart';

void main() {
  test('P315 MobileProvisionalIdClient parses mappings, bidirectional local lookup & 403', () {
    final client = MobileProvisionalIdClient();

    final mappings = client.parseMappingsResponse({
      'results': [
        {
          'mapping_id': 'pim-1',
          'tenant_id': 'ten-1',
          'branch_id': 'br-1',
          'device_id': 'POS-01',
          'entity_type': 'INVOICE',
          'provisional_id': 'PROV-INVO-12345',
          'canonical_id': 'CAN-INV-99999',
          'idempotency_key': 'idem-1',
          'reconciliation_status': 'RECONCILED',
          'mapped_at': '2026-11-19T11:00:00Z',
        },
        {
          'mapping_id': 'pim-2',
          'tenant_id': 'ten-1',
          'branch_id': 'br-1',
          'device_id': 'POS-01',
          'entity_type': 'CUSTOMER',
          'provisional_id': 'PROV-CUST-54321',
          'canonical_id': 'CAN-CUS-88888',
          'idempotency_key': 'idem-2',
          'reconciliation_status': 'RECONCILED',
          'mapped_at': '2026-11-19T11:05:00Z',
        },
      ]
    });

    expect(client.uiState, MobileProvisionalUiState.loaded);
    expect(mappings.length, 2);

    // Bilingual badges
    expect(mappings[0].localizedTypeBadge()['en'], 'Sale Invoice');
    expect(mappings[0].localizedTypeBadge()['bn'], 'বিক্রয় চালান');
    expect(mappings[1].localizedTypeBadge()['en'], 'Customer');
    expect(mappings[1].localizedTypeBadge()['bn'], 'ক্রেতা');

    // Bidirectional Local Lookup
    final byProv = client.lookupLocally('PROV-INVO-12345');
    expect(byProv, isNotNull);
    expect(byProv!.canonicalId, 'CAN-INV-99999');

    final byCanon = client.lookupLocally('CAN-INV-99999');
    expect(byCanon, isNotNull);
    expect(byCanon!.provisionalId, 'PROV-INVO-12345');

    // 403 Permission Denied handling
    client.handleHttpError(403);
    expect(client.uiState, MobileProvisionalUiState.permissionDenied);
    expect(client.lastErrorBn, contains('অনুমতি প্রয়োজন'));

    // Offline fallback
    final fallback = client.loadOfflineFallback();
    expect(client.uiState, MobileProvisionalUiState.offlineCache);
    expect(fallback.length, 2);
  });
}
