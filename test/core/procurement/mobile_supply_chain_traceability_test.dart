import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_supply_chain_traceability_client.dart';

void main() {
  group('MobileSupplyChainTraceabilityClient Tests (ADR-0197 / P197)', () {
    late Map<String, MobileTraceabilityRecord> recordStore;
    late MobileSupplyChainTraceabilityClient managerClient;
    late MobileSupplyChainTraceabilityClient cashierClient;

    setUp(() {
      recordStore = {};

      managerClient = MobileSupplyChainTraceabilityClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        recordStore: recordStore,
      );

      cashierClient = MobileSupplyChainTraceabilityClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        recordStore: recordStore,
      );
    });

    MobileBatchLineage createSampleLineage() {
      final prod = MobileProductTrace(
        productId: 'prod-humalog',
        brandName: 'Humalog 100IU/ml',
        genericName: 'Insulin Lispro',
        strength: '100IU/ml',
        dosageForm: 'INJECTION',
        manufacturer: 'Square / Lilly',
        requiresColdChain: true,
      );

      final batch = MobileBatchTrace(
        batchId: 'bat-001',
        batchNumber: 'BATCH-INS-01',
        lotReference: 'LOT-SQ-01',
        expiryDate: '2027-10-31',
        costPerUnit: 450.0,
        status: 'ACTIVE',
        storageCondition: 'Cold Storage 2-8°C',
        isQuarantined: false,
        availableQuantity: 85,
      );

      final sales = [
        MobileDownstreamSale(
          allocationId: 'sla-1',
          invoiceNumber: 'INV-001',
          dispensedAt: '2026-11-06T10:00:00Z',
          quantityDispensed: 18,
          quantityReturned: 3,
          unitSellingPrice: 520.0,
          isReturned: true,
        ),
      ];

      final rec = MobileReconciliation(
        totalReceivedQuantity: 100,
        totalDispensedQuantity: 18,
        totalReturnedQuantity: 3,
        currentStockOnHand: 85,
        discrepancyQuantity: 0,
        coldChainBreachedInTransit: false,
      );

      return MobileBatchLineage(
        product: prod,
        batch: batch,
        poNumbers: ['PO-2026-01'],
        grnNumbers: ['GRN-2026-01'],
        shipmentConsignments: ['SQ-REEFER-01'],
        sales: sales,
        reconciliation: rec,
      );
    }

    test('01. Generates formal traceability record with SHA-256 hash', () {
      final lineage = createSampleLineage();
      final record = managerClient.generateTraceabilityRecord(
        lineage: lineage,
        auditPurpose: 'REGULATORY_INSPECTION',
        notes: 'DGDA Annual GDP Audit',
      );

      expect(record.traceNumber.startsWith('TRC-'), isTrue);
      expect(record.auditPurpose, equals('REGULATORY_INSPECTION'));
      expect(record.reconciliation.totalReceivedQuantity, equals(100));
      expect(record.reconciliation.currentStockOnHand, equals(85));
      expect(record.reconciliation.discrepancyQuantity, equals(0));
      expect(record.immutableVerificationHash.length, equals(64));
    });

    test('02. Hash computation is deterministic and reproducible', () {
      final now = DateTime(2026, 11, 8, 12, 0);
      final hash1 = MobileSupplyChainTraceabilityClient.computeVerificationHash(
        traceId: 'trc-1',
        tenantId: 'tenant-1',
        batchNumber: 'BATCH-01',
        totalReceived: 100,
        totalDispensed: 20,
        currentStock: 80,
        coldChainBreached: false,
        auditPurpose: 'INTERNAL_AUDIT',
        generatedAt: now,
      );

      final hash2 = MobileSupplyChainTraceabilityClient.computeVerificationHash(
        traceId: 'trc-1',
        tenantId: 'tenant-1',
        batchNumber: 'BATCH-01',
        totalReceived: 100,
        totalDispensed: 20,
        currentStock: 80,
        coldChainBreached: false,
        auditPurpose: 'INTERNAL_AUDIT',
        generatedAt: now,
      );

      expect(hash1, equals(hash2));
    });

    test('03. Retrieves traceability record by trace ID', () {
      final lineage = createSampleLineage();
      final record = managerClient.generateTraceabilityRecord(
        lineage: lineage,
        auditPurpose: 'QUALITY_INVESTIGATION',
        notes: 'Customer complaint check',
      );

      final retrieved = managerClient.getTraceabilityRecord(record.traceId);
      expect(retrieved.traceId, equals(record.traceId));
      expect(retrieved.immutableVerificationHash,
          equals(record.immutableVerificationHash));
    });

    test('04. Lists traceability records with audit purpose filter', () {
      final lineage = createSampleLineage();
      managerClient.generateTraceabilityRecord(
        lineage: lineage,
        auditPurpose: 'REGULATORY_INSPECTION',
      );
      managerClient.generateTraceabilityRecord(
        lineage: lineage,
        auditPurpose: 'INTERNAL_AUDIT',
      );

      final regList = managerClient.listTraceabilityRecords(
          auditPurposeFilter: 'REGULATORY_INSPECTION');
      expect(regList.length, equals(1));
      expect(regList.first.auditPurpose, equals('REGULATORY_INSPECTION'));

      final allList = managerClient.listTraceabilityRecords();
      expect(allList.length, equals(2));
    });

    test('05. Cashier role access denied', () {
      final lineage = createSampleLineage();
      expect(
        () => cashierClient.generateTraceabilityRecord(lineage: lineage),
        throwsA(isA<Exception>().having((e) => e.toString(), 'detail',
            contains('ERR_STAFF_ROLE_DENIED'))),
      );
    });
  });
}
