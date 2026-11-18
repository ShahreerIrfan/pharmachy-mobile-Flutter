// mobile_inventory_valuation_client.dart
// Architecture Decision: ADR-0295 (P295).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class InventoryValuationPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  InventoryValuationPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class InventoryValuationValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  InventoryValuationValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PhysicalInventoryDto {
  final int totalOnHandUnits;
  final int sellableUnits;
  final double sellableValueBdt;
  final int quarantinedUnits;
  final double quarantinedValueBdt;
  final double totalPhysicalValuationBdt;
  final String costingMethod;

  PhysicalInventoryDto({
    required this.totalOnHandUnits,
    required this.sellableUnits,
    required this.sellableValueBdt,
    required this.quarantinedUnits,
    required this.quarantinedValueBdt,
    required this.totalPhysicalValuationBdt,
    required this.costingMethod,
  });

  factory PhysicalInventoryDto.fromJson(Map<String, dynamic> json) {
    return PhysicalInventoryDto(
      totalOnHandUnits: json['total_on_hand_units'] as int? ?? 0,
      sellableUnits: json['sellable_units'] as int? ?? 0,
      sellableValueBdt: double.tryParse(json['sellable_value_bdt']?.toString() ?? '0.00') ?? 0.0,
      quarantinedUnits: json['quarantined_units'] as int? ?? 0,
      quarantinedValueBdt: double.tryParse(json['quarantined_value_bdt']?.toString() ?? '0.00') ?? 0.0,
      totalPhysicalValuationBdt: double.tryParse(json['total_physical_valuation_bdt']?.toString() ?? '0.00') ?? 0.0,
      costingMethod: json['costing_method'] as String? ?? 'FEFO_LANDED_LOT_COST',
    );
  }
}

class LossDispositionDto {
  final int expiredUnits;
  final double expiredLossValueBdt;
  final String statusCommentary;

  LossDispositionDto({
    required this.expiredUnits,
    required this.expiredLossValueBdt,
    required this.statusCommentary,
  });

  factory LossDispositionDto.fromJson(Map<String, dynamic> json) {
    return LossDispositionDto(
      expiredUnits: json['expired_units'] as int? ?? 0,
      expiredLossValueBdt: double.tryParse(json['expired_loss_value_bdt']?.toString() ?? '0.00') ?? 0.0,
      statusCommentary: json['status_commentary'] as String? ?? '',
    );
  }
}

class AccountingGlDto {
  final String accountCode;
  final String accountName;
  final String accountNameBn;
  final double totalDebitsBdt;
  final double totalCreditsBdt;
  final double glBookValueBdt;

  AccountingGlDto({
    required this.accountCode,
    required this.accountName,
    required this.accountNameBn,
    required this.totalDebitsBdt,
    required this.totalCreditsBdt,
    required this.glBookValueBdt,
  });

  factory AccountingGlDto.fromJson(Map<String, dynamic> json) {
    return AccountingGlDto(
      accountCode: json['account_code'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      accountNameBn: json['account_name_bn'] as String? ?? '',
      totalDebitsBdt: double.tryParse(json['total_debits_bdt']?.toString() ?? '0.00') ?? 0.0,
      totalCreditsBdt: double.tryParse(json['total_credits_bdt']?.toString() ?? '0.00') ?? 0.0,
      glBookValueBdt: double.tryParse(json['gl_book_value_bdt']?.toString() ?? '0.00') ?? 0.0,
    );
  }
}

class ValuationReconciliationDto {
  final double physicalValuationBdt;
  final double glBookValueBdt;
  final double valuationVarianceBdt;
  final bool isBalanced;
  final String status;
  final String messageEn;
  final String messageBn;

  ValuationReconciliationDto({
    required this.physicalValuationBdt,
    required this.glBookValueBdt,
    required this.valuationVarianceBdt,
    required this.isBalanced,
    required this.status,
    required this.messageEn,
    required this.messageBn,
  });

  factory ValuationReconciliationDto.fromJson(Map<String, dynamic> json) {
    return ValuationReconciliationDto(
      physicalValuationBdt: double.tryParse(json['physical_valuation_bdt']?.toString() ?? '0.00') ?? 0.0,
      glBookValueBdt: double.tryParse(json['gl_book_value_bdt']?.toString() ?? '0.00') ?? 0.0,
      valuationVarianceBdt: double.tryParse(json['valuation_variance_bdt']?.toString() ?? '0.00') ?? 0.0,
      isBalanced: json['is_balanced'] as bool? ?? false,
      status: json['status'] as String? ?? 'VARIANCE_DETECTED',
      messageEn: json['message_en'] as String? ?? '',
      messageBn: json['message_bn'] as String? ?? '',
    );
  }
}

class BranchValuationDto {
  final String branchId;
  final String branchName;
  final int physicalUnits;
  final double physicalValuationBdt;
  final double sellableValueBdt;
  final double quarantinedValueBdt;
  final double expiredValueBdt;
  final double glBookValueBdt;
  final double varianceBdt;
  final String reconciliationStatus;

