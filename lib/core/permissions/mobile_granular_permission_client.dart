// lib/core/permissions/mobile_granular_permission_client.dart
// Architecture Decision: ADR-0104
// Phase 06: Milestone M03 - Granular Action Permissions (P104)

enum MobilePermissionUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileGranularPermissionState {
  final String userId;
  final String tenantId;
  final String role;
  final bool costVisibilityEnabled;
  final Map<String, bool> actions;

  const MobileGranularPermissionState({
    required this.userId,
    required this.tenantId,
    required this.role,
    required this.costVisibilityEnabled,
    required this.actions,
  });

  bool allows(String action) => actions[action.trim().toLowerCase()] ?? false;

  bool get allowsSale => allows('sale');
  bool get allowsRefund => allows('refund');
  bool get allowsDiscount => allows('discount');
  bool get allowsCostVisibility => allows('cost_visibility');
  bool get allowsStockChange => allows('stock_change');
  bool get allowsPurchasing => allows('purchasing');
  bool get allowsExpenseApproval => allows('expense_approval');
  bool get allowsExport => allows('export');
  bool get allowsRxReview => allows('rx_review');

  factory MobileGranularPermissionState.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'] as Map<String, dynamic>? ?? {};
    final parsedActions = <String, bool>{};
    for (final entry in rawActions.entries) {
      parsedActions[entry.key] = entry.value == true;
    }

    return MobileGranularPermissionState(
      userId: json['user_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      role: (json['role'] as String? ?? 'UNKNOWN').toUpperCase(),
      costVisibilityEnabled: json['cost_visibility_enabled'] as bool? ?? false,
      actions: parsedActions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'tenant_id': tenantId,
      'role': role,
      'cost_visibility_enabled': costVisibilityEnabled,
      'actions': actions,
    };
  }
}

