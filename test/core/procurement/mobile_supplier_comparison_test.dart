import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_supplier_comparison_client.dart';

void main() {
  group('MobileSupplierComparisonClient Tests (ADR-0195 / P195)', () {
    late Map<String, MobileComparisonEvaluation> evaluationStore;
    late Map<String, Map<String, dynamic>> poStore;
    late MobileSupplierComparisonClient managerClient;
    late MobileSupplierComparisonClient cashierClient;

    setUp(() {
      evaluationStore = {};
      poStore = {};

      managerClient = MobileSupplierComparisonClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        evaluationStore: evaluationStore,
        poStore: poStore,
      );

      cashierClient = MobileSupplierComparisonClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        evaluationStore: evaluationStore,
        poStore: poStore,
      );
    });

    MobileComparisonLine createLine({
      required String lineId,
      required String supId,
      required String supName,
      required double unitCost,
      required double discount,
      required int moq,
      required int leadTime,
      required int termsDays,
      required double relScore,
    }) {
      return MobileComparisonLine(
        lineId: lineId,
        supplierId: supId,
        supplierName: supName,
        packageType: 'BOX_100',
        packageSize: 100,
        packageCostPrice: unitCost * 100,
        unitCostPrice: unitCost,
        discountPercentage: discount,
        minimumOrderQuantity: moq,
        leadTimeDays: leadTime,
        paymentTermsDays: termsDays,
        deliveryReliabilityScore: relScore,
        proofOfOriginVerified: true,
      );
    }

    test('01. Ranks and scores candidate suppliers', () {
      final l1 = createLine(
        lineId: 'l-1',
        supId: 'sup-sq',
        supName: 'Square Pharma',
        unitCost: 1.80,
        discount: 5.0,
        moq: 50,
        leadTime: 1,
        termsDays: 30,
        relScore: 100.0,
      );

      final l2 = createLine(
        lineId: 'l-2',
        supId: 'sup-bx',
        supName: 'Beximco Pharma',
        unitCost: 1.85,
        discount: 10.0,
        moq: 100,
        leadTime: 3,
        termsDays: 45,
        relScore: 50.0,
      );

      final ranked = managerClient.rankAndScoreLines([l1, l2]);

      expect(ranked.length, equals(2));
      final top = ranked.first;
      expect(top.supplierId, equals('sup-sq'));
      expect(top.isRecommended, isTrue);
      expect(top.compositeRank, equals(1));
    });

    test('02. Creates comparison evaluation snapshot', () {
      final l1 = createLine(
        lineId: 'l-1',
        supId: 'sup-sq',
        supName: 'Square Pharma',
        unitCost: 1.80,
        discount: 5.0,
        moq: 50,
        leadTime: 1,
        termsDays: 30,
        relScore: 100.0,
      );

      final eval = managerClient.createComparisonEvaluation(
        productId: 'prod-napa',
        productName: 'Napa 500mg',
        targetOrderQuantity: 100,
        rawLines: [l1],
        notes: 'Clinical evaluation committee',
      );

      expect(eval.status, equals('DRAFT'));
      expect(eval.lines.length, equals(1));
      expect(eval.evaluationNumber.startsWith('SCE-'), isTrue);
    });

    test('03. Selects supplier and generates Purchase Order', () {
      final l1 = createLine(
        lineId: 'l-1',
        supId: 'sup-sq',
        supName: 'Square Pharma',
        unitCost: 1.80,
        discount: 5.0,
        moq: 50,
        leadTime: 1,
        termsDays: 30,
        relScore: 100.0,
      );

      final eval = managerClient.createComparisonEvaluation(
        productId: 'prod-napa',
        productName: 'Napa 500mg',
        targetOrderQuantity: 100,
        rawLines: [l1],
      );

      final po = managerClient.selectSupplierAndCreatePo(
        evaluationId: eval.evaluationId,
        selectedSupplierId: 'sup-sq',
        selectionReason: 'Optimal composite rank with 100% on-time delivery',
        orderQuantity: 100,
      );

      expect(po['supplier_id'], equals('sup-sq'));
      expect(po['total_amount'], equals(171.0)); // 180 - 5% = 171.0
      expect(eval.status, equals('ORDER_PLACED'));
      expect(eval.createdPoId, equals(po['po_id']));
    });

    test('04. Fails when order quantity violates MOQ', () {
      final l1 = createLine(
        lineId: 'l-1',
        supId: 'sup-sq',
        supName: 'Square Pharma',
        unitCost: 1.80,
        discount: 5.0,
        moq: 50,
        leadTime: 1,
        termsDays: 30,
        relScore: 100.0,
      );

      final eval = managerClient.createComparisonEvaluation(
        productId: 'prod-napa',
        productName: 'Napa 500mg',
        targetOrderQuantity: 100,
        rawLines: [l1],
      );

      expect(
        () => managerClient.selectSupplierAndCreatePo(
          evaluationId: eval.evaluationId,
          selectedSupplierId: 'sup-sq',
          selectionReason: 'Testing MOQ violation',
          orderQuantity: 20,
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'detail',
            contains('ERR_BELOW_MINIMUM_ORDER_QTY'))),
      );
    });

    test('05. Prevents duplicate order placement from finalized evaluation', () {
      final l1 = createLine(
        lineId: 'l-1',
        supId: 'sup-sq',
        supName: 'Square Pharma',
        unitCost: 1.80,
        discount: 5.0,
        moq: 50,
        leadTime: 1,
        termsDays: 30,
        relScore: 100.0,
      );

      final eval = managerClient.createComparisonEvaluation(
        productId: 'prod-napa',
        productName: 'Napa 500mg',
        targetOrderQuantity: 100,
        rawLines: [l1],
      );

      managerClient.selectSupplierAndCreatePo(
        evaluationId: eval.evaluationId,
        selectedSupplierId: 'sup-sq',
        selectionReason: 'First order',
        orderQuantity: 100,
      );

      expect(
        () => managerClient.selectSupplierAndCreatePo(
          evaluationId: eval.evaluationId,
          selectedSupplierId: 'sup-sq',
          selectionReason: 'Second order',
          orderQuantity: 100,
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'detail',
            contains('ERR_ORDER_ALREADY_PLACED'))),
      );
    });

    test('06. Cashier access denied', () {
      expect(
        () => cashierClient.createComparisonEvaluation(
          productId: 'prod-napa',
          rawLines: [],
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'detail',
            contains('ERR_STAFF_ROLE_DENIED'))),
      );
    });
  });
}
