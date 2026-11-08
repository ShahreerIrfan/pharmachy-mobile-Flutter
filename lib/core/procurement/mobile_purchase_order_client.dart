// mobile_purchase_order_client.dart
// Architecture Decision: ADR-0185 (P185).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing purchase orders, line calculations,
// receipt tracking, and guarded lifecycle transitions.

class MobilePurchaseOrderItem {
  final String itemId;
  final String productId;
  final String productName;
  final String packageType;
  final int packageSize;
  final int orderedQuantity;
  int receivedQuantity;
  final double unitCostPrice;
  final double discountPercentage;
  final double netUnitCost;
  final double lineTotal;
  final String notes;

  MobilePurchaseOrderItem({
    required this.itemId,
    required this.productId,
    this.productName = '',
    this.packageType = 'BOX',
    this.packageSize = 1,
    required this.orderedQuantity,
    this.receivedQuantity = 0,
    required this.unitCostPrice,
    this.discountPercentage = 0.0,
    double? netUnitCost,
    double? lineTotal,
    this.notes = '',
  })  : netUnitCost = netUnitCost ??
            double.parse((unitCostPrice * (1.0 - (discountPercentage / 100.0)))
                .toStringAsFixed(4)),
        lineTotal = lineTotal ??
            double.parse(((netUnitCost ??
                        (unitCostPrice *
                            (1.0 - (discountPercentage / 100.0)))) *
                    orderedQuantity)
                .toStringAsFixed(4));

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'product_id': productId,
        'product_name': productName,
        'package_type': packageType,
        'package_size': packageSize,
        'ordered_quantity': orderedQuantity,
        'received_quantity': receivedQuantity,
        'unit_cost_price': unitCostPrice.toStringAsFixed(4),
        'discount_percentage': discountPercentage.toStringAsFixed(2),
        'net_unit_cost': netUnitCost.toStringAsFixed(4),
        'line_total': lineTotal.toStringAsFixed(4),
        'notes': notes,
      };
}

class MobilePurchaseOrder {
  final String poId;
  final String poNumber;
  final String tenantId;
  final String branchId;
  String branchName;
  final String supplierId;
  String supplierName;
  String? requisitionId;
  String status;
  int paymentTermsDays;
  String currency;
  double subtotalAmount;
  double discountAmount;
  double taxAmount;
  double totalAmount;
  DateTime? expectedDeliveryDate;
  DateTime? orderedAt;
  String? approvedById;
  DateTime? approvedAt;
  String approvalNotes;
  DateTime? closedAt;
  String closingNotes;
  String? cancelledById;
  DateTime? cancelledAt;
  String cancellationReason;
  String notes;
  bool isActive;
  final List<MobilePurchaseOrderItem> items;
  final DateTime createdAt;

  MobilePurchaseOrder({
    required this.poId,
    required this.poNumber,
    required this.tenantId,
    required this.branchId,
    this.branchName = '',
    required this.supplierId,
    this.supplierName = '',
    this.requisitionId,
    this.status = 'DRAFT',
    this.paymentTermsDays = 30,
    this.currency = 'BDT',
    required this.subtotalAmount,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    required this.totalAmount,
    this.expectedDeliveryDate,
    this.orderedAt,
    this.approvedById,
    this.approvedAt,
    this.approvalNotes = '',
    this.closedAt,
    this.closingNotes = '',
    this.cancelledById,
    this.cancelledAt,
    this.cancellationReason = '',
    this.notes = '',
    this.isActive = true,
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'po_id': poId,
        'po_number': poNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'branch_name': branchName,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'requisition_id': requisitionId,
        'status': status,
        'payment_terms_days': paymentTermsDays,
        'currency': currency,
        'subtotal_amount': subtotalAmount.toStringAsFixed(4),
        'discount_amount': discountAmount.toStringAsFixed(4),
        'tax_amount': taxAmount.toStringAsFixed(4),
        'total_amount': totalAmount.toStringAsFixed(4),
        'expected_delivery_date':
            expectedDeliveryDate?.toIso8601String().substring(0, 10),
        'ordered_at': orderedAt?.toIso8601String(),
        'approved_by_id': approvedById,
        'approved_at': approvedAt?.toIso8601String(),
        'approval_notes': approvalNotes,
        'closed_at': closedAt?.toIso8601String(),
        'closing_notes': closingNotes,
        'cancelled_by_id': cancelledById,
        'cancelled_at': cancelledAt?.toIso8601String(),
        'cancellation_reason': cancellationReason,
        'notes': notes,
        'is_active': isActive,
        'items': items.map((i) => i.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}

class MobilePurchaseOrderClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobilePurchaseOrder> _poStore;

  static const Set<String> _allowedProcurementRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'AUDITOR',
  };

  static const Set<String> _approvalRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'PROCUREMENT_OFFICER',
  };

  MobilePurchaseOrderClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobilePurchaseOrder>? initialStore,
  }) : _poStore = initialStore ?? {};

  void _assertProcurementRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedProcurementRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Cashiers cannot manage purchase orders.');
    }
  }

  void _assertApprovalRole() {
    if (!_approvalRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_APPROVAL_ROLE_REQUIRED: Only Branch Managers and Owners can approve, order, or cancel POs.');
    }
  }

  MobilePurchaseOrder createPurchaseOrder({
    required String supplierId,
    String supplierName = '',
    String? requisitionId,
    int paymentTermsDays = 30,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    DateTime? expectedDeliveryDate,
    String notes = '',
    required List<MobilePurchaseOrderItem> items,
  }) {
    _assertProcurementRole();

    if (supplierId.trim().isEmpty) {
      throw ArgumentError('ERR_MISSING_SUPPLIER_ID: Supplier ID cannot be empty');
    }
    if (items.isEmpty) {
      throw ArgumentError('ERR_EMPTY_PO_ITEMS: Purchase order must have items');
    }

    double subtotal = 0.0;
    for (final itm in items) {
      if (itm.productId.trim().isEmpty) {
        throw ArgumentError('ERR_MISSING_PRODUCT_ID: Product ID cannot be empty');
      }
      if (itm.orderedQuantity < 1) {
        throw ArgumentError('ERR_INVALID_QUANTITY: Ordered quantity must be >= 1');
      }
      if (itm.unitCostPrice <= 0.0) {
        throw ArgumentError('ERR_INVALID_COST_PRICE: Unit cost price must be > 0');
      }
      subtotal += itm.lineTotal;
    }

    final total = (subtotal - discountAmount + taxAmount).clamp(0.0, double.infinity);
    final poId = 'po-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}_${_poStore.length}';
    final poNumber = 'PO-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${_poStore.length + 1}';

    final po = MobilePurchaseOrder(
      poId: poId,
      poNumber: poNumber,
      tenantId: tenantId,
      branchId: branchId,
      branchName: 'Branch $branchId',
      supplierId: supplierId.trim(),
      supplierName: supplierName.trim(),
      requisitionId: requisitionId,
      status: 'DRAFT',
      paymentTermsDays: paymentTermsDays < 0 ? 30 : paymentTermsDays,
      currency: 'BDT',
      subtotalAmount: double.parse(subtotal.toStringAsFixed(4)),
      discountAmount: double.parse(discountAmount.toStringAsFixed(4)),
      taxAmount: double.parse(taxAmount.toStringAsFixed(4)),
      totalAmount: double.parse(total.toStringAsFixed(4)),
      expectedDeliveryDate: expectedDeliveryDate,
      notes: notes.trim(),
      isActive: true,
      items: items,
      createdAt: DateTime.now(),
    );

    _poStore[poId] = po;
    return po;
  }

  MobilePurchaseOrder approvePurchaseOrder({
    required String poId,
    String approvalNotes = '',
  }) {
    _assertApprovalRole();

    final existing = _poStore[poId];
    if (existing == null) {
      throw ArgumentError('ERR_PO_NOT_FOUND: Purchase order $poId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant PO approval forbidden');
    }
    if (existing.status != 'DRAFT') {
      throw StateError('ERR_INVALID_STATE_TRANSITION: PO must be in DRAFT to approve');
    }

    existing.status = 'APPROVED';
    existing.approvedById = userId;
    existing.approvedAt = DateTime.now();
    existing.approvalNotes = approvalNotes.trim();
    return existing;
  }

  MobilePurchaseOrder orderPurchaseOrder(String poId) {
    _assertApprovalRole();

    final existing = _poStore[poId];
    if (existing == null) {
      throw ArgumentError('ERR_PO_NOT_FOUND: Purchase order $poId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant PO dispatch forbidden');
    }
    if (existing.status != 'APPROVED') {
      throw StateError('ERR_INVALID_STATE_TRANSITION: PO must be APPROVED to dispatch');
    }

    existing.status = 'ORDERED';
    existing.orderedAt = DateTime.now();
    return existing;
  }

  MobilePurchaseOrder receiveItems({
    required String poId,
    required Map<String, int> itemReceipts,
  }) {
    _assertApprovalRole();

    final existing = _poStore[poId];
    if (existing == null) {
      throw ArgumentError('ERR_PO_NOT_FOUND: Purchase order $poId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant PO receipt forbidden');
    }
    if (existing.status != 'ORDERED' && existing.status != 'PARTIALLY_RECEIVED') {
      throw StateError('ERR_INVALID_STATE_TRANSITION: PO must be ORDERED or PARTIALLY_RECEIVED');
    }

    for (final itm in existing.items) {
      if (itemReceipts.containsKey(itm.itemId)) {
        final addQty = itemReceipts[itm.itemId]!;
        if (addQty > 0) {
          itm.receivedQuantity += addQty;
        }
      }
    }

    bool allFulfilled = true;
    bool anyReceived = false;
    for (final itm in existing.items) {
      if (itm.receivedQuantity < itm.orderedQuantity) {
        allFulfilled = false;
      }
      if (itm.receivedQuantity > 0) {
        anyReceived = true;
      }
    }

    if (allFulfilled) {
      existing.status = 'CLOSED';
      existing.closedAt = DateTime.now();
      existing.closingNotes = 'All line items fully received';
    } else if (anyReceived) {
      existing.status = 'PARTIALLY_RECEIVED';
    }

    return existing;
  }

  MobilePurchaseOrder closePurchaseOrder({
    required String poId,
    String closingNotes = '',
  }) {
    _assertApprovalRole();

    final existing = _poStore[poId];
    if (existing == null) {
      throw ArgumentError('ERR_PO_NOT_FOUND: Purchase order $poId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant PO close forbidden');
    }
    if (existing.status != 'ORDERED' && existing.status != 'PARTIALLY_RECEIVED') {
      throw StateError('ERR_INVALID_STATE_TRANSITION: PO must be ORDERED or PARTIALLY_RECEIVED to close');
    }

    existing.status = 'CLOSED';
    existing.closedAt = DateTime.now();
    existing.closingNotes = closingNotes.trim().isEmpty ? 'Manually closed' : closingNotes.trim();
    return existing;
  }

  MobilePurchaseOrder cancelPurchaseOrder({
    required String poId,
    required String cancellationReason,
  }) {
    _assertApprovalRole();

    final existing = _poStore[poId];
    if (existing == null) {
      throw ArgumentError('ERR_PO_NOT_FOUND: Purchase order $poId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant PO cancellation forbidden');
    }
    if (existing.status == 'CLOSED' || existing.status == 'CANCELLED') {
      throw StateError('ERR_INVALID_STATE_TRANSITION: Cannot cancel PO in ${existing.status}');
    }

    final totalReceived = existing.items.fold<int>(0, (sum, i) => sum + i.receivedQuantity);
    if (totalReceived > 0) {
      throw StateError('ERR_CANNOT_CANCEL_RECEIVED_PO: Cannot cancel PO with received goods ($totalReceived units received)');
    }

    if (cancellationReason.trim().isEmpty) {
      throw ArgumentError('ERR_MISSING_CANCELLATION_REASON: cancellation_reason is required');
    }

    existing.status = 'CANCELLED';
    existing.cancelledById = userId;
    existing.cancelledAt = DateTime.now();
    existing.cancellationReason = cancellationReason.trim();
    return existing;
  }

  MobilePurchaseOrder getPurchaseOrder(String poId) {
    final existing = _poStore[poId];
    if (existing == null) {
      throw ArgumentError('ERR_PO_NOT_FOUND: Purchase order $poId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant PO access forbidden');
    }
    return existing;
  }

  List<MobilePurchaseOrder> listPurchaseOrders({
    String? supplierId,
    String? status,
  }) {
    final list = _poStore.values.where((po) {
      if (po.tenantId != tenantId) return false;
      if (supplierId != null && po.supplierId != supplierId) return false;
      if (status != null && po.status != status.toUpperCase()) return false;
      return true;
    }).toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

