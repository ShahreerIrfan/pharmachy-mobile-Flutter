/// mobile_stock_quarantine_test.dart
/// Architecture Decision: ADR-0206 (P206).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_stock_quarantine_client.dart';

void main() {
  group('MobileStockQuarantineClient Tests (P206)', () {
    late MobileStockQuarantineClient client;

    setUp(() {
      client = MobileStockQuarantineClient();
      client.registerBatch(MobileBatchItem(
        batchId: 'batch-act',
        batchNumber: 'BATCH-ACT-01',
        expiryDate: DateTime.now().add(const Duration(days: 100)),
        quantityBaseUnits: 50,
        unitCost: 100.0,
        storageLocation: 'SHELF-A1',
      ));
      client.registerBatch(MobileBatchItem(
        batchId: 'batch-exp',
        batchNumber: 'BATCH-EXP-01',
        expiryDate: DateTime.now().subtract(const Duration(days: 5)),
        quantityBaseUnits: 30,
        unitCost: 80.0,
        storageLocation: 'SHELF-B2',
      ));
    });

    test('Manual quarantine moves batch and prohibits checkout sales', () {
      expect(() => client.assertSaleAllowed('batch-act'), returnsNormally);

      final record = client.quarantineBatch(
        tenantId: 'ten-01',
        branchId: 'br-01',
        batchId: 'batch-act',
        reason: MobileQuarantineReason.coldChainExcursion,
        notes: 'Temperature spike detected.',
        quarantineLocation: 'QUARANTINE-COLD-BIN',
        actorUserId: 'usr-pharm',
        actorRole: 'STAFF_PHARMACIST',
      );

      expect(record.status, equals(MobileQuarantineStatus.quarantined));
      expect(client.getBatch('batch-act')!.storageLocation, equals('QUARANTINE-COLD-BIN'));
      expect(client.getBatch('batch-act')!.isQuarantined, isTrue);

      expect(
        () => client.assertSaleAllowed('batch-act'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_EXPIRED_STOCK_SALE_PROHIBITED'),
        )),
      );
    });

    test('Automated sweep detects expired batches and quarantines them', () {
      final swept = client.sweepExpiredBatches(
        tenantId: 'ten-01',
        branchId: 'br-01',
        actorUserId: 'usr-pharm',
        actorRole: 'STAFF_PHARMACIST',
      );
      expect(swept.length, equals(1));
      expect(swept.first.batchNumber, equals('BATCH-EXP-01'));
      expect(client.getBatch('batch-exp')!.isQuarantined, isTrue);
    });

    test('Manager approves disposal, sets batch quantity to zero', () {
      final rec = client.quarantineBatch(
        tenantId: 'ten-01',
        branchId: 'br-01',
        batchId: 'batch-exp',
        reason: MobileQuarantineReason.batchExpired,
        notes: 'Expired',
        actorUserId: 'usr-p',
        actorRole: 'STAFF_PHARMACIST',
      );
      final actioned = client.approveDisposal(
        quarantineId: rec.quarantineId,
        actionType: MobileQuarantineStatus.disposed,
        certRef: 'CERT-001',
        actionNotes: 'Incinerated',
        actorUserId: 'usr-mgr',
        actorRole: 'BRANCH_MANAGER',
      );
      expect(actioned.status, equals(MobileQuarantineStatus.disposed));
      expect(client.getBatch('batch-exp')!.quantityBaseUnits, equals(0));
      expect(client.getBatch('batch-exp')!.status, equals('DEPLETED'));
    });

    test('Release guard: expired batch cannot be released back to active stock', () {
      final rec = client.quarantineBatch(
        tenantId: 'ten-01',
        branchId: 'br-01',
        batchId: 'batch-exp',
        reason: MobileQuarantineReason.batchExpired,
        notes: 'Expired',
        actorUserId: 'usr-p',
        actorRole: 'STAFF_PHARMACIST',
      );
      expect(
        () => client.releaseQuarantine(
          quarantineId: rec.quarantineId,
          releaseReason: 'Attempt release',
          newStorageLocation: 'SHELF-A1',
          actorUserId: 'usr-mgr',
          actorRole: 'BRANCH_MANAGER',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_EXPIRED_BATCH_CANNOT_BE_RELEASED'),
        )),
      );
    });

    test('Cashier role is strictly denied from quarantine operations', () {
      expect(
        () => client.quarantineBatch(
          tenantId: 'ten-01',
          branchId: 'br-01',
          batchId: 'batch-act',
          reason: MobileQuarantineReason.qualityDefect,
          notes: 'Notes',
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

