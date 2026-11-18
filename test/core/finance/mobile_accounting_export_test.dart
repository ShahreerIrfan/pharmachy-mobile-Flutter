// mobile_accounting_export_test.dart
// Architecture Decision: ADR-0298 (P298).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_accounting_export_client.dart';

void main() {
  group('P298 MobileAccountingExportClient', () {
    test('01. Owner parses consolidated accounting snapshots with balanced badge', () {
      final client = MobileAccountingExportClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'PHARMACY_OWNER',
      );
      final snaps = client.parseSnapshotsResponse({
        'snapshots': [
          {
            'snapshot_id': 'arsnp-1',
            'report_type': 'TRIAL_BALANCE',
            'title': 'Nov 2026 Trial Balance',
            'is_book_balanced': true,
            'total_debits_bdt': '50000.00',
            'total_credits_bdt': '50000.00',
            'row_count': 6,
            'sha256_digest': 'abc123',
            'status': 'FINALIZED',
          }
        ],
      });
      expect(snaps.length, 1);
      expect(snaps.first.localizedBalanceBadge()['bn'], 'হিসাব সমতায় আছে');
      expect(client.uiState, ExportUiState.loaded);
    });

    test('02. Branch Manager denied consolidated snapshot access', () {
      final client = MobileAccountingExportClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'BRANCH_MANAGER',
      );
      expect(
        () => client.parseSnapshotsResponse({'snapshots': []}, targetBranchId: null),
        throwsA(isA<AccountingExportPermissionException>()),
      );
      expect(client.uiState, ExportUiState.permissionDenied);
    });

    test('03. Offline fallback loads cached snapshots', () {
      final client = MobileAccountingExportClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'AUDITOR',
      );
      client.parseSnapshotsResponse({
        'snapshots': [
          {'snapshot_id': 'arsnp-2', 'report_type': 'PROFIT_AND_LOSS', 'title': 'P&L'}
        ],
      });
      expect(client.loadOfflineFallback().length, 1);
      expect(client.uiState, ExportUiState.offlineCache);
    });
  });
}
