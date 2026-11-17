// test/core/inventory/mobile_cold_chain_excursion_test.dart
// Unit tests for P212: Cold chain excursion workflow (Flutter Mobile Manager App)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_cold_chain_excursion_client.dart';

void main() {
  group('P212: Mobile Cold Chain Excursion Workflow Tests', () {
    late MobileColdChainExcursionClient client;

    setUp(() {
      client = MobileColdChainExcursionClient();
    });

    test('P212-M-1: Excursion triggers automated batch quarantine and locked sellable state', () {
      final batches = [
        MobileQuarantinedBatchItem(
          batchNumber: 'LOT-INS-101',
          productName: 'Insulin Glargine',
          quantity: 40,
          unitCost: 450.0,
        ),
        MobileQuarantinedBatchItem(
          batchNumber: 'LOT-VAC-202',
          productName: 'Hepatitis B Vaccine',
          quantity: 20,
          unitCost: 600.0,
        ),
      ];

      final incident = client.triggerExcursion(
        tenantId: 'ten-evercare-01',
        branchId: 'br-central-01',
        storageLocationCode: 'FRIDGE-BIOL-01',
        storageLocationName: 'Main Vaccine Refrigerator',
        recordedTemp: 11.5, // Excursion above 8.0°C (Warning severity)
        minThreshold: 2.0,
        maxThreshold: 8.0,
        activeBatches: batches,
      );

      expect(incident.status, equals(MobileIncidentStatus.detected));
      expect(incident.severity, equals(MobileExcursionSeverity.warning));
      expect(incident.quarantinedBatchesCount, equals(2));
      expect(incident.totalQuarantinedValue, equals(30000.0)); // 40*450 + 20*600 = 18000 + 12000 = 30000
      expect(incident.dispositionOutcome, equals(MobileDispositionOutcome.pending));
    });

    test('P212-M-2: Pharmacist review with clinical justification releases stock to sellable', () {
      final batches = [
        MobileQuarantinedBatchItem(
          batchNumber: 'LOT-INS-101',
          productName: 'Insulin Glargine',
          quantity: 40,
          unitCost: 450.0,
        ),
      ];

      final incident = client.triggerExcursion(
        tenantId: 'ten-evercare-01',
        branchId: 'br-central-01',
        storageLocationCode: 'FRIDGE-BIOL-01',
        storageLocationName: 'Main Vaccine Refrigerator',
        recordedTemp: 9.5,
        activeBatches: batches,
      );

      final resolved = client.reviewDisposition(
        incidentId: incident.incidentId,
        userRole: 'STAFF_PHARMACIST',
        reviewerUsername: 'pharmacist_ashraf',
        outcome: MobileDispositionOutcome.releaseToSellable,
        clinicalJustification: 'Stability data confirms no efficacy loss under 2 hours exposure at 9.5C.',
      );

      expect(resolved.status, equals(MobileIncidentStatus.resolved));
      expect(resolved.dispositionOutcome, equals(MobileDispositionOutcome.releaseToSellable));
      expect(resolved.reviewedBy, equals('pharmacist_ashraf'));
      expect(resolved.reviewedAt, isNotNull);
      expect(resolved.affectedBatches.first.disposition, equals(MobileDispositionOutcome.releaseToSellable));
    });

    test('P212-M-3: Severe temperature excursion triggers critical severity and condemn disposal', () {
      final batches = [
        MobileQuarantinedBatchItem(
          batchNumber: 'LOT-VAC-909',
          productName: 'Rabies Vaccine',
          quantity: 15,
          unitCost: 1200.0,
        ),
      ];

      final incident = client.triggerExcursion(
        tenantId: 'ten-evercare-01',
        branchId: 'br-central-01',
        storageLocationCode: 'FRIDGE-BIOL-01',
        storageLocationName: 'Main Vaccine Refrigerator',
        recordedTemp: 28.0, // Critical excursion (> 15C)
        activeBatches: batches,
      );

      expect(incident.severity, equals(MobileExcursionSeverity.critical));

      final resolved = client.reviewDisposition(
        incidentId: incident.incidentId,
        userRole: 'STAFF_PHARMACIST',
        reviewerUsername: 'pharmacist_ashraf',
        outcome: MobileDispositionOutcome.condemnDispose,
        clinicalJustification: 'Critical excursion above 25C for 8 hours; cold-chain broken, condemned.',
      );

      expect(resolved.dispositionOutcome, equals(MobileDispositionOutcome.condemnDispose));
      expect(resolved.affectedBatches.first.disposition, equals(MobileDispositionOutcome.condemnDispose));
    });

    test('P212-M-4: Short clinical justification (< 15 chars) throws ArgumentError', () {
      final batches = [
        MobileQuarantinedBatchItem(
          batchNumber: 'LOT-INS-101',
          productName: 'Insulin Glargine',
          quantity: 10,
          unitCost: 450.0,
        ),
      ];

      final incident = client.triggerExcursion(
        tenantId: 'ten-evercare-01',
        branchId: 'br-central-01',
        storageLocationCode: 'FRIDGE-BIOL-01',
        storageLocationName: 'Main Vaccine Refrigerator',
        recordedTemp: 10.0,
        activeBatches: batches,
      );

      expect(
        () => client.reviewDisposition(
          incidentId: incident.incidentId,
          userRole: 'STAFF_PHARMACIST',
          reviewerUsername: 'pharmacist_ashraf',
          outcome: MobileDispositionOutcome.releaseToSellable,
          clinicalJustification: 'Looks fine', // Under 15 chars
        ),
        throwsArgumentError,
      );
    });

    test('P212-M-5: Cashier role is rejected from reviewing excursions', () {
      final batches = [
        MobileQuarantinedBatchItem(
          batchNumber: 'LOT-INS-101',
          productName: 'Insulin Glargine',
          quantity: 10,
          unitCost: 450.0,
        ),
      ];

      final incident = client.triggerExcursion(
        tenantId: 'ten-evercare-01',
        branchId: 'br-central-01',
        storageLocationCode: 'FRIDGE-BIOL-01',
        storageLocationName: 'Main Vaccine Refrigerator',
        recordedTemp: 10.0,
        activeBatches: batches,
      );

      expect(
        () => client.reviewDisposition(
          incidentId: incident.incidentId,
          userRole: 'CASHIER',
          reviewerUsername: 'cashier_rahim',
          outcome: MobileDispositionOutcome.releaseToSellable,
          clinicalJustification: 'Cashier unauthorized attempt to release quarantined stock.',
        ),
        throwsException,
      );
    });
  });
}
