// mobile_reorder_planner_client.dart
// Architecture Decision: ADR-0194 (P194).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing Automatic Reorder Planning:
// - Recommends replenishment quantities using lead time, safety stock, FEFO exposure, and demand history.
// - Never auto-orders silently: generates structured proposals requiring explicit human authorization.
// - Provides managerial approval workflows and formal conversion into real Purchase Orders.

class MobileReorderItem {
  final String itemId;
  final String productId;
  final String productName;
  final String suggestedSupplierId;
  final String supplierName;
  final int currentStockUnits;
  final int pendingIncomingUnits;
  final int expiringSoonUnits;
  final int effectiveStockUnits;
  final double averageDailyDemand;
  final int leadTimeDays;
  final int safetyStockUnits;
  final int reorderPointUnits;
  final int rawRecommendedUnits;
  int approvedOrderUnits;
  final String packUnit;
  final double estimatedUnitCost;
  double estimatedLineCost;
  final String urgency; // CRITICAL, HIGH, MEDIUM, NORMAL
  final double stockoutRiskDays;
  String? conversionPoId;
  final String rationale;

  MobileReorderItem({
    String? itemId,
    required this.productId,
    this.productName = '',
    required this.suggestedSupplierId,
    this.supplierName = '',
    required this.currentStockUnits,
    this.pendingIncomingUnits = 0,
    this.expiringSoonUnits = 0,
    required this.effectiveStockUnits,
    this.averageDailyDemand = 0.0,
    this.leadTimeDays = 2,
    this.safetyStockUnits = 0,
    this.reorderPointUnits = 0,
    required this.rawRecommendedUnits,
    required this.approvedOrderUnits,
    this.packUnit = 'BASE_UNIT',
    required this.estimatedUnitCost,
    required this.estimatedLineCost,
    this.urgency = 'MEDIUM',
    this.stockoutRiskDays = 0.0,
    this.conversionPoId,
    this.rationale = '',
  }) : itemId = itemId ??
            'ropi-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'product_id': productId,
        'product_name': productName,
        'suggested_supplier_id': suggestedSupplierId,
        'supplier_name': supplierName,
        'current_stock_units': currentStockUnits,
        'pending_incoming_units': pendingIncomingUnits,
        'expiring_soon_units': expiringSoonUnits,
        'effective_stock_units': effectiveStockUnits,
        'average_daily_demand': averageDailyDemand.toStringAsFixed(2),
        'lead_time_days': leadTimeDays,
        'safety_stock_units': safetyStockUnits,
        'reorder_point_units': reorderPointUnits,
        'raw_recommended_units': rawRecommendedUnits,
        'approved_order_units': approvedOrderUnits,
        'pack_unit': packUnit,
        'estimated_unit_cost': estimatedUnitCost.toStringAsFixed(4),
        'estimated_line_cost': estimatedLineCost.toStringAsFixed(4),
        'urgency': urgency,
        'stockout_risk_days': stockoutRiskDays.toStringAsFixed(1),
        'conversion_po_id': conversionPoId,
        'rationale': rationale,
      };
}

class MobileReorderProposal {
  final String proposalId;
  final String proposalNumber;
  final String tenantId;
  final String branchId;
  final DateTime planDate;
  final int planningHorizonDays;
  String status; // DRAFT_PROPOSAL, APPROVED, CONVERTED_TO_PO, DISMISSED
  int totalRecommendedSkus;
  double totalEstimatedCost;
  String? reviewedBy;
  DateTime? reviewedAt;
  String reviewNotes;
  final String notes;
  final List<MobileReorderItem> items;

  MobileReorderProposal({
    required this.proposalId,
    required this.proposalNumber,
    required this.tenantId,
    required this.branchId,
    DateTime? planDate,
    this.planningHorizonDays = 14,
    this.status = 'DRAFT_PROPOSAL',
    this.totalRecommendedSkus = 0,
    this.totalEstimatedCost = 0.0,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes = '',
    this.notes = '',
    List<MobileReorderItem>? items,
  })  : planDate = planDate ?? DateTime.now(),
        items = items ?? [];

