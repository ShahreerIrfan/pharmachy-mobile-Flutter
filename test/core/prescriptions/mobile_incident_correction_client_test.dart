import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_incident_correction_client.dart';

void main() {
  group('P255: Mobile Incident Correction Client Tests', () {
    test('Role reporting, investigation, and closure authorization gates', () {
      // Cashier can report
      expect(MobileIncidentCorrectionClient.canReportIncident('CASHIER'), isTrue);
      expect(MobileIncidentCorrectionClient.canReportIncident('STAFF_PHARMACIST'), isTrue);

      // Cashier cannot investigate
      expect(MobileIncidentCorrectionClient.canConductInvestigation('CASHIER'), isFalse);
      expect(MobileIncidentCorrectionClient.canConductInvestigation('BRANCH_MANAGER'), isTrue);

      // Cashier cannot approve closures
      expect(
        MobileIncidentCorrectionClient.canApproveClosure(
          role: 'CASHIER',
          userBranchId: 'br-1',
          recordBranchId: 'br-1',
        ),
        isFalse,
      );

      // Pharmacist / Manager can approve closure in their branch
      expect(
        MobileIncidentCorrectionClient.canApproveClosure(
          role: 'STAFF_PHARMACIST',
          userBranchId: 'br-1',
          recordBranchId: 'br-1',
        ),
        isTrue,
      );
      expect(
        MobileIncidentCorrectionClient.canApproveClosure(
          role: 'STAFF_PHARMACIST',
          userBranchId: 'br-1',
          recordBranchId: 'br-2',
        ),
        isFalse,
      );

      // Owner can approve closure across branches
      expect(
        MobileIncidentCorrectionClient.canApproveClosure(
          role: 'PHARMACY_OWNER',
          userBranchId: 'br-1',
          recordBranchId: 'br-2',
        ),
        isTrue,
      );
    });

    test('DGDA regulatory notification triggers', () {
      expect(
        MobileIncidentCorrectionClient.isDgdaNotificationRequired(
          incidentType: 'INCORRECT_DISPENSING',
          severity: 'CRITICAL',
        ),
        isTrue,
      );
      expect(
        MobileIncidentCorrectionClient.isDgdaNotificationRequired(
          incidentType: 'PRODUCT_RECALL',
          severity: 'LOW',
        ),
        isTrue,
      );
      expect(
        MobileIncidentCorrectionClient.isDgdaNotificationRequired(
          incidentType: 'ADVERSE_DRUG_REACTION',
          severity: 'HIGH',
        ),
        isTrue,
      );
      expect(
        MobileIncidentCorrectionClient.isDgdaNotificationRequired(
          incidentType: 'INVENTORY_DISCREPANCY',
          severity: 'LOW',
        ),
        isFalse,
      );
    });

    test('Mandatory Root Cause and CAPA validation for High/Critical closures', () {
      // Low severity closure does not require strict CAPA
      expect(
        () => MobileIncidentCorrectionClient.validateClosureRequirements(
          severity: 'LOW',
          rootCause: null,
          capa: null,
        ),
        returnsNormally,
      );

      // High severity closure without CAPA throws StateError
      expect(
        () => MobileIncidentCorrectionClient.validateClosureRequirements(
          severity: 'HIGH',
          rootCause: 'HUMAN_ERROR',
          capa: '',
        ),
        throwsA(isA<StateError>()),
      );

      // High severity closure with CAPA succeeds
      expect(
        () => MobileIncidentCorrectionClient.validateClosureRequirements(
          severity: 'HIGH',
          rootCause: 'HUMAN_ERROR',
          capa: 'Dual pharmacist double-check on high-alert medicines',
        ),
        returnsNormally,
      );
    });

    test('Localization and summary formatting', () {
      expect(
        MobileIncidentCorrectionClient.getIncidentTypeDisplay(
          'INCORRECT_DISPENSING',
          lang: 'bn',
        ),
        'ভুল ওষুধ প্রদান / নিয়ার-মিস',
      );
      expect(
        MobileIncidentCorrectionClient.getSeverityDisplay('CRITICAL', lang: 'en'),
        'Critical (DGDA Alert)',
      );

      final summary = MobileIncidentCorrectionClient.formatBranchSummary(
        totalIncidents: 6,
        criticalCount: 2,
        totalFinancialImpactBdt: '14250.00',
        lang: 'en',
      );
      expect(summary, contains('6 total'));
      expect(summary, contains('2 critical alerts'));
      expect(summary, contains('14250.00'));
    });
  });
}

