// mobile_goods_receipt_client.dart
// Architecture Decision: ADR-0187 (P187).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing Goods Receipt Notes (GRN), PO line matching,
// cold-chain temperature verification, idempotent stock posting, and reversal safety.

import 'mobile_purchase_order_client.dart';

class MobileGoodsReceiptLine {
  final String lineId;
  final String? poItemId;
  final String productId;
  final String productBrandName;
  final String batchNumber;
  final DateTime expiryDate;
  final DateTime? mfgDate;
  final String packUnit;
  final int packageSize;
  final int receivedPackages;
  final int orderedQuantityBaseUnits;
  final int receivedQuantityBaseUnits;
  final double unitCost;
  final double mrpUnit;
  final double discountPercentage;
  final double taxPercentage;
  final double lineTotal;
  final String storageLocation;
  final bool isBonusGoods;
  final int excessQuantity;
  final String excessReason;
  bool isFullyAllocated;

  MobileGoodsReceiptLine({
    String? lineId,
    this.poItemId,
    required this.productId,
    this.productBrandName = '',
    required this.batchNumber,
    required this.expiryDate,
    this.mfgDate,
    this.packUnit = 'BOX',
    int packageSize = 1,
    int receivedPackages = 0,
    int orderedQuantityBaseUnits = 0,
    int? receivedQuantityBaseUnits,
    required double unitCost,
    this.mrpUnit = 0.0,
    double discountPercentage = 0.0,
    double taxPercentage = 0.0,
    double? lineTotal,
    this.storageLocation = 'MAIN_RACK',
    this.isBonusGoods = false,
    this.excessQuantity = 0,
    this.excessReason = '',
    this.isFullyAllocated = false,
  })  : lineId = lineId ??
            'grnl-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}',
        packageSize = packageSize < 1 ? 1 : packageSize,
        receivedPackages = receivedPackages < 0 ? 0 : receivedPackages,
        orderedQuantityBaseUnits =
            orderedQuantityBaseUnits < 0 ? 0 : orderedQuantityBaseUnits,
        receivedQuantityBaseUnits = (receivedQuantityBaseUnits != null &&
                receivedQuantityBaseUnits > 0)
            ? receivedQuantityBaseUnits
            : (receivedPackages > 0
                ? receivedPackages * (packageSize < 1 ? 1 : packageSize)
                : 1),
        unitCost = isBonusGoods ? 0.0 : unitCost,
        discountPercentage = isBonusGoods ? 0.0 : discountPercentage,
        taxPercentage = isBonusGoods ? 0.0 : taxPercentage,
        lineTotal = isBonusGoods
            ? 0.0
            : (lineTotal ??
                _calculateLineTotal(
                  receivedUnits: (receivedQuantityBaseUnits != null &&
                          receivedQuantityBaseUnits > 0)
                      ? receivedQuantityBaseUnits
                      : (receivedPackages > 0
                          ? receivedPackages * (packageSize < 1 ? 1 : packageSize)
                          : 1),
                  unitCost: unitCost,
                  discountPercentage: discountPercentage,
                  taxPercentage: taxPercentage,
                ));

  static double _calculateLineTotal({
    required int receivedUnits,
    required double unitCost,
    required double discountPercentage,
    required double taxPercentage,
  }) {
    final discountFactor = 1.0 - (discountPercentage / 100.0);
    final netCost = unitCost * discountFactor;
    final subtotal = netCost * receivedUnits;
    final taxAmount = subtotal * (taxPercentage / 100.0);
    return double.parse((subtotal + taxAmount).toStringAsFixed(4));
  }

  Map<String, dynamic> toJson() => {
        'line_id': lineId,
        'po_item_id': poItemId,
        'product_id': productId,
        'product_brand_name': productBrandName,
        'batch_number': batchNumber,
        'expiry_date': expiryDate.toIso8601String().substring(0, 10),
        'mfg_date': mfgDate?.toIso8601String().substring(0, 10),
        'pack_unit': packUnit,
        'package_size': packageSize,
        'received_packages': receivedPackages,
        'ordered_quantity_base_units': orderedQuantityBaseUnits,
        'received_quantity_base_units': receivedQuantityBaseUnits,
        'unit_cost': unitCost.toStringAsFixed(4),
        'mrp_unit': mrpUnit.toStringAsFixed(4),
        'discount_percentage': discountPercentage.toStringAsFixed(2),
        'tax_percentage': taxPercentage.toStringAsFixed(2),
        'line_total': lineTotal.toStringAsFixed(4),
        'storage_location': storageLocation,
        'is_bonus_goods': isBonusGoods,
        'excess_quantity': excessQuantity,
        'excess_reason': excessReason,
        'is_fully_allocated': isFullyAllocated,
      };