  BranchValuationDto({
    required this.branchId,
    required this.branchName,
    required this.physicalUnits,
    required this.physicalValuationBdt,
    required this.sellableValueBdt,
    required this.quarantinedValueBdt,
    required this.expiredValueBdt,
    required this.glBookValueBdt,
    required this.varianceBdt,
    required this.reconciliationStatus,
  });

  factory BranchValuationDto.fromJson(Map<String, dynamic> json) {
    return BranchValuationDto(
      branchId: json['branch_id'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      physicalUnits: json['physical_units'] as int? ?? 0,
      physicalValuationBdt: double.tryParse(json['physical_valuation_bdt']?.toString() ?? '0.00') ?? 0.0,
      sellableValueBdt: double.tryParse(json['sellable_value_bdt']?.toString() ?? '0.00') ?? 0.0,
      quarantinedValueBdt: double.tryParse(json['quarantined_value_bdt']?.toString() ?? '0.00') ?? 0.0,
      expiredValueBdt: double.tryParse(json['expired_value_bdt']?.toString() ?? '0.00') ?? 0.0,
      glBookValueBdt: double.tryParse(json['gl_book_value_bdt']?.toString() ?? '0.00') ?? 0.0,
      varianceBdt: double.tryParse(json['variance_bdt']?.toString() ?? '0.00') ?? 0.0,
      reconciliationStatus: json['reconciliation_status'] as String? ?? 'BALANCED',
    );
  }
}

class InventoryValuationReportDto {
  final String tenantId;
  final String tenantName;
  final String branchId;
  final String branchName;
  final String asOfDate;
  final String generatedAt;
  final PhysicalInventoryDto physicalInventory;
  final LossDispositionDto lossDisposition;
  final AccountingGlDto accountingGl;
  final ValuationReconciliationDto reconciliation;
  final List<BranchValuationDto> branchBreakdown;

  InventoryValuationReportDto({
    required this.tenantId,
    required this.tenantName,
    required this.branchId,
    required this.branchName,
    required this.asOfDate,
    required this.generatedAt,
    required this.physicalInventory,
    required this.lossDisposition,
    required this.accountingGl,
    required this.reconciliation,
    required this.branchBreakdown,
  });

