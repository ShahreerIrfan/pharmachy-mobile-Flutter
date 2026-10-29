// lib/core/constants/flavors.dart
// Architecture Decision: ADR-0021 & ADR-0024

enum AppFlavor { dev, staging, prod }

class AppConfig {
  final AppFlavor flavor;
  final String appName;
  final String apiBaseUrl;
  final bool enableDebugLogging;
  final Duration networkTimeout;

  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
    required this.enableDebugLogging,
    this.networkTimeout = const Duration(seconds: 15),
  });

  static AppConfig dev() {
    return const AppConfig(
      flavor: AppFlavor.dev,
      appName: 'Pharmacy Manager [DEV]',
      apiBaseUrl: 'http://localhost:8000/api/v2',
      enableDebugLogging: true,
    );
  }

  static AppConfig staging() {
    return const AppConfig(
      flavor: AppFlavor.staging,
      appName: 'Pharmacy Manager [STAGING]',
      apiBaseUrl: 'https://staging-api.pharmacy.com.bd/api/v2',
      enableDebugLogging: true,
    );
  }

  static AppConfig prod() {
    return const AppConfig(
      flavor: AppFlavor.prod,
      appName: 'Bangladesh Pharmacy Manager',
      apiBaseUrl: 'https://api.pharmacy.com.bd/api/v2',
      enableDebugLogging: false,
    );
  }
}
