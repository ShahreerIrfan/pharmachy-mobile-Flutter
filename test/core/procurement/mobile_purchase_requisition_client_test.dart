// mobile_purchase_requisition_client_test.dart
// Architecture Decision: ADR-0184 (P184).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_purchase_requisition_client.dart';

void main() {
  group('MobilePurchaseRequisitionClient Tests (P184)', () {
    late MobilePurchaseRequisitionClient managerClient;
    late MobilePurchaseRequisitionClient pharmacistClient;
    late MobilePurchaseRequisitionClient cashierClient;
    late MobilePurchaseRequisitionClient foreignClient;

    setUp(() {
      final sharedStore = <String, MobilePurchaseRequisition>{};

      managerClient = MobilePurchaseRequisitionClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        initialStore: sharedStore,
      );

      pharmacistClient = MobilePurchaseRequisitionClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'STAFF_PHARMACIST',
        userId: 'usr-pharm-1',
        initialStore: sharedStore,
      );

      cashierClient = MobilePurchaseRequisitionClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        initialStore: sharedStore,
      );

      foreignClient = MobilePurchaseRequisitionClient(
        tenantId: 'tenant-other',
        branchId: 'branch-2',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-2',
        initialStore: sharedStore,
      );
    });

    test('Test 1: Valid requisition drafting, item calculation, and submission',
        () {
      final items = [
        MobilePurchaseRequisitionItem(
          itemId: 'pri-1',
          productId: 'prod-napa-500',
          productName: 'Napa Extra',
          packageType: 'BOX',
          packageSize: 100,
          requestedQuantity: 50,
          estimatedUnitCost: 2.50,
        ),
        MobilePurchaseRequisitionItem(
          itemId: 'pri-2',
          productId: 'prod-seclo-20',
          productName: 'Seclo 20mg',
          packageType: 'STRIP',
          packageSize: 10,
          requestedQuantity: 100,
          estimatedUnitCost: 5.00,
        ),
      ];

      // Total = (50 * 2.50) + (100 * 5.00) = 125.0 + 500.0 = 625.0
      final req = pharmacistClient.createRequisition(
        department: 'DISPENSARY',
        priority: 'HIGH',
        allocatedBudget: 1000.0,
        justification: 'Replenishing monthly OPD buffer',
        items: items,
      );

      expect(req.requisitionId, startsWith('req-'));
      expect(req.tenantId, equals('tenant-evercare'));
      expect(req.department, equals('DISPENSARY'));
      expect(req.priority, equals('HIGH'));
      expect(req.status, equals('DRAFT'));
      expect(req.totalEstimatedCost, equals(625.0));
      expect(req.items.length, equals(2));

      // Submit under budget
      final submitted = pharmacistClient.submitRequisition(
        requisitionId: req.requisitionId,
        budgetOverride: false,
      );
      expect(submitted.status, equals('SUBMITTED'));
      expect(submitted.submittedById, equals('usr-pharm-1'));
      expect(submitted.submittedAt, isNotNull);
    });

    test('Test 2: Budget ceiling guard rejects submission when total exceeds budget',
        () {
      final items = [
        MobilePurchaseRequisitionItem(
          itemId: 'pri-1',
          productId: 'prod-napa-500',
          requestedQuantity: 100,
          estimatedUnitCost: 10.0, // 1000.0
        ),
      ];

      // Allocated budget is 500.0, cost is 1000.0
      final req = pharmacistClient.createRequisition(
        department: 'CENTRAL_STORE',
        allocatedBudget: 500.0,
        items: items,
      );

      // Submission without override fails
      expect(
        () => pharmacistClient.submitRequisition(
          requisitionId: req.requisitionId,
          budgetOverride: false,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Submission with override succeeds
      final submitted = pharmacistClient.submitRequisition(
        requisitionId: req.requisitionId,
        budgetOverride: true,
      );
      expect(submitted.status, equals('SUBMITTED'));
    });

    test('Test 3: Multi-tier approval and rejection lifecycle', () {
      final items = [
        MobilePurchaseRequisitionItem(
          itemId: 'pri-1',
          productId: 'prod-ace-500',
          requestedQuantity: 10,
          estimatedUnitCost: 2.0,
        ),
      ];

      // Req 1: Approved by Manager
      final req1 = pharmacistClient.createRequisition(
        department: 'OT_PHARMACY',
        priority: 'EMERGENCY',
        items: items,
      );
      pharmacistClient.submitRequisition(requisitionId: req1.requisitionId);

      final approved = managerClient.approveRequisition(
        requisitionId: req1.requisitionId,
        approvalNotes: 'Fast-track surgery approval',
      );
      expect(approved.status, equals('APPROVED'));
      expect(approved.approvedById, equals('usr-mgr-1'));
      expect(approved.approvalNotes, equals('Fast-track surgery approval'));

      // Cannot cancel approved requisition
      expect(
        () => pharmacistClient.cancelRequisition(approved.requisitionId),
        throwsA(isA<StateError>()),
      );

      // Req 2: Rejected by Manager with mandatory reason
      final req2 = pharmacistClient.createRequisition(
        department: 'INPATIENT',
        priority: 'LOW',
        items: items,
      );
      pharmacistClient.submitRequisition(requisitionId: req2.requisitionId);

      // Blank rejection reason fails
      expect(
        () => managerClient.rejectRequisition(
          requisitionId: req2.requisitionId,
          rejectionReason: '',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final rejected = managerClient.rejectRequisition(
        requisitionId: req2.requisitionId,
        rejectionReason: 'Stock available in main pharmacy',
      );
      expect(rejected.status, equals('REJECTED'));
      expect(rejected.rejectedById, equals('usr-mgr-1'));
      expect(rejected.rejectionReason, equals('Stock available in main pharmacy'));
    });

    test('Test 4: RBAC permissions and cross-tenant boundary isolation', () {
      final items = [
        MobilePurchaseRequisitionItem(
          itemId: 'pri-1',
          productId: 'prod-1',
          requestedQuantity: 5,
          estimatedUnitCost: 2.0,
        ),
      ];

      // Cashier role blocked
      expect(
        () => cashierClient.createRequisition(items: items),
        throwsA(isA<StateError>()),
      );

      // Pharmacist creates and submits
      final req = pharmacistClient.createRequisition(items: items);
      pharmacistClient.submitRequisition(requisitionId: req.requisitionId);

      // Pharmacist cannot approve
      expect(
        () => pharmacistClient.approveRequisition(requisitionId: req.requisitionId),
        throwsA(isA<StateError>()),
      );

      // Foreign tenant cannot access or approve
      expect(
        () => foreignClient.getRequisition(req.requisitionId),
        throwsA(isA<StateError>()),
      );
      expect(
        () => foreignClient.approveRequisition(requisitionId: req.requisitionId),
        throwsA(isA<StateError>()),
      );
    });
  });
}

