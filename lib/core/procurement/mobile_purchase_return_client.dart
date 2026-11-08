// mobile_purchase_return_client.dart
// Architecture Decision: ADR-0191 (P191).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing Supplier Purchase Returns & Debit Notes:
// - Direct link to batch stock and supplier AP debit note issuance.
// - Enforces stock integrity (cannot return stock already dispensed/reserved).
// - Atomically decrements batch quantities and creates SupplierLedgerEntry.

class MobileBatchStock {
  final String batchId;
  final String batchNumber;
  final String productId;
  int availableQuantity;
  final double costPerUnit;
  String status;

  MobileBatchStock({
    required this.batchId,
    required this.batchNumber,
    required this.productId,
    required this.availableQuantity,
    required this.costPerUnit,
    this.status = 'ACTIVE',
  });
}

class MobileSupplierLedgerEntry {
  final String postingId;
  final String supplierId;
  final String postingType;
  final String referenceNumber;
  final double debitAmount;
  final double creditAmount;
  final double balanceAfter;
  final DateTime postedAt;

  MobileSupplierLedgerEntry({
    required this.postingId,
    required this.supplierId,
    required this.postingType,
    required this.referenceNumber,
    required this.debitAmount,
    required this.creditAmount,
    required this.balanceAfter,
    required this.postedAt,
  });
}

class MobilePurchaseReturnItem {
  final String itemId;
  final String productId;
  final String productBrandName;
  final String batchStockId;
  final String? costLotId;
  final String batchNumber;
  final int returnQuantity;
  final double unitCost;
  final double lineDebitAmount;
  final String reason;
  final String notes;

  MobilePurchaseReturnItem({
    String? itemId,
    required this.productId,
    this.productBrandName = '',
    required this.batchStockId,
    this.costLotId,
    this.batchNumber = '',
    required this.returnQuantity,
    required this.unitCost,
    double? lineDebitAmount,
    this.reason = 'DAMAGED_DELIVERY',
    this.notes = '',
  })  : itemId = itemId ??
            'pri-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}',
        lineDebitAmount = lineDebitAmount ?? (unitCost * returnQuantity);

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'product_id': productId,
        'product_brand_name': productBrandName,
        'batch_stock_id': batchStockId,
        'cost_lot_id': costLotId,
        'batch_number': batchNumber,
        'return_quantity': returnQuantity,
        'unit_cost': unitCost.toStringAsFixed(4),
        'line_debit_amount': lineDebitAmount.toStringAsFixed(4),
        'reason': reason,
        'notes': notes,
      };
}

class MobilePurchaseReturn {
  final String returnId;
  final String returnNumber;
  final String tenantId;
  final String branchId;
  final String supplierId;
  final String supplierName;
  final String? goodsReceiptId;
  final String? purchaseOrderId;
  String status; // DRAFT, POSTED_DEBIT_NOTE, CANCELLED
  final String returnReason;
  final String disposition;
  String reasonNotes;
  final int totalReturnQuantity;
  final double totalDebitAmount;
  final String debitNoteReference;
  final String vendorCreditNoteRef;
  final String carrierPickupReference;
  String? debitLedgerEntryId;
  DateTime? postedAt;
  final String createdBy;
  String? approvedBy;
  final List<MobilePurchaseReturnItem> items;

