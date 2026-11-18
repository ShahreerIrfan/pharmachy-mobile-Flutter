// mobile_control_account_client.dart
// Architecture Decision: ADR-0285 (P285).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class ControlAccountPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  ControlAccountPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class ControlAccountValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  ControlAccountValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class ControlAccountReconciliationRunDto {
  final String runId;
  final String tenantId;
  final String? branchId;
  final String controlAccountType;
  final String glAccountCode;
  final String glAccountName;
  final double glControlBalanceBdt;
  final double subledgerTotalBalanceBdt;
  final double varianceBdt;
  final bool isBalanced;
  final int partyCount;
  final String status;
  final String? adjustmentJournalNumber;
  final String? reconciliationNotes;
  final String createdAt;

  ControlAccountReconciliationRunDto({
    required this.runId,
    required this.tenantId,
    this.branchId,
    required this.controlAccountType,
    required this.glAccountCode,
    required this.glAccountName,
    required this.glControlBalanceBdt,
    required this.subledgerTotalBalanceBdt,
    required this.varianceBdt,
    required this.isBalanced,
    required this.partyCount,
    required this.status,
    this.adjustmentJournalNumber,
    this.reconciliationNotes,
    required this.createdAt,
  });

  factory ControlAccountReconciliationRunDto.fromJson(Map<String, dynamic> json) {
    return ControlAccountReconciliationRunDto(
      runId: json['run_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'],
      controlAccountType: json['control_account_type'] ?? '',
      glAccountCode: json['gl_account_code'] ?? '',
      glAccountName: json['gl_account_name'] ?? '',
      glControlBalanceBdt: double.tryParse(json['gl_control_balance_bdt']?.toString() ?? '0') ?? 0.0,
      subledgerTotalBalanceBdt: double.tryParse(json['subledger_total_balance_bdt']?.toString() ?? '0') ?? 0.0,
      varianceBdt: double.tryParse(json['variance_bdt']?.toString() ?? '0') ?? 0.0,
      isBalanced: json['is_balanced'] ?? false,
      partyCount: json['party_count'] ?? 0,
      status: json['status'] ?? 'DISCREPANCY_FLAGGED',
      adjustmentJournalNumber: json['adjustment_journal_number'],
      reconciliationNotes: json['reconciliation_notes'],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'run_id': runId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'control_account_type': controlAccountType,
      'gl_account_code': glAccountCode,
      'gl_account_name': glAccountName,
      'gl_control_balance_bdt': glControlBalanceBdt.toStringAsFixed(2),
      'subledger_total_balance_bdt': subledgerTotalBalanceBdt.toStringAsFixed(2),
      'variance_bdt': varianceBdt.toStringAsFixed(2),
      'is_balanced': isBalanced,
      'party_count': partyCount,
      'status': status,
      'adjustment_journal_number': adjustmentJournalNumber,
      'reconciliation_notes': reconciliationNotes,
      'created_at': createdAt,
    };
  }
}

class ControlAccountsOverviewDto {
  final String tenantId;
  final String branchId;
  final String overallStatus;
  final bool isFullyReconciled;
  final Map<String, dynamic> accountsReceivable;
  final Map<String, dynamic> accountsPayable;

  ControlAccountsOverviewDto({
    required this.tenantId,
    required this.branchId,
    required this.overallStatus,
    required this.isFullyReconciled,
    required this.accountsReceivable,
    required this.accountsPayable,
  });

  factory ControlAccountsOverviewDto.fromJson(Map<String, dynamic> json) {
    return ControlAccountsOverviewDto(
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'] ?? 'ALL_BRANCHES',
      overallStatus: json['overall_status'] ?? 'DISCREPANCIES_DETECTED',
      isFullyReconciled: json['is_fully_reconciled'] ?? false,
      accountsReceivable: Map<String, dynamic>.from(json['accounts_receivable'] ?? {}),
      accountsPayable: Map<String, dynamic>.from(json['accounts_payable'] ?? {}),
    );
  }
}

class MobileControlAccountClient {
  static const Set<String> viewRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> adjustRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> deniedStaffRoles = {
    'CASHIER',
    'STAFF_PHARMACIST',
    'DISPENSER',
    'INVENTORY_CLERK',
  };

  final String tenantId;
  final String? branchId;
  final String userRole;
  final String userId;

  final Map<String, ControlAccountReconciliationRunDto> _cache = {};

  MobileControlAccountClient({
    required this.tenantId,
    this.branchId,
    required this.userRole,
    required this.userId,
  });

  bool get isViewAuthorized => viewRoles.contains(userRole.toUpperCase());
  bool get isAdjustAuthorized => adjustRoles.contains(userRole.toUpperCase());

  ControlAccountReconciliationRunDto reconcileControlAccount({
    required String controlAccountType,
    required double glControlBalanceBdt,
    required double subledgerTotalBalanceBdt,
    int partyCount = 0,
  }) {
    if (!isViewAuthorized) {
      throw ControlAccountPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to reconcile control accounts.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট কন্ট্রোল অ্যাকাউন্ট রিকনসিল করার অনুমতিপ্রাপ্ত নন।',
      );
    }

    final typeClean = controlAccountType.toUpperCase().trim();
    if (typeClean != 'CUSTOMER_AR' && typeClean != 'SUPPLIER_AP') {
      throw ControlAccountValidationException(
        errorCode: 'ERR_INVALID_CONTROL_ACCOUNT_TYPE',
        messageEn: 'Control account type must be CUSTOMER_AR or SUPPLIER_AP.',
        messageBn: 'কন্ট্রোল অ্যাকাউন্ট টাইপ অবশ্যই CUSTOMER_AR বা SUPPLIER_AP হতে হবে।',
      );
    }

