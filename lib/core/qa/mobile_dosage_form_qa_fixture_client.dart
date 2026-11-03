import '../forms/mobile_flexible_medicine_payload_client.dart';

/// MobileDosageFormQaFixtureClient
/// Architecture Decision: ADR-0160 (P160).
/// Phase 08: Specialized Item & Multi-Tier Packaging Formulation Editors.
///
/// Client-side QA fixture execution harness for Flutter Mobile Manager.
/// Validates canonical positive fixtures for all 11 dosage form families
/// and verifies strict field-level rejection on negative test cases.
class MobileFixtureExecutionResult {
  final String fixtureId;
  final bool passed;
  final String expectedSummary;
  final String observedSummary;
  final MobilePayloadValidationReport report;

  const MobileFixtureExecutionResult({
    required this.fixtureId,
    required this.passed,
    required this.expectedSummary,
    required this.observedSummary,
    required this.report,
  });

  Map<String, dynamic> toJson() => {
        'fixture_id': fixtureId,
        'passed': passed,
        'expected_summary': expectedSummary,
        'observed_summary': observedSummary,
        'is_valid': report.isValid,
        'error_count': report.errorCount,
      };
}

class MobileDosageFormQaFixtureClient {
  final MobileFlexibleMedicinePayloadClient payloadClient;

  MobileDosageFormQaFixtureClient({MobileFlexibleMedicinePayloadClient? payloadClient})
      : payloadClient = payloadClient ?? MobileFlexibleMedicinePayloadClient();

  /// Authorization check: Cashier role is blocked from seeding catalog QA fixtures.
  bool canSeedCatalog(String? userRole) {
    return payloadClient.canMutate(userRole);
  }

  /// Runs positive fixture through client validation engine and verifies success (0 errors).
  MobileFixtureExecutionResult runPositiveFixture({
    required String fixtureId,
    required String schemaVersion,
    required String dosageFormFamily,
    required Map<String, dynamic> attributes,
  }) {
    final report = payloadClient.validatePayload(
      schemaVersion: schemaVersion,
      dosageFormFamily: dosageFormFamily,
      attributes: attributes,
    );

    final passed = report.isValid && report.errorCount == 0;
    const expected = 'SUCCESS (0 errors)';
    final observed = 'isValid=${report.isValid}, errors=${report.errorCount}';

    return MobileFixtureExecutionResult(
      fixtureId: fixtureId,
      passed: passed,
      expectedSummary: expected,
      observedSummary: observed,
      report: report,
    );
  }

  /// Runs negative fixture and verifies that expected error code is detected.
  MobileFixtureExecutionResult runNegativeFixture({
    required String fixtureId,
    required String expectedErrorCode,
    required String schemaVersion,
    required String dosageFormFamily,
    required Map<String, dynamic> attributes,
  }) {
    final report = payloadClient.validatePayload(
      schemaVersion: schemaVersion,
      dosageFormFamily: dosageFormFamily,
      attributes: attributes,
    );

    final normalizedExpected = expectedErrorCode.trim().toUpperCase();
    final hasExpectedError = report.errors.any(
      (e) => e.errorCode.trim().toUpperCase() == normalizedExpected,
    );
    final passed = (!report.isValid) && hasExpectedError;

    final expected = 'REJECT with $expectedErrorCode';
    final observedCodes = report.errors.map((e) => e.errorCode).toList();
    final observed = 'isValid=${report.isValid}, observed=$observedCodes';

    return MobileFixtureExecutionResult(
      fixtureId: fixtureId,
      passed: passed,
      expectedSummary: expected,
      observedSummary: observed,
      report: report,
    );
  }
}
