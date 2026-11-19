// mobile_event_ordering_client.dart
// Architecture Decision: ADR-0316 (P316).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

enum MobileOrderingBarrierUiState { idle, loading, evaluated, blocked, error }

class MobileEventOrderingClient {
  MobileOrderingBarrierUiState uiState = MobileOrderingBarrierUiState.idle;
  bool allDependenciesSatisfied = true;
  String blockedCommandId = '';
  List<String> blockedReasons = [];
  List<String> topologicalOrder = [];
  String lastErrorEn = '';
  String lastErrorBn = '';

  void parseEvaluationResponse(Map<String, dynamic> json) {
    allDependenciesSatisfied = json['all_dependencies_satisfied'] == true;
    blockedCommandId = json['blocked_command_id']?.toString() ?? '';
    blockedReasons = (json['blocked_reasons'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    topologicalOrder = (json['topological_order'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    uiState = allDependenciesSatisfied
        ? MobileOrderingBarrierUiState.evaluated
        : MobileOrderingBarrierUiState.blocked;
  }

  void handleHttpError(int statusCode, {String? detail}) {
    uiState = MobileOrderingBarrierUiState.error;
    lastErrorEn = detail ?? 'Failed to evaluate ordering barriers (HTTP $statusCode).';
    lastErrorBn = 'ইভেন্ট নির্ভরতা যাচাই ব্যর্থ হয়েছে (HTTP $statusCode)।';
  }
}
