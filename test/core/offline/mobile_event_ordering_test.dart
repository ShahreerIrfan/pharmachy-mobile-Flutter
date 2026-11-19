import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_event_ordering_client.dart';

void main() {
  test('P316 MobileEventOrderingClient parses causal topological evaluation, blocked states & errors', () {
    final client = MobileEventOrderingClient();

    // 1. All satisfied case
    client.parseEvaluationResponse({
      'all_dependencies_satisfied': true,
      'blocked_command_id': '',
      'blocked_reasons': [],
      'topological_order': ['cmd-cust-1', 'cmd-grn-1', 'cmd-sale-1'],
    });

    expect(client.uiState, MobileOrderingBarrierUiState.evaluated);
    expect(client.allDependenciesSatisfied, true);
    expect(client.topologicalOrder.length, 3);
    expect(client.topologicalOrder.last, 'cmd-sale-1');

    // 2. Blocked case
    client.parseEvaluationResponse({
      'all_dependencies_satisfied': false,
      'blocked_command_id': 'cmd-sale-1',
      'blocked_reasons': ["Upstream dependency 'cmd-cust-1' not committed."],
      'topological_order': ['cmd-cust-1', 'cmd-sale-1'],
    });

    expect(client.uiState, MobileOrderingBarrierUiState.blocked);
    expect(client.allDependenciesSatisfied, false);
    expect(client.blockedCommandId, 'cmd-sale-1');
    expect(client.blockedReasons.first, contains('not committed'));

    // 3. HTTP error handling
    client.handleHttpError(500);
    expect(client.uiState, MobileOrderingBarrierUiState.error);
    expect(client.lastErrorBn, contains('ইভেন্ট নির্ভরতা'));
  });
}
