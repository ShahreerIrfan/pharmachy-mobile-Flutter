// test/widget/dashboard_screen_test.dart
// Architecture Decision: ADR-0007, ADR-0009 & ADR-0024

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/models/dashboard_kpi.dart';
import 'package:pharmacy_mobile_manager/models/tenant_session.dart';
import 'package:pharmacy_mobile_manager/ui/screens/dashboard_screen.dart';

void main() {
  const sampleOwnerSession = TenantSession(
    tenantId: 'tenant-dhaka-01',
    branchId: 'branch-dhanmondi',
    userId: 'user-owner-01',
    userRole: 'TENANT_OWNER',
    authToken: 'token-xyz',
  );

  const sampleCashierSession = TenantSession(
    tenantId: 'tenant-dhaka-01',
    branchId: 'branch-dhanmondi',
    userId: 'user-cashier-01',
    userRole: 'CASHIER',
    authToken: 'token-xyz',
  );

  const sampleKpi = DashboardKpi(
    todaySalesBdt: '45250.75',
    totalOrdersCount: 142,
    grossMarginPercent: '22.4',
    lowStockAlertCount: 4,
    expiringBatchesCount: 2,
    pendingRxCount: 3,
    asOfTimestamp: '2026-10-29T12:00:00Z',
  );

  Widget createWidgetUnderTest({
    TenantSession session = sampleOwnerSession,
    bool isOffline = false,
    DashboardKpi? kpi = sampleKpi,
    DashboardViewState? forcedState,
  }) {
    return MaterialApp(
      home: DashboardScreen(
        session: session,
        isOffline: isOffline,
        initialKpi: kpi,
        forcedState: forcedState,
      ),
    );
  }

  group('DashboardScreen Widget & State Rendering', () {
    testWidgets('Renders loaded KPI state with correct currency formatting',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Pharmacy Executive Dashboard'), findsOneWidget);
      expect(find.text("TODAY'S REVENUE"), findsOneWidget);
      expect(find.text('BDT 45,250.75'), findsOneWidget);
      expect(find.text('22.4%'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // Low stock alert count
    });

    testWidgets('Renders offline warning banner when isOffline is true',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(isOffline: true));
      await tester.pumpAndSettle();

      expect(
          find.text('Working Offline - Showing Cached Data'), findsOneWidget);
      expect(find.text('BDT 45,250.75'), findsOneWidget);
    });

    testWidgets('Renders Permission Denied state when cashier tries to access',
        (tester) async {
      await tester
          .pumpWidget(createWidgetUnderTest(session: sampleCashierSession));
      await tester.pumpAndSettle();

      expect(find.text('Permission Denied'), findsOneWidget);
      expect(find.textContaining('Cashier role is not authorized'),
          findsOneWidget);
    });

    testWidgets('Renders empty state when no KPI data is present',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(kpi: null));
      await tester.pumpAndSettle();

      expect(find.text('No Transactions Recorded Today'), findsOneWidget);
    });
  });
}
