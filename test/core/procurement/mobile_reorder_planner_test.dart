import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_reorder_planner_client.dart';

void main() {
  group('MobileReorderPlannerClient Tests (ADR-0194 / P194)', () {
    late Map<String, MobileReorderProposal> proposalStore;
    late Map<String, Map<String, dynamic>> poStore;
    late MobileReorderPlannerClient managerClient;
    late MobileReorderPlannerClient cashierClient;

    setUp(() {
      proposalStore = {};
      poStore = {};

      managerClient = MobileReorderPlannerClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        proposalStore: proposalStore,
        poStore: poStore,
      );

      cashierClient = MobileReorderPlannerClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        proposalStore: proposalStore,
        poStore: poStore,
      );
    });

    MobileReorderItem createSampleItem({
      required String itemId,
      required String prodId,
      required String prodName,
      required String supId,
      required String supName,
      required int curStock,
      required int effStock,
      required int rawRec,
      required double unitCost,
    }) {
      return MobileReorderItem(
        itemId: itemId,
        productId: prodId,
        productName: prodName,
        suggestedSupplierId: supId,
        supplierName: supName,
        currentStockUnits: curStock,
        effectiveStockUnits: effStock,
        rawRecommendedUnits: rawRec,
        approvedOrderUnits: rawRec,
        estimatedUnitCost: unitCost,
        estimatedLineCost: double.parse((unitCost * rawRec).toStringAsFixed(4)),
        urgency: 'HIGH',
        stockoutRiskDays: 1.5,
      );
    }

    test('01. Generates reorder plan with calculated metrics', () {
      final items = [
        createSampleItem(
          itemId: 'itm-1',
          prodId: 'prod-napa',
          prodName: 'Napa Extra',
          supId: 'sup-sq',
          supName: 'Square Pharma',
          curStock: 5,
          effStock: 3,
          rawRec: 40,
          unitCost: 2.5,
        ),
        createSampleItem(
          itemId: 'itm-2',
          prodId: 'prod-ace',
          prodName: 'Ace Plus',
          supId: 'sup-sq',
          supName: 'Square Pharma',
          curStock: 8,
          effStock: 8,
          rawRec: 30,
          unitCost: 3.0,
        ),
      ];

      final plan = managerClient.generateReorderPlan(
        planningHorizonDays: 14,
        calculatedRecommendations: items,
      );

      expect(plan.status, equals('DRAFT_PROPOSAL'));
      expect(plan.totalRecommendedSkus, equals(2));
      expect(plan.totalEstimatedCost, equals(190.0));
      expect(plan.items.length, equals(2));
    });

    test('02. Never auto-orders silently: blocks unapproved conversion', () {
      final items = [
        createSampleItem(
          itemId: 'itm-1',
          prodId: 'prod-napa',
          prodName: 'Napa Extra',
          supId: 'sup-sq',
          supName: 'Square Pharma',
          curStock: 5,
          effStock: 3,
          rawRec: 40,
          unitCost: 2.5,
        ),
      ];
      final plan = managerClient.generateReorderPlan(
        planningHorizonDays: 14,
        calculatedRecommendations: items,
      );

      expect(
        () => managerClient.convertToPurchaseOrders(proposalId: plan.proposalId),
        throwsA(isA<Exception>().having((e) => e.toString(), 'detail',
            contains('ERR_PLAN_NOT_APPROVED'))),
      );
    });

    test('03. Managerial approval with item adjustments', () {
      final items = [
        createSampleItem(
          itemId: 'itm-1',
          prodId: 'prod-napa',
          prodName: 'Napa Extra',
          supId: 'sup-sq',
          supName: 'Square Pharma',
          curStock: 5,
          effStock: 5,
          rawRec: 50,
          unitCost: 10.0,
        ),
      ];
      final plan = managerClient.generateReorderPlan(
        planningHorizonDays: 14,
        calculatedRecommendations: items,
      );

      final approved = managerClient.approveReorderPlan(
        proposalId: plan.proposalId,
        reviewNotes: 'Manager adjusted batch volume',
        itemAdjustments: {'itm-1': 70},
      );

      expect(approved.status, equals('APPROVED'));
      expect(approved.reviewedBy, equals('usr-mgr-1'));
      expect(approved.items.first.approvedOrderUnits, equals(70));
      expect(approved.totalEstimatedCost, equals(700.0));
    });

    test('04. Converts approved plan to POs grouped by supplier', () {
      final items = [
        createSampleItem(
          itemId: 'itm-1',
          prodId: 'prod-napa',
          prodName: 'Napa Extra',
          supId: 'sup-sq',
          supName: 'Square Pharma',
          curStock: 5,
          effStock: 5,
          rawRec: 20,
          unitCost: 10.0,
        ),
        createSampleItem(
          itemId: 'itm-2',
          prodId: 'prod-bex',
          prodName: 'Napa Extend',
          supId: 'sup-bx',
          supName: 'Beximco Pharma',
          curStock: 2,
          effStock: 2,
          rawRec: 15,
          unitCost: 20.0,
        ),
      ];
      final plan = managerClient.generateReorderPlan(
        planningHorizonDays: 14,
        calculatedRecommendations: items,
      );
      managerClient.approveReorderPlan(proposalId: plan.proposalId);

      final poIds =
          managerClient.convertToPurchaseOrders(proposalId: plan.proposalId);

      expect(poIds.length, equals(2));
      expect(plan.status, equals('CONVERTED_TO_PO'));
      expect(poStore.length, equals(2));
    });

    test('05. Dismisses reorder proposal', () {
      final items = [
        createSampleItem(
          itemId: 'itm-1',
          prodId: 'prod-napa',
          prodName: 'Napa Extra',
          supId: 'sup-sq',
          supName: 'Square Pharma',
          curStock: 5,
          effStock: 5,
          rawRec: 20,
          unitCost: 10.0,
        ),
      ];
      final plan = managerClient.generateReorderPlan(
        planningHorizonDays: 14,
        calculatedRecommendations: items,
      );

      final dismissed = managerClient.dismissReorderPlan(
        proposalId: plan.proposalId,
        reason: 'Surplus transfer coming from Central warehouse',
      );

      expect(dismissed.status, equals('DISMISSED'));
      expect(dismissed.reviewNotes, contains('Surplus transfer'));
    });

    test('06. Cannot dismiss already converted proposal', () {
      final items = [
        createSampleItem(
          itemId: 'itm-1',
          prodId: 'prod-napa',
          prodName: 'Napa Extra',
          supId: 'sup-sq',
          supName: 'Square Pharma',
          curStock: 5,
          effStock: 5,
          rawRec: 20,
          unitCost: 10.0,
        ),
      ];
      final plan = managerClient.generateReorderPlan(
        planningHorizonDays: 14,
        calculatedRecommendations: items,
      );
      managerClient.approveReorderPlan(proposalId: plan.proposalId);
      managerClient.convertToPurchaseOrders(proposalId: plan.proposalId);

      expect(
        () => managerClient.dismissReorderPlan(
          proposalId: plan.proposalId,
          reason: 'Try dismiss',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'detail',
            contains('ERR_CANNOT_DISMISS_CONVERTED'))),
      );
    });

    test('07. Cashier role access denied', () {
      expect(
        () => cashierClient.generateReorderPlan(planningHorizonDays: 14),
        throwsA(isA<Exception>().having((e) => e.toString(), 'detail',
            contains('ERR_STAFF_ROLE_DENIED'))),
      );
    });
  });
}
