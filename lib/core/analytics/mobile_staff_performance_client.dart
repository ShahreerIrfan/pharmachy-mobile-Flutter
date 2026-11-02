// lib/core/analytics/mobile_staff_performance_client.dart
// Architecture Decision: ADR-0115 (P115)
// Phase 06: Milestone M03 - Offline-First Desktop POS & Owner Visibility.

enum MobileStaffPerformanceUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

class MobileStaffPerformanceRecord {
  final String snapshotId;
  final String tenantId;
  final String? branchId;
  final String staffId;
  final String staffName;
  final String staffRole;
  final String metricDate;
  final int totalSalesCount;
  final double totalSalesAmount;
  final int totalRefundsCount;
  final double totalRefundsAmount;
  final double netRevenue;
  final double reconciliationVarianceAmount;
  final String reconciliationStatus;
  final int reportingFreshnessSeconds;

  const MobileStaffPerformanceRecord({
    required this.snapshotId,
    required this.tenantId,
    this.branchId,
    required this.staffId,
    required this.staffName,
    required this.staffRole,
    required this.metricDate,
    required this.totalSalesCount,
    required this.totalSalesAmount,
    required this.totalRefundsCount,
    required this.totalRefundsAmount,
    required this.netRevenue,
    required this.reconciliationVarianceAmount,
    required this.reconciliationStatus,
    required this.reportingFreshnessSeconds,
  });

  factory MobileStaffPerformanceRecord.fromJson(Map<String, dynamic> json) {
    return MobileStaffPerformanceRecord(
      snapshotId: json['snapshot_id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      staffId: json['staff_id']?.toString() ?? '',
      staffName: json['staff_name']?.toString() ?? '',
      staffRole: json['staff_role']?.toString() ?? 'CASHIER',
      metricDate: json['metric_date']?.toString() ?? '',
      totalSalesCount: (json['total_sales_count'] as num?)?.toInt() ?? 0,
      totalSalesAmount: double.tryParse(json['total_sales_amount']?.toString() ?? '0.0') ?? 0.0,
      totalRefundsCount: (json['total_refunds_count'] as num?)?.toInt() ?? 0,
      totalRefundsAmount: double.tryParse(json['total_refunds_amount']?.toString() ?? '0.0') ?? 0.0,
      netRevenue: double.tryParse(json['net_revenue']?.toString() ?? '0.0') ?? 0.0,
      reconciliationVarianceAmount: double.tryParse(json['reconciliation_variance_amount']?.toString() ?? '0.0') ?? 0.0,
      reconciliationStatus: json['reconciliation_status']?.toString() ?? 'BALANCED',
      reportingFreshnessSeconds: (json['reporting_freshness_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class MobileScopedMetricsResult {
  final MobileStaffPerformanceUiStatus uiStatus;
  final List<MobileStaffPerformanceRecord> records;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileScopedMetricsResult({
    required this.uiStatus,
    this.records = const [],
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileScopedMetricsResult.success(List<MobileStaffPerformanceRecord> records) {
    return MobileScopedMetricsResult(
      uiStatus: records.isEmpty ? MobileStaffPerformanceUiStatus.empty : MobileStaffPerformanceUiStatus.success,
      records: records,
      messageEn: 'Staff performance metrics loaded successfully.',
      messageBn: 'স্টাফ পারফরম্যান্স মেট্রিক সফলভাবে লোড হয়েছে।',
    );
  }

  factory MobileScopedMetricsResult.error({
    required MobileStaffPerformanceUiStatus status,
    required String errorCode,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileScopedMetricsResult(
      uiStatus: status,
      errorCode: errorCode,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileStaffPerformanceClient {
  MobileScopedMetricsResult filterMetrics({
    required List<MobileStaffPerformanceRecord> allRecords,
    required String callerRole,
    required String callerTenantId,
    String? callerBranchId,
    String? callerStaffId,
    String? targetTenantId,
    String? targetBranchId,
    String? targetStaffId,
  }) {
    if (targetTenantId != null && targetTenantId != callerTenantId && callerRole != 'SUPERADMIN') {
      return MobileScopedMetricsResult.error(
        status: MobileStaffPerformanceUiStatus.permissionDenied,
        errorCode: 'ERR_CROSS_TENANT_VIOLATION',
        msgEn: 'Cross-tenant metrics access forbidden.',
        msgBn: 'অন্য টেন্যান্টের পারফরম্যান্স মেট্রিক দেখার অনুমতি নেই।',
      );
    }

    final isOwner = callerRole == 'PHARMACY_OWNER' || callerRole == 'SUPERADMIN';
    final isManager = callerRole == 'BRANCH_MANAGER';

    final List<MobileStaffPerformanceRecord> filtered = [];

    if (isOwner) {
      for (final r in allRecords) {
        if (targetBranchId != null && targetBranchId != r.branchId) continue;
        if (targetStaffId != null && targetStaffId != r.staffId) continue;
        filtered.add(r);
      }
    } else if (isManager) {
      if (targetBranchId != null && targetBranchId != callerBranchId) {
        return MobileScopedMetricsResult.error(
          status: MobileStaffPerformanceUiStatus.permissionDenied,
          errorCode: 'ERR_CROSS_BRANCH_VIOLATION',
          msgEn: 'Branch managers cannot inspect performance of other branches.',
          msgBn: 'শাখা ব্যবস্থাপক অন্য শাখার মেট্রিক দেখতে পারেন না।',
        );
      }
      for (final r in allRecords) {
        if (callerBranchId != r.branchId) continue;
        if (targetStaffId != null && targetStaffId != r.staffId) continue;
        filtered.add(r);
      }
    } else {
      // Cashier: Self-only
      if (targetStaffId != null && targetStaffId != callerStaffId) {
        return MobileScopedMetricsResult.error(
          status: MobileStaffPerformanceUiStatus.permissionDenied,
          errorCode: 'ERR_PERMISSION_DENIED',
          msgEn: 'Staff are strictly restricted to their own performance metrics.',
          msgBn: 'স্টাফ শুধুমাত্র নিজের পারফরম্যান্স মেট্রিক দেখতে পারেন।',
        );
      }
      for (final r in allRecords) {
        if (callerStaffId == r.staffId) {
          filtered.add(r);
        }
      }
    }

    return MobileScopedMetricsResult.success(filtered);
  }
}

