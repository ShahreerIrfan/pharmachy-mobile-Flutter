// mobile_vendor_price_list_client.dart
// Architecture Decision: ADR-0183 (P183).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing supplier product price lists, SKU quotations,
// trade discounts, MOQ requirements, DGDA price-ceiling guard, and best-price PO allocation.

class MobileVendorProductPriceList {
  final String priceEntryId;
  final String tenantId;
  final String supplierId;
  final String supplierName;
  final String productId;
  final String productName;
  final String supplierSkuCode;
  final String packageType;
  final int packageSize;
  final double unitCostPrice;
  final double packageCostPrice;
  final double mrpUnit;
  final double discountPercentage;
  final double netUnitCost;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final int minimumOrderQuantity;
  final int freeGoodsThreshold;
  final int freeGoodsBonusQuantity;
  final bool isContracted;
  bool isActive;
  final String notes;
  final DateTime createdAt;

  MobileVendorProductPriceList({
    required this.priceEntryId,
    required this.tenantId,
    required this.supplierId,
    this.supplierName = '',
    required this.productId,
    this.productName = '',
    this.supplierSkuCode = '',
    this.packageType = 'BOX',
    this.packageSize = 1,
    required this.unitCostPrice,
    required this.packageCostPrice,
    this.mrpUnit = 0.0,
    this.discountPercentage = 0.0,
    required this.netUnitCost,
    required this.effectiveFrom,
    this.effectiveTo,
    this.minimumOrderQuantity = 1,
    this.freeGoodsThreshold = 0,
    this.freeGoodsBonusQuantity = 0,
    this.isContracted = false,
    this.isActive = true,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'price_entry_id': priceEntryId,
        'tenant_id': tenantId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'product_id': productId,
        'product_name': productName,
        'supplier_sku_code': supplierSkuCode,
        'package_type': packageType,
        'package_size': packageSize,
        'unit_cost_price': unitCostPrice.toStringAsFixed(4),
        'package_cost_price': packageCostPrice.toStringAsFixed(4),
        'mrp_unit': mrpUnit.toStringAsFixed(4),
        'discount_percentage': discountPercentage.toStringAsFixed(2),
        'net_unit_cost': netUnitCost.toStringAsFixed(4),
        'effective_from': effectiveFrom.toIso8601String().substring(0, 10),
        'effective_to': effectiveTo?.toIso8601String().substring(0, 10),
        'minimum_order_quantity': minimumOrderQuantity,
        'free_goods_threshold': freeGoodsThreshold,
        'free_goods_bonus_quantity': freeGoodsBonusQuantity,
        'is_contracted': isContracted,
        'is_active': isActive,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

class MobileBestPriceOffer {
  final String selectedPriceEntryId;
  final String supplierId;
  final String supplierName;
  final String productId;
  final String productName;
  final int demandedQuantity;
  final double unitCostPrice;
  final double discountPercentage;
  final double netUnitCost;
  final double totalNetCost;
  final int freeGoodsBonusUnits;
  final bool moqSatisfied;

  const MobileBestPriceOffer({
    required this.selectedPriceEntryId,
    required this.supplierId,
    required this.supplierName,
    required this.productId,
    required this.productName,
    required this.demandedQuantity,
    required this.unitCostPrice,
    required this.discountPercentage,
    required this.netUnitCost,
    required this.totalNetCost,
    required this.freeGoodsBonusUnits,
    required this.moqSatisfied,
  });

  Map<String, dynamic> toJson() => {
        'selected_price_entry_id': selectedPriceEntryId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'product_id': productId,
        'product_name': productName,
        'demanded_quantity': demandedQuantity,
        'unit_cost_price': unitCostPrice.toStringAsFixed(4),
        'discount_percentage': discountPercentage.toStringAsFixed(2),
        'net_unit_cost': netUnitCost.toStringAsFixed(4),
        'total_net_cost': totalNetCost.toStringAsFixed(4),
        'free_goods_bonus_units': freeGoodsBonusUnits,
        'moq_satisfied': moqSatisfied,
      };
}

class MobileVendorPriceListClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileVendorProductPriceList> _priceEntryStore;

  static const Set<String> _allowedProcurementRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'AUDITOR',
  };

  MobileVendorPriceListClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileVendorProductPriceList>? initialStore,
  }) : _priceEntryStore = initialStore ?? {};

  void _assertProcurementRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedProcurementRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Cashiers cannot manage vendor price lists.');
    }
  }

  MobileVendorProductPriceList createPriceEntry({
    required String supplierId,
    String supplierName = '',
    required String productId,
    String productName = '',
    String supplierSkuCode = '',
    String packageType = 'BOX',
    int packageSize = 1,
    required double unitCostPrice,
    double mrpUnit = 0.0,
    double discountPercentage = 0.0,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    int minimumOrderQuantity = 1,
    int freeGoodsThreshold = 0,
    int freeGoodsBonusQuantity = 0,
    bool isContracted = false,
    String notes = '',
  }) {
    _assertProcurementRole();

    if (supplierId.trim().isEmpty) {
      throw ArgumentError('ERR_MISSING_SUPPLIER_ID: Supplier ID cannot be empty');
    }
    if (productId.trim().isEmpty) {
      throw ArgumentError('ERR_MISSING_PRODUCT_ID: Product ID cannot be empty');
    }
    if (unitCostPrice <= 0.0) {
      throw ArgumentError('ERR_INVALID_COST_PRICE: Unit cost price must be positive');
    }
    if (mrpUnit > 0.0 && unitCostPrice > mrpUnit) {
      throw ArgumentError(
          'ERR_COST_EXCEEDS_MRP: Unit cost price ($unitCostPrice) cannot exceed MRP ($mrpUnit)');
    }
    if (discountPercentage < 0.0 || discountPercentage > 100.0) {
      throw ArgumentError(
          'ERR_INVALID_DISCOUNT_PERCENTAGE: Discount must be between 0% and 100%');
    }
    if (minimumOrderQuantity < 1) {
      throw ArgumentError('ERR_INVALID_MOQ: Minimum order quantity must be at least 1');
    }

    final fromDate = effectiveFrom ?? DateTime.now();
    if (effectiveTo != null && effectiveTo.isBefore(fromDate)) {
      throw ArgumentError(
          'ERR_INVALID_DATE_RANGE: Effective to date cannot precede effective from date');
    }

    final sanitizedSize = packageSize < 1 ? 1 : packageSize;
    final packageCost = double.parse((unitCostPrice * sanitizedSize).toStringAsFixed(4));
    final netUnitCost = double.parse(
        (unitCostPrice * (1.0 - (discountPercentage / 100.0))).toStringAsFixed(4));

    final priceEntryId =
        'vpl-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}_${_priceEntryStore.length}';
    final entry = MobileVendorProductPriceList(
      priceEntryId: priceEntryId,
      tenantId: tenantId,
      supplierId: supplierId.trim(),
      supplierName: supplierName.trim(),
      productId: productId.trim(),
      productName: productName.trim(),
      supplierSkuCode: supplierSkuCode.trim(),
      packageType: packageType.trim(),
      packageSize: sanitizedSize,
      unitCostPrice: double.parse(unitCostPrice.toStringAsFixed(4)),
      packageCostPrice: packageCost,
      mrpUnit: double.parse(mrpUnit.toStringAsFixed(4)),
      discountPercentage: double.parse(discountPercentage.toStringAsFixed(2)),
      netUnitCost: netUnitCost,
      effectiveFrom: fromDate,
      effectiveTo: effectiveTo,
      minimumOrderQuantity: minimumOrderQuantity,
      freeGoodsThreshold: freeGoodsThreshold < 0 ? 0 : freeGoodsThreshold,
      freeGoodsBonusQuantity:
          freeGoodsBonusQuantity < 0 ? 0 : freeGoodsBonusQuantity,
      isContracted: isContracted,
      isActive: true,
      notes: notes.trim(),
      createdAt: DateTime.now(),
    );

    _priceEntryStore[priceEntryId] = entry;
    return entry;
  }

  MobileVendorProductPriceList updatePriceEntry({
    required String priceEntryId,
    double? newUnitCostPrice,
    double? newDiscountPercentage,
    int? newMoq,
    DateTime? newEffectiveTo,
    bool? newIsActive,
  }) {
    _assertProcurementRole();

    final existing = _priceEntryStore[priceEntryId];
    if (existing == null) {
      throw ArgumentError('ERR_PRICE_ENTRY_NOT_FOUND: Price entry $priceEntryId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant price entry update forbidden');
    }

    var unitCost = existing.unitCostPrice;
    if (newUnitCostPrice != null) {
      if (newUnitCostPrice <= 0.0) {
        throw ArgumentError('ERR_INVALID_COST_PRICE: Unit cost price must be positive');
      }
      if (existing.mrpUnit > 0.0 && newUnitCostPrice > existing.mrpUnit) {
        throw ArgumentError('ERR_COST_EXCEEDS_MRP: Unit cost price cannot exceed MRP');
      }
      unitCost = double.parse(newUnitCostPrice.toStringAsFixed(4));
    }

    var discount = existing.discountPercentage;
    if (newDiscountPercentage != null) {
      if (newDiscountPercentage < 0.0 || newDiscountPercentage > 100.0) {
        throw ArgumentError('ERR_INVALID_DISCOUNT_PERCENTAGE: Discount must be 0-100%');
      }
      discount = double.parse(newDiscountPercentage.toStringAsFixed(2));
    }

    var moq = existing.minimumOrderQuantity;
    if (newMoq != null) {
      if (newMoq < 1) {
        throw ArgumentError('ERR_INVALID_MOQ: MOQ must be at least 1');
      }
      moq = newMoq;
    }

    var effTo = existing.effectiveTo;
    if (newEffectiveTo != null) {
      if (newEffectiveTo.isBefore(existing.effectiveFrom)) {
        throw ArgumentError('ERR_INVALID_DATE_RANGE: Effective to precedes effective from');
      }
      effTo = newEffectiveTo;
    }

    final active = newIsActive ?? existing.isActive;
    final packageCost = double.parse((unitCost * existing.packageSize).toStringAsFixed(4));
    final netCost = double.parse((unitCost * (1.0 - (discount / 100.0))).toStringAsFixed(4));

    final updated = MobileVendorProductPriceList(
      priceEntryId: existing.priceEntryId,
      tenantId: existing.tenantId,
      supplierId: existing.supplierId,
      supplierName: existing.supplierName,
      productId: existing.productId,
      productName: existing.productName,
      supplierSkuCode: existing.supplierSkuCode,
      packageType: existing.packageType,
      packageSize: existing.packageSize,
      unitCostPrice: unitCost,
      packageCostPrice: packageCost,
      mrpUnit: existing.mrpUnit,
      discountPercentage: discount,
      netUnitCost: netCost,
      effectiveFrom: existing.effectiveFrom,
      effectiveTo: effTo,
      minimumOrderQuantity: moq,
      freeGoodsThreshold: existing.freeGoodsThreshold,
      freeGoodsBonusQuantity: existing.freeGoodsBonusQuantity,
      isContracted: existing.isContracted,
      isActive: active,
      notes: existing.notes,
      createdAt: existing.createdAt,
    );

    _priceEntryStore[priceEntryId] = updated;
    return updated;
  }

  MobileVendorProductPriceList archivePriceEntry(String priceEntryId) {
    _assertProcurementRole();
    final existing = _priceEntryStore[priceEntryId];
    if (existing == null) {
      throw ArgumentError('ERR_PRICE_ENTRY_NOT_FOUND: Price entry $priceEntryId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant price entry archival forbidden');
    }

    return updatePriceEntry(priceEntryId: priceEntryId, newIsActive: false);
  }

  MobileVendorProductPriceList getPriceEntry(String priceEntryId) {
    final existing = _priceEntryStore[priceEntryId];
    if (existing == null) {
      throw ArgumentError('ERR_PRICE_ENTRY_NOT_FOUND: Price entry $priceEntryId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant price entry access forbidden');
    }
    return existing;
  }

  List<MobileVendorProductPriceList> listPriceEntries({
    String? supplierId,
    String? productId,
    DateTime? activeOnDate,
    bool? isActive,
  }) {
    final list = _priceEntryStore.values.where((e) {
      if (e.tenantId != tenantId) return false;
      if (supplierId != null && e.supplierId != supplierId) return false;
      if (productId != null && e.productId != productId) return false;
      if (isActive != null && e.isActive != isActive) return false;
      if (activeOnDate != null) {
        if (e.effectiveFrom.isAfter(activeOnDate)) return false;
        if (e.effectiveTo != null && e.effectiveTo!.isBefore(activeOnDate)) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return list;
  }

  MobileBestPriceOffer? resolveBestPrice({
    required String productId,
    required int demandedQuantity,
    DateTime? targetDate,
  }) {
    if (productId.trim().isEmpty) {
      throw ArgumentError('ERR_MISSING_PRODUCT_ID: Product ID cannot be empty');
    }
    if (demandedQuantity <= 0) {
      throw ArgumentError('ERR_INVALID_QUANTITY: Demanded quantity must be greater than zero');
    }

    final date = targetDate ?? DateTime.now();
    final candidates = _priceEntryStore.values.where((e) {
      if (e.tenantId != tenantId || e.productId != productId || !e.isActive) {
        return false;
      }
      if (e.effectiveFrom.isAfter(date)) return false;
      if (e.effectiveTo != null && e.effectiveTo!.isBefore(date)) return false;
      if (demandedQuantity < e.minimumOrderQuantity) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final cmp = a.netUnitCost.compareTo(b.netUnitCost);
      if (cmp != 0) return cmp;
      return b.discountPercentage.compareTo(a.discountPercentage);
    });

    final best = candidates.first;
    final totalNetCost = double.parse((best.netUnitCost * demandedQuantity).toStringAsFixed(4));

    int bonusUnits = 0;
    if (best.freeGoodsThreshold > 0 && best.freeGoodsBonusQuantity > 0) {
      final tiers = demandedQuantity ~/ best.freeGoodsThreshold;
      bonusUnits = tiers * best.freeGoodsBonusQuantity;
    }

    return MobileBestPriceOffer(
      selectedPriceEntryId: best.priceEntryId,
      supplierId: best.supplierId,
      supplierName: best.supplierName,
      productId: best.productId,
      productName: best.productName,
      demandedQuantity: demandedQuantity,
      unitCostPrice: best.unitCostPrice,
      discountPercentage: best.discountPercentage,
      netUnitCost: best.netUnitCost,
      totalNetCost: totalNetCost,
      freeGoodsBonusUnits: bonusUnits,
      moqSatisfied: true,
    );
  }
}
