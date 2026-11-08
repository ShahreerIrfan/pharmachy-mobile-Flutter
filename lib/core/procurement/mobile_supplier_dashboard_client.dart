// mobile_supplier_dashboard_client.dart
// Architecture Decision: ADR-0199 (P199).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client for Supplier Operations Dashboard:
// - Aggregates open orders, overdue deliveries, due balances, and low-stock sourcing opportunities.
// - Generates auditable snapshots with SHA-256 cryptographic hashes.
// - Restricts Cashier access with role verification.

import 'dart:convert';
import 'package:crypto/crypto.dart';

class MobileOpenOrderItem {
  final String poId;
  final String poNumber;
  final String supplierName;
  final String status;
  final double totalAmount;

  MobileOpenOrderItem({
    required this.poId,
    required this.poNumber,
    required this.supplierName,
    required this.status,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() => {
        'po_id': poId,
        'po_number': poNumber,
        'supplier_name': supplierName,
        'status': status,
        'total_amount': totalAmount,
      };
}

class MobileOverdueDeliveryItem {
  final String poId;
  final String poNumber;
  final String supplierName;
  final String expectedDeliveryDate;
  final int daysOverdue;
  final double totalAmount;

  MobileOverdueDeliveryItem({
    required this.poId,
    required this.poNumber,
    required this.supplierName,
    required this.expectedDeliveryDate,
    required this.daysOverdue,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() => {
        'po_id': poId,
        'po_number': poNumber,
        'supplier_name': supplierName,
        'expected_delivery_date': expectedDeliveryDate,
        'days_overdue': daysOverdue,
        'total_amount': totalAmount,
      };
}

class MobileSupplierDueItem {
  final String supplierId;
  final String supplierName;
  final int paymentTermsDays;
  final double currentBalance;
  final bool isOverdue;

  MobileSupplierDueItem({
    required this.supplierId,
    required this.supplierName,
    required this.paymentTermsDays,
    required this.currentBalance,
    required this.isOverdue,
  });

  Map<String, dynamic> toJson() => {
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'payment_terms_days': paymentTermsDays,
        'current_balance': currentBalance,
        'is_overdue': isOverdue,
      };
}

class MobileLowStockSourcingItem {
  final String productId;
  final String brandName;
  final int currentStock;
  final int recommendedReorderQty;
  final String preferredSupplierName;
  final double quotedUnitCost;
  final double estimatedCost;

  MobileLowStockSourcingItem({
    required this.productId,
    required this.brandName,
    required this.currentStock,
    required this.recommendedReorderQty,
    required this.preferredSupplierName,
    required this.quotedUnitCost,
    required this.estimatedCost,
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'brand_name': brandName,
        'current_stock': currentStock,
        'recommended_reorder_qty': recommendedReorderQty,
        'preferred_supplier_name': preferredSupplierName,
        'quoted_unit_cost': quotedUnitCost,
        'estimated_cost': estimatedCost,
      };
}

class MobileSupplierDashboardSummary {
  final int openOrdersCount;
  final double openOrdersValue;
  final List<MobileOpenOrderItem> openOrders;

  final int overdueDeliveriesCount;
  final double overdueDeliveriesValue;
  final List<MobileOverdueDeliveryItem> overdueDeliveries;

  final double totalDueBalance;
  final List<MobileSupplierDueItem> supplierDues;

  final int lowStockOpportunitiesCount;
  final double estimatedReorderCost;
  final List<MobileLowStockSourcingItem> lowStockItems;

  final int activeSuppliersCount;

  MobileSupplierDashboardSummary({
    required this.openOrdersCount,
    required this.openOrdersValue,
    this.openOrders = const [],
    required this.overdueDeliveriesCount,
    required this.overdueDeliveriesValue,
    this.overdueDeliveries = const [],
    required this.totalDueBalance,
    this.supplierDues = const [],
    required this.lowStockOpportunitiesCount,
    required this.estimatedReorderCost,
    this.lowStockItems = const [],
    required this.activeSuppliersCount,
  });

  Map<String, dynamic> toJson() => {
        'open_orders_count': openOrdersCount,
        'open_orders_value': openOrdersValue,
        'open_orders': openOrders.map((e) => e.toJson()).toList(),
        'overdue_deliveries_count': overdueDeliveriesCount,
        'overdue_deliveries_value': overdueDeliveriesValue,
        'overdue_deliveries': overdueDeliveries.map((e) => e.toJson()).toList(),
        'total_due_balance': totalDueBalance,
        'supplier_dues': supplierDues.map((e) => e.toJson()).toList(),
        'low_stock_opportunities_count': lowStockOpportunitiesCount,
        'estimated_reorder_cost': estimatedReorderCost,
        'low_stock_items': lowStockItems.map((e) => e.toJson()).toList(),
        'active_suppliers_count': activeSuppliersCount,
      };
}

class MobileSupplierDashboardSnapshot {
  final String snapshotId;
  final String tenantId;
  final String branchId;
  final MobileSupplierDashboardSummary summary;
  final String immutableVerificationHash;
  final String notes;
  final String generatedBy;
  final DateTime generatedAt;

  MobileSupplierDashboardSnapshot({
    required this.snapshotId,
    required this.tenantId,
    required this.branchId,
    required this.summary,
    required this.immutableVerificationHash,
    this.notes = '',
    required this.generatedBy,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'snapshot_id': snapshotId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'summary': summary.toJson(),
        'immutable_verification_hash': immutableVerificationHash,
        'notes': notes,
        'generated_by': generatedBy,
        'generated_at': generatedAt.toIso8601String(),
      };
}

class MobileSupplierDashboardClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileSupplierDashboardSnapshot> snapshotStore;

  static const Set<String> _allowedRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
    'AUDITOR',
  };

  MobileSupplierDashboardClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileSupplierDashboardSnapshot>? snapshotStore,
  }) : snapshotStore = snapshotStore ?? {};

  void _assertRolePermission() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedRoles.contains(userRole.toUpperCase())) {
      throw Exception(
          'ERR_STAFF_ROLE_DENIED: Staff role $userRole cannot view supplier dashboard.');
    }
  }