  factory MobileGoodsReceiptLine.fromJson(Map<String, dynamic> json) {
    return MobileGoodsReceiptLine(
      lineId: json['line_id']?.toString(),
      poItemId: json['po_item_id']?.toString(),
      productId: json['product_id']?.toString() ?? '',
      productBrandName: json['product_brand_name']?.toString() ?? '',
      batchNumber: json['batch_number']?.toString() ?? '',
      expiryDate: DateTime.parse(json['expiry_date']),
      mfgDate: json['mfg_date'] != null ? DateTime.parse(json['mfg_date']) : null,
      packUnit: json['pack_unit']?.toString() ?? 'BOX',
      packageSize: (json['package_size'] as num?)?.toInt() ?? 1,
      receivedPackages: (json['received_packages'] as num?)?.toInt() ?? 0,
      orderedQuantityBaseUnits:
          (json['ordered_quantity_base_units'] as num?)?.toInt() ?? 0,
      receivedQuantityBaseUnits:
          (json['received_quantity_base_units'] as num?)?.toInt(),
      unitCost: double.tryParse(json['unit_cost']?.toString() ?? '0') ?? 0.0,
      mrpUnit: double.tryParse(json['mrp_unit']?.toString() ?? '0') ?? 0.0,
      discountPercentage:
          double.tryParse(json['discount_percentage']?.toString() ?? '0') ?? 0.0,
      taxPercentage:
          double.tryParse(json['tax_percentage']?.toString() ?? '0') ?? 0.0,
      lineTotal:
          double.tryParse(json['line_total']?.toString() ?? '0') ?? 0.0,
      storageLocation: json['storage_location']?.toString() ?? 'MAIN_RACK',
      isBonusGoods: json['is_bonus_goods'] == true,
      excessQuantity: (json['excess_quantity'] as num?)?.toInt() ?? 0,
      excessReason: json['excess_reason']?.toString() ?? '',
      isFullyAllocated: json['is_fully_allocated'] == true,
    );
  }
}

class MobileGoodsReceipt {
  final String grnId;
  final String grnNumber;
  final String tenantId;
  final String branchId;
  final String? purchaseOrderId;
  final String purchaseOrderNumber;
  final String supplierId;
  final String supplierName;
  final String challanNumber;
  final DateTime? challanDate;
  final DateTime receiptDate;
  final String storageCondition;
  final double? storageTemperatureCelsius;
  final bool storageCheckPassed;
  final String proofOfOrigin;
  String status;
  final int totalReceivedBaseUnits;
  final double totalInvoiceAmount;
  String apPostingStatus;
  double apInvoiceAmount;
  String notes;
  bool isActive;
  final List<MobileGoodsReceiptLine> lines;
  final DateTime createdAt;

