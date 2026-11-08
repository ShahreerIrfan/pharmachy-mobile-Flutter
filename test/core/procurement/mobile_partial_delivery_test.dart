// mobile_partial_delivery_test.dart
// Architecture Decision: ADR-0188 (P188).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_purchase_order_client.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_goods_receipt_client.dart';

void main() {
  group('MobilePartialDeliveryClient Tests (P188)', () {
    late MobilePurchaseOrderClient poClient;
    late MobileGoodsReceiptClient grnClient;
    late MobilePurchaseOrder testPo;

    setUp(() {
      final poStore = <String, MobilePurchaseOrder>{};
      final grnStore = <String, MobileGoodsReceipt>{};

      poClient = MobilePurchaseOrderClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        initialStore: poStore,
      );

      grnClient = MobileGoodsReceiptClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        initialStore: grnStore,
        poClient: poClient,
      );

      // Create, approve, and order a PO for 100 units of Napa 500mg
      testPo = poClient.createPurchaseOrder(
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        notes: 'P188 Test Order',
        items: [
          MobilePurchaseOrderItem(
            itemId: 'poi-napa-100',
            productId: 'prod-napa-500',
            productName: 'Napa 500mg Tablet',
            packageType: 'BOX',
            packUnit: 'BOX',
            packageSize: 10,
            orderedPackages: 10,
            orderedQuantity: 100,
            unitCostPrice: 2.50,
            mrpUnit: 3.50,
          ),
        ],
      );

      poClient.approvePurchaseOrder(poId: testPo.poId);
      poClient.orderPurchaseOrder(testPo.poId);
    });

    test('1. Partial shipment sets PARTIALLY_DELIVERED on line and PARTIALLY_RECEIVED on PO', () {
      final line1 = MobileGoodsReceiptLine(
        poItemId: 'poi-napa-100',
        productId: 'prod-napa-500',
        productBrandName: 'Napa 500mg Tablet',
        batchNumber: 'BEX-2026-P1',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        receivedQuantityBaseUnits: 60,
        unitCost: 2.50,
        mrpUnit: 3.50,
      );

      final grn1 = grnClient.createGrn(
        purchaseOrderId: testPo.poId,
        supplierId: 'supp-beximco',
        challanNumber: 'CH-P188-001',
        lines: [line1],
      );

      grnClient.postGrnToStock(grn1.grnId);

      final updatedPo = poClient.getPurchaseOrder(testPo.poId);
      expect(updatedPo.status, equals('PARTIALLY_RECEIVED'));

      final item = updatedPo.items.first;
      expect(item.receivedQuantity, equals(60));
      expect(item.backorderedQuantity, equals(40));
      expect(item.deliveryStatus, equals('PARTIALLY_DELIVERED'));
      expect(item.isBackordered, isTrue);
    });

    test('2. Subsequent delivery fulfills remaining backorder and transitions PO to CLOSED', () {
      // First partial GRN (60 units)
      final line1 = MobileGoodsReceiptLine(
        poItemId: 'poi-napa-100',
        productId: 'prod-napa-500',
        batchNumber: 'BEX-2026-P1',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        receivedQuantityBaseUnits: 60,
        unitCost: 2.50,
        mrpUnit: 3.50,
      );
      final grn1 = grnClient.createGrn(
        purchaseOrderId: testPo.poId,
        supplierId: 'supp-beximco',
        challanNumber: 'CH-P188-001',
        lines: [line1],
      );
      grnClient.postGrnToStock(grn1.grnId);

      // Second GRN fulfilling remaining 40 units
      final line2 = MobileGoodsReceiptLine(
        poItemId: 'poi-napa-100',
        productId: 'prod-napa-500',
        batchNumber: 'BEX-2026-P2',
        expiryDate: DateTime.now().add(const Duration(days: 400)),
        receivedQuantityBaseUnits: 40,
        unitCost: 2.50,
        mrpUnit: 3.50,
      );
      final grn2 = grnClient.createGrn(
        purchaseOrderId: testPo.poId,
        supplierId: 'supp-beximco',
        challanNumber: 'CH-P188-002',
        lines: [line2],
      );
      grnClient.postGrnToStock(grn2.grnId);

      final updatedPo = poClient.getPurchaseOrder(testPo.poId);
      expect(updatedPo.status, equals('CLOSED'));

      final item = updatedPo.items.first;
      expect(item.receivedQuantity, equals(100));
      expect(item.backorderedQuantity, equals(0));
      expect(item.deliveryStatus, equals('FULLY_DELIVERED'));
      expect(item.isBackordered, isFalse);
    });

    test('3. Promotional bonus free goods increment physical quantity at zero cost liability', () {
      final bonusLine = MobileGoodsReceiptLine(
        productId: 'prod-bonus-sample',
        productBrandName: 'Free Doctor Sample Napa',
        batchNumber: 'BEX-BONUS-01',
        expiryDate: DateTime.now().add(const Duration(days: 300)),
        receivedQuantityBaseUnits: 10,
        unitCost: 2.50, // Should be overridden to 0.0 because isBonusGoods is true
        mrpUnit: 3.50,
        isBonusGoods: true,
      );

      expect(bonusLine.unitCost, equals(0.0));
      expect(bonusLine.lineTotal, equals(0.0));
      expect(bonusLine.isBonusGoods, isTrue);

      final grn = grnClient.createGrn(
        supplierId: 'supp-beximco',
        challanNumber: 'CH-BONUS-01',
        lines: [bonusLine],
      );

      expect(grn.totalReceivedBaseUnits, equals(10));
      expect(grn.totalInvoiceAmount, equals(0.0));

      grnClient.postGrnToStock(grn.grnId);
      expect(grn.apInvoiceAmount, equals(0.0));
    });

    test('4. Excess delivery requires manager authorization and reason, otherwise rejected', () {
      // 120 units received when only 100 ordered
      final excessLine = MobileGoodsReceiptLine(
        poItemId: 'poi-napa-100',
        productId: 'prod-napa-500',
        batchNumber: 'BEX-EXCESS-01',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        receivedQuantityBaseUnits: 120,
        unitCost: 2.50,
        mrpUnit: 3.50,
      );

      // Unauthorized excess must fail
      expect(
        () => grnClient.createGrn(
          purchaseOrderId: testPo.poId,
          supplierId: 'supp-beximco',
          challanNumber: 'CH-EXCESS-FAIL',
          allowExcess: false,
          lines: [excessLine],
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_EXCESS_RECEIPT'),
        )),
      );

      // Authorized excess with valid manager reason succeeds
      final authorizedGrn = grnClient.createGrn(
        purchaseOrderId: testPo.poId,
        supplierId: 'supp-beximco',
        challanNumber: 'CH-EXCESS-PASS',
        allowExcess: true,
        excessReason: 'Supplier promotional surplus accepted by Manager',
        lines: [excessLine],
      );

      expect(authorizedGrn.lines.first.receivedQuantityBaseUnits, equals(120));
      expect(authorizedGrn.totalReceivedBaseUnits, equals(120));
    });

    test('5. Backorder cancellation safely closes PO without counting cancelled units in received stock', () {
      // Receive 60 units first
      final line1 = MobileGoodsReceiptLine(
        poItemId: 'poi-napa-100',
        productId: 'prod-napa-500',
        batchNumber: 'BEX-2026-P1',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        receivedQuantityBaseUnits: 60,
        unitCost: 2.50,
        mrpUnit: 3.50,
      );
      final grn1 = grnClient.createGrn(
        purchaseOrderId: testPo.poId,
        supplierId: 'supp-beximco',
        challanNumber: 'CH-P188-001',
        lines: [line1],
      );
      grnClient.postGrnToStock(grn1.grnId);

      // Over-cancellation must fail (e.g. attempting to cancel 50 when only 40 are backordered)
      expect(
        () => grnClient.cancelPoBackorder(
          poId: testPo.poId,
          itemId: 'poi-napa-100',
          cancelQuantity: 50,
          reason: 'Supplier out of stock',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_INVALID_CANCEL_QUANTITY'),
        )),
      );

      // Cancel remaining 40 backordered units
      final closedPo = grnClient.cancelPoBackorder(
        poId: testPo.poId,
        itemId: 'poi-napa-100',
        cancelQuantity: 40,
        reason: 'Manufacturer discontinued this batch production',
      );

      expect(closedPo.status, equals('CLOSED'));
      final item = closedPo.items.first;
      expect(item.receivedQuantity, equals(60));
      expect(item.cancelledQuantity, equals(40));
      expect(item.backorderedQuantity, equals(0));
      expect(item.deliveryStatus, equals('FULLY_DELIVERED')); // since 60 received + 40 cancelled >= 100
      expect(item.isBackordered, isFalse);
    });
  });
}

