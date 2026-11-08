// mobile_supplier_invoice_matching_client.dart
// Architecture Decision: ADR-0190 (P190).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing 3-Way Supplier Invoice Matching:
// - Reconciles PO commitment <-> GRN physical custody <-> Supplier Invoice billing.
// - Handles price variance tolerances (default 1.5% or ৳50 BDT) and quantity variance.
// - Routes price spikes, physical over-billing, and unmatched items to the Discrepancy Queue.
// - Enforces managerial exception overrides and immutable Accounts Payable ledger posting.

import 'mobile_purchase_order_client.dart';
import 'mobile_goods_receipt_client.dart';

class MobileSupplierInvoiceItem {
  final String itemId;
  final String productId;
  final String productBrandName;
  final String? poItemId;
  final String? grnLineId;
  final String batchNumber;
  final int billedQuantity;
  int receivedQuantity;
  int orderedQuantity;
  final double billedUnitPrice;
  double poUnitPrice;
  final double lineSubtotal;
  final double lineTaxPercentage;
  final double lineDiscountPercentage;
  final double lineTotal;
  String matchStatus;
  double priceVariance;
  int quantityVariance;
  final String notes;

  MobileSupplierInvoiceItem({
    String? itemId,
    required this.productId,
    this.productBrandName = '',
    this.poItemId,
    this.grnLineId,
    this.batchNumber = '',
    int billedQuantity = 1,
    this.receivedQuantity = 0,
    this.orderedQuantity = 0,
    required this.billedUnitPrice,
    this.poUnitPrice = 0.0,
    double? lineSubtotal,
    this.lineTaxPercentage = 0.0,
    this.lineDiscountPercentage = 0.0,
    double? lineTotal,
    this.matchStatus = 'MATCHED',
    this.priceVariance = 0.0,
    this.quantityVariance = 0,
    this.notes = '',
  })  : itemId = itemId ??
            'sii-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}',
        billedQuantity = billedQuantity < 1 ? 1 : billedQuantity,
        lineSubtotal = lineSubtotal ??
            _calcSubtotal(
              billedQuantity < 1 ? 1 : billedQuantity,
              billedUnitPrice,
              lineDiscountPercentage,
            ),
        lineTotal = lineTotal ??
            _calcTotal(
              billedQuantity < 1 ? 1 : billedQuantity,
              billedUnitPrice,
              lineDiscountPercentage,
              lineTaxPercentage,
            );

  static double _calcSubtotal(int qty, double unitPrice, double discPct) {
    final discFactor = 1.0 - (discPct / 100.0);
    return double.parse((unitPrice * discFactor * qty).toStringAsFixed(4));
  }

  static double _calcTotal(
      int qty, double unitPrice, double discPct, double taxPct) {
    final sub = _calcSubtotal(qty, unitPrice, discPct);
    final tax = sub * (taxPct / 100.0);
    return double.parse((sub + tax).toStringAsFixed(4));
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'product_id': productId,
        'product_brand_name': productBrandName,
        'po_item_id': poItemId,
        'grn_line_id': grnLineId,
        'batch_number': batchNumber,
        'billed_quantity': billedQuantity,
        'received_quantity': receivedQuantity,
        'ordered_quantity': orderedQuantity,
        'billed_unit_price': billedUnitPrice.toStringAsFixed(4),
        'po_unit_price': poUnitPrice.toStringAsFixed(4),
        'line_subtotal': lineSubtotal.toStringAsFixed(4),
        'line_tax_percentage': lineTaxPercentage.toStringAsFixed(2),
        'line_discount_percentage': lineDiscountPercentage.toStringAsFixed(2),
        'line_total': lineTotal.toStringAsFixed(4),
        'match_status': matchStatus,
        'price_variance': priceVariance.toStringAsFixed(4),
        'quantity_variance': quantityVariance,
        'notes': notes,
      };

