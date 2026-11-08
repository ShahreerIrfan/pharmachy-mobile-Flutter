/// mobile_stock_adjustment_test.dart
/// Architecture Decision: ADR-0205 (P205).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_stock_adjustment_client.dart';

void main() {
  group('MobileStockAdjustmentClient Tests (P205)', () {
    late MobileStockAdjustmentClient client;

    setUp(() {
      client = MobileStockAdjustmentClient();
      client.setBatchStock('BATCH-MOX-2026-001', 50);
    });

    test('Nontrivial proposal, manager approval, difference events and stock updates', () {
      final adj = client.proposeAdjustment(
        tenantId: 'ten-001',
        branchId: 'br-001',
        productId: 'prod-mox',
        productName: 'Moxacil 500mg Capsule',
        batchNumber: 'BATCH-MOX-2026-001',
        quantityDelta: -15,
        unitCost: 45.0,
        reasonCode: MobileStockAdjustmentReasonCode.expirySpoilage,
        reasonNotes: 'Expired ampoules identified during quarterly stock check.',
        supportingDocumentRef: 'DOC-EXP-2026-01',
        actorUserId: 'user-pharmacist-1',
        actorRole: 'STAFF_PHARMACIST',
      );

      expect(adj.isNontrivial, isTrue);
      expect(adj.status, equals(MobileStockAdjustmentStatus.pending));
      expect(client.getBatchStock('BATCH-MOX-2026-001'), equals(50));

      final approved = client.approveAdjustment(
        adjustmentId: adj.adjustmentId,
        checkerUserId: 'user-manager-2',
        checkerRole: 'BRANCH_MANAGER',
        checkerNotes: 'Verified physical expiry and approved write-off.',
      );

      expect(approved.status, equals(MobileStockAdjustmentStatus.approved));
      expect(client.getBatchStock('BATCH-MOX-2026-001'), equals(35));
      expect(approved.ledgerEntryId, isNotNull);

      final events = client.getDifferenceEvents(adj.adjustmentId);
      expect(events.length, equals(1));
      final event = events.first;
      expect(event.preAdjustmentQuantity, equals(50));
      expect(event.postAdjustmentQuantity, equals(35));
      expect(event.quantityDelta, equals(-15));
      expect(event.immutableEventHash, isNotEmpty);
    });

    test('Maker-Checker anti-self-approval rule prevents self-approval of nontrivial adjustments', () {
      final adj = client.proposeAdjustment(
        tenantId: 'ten-001',
        branchId: 'br-001',
        productId: 'prod-mox',
        productName: 'Moxacil 500mg Capsule',
        batchNumber: 'BATCH-MOX-2026-001',
        quantityDelta: -15,
        unitCost: 45.0,
        reasonCode: MobileStockAdjustmentReasonCode.theftPilferage,
        reasonNotes: 'Unaccounted loss noted during night shift inspection.',
        actorUserId: 'user-manager-1',
        actorRole: 'BRANCH_MANAGER',
      );

      expect(adj.isNontrivial, isTrue);

      expect(
        () => client.approveAdjustment(
          adjustmentId: adj.adjustmentId,
          checkerUserId: 'user-manager-1',
          checkerRole: 'BRANCH_MANAGER',
          checkerNotes: 'Self-approval attempt',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_MAKER_CHECKER_SELF_APPROVAL'),
        )),
      );
    });

    test('Mandatory reason length, non-zero delta, and stock boundary validation', () {
      // Reason too short (< 10 chars)
      expect(
        () => client.proposeAdjustment(
          tenantId: 'ten-001',
          branchId: 'br-001',
          productId: 'prod-mox',
          productName: 'Moxacil',
          batchNumber: 'BATCH-MOX-2026-001',
          quantityDelta: -5,
          unitCost: 10.0,
          reasonCode: MobileStockAdjustmentReasonCode.breakageSpillage,
          reasonNotes: 'broken',
          actorUserId: 'user-1',
          actorRole: 'STAFF_PHARMACIST',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_MANDATORY_REASON_REQUIRED'),
        )),
      );

      // Zero delta
      expect(
        () => client.proposeAdjustment(
          tenantId: 'ten-001',
          branchId: 'br-001',
          productId: 'prod-mox',
          productName: 'Moxacil',
          batchNumber: 'BATCH-MOX-2026-001',
          quantityDelta: 0,
          unitCost: 10.0,
          reasonCode: MobileStockAdjustmentReasonCode.breakageSpillage,
          reasonNotes: 'Proper explanation exceeding ten chars',
          actorUserId: 'user-1',
          actorRole: 'STAFF_PHARMACIST',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_ZERO_DELTA'),
        )),
      );

      // Exceeding available stock (-100 when only 50 available)
      expect(
        () => client.proposeAdjustment(
          tenantId: 'ten-001',
          branchId: 'br-001',
          productId: 'prod-mox',
          productName: 'Moxacil',
          batchNumber: 'BATCH-MOX-2026-001',
          quantityDelta: -100,
          unitCost: 10.0,
          reasonCode: MobileStockAdjustmentReasonCode.breakageSpillage,
          reasonNotes: 'Proper explanation exceeding ten chars',
          actorUserId: 'user-1',
          actorRole: 'STAFF_PHARMACIST',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_INSUFFICIENT_STOCK'),
        )),
      );
    });

    test('Reversal workflow restores batch stock and creates offsetting difference event', () {
      final adj = client.proposeAdjustment(
        tenantId: 'ten-001',
        branchId: 'br-001',
        productId: 'prod-mox',
        productName: 'Moxacil',
        batchNumber: 'BATCH-MOX-2026-001',
        quantityDelta: -10,
        unitCost: 45.0,
        reasonCode: MobileStockAdjustmentReasonCode.dispensingErrorReversal,
        reasonNotes: 'Dispensing correction due to cashier system mix-up.',
        actorUserId: 'user-1',
        actorRole: 'STAFF_PHARMACIST',
      );
      client.approveAdjustment(
        adjustmentId: adj.adjustmentId,
        checkerUserId: 'user-mgr-2',
        checkerRole: 'BRANCH_MANAGER',
      );
      expect(client.getBatchStock('BATCH-MOX-2026-001'), equals(40));

      final rev = client.reverseAdjustment(
        adjustmentId: adj.adjustmentId,
        actorUserId: 'user-mgr-2',
        actorRole: 'BRANCH_MANAGER',
        reversalReason: 'Reversal due to customer returning unopened medicine.',
      );

      expect(adj.isReversed, isTrue);
      expect(rev.quantityDelta, equals(10));
      expect(client.getBatchStock('BATCH-MOX-2026-001'), equals(50));

      final revEvents = client.getDifferenceEvents(rev.adjustmentId);
      expect(revEvents.length, equals(1));
      expect(revEvents.first.quantityDelta, equals(10));
      expect(revEvents.first.postAdjustmentQuantity, equals(50));

      // Cannot reverse twice
      expect(
        () => client.reverseAdjustment(
          adjustmentId: adj.adjustmentId,
          actorUserId: 'user-mgr-2',
          actorRole: 'BRANCH_MANAGER',
          reversalReason: 'Attempting double reversal',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_ALREADY_REVERSED'),
        )),
      );
    });

    test('Cashier role is strictly denied from proposing adjustments', () {
      expect(
        () => client.proposeAdjustment(
          tenantId: 'ten-001',
          branchId: 'br-001',
          productId: 'prod-mox',
          productName: 'Moxacil',
          batchNumber: 'BATCH-MOX-2026-001',
          quantityDelta: -5,
          unitCost: 10.0,
          reasonCode: MobileStockAdjustmentReasonCode.breakageSpillage,
          reasonNotes: 'Accidental drop during cashier packing.',
          actorUserId: 'user-cashier-1',
          actorRole: 'CASHIER',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });

    test('Nontrivial flag triggered by threshold or cold-chain/narcotics/quarantine attributes', () {
      expect(
        MobileStockAdjustmentClient.isNontrivialAdjustment(quantityDelta: -2, totalCost: 20.0),
        isFalse,
      );
      expect(
        MobileStockAdjustmentClient.isNontrivialAdjustment(
          quantityDelta: -2,
          totalCost: 20.0,
          isNarcotic: true,
        ),
        isTrue,
      );
      expect(
        MobileStockAdjustmentClient.isNontrivialAdjustment(
          quantityDelta: -1,
          totalCost: 10.0,
          requiresColdChain: true,
        ),
        isTrue,
      );
      expect(
        MobileStockAdjustmentClient.isNontrivialAdjustment(
          quantityDelta: -1,
          totalCost: 10.0,
          isQuarantined: true,
        ),
        isTrue,
      );
      expect(
        MobileStockAdjustmentClient.isNontrivialAdjustment(quantityDelta: -10, totalCost: 20.0),
        isTrue,
      );
      expect(
        MobileStockAdjustmentClient.isNontrivialAdjustment(quantityDelta: -2, totalCost: 550.0),
        isTrue,
      );
    });
  });
}
