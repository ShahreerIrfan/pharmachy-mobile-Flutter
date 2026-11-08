import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_purchase_document_client.dart';

void main() {
  group('MobilePurchaseDocumentClient Tests (ADR-0198 / P198)', () {
    late Map<String, MobilePurchaseDocument> documentStore;
    late MobilePurchaseDocumentClient managerClient;
    late MobilePurchaseDocumentClient cashierClient;

    setUp(() {
      documentStore = {};

      managerClient = MobilePurchaseDocumentClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        documentStore: documentStore,
      );

      cashierClient = MobilePurchaseDocumentClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        documentStore: documentStore,
      );
    });

    List<MobileDocumentLineItem> createSampleLines() {
      return [
        MobileDocumentLineItem(
          itemId: 'item-1',
          productName: 'Napa Extra 500mg',
          batchOrReference: 'BATCH-NP-01',
          quantity: 100,
          unitCost: 2.50,
          lineTotal: 250.00,
        ),
        MobileDocumentLineItem(
          itemId: 'item-2',
          productName: 'Seclo 20mg Capsule',
          batchOrReference: 'BATCH-SC-02',
          quantity: 50,
          unitCost: 5.00,
          lineTotal: 250.00,
        ),
      ];
    }

    test('01. Generates version 1 PO document with valid SHA-256 hash', () {
      final lines = createSampleLines();
      final doc = managerClient.generateDocument(
        documentType: 'PURCHASE_ORDER',
        sourceId: 'po-001',
        sourceReference: 'PO-202611-001',
        supplierId: 'sup-square',
        supplierName: 'Square Pharmaceuticals Ltd.',
        totalAmount: 500.0,
        lineItems: lines,
        notes: 'Regular restock',
      );

      expect(doc.version, equals(1));
      expect(doc.isLatest, isTrue);
      expect(doc.status, equals('FINAL'));
      expect(doc.lineItems.length, equals(2));
      expect(doc.totalAmount, equals(500.0));
      expect(doc.immutableVerificationHash.length, equals(64));
      expect(managerClient.verifyDocumentIntegrity(doc.documentId), isTrue);
    });

    test('02. Re-generating document increments version to 2 and supersedes version 1', () {
      final lines = createSampleLines();
      final v1 = managerClient.generateDocument(
        documentType: 'PURCHASE_ORDER',
        sourceId: 'po-002',
        sourceReference: 'PO-202611-002',
        supplierId: 'sup-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        totalAmount: 500.0,
        lineItems: lines,
      );

      expect(v1.version, equals(1));
      expect(v1.isLatest, isTrue);

      final v2 = managerClient.generateDocument(
        documentType: 'PURCHASE_ORDER',
        sourceId: 'po-002',
        sourceReference: 'PO-202611-002',
        supplierId: 'sup-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        totalAmount: 600.0,
        lineItems: lines,
      );

      expect(v2.version, equals(2));
      expect(v2.isLatest, isTrue);
      expect(v2.status, equals('FINAL'));

      final retrievedV1 = managerClient.getDocument(v1.documentId);
      expect(retrievedV1.isLatest, isFalse);
      expect(retrievedV1.status, equals('SUPERSEDED'));

      final allVersions = managerClient.listDocuments(
        filterType: 'PURCHASE_ORDER',
        filterSourceId: 'po-002',
        onlyLatest: false,
      );
      expect(allVersions.length, equals(2));
    });

    test('03. Generates Goods Receipt Note and Purchase Return documents', () {
      final lines = createSampleLines();
      final grnDoc = managerClient.generateDocument(
        documentType: 'GOODS_RECEIPT_NOTE',
        sourceId: 'grn-001',
        sourceReference: 'GRN-202611-001',
        supplierId: 'sup-incepta',
        supplierName: 'Incepta Pharmaceuticals Ltd.',
        totalAmount: 500.0,
        lineItems: lines,
      );

      expect(grnDoc.documentNumber.startsWith('DOC-GRN-'), isTrue);

      final retDoc = managerClient.generateDocument(
        documentType: 'PURCHASE_RETURN',
        sourceId: 'ret-001',
        sourceReference: 'RET-202611-001',
        supplierId: 'sup-incepta',
        supplierName: 'Incepta Pharmaceuticals Ltd.',
        totalAmount: 50.0,
        lineItems: lines,
      );

      expect(retDoc.documentNumber.startsWith('DOC-RET-'), isTrue);
    });

    test('04. Generates Supplier Statement document', () {
      final stmtDoc = managerClient.generateDocument(
        documentType: 'SUPPLIER_STATEMENT',
        sourceId: 'sup-square',
        sourceReference: 'STMT-2026-Q4',
        supplierId: 'sup-square',
        supplierName: 'Square Pharmaceuticals Ltd.',
        totalAmount: 125000.0,
      );

      expect(stmtDoc.documentNumber.startsWith('DOC-STMT-'), isTrue);
      expect(stmtDoc.totalAmount, equals(125000.0));
    });

    test('05. Cashier role access denied with ERR_STAFF_ROLE_DENIED', () {
      expect(
        () => cashierClient.generateDocument(
          documentType: 'PURCHASE_ORDER',
          sourceId: 'po-csh-01',
        ),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('ERR_STAFF_ROLE_DENIED'))),
      );
    });

    test('06. Verifies cryptographic integrity check', () {
      final doc = managerClient.generateDocument(
        documentType: 'PURCHASE_ORDER',
        sourceId: 'po-sec-01',
        totalAmount: 100.0,
      );

      expect(managerClient.verifyDocumentIntegrity(doc.documentId), isTrue);
    });
  });
}

