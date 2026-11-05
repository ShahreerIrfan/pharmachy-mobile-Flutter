// mobile_purchase_requisition_client.dart
// Architecture Decision: ADR-0184 (P184).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing department purchase requisitions,
// requested items, department budget tracking, and approval lifecycle.

class MobilePurchaseRequisitionItem {
  final String itemId;
  final String productId;
  final String productName;
  final String? preferredSupplierId;
  final String preferredSupplierName;
  final String packageType;
  final int packageSize;
  final int requestedQuantity;
  final double estimatedUnitCost;
  final double estimatedTotalCost;
  final int currentStockQuantity;
  final String notes;

  MobilePurchaseRequisitionItem({
    required this.itemId,
    required this.productId,
    this.productName = '',
    this.preferredSupplierId,
    this.preferredSupplierName = '',
    this.packageType = 'BOX',
    this.packageSize = 1,
    required this.requestedQuantity,
    required this.estimatedUnitCost,
    double? estimatedTotalCost,
    this.currentStockQuantity = 0,
    this.notes = '',
  }) : estimatedTotalCost = estimatedTotalCost ??
            double.parse(
                (estimatedUnitCost * requestedQuantity).toStringAsFixed(4));

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'product_id': productId,
        'product_name': productName,
        'preferred_supplier_id': preferredSupplierId,
        'preferred_supplier_name': preferredSupplierName,
        'package_type': packageType,
        'package_size': packageSize,
        'requested_quantity': requestedQuantity,
        'estimated_unit_cost': estimatedUnitCost.toStringAsFixed(4),
        'estimated_total_cost': estimatedTotalCost.toStringAsFixed(4),
        'current_stock_quantity': currentStockQuantity,
        'notes': notes,
      };
}

class MobilePurchaseRequisition {
  final String requisitionId;
  final String tenantId;
  final String branchId;
  String branchName;
  String department;
  String priority;
  String status;
  double totalEstimatedCost;
  double allocatedBudget;
  String justification;
  DateTime? targetDeliveryDate;
  String? submittedById;
  DateTime? submittedAt;
  String? approvedById;
  DateTime? approvedAt;
  String approvalNotes;
  String? rejectedById;
  DateTime? rejectedAt;
  String rejectionReason;
  bool isActive;
  final List<MobilePurchaseRequisitionItem> items;
  final DateTime createdAt;

  MobilePurchaseRequisition({
    required this.requisitionId,
    required this.tenantId,
    required this.branchId,
    this.branchName = '',
    this.department = 'DISPENSARY',
    this.priority = 'MEDIUM',
    this.status = 'DRAFT',
    required this.totalEstimatedCost,
    this.allocatedBudget = 0.0,
    this.justification = '',
    this.targetDeliveryDate,
    this.submittedById,
    this.submittedAt,
    this.approvedById,
    this.approvedAt,
    this.approvalNotes = '',
    this.rejectedById,
    this.rejectedAt,
    this.rejectionReason = '',
    this.isActive = true,
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'requisition_id': requisitionId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'branch_name': branchName,
        'department': department,
        'priority': priority,
        'status': status,
        'total_estimated_cost': totalEstimatedCost.toStringAsFixed(4),
        'allocated_budget': allocatedBudget.toStringAsFixed(4),
        'justification': justification,
        'target_delivery_date':
            targetDeliveryDate?.toIso8601String().substring(0, 10),
        'submitted_by_id': submittedById,
        'submitted_at': submittedAt?.toIso8601String(),
        'approved_by_id': approvedById,
        'approved_at': approvedAt?.toIso8601String(),
        'approval_notes': approvalNotes,
        'rejected_by_id': rejectedById,
        'rejected_at': rejectedAt?.toIso8601String(),
        'rejection_reason': rejectionReason,
        'is_active': isActive,
        'items': items.map((i) => i.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}

class MobilePurchaseRequisitionClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobilePurchaseRequisition> _store;

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

  MobilePurchaseRequisitionClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobilePurchaseRequisition>? initialStore,
  }) : _store = initialStore ?? {};

