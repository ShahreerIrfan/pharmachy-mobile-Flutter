// mobile_cash_flow_client.dart
// Architecture Decision: ADR-0294 (P294).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class CashFlowPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  CashFlowPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class CashFlowValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  CashFlowValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class CashFlowInflowsDto {
  final double posSalesCollectionsBdt;
  final double customerArCollectionsBdt;
  final double otherReceiptsBdt;
  final double totalOperatingInflowsBdt;

  CashFlowInflowsDto({
    required this.posSalesCollectionsBdt,
    required this.customerArCollectionsBdt,
    required this.otherReceiptsBdt,
    required this.totalOperatingInflowsBdt,
  });

  factory CashFlowInflowsDto.fromJson(Map<String, dynamic> json) {
    return CashFlowInflowsDto(
      posSalesCollectionsBdt: double.tryParse(json['pos_sales_collections_bdt']?.toString() ?? '0.00') ?? 0.0,
      customerArCollectionsBdt: double.tryParse(json['customer_ar_collections_bdt']?.toString() ?? '0.00') ?? 0.0,
      otherReceiptsBdt: double.tryParse(json['other_receipts_bdt']?.toString() ?? '0.00') ?? 0.0,
      totalOperatingInflowsBdt: double.tryParse(json['total_operating_inflows_bdt']?.toString() ?? '0.00') ?? 0.0,
    );
  }
}

class CashFlowOutflowsDto {
  final double operatingExpensePaymentsBdt;
  final double supplierApPaymentsBdt;
  final double payrollDisbursementsBdt;
  final double otherPaymentsBdt;
  final double totalOperatingOutflowsBdt;

  CashFlowOutflowsDto({
    required this.operatingExpensePaymentsBdt,
    required this.supplierApPaymentsBdt,
    required this.payrollDisbursementsBdt,
    required this.otherPaymentsBdt,
    required this.totalOperatingOutflowsBdt,
  });

  factory CashFlowOutflowsDto.fromJson(Map<String, dynamic> json) {
    return CashFlowOutflowsDto(
      operatingExpensePaymentsBdt: double.tryParse(json['operating_expense_payments_bdt']?.toString() ?? '0.00') ?? 0.0,
      supplierApPaymentsBdt: double.tryParse(json['supplier_ap_payments_bdt']?.toString() ?? '0.00') ?? 0.0,
      payrollDisbursementsBdt: double.tryParse(json['payroll_disbursements_bdt']?.toString() ?? '0.00') ?? 0.0,
      otherPaymentsBdt: double.tryParse(json['other_payments_bdt']?.toString() ?? '0.00') ?? 0.0,
      totalOperatingOutflowsBdt: double.tryParse(json['total_operating_outflows_bdt']?.toString() ?? '0.00') ?? 0.0,
    );
  }
}

class CashFlowTreasuryTransfersDto {
  final double transfersInBdt;
  final double transfersOutBdt;
  final double netTransfersBdt;
  final String commentary;

  CashFlowTreasuryTransfersDto({
    required this.transfersInBdt,
    required this.transfersOutBdt,
    required this.netTransfersBdt,
    required this.commentary,
  });

  factory CashFlowTreasuryTransfersDto.fromJson(Map<String, dynamic> json) {
    return CashFlowTreasuryTransfersDto(
      transfersInBdt: double.tryParse(json['transfers_in_bdt']?.toString() ?? '0.00') ?? 0.0,
      transfersOutBdt: double.tryParse(json['transfers_out_bdt']?.toString() ?? '0.00') ?? 0.0,
      netTransfersBdt: double.tryParse(json['net_transfers_bdt']?.toString() ?? '0.00') ?? 0.0,
      commentary: json['transfer_commentary'] as String? ?? '',
    );
  }
}

class CashFlowAccrualReconciliationDto {
  final double accrualNetRevenueBdt;
  final double cashOperatingInflowsBdt;
  final double revenueTimingVarianceBdt;
  final double accrualCogsAndExpensesBdt;
  final double cashOperatingOutflowsBdt;
  final double accrualNetIncomeBdt;
  final double cashNetOperatingFlowBdt;
  final double netIncomeToCashVarianceBdt;
  final String explanationEn;
  final String explanationBn;

