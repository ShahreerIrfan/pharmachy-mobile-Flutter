import 'dart:convert';

/// Architecture Decision: ADR-0238 (P238).
/// POS Mobile Offline Transaction Atomicity & Durable Outbox Engine.
class MobileOfflineStockBatch {
  final String batchId;
  final String productId;
  final String batchNumber;
  int availableQuantity;
  final String unitPriceBdt;

  MobileOfflineStockBatch({
    required this.batchId,
    required this.productId,
    required this.batchNumber,
    required this.availableQuantity,
    required this.unitPriceBdt,
  });
}

class MobileOfflineSaleLine {
  final String lineId;
  final String productId;
  final String batchId;
  final String batchNumber;
  final int quantity;
  final String unitPriceBdt;
  final String lineTotalBdt;

  const MobileOfflineSaleLine({
    required this.lineId,
    required this.productId,
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    required this.unitPriceBdt,
    required this.lineTotalBdt,
  });

  Map<String, dynamic> toJson() => {
    'line_id': lineId,
    'product_id': productId,
    'batch_id': batchId,
    'batch_number': batchNumber,
    'quantity': quantity,
    'unit_price_bdt': unitPriceBdt,
    'line_total_bdt': lineTotalBdt,
  };
}

class MobileOfflineOutboxEvent {
  final String eventId;
  final String eventType;
  final String aggregateId;
  final String payloadJson;
  String status;
  final String createdAt;

  MobileOfflineOutboxEvent({
    required this.eventId,
    required this.eventType,
    required this.aggregateId,
    required this.payloadJson,
    this.status = 'PENDING',
    required this.createdAt,
  });
}

class MobilePosOfflineTransactionEngine {
  final Map<String, MobileOfflineStockBatch> _stockDb = {};
  final Map<String, Map<String, dynamic>> _salesDb = {};
  final List<MobileOfflineOutboxEvent> _outbox = [];

  void seedStock(MobileOfflineStockBatch batch) {
    _stockDb[batch.batchId] = batch;
  }

  int getAvailableStock(String batchId) {
    return _stockDb[batchId]?.availableQuantity ?? -1;
  }

  bool hasSale(String saleId) => _salesDb.containsKey(saleId);

  List<MobileOfflineOutboxEvent> getPendingOutbox() {
    return _outbox.where((e) => e.status == 'PENDING').toList();
  }

  /// Commits offline sale, lines, stock deduction, and outbox event atomically.
  /// If stock is insufficient or order number already exists, rolls back completely.
  MobileOfflineOutboxEvent commitOfflineSaleAtomic({
    required String saleId,
    required String orderNumber,
    required String tenantId,
    required String branchId,
    required String deviceId,
    required String cashierId,
    required String grandTotalBdt,
    required List<MobileOfflineSaleLine> lines,
    String paymentMethod = 'CASH',
  }) {
    if (lines.isEmpty) {
      throw ArgumentError('Offline sale must contain at least one line item.');
    }

    // Check duplicate order number
    for (final s in _salesDb.values) {
      if (s['order_number'] == orderNumber) {
        throw StateError('Duplicate order_number collision: $orderNumber');
      }
    }

    // Phase 1: Preflight Stock Verification (Rollback Gate)
    for (final line in lines) {
      final batch = _stockDb[line.batchId];
      if (batch == null || batch.availableQuantity < line.quantity) {
        final avail = batch?.availableQuantity ?? 0;
        throw StateError(
          'Insufficient local stock for batch ${line.batchId}. Available: $avail, Requested: ${line.quantity}',
        );
      }
    }

    // Phase 2: Atomic State Mutex Execution
    final stockSnapshot = <String, int>{};
    for (final line in lines) {
      stockSnapshot[line.batchId] = _stockDb[line.batchId]!.availableQuantity;
      _stockDb[line.batchId]!.availableQuantity -= line.quantity;
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final saleRecord = {
      'sale_id': saleId,
      'order_number': orderNumber,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'device_id': deviceId,
      'cashier_id': cashierId,
      'grand_total_bdt': grandTotalBdt,
      'payment_method': paymentMethod,
      'lines': lines.map((l) => l.toJson()).toList(),
      'created_at': nowIso,
      'status': 'COMMITTED',
    };
    _salesDb[saleId] = saleRecord;

    final outboxEvent = MobileOfflineOutboxEvent(
      eventId: 'evt-mob-${DateTime.now().millisecondsSinceEpoch}',
      eventType: 'POS_SALE_COMMITTED',
      aggregateId: saleId,
      payloadJson: jsonEncode(saleRecord),
      status: 'PENDING',
      createdAt: nowIso,
    );
    _outbox.add(outboxEvent);

    return outboxEvent;
  }
}
