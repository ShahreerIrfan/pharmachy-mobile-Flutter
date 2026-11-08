// mobile_supplier_invoice_matching_test.dart
// Architecture Decision: ADR-0190 (P190).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_purchase_order_client.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_goods_receipt_client.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_supplier_invoice_matching_client.dart';

void main() {
  group('MobileSupplierInvoiceMatchingClient Tests (P190)', () {
    late MobilePurchaseOrderClient poClient;
    late MobileGoodsReceiptClient grnClient;
    late MobileSupplierInvoiceMatchingClient invoiceClient;
    late MobileSupplierInvoiceMatchingClient cashierInvoiceClient;

    late MobilePurchaseOrder testPo;
    late MobileGoodsReceipt testGrn;

    setUp(() {
      final poStore = <String, MobilePurchaseOrder>{};
      final grnStore = <String, MobileGoodsReceipt>{};
      final invoiceStore = <String, MobileSupplierInvoice>{};
      final balances = <String, double>{};

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

      invoiceClient = MobileSupplierInvoiceMatchingClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        initialStore: invoiceStore,
        initialBalances: balances,
        poClient: poClient,
        grnClient: grnClient,
      );

      cashierInvoiceClient = MobileSupplierInvoiceMatchingClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        initialStore: invoiceStore,
        initialBalances: balances,
        poClient: poClient,
        grnClient: grnClient,
      );

      // 1. Create and Order PO for 50 vials of Insulin @ ৳350.00
      testPo = poClient.createPurchaseOrder(
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        notes: 'Insulin PO',
        items: [
          MobilePurchaseOrderItem(
            itemId: 'poi-ins-50',
            productId: 'prod-insulin',
            productName: 'Glarin Insulin 100IU',
            packageType: 'VIAL',
            packUnit: 'VIAL',
            packageSize: 1,
            orderedPackages: 50,
            orderedQuantity: 50,
            unitCostPrice: 350.00,
            mrpUnit: 420.00,
          ),
        ],
      );
      poClient.approvePurchaseOrder(poId: testPo.poId);
      poClient.orderPurchaseOrder(testPo.poId);

      // 2. Create GRN for 50 vials received
      final grnLine = MobileGoodsReceiptLine(
        poItemId: 'poi-ins-50',
        productId: 'prod-insulin',
        productBrandName: 'Glarin Insulin 100IU',
        batchNumber: 'BEX-INS-2026',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        receivedQuantityBaseUnits: 50,
        unitCost: 350.00,
        mrpUnit: 420.00,
      );

      testGrn = grnClient.createGrn(
        purchaseOrderId: testPo.poId,
        supplierId: 'supp-beximco',
        challanNumber: 'CH-BEX-9901',
        storageCondition: 'COLD_CHAIN_2_8C',
        storageTemperatureCelsius: 4.5,
        lines: [grnLine],
      );
      grnClient.postGrnToStock(testGrn.grnId);
    });

    test('1. Valid 3-Way Match within tolerance sets MATCHED status and posts to AP', () {
      final item = MobileSupplierInvoiceItem(
        itemId: 'sii-1',
        productId: 'prod-insulin',
        productBrandName: 'Glarin Insulin 100IU',
        poItemId: 'poi-ins-50',
        grnLineId: testGrn.lines.first.lineId,
        batchNumber: 'BEX-INS-2026',
        billedQuantity: 50,
        receivedQuantity: 50,
        orderedQuantity: 50,
        billedUnitPrice: 350.00,
        poUnitPrice: 350.00,
        lineSubtotal: 17500.00,
        lineTotal: 17500.00,
      );

      final invoice = invoiceClient.createSupplierInvoice(
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        invoiceNumber: 'INV-BEX-2026-001',
        invoiceDate: DateTime.now(),
        purchaseOrderId: testPo.poId,
        goodsReceiptId: testGrn.grnId,
        items: [item],
      );

      expect(invoice.matchingStatus, equals('MATCHED'));
      expect(invoice.hasDiscrepancy, isFalse);
      expect(invoice.discrepancyReasons, isEmpty);
      expect(invoice.totalAmount, equals(17500.00));

      final posted = invoiceClient.postInvoiceToAp(invoice.invoiceId);
      expect(posted.matchingStatus, equals('POSTED_TO_AP'));
      expect(posted.postedToApAt, isNotNull);
      expect(posted.apLedgerEntryId, isNotNull);
    });

    test('2. Price variance exceeding 1.5% tolerance routes invoice to DISCREPANCY_QUEUE', () {
      final item = MobileSupplierInvoiceItem(
        itemId: 'sii-price-err',
        productId: 'prod-insulin',
        productBrandName: 'Glarin Insulin 100IU',
        poItemId: 'poi-ins-50',
        grnLineId: testGrn.lines.first.lineId,
        batchNumber: 'BEX-INS-2026',
        billedQuantity: 50,
        receivedQuantity: 50,
        orderedQuantity: 50,
        billedUnitPrice: 370.00, // +5.7% price variance violation
        poUnitPrice: 350.00,
      );

      final invoice = invoiceClient.createSupplierInvoice(
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        invoiceNumber: 'INV-BEX-2026-PRICE-VAR',
        invoiceDate: DateTime.now(),
        purchaseOrderId: testPo.poId,
        goodsReceiptId: testGrn.grnId,
        items: [item],
      );

      expect(invoice.matchingStatus, equals('DISCREPANCY_QUEUE'));
      expect(invoice.hasDiscrepancy, isTrue);
      expect(invoice.discrepancyReasons, isNotEmpty);
      expect(invoice.discrepancyReasons.first, contains('PRICE_VARIANCE'));

      // Posting unapproved invoice throws StateError
      expect(
        () => invoiceClient.postInvoiceToAp(invoice.invoiceId),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_INVOICE_NOT_MATCHED'),
        )),
      );

      // Present in exception queue
      final queue = invoiceClient.getExceptionQueue('branch-1');
      expect(queue.any((inv) => inv.invoiceId == invoice.invoiceId), isTrue);
    });

    test('3. Physical quantity overbilling (billed 60 > received 50) routes to DISCREPANCY_QUEUE', () {
      final item = MobileSupplierInvoiceItem(
        itemId: 'sii-qty-err',
        productId: 'prod-insulin',
        productBrandName: 'Glarin Insulin 100IU',
        poItemId: 'poi-ins-50',
        grnLineId: testGrn.lines.first.lineId,
        batchNumber: 'BEX-INS-2026',
        billedQuantity: 60, // Billed 60 > GRN 50
        receivedQuantity: 50,
        orderedQuantity: 50,
        billedUnitPrice: 350.00,
        poUnitPrice: 350.00,
      );

      final invoice = invoiceClient.createSupplierInvoice(
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        invoiceNumber: 'INV-BEX-2026-QTY-ERR',
        invoiceDate: DateTime.now(),
        purchaseOrderId: testPo.poId,
        goodsReceiptId: testGrn.grnId,
        items: [item],
      );

      expect(invoice.matchingStatus, equals('DISCREPANCY_QUEUE'));
      expect(invoice.hasDiscrepancy, isTrue);
      expect(
        invoice.discrepancyReasons.any((r) => r.contains('QUANTITY_OVER_BILLING')),
        isTrue,
      );
    });

    test('4. Managerial exception approval unlocks AP posting with documented justification', () {
      final item = MobileSupplierInvoiceItem(
        itemId: 'sii-override',
        productId: 'prod-insulin',
        productBrandName: 'Glarin Insulin 100IU',
        poItemId: 'poi-ins-50',
        grnLineId: testGrn.lines.first.lineId,
        batchNumber: 'BEX-INS-2026',
        billedQuantity: 50,
        receivedQuantity: 50,
        orderedQuantity: 50,
        billedUnitPrice: 360.00, // ৳10 higher
        poUnitPrice: 350.00,
      );

      final invoice = invoiceClient.createSupplierInvoice(
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        invoiceNumber: 'INV-BEX-2026-OVERRIDE',
        invoiceDate: DateTime.now(),
        purchaseOrderId: testPo.poId,
        goodsReceiptId: testGrn.grnId,
        items: [item],
      );

      expect(invoice.matchingStatus, equals('DISCREPANCY_QUEUE'));

      // Empty justification throws ArgumentError
      expect(
        () => invoiceClient.approveException(
          invoiceId: invoice.invoiceId,
          justification: '',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_MISSING_JUSTIFICATION'),
        )),
      );

      // Manager approves exception
      final approved = invoiceClient.approveException(
        invoiceId: invoice.invoiceId,
        justification: 'Price adjustment verified against revised circular',
      );

      expect(approved.matchingStatus, equals('APPROVED_EXCEPTION'));
      expect(approved.exceptionApprovedBy, equals('usr-mgr-1'));
      expect(approved.exceptionApprovedAt, isNotNull);

      final posted = invoiceClient.postInvoiceToAp(invoice.invoiceId);
      expect(posted.matchingStatus, equals('POSTED_TO_AP'));
    });

    test('5. Invoice Rejection sets REJECTED; Cashier role is barred with ERR_STAFF_ROLE_DENIED', () {
      final item = MobileSupplierInvoiceItem(
        itemId: 'sii-reject',
        productId: 'prod-insulin',
        productBrandName: 'Glarin Insulin 100IU',
        poItemId: 'poi-ins-50',
        grnLineId: testGrn.lines.first.lineId,
        batchNumber: 'BEX-INS-2026',
        billedQuantity: 50,
        receivedQuantity: 50,
        orderedQuantity: 50,
        billedUnitPrice: 400.00, // ৳50 spike
        poUnitPrice: 350.00,
      );

      final invoice = invoiceClient.createSupplierInvoice(
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        invoiceNumber: 'INV-BEX-2026-REJECT',
        invoiceDate: DateTime.now(),
        purchaseOrderId: testPo.poId,
        goodsReceiptId: testGrn.grnId,
        items: [item],
      );

      // Cashier barred
      expect(
        () => cashierInvoiceClient.executeThreeWayMatch(invoice.invoiceId),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_STAFF_ROLE_DENIED'),
        )),
      );

      // Manager rejects invoice
      final rejected = invoiceClient.rejectInvoice(
        invoiceId: invoice.invoiceId,
        rejectionReason: 'Unjustified price spike. Returned to vendor.',
      );

      expect(rejected.matchingStatus, equals('REJECTED'));
      expect(rejected.rejectedBy, equals('usr-mgr-1'));
      expect(rejected.rejectedAt, isNotNull);

      // Cannot post rejected invoice to AP
      expect(
        () => invoiceClient.postInvoiceToAp(invoice.invoiceId),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_INVOICE_REJECTED'),
        )),
      );
    });
  });
}

