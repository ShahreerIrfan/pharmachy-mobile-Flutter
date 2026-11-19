import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_conflict_review_center_controller.dart';

void main() {
  test('P314 MobileConflictReviewCenterController handles source events, proposals, approvals & 403', () {
    final controller = MobileConflictReviewCenterController();

    final tickets = controller.parseTicketsResponse({
      'results': [
        {
          'conflict_id': 'conf-rev-01',
          'command_id': 'cmd-001',
          'idempotency_key': 'idem-001',
          'client_sequence': 8,
          'tenant_id': 'ten-1',
          'branch_id': 'br-1',
          'branch_name': 'Gulshan Branch',
          'conflict_category': 'STALE_STOCK',
          'error_code': 'CONFLICT_STALE_STOCK',
          'disputed_monetary_bdt': '450.00',
          'local_payload_json': {'product_id': 'med-1', 'quantity': 10},
          'server_state_snapshot': {'available_units': 4, 'shortage': 6},
          'resolution_status': 'OPEN',
          'created_at': '2026-11-19T11:00:00Z',
        }
      ]
    });

    expect(controller.uiState, MobileConflictReviewUiState.loaded);
    expect(tickets.length, 1);

    final t = tickets.first;
    expect(t.disputedMonetaryBdt, '450.00');
    expect(t.localPayload['quantity'], 10);
    expect(t.serverSnapshot['shortage'], 6);
    expect(t.localizedStatusBadge()['en'], contains('Needs Review'));
    expect(t.localizedStatusBadge()['bn'], contains('পর্যালোচনা'));

    // Apply manager proposed decision
    controller.applyProposalLocally(
      'conf-rev-01',
      MobileProposedDecisionEnum.OVERRIDE_WITH_INVENTORY_ADJUSTMENT,
      'Post adjustment voucher for shortage.',
    );
    expect(t.resolutionStatus, 'DECISION_PROPOSED');
    expect(t.localizedStatusBadge()['bn'], contains('সিদ্ধান্ত প্রস্তাবিত'));
    expect(t.localizedDecisionBadge()['en'], contains('Inventory Adjustment'));
    expect(t.localizedDecisionBadge()['bn'], contains('স্টক সমন্বয়'));

    // Apply manager approval
    controller.applyApprovalLocally(
      'conf-rev-01',
      'Approved by owner.',
      {
        'execution_status': 'COMMITTED_CLOUD',
        'reference_id': 'ADJ-888',
      },
    );
    expect(t.resolutionStatus, 'RESOLVED_ADJUSTED');
    expect(t.finalCloudOutcome['reference_id'], 'ADJ-888');

    // HTTP 403 test
    controller.handleHttpError(403);
    expect(controller.uiState, MobileConflictReviewUiState.permissionDenied);
    expect(controller.lastErrorBn, contains('ম্যানেজারের অনুমতি'));

    // Offline fallback
    final cached = controller.loadOfflineFallback();
    expect(controller.uiState, MobileConflictReviewUiState.offlineCache);
    expect(cached.length, 1);
  });
}
