import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_packaging_hierarchy_client.dart';

void main() {
  late MobilePackagingHierarchyClient client;
  late List<MobilePackagingNode> standardNodes;

  setUp(() {
    client = MobilePackagingHierarchyClient();
    standardNodes = [
      MobilePackagingNode(
        nodeId: 'pkn-01',
        productId: 'prod-napa-500',
        parentUnit: 'CARTON',
        childUnit: 'BOX',
        conversionFactor: 10,
        tierLevel: 3,
        effectiveFrom: DateTime(2026, 1, 1),
      ),
      MobilePackagingNode(
        nodeId: 'pkn-02',
        productId: 'prod-napa-500',
        parentUnit: 'BOX',
        childUnit: 'STRIP',
        conversionFactor: 10,
        tierLevel: 2,
        effectiveFrom: DateTime(2026, 1, 1),
      ),
      MobilePackagingNode(
        nodeId: 'pkn-03',
        productId: 'prod-napa-500',
        parentUnit: 'STRIP',
        childUnit: 'TABLET',
        conversionFactor: 10,
        tierLevel: 1,
        isBaseLevel: true,
        effectiveFrom: DateTime(2026, 1, 1),
      ),
    ];
  });

  group('MobilePackagingHierarchyClient Tests (P162)', () {
    test('1. Valid scenario: Resolves 3-tier tree with cumulative multipliers', () {
      final tree = client.resolvePackagingTree(
        productId: 'prod-napa-500',
        nodes: standardNodes,
        asOfDate: DateTime(2026, 6, 1),
      );

      expect(tree.baseUnit, 'TABLET');
      expect(tree.chain.length, 3);
      expect(tree.cumulativeFactors['CARTON'], 1000);
      expect(tree.cumulativeFactors['BOX'], 100);
      expect(tree.cumulativeFactors['STRIP'], 10);
      expect(tree.cumulativeFactors['TABLET'], 1);
    });

    test('2. Valid scenario: Converts 2 Cartons to Strips and 5 Boxes to Tablets', () {
      final res1 = client.convertPackagingTier(
        productId: 'prod-napa-500',
        fromUnit: 'CARTON',
        toUnit: 'STRIP',
        quantity: 2.0,
        nodes: standardNodes,
        asOfDate: DateTime(2026, 6, 1),
      );
      expect(res1.success, isTrue);
      expect(res1.convertedQuantity, 200.0);

      final res2 = client.convertPackagingTier(
        productId: 'prod-napa-500',
        fromUnit: 'BOX',
        toUnit: 'TABLET',
        quantity: 5.0,
        nodes: standardNodes,
        asOfDate: DateTime(2026, 6, 1),
      );
      expect(res2.success, isTrue);
      expect(res2.convertedQuantity, 500.0);
    });

    test('3. Effective date switching: Historical vs new factor resolution', () {
      final datedNodes = [
        MobilePackagingNode(
          nodeId: 'pkn-old',
          productId: 'prod-napa-500',
          parentUnit: 'BOX',
          childUnit: 'STRIP',
          conversionFactor: 10,
          tierLevel: 2,
          effectiveFrom: DateTime(2025, 1, 1),
          effectiveTo: DateTime(2026, 5, 31),
        ),
        MobilePackagingNode(
          nodeId: 'pkn-new',
          productId: 'prod-napa-500',
          parentUnit: 'BOX',
          childUnit: 'STRIP',
          conversionFactor: 20,
          tierLevel: 2,
          effectiveFrom: DateTime(2026, 6, 1),
        ),
        MobilePackagingNode(
          nodeId: 'pkn-strip',
          productId: 'prod-napa-500',
          parentUnit: 'STRIP',
          childUnit: 'TABLET',
          conversionFactor: 10,
          tierLevel: 1,
          isBaseLevel: true,
          effectiveFrom: DateTime(2025, 1, 1),
        ),
      ];

      final resOld = client.convertPackagingTier(
        productId: 'prod-napa-500',
        fromUnit: 'BOX',
        toUnit: 'TABLET',
        quantity: 1.0,
        nodes: datedNodes,
        asOfDate: DateTime(2026, 5, 15),
      );
      expect(resOld.success, isTrue);
      expect(resOld.convertedQuantity, 100.0);

      final resNew = client.convertPackagingTier(
        productId: 'prod-napa-500',
        fromUnit: 'BOX',
        toUnit: 'TABLET',
        quantity: 1.0,
        nodes: datedNodes,
        asOfDate: DateTime(2026, 7, 1),
      );
      expect(resNew.success, isTrue);
      expect(resNew.convertedQuantity, 200.0);
    });

    test('4. Cycle detection: Self cycle and circular dependency detected', () {
      expect(client.hasCycle('BOX', 'BOX', standardNodes), isTrue);
      expect(client.hasCycle('TABLET', 'CARTON', standardNodes), isTrue);
      expect(client.hasCycle('PALLET', 'CARTON', standardNodes), isFalse);
    });

    test('5. Unlinked tier rejection: Non-existent tier rejected', () {
      final res = client.convertPackagingTier(
        productId: 'prod-napa-500',
        fromUnit: 'BOTTLE',
        toUnit: 'TABLET',
        quantity: 1.0,
        nodes: standardNodes,
        asOfDate: DateTime(2026, 6, 1),
      );
      expect(res.success, isFalse);
      expect(res.errorCode, 'ERR_UNLINKED_PACKAGING_TIER');
    });

    test('6. Role authorization: Cashier blocked from configuring packaging', () {
      expect(client.canConfigurePackaging('OWNER'), isTrue);
      expect(client.canConfigurePackaging('MANAGER'), isTrue);
      expect(client.canConfigurePackaging('PHARMACIST'), isTrue);
      expect(client.canConfigurePackaging('CASHIER'), isFalse);
      expect(client.canConfigurePackaging(null), isFalse);
    });
  });
}

