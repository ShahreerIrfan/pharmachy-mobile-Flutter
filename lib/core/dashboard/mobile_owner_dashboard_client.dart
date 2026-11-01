// lib/core/dashboard/mobile_owner_dashboard_client.dart
// Architecture Decision: ADR-0101
// Phase 06: Milestone M03 - Offline-First Desktop POS & Owner Visibility (P101)
// Requirement Trace: FR-031, FR-032, FR-033, FR-044, FR-066, FR-070

enum MobileDashboardUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileSalesKpi {
  final String todaySalesBdt;
  final String periodSalesBdt;
  final int totalOrdersCount;
  final String averageOrderValueBdt;

  const MobileSalesKpi({
    required this.todaySalesBdt,
    required this.periodSalesBdt,
    required this.totalOrdersCount,
    required this.averageOrderValueBdt,
  });

  factory MobileSalesKpi.fromJson(Map<String, dynamic> json) {
    return MobileSalesKpi(
      todaySalesBdt: json['today_sales_bdt'] as String? ?? '0.00',
      periodSalesBdt: json['period_sales_bdt'] as String? ?? '0.00',
      totalOrdersCount: json['total_orders_count'] as int? ?? 0,
      averageOrderValueBdt: json['average_order_value_bdt'] as String? ?? '0.00',
    );
  }
}

class MobileProfitabilityKpi {
  final String grossSalesBdt;
  final String cogsBdt;
  final String grossProfitBdt;
  final String grossMarginPercent;
  final String discountsBdt;
  final String netProfitBdt;

  const MobileProfitabilityKpi({
    required this.grossSalesBdt,
    required this.cogsBdt,
    required this.grossProfitBdt,
    required this.grossMarginPercent,
    required this.discountsBdt,
    required this.netProfitBdt,
  });

  factory MobileProfitabilityKpi.fromJson(Map<String, dynamic> json) {
    return MobileProfitabilityKpi(
      grossSalesBdt: json['gross_sales_bdt'] as String? ?? '0.00',
      cogsBdt: json['cogs_bdt'] as String? ?? '0.00',
      grossProfitBdt: json['gross_profit_bdt'] as String? ?? '0.00',
      grossMarginPercent: json['gross_margin_percent'] as String? ?? '0.00',
      discountsBdt: json['discounts_bdt'] as String? ?? '0.00',
      netProfitBdt: json['net_profit_bdt'] as String? ?? '0.00',
    );
  }
}

class MobileCustomerDuesKpi {
  final String totalDuesBdt;
  final int outstandingCustomersCount;
  final int overdueInvoicesCount;

  const MobileCustomerDuesKpi({
    required this.totalDuesBdt,
    required this.outstandingCustomersCount,
    required this.overdueInvoicesCount,
  });

  factory MobileCustomerDuesKpi.fromJson(Map<String, dynamic> json) {
    return MobileCustomerDuesKpi(
      totalDuesBdt: json['total_dues_bdt'] as String? ?? '0.00',
      outstandingCustomersCount: json['outstanding_customers_count'] as int? ?? 0,
      overdueInvoicesCount: json['overdue_invoices_count'] as int? ?? 0,
    );
  }
}

class MobileInventoryKpi {
  final String totalStockValueBdt;
  final int activeBatchesCount;
  final int lowStockItemsCount;
  final int outOfStockItemsCount;

  const MobileInventoryKpi({
    required this.totalStockValueBdt,
    required this.activeBatchesCount,
    required this.lowStockItemsCount,
    required this.outOfStockItemsCount,
  });

  factory MobileInventoryKpi.fromJson(Map<String, dynamic> json) {
    return MobileInventoryKpi(
      totalStockValueBdt: json['total_stock_value_bdt'] as String? ?? '0.00',
      activeBatchesCount: json['active_batches_count'] as int? ?? 0,
      lowStockItemsCount: json['low_stock_items_count'] as int? ?? 0,
      outOfStockItemsCount: json['out_of_stock_items_count'] as int? ?? 0,
    );
  }

  bool get hasStockShortage => lowStockItemsCount > 0 || outOfStockItemsCount > 0;
}

class MobileExpiryKpi {
  final int expiringIn30DaysCount;
  final int expiringIn90DaysCount;
  final int expiredBatchesCount;
  final String expiredStockValueBdt;

  const MobileExpiryKpi({
    required this.expiringIn30DaysCount,
    required this.expiringIn90DaysCount,
    required this.expiredBatchesCount,
    required this.expiredStockValueBdt,
  });

  factory MobileExpiryKpi.fromJson(Map<String, dynamic> json) {
    return MobileExpiryKpi(
      expiringIn30DaysCount: json['expiring_in_30_days_count'] as int? ?? 0,
      expiringIn90DaysCount: json['expiring_in_90_days_count'] as int? ?? 0,
      expiredBatchesCount: json['expired_batches_count'] as int? ?? 0,
      expiredStockValueBdt: json['expired_stock_value_bdt'] as String? ?? '0.00',
    );
  }