class MobilePermissionEvaluationResult {
  final bool isAllowed;
  final String action;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobilePermissionEvaluationResult({
    required this.isAllowed,
    required this.action,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobilePermissionEvaluationResult.allow(String action) {
    return MobilePermissionEvaluationResult(
      isAllowed: true,
      action: action,
      messageEn: 'Action permitted.',
      messageBn: 'অ্যাকশন অনুমোদিত।',
    );
  }

  factory MobilePermissionEvaluationResult.deny(
    String action,
    String role,
    String reason,
  ) {
    return MobilePermissionEvaluationResult(
      isAllowed: false,
      action: action,
      errorCode: 'ERR_GRANULAR_PERMISSION_DENIED',
      messageEn: "Access denied: role '$role' cannot perform '$action'. $reason",
      messageBn: "অননুমোদিত অ্যাকশন: '$role' রোলে '$action' সম্পন্ন করার অনুমতি নেই।",
    );
  }
}

class MobileGranularViewState {
  final MobilePermissionUiStatus status;
  final MobileGranularPermissionState? state;
  final String messageEn;
  final String messageBn;

  const MobileGranularViewState({
    required this.status,
    this.state,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileGranularViewState.loading() => const MobileGranularViewState(
        status: MobilePermissionUiStatus.loading,
        messageEn: 'Loading permissions...',
        messageBn: 'অনুমতি লোড হচ্ছে...',
      );

  factory MobileGranularViewState.success(MobileGranularPermissionState state) =>
      MobileGranularViewState(
        status: MobilePermissionUiStatus.success,
        state: state,
        messageEn: 'Permissions synchronized.',
        messageBn: 'অনুমতি সিঙ্ক হয়েছে।',
      );

  factory MobileGranularViewState.offline(MobileGranularPermissionState fallback) =>
      MobileGranularViewState(
        status: MobilePermissionUiStatus.offline,
        state: fallback,
        messageEn: 'Operating offline with cached permissions.',
        messageBn: 'ক্যাশ করা অনুমতি নিয়ে অফলাইনে চলছে।',
      );

  factory MobileGranularViewState.denied(String en, String bn) =>
      MobileGranularViewState(
        status: MobilePermissionUiStatus.permissionDenied,
        messageEn: en,
        messageBn: bn,
      );

  factory MobileGranularViewState.error(String en, String bn) =>
      MobileGranularViewState(
        status: MobilePermissionUiStatus.error,
        messageEn: en,
        messageBn: bn,
      );
}

class MobileGranularPermissionClient {
  static const List<String> allActions = [
    'sale',
    'refund',
    'discount',
    'cost_visibility',
    'stock_change',
    'purchasing',
    'expense_approval',
    'export',
    'rx_review',
  ];

  static Map<String, bool> resolveRoleDefaults(String role) {
    final r = role.toUpperCase();
    if (['SUPERADMIN', 'SUPER_ADMIN', 'PLATFORM_OPERATOR', 'PHARMACY_OWNER']
        .contains(r)) {
      return {for (var act in allActions) act: true};
    }

    final map = {for (var act in allActions) act: false};
    switch (r) {
      case 'BRANCH_MANAGER':
        map['sale'] = true;
        map['refund'] = true;
        map['discount'] = true;
        map['cost_visibility'] = true;
        map['stock_change'] = true;
        map['purchasing'] = true;
        map['expense_approval'] = true;
        break;
      case 'STAFF_PHARMACIST':
      case 'PHARMACIST':
        map['sale'] = true;
        map['rx_review'] = true;
        break;
      case 'CASHIER':
        map['sale'] = true;
        break;
      case 'INVENTORY_CLERK':
        map['cost_visibility'] = true;
        map['stock_change'] = true;
        map['purchasing'] = true;
        break;
      case 'FINANCE_OFFICER':
        map['cost_visibility'] = true;
        map['expense_approval'] = true;
        map['export'] = true;
        break;
      case 'AUDITOR':
        map['export'] = true;
        break;
      default:
        break;
    }
    return map;
  }

  static MobilePermissionEvaluationResult evaluateLocalAction(
    String role,
    String action, {
    String? userBranchId,
    String? targetBranchId,
  }) {
    final cleanAction = action.trim().toLowerCase();
    if (!allActions.contains(cleanAction)) {
      return MobilePermissionEvaluationResult(
        isAllowed: false,
        action: action,
        errorCode: 'UNKNOWN_ACTION',
        messageEn: 'Unknown action: $action',
        messageBn: 'অজানা অ্যাকশন: $action',
      );
    }

    final defaults = resolveRoleDefaults(role);
    if (defaults[cleanAction] != true) {
      return MobilePermissionEvaluationResult.deny(
        cleanAction,
        role,
        'Role does not hold this action privilege.',
      );
    }

    if (role.toUpperCase() == 'BRANCH_MANAGER' &&
        userBranchId != null &&
        targetBranchId != null &&
        userBranchId != targetBranchId) {
      return MobilePermissionEvaluationResult.deny(
        cleanAction,
        role,
        'Cross-branch actions are forbidden.',
      );
    }

    return MobilePermissionEvaluationResult.allow(cleanAction);
  }

  static Map<String, dynamic> maskMedicineCost(
    Map<String, dynamic> medicine,
    bool costVisibility,
  ) {
    final copy = Map<String, dynamic>.from(medicine);
    if (!costVisibility) {
      copy['cost_unit'] = null;
      copy['cost_per_unit'] = null;
      copy['unit_cost_bdt'] = null;
      copy['cogs_bdt'] = null;
    }
    return copy;
  }

  static MobileGranularPermissionState createOfflineFallback({
    required String userId,
    required String tenantId,
    required String role,
  }) {
    final defaults = resolveRoleDefaults(role);
    final costVis = defaults['cost_visibility'] == true;
    return MobileGranularPermissionState(
      userId: userId,
      tenantId: tenantId,
      role: role,
      costVisibilityEnabled: costVis,
      actions: defaults,
    );
  }
}