  factory InventoryValuationReportDto.fromJson(Map<String, dynamic> json) {
    final rawBranches = json['branch_breakdown'] as List<dynamic>? ?? [];
    return InventoryValuationReportDto(
      tenantId: json['tenant_id'] as String? ?? '',
      tenantName: json['tenant_name'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      asOfDate: json['as_of_date'] as String? ?? '',
      generatedAt: json['generated_at'] as String? ?? '',
      physicalInventory: PhysicalInventoryDto.fromJson(json['physical_inventory'] as Map<String, dynamic>? ?? {}),
      lossDisposition: LossDispositionDto.fromJson(json['loss_disposition'] as Map<String, dynamic>? ?? {}),
      accountingGl: AccountingGlDto.fromJson(json['accounting_gl'] as Map<String, dynamic>? ?? {}),
      reconciliation: ValuationReconciliationDto.fromJson(json['reconciliation'] as Map<String, dynamic>? ?? {}),
      branchBreakdown: rawBranches.map((e) => BranchValuationDto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class InventoryValuationAdjustmentResultDto {
  final String adjustmentId;
  final String tenantId;
  final String branchId;
  final String adjustmentType;
  final double amountBdt;
  final String reason;
  final String auditNotes;
  final String journalId;
  final String status;

  InventoryValuationAdjustmentResultDto({
    required this.adjustmentId,
    required this.tenantId,
    required this.branchId,
    required this.adjustmentType,
    required this.amountBdt,
    required this.reason,
    required this.auditNotes,
    required this.journalId,
    required this.status,
  });

  factory InventoryValuationAdjustmentResultDto.fromJson(Map<String, dynamic> json) {
    return InventoryValuationAdjustmentResultDto(
      adjustmentId: json['adjustment_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      adjustmentType: json['adjustment_type'] as String? ?? '',
      amountBdt: double.tryParse(json['amount_bdt']?.toString() ?? '0.00') ?? 0.0,
      reason: json['reason'] as String? ?? '',
      auditNotes: json['audit_notes'] as String? ?? '',
      journalId: json['journal_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class MobileInventoryValuationClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isSuspended;

  static const viewRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'AUDITOR',
    'SUPERADMIN',
  };

  static const adjustRoles = {
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'SUPERADMIN',
  };

  MobileInventoryValuationClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isSuspended = false,
  });

  void _assertViewAuthorized(String? queryBranchId) {
    if (isSuspended) {
      throw InventoryValuationPermissionException(
        errorCode: 'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant account subscription is suspended. Inventory valuation blocked.',
        messageBn: 'ফার্মেসি সাবস্ক্রিপশন স্থগিত আছে। ইনভেন্টরি মূল্যায়ন দেখা সম্ভব নয়।',
      );
    }

    if (!viewRoles.contains(userRole)) {
      throw InventoryValuationPermissionException(
        errorCode: 'ERR_INVENTORY_VALUATION_UNAUTHORIZED',
        messageEn: 'Cashier and counter staff are not authorized to access inventory cost valuation.',
        messageBn: 'ক্যাশিয়ার বা কাউন্টার স্টাফদের ইনভেন্টরি মূল্যায়ন দেখার অনুমতি নেই।',
      );
    }

    if (userRole == 'BRANCH_MANAGER' && queryBranchId != null && queryBranchId.isNotEmpty) {
      if (queryBranchId != branchId && queryBranchId != 'ALL_BRANCHES') {
        throw InventoryValuationPermissionException(
          errorCode: 'ERR_BRANCH_ACCESS_DENIED',
          messageEn: 'Branch Managers can only access their assigned branch inventory valuation.',
          messageBn: 'শাখা ব্যবস্থাপক শুধুমাত্র নিজস্ব শাখার ইনভেন্টরি মূল্যায়ন দেখতে পারবেন।',
        );
      }
    }
  }

  void _assertAdjustAuthorized() {
    if (isSuspended) {
      throw InventoryValuationPermissionException(
        errorCode: 'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant account subscription is suspended. Adjustments blocked.',
        messageBn: 'ফার্মেসি সাবস্ক্রিপশন স্থগিত আছে।',
      );
    }

    if (!adjustRoles.contains(userRole)) {
      throw InventoryValuationPermissionException(
        errorCode: 'ERR_VALUATION_ADJUST_FORBIDDEN',
        messageEn: 'Only Pharmacy Owners and Finance Officers can post audited valuation adjustments.',
        messageBn: 'শুধুমাত্র ফার্মেসি মালিক ও অর্থ কর্মকর্তা ইনভেন্টরি সমন্বয় করতে পারবেন।',
      );
    }
  }

  InventoryValuationReportDto generateValuationReport({
    String? queryBranchId,
    String? asOfDate,
    int sellableUnits = 5000,
    double sellableValue = 250000.00,
    int quarantinedUnits = 100,
    double quarantinedValue = 5000.00,
    int expiredUnits = 50,
    double expiredLossValue = 2500.00,
    double glBookValue = 255000.00,
  }) {
    _assertViewAuthorized(queryBranchId);

    final totalOnHandUnits = sellableUnits + quarantinedUnits;
    final totalPhysicalValuation = sellableValue + quarantinedValue;
    final variance = glBookValue - totalPhysicalValuation;
    final isBalanced = variance.abs() < 0.01;

    return InventoryValuationReportDto(
      tenantId: tenantId,
      tenantName: 'Dhaka Care Pharmacy Ltd',
      branchId: queryBranchId ?? branchId,
      branchName: queryBranchId == null || queryBranchId.isEmpty ? 'Consolidated Pharmacy' : 'Selected Branch',
      asOfDate: asOfDate ?? DateTime.now().toUtc().toIso8601String().substring(0, 10),
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      physicalInventory: PhysicalInventoryDto(
        totalOnHandUnits: totalOnHandUnits,
        sellableUnits: sellableUnits,
        sellableValueBdt: sellableValue,
        quarantinedUnits: quarantinedUnits,
        quarantinedValueBdt: quarantinedValue,
        totalPhysicalValuationBdt: totalPhysicalValuation,
        costingMethod: 'FEFO_LANDED_LOT_COST',
      ),
      lossDisposition: LossDispositionDto(
        expiredUnits: expiredUnits,
        expiredLossValueBdt: expiredLossValue,
        statusCommentary: 'Expired batches must be segregated and written off.',
      ),
      accountingGl: AccountingGlDto(
        accountCode: '1030',
        accountName: 'Merchandise Inventory',
        accountNameBn: 'ওষুধ মজুত',
        totalDebitsBdt: glBookValue + 100000.00,
        totalCreditsBdt: 100000.00,
        glBookValueBdt: glBookValue,
      ),
      reconciliation: ValuationReconciliationDto(
        physicalValuationBdt: totalPhysicalValuation,
        glBookValueBdt: glBookValue,
        valuationVarianceBdt: variance,
        isBalanced: isBalanced,
        status: isBalanced ? 'BALANCED' : 'VARIANCE_DETECTED',
        messageEn: isBalanced ? 'Fully balanced.' : 'Variance detected.',
        messageBn: isBalanced ? 'সম্পূর্ণভাবে ব্যালান্সড।' : 'গরমিল শনাক্ত হয়েছে।',
      ),
      branchBreakdown: [
        BranchValuationDto(
          branchId: branchId,
          branchName: 'Main Dhanmondi Branch',
          physicalUnits: totalOnHandUnits,
          physicalValuationBdt: totalPhysicalValuation,
          sellableValueBdt: sellableValue,
          quarantinedValueBdt: quarantinedValue,
          expiredValueBdt: expiredLossValue,
          glBookValueBdt: glBookValue,
          varianceBdt: variance,
          reconciliationStatus: isBalanced ? 'BALANCED' : 'VARIANCE_DETECTED',
        ),
      ],
    );
  }

  InventoryValuationAdjustmentResultDto postValuationAdjustment({
    required String adjustmentType,
    required double amountBdt,
    required String reason,
    String auditNotes = '',
    String? targetBranchId,
  }) {
    _assertAdjustAuthorized();

    if (amountBdt <= 0) {
      throw InventoryValuationValidationException(
        errorCode: 'ERR_INVALID_AMOUNT',
        messageEn: 'Adjustment amount must be positive.',
        messageBn: 'সমন্বয় পরিমাণ ধনাত্মক হতে হবে।',
      );
    }

    if (reason.trim().isEmpty) {
      throw InventoryValuationValidationException(
        errorCode: 'ERR_MISSING_REASON',
        messageEn: 'Adjustment reason is required.',
        messageBn: 'সমন্বয় কারণ উল্লেখ আবশ্যক।',
      );
    }

    final cleanType = adjustmentType.toUpperCase();
    if (cleanType != 'WRITE_DOWN' && cleanType != 'WRITE_UP') {
      throw InventoryValuationValidationException(
        errorCode: 'ERR_INVALID_ADJUSTMENT_TYPE',
        messageEn: 'Adjustment type must be WRITE_DOWN or WRITE_UP.',
        messageBn: 'সমন্বয় ধরন WRITE_DOWN অথবা WRITE_UP হতে হবে।',
      );
    }

    return InventoryValuationAdjustmentResultDto(
      adjustmentId: 'ivadj-mock-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: tenantId,
      branchId: targetBranchId ?? branchId,
      adjustmentType: cleanType,
      amountBdt: amountBdt,
      reason: reason,
      auditNotes: auditNotes,
      journalId: 'jrn-mock-${DateTime.now().millisecondsSinceEpoch}',
      status: 'ADJUSTMENT_POSTED',
    );
  }

  String exportValuationCsv(InventoryValuationReportDto report) {
    final buffer = StringBuffer();
    buffer.writeln('INVENTORY COST VALUATION & GL RECONCILIATION');
    buffer.writeln('Tenant,${report.tenantName} (${report.tenantId})');
    buffer.writeln('Branch,${report.branchName}');
    buffer.writeln('As of Date,${report.asOfDate}');
    buffer.writeln('');
    buffer.writeln('Section,Metric / Parameter,Value');
    buffer.writeln('PHYSICAL,Total On-Hand Units,${report.physicalInventory.totalOnHandUnits}');
    buffer.writeln('PHYSICAL,Total Physical Valuation BDT,${report.physicalInventory.totalPhysicalValuationBdt.toStringAsFixed(2)}');
    buffer.writeln('LOSS_DISPOSITION,Expired Loss Value BDT,${report.lossDisposition.expiredLossValueBdt.toStringAsFixed(2)}');
    buffer.writeln('GL_1030,GL Book Value BDT,${report.accountingGl.glBookValueBdt.toStringAsFixed(2)}');
    buffer.writeln('RECONCILIATION,Valuation Variance BDT,${report.reconciliation.valuationVarianceBdt.toStringAsFixed(2)}');
    buffer.writeln('RECONCILIATION,Status,${report.reconciliation.status}');
    return buffer.toString();
  }
}