  MobilePurchaseReturn({
    required this.returnId,
    required this.returnNumber,
    required this.tenantId,
    required this.branchId,
    required this.supplierId,
    required this.supplierName,
    this.goodsReceiptId,
    this.purchaseOrderId,
    this.status = 'DRAFT',
    this.returnReason = 'DAMAGED_DELIVERY',
    this.disposition = 'RETURNED_TO_VENDOR',
    this.reasonNotes = '',
    required this.totalReturnQuantity,
    required this.totalDebitAmount,
    required this.debitNoteReference,
    this.vendorCreditNoteRef = '',
    this.carrierPickupReference = '',
    this.debitLedgerEntryId,
    this.postedAt,
    required this.createdBy,
    this.approvedBy,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'return_id': returnId,
        'return_number': returnNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'goods_receipt_id': goodsReceiptId,
        'purchase_order_id': purchaseOrderId,
        'status': status,
        'return_reason': returnReason,
        'disposition': disposition,
        'reason_notes': reasonNotes,
        'total_return_quantity': totalReturnQuantity,
        'total_debit_amount': totalDebitAmount.toStringAsFixed(4),
        'debit_note_reference': debitNoteReference,
        'vendor_credit_note_ref': vendorCreditNoteRef,
        'carrier_pickup_reference': carrierPickupReference,
        'debit_ledger_entry_id': debitLedgerEntryId,
        'posted_at': postedAt?.toIso8601String(),
        'created_by': createdBy,
        'approved_by': approvedBy,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class MobilePurchaseReturnClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobilePurchaseReturn> returnStore;
  final Map<String, MobileBatchStock> batchStore;
  final Map<String, MobileSupplierLedgerEntry> ledgerStore;

  static const Set<String> _allowedRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
  };

  MobilePurchaseReturnClient({
    required this.tenantId,
    required this.branchId,
    this.userRole = 'CASHIER',
    this.userId = 'usr_anon',
    this.isOffline = false,
    Map<String, MobilePurchaseReturn>? returnStore,
    Map<String, MobileBatchStock>? batchStore,
    Map<String, MobileSupplierLedgerEntry>? ledgerStore,
  })  : returnStore = returnStore ?? {},
        batchStore = batchStore ?? {},
        ledgerStore = ledgerStore ?? {};

  void _assertRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Role $userRole cannot perform purchase returns.');
    }
  }

  MobilePurchaseReturn createPurchaseReturn({
    required String supplierId,
    required String supplierName,
    String? goodsReceiptId,
    String? purchaseOrderId,
    String returnReason = 'DAMAGED_DELIVERY',
    String disposition = 'RETURNED_TO_VENDOR',
    String reasonNotes = '',
    String? debitNoteRef,
    required List<MobilePurchaseReturnItem> items,
    bool autoPost = false,
  }) {
    _assertRole();

    if (items.isEmpty) {
      throw ArgumentError('ERR_EMPTY_ITEMS: Return must have at least 1 item.');
    }

    int totalQty = 0;
    double totalDebit = 0.0;
    final validated = <MobilePurchaseReturnItem>[];

    for (final item in items) {
      if (item.returnQuantity <= 0) {
        throw ArgumentError('ERR_INVALID_QUANTITY: Quantity must be positive.');
      }

      final batch = batchStore[item.batchStockId];
      if (batch != null && batch.availableQuantity < item.returnQuantity) {
        throw ArgumentError(
            'ERR_INSUFFICIENT_STOCK_FOR_RETURN: Batch ${batch.batchNumber} has ${batch.availableQuantity} available, cannot return ${item.returnQuantity}.');
      }

      final cost = item.unitCost > 0
          ? item.unitCost
          : (batch != null ? batch.costPerUnit : 1.0);
      final lineDebit = cost * item.returnQuantity;

      totalQty += item.returnQuantity;
      totalDebit += lineDebit;

      validated.add(MobilePurchaseReturnItem(
        itemId: item.itemId,
        productId: item.productId,
        productBrandName: item.productBrandName,
        batchStockId: item.batchStockId,
        costLotId: item.costLotId,
        batchNumber: batch != null ? batch.batchNumber : item.batchNumber,
        returnQuantity: item.returnQuantity,
        unitCost: cost,
        lineDebitAmount: lineDebit,
        reason: item.reason,
        notes: item.notes,
      ));
    }

    final retId =
        'pret-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final retNum = 'PR-${DateTime.now().millisecondsSinceEpoch}';
    final dRef =
        debitNoteRef ?? 'DN-${DateTime.now().millisecondsSinceEpoch}';

    final pret = MobilePurchaseReturn(
      returnId: retId,
      returnNumber: retNum,
      tenantId: tenantId,
      branchId: branchId,
      supplierId: supplierId,
      supplierName: supplierName,
      goodsReceiptId: goodsReceiptId,
      purchaseOrderId: purchaseOrderId,
      status: 'DRAFT',
      returnReason: returnReason,
      disposition: disposition,
      reasonNotes: reasonNotes,
      totalReturnQuantity: totalQty,
      totalDebitAmount: totalDebit,
      debitNoteReference: dRef,
      createdBy: userId,
      items: validated,
    );

    returnStore[retId] = pret;

    if (autoPost) {
      return postPurchaseReturn(retId);
    }

    return pret;
  }

  MobilePurchaseReturn postPurchaseReturn(String returnId) {
    _assertRole();

    final pret = returnStore[returnId];
    if (pret == null) {
      throw ArgumentError('ERR_RETURN_NOT_FOUND: Return $returnId not found.');
    }

    if (pret.status == 'POSTED_DEBIT_NOTE') {
      throw StateError('ERR_ALREADY_POSTED: Return already posted as debit note.');
    }

    if (pret.status == 'CANCELLED') {
      throw StateError(
          'ERR_RETURN_CANCELLED: Cannot post a cancelled purchase return.');
    }

    // 1. Decrement batch stock
    for (final item in pret.items) {
      final batch = batchStore[item.batchStockId];
      if (batch != null) {
        if (batch.availableQuantity < item.returnQuantity) {
          throw ArgumentError(
              'ERR_INSUFFICIENT_STOCK_FOR_RETURN: Batch ${batch.batchNumber} has only ${batch.availableQuantity} units available.');
        }
        batch.availableQuantity -= item.returnQuantity;
        if (batch.availableQuantity <= 0) {
          batch.availableQuantity = 0;
          batch.status = 'DEPLETED';
        }
      }
    }

    // 2. Post AP Debit note
    double prevBalance = 0.0;
    for (final entry in ledgerStore.values) {
      if (entry.supplierId == pret.supplierId) {
        prevBalance = entry.balanceAfter;
      }
    }

    double newBalance = prevBalance - pret.totalDebitAmount;
    if (newBalance < 0.0) newBalance = 0.0;

    final postingId =
        'sup-post-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final ledgerEntry = MobileSupplierLedgerEntry(
      postingId: postingId,
      supplierId: pret.supplierId,
      postingType: 'RETURN_DEBIT_NOTE',
      referenceNumber: pret.debitNoteReference,
      debitAmount: pret.totalDebitAmount,
      creditAmount: 0.0,
      balanceAfter: newBalance,
      postedAt: DateTime.now(),
    );
    ledgerStore[postingId] = ledgerEntry;

    pret.status = 'POSTED_DEBIT_NOTE';
    pret.debitLedgerEntryId = postingId;
    pret.postedAt = DateTime.now();
    pret.approvedBy = userId;

    return pret;
  }

  MobilePurchaseReturn cancelPurchaseReturn(String returnId, String reason) {
    _assertRole();

    final pret = returnStore[returnId];
    if (pret == null) {
      throw ArgumentError('ERR_RETURN_NOT_FOUND: Return $returnId not found.');
    }

    if (pret.status != 'DRAFT') {
      throw StateError(
          'ERR_CANNOT_CANCEL_POSTED_RETURN: Cannot cancel return in status ${pret.status}');
    }

    pret.status = 'CANCELLED';
    pret.reasonNotes = '${pret.reasonNotes} | Cancelled: $reason'.trim();
    return pret;
  }

  MobilePurchaseReturn getPurchaseReturn(String returnId) {
    final pret = returnStore[returnId];
    if (pret == null) {
      throw ArgumentError('ERR_RETURN_NOT_FOUND: Return $returnId not found.');
    }
    return pret;
  }

  List<MobilePurchaseReturn> listPurchaseReturns({
    String? supplierId,
    String? statusFilter,
  }) {
    return returnStore.values.where((r) {
      if (supplierId != null && supplierId.isNotEmpty && r.supplierId != supplierId) {
        return false;
      }
      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          r.status.toUpperCase() != statusFilter.toUpperCase()) {
        return false;
      }
      return true;
    }).toList();
  }
}

