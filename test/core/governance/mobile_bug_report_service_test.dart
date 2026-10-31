import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/governance/mobile_bug_report_service.dart';

void main() {
  group('P039: Mobile Bug Report & Governance Test Suite', () {
    test('Valid Bug Report construction produces expected payload', () {
      final report = MobileBugReportService.createReport(
        tenantId: 'tenant-dhaka-central',
        title: 'Push notification delay on daily sales report',
        severity: 'MEDIUM',
        reproductionSteps:
            '1. Open app. 2. Navigate to Reports. 3. Pull to refresh daily summary.',
        expectedBehavior: 'Daily summary loads within 500ms',
        observedBehavior: 'Spinner stays for 4 seconds before loading',
        platformName: 'Android 14',
        isOnline: true,
      );

      expect(report.tenantId, equals('tenant-dhaka-central'));
      expect(report.severity, equals('MEDIUM'));
      expect(report.clientVersion, equals('1.1.0'));

      final jsonMap = report.toJson();
      expect(jsonMap['category'], equals('BUG'));
      expect(jsonMap['client_platform'], equals('MOBILE'));
      expect(jsonMap['connectivity_state'], equals('ONLINE'));
    });

    test(
        'Incomplete reproduction steps or blank behaviors throw FormatException',
        () {
      expect(
        () => MobileBugReportService.createReport(
          tenantId: 'tenant-dhaka-central',
          title: 'Error',
          severity: 'LOW',
          reproductionSteps: 'Short', // < 10 chars
          expectedBehavior: 'Ok',
          observedBehavior: 'Fail',
          platformName: 'iOS 17',
        ),
        throwsFormatException,
      );

      expect(
        () => MobileBugReportService.createReport(
          tenantId: 'tenant-dhaka-central',
          title: 'Error',
          severity: 'LOW',
          reproductionSteps: 'Valid step-by-step reproduction instructions.',
          expectedBehavior: '', // Blank
          observedBehavior: 'Fail',
          platformName: 'iOS 17',
        ),
        throwsFormatException,
      );
    });
  });
}