  MobileGoodsReceipt({
    required this.grnId,
    required this.grnNumber,
    required this.tenantId,
    required this.branchId,
    this.purchaseOrderId,
    this.purchaseOrderNumber = '',
    required this.supplierId,
    this.supplierName = '',
    this.challanNumber = '',
    this.challanDate,
    DateTime? receiptDate,
    this.storageCondition = 'ROOM_TEMPERATURE',
    this.storageTemperatureCelsius,
    this.storageCheckPassed = true,
    this.proofOfOrigin = '',
    this.status = 'RECEIVED',
    required this.totalReceivedBaseUnits,
    required this.totalInvoiceAmount,
    this.apPostingStatus = 'PENDING',
    this.apInvoiceAmount = 0.0,
    this.notes = '',
    this.isActive = true,
    required this.lines,
    DateTime? createdAt,
  })  : receiptDate = receiptDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'grn_id': grnId,
        'grn_number': grnNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'purchase_order_id': purchaseOrderId,
        'purchase_order_number': purchaseOrderNumber,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'challan_number': challanNumber,
        'challan_date': challanDate?.toIso8601String().substring(0, 10),
        'receipt_date': receiptDate.toIso8601String().substring(0, 10),
        'storage_condition': storageCondition,
        'storage_temperature_celsius': storageTemperatureCelsius,
        'storage_check_passed': storageCheckPassed,
        'proof_of_origin': proofOfOrigin,
        'status': status,
        'total_received_base_units': totalReceivedBaseUnits,
        'total_invoice_amount': totalInvoiceAmount.toStringAsFixed(4),
        'ap_posting_status': apPostingStatus,
        'ap_invoice_amount': apInvoiceAmount.toStringAsFixed(4),
        'notes': notes,
        'is_active': isActive,
        'lines': lines.map((l) => l.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  factory MobileGoodsReceipt.fromJson(Map<String, dynamic> json) {
    return MobileGoodsReceipt(
      grnId: json['grn_id']?.toString() ?? '',
      grnNumber: json['grn_number']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      purchaseOrderId: json['purchase_order_id']?.toString(),
      purchaseOrderNumber: json['purchase_order_number']?.toString() ?? '',
      supplierId: json['supplier_id']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString() ?? '',
      challanNumber: json['challan_number']?.toString() ?? '',
      challanDate: json['challan_date'] != null
          ? DateTime.parse(json['challan_date'])
          : null,
      receiptDate: json['receipt_date'] != null
          ? DateTime.parse(json['receipt_date'])
          : DateTime.now(),
      storageCondition: json['storage_condition']?.toString() ?? 'ROOM_TEMPERATURE',
      storageTemperatureCelsius:
          (json['storage_temperature_celsius'] as num?)?.toDouble(),
      storageCheckPassed: json['storage_check_passed'] == true,
      proofOfOrigin: json['proof_of_origin']?.toString() ?? '',
      status: json['status']?.toString() ?? 'RECEIVED',
      totalReceivedBaseUnits:
          (json['total_received_base_units'] as num?)?.toInt() ?? 0,
      totalInvoiceAmount:
          double.tryParse(json['total_invoice_amount']?.toString() ?? '0') ??
              0.0,
      apPostingStatus: json['ap_posting_status']?.toString() ?? 'PENDING',
      apInvoiceAmount:
          double.tryParse(json['ap_invoice_amount']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString() ?? '',
      isActive: json['is_active'] != false,
      lines: (json['lines'] as List<dynamic>?)
              ?.map((item) =>
                  MobileGoodsReceiptLine.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class MobileGoodsReceiptClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileGoodsReceipt> _grnStore;
  final MobilePurchaseOrderClient? poClient;

  static const Set<String> _allowedProcurementRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
  };

  MobileGoodsReceiptClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileGoodsReceipt>? initialStore,
    this.poClient,
  }) : _grnStore = initialStore ?? {};

  void _assertProcurementRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedProcurementRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Cashiers cannot create or post goods receipts.');
    }
  }

