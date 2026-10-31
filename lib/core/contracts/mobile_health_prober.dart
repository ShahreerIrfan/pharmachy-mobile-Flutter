/// Architecture Decision: ADR-0058
/// Mobile Client implementation of Health, Liveness, and Readiness Probe Monitor:
/// - Verifies cloud backend readiness before executing sync
/// - Prohibits exposure of internal secrets, credentials, or PII
library;

class MobileHealthProber {
  static const Set<String> forbiddenSecretTerms = {
    'password',
    'secret_key',
    'bearer',
    'private_key',
    'postgres://',
    'redis://',
    'password_hash',
  };

  static bool containsSensitiveLeak(String responseBody) {
    final lower = responseBody.toLowerCase();
    for (final term in forbiddenSecretTerms) {
      if (lower.contains(term)) {
        return true;
      }
    }
    return false;
  }

  static bool isReady(String overallStatus, Map<String, dynamic>? checks) {
    final upper = overallStatus.toUpperCase().trim();
    if (upper != 'READY' && upper != 'UP') {
      return false;
    }
    if (checks == null || checks.isEmpty) {
      return true;
    }
    final db = checks['database']?.toString().toUpperCase();
    return db == 'UP';
  }
}

class MobileHealthReport {
  final String service;
  final String status;
  final bool isReady;
  final Map<String, String> componentChecks;
  final DateTime timestamp;

  const MobileHealthReport({
    required this.service,
    required this.status,
    required this.isReady,
    required this.componentChecks,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'service': service,
      'status': status,
      'is_ready': isReady,
      'component_checks': componentChecks,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