  void _assertProcurementRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedProcurementRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Cashiers cannot manage purchase requisitions.');
    }
  }

  void _assertApprovalRole() {
    if (!_approvalRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_APPROVAL_ROLE_REQUIRED: Only Branch Managers and Owners can approve or reject requisitions.');
    }
  }

  MobilePurchaseRequisition createRequisition({
    String department = 'DISPENSARY',
    String priority = 'MEDIUM',
    double allocatedBudget = 0.0,
    String justification = '',
    DateTime? targetDeliveryDate,
    required List<MobilePurchaseRequisitionItem> items,
  }) {
    _assertProcurementRole();

    if (items.isEmpty) {
      throw ArgumentError(
          'ERR_EMPTY_REQUISITION_ITEMS: Requisition must contain at least one item');
    }

    double total = 0.0;
    for (final item in items) {
      if (item.productId.trim().isEmpty) {
        throw ArgumentError('ERR_MISSING_PRODUCT_ID: Product ID cannot be empty');
      }
      if (item.requestedQuantity < 1) {
        throw ArgumentError(
            'ERR_INVALID_QUANTITY: Requested quantity must be at least 1');
      }
      if (item.estimatedUnitCost <= 0.0) {
        throw ArgumentError(
            'ERR_INVALID_COST_PRICE: Estimated unit cost must be positive');
      }
      total += item.estimatedTotalCost;
    }

    if (allocatedBudget < 0.0) {
      throw ArgumentError('ERR_INVALID_BUDGET: Allocated budget cannot be negative');
    }

    final reqId =
        'req-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}_${_store.length}';
    final req = MobilePurchaseRequisition(
      requisitionId: reqId,
      tenantId: tenantId,
      branchId: branchId,
      branchName: 'Branch $branchId',
      department: department.toUpperCase(),
      priority: priority.toUpperCase(),
      status: 'DRAFT',
      totalEstimatedCost: double.parse(total.toStringAsFixed(4)),
      allocatedBudget: double.parse(allocatedBudget.toStringAsFixed(4)),
      justification: justification.trim(),
      targetDeliveryDate: targetDeliveryDate,
      isActive: true,
      items: items,
      createdAt: DateTime.now(),
    );

    _store[reqId] = req;
    return req;
  }

  MobilePurchaseRequisition submitRequisition({
    required String requisitionId,
    bool budgetOverride = false,
  }) {
    _assertProcurementRole();

    final existing = _store[requisitionId];
    if (existing == null) {
      throw ArgumentError('ERR_REQUISITION_NOT_FOUND: Requisition $requisitionId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant requisition submission forbidden');
    }
    if (existing.status != 'DRAFT') {
      throw StateError('ERR_INVALID_STATE_TRANSITION: Requisition must be in DRAFT to submit');
    }
    if (existing.items.isEmpty) {
      throw ArgumentError('ERR_EMPTY_REQUISITION_ITEMS: Requisition has no items');
    }

    if (existing.allocatedBudget > 0.0 &&
        existing.totalEstimatedCost > existing.allocatedBudget) {
      if (!budgetOverride) {
        throw ArgumentError(
            'ERR_BUDGET_EXCEEDED: Total cost (${existing.totalEstimatedCost}) exceeds allocated budget (${existing.allocatedBudget})');
      }
    }

    existing.status = 'SUBMITTED';
    existing.submittedById = userId;
    existing.submittedAt = DateTime.now();
    return existing;
  }

  MobilePurchaseRequisition approveRequisition({
    required String requisitionId,
    String approvalNotes = '',
  }) {
    _assertApprovalRole();

    final existing = _store[requisitionId];
    if (existing == null) {
      throw ArgumentError('ERR_REQUISITION_NOT_FOUND: Requisition $requisitionId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant requisition approval forbidden');
    }
    if (existing.status != 'SUBMITTED') {
      throw StateError('ERR_INVALID_STATE_TRANSITION: Requisition must be SUBMITTED to approve');
    }

    existing.status = 'APPROVED';
    existing.approvedById = userId;
    existing.approvedAt = DateTime.now();
    existing.approvalNotes = approvalNotes.trim();
    return existing;
  }

  MobilePurchaseRequisition rejectRequisition({
    required String requisitionId,
    required String rejectionReason,
  }) {
    _assertApprovalRole();

    final existing = _store[requisitionId];
    if (existing == null) {
      throw ArgumentError('ERR_REQUISITION_NOT_FOUND: Requisition $requisitionId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant requisition rejection forbidden');
    }
    if (existing.status != 'SUBMITTED') {
      throw StateError('ERR_INVALID_STATE_TRANSITION: Requisition must be SUBMITTED to reject');
    }
    if (rejectionReason.trim().isEmpty) {
      throw ArgumentError('ERR_MISSING_REJECTION_REASON: rejection_reason is required');
    }

    existing.status = 'REJECTED';
    existing.rejectedById = userId;
    existing.rejectedAt = DateTime.now();
    existing.rejectionReason = rejectionReason.trim();
    return existing;
  }

  MobilePurchaseRequisition cancelRequisition(String requisitionId) {
    _assertProcurementRole();

    final existing = _store[requisitionId];
    if (existing == null) {
      throw ArgumentError('ERR_REQUISITION_NOT_FOUND: Requisition $requisitionId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant requisition cancellation forbidden');
    }
    if (existing.status == 'APPROVED' || existing.status == 'CONVERTED_TO_PO') {
      throw StateError('ERR_CANNOT_CANCEL_APPROVED: Cannot cancel approved requisition');
    }

    existing.status = 'CANCELLED';
    return existing;
  }

  MobilePurchaseRequisition getRequisition(String requisitionId) {
    final existing = _store[requisitionId];
    if (existing == null) {
      throw ArgumentError('ERR_REQUISITION_NOT_FOUND: Requisition $requisitionId not found');
    }
    if (existing.tenantId != tenantId) {
      throw StateError('ERR_CROSS_TENANT_ACCESS: Cross-tenant requisition access forbidden');
    }
    return existing;
  }

  List<MobilePurchaseRequisition> listRequisitions({
    String? department,
    String? priority,
    String? status,
  }) {
    final list = _store.values.where((r) {
      if (r.tenantId != tenantId) return false;
      if (department != null && r.department != department.toUpperCase()) return false;
      if (priority != null && r.priority != priority.toUpperCase()) return false;
      if (status != null && r.status != status.toUpperCase()) return false;
      return true;
    }).toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

