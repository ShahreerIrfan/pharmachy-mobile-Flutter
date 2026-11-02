import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/approval/mobile_approval_client.dart';

void main() {
  group('P108: MobileApprovalClient Tests', () {
    late MobileApprovalClient client;
    const tenantId = 'tn-popular-dhk';
    const branchA = 'br-dhanmondi-main';
    const branchB = 'br-gulshan-outlet';

    setUp(() {
      client = MobileApprovalClient(baseUrl: 'http://localhost:8000/api/v2');
    });

    test('P108: Cashier submits High Discount approval request successfully', () async {
      final res = await client.submitRequest(
        tenantId: tenantId,
        branchId: branchA,
        makerUsername: 'cashier_rahim',
        makerRole: 'CASHIER',
        approvalType: 'HIGH_DISCOUNT',
        title: '15% Discount on Chronic Cancer Refill',
        reason: 'Patient purchasing 2-month protocol, requested price concession.',
        amountBdt: 1500.0,
        discountPercent: 15.0,
        urgency: 'URGENT',
      );

      expect(res.isSuccess, isTrue);
      expect(res.uiStatus, equals(MobileApprovalUiStatus.success));
      expect(res.data?.status, equals('PENDING'));
      expect(res.data?.makerUsername, equals('cashier_rahim'));
      expect(res.data?.checkerUsername, isNull);
    });

    test('P108: Incomplete inputs (short title, missing reason) rejected', () async {
      final shortTitle = await client.submitRequest(
        tenantId: tenantId,
        branchId: branchA,
        makerUsername: 'cashier_rahim',
        makerRole: 'CASHIER',
        approvalType: 'REFUND',
        title: 'Rx',
        reason: 'Sufficient reason provided here.',
      );
      expect(shortTitle.uiStatus, equals(MobileApprovalUiStatus.error));
      expect(shortTitle.errorCode, equals('INVALID_TITLE'));

      final shortReason = await client.submitRequest(
        tenantId: tenantId,
        branchId: branchA,
        makerUsername: 'cashier_rahim',
        makerRole: 'CASHIER',
        approvalType: 'REFUND',
        title: 'Customer Return',
        reason: 'Bad',
      );
      expect(shortReason.uiStatus, equals(MobileApprovalUiStatus.error));
      expect(shortReason.errorCode, equals('INVALID_REASON'));
    });

    test('P108: Maker-Checker Dual-Control: self approval blocked', () async {
      final sub = await client.submitRequest(
        tenantId: tenantId,
        branchId: branchA,
        makerUsername: 'manager_tariq',
        makerRole: 'BRANCH_MANAGER',
        approvalType: 'STOCK_WRITE_OFF',
        title: 'Expired Insulin Batch 99',
        reason: 'Cold chain failure caused vial spoilage; write-off requested.',
        amountBdt: 4200.0,
      );
      expect(sub.isSuccess, isTrue);

      // Same user attempts self-approval
      final selfApprove = await client.approveRequest(
        tenantId: tenantId,
        requestId: sub.data!.requestId,
        checkerUsername: 'manager_tariq',
        checkerRole: 'BRANCH_MANAGER',
        checkerBranchId: branchA,
        decisionNotes: 'Self approved',
      );

      expect(selfApprove.uiStatus, equals(MobileApprovalUiStatus.permissionDenied));
      expect(selfApprove.errorCode, equals('ERR_CANNOT_APPROVE_OWN_REQUEST'));
      expect(selfApprove.messageBn, contains('মেকার-চেকার লঙ্ঘন'));
    });

    test('P108: Frontline staff cannot act as supervisor checker', () async {
      final sub = await client.submitRequest(
        tenantId: tenantId,
        branchId: branchA,
        makerUsername: 'cashier_rahim',
        makerRole: 'CASHIER',
        approvalType: 'REFUND',
        title: 'Defective Syringe Pack',
        reason: 'Customer returned opened pack with missing safety caps.',
        amountBdt: 120.0,
      );
      expect(sub.isSuccess, isTrue);

      final cashierApprove = await client.approveRequest(
        tenantId: tenantId,
        requestId: sub.data!.requestId,
        checkerUsername: 'cashier_karim',
        checkerRole: 'CASHIER',
        checkerBranchId: branchA,
        decisionNotes: 'Checked and OK',
      );

      expect(cashierApprove.uiStatus, equals(MobileApprovalUiStatus.permissionDenied));
      expect(cashierApprove.errorCode, equals('ERR_INSUFFICIENT_APPROVAL_AUTHORITY'));
    });

    test('P108: Branch Manager cannot approve requests for other branches', () async {
      final sub = await client.submitRequest(
        tenantId: tenantId,
        branchId: branchA,
        makerUsername: 'cashier_rahim',
        makerRole: 'CASHIER',
        approvalType: 'HIGH_DISCOUNT',
        title: 'Chronic Patient Concession',
        reason: 'Special concession for lifelong regular patient.',
        amountBdt: 300.0,
        discountPercent: 12.0,
      );
      expect(sub.isSuccess, isTrue);

      // Manager of Branch B attempts approval
      final crossApprove = await client.approveRequest(
        tenantId: tenantId,
        requestId: sub.data!.requestId,
        checkerUsername: 'manager_gulshan',
        checkerRole: 'BRANCH_MANAGER',
        checkerBranchId: branchB, // Different branch
        decisionNotes: 'Approved from another store',
      );

      expect(crossApprove.uiStatus, equals(MobileApprovalUiStatus.permissionDenied));
      expect(crossApprove.errorCode, equals('ERR_CROSS_BRANCH_VIOLATION'));
    });

    test('P108: Checker signs off, generating valid approval token', () async {
      final sub = await client.submitRequest(
        tenantId: tenantId,
        branchId: branchA,
        makerUsername: 'dispenser_hasan',
        makerRole: 'STAFF_PHARMACIST',
        approvalType: 'CLINICAL_ESCALATION',
        title: 'Methotrexate and NSAID Severe Toxicity Risk',
        reason: 'Concomitant prescription introduces severe bone marrow suppression risk.',
        urgency: 'CRITICAL',
      );
      expect(sub.isSuccess, isTrue);

      final approved = await client.approveRequest(
        tenantId: tenantId,
        requestId: sub.data!.requestId,
        checkerUsername: 'clinical_pharmacist_monir',
        checkerRole: 'STAFF_PHARMACIST',
        checkerBranchId: branchA,
        decisionNotes: 'Consulted physician; NSAID discontinued and substituted with Paracetamol.',
      );

      expect(approved.isSuccess, isTrue);
      expect(approved.data?.status, equals('APPROVED'));
      expect(approved.data?.approvalToken, isNotNull);
      expect(approved.data?.approvalToken, startsWith('tok_appr_'));

      // Verify token
      final verify = await client.verifyToken(
        tenantId: tenantId,
        approvalToken: approved.data!.approvalToken!,
      );
      expect(verify.isSuccess, isTrue);
      expect(verify.data?.requestId, equals(sub.data!.requestId));
    });

    test('P108: Offline mobile client queues request and lists pending items', () async {
      client.setSimulatedOffline(true);

      final sub = await client.submitRequest(
        tenantId: tenantId,
        branchId: branchA,
        makerUsername: 'cashier_rahim',
        makerRole: 'CASHIER',
        approvalType: 'HIGH_DISCOUNT',
        title: 'Offline Queue Request',
        reason: 'Network down, pending owner review.',
        amountBdt: 250.0,
      );

      expect(sub.uiStatus, equals(MobileApprovalUiStatus.offline));
      expect(sub.errorCode, equals('OFFLINE_QUEUED'));

      final pending = await client.getPendingRequests(
        tenantId: tenantId,
        branchId: branchA,
      );
      expect(pending.isSuccess, isTrue);
      expect(pending.data?.length, equals(1));
    });
  });
}