  Map<String, dynamic> toJson() => {
        'proposal_id': proposalId,
        'proposal_number': proposalNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'plan_date': planDate.toIso8601String(),
        'planning_horizon_days': planningHorizonDays,
        'status': status,
        'total_recommended_skus': totalRecommendedSkus,
        'total_estimated_cost': totalEstimatedCost.toStringAsFixed(4),
        'reviewed_by': reviewedBy,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'review_notes': reviewNotes,
        'notes': notes,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class MobileReorderPlannerClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileReorderProposal> proposalStore;
  final Map<String, Map<String, dynamic>> poStore;

  static const Set<String> _allowedProcurementRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
    'AUDITOR',
  };

  static const Set<String> _allowedApprovalRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'PROCUREMENT_OFFICER',
  };

  MobileReorderPlannerClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileReorderProposal>? proposalStore,
    Map<String, Map<String, dynamic>>? poStore,
  })  : proposalStore = proposalStore ?? {},
        poStore = poStore ?? {};

  void _assertProcurementRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedProcurementRoles.contains(userRole.toUpperCase())) {
      throw Exception(
          'ERR_STAFF_ROLE_DENIED: Staff role $userRole cannot access reorder planning.');
    }
  }

  void _assertApprovalRole() {
    if (!_allowedApprovalRoles.contains(userRole.toUpperCase())) {
      throw Exception(
          'ERR_STAFF_ROLE_DENIED: Approval requires managerial or procurement officer role.');
    }
  }

  MobileReorderProposal generateReorderPlan({
    int planningHorizonDays = 14,
    List<MobileReorderItem>? calculatedRecommendations,
    String notes = '',
  }) {
    _assertProcurementRole();

    final propId =
        'rop-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final propNum = 'ROP-${DateTime.now().millisecondsSinceEpoch}';

    double totalCost = 0.0;
    final List<MobileReorderItem> validated = [];

    if (calculatedRecommendations != null) {
      for (final itm in calculatedRecommendations) {
        totalCost += itm.estimatedLineCost;
        validated.add(itm);
      }
    }

    final prop = MobileReorderProposal(
      proposalId: propId,
      proposalNumber: propNum,
      tenantId: tenantId,
      branchId: branchId,
      planDate: DateTime.now(),
      planningHorizonDays: planningHorizonDays > 0 ? planningHorizonDays : 14,
      status: 'DRAFT_PROPOSAL',
      totalRecommendedSkus: validated.sizeSafe(),
      totalEstimatedCost: double.parse(totalCost.toStringAsFixed(4)),
      notes: notes,
      items: validated,
    );

    proposalStore[propId] = prop;
    return prop;
  }

  MobileReorderProposal approveReorderPlan({
    required String proposalId,
    String reviewNotes = '',
    Map<String, int>? itemAdjustments,
  }) {
    _assertApprovalRole();

    final prop = proposalStore[proposalId];
    if (prop == null) {
      throw Exception('ERR_PROPOSAL_NOT_FOUND: Proposal $proposalId not found.');
    }

    if (prop.status != 'DRAFT_PROPOSAL') {
      throw Exception(
          'ERR_INVALID_STATUS: Cannot approve proposal in status ${prop.status}');
    }

    double newTotal = 0.0;
    for (final item in prop.items) {
      if (itemAdjustments != null && itemAdjustments.containsKey(item.itemId)) {
        item.approvedOrderUnits = itemAdjustments[item.itemId]! < 0
            ? 0
            : itemAdjustments[item.itemId]!;
        item.estimatedLineCost = double.parse(
            (item.estimatedUnitCost * item.approvedOrderUnits)
                .toStringAsFixed(4));
      }
      newTotal += item.estimatedLineCost;
    }

    prop.status = 'APPROVED';
    prop.reviewedBy = userId;
    prop.reviewedAt = DateTime.now();
    prop.reviewNotes = reviewNotes;
    prop.totalEstimatedCost = double.parse(newTotal.toStringAsFixed(4));

    return prop;
  }

  List<String> convertToPurchaseOrders({required String proposalId}) {
    _assertApprovalRole();

    final prop = proposalStore[proposalId];
    if (prop == null) {
      throw Exception('ERR_PROPOSAL_NOT_FOUND: Proposal $proposalId not found.');
    }

    if (prop.status != 'APPROVED') {
      throw Exception(
          'ERR_PLAN_NOT_APPROVED: Plan must be APPROVED before conversion. Never auto-orders silently.');
    }

    // Group by supplier
    final Map<String, List<MobileReorderItem>> grouped = {};
    for (final item in prop.items) {
      if (item.approvedOrderUnits > 0) {
        grouped
            .putIfAbsent(item.suggestedSupplierId.isNotEmpty
                ? item.suggestedSupplierId
                : 'default', () => [])
            .add(item);
      }
    }

    final List<String> createdPoIds = [];
    for (final entry in grouped.entries) {
      final poId =
          'po-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
      final poNum = 'PO-${DateTime.now().millisecondsSinceEpoch}';

      double poTotal = 0.0;
      final List<Map<String, dynamic>> poItems = [];

      for (final itm in entry.value) {
        poTotal += itm.estimatedLineCost;
        itm.conversionPoId = poId;
        poItems.add({
          'item_id': 'poi-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}',
          'product_id': itm.productId,
          'product_name': itm.productName,
          'pack_unit': itm.packUnit,
          'package_size': 1,
          'ordered_packages': itm.approvedOrderUnits,
          'ordered_quantity': itm.approvedOrderUnits,
          'received_quantity': 0,
          'unit_cost_price': itm.estimatedUnitCost,
          'line_total': itm.estimatedLineCost,
        });
      }

      final po = {
        'po_id': poId,
        'po_number': poNum,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'supplier_id': entry.key,
        'supplier_name': entry.value.first.supplierName,
        'status': 'DRAFT',
        'subtotal_amount': poTotal,
        'total_amount': poTotal,
        'notes': 'Auto-generated from ${prop.proposalNumber}',
        'items': poItems,
        'created_at': DateTime.now().toIso8601String(),
      };

      poStore[poId] = po;
      createdPoIds.add(poId);
    }

    prop.status = 'CONVERTED_TO_PO';
    return createdPoIds;
  }

  MobileReorderProposal dismissReorderPlan({
    required String proposalId,
    required String reason,
  }) {
    _assertProcurementRole();

    final prop = proposalStore[proposalId];
    if (prop == null) {
      throw Exception('ERR_PROPOSAL_NOT_FOUND: Proposal $proposalId not found.');
    }

    if (prop.status == 'CONVERTED_TO_PO') {
      throw Exception(
          'ERR_CANNOT_DISMISS_CONVERTED: Cannot dismiss converted proposal.');
    }

    prop.status = 'DISMISSED';
    prop.reviewNotes =
        '${prop.reviewNotes.isNotEmpty ? "${prop.reviewNotes} | " : ""}Dismissed: $reason';
    return prop;
  }

  MobileReorderProposal getReorderPlan(String proposalId) {
    final prop = proposalStore[proposalId];
    if (prop == null) {
      throw Exception('ERR_PROPOSAL_NOT_FOUND: Proposal $proposalId not found.');
    }
    return prop;
  }

  List<MobileReorderProposal> listReorderPlans({String? statusFilter}) {
    final list = proposalStore.values.toList();
    if (statusFilter == null || statusFilter.isEmpty) {
      return list;
    }
    return list
        .where((p) => p.status.toUpperCase() == statusFilter.toUpperCase())
        .toList();
  }
}

extension SafeListExtension on List {
  int sizeSafe() => length;
}