  bool get hasCriticalExpiryRisk => expiringIn30DaysCount > 0 || expiredBatchesCount > 0;
}

class MobileSyncHealthKpi {
  final int enrolledDevicesCount;
  final int activeLeasesCount;
  final int unreconciledHeldCount;
  final String syncStatus;
  final String lastSyncAt;

  const MobileSyncHealthKpi({
    required this.enrolledDevicesCount,
    required this.activeLeasesCount,
    required this.unreconciledHeldCount,
    required this.syncStatus,
    required this.lastSyncAt,
  });

  factory MobileSyncHealthKpi.fromJson(Map<String, dynamic> json) {
    return MobileSyncHealthKpi(
      enrolledDevicesCount: json['enrolled_devices_count'] as int? ?? 0,
      activeLeasesCount: json['active_leases_count'] as int? ?? 0,
      unreconciledHeldCount: json['unreconciled_held_count'] as int? ?? 0,
      syncStatus: json['sync_status'] as String? ?? 'HEALTHY',
      lastSyncAt: json['last_sync_at'] as String? ?? '',
    );
  }

  bool get isHealthy => syncStatus.toUpperCase() == 'HEALTHY' && unreconciledHeldCount == 0;
}

class MobileOwnerDashboardData {
  final String tenantId;
  final String tenantName;
  final String? branchFilter;
  final MobileSalesKpi sales;
  final MobileProfitabilityKpi profitability;
  final MobileCustomerDuesKpi dues;
  final MobileInventoryKpi inventory;
  final MobileExpiryKpi expiry;
  final MobileSyncHealthKpi syncHealth;
  final String asOfTimestamp;

  const MobileOwnerDashboardData({
    required this.tenantId,
    required this.tenantName,
    this.branchFilter,
    required this.sales,
    required this.profitability,
    required this.dues,
    required this.inventory,
    required this.expiry,
    required this.syncHealth,
    required this.asOfTimestamp,
  });

  factory MobileOwnerDashboardData.fromJson(Map<String, dynamic> json) {
    return MobileOwnerDashboardData(
      tenantId: json['tenant_id'] as String? ?? '',
      tenantName: json['tenant_name'] as String? ?? '',
      branchFilter: json['branch_filter'] as String?,
      sales: MobileSalesKpi.fromJson(json['sales_summary'] as Map<String, dynamic>? ?? {}),
      profitability: MobileProfitabilityKpi.fromJson(json['profitability_summary'] as Map<String, dynamic>? ?? {}),
      dues: MobileCustomerDuesKpi.fromJson(json['customer_dues_summary'] as Map<String, dynamic>? ?? {}),
      inventory: MobileInventoryKpi.fromJson(json['inventory_summary'] as Map<String, dynamic>? ?? {}),
      expiry: MobileExpiryKpi.fromJson(json['expiry_summary'] as Map<String, dynamic>? ?? {}),
      syncHealth: MobileSyncHealthKpi.fromJson(json['sync_health_summary'] as Map<String, dynamic>? ?? {}),
      asOfTimestamp: json['as_of_timestamp'] as String? ?? '',
    );
  }
}

class MobileOwnerDashboardState {
  final MobileDashboardUiStatus status;
  final MobileOwnerDashboardData? data;
  final String errorMessageEn;
  final String errorMessageBn;

  const MobileOwnerDashboardState({
    required this.status,
    this.data,
    this.errorMessageEn = '',
    this.errorMessageBn = '',
  });

  static MobileOwnerDashboardState success(MobileOwnerDashboardData data) {
    return MobileOwnerDashboardState(
      status: MobileDashboardUiStatus.success,
      data: data,
    );
  }

  static MobileOwnerDashboardState permissionDenied(String role) {
    return MobileOwnerDashboardState(
      status: MobileDashboardUiStatus.permissionDenied,
      errorMessageEn: "Access denied for role '$role'. Only pharmacy owners and branch managers can access executive dashboards.",
      errorMessageBn: "আপনার রোলে ('$role') এক্সিকিউটিভ ড্যাশবোর্ড দেখার অনুমতি নেই। শুধুমাত্র ফার্মেসি মালিক ও ব্রাঞ্চ ম্যানেজারদের প্রবেশাধিকার আছে।",
    );
  }

  static MobileOwnerDashboardState offline() {
    return const MobileOwnerDashboardState(
      status: MobileDashboardUiStatus.offline,
      errorMessageEn: 'Device is offline. Executive metrics require cloud server synchronization.',
      errorMessageBn: 'ডিভাইসটি অফলাইনে আছে। এক্সিকিউটিভ তথ্য দেখতে ক্লাউড সার্ভারের সাথে সক্রিয় ইন্টারনেট সংযোগ প্রয়োজন।',
    );
  }
}
