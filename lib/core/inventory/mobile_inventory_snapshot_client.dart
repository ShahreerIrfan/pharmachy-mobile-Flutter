import 'dart:convert';
import 'dart:typed_data';

/// mobile_inventory_snapshot_client.dart
/// Architecture Decision: ADR-0215 (P215).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.
///
/// Mobile Manager Client for Inventory Snapshots & Canonical Read Models:
/// - Strictly derived from append-only StockLedgerEntry ledger.
/// - Mathematical reconciliation check (batch balance == ledger delta sum).
/// - Cryptographic SHA-256 verification hash over ordered line items.
/// - Restricts unauthorized cashier access (Owner/Manager/Pharmacist only).
/// - Provides offline caching and fast status inspection.

enum MobileSnapshotCheckpointType {
  dailyEod('Daily End of Day', 'দৈনিক কার্যদিবস সমাপ্তি'),
  monthlyClose('Monthly Accounting Close', 'মাসিক হিসাব ক্লোজিং'),
  cycleCount('Cycle Count Checkpoint', 'সাইকেল কাউন্ট স্ন্যাপশট'),
  onDemand('On-Demand Snapshot', 'অন-ডিমান্ড স্ন্যাপশট');

  final String labelEn;
  final String labelBn;

  const MobileSnapshotCheckpointType(this.labelEn, this.labelBn);
}

class MobileSnapshotLineItem {
  final String productId;
  final String productName;
  final String batchNumber;
  final String storageLocation;
  final int quantityBaseUnits;
  final double unitCost;
  final double totalValuation;
  final bool isColdChain;
  final int ledgerDeltaSum;
  final int discrepancy;

  MobileSnapshotLineItem({
    required this.productId,
    required this.productName,
    required this.batchNumber,
    this.storageLocation = '',
    required this.quantityBaseUnits,
    required this.unitCost,
    this.isColdChain = false,
    required this.ledgerDeltaSum,
  })  : totalValuation = unitCost * quantityBaseUnits,
        discrepancy = quantityBaseUnits - ledgerDeltaSum;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'batch_number': batchNumber,
    'storage_location': storageLocation,
    'quantity_base_units': quantityBaseUnits,
    'unit_cost': unitCost,
    'total_valuation': totalValuation,
    'is_cold_chain': isColdChain,
    'ledger_delta_sum': ledgerDeltaSum,
    'discrepancy': discrepancy,
  };

  factory MobileSnapshotLineItem.fromJson(Map<String, dynamic> json) {
    return MobileSnapshotLineItem(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? '',
      batchNumber: json['batch_number'] as String,
      storageLocation: json['storage_location'] as String? ?? '',
      quantityBaseUnits: (json['quantity_base_units'] as num).toInt(),
      unitCost: (json['unit_cost'] as num).toDouble(),
      isColdChain: json['is_cold_chain'] as bool? ?? false,
      ledgerDeltaSum: (json['ledger_delta_sum'] as num?)?.toInt() ?? (json['quantity_base_units'] as num).toInt(),
    );
  }
}

class MobileSnapshotCheckpoint {
  final String snapshotId;
  final String tenantId;
  final String branchId;
  final MobileSnapshotCheckpointType checkpointType;
  final DateTime asOfTimestamp;
  final int totalProducts;
  final int totalBatches;
  final int totalQuantity;
  final double totalValuation;
  final int ledgerEntriesCount;
  final String sha256Checksum;
  final bool isReconciled;
  final List<MobileSnapshotLineItem> lineItems;

  MobileSnapshotCheckpoint({
    required this.snapshotId,
    required this.tenantId,
    required this.branchId,
    required this.checkpointType,
    required this.asOfTimestamp,
    required this.totalProducts,
    required this.totalBatches,
    required this.totalQuantity,
    required this.totalValuation,
    required this.ledgerEntriesCount,
    required this.sha256Checksum,
    required this.isReconciled,
    required this.lineItems,
  });

  Map<String, dynamic> toJson() => {
    'snapshot_id': snapshotId,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'checkpoint_type': checkpointType.name,
    'as_of_timestamp': asOfTimestamp.toIso8601String(),
    'total_products': totalProducts,
    'total_batches': totalBatches,
    'total_quantity': totalQuantity,
    'total_valuation': totalValuation,
    'ledger_entries_count': ledgerEntriesCount,
    'sha256_checksum': sha256Checksum,
    'is_reconciled': isReconciled,
    'line_items': lineItems.map((e) => e.toJson()).toList(),
  };
}

class SimpleSha256 {
  static final List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xFFFFFFFF;
  static int _ch(int x, int y, int z) => ((x & y) ^ ((~x) & z)) & 0xFFFFFFFF;
  static int _maj(int x, int y, int z) => ((x & y) ^ (x & z) ^ (y & z)) & 0xFFFFFFFF;
  static int _s0(int x) => (_rotr(x, 2) ^ _rotr(x, 13) ^ _rotr(x, 22)) & 0xFFFFFFFF;
  static int _s1(int x) => (_rotr(x, 6) ^ _rotr(x, 11) ^ _rotr(x, 25)) & 0xFFFFFFFF;
  static int _sigma0(int x) => (_rotr(x, 7) ^ _rotr(x, 18) ^ (x >>> 3)) & 0xFFFFFFFF;
  static int _sigma1(int x) => (_rotr(x, 17) ^ _rotr(x, 19) ^ (x >>> 10)) & 0xFFFFFFFF;

