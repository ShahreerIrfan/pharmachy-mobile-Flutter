// mobile_expense_budget_client.dart
// Architecture Decision: ADR-0296 (P296).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class ExpenseBudgetPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  ExpenseBudgetPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class ExpenseBudgetValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  ExpenseBudgetValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

enum BudgetUiState {
  idle,
  loading,
  loaded,
  empty,
  offlineCache,
  permissionDenied,
  error,
}

class ExpenseBudgetDto {
  final String budgetId;
  final String tenantId;
  final String? branchId;
  final String branchName;
  final String? categoryId;
  final String categoryCode;
  final String categoryName;
  final String periodType;
  final int fiscalYear;
  final int? fiscalMonth;
  final String plannedAmountBdt;
  final String actualSpentBdt;
  final String remainingBdt;
  final String utilizationPct;
  final String warningThresholdPct;
  final String criticalThresholdPct;
  final String enforcementMode;
  final bool requireManagerApprovalOnExceed;
  final String healthStatus;
  final String status;

  ExpenseBudgetDto({
    required this.budgetId,
    required this.tenantId,
    this.branchId,
    required this.branchName,
    this.categoryId,
    required this.categoryCode,
    required this.categoryName,
    required this.periodType,
    required this.fiscalYear,
    this.fiscalMonth,
    required this.plannedAmountBdt,
    required this.actualSpentBdt,
    required this.remainingBdt,
    required this.utilizationPct,
    required this.warningThresholdPct,
    required this.criticalThresholdPct,
    required this.enforcementMode,
    required this.requireManagerApprovalOnExceed,
    required this.healthStatus,
    required this.status,
  });

