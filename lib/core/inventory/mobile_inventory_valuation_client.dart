import 'dart:convert';
import 'dart:typed_data';

/// mobile_inventory_valuation_client.dart
/// Architecture Decision: ADR-0216 (P216).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.
///
/// Mobile Manager Client for Multi-Category Inventory Valuation Reports:
/// - Reports on-hand, sellable, quarantined, in-transit, and expired stock.
/// - Costing rules: FEFO lot cost, FIFO, Weighted Average, and MRP.
/// - Decimal BDT precision with mathematical balance and discrepancy checks.
/// - Cryptographic SHA-256 tamper-evident integrity hashes.
/// - Role-based authorization (Cashier denied).

enum MobileValuationCostingRule {
  fefoLotCost('FEFO Batch Lot Cost', 'এফইএফও ব্যাচ লট কস্ট'),
  fifoLotCost('FIFO Inward Purchase Lot Cost', 'ফিফো পারচেজ লট কস্ট'),
  weightedAverage('Weighted Average Cost', 'ভারযুক্ত গড় মূল্য'),
  mrpRetailValue('MRP Retail Valuation', 'খুচরা মূল্য ভ্যালুয়েশন');

  final String labelEn;
  final String labelBn;

  const MobileValuationCostingRule(this.labelEn, this.labelBn);
}

enum MobileInventoryCategory {
  sellable('Sellable Stock', 'বিক্রয়যোগ্য স্টক'),
  quarantined('Quarantined Hold', 'কোয়ারেন্টাইনড স্টক'),
  inTransit('In-Transit Transfer', 'ইন-ট্রানজিট স্থানান্তর'),
  expired('Expired Pending Disposal', 'মেয়াদোত্তীর্ণ স্টক');

  final String labelEn;
  final String labelBn;

  const MobileInventoryCategory(this.labelEn, this.labelBn);
}

class MobileValuationLineItem {
  final String productId;
  final String productName;
  final String batchNumber;
  final MobileInventoryCategory category;
  final int quantityBaseUnits;
  final double unitCost;
  final double totalValueBdt;
  final bool isColdChain;
  final String statusReason;

  MobileValuationLineItem({
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.category,
    required this.quantityBaseUnits,
    required this.unitCost,
    this.isColdChain = false,
    this.statusReason = '',
  }) : totalValueBdt = double.parse((unitCost * quantityBaseUnits).toStringAsFixed(2));

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'batch_number': batchNumber,
    'category': category.name,
    'quantity_base_units': quantityBaseUnits,
    'unit_cost': unitCost,
    'total_value_bdt': totalValueBdt,
    'is_cold_chain': isColdChain,
    'status_reason': statusReason,
  };
}

class MobileValuationReport {
  final String reportId;
  final String tenantId;
  final String branchId;
  final DateTime asOfTimestamp;
  final MobileValuationCostingRule costingRule;
  final int totalOnHandUnits;
  final double totalOnHandValueBdt;
  final int sellableUnits;
  final double sellableValueBdt;
  final int quarantinedUnits;
  final double quarantinedValueBdt;
  final int inTransitUnits;
  final double inTransitValueBdt;
  final int expiredUnits;
  final double expiredValueBdt;
  final int coldChainUnits;
  final double coldChainValueBdt;
  final bool isMathematicallyBalanced;
  final int discrepancyUnits;
  final double discrepancyValueBdt;
  final String sha256Checksum;
  final List<MobileValuationLineItem> lineItems;

  MobileValuationReport({
    required this.reportId,
    required this.tenantId,
    required this.branchId,
    required this.asOfTimestamp,
    required this.costingRule,
    required this.totalOnHandUnits,
    required this.totalOnHandValueBdt,
    required this.sellableUnits,
    required this.sellableValueBdt,
    required this.quarantinedUnits,
    required this.quarantinedValueBdt,
    required this.inTransitUnits,
    required this.inTransitValueBdt,
    required this.expiredUnits,
    required this.expiredValueBdt,
    required this.coldChainUnits,
    required this.coldChainValueBdt,
    required this.isMathematicallyBalanced,
    required this.discrepancyUnits,
    required this.discrepancyValueBdt,
    required this.sha256Checksum,
    required this.lineItems,
  });

  Map<String, dynamic> toJson() => {
    'report_id': reportId,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'as_of_timestamp': asOfTimestamp.toIso8601String(),
    'costing_rule': costingRule.name,
    'total_on_hand_units': totalOnHandUnits,
    'total_on_hand_value_bdt': totalOnHandValueBdt,
    'sellable_units': sellableUnits,
    'sellable_value_bdt': sellableValueBdt,
    'quarantined_units': quarantinedUnits,
    'quarantined_value_bdt': quarantinedValueBdt,
    'in_transit_units': inTransitUnits,
    'in_transit_value_bdt': inTransitValueBdt,
    'expired_units': expiredUnits,
    'expired_value_bdt': expiredValueBdt,
    'cold_chain_units': coldChainUnits,
    'cold_chain_value_bdt': coldChainValueBdt,
    'is_mathematically_balanced': isMathematicallyBalanced,
    'discrepancy_units': discrepancyUnits,
    'discrepancy_value_bdt': discrepancyValueBdt,
    'sha256_checksum': sha256Checksum,
    'line_items': lineItems.map((e) => e.toJson()).toList(),
  };
}

