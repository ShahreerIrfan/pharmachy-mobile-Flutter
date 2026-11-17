/// mobile_stock_segregation_test.dart
/// Architecture Decision: ADR-0207 (P207).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_stock_segregation_client.dart';

void main() {
  group('MobileStockSegregationClient Tests (P207)', () {
    late MobileStockSegregationClient client;

    setUp(() {
      client = MobileStockSegregationClient();
      client.registerBatch(MobileBatchStockItem(
        batchId: 'batch-zith',
        batchNumber: 'BATCH-ZITH-01',
        quantityBaseUnits: 100,
        unitCost: 35.0,
        storageLocation: 'SHELF-A2',
        isExpired: false,
      ));
    });

    test('Segregating stock immediately deducts from available sellable inventory', () {
      expect(client.getBatch('batch-zith')!.availableQuantity, equals(100));

      final rec = client.segregateStock(
        tenantId: 'ten-01',
        branchId: 'br-01',
        batchId: 'batch-zith',
        quantity: 30,
        category: MobileSegregationCategory.damaged,
        reasonNotes: 'Outer carton crushed.',
        segregationLocation: 'DAMAGED-BAY',
        actorUserId: 'usr-pharm',
        actorRole: 'STAFF_PHARMACIST',
      );

      expect(rec.status, equals(MobileSegregationStatus.segregated));
      expect(client.getBatch('batch-zith')!.reservedQuantityBaseUnits, equals(30));
      expect(client.getBatch('batch-zith')!.availableQuantity, equals(70));
    });

    test('QA pharmacist clears return with documented justification (>= 15 chars)', () {
      final rec = client.segregateStock(
        tenantId: 'ten-01',
        branchId: 'br-01',
        batchId: 'batch-zith',
        quantity: 15,
        category: MobileSegregationCategory.returnedCustomer,
        reasonNotes: 'Customer return within 15 mins.',
        actorUserId: 'usr-pharm',
        actorRole: 'STAFF_PHARMACIST',
      );

      // Less than 15 chars fails
      expect(
        () => client.releaseToSellable(
          segregationId: rec.segregationId,
          justification: 'Seal ok',
          inspectorUserId: 'usr-pharm',
          inspectorRole: 'STAFF_PHARMACIST',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('ERR_RELEASE_JUSTIFICATION_REQUIRED'),
        )),
      );

      // Valid justification restores availability
      final released = client.releaseToSellable(
        segregationId: rec.segregationId,
        justification: 'Factory packaging seal verified intact and authentic.',
        inspectorUserId: 'usr-pharm',
        inspectorRole: 'STAFF_PHARMACIST',
      );

      expect(released.status, equals(MobileSegregationStatus.releasedToSellable));
      expect(client.getBatch('batch-zith')!.availableQuantity, equals(100));
    });

    test('Recalled or counterfeit stock is strictly prohibited from release', () {
      final rec = client.segregateStock(
        tenantId: 'ten-01',
        branchId: 'br-01',
        batchId: 'batch-zith',
        quantity: 20,
        category: MobileSegregationCategory.recalled,
        reasonNotes: 'DGDA recall notice.',
        actorUserId: 'usr-pharm',
        actorRole: 'STAFF_PHARMACIST',
      );

      expect(
        () => client.releaseToSellable(
          segregationId: rec.segregationId,
          justification: 'Attempting release of recalled stock.',
          inspectorUserId: 'usr-pharm',
          inspectorRole: 'STAFF_PHARMACIST',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_PROHIBITED_RELEASE'),
        )),
      );
    });

    test('Disposal deduction reduces physical batch stock and releases reservation', () {
      final rec = client.segregateStock(
        tenantId: 'ten-01',
        branchId: 'br-01',
        batchId: 'batch-zith',
        quantity: 40,
        category: MobileSegregationCategory.damaged,
        reasonNotes: 'Moisture damage.',
        actorUserId: 'usr-pharm',
        actorRole: 'STAFF_PHARMACIST',
      );

      final disposed = client.disposeOrReturnStock(
        segregationId: rec.segregationId,
        actionType: MobileSegregationStatus.disposedWrittenOff,
        dispositionReference: 'DISP-001',
        notes: 'Incinerated per policy.',
        actorUserId: 'usr-mgr',
        actorRole: 'BRANCH_MANAGER',
      );

      expect(disposed.status, equals(MobileSegregationStatus.disposedWrittenOff));
      expect(client.getBatch('batch-zith')!.quantityBaseUnits, equals(60));
      expect(client.getBatch('batch-zith')!.reservedQuantityBaseUnits, equals(0));
    });

    test('Cashier role is strictly denied from segregating stock', () {
      expect(
        () => client.segregateStock(
          tenantId: 'ten-01',
          branchId: 'br-01',
          batchId: 'batch-zith',
          quantity: 10,
          category: MobileSegregationCategory.damaged,
          reasonNotes: 'Dropped box.',
          actorUserId: 'usr-c',
          actorRole: 'CASHIER',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });
  });
}
