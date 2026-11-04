import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_batch_entity_client.dart';

void main() {
  final today = DateTime(2026, 11, 4);

  group('MobileBatchEntityClient Date Validation', () {
    test('passes valid manufacturing date and future expiry date', () {
      final res = MobileBatchEntityClient.validateBatchDates(
        mfgDate: DateTime(2025, 1, 1),
        expiryDate: DateTime(2027, 6, 1),
        today: today,
      );
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('rejects expiry date prior to manufacturing date', () {
      final res = MobileBatchEntityClient.validateBatchDates(
        mfgDate: DateTime(2026, 6, 1),
        expiryDate: DateTime(2025, 1, 1),
        today: today,
      );
      expect(res.isValid, isFalse);
      expect(res.errorCode, 'ERR_EXPIRY_BEFORE_MANUFACTURING');
    });

    test('rejects new batch when expiry date is already in the past', () {
      final res = MobileBatchEntityClient.validateBatchDates(
        mfgDate: DateTime(2024, 1, 1),
        expiryDate: DateTime(2026, 10, 1),
        today: today,
      );
      expect(res.isValid, isFalse);
      expect(res.errorCode, 'ERR_BATCH_EXPIRED_ON_CREATION');
    });
  });

  group('MobileBatchEntityClient Dispensability Evaluation', () {
    test('allows dispensing valid active batch with sufficient stock', () {
      final batch = MobileBatchEntity(
        batchId: 'bat-101',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        productBrandName: 'Ace Plus',
        batchNumber: 'B-101',
        quantityBaseUnits: 100,
        costPerUnit: 2.50,
        manufacturingDate: DateTime(2025, 1, 1),
        expiryDate: DateTime(2027, 12, 1),
      );

      final res = MobileBatchEntityClient.evaluateDispensability(
        batch: batch,
        requestedUnits: 10,
        today: today,
      );

      expect(res.isDispensable, isTrue);
      expect(res.errorCode, isNull);
      expect(res.batchId, 'bat-101');
    });

    test('blocks dispensing when statutory recall notice is active for batch', () {
      final batch = MobileBatchEntity(
        batchId: 'bat-102',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        batchNumber: 'B-RECALLED',
        quantityBaseUnits: 50,
        costPerUnit: 2.50,
        expiryDate: DateTime(2027, 12, 1),
      );

      const notice = MobileRecallNotice(
        noticeId: 'rec-001',
        noticeNumber: 'NOT-2026-DGDA-01',
        productId: 'prod-1',
        recallScope: 'BATCH_SPECIFIC',
        affectedBatchNumbers: {'B-RECALLED'},
        reason: 'Impurities found in batch samples',
      );

      final res = MobileBatchEntityClient.evaluateDispensability(
        batch: batch,
        recallNotice: notice,
        requestedUnits: 5,
        today: today,
      );

      expect(res.isDispensable, isFalse);
      expect(res.errorCode, 'ERR_BATCH_RECALLED');
      expect(res.messageBn, contains('প্রত্যাহার'));
    });

    test('blocks dispensing expired batch', () {
      final batch = MobileBatchEntity(
        batchId: 'bat-103',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        batchNumber: 'B-EXP',
        quantityBaseUnits: 40,
        costPerUnit: 2.50,
        expiryDate: DateTime(2026, 6, 1), // in past relative to 2026-11-04
      );

      final res = MobileBatchEntityClient.evaluateDispensability(
        batch: batch,
        requestedUnits: 5,
        today: today,
      );

      expect(res.isDispensable, isFalse);
      expect(res.errorCode, 'ERR_BATCH_EXPIRED');
      expect(res.messageBn, contains('মেয়াদ উত্তীর্ণ'));
    });

    test('blocks dispensing quarantined batch', () {
      final batch = MobileBatchEntity(
        batchId: 'bat-104',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        batchNumber: 'B-QUAR',
        quantityBaseUnits: 40,
        costPerUnit: 2.50,
        expiryDate: DateTime(2027, 6, 1),
        isQuarantined: true,
        status: 'QUARANTINED',
      );

      final res = MobileBatchEntityClient.evaluateDispensability(
        batch: batch,
        requestedUnits: 5,
        today: today,
      );

      expect(res.isDispensable, isFalse);
      expect(res.errorCode, 'ERR_BATCH_QUARANTINED');
      expect(res.messageBn, contains('কোয়ারেন্টাইনে'));
    });

    test('blocks dispensing when requested units exceed stock', () {
      final batch = MobileBatchEntity(
        batchId: 'bat-105',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        batchNumber: 'B-LOW',
        quantityBaseUnits: 5,
        costPerUnit: 2.50,
        expiryDate: DateTime(2027, 6, 1),
      );

      final res = MobileBatchEntityClient.evaluateDispensability(
        batch: batch,
        requestedUnits: 10,
        today: today,
      );

      expect(res.isDispensable, isFalse);
      expect(res.errorCode, 'ERR_INSUFFICIENT_STOCK');
      expect(res.messageBn, contains('পর্যাপ্ত স্টক নেই'));
    });
  });

  group('MobileBatchEntityClient FEFO & Stock Operations', () {
    test('selects earliest non-expired batch according to FEFO', () {
      final bExpired = MobileBatchEntity(
        batchId: 'b-exp',
        tenantId: 't1',
        branchId: 'br1',
        productId: 'p1',
        batchNumber: 'B-EXP',
        quantityBaseUnits: 100,
        costPerUnit: 2.0,
        expiryDate: DateTime(2026, 1, 1),
      );

      final bFar = MobileBatchEntity(
        batchId: 'b-far',
        tenantId: 't1',
        branchId: 'br1',
        productId: 'p1',
        batchNumber: 'B-FAR',
        quantityBaseUnits: 100,
        costPerUnit: 2.0,
        expiryDate: DateTime(2028, 1, 1),
      );

      final bNear = MobileBatchEntity(
        batchId: 'b-near',
        tenantId: 't1',
        branchId: 'br1',
        productId: 'p1',
        batchNumber: 'B-NEAR',
        quantityBaseUnits: 100,
        costPerUnit: 2.0,
        expiryDate: DateTime(2027, 1, 1),
      );

      final selected = MobileBatchEntityClient.selectFefoBatch(
        batches: [bFar, bExpired, bNear],
        productId: 'p1',
        requestedUnits: 10,
        today: today,
      );

      expect(selected, isNotNull);
      expect(selected!.batchId, 'b-near');
      expect(selected.batchNumber, 'B-NEAR');
    });

    test('deducts stock base units and marks DEPLETED at zero', () {
      final batch = MobileBatchEntity(
        batchId: 'b-dep',
        tenantId: 't1',
        branchId: 'br1',
        productId: 'p1',
        batchNumber: 'B-DEP',
        quantityBaseUnits: 10,
        costPerUnit: 2.0,
        expiryDate: DateTime(2027, 1, 1),
      );

      final d1 = MobileBatchEntityClient.deductBatchStock(batch, 6);
      expect(d1, isTrue);
      expect(batch.quantityBaseUnits, 4);
      expect(batch.status, 'ACTIVE');

      final d2 = MobileBatchEntityClient.deductBatchStock(batch, 4);
      expect(d2, isTrue);
      expect(batch.quantityBaseUnits, 0);
      expect(batch.status, 'DEPLETED');

      final d3 = MobileBatchEntityClient.deductBatchStock(batch, 1);
      expect(d3, isFalse);
    });
  });
}
