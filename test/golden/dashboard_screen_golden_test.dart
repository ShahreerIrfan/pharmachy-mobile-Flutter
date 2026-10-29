// test/golden/dashboard_screen_golden_test.dart
// Architecture Decision: ADR-0007, ADR-0009, ADR-0024 & ADR-0032

import 'dart:io';
import 'package:flutter/cupertino.dart';
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

  Widget createHarnessWidget({
    TenantSession session = sampleOwnerSession,
    bool isOffline = false,
    DashboardKpi? kpi = sampleKpi,
    DashboardViewState? forcedState,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: DashboardScreen(
        session: session,
        isOffline: isOffline,
        initialKpi: kpi,
        forcedState: forcedState,
      ),
    );
  }

  void setStandardMobileViewport(WidgetTester tester) {
    // 390x844 @ 2.0x device pixel ratio (ADR-0032 Standard Mobile Viewport)
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
  }

  group('Flutter Mobile Golden & Visual Regression Harness (ADR-0032)', () {
    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.clearAllTestValues();
    });

    testWidgets('1. Loaded Dashboard visual layout renders fixed 390x844 bounds and exact Decimal BDT',
        (tester) async {
      setStandardMobileViewport(tester);
      await tester.pumpWidget(createHarnessWidget());
      await tester.pumpAndSettle();

      // Verify Header & Metrics
      expect(find.text('Pharmacy Executive Dashboard'), findsOneWidget);
      expect(find.text("TODAY'S REVENUE"), findsOneWidget);
      expect(find.text('BDT 45,250.75'), findsOneWidget);
      expect(find.text('22.4%'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // Low stock
      expect(find.text('3'), findsOneWidget); // Pending Rx

      // Confirm no text overflows or clipped widgets
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Offline State renders persistent warning watermark banner with gold theme',
        (tester) async {
      setStandardMobileViewport(tester);
      await tester.pumpWidget(createHarnessWidget(isOffline: true));
      await tester.pumpAndSettle();

      expect(find.text('Working Offline - Showing Cached Data'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.wifi_slash), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Permission Denied state displays strict access restricted alert for Cashier',
        (tester) async {
      setStandardMobileViewport(tester);
      await tester.pumpWidget(createHarnessWidget(session: sampleCashierSession));
      await tester.pumpAndSettle();

      expect(find.text('Permission Denied'), findsOneWidget);
      expect(find.textContaining('Cashier role is not authorized to access the Mobile Manager App'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.lock_shield_fill), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Empty Dashboard state renders clean zero-data placeholder',
        (tester) async {
      setStandardMobileViewport(tester);
      await tester.pumpWidget(createHarnessWidget(forcedState: DashboardViewState.empty, kpi: null));
      await tester.pumpAndSettle();

      expect(find.text('No Transactions Recorded Today'), findsOneWidget);
      expect(find.text('Sales and orders for this branch will appear here in real time.'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.tray_fill), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Error state renders actionable retry button and error banner',
        (tester) async {
      setStandardMobileViewport(tester);
      await tester.pumpWidget(createHarnessWidget(forcedState: DashboardViewState.error, kpi: null));
      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Dashboard'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.exclamationmark_circle_fill), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Loading state renders clean activity indicator without overflow',
        (tester) async {
      setStandardMobileViewport(tester);
      await tester.pumpWidget(createHarnessWidget(forcedState: DashboardViewState.loading, kpi: null));
      await tester.pump();

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('7. Mobile codebase strictly avoids forbidden Unicode emojis in UI strings (ADR-0009)', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final emojiPattern = RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2702}-\u{27B0}\u{1F900}-\u{1F9FF}]',
        unicode: true,
      );

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final matches = emojiPattern.allMatches(content);
        expect(matches.isEmpty, isTrue,
            reason: 'Forbidden emoji found in ${file.path}: ${matches.map((m) => m.group(0))}');
      }
    });
  });
}
