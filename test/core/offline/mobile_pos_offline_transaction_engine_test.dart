import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_pos_offline_transaction_engine.dart';

void main() {
  group('P238 - Mobile POS Offline Transaction Atomicity & Outbox Tests', () {
    late MobilePosOfflineTransactionEngine engine;

    setUp(() {
      engine = MobilePosOfflineTransactionEngine();
      engine.seedStock(
        MobileOfflineStockBatch(
          batchId: 'batch-napa-01',
          productId: 'prod-napa-500',
          batchNumber: 'NP-202611-01',
          availableQuantity: 50,
          unitPriceBdt: '2.50',
        ),
      );
    });

    test('commitOfflineSaleAtomic commits sale, deducts stock and enqueues outbox', () {
      final line = MobileOfflineSaleLine(
        lineId: 'line-m-01',
        productId: 'prod-napa-500',
        batchId: 'batch-napa-01',
        batchNumber: 'NP-202611-01',
        quantity: 10,
        unitPriceBdt: '2.50',
        lineTotalBdt: '25.00',
      );

      final outbox = engine.commitOfflineSaleAtomic(
        saleId: 'sale-m-001',
        orderNumber: 'MOB-ORD-20261116-0001',
        tenantId: 'ten-001',
        branchId: 'br-001',
        deviceId: 'MOB-DEV-01',
        cashierId: 'user-001',
        grandTotalBdt: '25.00',
        lines: [line],
      );

      expect(outbox.status, equals('PENDING'));
      expect(engine.getAvailableStock('batch-napa-01'), equals(40));
      expect(engine.hasSale('sale-m-001'), isTrue);
      expect(engine.getPendingOutbox().length, equals(1));
    });

    test('commitOfflineSaleAtomic rolls back on insufficient stock without deduction', () {
      final line = MobileOfflineSaleLine(
        lineId: 'line-m-02',
        productId: 'prod-napa-500',
        batchId: 'batch-napa-01',
        batchNumber: 'NP-202611-01',
        quantity: 100, // exceeds 50 available
        unitPriceBdt: '2.50',
        lineTotalBdt: '250.00',
      );

      expect(
        () => engine.commitOfflineSaleAtomic(
          saleId: 'sale-m-fail',
          orderNumber: 'MOB-ORD-20261116-0002',
          tenantId: 'ten-001',
          branchId: 'br-001',
          deviceId: 'MOB-DEV-01',
          cashierId: 'user-001',
          grandTotalBdt: '250.00',
          lines: [line],
        ),
        throwsStateError,
      );

      // Invariants
      expect(engine.getAvailableStock('batch-napa-01'), equals(50));
      expect(engine.hasSale('sale-m-fail'), isFalse);
      expect(engine.getPendingOutbox(), isEmpty);
    });

    test('commitOfflineSaleAtomic rolls back on duplicate order number collision', () {
      final line = MobileOfflineSaleLine(
        lineId: 'line-m-03',
        productId: 'prod-napa-500',
        batchId: 'batch-napa-01',
        batchNumber: 'NP-202611-01',
        quantity: 5,
        unitPriceBdt: '2.50',
        lineTotalBdt: '12.50',
      );

      engine.commitOfflineSaleAtomic(
        saleId: 'sale-m-ok',
        orderNumber: 'MOB-ORD-COLLISION',
        tenantId: 'ten-001',
        branchId: 'br-001',
        deviceId: 'MOB-DEV-01',
        cashierId: 'user-001',
        grandTotalBdt: '12.50',
        lines: [line],
      );

      expect(engine.getAvailableStock('batch-napa-01'), equals(45));

      // Attempt duplicate order number
      expect(
        () => engine.commitOfflineSaleAtomic(
          saleId: 'sale-m-dup',
          orderNumber: 'MOB-ORD-COLLISION',
          tenantId: 'ten-001',
          branchId: 'br-001',
          deviceId: 'MOB-DEV-01',
          cashierId: 'user-001',
          grandTotalBdt: '12.50',
          lines: [line],
        ),
        throwsStateError,
      );

      // Stock remains at 45 (no extra deduction)
      expect(engine.getAvailableStock('batch-napa-01'), equals(45));
      expect(engine.hasSale('sale-m-dup'), isFalse);
    });
  });
}