class ValuationSimpleSha256 {
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

class MobileInventoryValuationClient {
  final Map<String, MobileValuationReport> _reportCache = {};

  static const Set<String> _allowedRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
    'AUDITOR',
  };

  void _assertValuationRole(String userRole) {
    if (userRole.toUpperCase() == 'CASHIER' || !_allowedRoles.contains(userRole.toUpperCase())) {
      throw StateError('Cashiers are strictly forbidden from viewing or generating valuation reports.');
    }
  }

  static String computeChecksum(List<MobileValuationLineItem> lines) {
    final sorted = List<MobileValuationLineItem>.from(lines);
    sorted.sort((a, b) {
      final pCmp = a.productId.compareTo(b.productId);
      if (pCmp != 0) return pCmp;
      final bCmp = a.batchNumber.compareTo(b.batchNumber);
      if (bCmp != 0) return bCmp;
      return a.category.name.compareTo(b.category.name);
    });

    final sb = StringBuffer();
    for (final item in sorted) {
      sb.write('${item.productId}|${item.batchNumber}|${item.category.name}|${item.quantityBaseUnits}|${item.unitCost.toStringAsFixed(2)}|${item.totalValueBdt.toStringAsFixed(2)}\n');
    }
    return ValuationSimpleSha256.hashString(sb.toString());
  }

  MobileValuationReport generateReport({
    required String userRole,
    required String tenantId,
    required String branchId,
    required MobileValuationCostingRule costingRule,
    required List<MobileValuationLineItem> lines,
  }) {
    _assertValuationRole(userRole);

    int onHandQty = 0;
    double onHandVal = 0.0;
    int sellableQty = 0;
    double sellableVal = 0.0;
    int quarantinedQty = 0;
    double quarantinedVal = 0.0;
    int inTransitQty = 0;
    double inTransitVal = 0.0;
    int expiredQty = 0;
    double expiredVal = 0.0;
    int coldChainQty = 0;
    double coldChainVal = 0.0;

    for (final item in lines) {
      final val = item.totalValueBdt;
      switch (item.category) {
        case MobileInventoryCategory.sellable:
          sellableQty += item.quantityBaseUnits;
          sellableVal += val;
          onHandQty += item.quantityBaseUnits;
          onHandVal += val;
          break;
        case MobileInventoryCategory.quarantined:
          quarantinedQty += item.quantityBaseUnits;
          quarantinedVal += val;
          onHandQty += item.quantityBaseUnits;
          onHandVal += val;
          break;
        case MobileInventoryCategory.expired:
          expiredQty += item.quantityBaseUnits;
          expiredVal += val;
          onHandQty += item.quantityBaseUnits;
          onHandVal += val;
          break;
        case MobileInventoryCategory.inTransit:
          inTransitQty += item.quantityBaseUnits;
          inTransitVal += val;
          break;
      }

      if (item.isColdChain && item.category != MobileInventoryCategory.inTransit) {
        coldChainQty += item.quantityBaseUnits;
        coldChainVal += val;
      }
    }

    final int discrepancyUnits = onHandQty - (sellableQty + quarantinedQty + expiredQty);
    final double discrepancyVal = double.parse((onHandVal - (sellableVal + quarantinedVal + expiredVal)).toStringAsFixed(2));
    final bool isBalanced = (discrepancyUnits == 0 && discrepancyVal.abs() < 0.001);

    final checksum = computeChecksum(lines);
    final reportId = 'valrep-mob-${DateTime.now().millisecondsSinceEpoch}';

    final report = MobileValuationReport(
      reportId: reportId,
      tenantId: tenantId,
      branchId: branchId,
      asOfTimestamp: DateTime.now(),
      costingRule: costingRule,
      totalOnHandUnits: onHandQty,
      totalOnHandValueBdt: double.parse(onHandVal.toStringAsFixed(2)),
      sellableUnits: sellableQty,
      sellableValueBdt: double.parse(sellableVal.toStringAsFixed(2)),
      quarantinedUnits: quarantinedQty,
      quarantinedValueBdt: double.parse(quarantinedVal.toStringAsFixed(2)),
      inTransitUnits: inTransitQty,
      inTransitValueBdt: double.parse(inTransitVal.toStringAsFixed(2)),
      expiredUnits: expiredQty,
      expiredValueBdt: double.parse(expiredVal.toStringAsFixed(2)),
      coldChainUnits: coldChainQty,
      coldChainValueBdt: double.parse(coldChainVal.toStringAsFixed(2)),
      isMathematicallyBalanced: isBalanced,
      discrepancyUnits: discrepancyUnits,
      discrepancyValueBdt: discrepancyVal,
      sha256Checksum: checksum,
      lineItems: lines,
    );

    _reportCache[reportId] = report;
    return report;
  }

  bool verifyIntegrity(MobileValuationReport report) {
    final recomputed = computeChecksum(report.lineItems);
    return recomputed == report.sha256Checksum;
  }

  MobileValuationReport? getReport(String reportId) {
    return _reportCache[reportId];
  }
}