    final variance = double.parse((glControlBalanceBdt - subledgerTotalBalanceBdt).toStringAsFixed(2));
    final isBalanced = variance.abs() < 0.005;
    final runId = 'RUN-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';

    final run = ControlAccountReconciliationRunDto(
      runId: runId,
      tenantId: tenantId,
      branchId: branchId,
      controlAccountType: typeClean,
      glAccountCode: typeClean == 'CUSTOMER_AR' ? '1030' : '2010',
      glAccountName: typeClean == 'CUSTOMER_AR'
          ? 'Accounts Receivable (Customer Dues)'
          : 'Accounts Payable (Supplier Dues)',
      glControlBalanceBdt: glControlBalanceBdt,
      subledgerTotalBalanceBdt: subledgerTotalBalanceBdt,
      varianceBdt: variance,
      isBalanced: isBalanced,
      partyCount: partyCount,
      status: isBalanced ? 'MATCHED' : 'DISCREPANCY_FLAGGED',
      createdAt: DateTime.now().toIso8601String(),
    );

    _cache[runId] = run;
    return run;
  }

  ControlAccountReconciliationRunDto applyAdjustment({
    required String runId,
    required String reason,
    String contraAccountCode = '3020',
  }) {
    if (!isAdjustAuthorized) {
      throw ControlAccountPermissionException(
        errorCode: 'ERR_CONTROL_ADJUST_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can apply control account balancing adjustments.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার কন্ট্রোল অ্যাকাউন্ট ব্যালেন্সিং অ্যাডজাস্টমেন্ট করতে পারেন।',
      );
    }

    if (reason.trim().isEmpty) {
      throw ControlAccountValidationException(
        errorCode: 'ERR_MISSING_ADJUSTMENT_REASON',
        messageEn: 'A mandatory explanatory reason is required to apply control account balancing adjustment.',
        messageBn: 'কন্ট্রোল অ্যাকাউন্ট ব্যালেন্সিং অ্যাডজাস্টমেন্টের জন্য কারণ উল্লেখ করা বাধ্যতামূলক।',
      );
    }

    final existing = _cache[runId];
    if (existing == null) {
      throw ControlAccountValidationException(
        errorCode: 'ERR_RUN_NOT_FOUND',
        messageEn: 'Reconciliation run not found.',
        messageBn: 'রিকনসিলিয়েশন রান পাওয়া যায়নি।',
      );
    }

    if (existing.isBalanced || existing.status == 'RECONCILED') {
      throw ControlAccountValidationException(
        errorCode: 'ERR_NO_ADJUSTMENT_NEEDED',
        messageEn: 'Reconciliation run is already balanced or has already been reconciled.',
        messageBn: 'এই রিকনসিলিয়েশনটি ইতিমধ্যেই ভারসাম্যপূর্ণ অথবা অ্যাডজাস্ট করা হয়েছে।',
      );
    }

    final adjusted = ControlAccountReconciliationRunDto(
      runId: existing.runId,
      tenantId: existing.tenantId,
      branchId: existing.branchId,
      controlAccountType: existing.controlAccountType,
      glAccountCode: existing.glAccountCode,
      glAccountName: existing.glAccountName,
      glControlBalanceBdt: existing.subledgerTotalBalanceBdt,
      subledgerTotalBalanceBdt: existing.subledgerTotalBalanceBdt,
      varianceBdt: 0.0,
      isBalanced: true,
      partyCount: existing.partyCount,
      status: 'RECONCILED',
      adjustmentJournalNumber: 'JRN-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}',
      reconciliationNotes: reason.trim(),
      createdAt: existing.createdAt,
    );

    _cache[runId] = adjusted;
    return adjusted;
  }

  ControlAccountsOverviewDto getOverview({
    required double arGl,
    required double arSub,
    required double apGl,
    required double apSub,
  }) {
    if (!isViewAuthorized) {
      throw ControlAccountPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to view control accounts.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট কন্ট্রোল অ্যাকাউন্ট দেখার অনুমতিপ্রাপ্ত নন।',
      );
    }

    final arVar = double.parse((arGl - arSub).toStringAsFixed(2));
    final apVar = double.parse((apGl - apSub).toStringAsFixed(2));
    final arBalanced = arVar.abs() < 0.005;
    final apBalanced = apVar.abs() < 0.005;
    final allBalanced = arBalanced && apBalanced;

    return ControlAccountsOverviewDto(
      tenantId: tenantId,
      branchId: branchId ?? 'ALL_BRANCHES',
      overallStatus: allBalanced ? 'BALANCED' : 'DISCREPANCIES_DETECTED',
      isFullyReconciled: allBalanced,
      accountsReceivable: {
        'account_code': '1030',
        'account_name': 'Accounts Receivable (Customer Dues)',
        'gl_control_balance_bdt': arGl.toStringAsFixed(2),
        'subledger_total_bdt': arSub.toStringAsFixed(2),
        'variance_bdt': arVar.toStringAsFixed(2),
        'is_balanced': arBalanced,
      },
      accountsPayable: {
        'account_code': '2010',
        'account_name': 'Accounts Payable (Supplier Dues)',
        'gl_control_balance_bdt': apGl.toStringAsFixed(2),
        'subledger_total_bdt': apSub.toStringAsFixed(2),
        'variance_bdt': apVar.toStringAsFixed(2),
        'is_balanced': apBalanced,
      },
    );
  }

  List<ControlAccountReconciliationRunDto> listRuns() {
    return _cache.values.toList();
  }
}