  CashFlowAccrualReconciliationDto({
    required this.accrualNetRevenueBdt,
    required this.cashOperatingInflowsBdt,
    required this.revenueTimingVarianceBdt,
    required this.accrualCogsAndExpensesBdt,
    required this.cashOperatingOutflowsBdt,
    required this.accrualNetIncomeBdt,
    required this.cashNetOperatingFlowBdt,
    required this.netIncomeToCashVarianceBdt,
    required this.explanationEn,
    required this.explanationBn,
  });

  factory CashFlowAccrualReconciliationDto.fromJson(Map<String, dynamic> json) {
    return CashFlowAccrualReconciliationDto(
      accrualNetRevenueBdt: double.tryParse(json['accrual_net_revenue_bdt']?.toString() ?? '0.00') ?? 0.0,
      cashOperatingInflowsBdt: double.tryParse(json['cash_operating_inflows_bdt']?.toString() ?? '0.00') ?? 0.0,
      revenueTimingVarianceBdt: double.tryParse(json['revenue_timing_variance_bdt']?.toString() ?? '0.00') ?? 0.0,
      accrualCogsAndExpensesBdt: double.tryParse(json['accrual_cogs_and_expenses_bdt']?.toString() ?? '0.00') ?? 0.0,
      cashOperatingOutflowsBdt: double.tryParse(json['cash_operating_outflows_bdt']?.toString() ?? '0.00') ?? 0.0,
      accrualNetIncomeBdt: double.tryParse(json['accrual_net_income_bdt']?.toString() ?? '0.00') ?? 0.0,
      cashNetOperatingFlowBdt: double.tryParse(json['cash_net_operating_flow_bdt']?.toString() ?? '0.00') ?? 0.0,
      netIncomeToCashVarianceBdt: double.tryParse(json['net_income_to_cash_variance_bdt']?.toString() ?? '0.00') ?? 0.0,
      explanationEn: json['explanation_en'] as String? ?? '',
      explanationBn: json['explanation_bn'] as String? ?? '',
    );
  }
}

class BranchCashFlowDto {
  final String branchId;
  final String branchName;
  final double openingBalanceBdt;
  final double operatingInflowsBdt;
  final double operatingOutflowsBdt;
  final double netOperatingCashFlowBdt;
  final double transfersInBdt;
  final double transfersOutBdt;
  final double netCashFlowBdt;
  final double closingBalanceBdt;

  BranchCashFlowDto({
    required this.branchId,
    required this.branchName,
    required this.openingBalanceBdt,
    required this.operatingInflowsBdt,
    required this.operatingOutflowsBdt,
    required this.netOperatingCashFlowBdt,
    required this.transfersInBdt,
    required this.transfersOutBdt,
    required this.netCashFlowBdt,
    required this.closingBalanceBdt,
  });

  factory BranchCashFlowDto.fromJson(Map<String, dynamic> json) {
    return BranchCashFlowDto(
      branchId: json['branch_id'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      openingBalanceBdt: double.tryParse(json['opening_balance_bdt']?.toString() ?? '0.00') ?? 0.0,
      operatingInflowsBdt: double.tryParse(json['operating_inflows_bdt']?.toString() ?? '0.00') ?? 0.0,
      operatingOutflowsBdt: double.tryParse(json['operating_outflows_bdt']?.toString() ?? '0.00') ?? 0.0,
      netOperatingCashFlowBdt: double.tryParse(json['net_operating_cash_flow_bdt']?.toString() ?? '0.00') ?? 0.0,
      transfersInBdt: double.tryParse(json['transfers_in_bdt']?.toString() ?? '0.00') ?? 0.0,
      transfersOutBdt: double.tryParse(json['transfers_out_bdt']?.toString() ?? '0.00') ?? 0.0,
      netCashFlowBdt: double.tryParse(json['net_cash_flow_bdt']?.toString() ?? '0.00') ?? 0.0,
      closingBalanceBdt: double.tryParse(json['closing_balance_bdt']?.toString() ?? '0.00') ?? 0.0,
    );
  }
}

class CashFlowReportDto {
  final String tenantId;
  final String tenantName;
  final String branchId;
  final String branchName;
  final String periodLabel;
  final String? startDate;
  final String? endDate;
  final String generatedAt;
  final double openingBalanceBdt;
  final double closingBalanceBdt;
  final CashFlowInflowsDto operatingInflows;
  final CashFlowOutflowsDto operatingOutflows;
  final double netOperatingCashFlowBdt;
  final CashFlowTreasuryTransfersDto treasuryTransfers;
  final double netCashFlowBdt;
  final bool isPositiveCashFlow;
  final CashFlowAccrualReconciliationDto accrualReconciliation;
  final List<BranchCashFlowDto> branchBreakdown;

