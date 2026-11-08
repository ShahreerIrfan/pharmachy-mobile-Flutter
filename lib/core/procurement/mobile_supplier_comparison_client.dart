// mobile_supplier_comparison_client.dart
// Architecture Decision: ADR-0195 (P195).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing Multi-Supplier Comparison:
// - Compares authorized suppliers on net unit costs, package size, delivery reliability,
//   nominal/historical lead times, and approved credit terms.
// - Evaluates multi-factor composite scores and recommends optimal vendors.
// - Generates audited comparison evaluations and converts winning quotes to Purchase Orders.

import 'dart:math' as math;

class MobileComparisonLine {
  final String lineId;
  final String supplierId;
  final String supplierName;
  final String packageType;
  final int packageSize;
  final double packageCostPrice;
  final double unitCostPrice;
  final double mrpUnit;
  final double discountPercentage;
  final double effectiveNetUnitCost;
  final int minimumOrderQuantity;
  final int leadTimeDays;
  final int paymentTermsDays;
  final double deliveryReliabilityScore;
  final boolean proofOfOriginVerified;
  int compositeRank;
  double compositeScore;
  bool isRecommended;
  final String notes;

  MobileComparisonLine({
    String? lineId,
    required this.supplierId,
    this.supplierName = '',
    this.packageType = 'BOX',
    this.packageSize = 1,
    this.packageCostPrice = 0.0,
    required this.unitCostPrice,
    this.mrpUnit = 0.0,
    this.discountPercentage = 0.0,
    double? effectiveNetUnitCost,
    this.minimumOrderQuantity = 1,
    this.leadTimeDays = 2,
    this.paymentTermsDays = 30,
    this.deliveryReliabilityScore = 100.0,
    this.proofOfOriginVerified = true,
    this.compositeRank = 1,
    this.compositeScore = 0.0,
    this.isRecommended = false,
    this.notes = '',
  })  : lineId = lineId ??
            'scl-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}',
        effectiveNetUnitCost = effectiveNetUnitCost ??
            double.parse((unitCostPrice * (1.0 - (discountPercentage / 100.0)))
                .toStringAsFixed(4));

  Map<String, dynamic> toJson() => {
        'line_id': lineId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'package_type': packageType,
        'package_size': packageSize,
        'package_cost_price': packageCostPrice.toStringAsFixed(4),
        'unit_cost_price': unitCostPrice.toStringAsFixed(4),
        'mrp_unit': mrpUnit.toStringAsFixed(4),
        'discount_percentage': discountPercentage.toStringAsFixed(2),
        'effective_net_unit_cost': effectiveNetUnitCost.toStringAsFixed(4),
        'minimum_order_quantity': minimumOrderQuantity,
        'lead_time_days': leadTimeDays,
        'payment_terms_days': paymentTermsDays,
        'delivery_reliability_score':
            deliveryReliabilityScore.toStringAsFixed(2),
        'proof_of_origin_verified': proofOfOriginVerified,
        'composite_rank': compositeRank,
        'composite_score': compositeScore.toStringAsFixed(2),
        'is_recommended': isRecommended,
        'notes': notes,
      };
}

typedef boolean = bool;

class MobileComparisonEvaluation {
  final String evaluationId;
  final String evaluationNumber;
  final String tenantId;
  final String branchId;
  final String productId;
  final String productName;
  final int targetOrderQuantity;
  String status; // DRAFT, FINALIZED, ORDER_PLACED, ARCHIVED
  String? selectedSupplierId;
  String? selectedSupplierName;
  String selectionReason;
  String? evaluatedBy;
  DateTime? evaluatedAt;
  String? createdPoId;
  final String notes;
  final List<MobileComparisonLine> lines;

  MobileComparisonEvaluation({
    required this.evaluationId,
    required this.evaluationNumber,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    this.productName = '',
    this.targetOrderQuantity = 100,
    this.status = 'DRAFT',
    this.selectedSupplierId,
    this.selectedSupplierName,
    this.selectionReason = '',
    this.evaluatedBy,
    this.evaluatedAt,
    this.createdPoId,
    this.notes = '',
    List<MobileComparisonLine>? lines,
  }) : lines = lines ?? [];

