/// mobile_stock_inquiry_client.dart
/// Architecture Decision: ADR-0203 (P203).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.
///
/// Mobile owner/manager client for multi-tenant branch stock inquiries.
/// Calculates on-hand, available, reserved, quarantined, and expired stock.

enum MobileExpiryCategory {
  active('Active Commercial Stock', 'সক্রিয় স্টক'),
  nearExpiry('Near Expiry (<90 Days)', 'আসন্ন মেয়াদোত্তীর্ণ (<৯০ দিন)'),
  criticalNearExpiry('Critical (<30 Days)', 'জরুরি মেয়াদোত্তীর্ণ (<৩০ দিন)'),
  expired('Expired Stock (Non-Sellable)', 'মেয়াদোত্তীর্ণ (অ-বিক্রয়যোগ্য)'),
  quarantined('Quarantined Stock', 'কোয়ারেন্টাইন স্টক'),
  recalled('DGDA Recalled Stock', 'প্রত্যাহারকৃত স্টক');

  final String labelEn;
  final String labelBn;

  const MobileExpiryCategory(this.labelEn, this.labelBn);
}

class MobileBatchInquiryItem {
  final String batchId;
  final String batchNumber;
  final DateTime expiryDate;
  final int daysUntilExpiry;
  final MobileExpiryCategory expiryStatus;
  final int quantityBaseUnits;
  final int reservedQuantityBaseUnits;
  final int availableQuantityBaseUnits;
  final String storageLocation;
  final double costPerUnit;
  final double mrpUnit;

  const MobileBatchInquiryItem({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.daysUntilExpiry,
    required this.expiryStatus,
    required this.quantityBaseUnits,
    required this.reservedQuantityBaseUnits,
    required this.availableQuantityBaseUnits,
    required this.storageLocation,
    required this.costPerUnit,
    required this.mrpUnit,
  });

  Map<String, dynamic> toJson() => {
        'batch_id': batchId,
        'batch_number': batchNumber,
        'expiry_date': expiryDate.toIso8601String().split('T').first,
        'days_until_expiry': daysUntilExpiry,
        'expiry_status': expiryStatus.name,
        'quantity_base_units': quantityBaseUnits,
        'reserved_quantity_base_units': reservedQuantityBaseUnits,
        'available_quantity_base_units': availableQuantityBaseUnits,
        'storage_location': storageLocation,
        'cost_per_unit': costPerUnit,
        'mrp_unit': mrpUnit,
      };
}

class MobilePackagingSummary {
  final int boxes;
  final int strips;
  final int pieces;
  final int totalBaseUnits;
  final String formattedText;

  const MobilePackagingSummary({
    required this.boxes,
    required this.strips,
    required this.pieces,
    required this.totalBaseUnits,
    required this.formattedText,
  });

  Map<String, dynamic> toJson() => {
        'boxes': boxes,
        'strips': strips,
        'pieces': pieces,
        'total_base_units': totalBaseUnits,
        'formatted_text': formattedText,
      };
}

class MobileProductStockInquiry {
  final String productId;
  final String brandName;
  final String brandNameBn;
  final String genericName;
  final String dosageForm;
  int totalQuantityBaseUnits;
  int availableQuantityBaseUnits;
  int reservedQuantityBaseUnits;
  int expiredQuantityBaseUnits;
  int quarantinedQuantityBaseUnits;
  int nearExpiryQuantityBaseUnits;
  double totalCostValuationBdt;
  double totalMrpValuationBdt;
  MobilePackagingSummary packagingSummary;
  final List<MobileBatchInquiryItem> batches;

