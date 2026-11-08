import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_inventory_count_client.dart';

void main() {
  group('MobileInventoryCountClient Tests (ADR-0204 / P204)', () {
    late MobileInventoryCountClient client;
    const tenantId = 'ten-banani-01';
    const branchId = 'br-main';

    setUp(() {
      client = MobileInventoryCountClient();
    });

    test('1. Full count cycle, discrepancy calculation and posting', () {
      // 1. Pharmacist creates session
      final session = client.createSession(
        tenantId: tenantId,
        branchId: branchId,
        type: MobileCountSessionType.cycleCount,
        actorRole: 'STAFF_PHARMACIST',
        actorUserId: 'usr-maker-01',
      );
      expect(session.status, equals(MobileCountSessionStatus.inProgress));

      // 2. Scan Batch 1 (Surplus: 100 system, 110 counted -> +10)
      final item1 = client.recordScanItem(
        sessionId: session.sessionId,
        batchNumber: 'BAT-01',
        systemQuantity: 100,
        countedQuantity: 110,
        unitCost: 2.50,
        actorRole: 'STAFF_PHARMACIST',
      );
      expect(item1.discrepancyQuantity, equals(10));
      expect(item1.discrepancyType, equals(MobileCountDiscrepancyType.surplus));
      expect(item1.costDiscrepancyBdt, closeTo(25.0, 0.001));

      // 3. Scan Batch 2 (Shortage: 50 system, 45 counted -> -5)
      final item2 = client.recordScanItem(
        sessionId: session.sessionId,
        batchNumber: 'BAT-02',
        systemQuantity: 50,
        countedQuantity: 45,
        unitCost: 2.50,
        actorRole: 'STAFF_PHARMACIST',
      );
      expect(item2.discrepancyQuantity, equals(-5));
      expect(item2.discrepancyType, equals(MobileCountDiscrepancyType.shortage));
      expect(item2.costDiscrepancyBdt, closeTo(-12.50, 0.001));

      // Session totals
      expect(session.items.length, equals(2));
      expect(session.totalDiscrepancyUnits, equals(5));
      expect(session.totalCostDiscrepancyBdt, closeTo(12.50, 0.001));
      expect(session.surplusCount, equals(1));
      expect(session.shortageCount, equals(1));

      // 4. Maker submits
      client.submitForReview(
        sessionId: session.sessionId,
        actorRole: 'STAFF_PHARMACIST',
        actorUserId: 'usr-maker-01',
      );
      expect(session.status, equals(MobileCountSessionStatus.submittedForReview));

      // 5. Manager approves
      client.reviewSession(
        sessionId: session.sessionId,
        isApproved: true,
        checkerRole: 'BRANCH_MANAGER',
        checkerUserId: 'usr-checker-02',
        checkerNotes: 'Count sheet verified',
      );
      expect(session.status, equals(MobileCountSessionStatus.approved));

      // 6. Post adjustments
      final postRes = client.postAdjustments(
        sessionId: session.sessionId,
        actorRole: 'BRANCH_MANAGER',
      );
      expect(postRes['status'], equals('posted'));
      expect(postRes['postedAdjustments'], equals(2));
      expect(item1.adjustmentLedgerEntryId, isNotNull);
      expect(item2.adjustmentLedgerEntryId, isNotNull);
    });

    test('2. Maker-checker anti-self-approval enforcement', () {
      final session = client.createSession(
        tenantId: tenantId,
        branchId: branchId,
        type: MobileCountSessionType.spotCheck,
        actorRole: 'BRANCH_MANAGER',
        actorUserId: 'usr-manager-01',
      );

      client.recordScanItem(
        sessionId: session.sessionId,
        batchNumber: 'BAT-01',
        systemQuantity: 20,
        countedQuantity: 22,
        unitCost: 1.0,
        actorRole: 'BRANCH_MANAGER',
      );

      client.submitForReview(
        sessionId: session.sessionId,
        actorRole: 'BRANCH_MANAGER',
        actorUserId: 'usr-manager-01',
      );

      // Self approval rejected
      expect(
        () => client.reviewSession(
          sessionId: session.sessionId,
          isApproved: true,
          checkerRole: 'BRANCH_MANAGER',
          checkerUserId: 'usr-manager-01',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_MAKER_CHECKER_SELF_APPROVAL'),
        )),
      );
    });

    test('3. Reject negative quantity and empty session submission', () {
      final session = client.createSession(
        tenantId: tenantId,
        branchId: branchId,
        type: MobileCountSessionType.cycleCount,
        actorRole: 'STAFF_PHARMACIST',
        actorUserId: 'usr-maker-01',
      );

      expect(
        () => client.recordScanItem(
          sessionId: session.sessionId,
          batchNumber: 'B1',
          systemQuantity: 10,
          countedQuantity: -3,
          unitCost: 1.0,
          actorRole: 'STAFF_PHARMACIST',
        ),
        throwsArgumentError,
      );

      expect(
        () => client.submitForReview(
          sessionId: session.sessionId,
          actorRole: 'STAFF_PHARMACIST',
          actorUserId: 'usr-maker-01',
        ),
        throwsArgumentError,
      );
    });

    test('4. Cashier RBAC rejection', () {
      expect(
        () => client.createSession(
          tenantId: tenantId,
          branchId: branchId,
          type: MobileCountSessionType.cycleCount,
          actorRole: 'CASHIER',
          actorUserId: 'usr-c1',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });

    test('5. Re-posting guardrail prevents duplicate adjustments', () {
      final session = client.createSession(
        tenantId: tenantId,
        branchId: branchId,
        type: MobileCountSessionType.cycleCount,
        actorRole: 'STAFF_PHARMACIST',
        actorUserId: 'usr-m1',
      );
      client.recordScanItem(
        sessionId: session.sessionId,
        batchNumber: 'B1',
        systemQuantity: 10,
        countedQuantity: 12,
        unitCost: 1.0,
        actorRole: 'STAFF_PHARMACIST',
      );
      client.submitForReview(
        sessionId: session.sessionId,
        actorRole: 'STAFF_PHARMACIST',
        actorUserId: 'usr-m1',
      );
      client.reviewSession(
        sessionId: session.sessionId,
        isApproved: true,
        checkerRole: 'BRANCH_MANAGER',
        checkerUserId: 'usr-c2',
      );
      client.postAdjustments(
        sessionId: session.sessionId,
        actorRole: 'BRANCH_MANAGER',
      );

      // Re-posting must throw
      expect(
        () => client.postAdjustments(
          sessionId: session.sessionId,
          actorRole: 'BRANCH_MANAGER',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_ALREADY_POSTED'),
        )),
      );
    });
  });
}