  Map<String, dynamic> toJson() => {
        'evaluation_id': evaluationId,
        'evaluation_number': evaluationNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'product_id': productId,
        'product_name': productName,
        'target_order_quantity': targetOrderQuantity,
        'status': status,
        'selected_supplier_id': selectedSupplierId,
        'selected_supplier_name': selectedSupplierName,
        'selection_reason': selectionReason,
        'evaluated_by': evaluatedBy,
        'evaluated_at': evaluatedAt?.toIso8601String(),
        'created_po_id': createdPoId,
        'notes': notes,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}

class MobileSupplierComparisonClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileComparisonEvaluation> evaluationStore;
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

  static const Set<String> _allowedManagerialRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'PROCUREMENT_OFFICER',
  };

  MobileSupplierComparisonClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileComparisonEvaluation>? evaluationStore,
    Map<String, Map<String, dynamic>>? poStore,
  })  : evaluationStore = evaluationStore ?? {},
        poStore = poStore ?? {};

  void _assertProcurementRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedProcurementRoles.contains(userRole.toUpperCase())) {
      throw Exception(
          'ERR_STAFF_ROLE_DENIED: Staff role $userRole cannot access supplier comparisons.');
    }
  }

  void _assertManagerialRole() {
    if (!_allowedManagerialRoles.contains(userRole.toUpperCase())) {
      throw Exception(
          'ERR_STAFF_ROLE_DENIED: Managerial role required for supplier selection and PO creation.');
    }
  }

  List<MobileComparisonLine> rankAndScoreLines(
      List<MobileComparisonLine> rawLines) {
    if (rawLines.isEmpty) return [];

    final scored = List<MobileComparisonLine>.from(rawLines);

    double minCost = scored.first.effectiveNetUnitCost;
    int minLt = scored.first.leadTimeDays;

    for (final l in scored) {
      if (l.effectiveNetUnitCost < minCost) minCost = l.effectiveNetUnitCost;
      if (l.leadTimeDays < minLt) minLt = l.leadTimeDays;
    }

    for (final l in scored) {
      // Cost score (40%): ratio minCost / effectiveNetUnitCost * 40
      final double effC = l.effectiveNetUnitCost > 0 ? l.effectiveNetUnitCost : 1.0;
      final double costFactor = math.min(1.0, minCost / effC);
      final costScore = costFactor * 40.0;

      // Reliability score (30%)
      final relScore = (l.deliveryReliabilityScore / 100.0) * 30.0;

      // Lead time score (20%): ratio minLt / leadTimeDays * 20
      final int lt = math.max(1, l.leadTimeDays);
      final double ltFactor = math.min(1.0, minLt / lt.toDouble());
      final ltScore = ltFactor * 20.0;

      // Payment terms score (10%)
      final termsCap = math.min(60, l.paymentTermsDays);
      final termsScore = (termsCap / 60.0) * 10.0;

      l.compositeScore = double.parse(
          (costScore + relScore + ltScore + termsScore).toStringAsFixed(2));
    }

    scored.sort((a, b) {
      final cmp = b.compositeScore.compareTo(a.compositeScore);
      if (cmp != 0) return cmp;
      return a.effectiveNetUnitCost.compareTo(b.effectiveNetUnitCost);
    });

    for (int i = 0; i < scored.length; i++) {
      scored[i].compositeRank = i + 1;
      scored[i].isRecommended = (i == 0);
    }

    return scored;
  }

  MobileComparisonEvaluation createComparisonEvaluation({
    required String productId,
    String productName = '',
    int targetOrderQuantity = 100,
    required List<MobileComparisonLine> rawLines,
    String notes = '',
  }) {
    _assertProcurementRole();

    final evalId =
        'sce-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final evalNum = 'SCE-${DateTime.now().millisecondsSinceEpoch}';

    final rankedLines = rankAndScoreLines(rawLines);

    final eval = MobileComparisonEvaluation(
      evaluationId: evalId,
      evaluationNumber: evalNum,
      tenantId: tenantId,
      branchId: branchId,
      productId: productId,
      productName: productName,
      targetOrderQuantity: targetOrderQuantity > 0 ? targetOrderQuantity : 100,
      status: 'DRAFT',
      evaluatedBy: userId,
      evaluatedAt: DateTime.now(),
      notes: notes,
      lines: rankedLines,
    );

    evaluationStore[evalId] = eval;
    return eval;
  }

  Map<String, dynamic> selectSupplierAndCreatePo({
    required String evaluationId,
    required String selectedSupplierId,
    required String selectionReason,
    int? orderQuantity,
  }) {
    _assertManagerialRole();

    final eval = evaluationStore[evaluationId];
    if (eval == null) {
      throw Exception('ERR_EVALUATION_NOT_FOUND: Evaluation $evaluationId not found.');
    }

    if (eval.status == 'ORDER_PLACED') {
      throw Exception(
          'ERR_ORDER_ALREADY_PLACED: Order ${eval.createdPoId} already placed.');
    }

    final selectedLine = eval.lines.firstWhere(
      (l) => l.supplierId == selectedSupplierId,
      orElse: () => throw Exception(
          'ERR_SUPPLIER_NOT_IN_COMPARISON: Supplier $selectedSupplierId not in evaluation.'),
    );

    final int qty = (orderQuantity != null && orderQuantity > 0)
        ? orderQuantity
        : eval.targetOrderQuantity;

    if (qty < selectedLine.minimumOrderQuantity) {
      throw Exception(
          'ERR_BELOW_MINIMUM_ORDER_QTY: Quantity $qty is below MOQ ${selectedLine.minimumOrderQuantity}');
    }

    final poId =
        'po-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final poNum = 'PO-${DateTime.now().millisecondsSinceEpoch}';

    final int pkgSize = math.max(1, selectedLine.packageSize);
    final int orderedPackages = (qty / pkgSize).ceil();
    final int actualQty = orderedPackages * pkgSize;

    final double subtotal = double.parse(
        (selectedLine.unitCostPrice * actualQty).toStringAsFixed(4));
    final double discountAmount = double.parse(
        (subtotal * (selectedLine.discountPercentage / 100.0))
            .toStringAsFixed(4));
    final double total = double.parse((subtotal - discountAmount).toStringAsFixed(4));

    final poItem = {
      'item_id': 'poi-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}',
      'product_id': eval.productId,
      'product_name': eval.productName,
      'pack_unit': selectedLine.packageType,
      'package_size': pkgSize,
      'ordered_packages': orderedPackages,
      'ordered_quantity': actualQty,
      'received_quantity': 0,
      'unit_cost_price': selectedLine.unitCostPrice,
      'discount_percentage': selectedLine.discountPercentage,
      'line_total': total,
      'notes': 'Rank #${selectedLine.compositeRank} (Score ${selectedLine.compositeScore})',
    };

    final po = {
      'po_id': poId,
      'po_number': poNum,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'supplier_id': selectedSupplierId,
      'supplier_name': selectedLine.supplierName,
      'status': 'DRAFT',
      'payment_terms_days': selectedLine.paymentTermsDays,
      'subtotal_amount': subtotal,
      'discount_amount': discountAmount,
      'total_amount': total,
      'notes': 'Generated from ${eval.evaluationNumber}. Reason: $selectionReason',
      'items': [poItem],
      'created_at': DateTime.now().toIso8601String(),
    };

    poStore[poId] = po;

    eval.status = 'ORDER_PLACED';
    eval.selectedSupplierId = selectedSupplierId;
    eval.selectedSupplierName = selectedLine.supplierName;
    eval.selectionReason = selectionReason;
    eval.createdPoId = poId;
    eval.evaluatedBy = userId;
    eval.evaluatedAt = DateTime.now();

    return po;
  }

  MobileComparisonEvaluation getEvaluation(String evaluationId) {
    final eval = evaluationStore[evaluationId];
    if (eval == null) {
      throw Exception('ERR_EVALUATION_NOT_FOUND: Evaluation $evaluationId not found.');
    }
    return eval;
  }

  List<MobileComparisonEvaluation> listEvaluations({String? statusFilter}) {
    final list = evaluationStore.values.toList();
    if (statusFilter == null || statusFilter.isEmpty) return list;
    return list
        .where((e) => e.status.toUpperCase() == statusFilter.toUpperCase())
        .toList();
  }
}