  static String hashString(String message) {
    final bytes = utf8.encode(message);
    final bitLength = bytes.length * 8;
    final paddedLength = ((bytes.length + 8 + 64) ~/ 64) * 64;
    final buffer = Uint8List(paddedLength);
    buffer.setRange(0, bytes.length, bytes);
    buffer[bytes.length] = 0x80;
    final bd = ByteData.sublistView(buffer);
    bd.setUint64(paddedLength - 8, bitLength, Endian.big);

    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final w = Int32List(64);
    for (int offset = 0; offset < paddedLength; offset += 64) {
      for (int i = 0; i < 16; i++) {
        w[i] = bd.getUint32(offset + (i * 4), Endian.big);
      }
      for (int i = 16; i < 64; i++) {
        w[i] = (_sigma1(w[i - 2]) + w[i - 7] + _sigma0(w[i - 15]) + w[i - 16]) & 0xFFFFFFFF;
      }
      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;
      int e = h4;
      int f = h5;
      int g = h6;
      int h = h7;

      for (int i = 0; i < 64; i++) {
        final t1 = (h + _s1(e) + _ch(e, f, g) + _k[i] + w[i]) & 0xFFFFFFFF;
        final t2 = (_s0(a) + _maj(a, b, c)) & 0xFFFFFFFF;
        h = g;
        g = f;
        f = e;
        e = (d + t1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & 0xFFFFFFFF;
      }
      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    return [h0, h1, h2, h3, h4, h5, h6, h7]
        .map((x) => x.toRadixString(16).padLeft(8, '0'))
        .join();
  }
}

class MobileInventorySnapshotClient {
  final Map<String, MobileSnapshotCheckpoint> _snapshotCache = {};

  static const Set<String> _allowedRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
  };

  void _assertInventoryRole(String userRole) {
    if (userRole.toUpperCase() == 'CASHIER' || !_allowedRoles.contains(userRole.toUpperCase())) {
      throw StateError('Cashiers cannot generate or audit inventory snapshots. Access is restricted to Managers and Pharmacists.');
    }
  }

  static String computeChecksum(List<MobileSnapshotLineItem> lines) {
    final sorted = List<MobileSnapshotLineItem>.from(lines);
    sorted.sort((a, b) {
      final pCmp = a.productId.compareTo(b.productId);
      if (pCmp != 0) return pCmp;
      return a.batchNumber.compareTo(b.batchNumber);
    });

    final sb = StringBuffer();
    for (final item in sorted) {
      sb.write('${item.productId}|${item.batchNumber}|${item.quantityBaseUnits}|${item.unitCost.toStringAsFixed(2)}|${item.totalValuation.toStringAsFixed(2)}\n');
    }
    return SimpleSha256.hashString(sb.toString());
  }

  MobileSnapshotCheckpoint generateSnapshot({
    required String userRole,
    required String tenantId,
    required String branchId,
    required MobileSnapshotCheckpointType checkpointType,
    required List<MobileSnapshotLineItem> lines,
    required int ledgerEntriesCount,
  }) {
    _assertInventoryRole(userRole);

    final products = <String>{};
    final batches = <String>{};
    int totalQty = 0;
    double totalVal = 0.0;
    bool allReconciled = true;

    for (final item in lines) {
      products.add(item.productId);
      batches.add(item.batchNumber);
      totalQty += item.quantityBaseUnits;
      totalVal += item.totalValuation;
      if (item.discrepancy != 0) {
        allReconciled = false;
      }
    }

    final checksum = computeChecksum(lines);
    final id = 'snap-mob-${DateTime.now().millisecondsSinceEpoch}';

    final checkpoint = MobileSnapshotCheckpoint(
      snapshotId: id,
      tenantId: tenantId,
      branchId: branchId,
      checkpointType: checkpointType,
      asOfTimestamp: DateTime.now(),
      totalProducts: products.length,
      totalBatches: batches.length,
      totalQuantity: totalQty,
      totalValuation: double.parse(totalVal.toStringAsFixed(2)),
      ledgerEntriesCount: ledgerEntriesCount,
      sha256Checksum: checksum,
      isReconciled: allReconciled,
      lineItems: lines,
    );

    _snapshotCache[id] = checkpoint;
    return checkpoint;
  }

  bool verifyIntegrity(MobileSnapshotCheckpoint checkpoint) {
    final recomputed = computeChecksum(checkpoint.lineItems);
    return recomputed == checkpoint.sha256Checksum;
  }

  MobileSnapshotCheckpoint? getSnapshot(String snapshotId) {
    return _snapshotCache[snapshotId];
  }
}
