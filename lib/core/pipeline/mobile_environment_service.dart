/// Mobile Environment & Settings Service
/// Architecture Decision: ADR-0041
/// Manages mobile client API target endpoints and transport security posture.
library mobile_environment_service;

enum MobileEnvironment { development, testing, production }

class MobileEnvironmentConfig {
  final MobileEnvironment environment;
  final String apiBaseUrl;
  final bool isHttpsEnforced;
  final int requestTimeoutMs;

  const MobileEnvironmentConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.isHttpsEnforced,
    required this.requestTimeoutMs,
  });

  Map<String, dynamic> toJson() => {
        'environment': environment.name,
        'api_base_url': apiBaseUrl,
        'is_https_enforced': isHttpsEnforced,
        'request_timeout_ms': requestTimeoutMs,
      };
}

class MobileEnvironmentService {
  static const String devApiUrl = 'http://10.0.2.2:8000/api/v2';
  static const String testApiUrl = 'http://localhost:8000/api/v2';
  static const String prodApiUrl = 'https://api.pharmacy.bd/api/v2';

  static MobileEnvironmentConfig resolveConfig(MobileEnvironment env) {
    switch (env) {
      case MobileEnvironment.development:
        return const MobileEnvironmentConfig(
          environment: MobileEnvironment.development,
          apiBaseUrl: devApiUrl,
          isHttpsEnforced: false,
          requestTimeoutMs: 15000,
        );
      case MobileEnvironment.testing:
        return const MobileEnvironmentConfig(
          environment: MobileEnvironment.testing,
          apiBaseUrl: testApiUrl,
          isHttpsEnforced: false,
          requestTimeoutMs: 5000,
        );
      case MobileEnvironment.production:
        return const MobileEnvironmentConfig(
          environment: MobileEnvironment.production,
          apiBaseUrl: prodApiUrl,
          isHttpsEnforced: true,
          requestTimeoutMs: 10000,
        );
    }
  }
}