  MobileGoodsReceipt createGrn({
    String? purchaseOrderId,
    required String supplierId,
    String supplierName = '',
    String challanNumber = '',
    DateTime? challanDate,
    DateTime? receiptDate,
    String storageCondition = 'ROOM_TEMPERATURE',
    double? storageTemperatureCelsius,
    bool storageCheckPassed = true,
    String proofOfOrigin = '',
    String notes = '',
    bool allowExcess = false,
    String excessReason = '',
    required List<MobileGoodsReceiptLine> lines,
  }) {
    _assertProcurementRole();

    if (lines.isEmpty) {
      throw ArgumentError(
          'ERR_EMPTY_GRN: Goods receipt must contain at least one line item');
    }

    // Purchase Order Validation
    MobilePurchaseOrder? po;
    if (purchaseOrderId != null && purchaseOrderId.trim().isNotEmpty) {
      if (poClient != null) {
        po = poClient!.getPurchaseOrder(purchaseOrderId.trim());
        if (po.tenantId != tenantId) {
          throw StateError(
              'ERR_CROSS_TENANT_ACCESS: Cross-tenant purchase order access forbidden');
        }
        if (po.status != 'ORDERED' && po.status != 'PARTIALLY_RECEIVED') {
          throw StateError(
              'ERR_PO_NOT_RECEIVABLE: PO must be in ORDERED or PARTIALLY_RECEIVED status');
        }
      }
    }

    // Cold-Chain & Storage Inspection Checks
    final cond = storageCondition.toUpperCase();
    if (cond.contains('COLD_CHAIN')) {
      if (!storageCheckPassed) {
        throw StateError(
            'ERR_STORAGE_CHECK_FAILED: Cold-chain physical inspection failed');
      }
      if (storageTemperatureCelsius != null) {
        if (storageTemperatureCelsius < 2.0 || storageTemperatureCelsius > 8.0) {
          throw StateError(
              'ERR_STORAGE_CHECK_FAILED: Cold-chain temperature violation ($storageTemperatureCelsius C). Accepted: 2-8 C');
        }
      }
    } else if (!storageCheckPassed) {
      throw StateError('ERR_STORAGE_CHECK_FAILED: Storage inspection check failed');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int totalUnits = 0;
    double totalAmount = 0.0;

    for (final line in lines) {
      if (line.productId.trim().isEmpty) {
        throw ArgumentError('ERR_MISSING_PRODUCT: Product ID cannot be empty');
      }
      if (line.batchNumber.trim().isEmpty) {
        throw ArgumentError(
            'ERR_MISSING_BATCH_NUMBER: Batch number cannot be empty');
      }
      final exp = DateTime(
          line.expiryDate.year, line.expiryDate.month, line.expiryDate.day);
      if (exp.isBefore(today) || exp.isAtSameMomentAs(today)) {
        throw ArgumentError(
            'ERR_EXPIRED_BATCH_RECEIVED: Batch ${line.batchNumber} is expired');
      }
      if (!line.isBonusGoods && line.unitCost <= 0.0) {
        throw ArgumentError('ERR_INVALID_COST: Unit cost must be positive');
      }
      if (!line.isBonusGoods && line.mrpUnit > 0.0 && line.unitCost > line.mrpUnit) {
        throw ArgumentError(
            'ERR_COST_EXCEEDS_MRP: Unit cost cannot exceed retail price');
      }

      // PO Over-receipt check
      if (po != null && line.poItemId != null) {
        MobilePurchaseOrderItem? poItem;
        for (final itm in po.items) {
          if (itm.itemId == line.poItemId) {
            poItem = itm;
            break;
          }
        }
        if (poItem != null) {
          final remaining = poItem.backorderedQuantity;
          if (line.receivedQuantityBaseUnits > remaining) {
            if (line.isBonusGoods) {
              // Bonus promotional goods permitted
            } else if (allowExcess) {
              if (userRole != 'BRANCH_MANAGER' &&
                  userRole != 'PHARMACY_OWNER' &&
                  userRole != 'SUPERADMIN') {
                throw StateError(
                    'ERR_STAFF_ROLE_DENIED: Only Managers and Owners can authorize excess delivery');
              }
              if (excessReason.trim().isEmpty) {
                throw ArgumentError(
                    'ERR_MISSING_EXCESS_REASON: Managerial excess reason is required');
              }
            } else {
              throw ArgumentError(
                  'ERR_EXCESS_RECEIPT: Received quantity (${line.receivedQuantityBaseUnits}) exceeds remaining unreceived quantity ($remaining) on PO item');
            }
          }
        }
      }

      totalUnits += line.receivedQuantityBaseUnits;
      totalAmount += line.lineTotal;
    }

    final grnId =
        'grn-${DateTime.now().microsecondsSinceEpoch.toString().substring(4)}';
    final grnNumber =
        'GRN-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${grnId.substring(4, 10).toUpperCase()}';

    final grn = MobileGoodsReceipt(
      grnId: grnId,
      grnNumber: grnNumber,
      tenantId: tenantId,
      branchId: branchId,
      purchaseOrderId: purchaseOrderId,
      purchaseOrderNumber: po?.poNumber ?? '',
      supplierId: supplierId,
      supplierName:
          supplierName.isNotEmpty ? supplierName : (po?.supplierName ?? ''),
      challanNumber: challanNumber,
      challanDate: challanDate,
      receiptDate: receiptDate ?? DateTime.now(),
      storageCondition: cond,
      storageTemperatureCelsius: storageTemperatureCelsius,
      storageCheckPassed: storageCheckPassed,
      proofOfOrigin: proofOfOrigin,
      status: 'RECEIVED',
      totalReceivedBaseUnits: totalUnits,
      totalInvoiceAmount: double.parse(totalAmount.toStringAsFixed(4)),
      apPostingStatus: 'PENDING',
      apInvoiceAmount: 0.0,
      notes: notes,
      isActive: true,
      lines: lines,
      createdAt: DateTime.now(),
    );

    _grnStore[grnId] = grn;
    return grn;
  }

  MobileGoodsReceipt postGrnToStock(String grnId) {
    _assertProcurementRole();

    final grn = _grnStore[grnId];
    if (grn == null) {
      throw ArgumentError('ERR_GRN_NOT_FOUND: Goods receipt $grnId not found');
    }
    if (grn.tenantId != tenantId) {
      throw StateError(
          'ERR_CROSS_TENANT_ACCESS: Cross-tenant GRN post forbidden');
    }
    if (grn.status == 'POSTED') {
      throw StateError(
          'ERR_ALREADY_POSTED: Goods receipt is already posted to inventory');
    }
    if (grn.status == 'CANCELLED' || grn.status == 'REVERSED') {
      throw StateError('ERR_GRN_INACTIVE: Cannot post inactive GRN');
    }

    // Post lines & update PO if linked
    if (poClient != null &&
        grn.purchaseOrderId != null &&
        grn.purchaseOrderId!.trim().isNotEmpty) {
      final receipts = <String, int>{};
      for (final line in grn.lines) {
        if (line.poItemId != null) {
          receipts[line.poItemId!] =
              (receipts[line.poItemId!] ?? 0) + line.receivedQuantityBaseUnits;
        }
      }
      if (receipts.isNotEmpty) {
        poClient!.receiveItems(
          poId: grn.purchaseOrderId!,
          itemReceipts: receipts,
        );
      }
    }

    for (final line in grn.lines) {
      line.isFullyAllocated = true;
    }

    grn.status = 'POSTED';
    grn.apPostingStatus = 'POSTED';
    grn.apInvoiceAmount = grn.totalInvoiceAmount;
    return grn;
  }

  MobileGoodsReceipt reverseGrn(
    String grnId, {
    String? reason,
    Map<String, int>? consumedStockPerLine,
  }) {
    _assertProcurementRole();

    final grn = _grnStore[grnId];
    if (grn == null) {
      throw ArgumentError('ERR_GRN_NOT_FOUND: Goods receipt $grnId not found');
    }
    if (grn.tenantId != tenantId) {
      throw StateError(
          'ERR_CROSS_TENANT_ACCESS: Cross-tenant GRN reversal forbidden');
    }

    if (grn.status != 'POSTED') {
      grn.status = 'CANCELLED';
      return grn;
    }

    // Check if any portion was consumed
    if (consumedStockPerLine != null) {
      for (final line in grn.lines) {
        final consumed = consumedStockPerLine[line.lineId] ?? 0;
        if (consumed > 0) {
          throw StateError(
              'ERR_CANNOT_REVERSE_CONSUMED_STOCK: Cannot reverse GRN; $consumed units of batch ${line.batchNumber} already dispensed');
        }
      }
    }

    for (final line in grn.lines) {
      line.isFullyAllocated = false;
    }

    grn.status = 'REVERSED';
    grn.apPostingStatus = 'REVERSED';
    grn.notes =
        '${grn.notes} | Reversal Reason: ${reason ?? "Reversed"}'.trim();
    return grn;
  }

  MobileGoodsReceipt getGrn(String grnId) {
    final grn = _grnStore[grnId];
    if (grn == null) {
      throw ArgumentError('ERR_GRN_NOT_FOUND: Goods receipt $grnId not found');
    }
    if (grn.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant GRN access forbidden');
    }
    return grn;
  }

  List<MobileGoodsReceipt> listGrns({
    String? purchaseOrderId,
    String? status,
  }) {
    final list = <MobileGoodsReceipt>[];
    for (final grn in _grnStore.values) {
      if (grn.tenantId != tenantId) {
        continue;
      }
      if (purchaseOrderId != null && grn.purchaseOrderId != purchaseOrderId) {
        continue;
      }
      if (status != null &&
          grn.status.toUpperCase() != status.toUpperCase()) {
        continue;
      }
      list.add(grn);
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  MobilePurchaseOrder cancelPoBackorder({
    required String poId,
    required String itemId,
    required int cancelQuantity,
    required String reason,
  }) {
    _assertProcurementRole();
    if (poClient == null) {
      throw StateError(
          'ERR_PO_CLIENT_NOT_CONFIGURED: PO client required to cancel backorders');
    }
    return poClient!.cancelBackorder(
      poId: poId,
      itemId: itemId,
      cancelQuantity: cancelQuantity,
      reason: reason,
    );
  }
}