  MobileProductStockInquiry({
    required this.productId,
    required this.brandName,
    required this.brandNameBn,
    required this.genericName,
    required this.dosageForm,
    this.totalQuantityBaseUnits = 0,
    this.availableQuantityBaseUnits = 0,
    this.reservedQuantityBaseUnits = 0,
    this.expiredQuantityBaseUnits = 0,
    this.quarantinedQuantityBaseUnits = 0,
    this.nearExpiryQuantityBaseUnits = 0,
    this.totalCostValuationBdt = 0.0,
    this.totalMrpValuationBdt = 0.0,
    this.packagingSummary = const MobilePackagingSummary(
      boxes: 0,
      strips: 0,
      pieces: 0,
      totalBaseUnits: 0,
      formattedText: '',
    ),
    List<MobileBatchInquiryItem>? batches,
  }) : batches = batches ?? [];

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'brand_name': brandName,
        'brand_name_bn': brandNameBn,
        'generic_name': genericName,
        'dosage_form': dosageForm,
        'total_quantity_base_units': totalQuantityBaseUnits,
        'available_quantity_base_units': availableQuantityBaseUnits,
        'reserved_quantity_base_units': reservedQuantityBaseUnits,
        'expired_quantity_base_units': expiredQuantityBaseUnits,
        'quarantined_quantity_base_units': quarantinedQuantityBaseUnits,
        'near_expiry_quantity_base_units': nearExpiryQuantityBaseUnits,
        'total_cost_valuation_bdt': totalCostValuationBdt,
        'total_mrp_valuation_bdt': totalMrpValuationBdt,
        'packaging_summary': packagingSummary.toJson(),
        'batches': batches.map((b) => b.toJson()).toList(),
      };
}

class MobileStockInquiryResult {
  final String tenantId;
  final String branchId;
  final int productsCount;
  final int totalAvailableUnits;
  final List<MobileProductStockInquiry> results;

  const MobileStockInquiryResult({
    required this.tenantId,
    required this.branchId,
    required this.productsCount,
    required this.totalAvailableUnits,
    required this.results,
  });
}

class MobileMockBatchRecord {
  final String batchId;
  final String tenantId;
  final String branchId;
  final String productId;
  final String brandName;
  final String brandNameBn;
  final String genericName;
  final String dosageForm;
  final String batchNumber;
  final int quantity;
  final int reserved;
  final DateTime expiryDate;
  final bool isQuarantined;
  final bool isRecalled;
  final double costPerUnit;
  final double mrpUnit;
  final String storageLocation;

  const MobileMockBatchRecord({
    required this.batchId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    required this.brandName,
    required this.brandNameBn,
    required this.genericName,
    required this.dosageForm,
    required this.batchNumber,
    required this.quantity,
    required this.reserved,
    required this.expiryDate,
    required this.isQuarantined,
    required this.isRecalled,
    required this.costPerUnit,
    required this.mrpUnit,
    required this.storageLocation,
  });
}

class MobileStockInquiryClient {
  final List<MobileMockBatchRecord> database = [];

  void addBatch(MobileMockBatchRecord batch) {
    database.add(batch);
  }