  static String computeVerificationHash({
    required String snapshotId,
    required String tenantId,
    required int openOrdersCount,
    required double openOrdersValue,
    required int overdueDeliveriesCount,
    required double totalDueBalance,
    required int lowStockCount,
  }) {
    final raw =
        '$snapshotId|$tenantId|$openOrdersCount|${openOrdersValue.toStringAsFixed(4)}|$overdueDeliveriesCount|${totalDueBalance.toStringAsFixed(4)}|$lowStockCount';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  MobileSupplierDashboardSummary compileSummary({
    List<MobileOpenOrderItem> orders = const [],
    List<MobileOverdueDeliveryItem> overdue = const [],
    List<MobileSupplierDueItem> dues = const [],
    List<MobileLowStockSourcingItem> lowStock = const [],
    int activeSuppliersCount = 0,
  }) {
    _assertRolePermission();

    double openVal = 0.0;
    for (final o in orders) {
      openVal += o.totalAmount;
    }

    double overdueVal = 0.0;
    for (final d in overdue) {
      overdueVal += d.totalAmount;
    }

    double dueBal = 0.0;
    for (final s in dues) {
      dueBal += s.currentBalance;
    }

    double restockCost = 0.0;
    for (final l in lowStock) {
      restockCost += l.estimatedCost;
    }

    return MobileSupplierDashboardSummary(
      openOrdersCount: orders.length,
      openOrdersValue: openVal,
      openOrders: orders,
      overdueDeliveriesCount: overdue.length,
      overdueDeliveriesValue: overdueVal,
      overdueDeliveries: overdue,
      totalDueBalance: dueBal,
      supplierDues: dues,
      lowStockOpportunitiesCount: lowStock.length,
      estimatedReorderCost: restockCost,
      lowStockItems: lowStock,
      activeSuppliersCount: activeSuppliersCount,
    );
  }

  MobileSupplierDashboardSnapshot createSnapshot(
      MobileSupplierDashboardSummary summary,
      [String notes = '']) {
    _assertRolePermission();

    final snapId =
        'sdash-${snapshotStore.length + 1}-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final now = DateTime.now();

    final hash = computeVerificationHash(
      snapshotId: snapId,
      tenantId: tenantId,
      openOrdersCount: summary.openOrdersCount,
      openOrdersValue: summary.openOrdersValue,
      overdueDeliveriesCount: summary.overdueDeliveriesCount,
      totalDueBalance: summary.totalDueBalance,
      lowStockCount: summary.lowStockOpportunitiesCount,
    );

    final snapshot = MobileSupplierDashboardSnapshot(
      snapshotId: snapId,
      tenantId: tenantId,
      branchId: branchId,
      summary: summary,
      immutableVerificationHash: hash,
      notes: notes,
      generatedBy: userId,
      generatedAt: now,
    );

    snapshotStore[snapId] = snapshot;
    return snapshot;
  }

  MobileSupplierDashboardSnapshot getSnapshot(String snapshotId) {
    final snap = snapshotStore[snapshotId];
    if (snap == null) {
      throw Exception('ERR_SNAPSHOT_NOT_FOUND: Snapshot $snapshotId not found.');
    }
    return snap;
  }

  List<MobileSupplierDashboardSnapshot> listSnapshots() {
    final list = snapshotStore.values.toList();
    list.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return list;
  }
}

