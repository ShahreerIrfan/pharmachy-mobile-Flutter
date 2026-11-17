import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_inventory_valuation_client.dart';

void main() {
  group('P216: MobileInventoryValuationClient Tests', () {
    late MobileInventoryValuationClient client;

    setUp(() {
      client = MobileInventoryValuationClient();
    });

    test('1. Valid scenario: Multi-category valuation and mathematical balance', () {
      final sellable = MobileValuationLineItem(
        productId: 'prod-nap-01',
        productName: 'Napa Extra 500mg',
        batchNumber: 'NAP-001',
        category: MobileInventoryCategory.sellable,
        quantityBaseUnits: 50,
        unitCost: 2.50,
      );

      final quarantined = MobileValuationLineItem(
        productId: 'prod-ins-01',
        productName: 'Mixtard 30 100IU',
        batchNumber: 'INS-002',
        category: MobileInventoryCategory.quarantined,
        quantityBaseUnits: 20,
        unitCost: 420.00,
        isColdChain: true,
      );

      final expired = MobileValuationLineItem(
        productId: 'prod-nap-01',
        productName: 'Napa Extra 500mg',
        batchNumber: 'NAP-EXP',
        category: MobileInventoryCategory.expired,
        quantityBaseUnits: 10,
        unitCost: 2.50,
      );

      final inTransit = MobileValuationLineItem(
        productId: 'prod-ins-01',
        productName: 'Mixtard 30 100IU',
        batchNumber: 'INS-TRF',
        category: MobileInventoryCategory.inTransit,
        quantityBaseUnits: 15,
        unitCost: 420.00,
        isColdChain: true,
      );

      final report = client.generateReport(
        userRole: 'PHARMACY_OWNER',
        tenantId: 'ten-united',
        branchId: 'br-central',
        costingRule: MobileValuationCostingRule.fefoLotCost,
        lines: [sellable, quarantined, expired, inTransit],
      );

      expect(report.totalOnHandUnits, 80);
      expect(report.totalOnHandValueBdt, 8550.00);
      expect(report.sellableUnits, 50);
      expect(report.sellableValueBdt, 125.00);
      expect(report.quarantinedUnits, 20);
      expect(report.quarantinedValueBdt, 8400.00);
      expect(report.expiredUnits, 10);
      expect(report.expiredValueBdt, 25.00);
      expect(report.inTransitUnits, 15);
      expect(report.inTransitValueBdt, 6300.00);
      expect(report.coldChainUnits, 20);
      expect(report.coldChainValueBdt, 8400.00);

      expect(report.isMathematicallyBalanced, isTrue);
      expect(report.discrepancyUnits, 0);
      expect(report.discrepancyValueBdt, 0.00);
      expect(client.verifyIntegrity(report), isTrue);
    });

    test('2. Fails cryptographic integrity if line items are tampered with', () {
      final item = MobileValuationLineItem(
        productId: 'prod-01',
        productName: 'Item A',
        batchNumber: 'BAT-01',
        category: MobileInventoryCategory.sellable,
        quantityBaseUnits: 100,
        unitCost: 10.0,
      );

      final report = client.generateReport(
        userRole: 'BRANCH_MANAGER',
        tenantId: 'ten-01',
        branchId: 'br-01',
        costingRule: MobileValuationCostingRule.fifoLotCost,
        lines: [item],
      );

      expect(client.verifyIntegrity(report), isTrue);

      // Create tampered line item
      final tamperedItem = MobileValuationLineItem(
        productId: 'prod-01',
        productName: 'Item A',
        batchNumber: 'BAT-01',
        category: MobileInventoryCategory.sellable,
        quantityBaseUnits: 999, // tampered
        unitCost: 10.0,
      );

      final tamperedReport = MobileValuationReport(
        reportId: report.reportId,
        tenantId: report.tenantId,
        branchId: report.branchId,
        asOfTimestamp: report.asOfTimestamp,
        costingRule: report.costingRule,
        totalOnHandUnits: 999,
        totalOnHandValueBdt: 9990.0,
        sellableUnits: 999,
        sellableValueBdt: 9990.0,
        quarantinedUnits: 0,
        quarantinedValueBdt: 0.0,
        inTransitUnits: 0,
        inTransitValueBdt: 0.0,
        expiredUnits: 0,
        expiredValueBdt: 0.0,
        coldChainUnits: 0,
        coldChainValueBdt: 0.0,
        isMathematicallyBalanced: true,
        discrepancyUnits: 0,
        discrepancyValueBdt: 0.0,
        sha256Checksum: report.sha256Checksum, // old hash
        lineItems: [tamperedItem],
      );

      expect(client.verifyIntegrity(tamperedReport), isFalse);
    });

    test('3. Denies CASHIER role with StateError', () {
      expect(
        () => client.generateReport(
          userRole: 'CASHIER',
          tenantId: 'ten-01',
          branchId: 'br-01',
          costingRule: MobileValuationCostingRule.fefoLotCost,
          lines: [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('4. Correctly verifies weighted average costing rule', () {
      final item = MobileValuationLineItem(
        productId: 'prod-wavg',
        productName: 'Product W',
        batchNumber: 'BAT-W',
        category: MobileInventoryCategory.sellable,
        quantityBaseUnits: 40,
        unitCost: 175.0,
      );

      final report = client.generateReport(
        userRole: 'STAFF_PHARMACIST',
        tenantId: 'ten-01',
        branchId: 'br-01',
        costingRule: MobileValuationCostingRule.weightedAverage,
        lines: [item],
      );

      expect(report.totalOnHandValueBdt, 7000.0);
      expect(report.isMathematicallyBalanced, isTrue);
    });
  });
}
