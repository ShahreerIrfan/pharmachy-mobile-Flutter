// mobile_cold_chain_evidence_test.dart
// Architecture Decision: ADR-0189 (P189).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_purchase_order_client.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_goods_receipt_client.dart';

void main() {
  group('MobileColdChainEvidence Tests (P189)', () {
    late MobilePurchaseOrderClient poClient;
    late MobileGoodsReceiptClient grnClient;
    late MobileGoodsReceiptClient cashierGrnClient;
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

      cashierGrnClient = MobileGoodsReceiptClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        initialStore: grnStore,
        poClient: poClient,
      );

      // Create PO with 50 vials of Insulin (cold-chain product)
      testPo = poClient.createPurchaseOrder(
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        notes: 'Insulin purchase',
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
    });

    test('1. Valid cold chain receipt (4.5C) creates NOT_QUARANTINED evidence and posts to active stock', () {
      final line = MobileGoodsReceiptLine(
        poItemId: 'poi-ins-50',
        productId: 'prod-insulin',
        productBrandName: 'Glarin Insulin 100IU',
        batchNumber: 'BEX-INS-001',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        receivedQuantityBaseUnits: 50,
        unitCost: 350.00,
        mrpUnit: 420.00,
        storageLocation: 'COLD_ROOM_A',
      );

      final grn = grnClient.createGrn(
        purchaseOrderId: testPo.poId,
        supplierId: 'supp-beximco',
        challanNumber: 'CH-INS-001',
        storageCondition: 'COLD_CHAIN_2_8C',
        storageTemperatureCelsius: 4.5,
        storageCheckPassed: true,
        proofOfOrigin: 'REF-VAN-LOG-9921',
        lines: [line],
      );

      expect(grn.coldChainEvidences.length, equals(1));
      final evidence = grn.coldChainEvidences.first;
      expect(evidence.quarantineStatus, equals('NOT_QUARANTINED'));
      expect(evidence.excursionDetected, isFalse);
      expect(evidence.recordedTemperatureCelsius, equals(4.5));
      expect(line.isQuarantined, isFalse);

      final posted = grnClient.postGrnToStock(grn.grnId);
      expect(posted.status, equals('POSTED'));
      expect(posted.lines.first.isQuarantined, isFalse);
    });

    test('2. Suspicious temperature excursion (9.2C) with quarantineSuspicious=true sets PENDING_REVIEW and isQuarantined=true', () {
      final line = MobileGoodsReceiptLine(
        poItemId: 'poi-ins-50',
        productId: 'prod-insulin',
        productBrandName: 'Glarin Insulin 100IU',
        batchNumber: 'BEX-INS-WARM',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        receivedQuantityBaseUnits: 50,
        unitCost: 350.00,
        mrpUnit: 420.00,
      );

      final grn = grnClient.createGrn(
        purchaseOrderId: testPo.poId,
        supplierId: 'supp-beximco',
        challanNumber: 'CH-INS-WARM-01',
        storageCondition: 'COLD_CHAIN_2_8C',
        storageTemperatureCelsius: 9.2,
        storageCheckPassed: false,
        quarantineSuspicious: true,
        notes: 'Van thermometer showed 9.2C; ice packs partially thawed',
        lines: [line],
      );

      expect(grn.coldChainEvidences.length, equals(1));
      final evidence = grn.coldChainEvidences.first;
      expect(evidence.quarantineStatus, equals('PENDING_REVIEW'));
      expect(evidence.excursionDetected, isTrue);
      expect(evidence.packagingCondition, equals('ICE_PACKS_MELTED'));
      expect(line.isQuarantined, isTrue);

      final posted = grnClient.postGrnToStock(grn.grnId);
      expect(posted.status, equals('POSTED'));
      expect(posted.lines.first.isQuarantined, isTrue);
    });

    test('3. Strict inspection failure without quarantineSuspicious throws ERR_STORAGE_CHECK_FAILED', () {
      final line = MobileGoodsReceiptLine(
        poItemId: 'poi-ins-50',
        productId: 'prod-insulin',
        batchNumber: 'BEX-INS-REJECT',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        receivedQuantityBaseUnits: 50,
        unitCost: 350.00,
      );

      expect(
        () => grnClient.createGrn(
          purchaseOrderId: testPo.poId,
          supplierId: 'supp-beximco',
          challanNumber: 'CH-INS-FAIL',
          storageCondition: 'COLD_CHAIN_2_8C',
          storageTemperatureCelsius: 11.5,
          storageCheckPassed: false,
          quarantineSuspicious: false,
          lines: [line],
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_STORAGE_CHECK_FAILED'),
        )),
      );
    });

    test('4. Authorized quarantine resolution (APPROVE_RELEASE) releases line from quarantine with justification', () {
      final line = MobileGoodsReceiptLine(
        poItemId: 'poi-ins-50',
        productId: 'prod-insulin',
        batchNumber: 'BEX-INS-VERIFY',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        receivedQuantityBaseUnits: 50,
        unitCost: 350.00,
        mrpUnit: 420.00,
      );

      final grn = grnClient.createGrn(
        purchaseOrderId: testPo.poId,
        supplierId: 'supp-beximco',
        storageCondition: 'COLD_CHAIN_2_8C',
        storageTemperatureCelsius: 8.8,
        quarantineSuspicious: true,
        lines: [line],
      );

      final evidence = grn.coldChainEvidences.first;
      expect(evidence.quarantineStatus, equals('PENDING_REVIEW'));
      expect(line.isQuarantined, isTrue);

      final resolved = grnClient.resolveQuarantine(
        grnId: grn.grnId,
        evidenceId: evidence.evidenceId,
        resolutionAction: 'APPROVE_RELEASE',
        justification: 'Manufacturer confirmed product stability maintained up to 10C for 6 hours; release approved by QA',
      );

      expect(resolved.quarantineStatus, equals('RELEASED'));
      expect(resolved.resolutionAction, equals('APPROVE_RELEASE'));
      expect(resolved.reviewedById, equals('usr-mgr-1'));
      expect(line.isQuarantined, isFalse);
    });

    test('5. Authorized REJECT_RETURN unquarantines and credits apInvoiceAmount; Cashier role is barred with ERR_STAFF_ROLE_DENIED', () {
      final line = MobileGoodsReceiptLine(
        poItemId: 'poi-ins-50',
        productId: 'prod-insulin',
        batchNumber: 'BEX-INS-SPOILED',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        receivedQuantityBaseUnits: 50,
        unitCost: 350.00,
        mrpUnit: 420.00,
      );

      final grn = grnClient.createGrn(
        purchaseOrderId: testPo.poId,
        supplierId: 'supp-beximco',
        storageCondition: 'COLD_CHAIN_2_8C',
        storageTemperatureCelsius: 15.0,
        quarantineSuspicious: true,
        lines: [line],
      );

      grnClient.postGrnToStock(grn.grnId);
      final initialApAmount = grn.apInvoiceAmount;
      expect(initialApAmount, equals(17500.0));

      final evidence = grn.coldChainEvidences.first;

      // Cashier barred
      expect(
        () => cashierGrnClient.resolveQuarantine(
          grnId: grn.grnId,
          evidenceId: evidence.evidenceId,
          resolutionAction: 'REJECT_RETURN',
          justification: 'Cashier attempt',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_STAFF_ROLE_DENIED'),
        )),
      );

      // Manager successfully rejects & returns
      final resolved = grnClient.resolveQuarantine(
        grnId: grn.grnId,
        evidenceId: evidence.evidenceId,
        resolutionAction: 'REJECT_RETURN',
        justification: 'Temperature 15C exceeded safety limit; returned to Beximco for credit note',
      );

      expect(resolved.quarantineStatus, equals('RETURNED_TO_SUPPLIER'));
      expect(resolved.resolutionAction, equals('REJECT_RETURN'));
      expect(line.isQuarantined, isFalse);
      expect(grn.apInvoiceAmount, equals(0.0)); // credited
    });
  });
}