  CashFlowReportDto({
    required this.tenantId,
    required this.tenantName,
    required this.branchId,
    required this.branchName,
    required this.periodLabel,
    this.startDate,
    this.endDate,
    required this.generatedAt,
    required this.openingBalanceBdt,
    required this.closingBalanceBdt,
    required this.operatingInflows,
    required this.operatingOutflows,
    required this.netOperatingCashFlowBdt,
    required this.treasuryTransfers,
    required this.netCashFlowBdt,
    required this.isPositiveCashFlow,
    required this.accrualReconciliation,
    required this.branchBreakdown,
  });

  factory CashFlowReportDto.fromJson(Map<String, dynamic> json) {
    final rawBranches = json['branch_breakdown'] as List<dynamic>? ?? [];
    return CashFlowReportDto(
      tenantId: json['tenant_id'] as String? ?? '',
      tenantName: json['tenant_name'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      periodLabel: json['period_label'] as String? ?? '',
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      generatedAt: json['generated_at'] as String? ?? '',
      openingBalanceBdt: double.tryParse(json['opening_balance_bdt']?.toString() ?? '0.00') ?? 0.0,
      closingBalanceBdt: double.tryParse(json['closing_balance_bdt']?.toString() ?? '0.00') ?? 0.0,
      operatingInflows: CashFlowInflowsDto.fromJson(json['operating_inflows'] as Map<String, dynamic>? ?? {}),
      operatingOutflows: CashFlowOutflowsDto.fromJson(json['operating_outflows'] as Map<String, dynamic>? ?? {}),
      netOperatingCashFlowBdt: double.tryParse(json['net_operating_cash_flow']?['net_operating_cash_flow_bdt']?.toString() ?? '0.00') ?? 0.0,
      treasuryTransfers: CashFlowTreasuryTransfersDto.fromJson(json['treasury_transfers'] as Map<String, dynamic>? ?? {}),
      netCashFlowBdt: double.tryParse(json['net_cash_flow']?['net_cash_flow_bdt']?.toString() ?? '0.00') ?? 0.0,
      isPositiveCashFlow: json['net_cash_flow']?['is_positive'] as bool? ?? false,
      accrualReconciliation: CashFlowAccrualReconciliationDto.fromJson(json['accrual_reconciliation'] as Map<String, dynamic>? ?? {}),
      branchBreakdown: rawBranches.map((e) => BranchCashFlowDto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class MobileCashFlowClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isSuspended;

  static const authorizedRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'AUDITOR',
    'SUPERADMIN',
  };

  MobileCashFlowClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isSuspended = false,
  });

  void _assertAuthorized(String? queryBranchId) {
    if (isSuspended) {
      throw CashFlowPermissionException(
        errorCode: 'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant account subscription is suspended. Cash flow reporting blocked.',
        messageBn: 'ফার্মেসি সাবস্ক্রিপশন স্থগিত আছে। ক্যাশ ফ্লো রিপোর্ট দেখা সম্ভব নয়।',
      );
    }

    if (!authorizedRoles.contains(userRole)) {
      throw CashFlowPermissionException(
        errorCode: 'ERR_CASH_FLOW_UNAUTHORIZED',
        messageEn: 'Cashier and counter staff are not authorized to access Cash Flow financial statements.',
        messageBn: 'ক্যাশিয়ার বা কাউন্টার স্টাফদের ক্যাশ ফ্লো বিবরণী দেখার অনুমতি নেই।',
      );
    }

    if (userRole == 'BRANCH_MANAGER' && queryBranchId != null && queryBranchId.isNotEmpty) {
      if (queryBranchId != branchId && queryBranchId != 'ALL_BRANCHES') {
        throw CashFlowPermissionException(
          errorCode: 'ERR_BRANCH_ACCESS_DENIED',
          messageEn: 'Branch Managers can only access their assigned branch Cash Flow overview.',
          messageBn: 'শাখা ব্যবস্থাপক শুধুমাত্র নিজস্ব শাখার ক্যাশ ফ্লো দেখতে পারবেন।',
        );
      }
    }
  }

  CashFlowReportDto generateCashFlowOverview({
    String? queryBranchId,
    String? startDate,
    String? endDate,
    double openingBalance = 50000.00,
    double posSales = 200000.00,
    double arCollections = 20000.00,
    double otherInflows = 5000.00,
    double operatingExpenses = 45000.00,
    double supplierAp = 100000.00,
    double payroll = 30000.00,
    double otherOutflows = 2000.00,
    double transfersIn = 40000.00,
    double transfersOut = 40000.00,
    double accrualNetRevenue = 240000.00,
    double accrualExpenses = 185000.00,
  }) {
    _assertAuthorized(queryBranchId);

    if (startDate != null && endDate != null) {
      final s = DateTime.tryParse(startDate);
      final e = DateTime.tryParse(endDate);
      if (s != null && e != null && s.isAfter(e)) {
        throw CashFlowValidationException(
          errorCode: 'ERR_INVALID_DATE_RANGE',
          messageEn: 'start_date cannot be after end_date.',
          messageBn: 'শুরুর তারিখ শেষের তারিখের চেয়ে পরের হতে পারে না।',
        );
      }
    }

    final totalInflows = posSales + arCollections + otherInflows;
    final totalOutflows = operatingExpenses + supplierAp + payroll + otherOutflows;
    final netOperatingFlow = totalInflows - totalOutflows;
    final netTransfers = transfersIn - transfersOut; // 0.00 consolidated
    final netCashFlow = netOperatingFlow + netTransfers;
    final closingBalance = openingBalance + netCashFlow;

    final accrualNetIncome = accrualNetRevenue - accrualExpenses;
    final incomeToCashVariance = accrualNetIncome - netOperatingFlow;

    return CashFlowReportDto(
      tenantId: tenantId,
      tenantName: 'Dhaka Care Pharmacy Ltd',
      branchId: queryBranchId ?? branchId,
      branchName: queryBranchId == null || queryBranchId.isEmpty ? 'Consolidated Pharmacy' : 'Selected Branch',
      periodLabel: startDate != null && endDate != null ? '$startDate to $endDate' : 'Cumulative Period',
      startDate: startDate,
      endDate: endDate,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      openingBalanceBdt: openingBalance,
      closingBalanceBdt: closingBalance,
      operatingInflows: CashFlowInflowsDto(
        posSalesCollectionsBdt: posSales,
        customerArCollectionsBdt: arCollections,
        otherReceiptsBdt: otherInflows,
        totalOperatingInflowsBdt: totalInflows,
      ),
      operatingOutflows: CashFlowOutflowsDto(
        operatingExpensePaymentsBdt: operatingExpenses,
        supplierApPaymentsBdt: supplierAp,
        payrollDisbursementsBdt: payroll,
        otherPaymentsBdt: otherOutflows,
        totalOperatingOutflowsBdt: totalOutflows,
      ),
      netOperatingCashFlowBdt: netOperatingFlow,
      treasuryTransfers: CashFlowTreasuryTransfersDto(
        transfersInBdt: transfersIn,
        transfersOutBdt: transfersOut,
        netTransfersBdt: netTransfers,
        commentary: 'Internal cash-bank transfers do not affect total liquid funds.',
      ),
      netCashFlowBdt: netCashFlow,
      isPositiveCashFlow: netCashFlow >= 0,
      accrualReconciliation: CashFlowAccrualReconciliationDto(
        accrualNetRevenueBdt: accrualNetRevenue,
        cashOperatingInflowsBdt: totalInflows,
        revenueTimingVarianceBdt: accrualNetRevenue - totalInflows,
        accrualCogsAndExpensesBdt: accrualExpenses,
        cashOperatingOutflowsBdt: totalOutflows,
        accrualNetIncomeBdt: accrualNetIncome,
        cashNetOperatingFlowBdt: netOperatingFlow,
        netIncomeToCashVarianceBdt: incomeToCashVariance,
        explanationEn: 'Variance is driven by customer credit dues, supplier payables, and lot write-offs.',
        explanationBn: 'পার্থক্যটি বাকি বিক্রয়, বাকিতে পণ্য ক্রয় এবং মেয়াদোত্তীর্ণ পণ্যের কারণে সৃষ্ট।',
      ),
      branchBreakdown: [
        BranchCashFlowDto(
          branchId: branchId,
          branchName: 'Main Dhanmondi Branch',
          openingBalanceBdt: openingBalance,
          operatingInflowsBdt: totalInflows,
          operatingOutflowsBdt: totalOutflows,
          netOperatingCashFlowBdt: netOperatingFlow,
          transfersInBdt: transfersIn,
          transfersOutBdt: transfersOut,
          netCashFlowBdt: netCashFlow,
          closingBalanceBdt: closingBalance,
        ),
      ],
    );
  }

  String exportCashFlowCsv(CashFlowReportDto report) {
    final buffer = StringBuffer();
    buffer.writeln('CASH FLOW STATEMENT (DIRECT METHOD)');
    buffer.writeln('Tenant,${report.tenantName} (${report.tenantId})');
    buffer.writeln('Branch,${report.branchName}');
    buffer.writeln('Period,${report.periodLabel}');
    buffer.writeln('');
    buffer.writeln('Section,Activity / Item,Amount (BDT)');
    buffer.writeln('BALANCE,Opening Liquid Cash & Bank Balance,${report.openingBalanceBdt.toStringAsFixed(2)}');
    buffer.writeln('OPERATING_INFLOW,POS Counter Sales Collections,${report.operatingInflows.posSalesCollectionsBdt.toStringAsFixed(2)}');
    buffer.writeln('OPERATING_INFLOW,Customer Due (AR) Collections,${report.operatingInflows.customerArCollectionsBdt.toStringAsFixed(2)}');
    buffer.writeln('SUBTOTAL,Total Operating Inflows,${report.operatingInflows.totalOperatingInflowsBdt.toStringAsFixed(2)}');
    buffer.writeln('OPERATING_OUTFLOW,Operating Expenses Paid,${report.operatingOutflows.operatingExpensePaymentsBdt.toStringAsFixed(2)}');
    buffer.writeln('OPERATING_OUTFLOW,Supplier AP Paid,${report.operatingOutflows.supplierApPaymentsBdt.toStringAsFixed(2)}');
    buffer.writeln('OPERATING_OUTFLOW,Payroll Disbursed,${report.operatingOutflows.payrollDisbursementsBdt.toStringAsFixed(2)}');
    buffer.writeln('SUBTOTAL,Total Operating Outflows,${report.operatingOutflows.totalOperatingOutflowsBdt.toStringAsFixed(2)}');
    buffer.writeln('SUMMARY,Net Operating Cash Flow,${report.netOperatingCashFlowBdt.toStringAsFixed(2)}');
    buffer.writeln('TREASURY,Net Internal Transfers,${report.treasuryTransfers.netTransfersBdt.toStringAsFixed(2)}');
    buffer.writeln('SUMMARY,Net Overall Cash Flow,${report.netCashFlowBdt.toStringAsFixed(2)}');
    buffer.writeln('BALANCE,Closing Liquid Cash & Bank Balance,${report.closingBalanceBdt.toStringAsFixed(2)}');
    return buffer.toString();
  }
}
