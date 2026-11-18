// mobile_accounting_reversal_test.dart
// Architecture Decision: ADR-0299 (P299).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_accounting_reversal_client.dart';

void main() {
  group('P299 MobileAccountingReversalClient', () {
    test('01. Owner parses reversal request list with localized BN badge', () {
      final client = MobileAccountingReversalClient(tenantId: 'ten-1', userRole: 'PHARMACY_OWNER');
      final list = client.parseList({
        'requests': [
          {
            'request_id': 'arev-1',
            'original_journal_number': 'JRN-202611-ABC123',
            'original_total_bdt': '5000.00',
            'error_category': 'WRONG_AMOUNT',
            'reason': 'Typo in cash entry',
            'status': 'APPROVED_EXECUTED',
          }
        ],
      });
      expect(list.length, 1);
      expect(list.first.localizedStatusLabel()['bn'], 'রিভার্সাল সম্পন্ন');
      expect(client.uiState, ReversalUiState.loaded);
    });

    test('02. Branch Manager denied approval permission', () {
      final client = MobileAccountingReversalClient(tenantId: 'ten-1', userRole: 'BRANCH_MANAGER');
      expect(() => client.assertApproveAuthorized(), throwsA(isA<AccountingReversalPermissionException>()));
      expect(client.uiState, ReversalUiState.permissionDenied);
    });
  });
}