  MobileStockInquiryResult queryStock({
    required String tenantId,
    required String branchId,
    String? search,
    String? productId,
    String expiryStatus = 'ALL',
    required String userRole,
    String? userBranchId,
  }) {
    if (userRole.toUpperCase() == 'CASHIER') {
      if (userBranchId != null && userBranchId != branchId) {
        throw StateError('ERR_BRANCH_ACCESS_DENIED: Cashiers cannot query stock outside assigned branch.');
      }
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final Map<String, MobileProductStockInquiry> productMap = {};
    int runAvailableTotal = 0;

    for (final b in database) {
      if (b.tenantId != tenantId || b.branchId != branchId) {
        continue;
      }
      if (productId != null && b.productId != productId) {
        continue;
      }
      if (search != null && search.trim().isNotEmpty) {
        final s = search.trim().toLowerCase();
        final matches = b.brandName.toLowerCase().contains(s) ||
            b.brandNameBn.toLowerCase().contains(s) ||
            b.genericName.toLowerCase().contains(s) ||
            b.batchNumber.toLowerCase().contains(s);
        if (!matches) {
          continue;
        }
      }

      final bDate = DateTime(b.expiryDate.year, b.expiryDate.month, b.expiryDate.day);
      final daysLeft = bDate.difference(todayDate).inDays;

      MobileExpiryCategory cat;
      if (b.isRecalled) {
        cat = MobileExpiryCategory.recalled;
      } else if (b.isQuarantined) {
        cat = MobileExpiryCategory.quarantined;
      } else if (daysLeft <= 0) {
        cat = MobileExpiryCategory.expired;
      } else if (daysLeft <= 30) {
        cat = MobileExpiryCategory.criticalNearExpiry;
      } else if (daysLeft <= 90) {
        cat = MobileExpiryCategory.nearExpiry;
      } else {
        cat = MobileExpiryCategory.active;
      }

      if (expiryStatus != 'ALL') {
        if (expiryStatus == 'EXPIRED' && cat != MobileExpiryCategory.expired) {
          continue;
        }
        if (expiryStatus == 'NEAR_EXPIRY' &&
            cat != MobileExpiryCategory.nearExpiry &&
            cat != MobileExpiryCategory.criticalNearExpiry) {
          continue;
        }
      }

      final available = (cat == MobileExpiryCategory.expired ||
              cat == MobileExpiryCategory.quarantined ||
              cat == MobileExpiryCategory.recalled)
          ? 0
          : (b.quantity - b.reserved > 0 ? b.quantity - b.reserved : 0);

      runAvailableTotal += available;

      final prod = productMap.putIfAbsent(
        b.productId,
        () => MobileProductStockInquiry(
          productId: b.productId,
          brandName: b.brandName,
          brandNameBn: b.brandNameBn,
          genericName: b.genericName,
          dosageForm: b.dosageForm,
        ),
      );

      prod.totalQuantityBaseUnits += b.quantity;
      prod.availableQuantityBaseUnits += available;
      prod.reservedQuantityBaseUnits += b.reserved;

      if (cat == MobileExpiryCategory.expired) {
        prod.expiredQuantityBaseUnits += b.quantity;
      } else if (cat == MobileExpiryCategory.quarantined || cat == MobileExpiryCategory.recalled) {
        prod.quarantinedQuantityBaseUnits += b.quantity;
      } else if (cat == MobileExpiryCategory.nearExpiry || cat == MobileExpiryCategory.criticalNearExpiry) {
        prod.nearExpiryQuantityBaseUnits += b.quantity;
      }

      prod.totalCostValuationBdt += (b.costPerUnit * b.quantity);
      prod.totalMrpValuationBdt += (b.mrpUnit * b.quantity);

      prod.batches.add(MobileBatchInquiryItem(
        batchId: b.batchId,
        batchNumber: b.batchNumber,
        expiryDate: b.expiryDate,
        daysUntilExpiry: daysLeft,
        expiryStatus: cat,
        quantityBaseUnits: b.quantity,
        reservedQuantityBaseUnits: b.reserved,
        availableQuantityBaseUnits: available,
        storageLocation: b.storageLocation,
        costPerUnit: b.costPerUnit,
        mrpUnit: b.mrpUnit,
      ));
    }

    for (final prod in productMap.values) {
      prod.batches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      final units = prod.availableQuantityBaseUnits;
      final boxes = units ~/ 100;
      final rem = units % 100;
      final strips = rem ~/ 10;
      final pieces = rem % 10;
      final text = '$boxes Boxes, $strips Strips, $pieces Pieces (Total: $units)';
      prod.packagingSummary = MobilePackagingSummary(
        boxes: boxes,
        strips: strips,
        pieces: pieces,
        totalBaseUnits: units,
        formattedText: text,
      );
    }

    return MobileStockInquiryResult(
      tenantId: tenantId,
      branchId: branchId,
      productsCount: productMap.length,
      totalAvailableUnits: runAvailableTotal,
      results: productMap.values.toList(),
    );
  }
}
