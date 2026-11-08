// mobile_purchase_order_client_test.dart
// Architecture Decision: ADR-0185 (P185).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_purchase_order_client.dart';

void main() {
  group('MobilePurchaseOrderClient Tests (P185)', () {
    late MobilePurchaseOrderClient managerClient;
    late MobilePurchaseOrderClient pharmacistClient;
    late MobilePurchaseOrderClient cashierClient;
    late MobilePurchaseOrderClient foreignClient;

    setUp(() {
      final sharedStore = <String, MobilePurchaseOrder>{};

      managerClient = MobilePurchaseOrderClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        initialStore: sharedStore,
      );

      pharmacistClient = MobilePurchaseOrderClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'STAFF_PHARMACIST',
        userId: 'usr-pharm-1',
        initialStore: sharedStore,
      );

      cashierClient = MobilePurchaseOrderClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        initialStore: sharedStore,
      );

      foreignClient = MobilePurchaseOrderClient(
        tenantId: 'tenant-other',
        branchId: 'branch-2',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-2',
        initialStore: sharedStore,
      );
    });

    test(
        'Test 1: Valid purchase order creation, line discounts, and manager approval',
        () {
      final items = [
        // 100 units @ 2.50 BDT, 10% discount -> net 2.2500 -> total 225.00
        MobilePurchaseOrderItem(
          itemId: 'poi-1',
          productId: 'prod-napa-500',
          productName: 'Napa Extra',
          orderedQuantity: 100,
          unitCostPrice: 2.50,
          discountPercentage: 10.0,
        ),
        // 50 units @ 5.00 BDT, 0% discount -> net 5.0000 -> total 250.00
        MobilePurchaseOrderItem(
          itemId: 'poi-2',
          productId: 'prod-seclo-20',
          productName: 'Seclo 20mg',
          orderedQuantity: 50,
          unitCostPrice: 5.00,
          discountPercentage: 0.0,
        ),
      ];

      // Subtotal = 225.0 + 250.0 = 475.0
      // Discount = 25.0, Tax = 10.0 -> Total = 460.0
      final po = managerClient.createPurchaseOrder(
        supplierId: 'sup-square-001',
        supplierName: 'Square Pharmaceuticals Depot',
        requisitionId: 'req-12345',
        paymentTermsDays: 30,
        discountAmount: 25.0,
        taxAmount: 10.0,
        expectedDeliveryDate: DateTime(2026, 11, 25),
        notes: 'Monthly bulk replenishment',
        items: items,
      );

      expect(po.poId, startsWith('po-'));
      expect(po.poNumber, startsWith('PO-'));
      expect(po.tenantId, equals('tenant-evercare'));
      expect(po.status, equals('DRAFT'));
      expect(po.subtotalAmount, equals(475.0));
      expect(po.discountAmount, equals(25.0));
      expect(po.taxAmount, equals(10.0));
      expect(po.totalAmount, equals(460.0));
      expect(po.items.length, equals(2));

      // Manager approves
      final approved = managerClient.approvePurchaseOrder(
        poId: po.poId,
        approvalNotes: 'Financial liability committed',
      );
      expect(approved.status, equals('APPROVED'));
      expect(approved.approvedById, equals('usr-mgr-1'));
      expect(approved.approvedAt, isNotNull);
    });

    test(
        'Test 2: Order dispatch and progressive goods receipt transitions to CLOSED',
        () {
      final items = [
        MobilePurchaseOrderItem(
          itemId: 'poi-1',
          productId: 'prod-napa-500',
          orderedQuantity: 100,
          unitCostPrice: 2.00,
        ),
        MobilePurchaseOrderItem(
          itemId: 'poi-2',
          productId: 'prod-ace-500',
          orderedQuantity: 50,
          unitCostPrice: 3.00,
        ),
      ];

      final po = managerClient.createPurchaseOrder(
        supplierId: 'sup-sq',
        items: items,
      );
      managerClient.approvePurchaseOrder(poId: po.poId);

      // Dispatch to supplier
      final ordered = managerClient.orderPurchaseOrder(po.poId);
      expect(ordered.status, equals('ORDERED'));
      expect(ordered.orderedAt, isNotNull);

      // 1. Partial receipt
      final partial = managerClient.receiveItems(
        poId: po.poId,
        itemReceipts: {'poi-1': 50},
      );
      expect(partial.status, equals('PARTIALLY_RECEIVED'));
      expect(partial.items.first.receivedQuantity, equals(50));

      // 2. Full receipt completion
      final closed = managerClient.receiveItems(
        poId: po.poId,
        itemReceipts: {'poi-1': 50, 'poi-2': 50},
      );
      expect(closed.status, equals('CLOSED'));
      expect(closed.items[0].receivedQuantity, equals(100));
      expect(closed.items[1].receivedQuantity, equals(50));
      expect(closed.closedAt, isNotNull);
    });

    test(
        'Test 3: Guarded cancellation prevents cancellation if goods were received',
        () {
      final items = [
        MobilePurchaseOrderItem(
          itemId: 'poi-1',
          productId: 'prod-1',
          orderedQuantity: 50,
          unitCostPrice: 2.00,
        ),
      ];

      // Clean cancellation before receipt
      final po1 = managerClient.createPurchaseOrder(
        supplierId: 'sup-sq',
        items: items,
      );
      managerClient.approvePurchaseOrder(poId: po1.poId);
      managerClient.orderPurchaseOrder(po1.poId);

      // Blank reason fails
      expect(
        () => managerClient.cancelPurchaseOrder(
          poId: po1.poId,
          cancellationReason: '',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final cancelled = managerClient.cancelPurchaseOrder(
        poId: po1.poId,
        cancellationReason: 'Supplier unable to deliver',
      );
      expect(cancelled.status, equals('CANCELLED'));
      expect(cancelled.cancellationReason, equals('Supplier unable to deliver'));

      // Received items cannot be cancelled
      final po2 = managerClient.createPurchaseOrder(
        supplierId: 'sup-sq',
        items: items,
      );
      managerClient.approvePurchaseOrder(poId: po2.poId);
      managerClient.orderPurchaseOrder(po2.poId);
      managerClient.receiveItems(poId: po2.poId, itemReceipts: {'poi-1': 10});

      expect(
        () => managerClient.cancelPurchaseOrder(
          poId: po2.poId,
          cancellationReason: 'Try cancel',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Test 4: RBAC permissions and cross-tenant boundary isolation', () {
      final items = [
        MobilePurchaseOrderItem(
          itemId: 'poi-1',
          productId: 'prod-1',
          orderedQuantity: 10,
          unitCostPrice: 2.00,
        ),
      ];

      // Cashier role blocked
      expect(
        () => cashierClient.createPurchaseOrder(
          supplierId: 'sup-sq',
          items: items,
        ),
        throwsA(isA<StateError>()),
      );

      // Pharmacist creates DRAFT PO
      final po = pharmacistClient.createPurchaseOrder(
        supplierId: 'sup-sq',
        items: items,
      );
      expect(po.status, equals('DRAFT'));

      // Pharmacist cannot approve or dispatch
      expect(
        () => pharmacistClient.approvePurchaseOrder(poId: po.poId),
        throwsA(isA<StateError>()),
      );
      expect(
        () => pharmacistClient.orderPurchaseOrder(po.poId),
        throwsA(isA<StateError>()),
      );

      // Foreign tenant cannot access or approve
      expect(
        () => foreignClient.getPurchaseOrder(po.poId),
        throwsA(isA<StateError>()),
      );
      expect(
        () => foreignClient.approvePurchaseOrder(poId: po.poId),
        throwsA(isA<StateError>()),
      );
    });
  });
}
