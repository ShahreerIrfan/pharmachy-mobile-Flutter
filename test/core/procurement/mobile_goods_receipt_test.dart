// mobile_goods_receipt_test.dart
// Architecture Decision: ADR-0187 (P187).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_purchase_order_client.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_goods_receipt_client.dart';

void main() {
  group('MobileGoodsReceiptClient Tests (P187)', () {
    late MobilePurchaseOrderClient poClient;
    late MobileGoodsReceiptClient grnClient;
    late MobileGoodsReceiptClient cashierGrnClient;
    late MobileGoodsReceiptClient foreignGrnClient;

    late MobilePurchaseOrder activePo;

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

      cashierGrnClient = MobileGoodsReceiptClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'CASHIER',
        userId: 'usr-cashier-1',
        initialStore: grnStore,
        poClient: poClient,
      );

      foreignGrnClient = MobileGoodsReceiptClient(
        tenantId: 'tenant-other',
        branchId: 'branch-2',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-2',
        initialStore: grnStore,
        poClient: poClient,
      );

      // Create and approve + order a PO
      activePo = poClient.createPurchaseOrder(
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        notes: 'Cold chain shipment',
        items: [
          MobilePurchaseOrderItem(
            itemId: 'poi-insulin-1',
            productId: 'prod-insulin',
            productName: 'Napa Insulin 100IU',
            packageType: 'VIAL',
            packUnit: 'VIAL',
            packageSize: 1,
            orderedQuantity: 100,
            unitCostPrice: 350.0,
            mrpUnit: 420.0,
          ),
          MobilePurchaseOrderItem(
            itemId: 'poi-paracetamol-2',
            productId: 'prod-paracetamol',
            productName: 'Napa 500mg',
            packageType: 'BOX',
            packUnit: 'BOX',
            packageSize: 10,
            orderedPackages: 10,
            orderedQuantity: 100,
            unitCostPrice: 2.0,
            mrpUnit: 3.0,
          ),
        ],
      );

      poClient.approvePurchaseOrder(
        poId: activePo.poId,
        approvalNotes: 'Approved by Manager',
      );
      poClient.orderPurchaseOrder(activePo.poId);
    });

    test(
        'Test 1: Valid GRN creation matching PO lines with cold chain verification',
        () {
      final lines = [
        MobileGoodsReceiptLine(
          poItemId: 'poi-insulin-1',
          productId: 'prod-insulin',
          productBrandName: 'Napa Insulin 100IU',
          batchNumber: 'BX-INS-2026',
          expiryDate: DateTime.now().add(const Duration(days: 365)),
          packUnit: 'VIAL',
          packageSize: 1,
          receivedPackages: 100,
          receivedQuantityBaseUnits: 100,
          unitCost: 350.0,
          mrpUnit: 420.0,
          discountPercentage: 0.0,
          taxPercentage: 0.0,
        ),
      ];

      final grn = grnClient.createGrn(
        purchaseOrderId: activePo.poId,
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        challanNumber: 'CH-9921',
        storageCondition: 'COLD_CHAIN',
        storageTemperatureCelsius: 4.5,
        storageCheckPassed: true,
        proofOfOrigin: 'Beximco Central Depot Delivery Challan',
        notes: 'Challan verified and condition intact',
        lines: lines,
      );

      expect(grn.status, equals('RECEIVED'));
      expect(grn.apPostingStatus, equals('PENDING'));
      expect(grn.totalReceivedBaseUnits, equals(100));
      expect(grn.totalInvoiceAmount, equals(35000.0));
      expect(grn.storageCondition, equals('COLD_CHAIN'));
      expect(grn.storageTemperatureCelsius, equals(4.5));
      expect(grn.storageCheckPassed, isTrue);
    });

    test(
        'Test 2: Cold chain temperature inspection failure throws ERR_STORAGE_CHECK_FAILED',
        () {
      final lines = [
        MobileGoodsReceiptLine(
          poItemId: 'poi-insulin-1',
          productId: 'prod-insulin',
          productBrandName: 'Napa Insulin 100IU',
          batchNumber: 'BX-INS-HOT',
          expiryDate: DateTime.now().add(const Duration(days: 365)),
          receivedQuantityBaseUnits: 50,
          unitCost: 350.0,
          mrpUnit: 420.0,
        ),
      ];

      // Case A: Temperature too high (11.5 C)
      expect(
        () => grnClient.createGrn(
          purchaseOrderId: activePo.poId,
          supplierId: 'supp-beximco',
          storageCondition: 'COLD_CHAIN',
          storageTemperatureCelsius: 11.5,
          storageCheckPassed: true,
          lines: lines,
        ),
        throwsA(predicate((e) =>
            e is StateError &&
            e.message.contains('ERR_STORAGE_CHECK_FAILED') &&
            e.message.contains('Cold-chain temperature violation'))),
      );

      // Case B: Inspection check failed
      expect(
        () => grnClient.createGrn(
          purchaseOrderId: activePo.poId,
          supplierId: 'supp-beximco',
          storageCondition: 'COLD_CHAIN',
          storageTemperatureCelsius: 5.0,
          storageCheckPassed: false,
          lines: lines,
        ),
        throwsA(predicate((e) =>
            e is StateError &&
            e.message.contains('ERR_STORAGE_CHECK_FAILED') &&
            e.message.contains('physical inspection failed'))),
      );
    });

    test(
        'Test 3: Expired batch receipt guard throws ERR_EXPIRED_BATCH_RECEIVED',
        () {
      final lines = [
        MobileGoodsReceiptLine(
          poItemId: 'poi-paracetamol-2',
          productId: 'prod-paracetamol',
          batchNumber: 'OLD-BATCH-01',
          expiryDate: DateTime.now().subtract(const Duration(days: 5)),
          receivedQuantityBaseUnits: 50,
          unitCost: 2.0,
          mrpUnit: 3.0,
        ),
      ];

      expect(
        () => grnClient.createGrn(
          purchaseOrderId: activePo.poId,
          supplierId: 'supp-beximco',
          storageCondition: 'ROOM_TEMPERATURE',
          lines: lines,
        ),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.message.contains('ERR_EXPIRED_BATCH_RECEIVED'))),
      );
    });

    test(
        'Test 4: Over-receipt guard throws ERR_EXCESS_RECEIPT',
        () {
      final lines = [
        MobileGoodsReceiptLine(
          poItemId: 'poi-paracetamol-2',
          productId: 'prod-paracetamol',
          batchNumber: 'EXCESS-BATCH-01',
          expiryDate: DateTime.now().add(const Duration(days: 200)),
          receivedQuantityBaseUnits: 150, // Ordered was 100
          unitCost: 2.0,
          mrpUnit: 3.0,
        ),
      ];

      expect(
        () => grnClient.createGrn(
          purchaseOrderId: activePo.poId,
          supplierId: 'supp-beximco',
          storageCondition: 'ROOM_TEMPERATURE',
          lines: lines,
        ),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.message.contains('ERR_EXCESS_RECEIPT'))),
      );
    });

    test(
        'Test 5: Idempotent stock posting & PO fulfillment transitions',
        () {
      final lines = [
        MobileGoodsReceiptLine(
          poItemId: 'poi-insulin-1',
          productId: 'prod-insulin',
          batchNumber: 'INS-OK-1',
          expiryDate: DateTime.now().add(const Duration(days: 365)),
          receivedQuantityBaseUnits: 100,
          unitCost: 350.0,
          mrpUnit: 420.0,
        ),
      ];

      final grn = grnClient.createGrn(
        purchaseOrderId: activePo.poId,
        supplierId: 'supp-beximco',
        storageCondition: 'COLD_CHAIN',
        storageTemperatureCelsius: 5.0,
        lines: lines,
      );

      final posted = grnClient.postGrnToStock(grn.grnId);
      expect(posted.status, equals('POSTED'));
      expect(posted.apPostingStatus, equals('POSTED'));
      expect(posted.apInvoiceAmount, equals(35000.0));
      expect(posted.lines.first.isFullyAllocated, isTrue);

      // Verify PO transitioned to PARTIALLY_RECEIVED
      final updatedPo = poClient.getPurchaseOrder(activePo.poId);
      expect(updatedPo.status, equals('PARTIALLY_RECEIVED'));
      expect(updatedPo.items.first.receivedQuantity, equals(100));

      // Attempt duplicate posting
      expect(
        () => grnClient.postGrnToStock(grn.grnId),
        throwsA(predicate((e) =>
            e is StateError && e.message.contains('ERR_ALREADY_POSTED'))),
      );
    });

    test(
        'Test 6: Safe reversal and consumed stock guard',
        () {
      final lines = [
        MobileGoodsReceiptLine(
          poItemId: 'poi-paracetamol-2',
          productId: 'prod-paracetamol',
          batchNumber: 'PARA-REV-01',
          expiryDate: DateTime.now().add(const Duration(days: 180)),
          receivedQuantityBaseUnits: 50,
          unitCost: 2.0,
          mrpUnit: 3.0,
        ),
      ];

      final grn = grnClient.createGrn(
        purchaseOrderId: activePo.poId,
        supplierId: 'supp-beximco',
        lines: lines,
      );
      grnClient.postGrnToStock(grn.grnId);

      // Block reversal if stock was consumed
      expect(
        () => grnClient.reverseGrn(
          grn.grnId,
          reason: 'Faulty packaging',
          consumedStockPerLine: {lines.first.lineId: 10},
        ),
        throwsA(predicate((e) =>
            e is StateError &&
            e.message.contains('ERR_CANNOT_REVERSE_CONSUMED_STOCK'))),
      );

      // Successfully reverse when 0 stock was consumed
      final reversed = grnClient.reverseGrn(
        grn.grnId,
        reason: 'Recalled lot before any dispensing',
        consumedStockPerLine: {lines.first.lineId: 0},
      );
      expect(reversed.status, equals('REVERSED'));
      expect(reversed.apPostingStatus, equals('REVERSED'));
      expect(reversed.notes, contains('Recalled lot before any dispensing'));
    });

    test(
        'Test 7: Cashier role restriction and cross-tenant isolation',
        () {
      final lines = [
        MobileGoodsReceiptLine(
          poItemId: 'poi-paracetamol-2',
          productId: 'prod-paracetamol',
          batchNumber: 'SEC-TEST',
          expiryDate: DateTime.now().add(const Duration(days: 100)),
          receivedQuantityBaseUnits: 10,
          unitCost: 2.0,
          mrpUnit: 3.0,
        ),
      ];

      // Cashier denied
      expect(
        () => cashierGrnClient.createGrn(
          purchaseOrderId: activePo.poId,
          supplierId: 'supp-beximco',
          lines: lines,
        ),
        throwsA(predicate((e) =>
            e is StateError && e.message.contains('ERR_STAFF_ROLE_DENIED'))),
      );

      // Foreign tenant denied
      expect(
        () => foreignGrnClient.createGrn(
          purchaseOrderId: activePo.poId,
          supplierId: 'supp-beximco',
          lines: lines,
        ),
        throwsA(predicate((e) =>
            e is StateError && e.message.contains('ERR_CROSS_TENANT_ACCESS'))),
      );
    });
  });
}
