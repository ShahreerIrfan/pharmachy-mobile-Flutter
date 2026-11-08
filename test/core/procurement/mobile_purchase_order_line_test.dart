import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_purchase_order_client.dart';

void main() {
  group('MobilePurchaseOrderLineTest (P186)', () {
    late MobilePurchaseOrderClient client;
    late Map<String, MobilePurchaseOrder> store;

    setUp(() {
      store = {};
      client = MobilePurchaseOrderClient(
        tenantId: 'tenant-001',
        branchId: 'branch-001',
        userRole: 'BRANCH_MANAGER',
        userId: 'user-manager-001',
        initialStore: store,
      );
    });

    test('1. Create and list PO with complete line item modeling', () {
      final deliveryDate = DateTime.now().add(const Duration(days: 7));
      final item = MobilePurchaseOrderItem(
        itemId: 'item-001',
        productId: 'prod-ace-500',
        productName: 'Ace Plus 500mg Tablet',
        packUnit: 'BOX',
        packageSize: 100,
        orderedPackages: 10,
        orderedQuantity: 1000,
        unitCostPrice: 2.0,
        mrpUnit: 2.5,
        discountPercentage: 5.0,
        taxPercentage: 7.5,
        expectedDeliveryDate: deliveryDate,
        freeGoodsBonusQuantity: 20,
        notes: 'Emergency cold & flu stock',
      );

      final po = client.createPurchaseOrder(
        supplierId: 'supp-square',
        supplierName: 'Square Pharmaceuticals Ltd.',
        notes: 'Main depot order',
        items: [item],
      );

      expect(po.status, equals('DRAFT'));
      expect(po.items.length, equals(1));

      final savedItem = po.items.first;
      expect(savedItem.packUnit, equals('BOX'));
      expect(savedItem.packageSize, equals(100));
      expect(savedItem.orderedPackages, equals(10));
      expect(savedItem.orderedQuantity, equals(1000));
      expect(savedItem.freeGoodsBonusQuantity, equals(20));
      expect(savedItem.packageCostPrice, equals(200.0)); // 2.0 * 100
      // netUnitCost = 2.0 * (1 - 0.05) = 1.90
      expect(savedItem.netUnitCost, equals(1.9));
      // lineSubtotal = 1.9 * 1000 = 1900.0
      expect(savedItem.lineSubtotal, equals(1900.0));
      // taxAmount = 1900.0 * 0.075 = 142.5
      expect(savedItem.taxAmount, equals(142.5));
      // lineTotal = 1900.0 + 142.5 = 2042.5
      expect(savedItem.lineTotal, equals(2042.5));

      final itemsList = client.listPoItems(po.poId);
      expect(itemsList.length, equals(1));
      expect(itemsList.first.itemId, equals('item-001'));
    });

    test('2. Add line item dynamically recalculates parent PO totals', () {
      final item1 = MobilePurchaseOrderItem(
        itemId: 'item-001',
        productId: 'prod-1',
        orderedQuantity: 50,
        unitCostPrice: 10.0,
        mrpUnit: 12.0,
      );

      final po = client.createPurchaseOrder(
        supplierId: 'supp-beximco',
        items: [item1],
      );

      // Initial subtotal = 50 * 10 = 500.0
      expect(po.subtotalAmount, equals(500.0));
      expect(po.taxAmount, equals(0.0));
      expect(po.totalAmount, equals(500.0));

      // Add item2 with discount and tax
      final item2 = MobilePurchaseOrderItem(
        itemId: 'item-002',
        productId: 'prod-2',
        orderedQuantity: 100,
        unitCostPrice: 5.0,
        mrpUnit: 6.0,
        discountPercentage: 10.0, // net = 4.50, subtotal = 450.0
        taxPercentage: 10.0,      // tax = 45.0
      );

      final updatedPo = client.addPoItem(poId: po.poId, item: item2);
      expect(updatedPo.items.length, equals(2));
      // Subtotal = 500.0 + 450.0 = 950.0
      expect(updatedPo.subtotalAmount, equals(950.0));
      // Tax = 0 + 45.0 = 45.0
      expect(updatedPo.taxAmount, equals(45.0));
      // Total = 950.0 + 45.0 = 995.0
      expect(updatedPo.totalAmount, equals(995.0));
    });

    test('3. Update and delete line item with recalculation and last-item guard', () {
      final item1 = MobilePurchaseOrderItem(
        itemId: 'item-001',
        productId: 'prod-1',
        orderedQuantity: 10,
        unitCostPrice: 5.0,
        mrpUnit: 7.0,
      );
      final item2 = MobilePurchaseOrderItem(
        itemId: 'item-002',
        productId: 'prod-2',
        orderedQuantity: 10,
        unitCostPrice: 8.0,
        mrpUnit: 10.0,
      );

      final po = client.createPurchaseOrder(
        supplierId: 'supp-incepta',
        items: [item1, item2],
      );

      // Subtotal = 50 + 80 = 130.0
      expect(po.subtotalAmount, equals(130.0));

      // Update item 1: increase quantity to 20
      final updatedItem1 = MobilePurchaseOrderItem(
        itemId: 'item-001',
        productId: 'prod-1',
        orderedQuantity: 20,
        unitCostPrice: 5.0,
        mrpUnit: 7.0,
      );

      final poAfterUpdate = client.updatePoItem(
        poId: po.poId,
        itemId: 'item-001',
        updatedItem: updatedItem1,
      );
      // Subtotal = 100 + 80 = 180.0
      expect(poAfterUpdate.subtotalAmount, equals(180.0));

      // Delete item 2
      final poAfterDelete = client.deletePoItem(
        poId: po.poId,
        itemId: 'item-002',
      );
      expect(poAfterDelete.items.length, equals(1));
      expect(poAfterDelete.subtotalAmount, equals(100.0));

      // Cannot delete last remaining item
      expect(
        () => client.deletePoItem(poId: po.poId, itemId: 'item-001'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_CANNOT_DELETE_LAST_ITEM'),
        )),
      );
    });

    test('4. Locked PO guard and MRP ceiling guard', () {
      final item1 = MobilePurchaseOrderItem(
        itemId: 'item-001',
        productId: 'prod-1',
        orderedQuantity: 10,
        unitCostPrice: 10.0,
        mrpUnit: 15.0,
      );

      final po = client.createPurchaseOrder(
        supplierId: 'supp-square',
        items: [item1],
      );

      // DGDA MRP price ceiling guard
      final invalidMrpItem = MobilePurchaseOrderItem(
        itemId: 'item-002',
        productId: 'prod-2',
        orderedQuantity: 10,
        unitCostPrice: 20.0, // Cost exceeds MRP
        mrpUnit: 18.0,
      );

      expect(
        () => client.addPoItem(poId: po.poId, item: invalidMrpItem),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_COST_EXCEEDS_MRP'),
        )),
      );

      // Approve order -> locks lines
      client.approvePurchaseOrder(poId: po.poId);

      final validItem = MobilePurchaseOrderItem(
        itemId: 'item-003',
        productId: 'prod-3',
        orderedQuantity: 5,
        unitCostPrice: 5.0,
        mrpUnit: 8.0,
      );

      expect(
        () => client.addPoItem(poId: po.poId, item: validItem),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_PO_LOCKED'),
        )),
      );

      expect(
        () => client.updatePoItem(poId: po.poId, itemId: 'item-001', updatedItem: validItem),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_PO_LOCKED'),
        )),
      );

      expect(
        () => client.deletePoItem(poId: po.poId, itemId: 'item-001'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_PO_LOCKED'),
        )),
      );
    });
  });
}
