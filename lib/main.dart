// lib/main.dart
// Architecture Decision: ADR-0007 & ADR-0024

import 'package:flutter/material.dart';
import 'core/constants/flavors.dart';
import 'core/theme/tokens.dart';
import 'models/dashboard_kpi.dart';
import 'models/tenant_session.dart';
import 'ui/screens/dashboard_screen.dart';

void main() {
  runApp(PharmacyManagerApp(config: AppConfig.prod()));
}

class PharmacyManagerApp extends StatelessWidget {
  final AppConfig config;
  final TenantSession? session;

  const PharmacyManagerApp({
    super.key,
    this.config = const AppConfig(
      flavor: AppFlavor.dev,
      appName: 'Pharmacy Manager',
      apiBaseUrl: 'http://localhost:8000/api/v2',
      enableDebugLogging: true,
    ),
    this.session,
  });

  @override
  Widget build(BuildContext context) {
    final activeSession = session ??
        const TenantSession(
          tenantId: 'tenant-demo',
          branchId: 'branch-dhanmondi',
          userId: 'user-owner',
          userRole: 'TENANT_OWNER',
          authToken: 'demo-jwt-token',
        );

    const defaultKpi = DashboardKpi(
      todaySalesBdt: '45250.75',
      totalOrdersCount: 142,
      grossMarginPercent: '22.4',
      lowStockAlertCount: 4,
      expiringBatchesCount: 2,
      pendingRxCount: 3,
      asOfTimestamp: '2026-10-29T12:00:00Z',
    );

    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTokens.primaryTeal,
          brightness: Brightness.light,
          surface: AppTokens.surfaceBackground,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppTokens.surfaceBackground,
      ),
      home: DashboardScreen(
        session: activeSession,
        initialKpi: defaultKpi,
      ),
    );
  }
}
