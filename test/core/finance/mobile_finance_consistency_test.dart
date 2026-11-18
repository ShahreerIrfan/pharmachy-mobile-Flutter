// mobile_finance_consistency_test.dart
// Architecture Decision: ADR-0300 (P300).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_finance_consistency_client.dart';

void main() {
  group('P300 MobileFinanceConsistencyClient', () {
    test('01. Owner parses 6/6 consistent audit result with BN summary', () {
      final client = MobileFinanceConsistencyClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'PHARMACY_OWNER',
      );
      final dto = client.parseAuditResponse({
        'overall_status': 'CONSISTENT',
        'passed_checks': 6,
        'total_checks': 6,
      });
      expect(dto.overallStatus, 'CONSISTENT');
      expect(dto.localizedSummary()['bn'], contains('6/6'));
      expect(client.uiState, AuditUiState.consistent);
    });

    test('02. Cashier denied access', () {
      final client = MobileFinanceConsistencyClient(
        tenantId: 'ten-1',
        branchId: 'br-1',
        userRole: 'CASHIER',
      );
      expect(
        () => client.parseAuditResponse({'overall_status': 'CONSISTENT'}),
        throwsA(isA<FinanceConsistencyPermissionException>()),
      );
      expect(client.uiState, AuditUiState.permissionDenied);
    });
  });
}
