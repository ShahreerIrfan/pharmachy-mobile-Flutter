// test/widget_test.dart
// Architecture Decision: ADR-0024

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/main.dart';

void main() {
  testWidgets('Renders Pharmacy Manager App root with Executive Dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PharmacyManagerApp());
    await tester.pumpAndSettle();
    expect(find.text('Pharmacy Executive Dashboard'), findsOneWidget);
    expect(find.text("TODAY'S REVENUE"), findsOneWidget);
  });
}
