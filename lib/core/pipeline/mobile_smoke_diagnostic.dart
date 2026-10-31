/// Mobile Smoke Diagnostic Probe
/// Architecture Decision: ADR-0040
/// Diagnostic probe for Flutter Mobile Manager during automated build smoke verification.
library mobile_smoke_diagnostic;

import 'dart:io' show Platform;

class MobileDiagnosticResult {
  final bool isHealthy;
  final String dartVersion;
  final String operatingSystem;
  final String component;
  final String timestamp;
  final Map<String, dynamic> metadata;

  const MobileDiagnosticResult({
    required this.isHealthy,
    required this.dartVersion,
    required this.operatingSystem,
    required this.component,
    required this.timestamp,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'is_healthy': isHealthy,
        'dart_version': dartVersion,
        'operating_system': operatingSystem,
        'component': component,
        'timestamp': timestamp,
        'metadata': metadata,
      };
}

class MobileSmokeDiagnostic {
  static const String componentName = 'MOBILE_MANAGER';

  static MobileDiagnosticResult runDiagnostic() {
    final dartVersion = Platform.version;
    final os = Platform.operatingSystem;
    final isHealthy = dartVersion.isNotEmpty && os.isNotEmpty;

    return MobileDiagnosticResult(
      isHealthy: isHealthy,
      dartVersion: dartVersion,
      operatingSystem: os,
      component: componentName,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      metadata: {
        'numberOfProcessors': Platform.numberOfProcessors,
        'resolvedExecutable': Platform.resolvedExecutable,
      },
    );
  }
}
