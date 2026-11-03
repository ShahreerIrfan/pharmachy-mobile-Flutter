/// test/widget/dynamic_medicine_form_screen_test.dart
/// Architecture Decision: ADR-0158 (P158).
/// Phase 08: Specialized Item & Multi-Tier Packaging Formulation Editors.
///
/// Screen-level widget test suite for Flutter dynamic medicine forms.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/models/tenant_session.dart';
import 'package:pharmacy_mobile_manager/ui/screens/dynamic_medicine_form_screen.dart';

void main() {
  const sampleOwnerSession = TenantSession(
    tenantId: 'tenant-dhaka-01',
    branchId: 'branch-dhanmondi',
    userId: 'user-pharmacist-01',
    userRole: 'STAFF_PHARMACIST',
    authToken: 'token-xyz-pharmacist',
  );

  const sampleCashierSession = TenantSession(
    tenantId: 'tenant-dhaka-01',
    branchId: 'branch-dhanmondi',
    userId: 'user-cashier-01',
    userRole: 'CASHIER',
    authToken: 'token-xyz-cashier',
  );

  Widget createWidgetUnderTest({
    TenantSession session = sampleOwnerSession,
    bool isOffline = false,
    String initialDosageForm = 'TABLET_CAPSULE',
    DynamicFormViewState? forcedState,
  }) {
    return MaterialApp(
      home: DynamicMedicineFormScreen(
        session: session,
        isOffline: isOffline,
        initialDosageForm: initialDosageForm,
        forcedState: forcedState,
      ),
    );
  }

  group('DynamicMedicineFormScreen Widget & State Tests (P158)', () {
    testWidgets('1. Valid scenario: Renders loaded dynamic form, enters values, and validates successfully',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Medicine Monograph Editor'), findsOneWidget);
      expect(find.text('General Product Identification'), findsOneWidget);
      expect(find.text('Financial Pricing & MRP'), findsOneWidget);

      // Enter valid fields
      await tester.enterText(find.byKey(const Key('field_brand_name')), 'Napa Extra');
      await tester.enterText(find.byKey(const Key('field_generic_name')), 'Paracetamol + Caffeine');
      await tester.enterText(find.byKey(const Key('field_dar_number')), '012-345-678');
      await tester.enterText(find.byKey(const Key('field_cost_unit')), '2.10');
      await tester.enterText(find.byKey(const Key('field_mrp_unit')), '3.00');

      await tester.tap(find.byKey(const Key('btn_validate_save')));
      await tester.pumpAndSettle();

      expect(find.text('Form successfully validated and ready to save.'), findsOneWidget);
    });

    testWidgets('2. Invalid scenario: Missing mandatory fields triggers error banner and inline feedback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Submit without entering required fields
      await tester.tap(find.byKey(const Key('btn_validate_save')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Validation Errors'), findsOneWidget);
      expect(find.textContaining("Field 'Brand Name' is mandatory."), findsOneWidget);
      expect(find.textContaining("Field 'Generic Name' is mandatory."), findsOneWidget);
    });

    testWidgets('3. Pricing validation: Detects negative cost and MRP below purchase cost',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('field_brand_name')), 'Seclo 20');
      await tester.enterText(find.byKey(const Key('field_generic_name')), 'Omeprazole');
      await tester.enterText(find.byKey(const Key('field_dar_number')), '001-222-333');
      await tester.enterText(find.byKey(const Key('field_cost_unit')), '10.00');
      await tester.enterText(find.byKey(const Key('field_mrp_unit')), '8.00'); // MRP < Cost

      await tester.tap(find.byKey(const Key('btn_validate_save')));
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot be less than purchase cost'), findsOneWidget);
    });

    testWidgets('4. Unauthorized scenario: Cashier session renders permission denied view state',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(session: sampleCashierSession));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.textContaining('Cashier role has read-only access'), findsOneWidget);
      expect(find.byKey(const Key('btn_validate_save')), findsNothing);
    });

    testWidgets('5. Offline scenario: Renders offline mode banner',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(isOffline: true));
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline Mode Active'), findsOneWidget);
    });

    testWidgets('6. Language toggle switches from English to Bengali labels',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('General Product Identification'), findsOneWidget);

      // Toggle language
      await tester.tap(find.text('বাংলা'));
      await tester.pumpAndSettle();

      expect(find.text('মেডিসিন মনোগ্রাফ এডিটর'), findsOneWidget);
      expect(find.text('সাধারণ পণ্যের পরিচিতি'), findsOneWidget);
      expect(find.text('ENGLISH'), findsOneWidget);
    });
  });
}