  factory ExpenseBudgetDto.fromJson(Map<String, dynamic> json) {
    return ExpenseBudgetDto(
      budgetId: json['budget_id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      branchName: json['branch_name']?.toString() ?? 'All Branches (Consolidated)',
      categoryId: json['category_id']?.toString(),
      categoryCode: json['category_code']?.toString() ?? 'ALL_CATEGORIES',
      categoryName: json['category_name']?.toString() ?? 'All Operating Categories',
      periodType: json['period_type']?.toString() ?? 'MONTHLY',
      fiscalYear: (json['fiscal_year'] as num?)?.toInt() ?? 2026,
      fiscalMonth: (json['fiscal_month'] as num?)?.toInt(),
      plannedAmountBdt: json['planned_amount_bdt']?.toString() ?? '0.00',
      actualSpentBdt: json['actual_spent_bdt']?.toString() ?? '0.00',
      remainingBdt: json['remaining_bdt']?.toString() ?? '0.00',
      utilizationPct: json['utilization_pct']?.toString() ?? '0.00',
      warningThresholdPct: json['warning_threshold_pct']?.toString() ?? '80.00',
      criticalThresholdPct: json['critical_threshold_pct']?.toString() ?? '100.00',
      enforcementMode: json['enforcement_mode']?.toString() ?? 'REQUIRE_APPROVAL',
      requireManagerApprovalOnExceed: json['require_manager_approval_on_exceed'] as bool? ?? true,
      healthStatus: json['health_status']?.toString() ?? 'HEALTHY',
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }

  Map<String, String> localizedBadge() {
    switch (healthStatus.toUpperCase()) {
      case 'EXCEEDED':
        return {'en': 'Budget Exceeded', 'bn': 'বাজেট অতিক্রম করেছে'};
      case 'WARNING':
        return {'en': 'Approaching Limit', 'bn': 'সীমার কাছাকাছি'};
      default:
        return {'en': 'Within Budget', 'bn': 'বাজেটের মধ্যে আছে'};
    }
  }
}

class ExpenseBudgetEvaluationDto {
  final String overallStatus;
  final bool hardBlocked;
  final bool requiresSeniorOverride;
  final int matchedBudgetCount;

  ExpenseBudgetEvaluationDto({
    required this.overallStatus,
    required this.hardBlocked,
    required this.requiresSeniorOverride,
    required this.matchedBudgetCount,
  });

  factory ExpenseBudgetEvaluationDto.fromJson(Map<String, dynamic> json) {
    return ExpenseBudgetEvaluationDto(
      overallStatus: json['overall_status']?.toString() ?? 'WITHIN_BUDGET',
      hardBlocked: json['hard_blocked'] as bool? ?? false,
      requiresSeniorOverride: json['requires_senior_override'] as bool? ?? false,
      matchedBudgetCount: (json['matched_budget_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class MobileExpenseBudgetClient {
  static const Set<String> _viewRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'BRANCH_MANAGER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> _manageRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> _enforcementModes = {
    'ADVISORY_ALERT',
    'REQUIRE_APPROVAL',
    'HARD_STOP',
  };

  final String tenantId;
  final String branchId;
  final String userRole;

  BudgetUiState uiState = BudgetUiState.idle;
  List<ExpenseBudgetDto> _offlineCache = [];

  MobileExpenseBudgetClient({
    required this.tenantId,
    required this.branchId,
    required String userRole,
  }) : userRole = userRole.toUpperCase();

  bool canView({String? targetBranchId}) {
    if (!_viewRoles.contains(userRole)) return false;
    if (userRole == 'BRANCH_MANAGER' &&
        targetBranchId != null &&
        targetBranchId.isNotEmpty &&
        targetBranchId != branchId) {
      return false;
    }
    return true;
  }

  bool canManage() => _manageRoles.contains(userRole);

  void assertViewAuthorized({String? targetBranchId}) {
    if (!canView(targetBranchId: targetBranchId)) {
      uiState = BudgetUiState.permissionDenied;
      throw ExpenseBudgetPermissionException(
        errorCode: 'ERR_BUDGET_VIEW_DENIED',
        messageEn: 'You do not have permission to view expense budgets for this scope.',
        messageBn: 'এই শাখার খরচের বাজেট দেখার অনুমতি আপনার নেই।',
      );
    }
  }

  void assertManageAuthorized() {
    if (!canManage()) {
      uiState = BudgetUiState.permissionDenied;
      throw ExpenseBudgetPermissionException(
        errorCode: 'ERR_BUDGET_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can modify expense budgets.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার খরচের বাজেট পরিবর্তন করতে পারেন।',
      );
    }
  }

  Map<String, dynamic> buildCreatePayload({
    String? targetBranchId,
    String? categoryId,
    String periodType = 'MONTHLY',
    required int fiscalYear,
    int? fiscalMonth,
    required String plannedAmountBdt,
    String warningThresholdPct = '80.00',
    String criticalThresholdPct = '100.00',
    String enforcementMode = 'REQUIRE_APPROVAL',
    String notes = '',
  }) {
    assertManageAuthorized();
    final parsedAmt = double.tryParse(plannedAmountBdt) ?? 0.0;
    if (parsedAmt <= 0) {
      throw ExpenseBudgetValidationException(
        errorCode: 'ERR_INVALID_PLANNED_AMOUNT',
        messageEn: 'Planned budget amount must be greater than zero.',
        messageBn: 'পরিকল্পিত বাজেটের পরিমাণ শূন্যের চেয়ে বেশি হতে হবে।',
      );
    }
    final mode = enforcementMode.toUpperCase();
    if (!_enforcementModes.contains(mode)) {
      throw ExpenseBudgetValidationException(
        errorCode: 'ERR_INVALID_ENFORCEMENT_MODE',
        messageEn: 'Unsupported budget enforcement mode: $mode',
        messageBn: 'অবৈধ বাজেট এনফোর্সমেন্ট মোড: $mode',
      );
    }

    return {
      'tenant_id': tenantId,
      if (targetBranchId != null && targetBranchId.isNotEmpty) 'branch_id': targetBranchId,
      if (categoryId != null && categoryId.isNotEmpty) 'category_id': categoryId,
      'period_type': periodType.toUpperCase(),
      'fiscal_year': fiscalYear,
      if (fiscalMonth != null) 'fiscal_month': fiscalMonth,
      'planned_amount_bdt': plannedAmountBdt,
      'warning_threshold_pct': warningThresholdPct,
      'critical_threshold_pct': criticalThresholdPct,
      'enforcement_mode': mode,
      'require_manager_approval_on_exceed': mode == 'REQUIRE_APPROVAL',
      'notes': notes.trim(),
    };
  }

  List<ExpenseBudgetDto> parseBudgetListResponse(Map<String, dynamic> json, {String? targetBranchId}) {
    assertViewAuthorized(targetBranchId: targetBranchId);
    final raw = (json['budgets'] as List<dynamic>? ?? []);
    final items = raw.map((e) => ExpenseBudgetDto.fromJson(e as Map<String, dynamic>)).toList();
    _offlineCache = items;
    uiState = items.isEmpty ? BudgetUiState.empty : BudgetUiState.loaded;
    return items;
  }

  List<ExpenseBudgetDto> loadOfflineFallback() {
    if (_offlineCache.isEmpty) {
      uiState = BudgetUiState.empty;
      return const [];
    }
    uiState = BudgetUiState.offlineCache;
    return List.unmodifiable(_offlineCache);
  }
}
