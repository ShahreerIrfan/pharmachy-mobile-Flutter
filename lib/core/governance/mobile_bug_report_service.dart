/// Mobile Bug Report & Governance Service
/// Architecture Decision: ADR-0039
/// Captures mobile client runtime context and enforces bug reproduction fields.
library mobile_bug_report_service;

class MobileBugReport {
  final String tenantId;
  final String title;
  final String severity;
  final String reproductionSteps;
  final String expectedBehavior;
  final String observedBehavior;
  final String clientVersion;
  final String platform;
  final String connectivityState;
  final String timestamp;

  const MobileBugReport({
    required this.tenantId,
    required this.title,
    required this.severity,
    required this.reproductionSteps,
    required this.expectedBehavior,
    required this.observedBehavior,
    required this.clientVersion,
    required this.platform,
    required this.connectivityState,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'title': title,
        'category': 'BUG',
        'severity': severity,
        'client_platform': 'MOBILE',
        'client_version': clientVersion,
        'environment': 'DEVELOPMENT',
        'connectivity_state': connectivityState,
        'reproduction_steps': reproductionSteps,
        'expected_behavior': expectedBehavior,
        'observed_behavior': observedBehavior,
        'sanitized_logs':
            'Flutter Mobile App | OS: $platform | Version: $clientVersion',
      };
}

class MobileBugReportService {
  static const String currentMobileVersion = '1.1.0';

  static MobileBugReport createReport({
    required String tenantId,
    required String title,
    required String severity,
    required String reproductionSteps,
    required String expectedBehavior,
    required String observedBehavior,
    required String platformName,
    bool isOnline = true,
  }) {
    if (reproductionSteps.trim().length < 10) {
      throw const FormatException(
          'Reproduction steps must contain at least 10 characters.');
    }
    if (expectedBehavior.trim().isEmpty || observedBehavior.trim().isEmpty) {
      throw const FormatException(
          'Both expected and observed behaviors are required.');
    }

    return MobileBugReport(
      tenantId: tenantId,
      title: title,
      severity: severity,
      reproductionSteps: reproductionSteps,
      expectedBehavior: expectedBehavior,
      observedBehavior: observedBehavior,
      clientVersion: currentMobileVersion,
      platform: platformName,
      connectivityState: isOnline ? 'ONLINE' : 'OFFLINE',
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
  }
}