  factory MobileSupplierInvoiceItem.fromJson(Map<String, dynamic> json) {
    return MobileSupplierInvoiceItem(
      itemId: json['item_id']?.toString(),
      productId: json['product_id']?.toString() ?? '',
      productBrandName: json['product_brand_name']?.toString() ?? '',
      poItemId: json['po_item_id']?.toString(),
      grnLineId: json['grn_line_id']?.toString(),
      batchNumber: json['batch_number']?.toString() ?? '',
      billedQuantity: (json['billed_quantity'] as num?)?.toInt() ?? 1,
      receivedQuantity: (json['received_quantity'] as num?)?.toInt() ?? 0,
      orderedQuantity: (json['ordered_quantity'] as num?)?.toInt() ?? 0,
      billedUnitPrice: double.tryParse(
              json['billed_unit_price']?.toString() ?? '0') ??
          0.0,
      poUnitPrice:
          double.tryParse(json['po_unit_price']?.toString() ?? '0') ?? 0.0,
      lineSubtotal:
          double.tryParse(json['line_subtotal']?.toString() ?? '0') ?? 0.0,
      lineTaxPercentage: double.tryParse(
              json['line_tax_percentage']?.toString() ?? '0') ??
          0.0,
      lineDiscountPercentage: double.tryParse(
              json['line_discount_percentage']?.toString() ?? '0') ??
          0.0,
      lineTotal:
          double.tryParse(json['line_total']?.toString() ?? '0') ?? 0.0,
      matchStatus: json['match_status']?.toString() ?? 'MATCHED',
      priceVariance:
          double.tryParse(json['price_variance']?.toString() ?? '0') ?? 0.0,
      quantityVariance: (json['quantity_variance'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class MobileSupplierInvoice {
  final String invoiceId;
  final String invoiceNumber;
  final String tenantId;
  final String branchId;
  final String supplierId;
  final String supplierName;
  final String? purchaseOrderId;
  final String purchaseOrderNumber;
  final String? goodsReceiptId;
  final String goodsReceiptNumber;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String currency;
  final double subtotalAmount;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  String matchingStatus;
  bool hasDiscrepancy;
  List<String> discrepancyReasons;
  double priceVarianceAmount;
  int quantityVarianceUnits;
  double totalVarianceAmount;
  final double toleratedPriceVariancePercentage;
  final double toleratedAmountVarianceBdt;
  String? exceptionApprovedBy;
  DateTime? exceptionApprovedAt;
  String exceptionJustification;
  String rejectionReason;
  String? rejectedBy;
  DateTime? rejectedAt;
  DateTime? postedToApAt;
  String? apLedgerEntryId;
  final String proofAttachmentReference;
  final String notes;
  bool isActive;
  final List<MobileSupplierInvoiceItem> items;
  final DateTime createdAt;

  MobileSupplierInvoice({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.tenantId,
    this.branchId = '',
    required this.supplierId,
    this.supplierName = '',
    this.purchaseOrderId,
    this.purchaseOrderNumber = '',
    this.goodsReceiptId,
    this.goodsReceiptNumber = '',
    required this.invoiceDate,
    this.dueDate,
    this.currency = 'BDT',
    required this.subtotalAmount,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    required this.totalAmount,
    this.matchingStatus = 'DRAFT',
    this.hasDiscrepancy = false,
    List<String>? discrepancyReasons,
    this.priceVarianceAmount = 0.0,
    this.quantityVarianceUnits = 0,
    this.totalVarianceAmount = 0.0,
    this.toleratedPriceVariancePercentage = 1.50,
    this.toleratedAmountVarianceBdt = 50.00,
    this.exceptionApprovedBy,
    this.exceptionApprovedAt,
    this.exceptionJustification = '',
    this.rejectionReason = '',
    this.rejectedBy,
    this.rejectedAt,
    this.postedToApAt,
    this.apLedgerEntryId,
    this.proofAttachmentReference = '',
    this.notes = '',
    this.isActive = true,
    required this.items,
    DateTime? createdAt,
  })  : discrepancyReasons = discrepancyReasons ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'purchase_order_id': purchaseOrderId,
        'purchase_order_number': purchaseOrderNumber,
        'goods_receipt_id': goodsReceiptId,
        'goods_receipt_number': goodsReceiptNumber,
        'invoice_date': invoiceDate.toIso8601String().substring(0, 10),
        'due_date': dueDate?.toIso8601String().substring(0, 10),
        'currency': currency,
        'subtotal_amount': subtotalAmount.toStringAsFixed(4),
        'tax_amount': taxAmount.toStringAsFixed(4),
        'discount_amount': discountAmount.toStringAsFixed(4),
        'total_amount': totalAmount.toStringAsFixed(4),
        'matching_status': matchingStatus,
        'has_discrepancy': hasDiscrepancy,
        'discrepancy_reasons': discrepancyReasons,
        'price_variance_amount': priceVarianceAmount.toStringAsFixed(4),
        'quantity_variance_units': quantityVarianceUnits,
        'total_variance_amount': totalVarianceAmount.toStringAsFixed(4),
        'tolerated_price_variance_percentage':
            toleratedPriceVariancePercentage.toStringAsFixed(2),
        'tolerated_amount_variance_bdt':
            toleratedAmountVarianceBdt.toStringAsFixed(4),
        'exception_approved_by': exceptionApprovedBy,
        'exception_approved_at': exceptionApprovedAt?.toIso8601String(),
        'exception_justification': exceptionJustification,
        'rejection_reason': rejectionReason,
        'rejected_by': rejectedBy,
        'rejected_at': rejectedAt?.toIso8601String(),
        'posted_to_ap_at': postedToApAt?.toIso8601String(),
        'ap_ledger_entry_id': apLedgerEntryId,
        'proof_attachment_reference': proofAttachmentReference,
        'notes': notes,
        'is_active': isActive,
        'items': items.map((i) => i.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  factory MobileSupplierInvoice.fromJson(Map<String, dynamic> json) {
    return MobileSupplierInvoice(
      invoiceId: json['invoice_id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      supplierId: json['supplier_id']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString() ?? '',
      purchaseOrderId: json['purchase_order_id']?.toString(),
      purchaseOrderNumber: json['purchase_order_number']?.toString() ?? '',
      goodsReceiptId: json['goods_receipt_id']?.toString(),
      goodsReceiptNumber: json['goods_receipt_number']?.toString() ?? '',
      invoiceDate: json['invoice_date'] != null
          ? DateTime.parse(json['invoice_date'])
          : DateTime.now(),
      dueDate:
          json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      currency: json['currency']?.toString() ?? 'BDT',
      subtotalAmount:
          double.tryParse(json['subtotal_amount']?.toString() ?? '0') ?? 0.0,
      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0.0,
      discountAmount:
          double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      matchingStatus: json['matching_status']?.toString() ?? 'DRAFT',
      hasDiscrepancy: json['has_discrepancy'] == true,
      discrepancyReasons: (json['discrepancy_reasons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      priceVarianceAmount: double.tryParse(
              json['price_variance_amount']?.toString() ?? '0') ??
          0.0,
      quantityVarianceUnits:
          (json['quantity_variance_units'] as num?)?.toInt() ?? 0,
      totalVarianceAmount: double.tryParse(
              json['total_variance_amount']?.toString() ?? '0') ??
          0.0,
      toleratedPriceVariancePercentage: double.tryParse(
              json['tolerated_price_variance_percentage']?.toString() ??
                  '1.50') ??
          1.50,
      toleratedAmountVarianceBdt: double.tryParse(
              json['tolerated_amount_variance_bdt']?.toString() ?? '50.00') ??
          50.00,
      exceptionApprovedBy: json['exception_approved_by']?.toString(),
      exceptionApprovedAt: json['exception_approved_at'] != null
          ? DateTime.parse(json['exception_approved_at'])
          : null,
      exceptionJustification:
          json['exception_justification']?.toString() ?? '',
      rejectionReason: json['rejection_reason']?.toString() ?? '',
      rejectedBy: json['rejected_by']?.toString(),
      rejectedAt: json['rejected_at'] != null
          ? DateTime.parse(json['rejected_at'])
          : null,
      postedToApAt: json['posted_to_ap_at'] != null
          ? DateTime.parse(json['posted_to_ap_at'])
          : null,
      apLedgerEntryId: json['ap_ledger_entry_id']?.toString(),
      proofAttachmentReference:
          json['proof_attachment_reference']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      isActive: json['is_active'] != false,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => MobileSupplierInvoiceItem.fromJson(
                  item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class MobileSupplierInvoiceMatchingClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileSupplierInvoice> _invoiceStore;
  final Map<String, double> _supplierApBalances;
  final MobilePurchaseOrderClient? poClient;
  final MobileGoodsReceiptClient? grnClient;

  static const Set<String> _allowedProcurementRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
    'AUDITOR',
  };

  static const Set<String> _allowedApproverRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'AUDITOR',
  };

  MobileSupplierInvoiceMatchingClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileSupplierInvoice>? initialStore,
    Map<String, double>? initialBalances,
    this.poClient,
    this.grnClient,
  })  : _invoiceStore = initialStore ?? {},
        _supplierApBalances = initialBalances ?? {};

  void _assertProcurementRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedProcurementRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Cashiers cannot process supplier invoices.');
    }
  }

  void _assertApproverRole() {
    if (!_allowedApproverRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Only Managers and Owners can approve discrepancy exceptions.');
    }
  }

  MobileSupplierInvoice createSupplierInvoice({
    required String supplierId,
    String supplierName = '',
    required String invoiceNumber,
    required DateTime invoiceDate,
    DateTime? dueDate,
    String? purchaseOrderId,
    String? goodsReceiptId,
    String currency = 'BDT',
    double toleratedPriceVariancePercentage = 1.50,
    double toleratedAmountVarianceBdt = 50.00,
    String proofAttachmentReference = '',
    String notes = '',
    required List<MobileSupplierInvoiceItem> items,
  }) {
    _assertProcurementRole();

    if (supplierId.trim().isEmpty) {
      throw ArgumentError('ERR_MISSING_SUPPLIER: Supplier ID is required');
    }
    if (invoiceNumber.trim().isEmpty) {
      throw ArgumentError(
          'ERR_MISSING_INVOICE_NUMBER: Supplier invoice number is required');
    }
    if (items.isEmpty) {
      throw ArgumentError(
          'ERR_EMPTY_INVOICE: Invoice must contain at least one line item');
    }

    // Duplicate invoice detection
    for (final existing in _invoiceStore.values) {
      if (existing.tenantId == tenantId &&
          existing.supplierId == supplierId &&
          existing.invoiceNumber.toUpperCase() ==
              invoiceNumber.trim().toUpperCase()) {
        throw StateError(
            'ERR_DUPLICATE_INVOICE: Invoice $invoiceNumber already exists for supplier $supplierName');
      }
    }

    // PO and GRN cross-tenant validation
    MobilePurchaseOrder? po;
    if (purchaseOrderId != null &&
        purchaseOrderId.trim().isNotEmpty &&
        poClient != null) {
      po = poClient!.getPurchaseOrder(purchaseOrderId.trim());
      if (po.tenantId != tenantId) {
        throw StateError(
            'ERR_CROSS_TENANT_ACCESS: Cross-tenant PO access forbidden');
      }
    }

    MobileGoodsReceipt? grn;
    if (goodsReceiptId != null &&
        goodsReceiptId.trim().isNotEmpty &&
        grnClient != null) {
      grn = grnClient!.getGrn(goodsReceiptId.trim());
      if (grn.tenantId != tenantId) {
        throw StateError(
            'ERR_CROSS_TENANT_ACCESS: Cross-tenant GRN access forbidden');
      }
    }

    double subtotal = 0.0;
    double total = 0.0;

    for (final item in items) {
      if (item.productId.trim().isEmpty) {
        throw ArgumentError(
            'ERR_MISSING_PRODUCT: Product ID is required on each line');
      }
      if (item.billedQuantity <= 0) {
        throw ArgumentError(
            'ERR_INVALID_QUANTITY: Billed quantity must be positive');
      }
      if (item.billedUnitPrice <= 0.0) {
        throw ArgumentError(
            'ERR_INVALID_UNIT_PRICE: Billed unit price must be positive');
      }

      subtotal += item.lineSubtotal;
      total += item.lineTotal;
    }

    final invoiceId =
        'si-${DateTime.now().microsecondsSinceEpoch.toString().substring(4)}';

    final invoice = MobileSupplierInvoice(
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber.trim(),
      tenantId: tenantId,
      branchId: branchId,
      supplierId: supplierId,
      supplierName:
          supplierName.isNotEmpty ? supplierName : (po?.supplierName ?? ''),
      purchaseOrderId: purchaseOrderId,
      purchaseOrderNumber: po?.poNumber ?? '',
      goodsReceiptId: goodsReceiptId,
      goodsReceiptNumber: grn?.grnNumber ?? '',
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      currency: currency,
      subtotalAmount: double.parse(subtotal.toStringAsFixed(4)),
      taxAmount: 0.0,
      discountAmount: 0.0,
      totalAmount: double.parse(total.toStringAsFixed(4)),
      matchingStatus: 'DRAFT',
      toleratedPriceVariancePercentage: toleratedPriceVariancePercentage,
      toleratedAmountVarianceBdt: toleratedAmountVarianceBdt,
      proofAttachmentReference: proofAttachmentReference,
      notes: notes,
      items: items,
      createdAt: DateTime.now(),
    );

    _invoiceStore[invoiceId] = invoice;

    // Execute automated 3-way match
    return executeThreeWayMatch(invoiceId);
  }

  MobileSupplierInvoice executeThreeWayMatch(String invoiceId) {
    _assertProcurementRole();

    final invoice = _invoiceStore[invoiceId];
    if (invoice == null) {
      throw ArgumentError(
          'ERR_INVOICE_NOT_FOUND: Supplier invoice $invoiceId not found');
    }
    if (invoice.tenantId != tenantId) {
      throw StateError(
          'ERR_CROSS_TENANT_ACCESS: Cross-tenant invoice matching forbidden');
    }
    if (invoice.matchingStatus == 'POSTED_TO_AP' ||
        invoice.matchingStatus == 'REJECTED') {
      throw StateError(
          'ERR_INVOICE_IMMUTABLE: Cannot match invoice in ${invoice.matchingStatus} status');
    }

    MobilePurchaseOrder? po;
    if (invoice.purchaseOrderId != null &&
        invoice.purchaseOrderId!.trim().isNotEmpty &&
        poClient != null) {
      po = poClient!.getPurchaseOrder(invoice.purchaseOrderId!);
    }

    MobileGoodsReceipt? grn;
    if (invoice.goodsReceiptId != null &&
        invoice.goodsReceiptId!.trim().isNotEmpty &&
        grnClient != null) {
      grn = grnClient!.getGrn(invoice.goodsReceiptId!);
    }

    final discrepancies = <String>[];
    double totalPriceVariance = 0.0;
    int totalQtyVariance = 0;
    bool hasBlockingDiscrepancy = false;

    final priceTolerancePct = invoice.toleratedPriceVariancePercentage;
    final amountToleranceBdt = invoice.toleratedAmountVarianceBdt;

    for (final item in invoice.items) {
      bool itemHasDiscrepancy = false;

      // 1. PO Price Verification
      if (po != null) {
        MobilePurchaseOrderItem? poItem;
        for (final pi in po.items) {
          if (item.poItemId != null && item.poItemId == pi.itemId) {
            poItem = pi;
            break;
          } else if (item.productId == pi.productId) {
            poItem = pi;
            break;
          }
        }

        if (poItem != null) {
          item.poUnitPrice = poItem.unitCostPrice;
          item.orderedQuantity = poItem.orderedQuantity;
          final priceDiff = item.billedUnitPrice - poItem.unitCostPrice;
          item.priceVariance = double.parse(priceDiff.toStringAsFixed(4));
          totalPriceVariance += priceDiff * item.billedQuantity;

          if (poItem.unitCostPrice > 0.0 && priceDiff > 0.0) {
            final pctDiff = (priceDiff / poItem.unitCostPrice) * 100.0;
            if (pctDiff > priceTolerancePct && priceDiff > 1.0) {
              item.matchStatus = 'PRICE_VARIANCE';
              itemHasDiscrepancy = true;
              hasBlockingDiscrepancy = true;
              final msg =
                  'PRICE_VARIANCE: ${item.productBrandName} billed ৳${item.billedUnitPrice} exceeds PO price ৳${poItem.unitCostPrice} by ${pctDiff.toStringAsFixed(2)}%';
              if (!discrepancies.contains(msg)) {
                discrepancies.add(msg);
              }
            }
          }
        }
      }

      // 2. GRN Physical Quantity Verification
      if (grn != null) {
        MobileGoodsReceiptLine? grnLine;
        for (final gl in grn.lines) {
          if (item.grnLineId != null && item.grnLineId == gl.lineId) {
            grnLine = gl;
            break;
          } else if (item.productId == gl.productId) {
            grnLine = gl;
            break;
          }
        }

        if (grnLine != null) {
          item.receivedQuantity = grnLine.receivedQuantityBaseUnits;
          final qtyDiff = item.billedQuantity - grnLine.receivedQuantityBaseUnits;
          item.quantityVariance = qtyDiff;

          if (qtyDiff > 0) {
            totalQtyVariance += qtyDiff;
            item.matchStatus = 'QUANTITY_OVER_BILLING';
            itemHasDiscrepancy = true;
            hasBlockingDiscrepancy = true;
            final msg =
                'QUANTITY_OVER_BILLING: ${item.productBrandName} billed ${item.billedQuantity} units exceeds GRN received ${grnLine.receivedQuantityBaseUnits} units';
            if (!discrepancies.contains(msg)) {
              discrepancies.add(msg);
            }
          } else if (qtyDiff < 0) {
            item.matchStatus = 'QUANTITY_UNDER_BILLING';
          }
        } else {
          item.matchStatus = 'UNMATCHED_ITEM';
          itemHasDiscrepancy = true;
          hasBlockingDiscrepancy = true;
          final msg =
              'UNMATCHED_ITEM: ${item.productBrandName} billed on invoice but not found in GRN shipment';
          if (!discrepancies.contains(msg)) {
            discrepancies.add(msg);
          }
        }
      }

      if (!itemHasDiscrepancy) {
        item.matchStatus = 'MATCHED';
      }
    }

    if (totalPriceVariance.abs() > amountToleranceBdt &&
        totalPriceVariance > 0.0) {
      hasBlockingDiscrepancy = true;
      final msg =
          'AMOUNT_VARIANCE: Net invoice variance ৳${totalPriceVariance.toStringAsFixed(2)} exceeds tolerance ৳$amountToleranceBdt';
      if (!discrepancies.contains(msg)) {
        discrepancies.add(msg);
      }
    }

    invoice.hasDiscrepancy = hasBlockingDiscrepancy;
    invoice.discrepancyReasons = discrepancies;
    invoice.priceVarianceAmount =
        double.parse(totalPriceVariance.toStringAsFixed(4));
    invoice.quantityVarianceUnits = totalQtyVariance;
    invoice.totalVarianceAmount =
        double.parse(totalPriceVariance.toStringAsFixed(4));

    if (hasBlockingDiscrepancy) {
      invoice.matchingStatus = 'DISCREPANCY_QUEUE';
    } else {
      invoice.matchingStatus = 'MATCHED';
    }

    return invoice;
  }

  MobileSupplierInvoice approveException({
    required String invoiceId,
    required String justification,
    String notes = '',
  }) {
    _assertApproverRole();

    final invoice = _invoiceStore[invoiceId];
    if (invoice == null) {
      throw ArgumentError(
          'ERR_INVOICE_NOT_FOUND: Supplier invoice $invoiceId not found');
    }
    if (invoice.tenantId != tenantId) {
      throw StateError(
          'ERR_CROSS_TENANT_ACCESS: Cross-tenant exception approval forbidden');
    }
    if (invoice.matchingStatus != 'DISCREPANCY_QUEUE') {
      throw StateError(
          'ERR_INVALID_INVOICE_STATUS: Invoice is not in discrepancy queue (${invoice.matchingStatus})');
    }
    if (justification.trim().isEmpty) {
      throw ArgumentError(
          'ERR_MISSING_JUSTIFICATION: Documented managerial justification is required');
    }

    invoice.matchingStatus = 'APPROVED_EXCEPTION';
    invoice.exceptionApprovedBy = userId;
    invoice.exceptionApprovedAt = DateTime.now();
    invoice.exceptionJustification = justification.trim();
    return invoice;
  }

  MobileSupplierInvoice rejectInvoice({
    required String invoiceId,
    required String rejectionReason,
    String notes = '',
  }) {
    _assertApproverRole();

    final invoice = _invoiceStore[invoiceId];
    if (invoice == null) {
      throw ArgumentError(
          'ERR_INVOICE_NOT_FOUND: Supplier invoice $invoiceId not found');
    }
    if (invoice.tenantId != tenantId) {
      throw StateError(
          'ERR_CROSS_TENANT_ACCESS: Cross-tenant invoice rejection forbidden');
    }
    if (invoice.matchingStatus == 'POSTED_TO_AP') {
      throw StateError(
          'ERR_INVOICE_ALREADY_POSTED: Cannot reject invoice already posted to AP');
    }
    if (rejectionReason.trim().isEmpty) {
      throw ArgumentError(
          'ERR_MISSING_REJECTION_REASON: Documented rejection reason is required');
    }

    invoice.matchingStatus = 'REJECTED';
    invoice.rejectedBy = userId;
    invoice.rejectedAt = DateTime.now();
    invoice.rejectionReason = rejectionReason.trim();
    return invoice;
  }

  MobileSupplierInvoice postInvoiceToAp(String invoiceId) {
    _assertProcurementRole();

    final invoice = _invoiceStore[invoiceId];
    if (invoice == null) {
      throw ArgumentError(
          'ERR_INVOICE_NOT_FOUND: Supplier invoice $invoiceId not found');
    }
    if (invoice.tenantId != tenantId) {
      throw StateError(
          'ERR_CROSS_TENANT_ACCESS: Cross-tenant AP posting forbidden');
    }
    if (invoice.matchingStatus == 'POSTED_TO_AP') {
      throw StateError(
          'ERR_ALREADY_POSTED: Invoice is already posted to Accounts Payable');
    }
    if (invoice.matchingStatus == 'REJECTED') {
      throw StateError(
          'ERR_INVOICE_REJECTED: Cannot post rejected invoice to Accounts Payable');
    }
    if (invoice.matchingStatus != 'MATCHED' &&
        invoice.matchingStatus != 'APPROVED_EXCEPTION') {
      throw StateError(
          'ERR_INVOICE_NOT_MATCHED: Cannot post invoice in ${invoice.matchingStatus} status. Must be MATCHED or APPROVED_EXCEPTION.');
    }

    final prevBalance = _supplierApBalances[invoice.supplierId] ?? 0.0;
    final newBalance = prevBalance + invoice.totalAmount;
    _supplierApBalances[invoice.supplierId] =
        double.parse(newBalance.toStringAsFixed(4));

    final postingId =
        'sup-post-${DateTime.now().microsecondsSinceEpoch.toString().substring(4)}';

    invoice.matchingStatus = 'POSTED_TO_AP';
    invoice.postedToApAt = DateTime.now();
    invoice.apLedgerEntryId = postingId;

    if (grnClient != null &&
        invoice.goodsReceiptId != null &&
        invoice.goodsReceiptId!.trim().isNotEmpty) {
      final grn = grnClient!.getGrn(invoice.goodsReceiptId!);
      grn.apPostingStatus = 'POSTED';
      grn.apInvoiceAmount = invoice.totalAmount;
    }

    return invoice;
  }

  List<MobileSupplierInvoice> getExceptionQueue(String? branchId) {
    final queue = <MobileSupplierInvoice>[];
    for (final inv in _invoiceStore.values) {
      if (inv.tenantId != tenantId) {
        continue;
      }
      if (branchId != null && branchId.isNotEmpty && inv.branchId != branchId) {
        continue;
      }
      if (inv.matchingStatus == 'DISCREPANCY_QUEUE') {
        queue.add(inv);
      }
    }
    queue.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return queue;
  }

  MobileSupplierInvoice getSupplierInvoice(String invoiceId) {
    final invoice = _invoiceStore[invoiceId];
    if (invoice == null) {
      throw ArgumentError(
          'ERR_INVOICE_NOT_FOUND: Supplier invoice $invoiceId not found');
    }
    if (invoice.tenantId != tenantId) {
      throw StateError(
          'ERR_CROSS_TENANT_ACCESS: Cross-tenant invoice access forbidden');
    }
    return invoice;
  }

  List<MobileSupplierInvoice> listSupplierInvoices({
    String? supplierId,
    String? matchingStatus,
  }) {
    final list = <MobileSupplierInvoice>[];
    for (final inv in _invoiceStore.values) {
      if (inv.tenantId != tenantId) {
        continue;
      }
      if (supplierId != null && inv.supplierId != supplierId) {
        continue;
      }
      if (matchingStatus != null &&
          inv.matchingStatus.toUpperCase() != matchingStatus.toUpperCase()) {
        continue;
      }
      list.add(inv);
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

