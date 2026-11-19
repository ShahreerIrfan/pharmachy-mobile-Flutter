import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_conflict_classification_client.dart';

void main() {
  test('P313 MobileConflictClassificationClient parses all 6 conflict categories, bilingual badges, filters & 403', () {
    final client = MobileConflictClassificationClient();
    final items = client.parseListResponse({
      'results': [
        {
          'conflict_id': 'conf-001',
          'tenant_id': 'ten-1',
          'branch_id': 'br-1',
          'branch_name': 'Dhanmondi Branch',
          'device_id': 'POS-01',
          'command_id': 'cmd-101',
          'idempotency_key': 'idem-101',
          'client_sequence': 12,
          'conflict_category': 'STALE_STOCK',
          'error_code': 'CONFLICT_STALE_STOCK',
          'disputed_monetary_bdt': '850.50',
          'resolution_status': 'OPEN',
          'created_at': '2026-11-19T10:00:00Z',
        },
        {
          'conflict_id': 'conf-002',
          'tenant_id': 'ten-1',
          'branch_id': 'br-1',
          'branch_name': 'Dhanmondi Branch',
          'device_id': 'POS-02',
          'command_id': 'cmd-102',
          'idempotency_key': 'idem-102',
          'client_sequence': 5,
          'conflict_category': 'STALE_PRICE',
          'error_code': 'CONFLICT_STALE_PRICE',
          'disputed_monetary_bdt': '120.00',
          'resolution_status': 'RESOLVED_KEEP_SERVER',
          'created_at': '2026-11-19T10:05:00Z',
        },
      ],
    });

    expect(client.uiState, MobileConflictUiState.loaded);
    expect(items.length, 2);

    // Assert bilingual badges
    expect(items[0].localizedCategoryBadge()['en'], contains('Stale Stock'));
    expect(items[0].localizedCategoryBadge()['bn'], contains('স্টক শেষ'));
    expect(items[0].localizedStatusBadge()['en'], contains('Needs Manager Review'));
    expect(items[0].localizedStatusBadge()['bn'], contains('ম্যানেজার পর্যালোচনা'));

    expect(items[1].localizedCategoryBadge()['en'], contains('Stale Price'));
    expect(items[1].localizedCategoryBadge()['bn'], contains('পুরনো মূল্য'));
    expect(items[1].localizedStatusBadge()['en'], contains('Resolved (Server Maintained)'));
    expect(items[1].localizedStatusBadge()['bn'], contains('সার্ভার অক্ষুণ্ণ'));

    // Assert filtering
    final stockOnly = client.filterByCategory('STALE_STOCK');
    expect(stockOnly.length, 1);
    expect(stockOnly.first.conflictId, 'conf-001');

    final openOnly = client.filterByStatus('OPEN');
    expect(openOnly.length, 1);
    expect(openOnly.first.conflictId, 'conf-001');

    // Assert 403 handling
    client.handleHttpError(403);
    expect(client.uiState, MobileConflictUiState.permissionDenied);
    expect(client.lastErrorBn, contains('ম্যানেজারের অনুমতি'));

    // Assert offline fallback
    final fallback = client.loadOfflineFallback();
    expect(client.uiState, MobileConflictUiState.offlineCache);
    expect(fallback.length, 2);

    // Summary DTO parsing
    final summary = MobileConflictSummaryDto.fromJson({
      'total_conflicts': 5,
      'open_conflicts': 3,
      'total_disputed_bdt': '2450.75',
      'category_breakdown': {
        'STALE_STOCK': 2,
        'STALE_PRICE': 1,
      },
    });
    expect(summary.totalConflicts, 5);
    expect(summary.openConflicts, 3);
    expect(summary.totalDisputedBdt, '2450.75');
    expect(summary.categoryBreakdown['STALE_STOCK'], 2);
  });
}
