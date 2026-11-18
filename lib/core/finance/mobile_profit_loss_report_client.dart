// mobile_profit_loss_report_client.dart
// Architecture Decision: ADR-0293 (P293).
// Phase 15: General Ledger, Operating Expenses & Profitability.

import 'dart:math';

class ProfitLossPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  ProfitLossPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class ProfitLossValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  ProfitLossValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class ProfitLossLineItemDto {
  final String accountCode;
  final String accountName;
  final String accountNameBn;
  final double amountBdt;
  final bool isContra;

  ProfitLossLineItemDto({
    required this.accountCode,
    required this.accountName,
    required this.accountNameBn,
    required this.amountBdt,
    this.isContra = false,
  });

  factory ProfitLossLineItemDto.fromJson(Map<String, dynamic> json) {
    return ProfitLossLineItemDto(
      accountCode: json['account_code'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      accountNameBn: json['account_name_bn'] as String? ?? json['account_name'] as String? ?? '',
      amountBdt: double.tryParse(json['amount_bdt']?.toString() ?? '0.00') ?? 0.0,
      isContra: json['is_contra'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'account_code': accountCode,
    'account_name': accountName,
    'account_name_bn': accountNameBn,
    'amount_bdt': amountBdt.toStringAsFixed(2),
    'is_contra': isContra,
  };
}

class ProfitLossRevenueDto {
  final List<ProfitLossLineItemDto> items;
  final double grossRevenueBdt;
  final double contraDiscountsBdt;
  final double netRevenueBdt;

  ProfitLossRevenueDto({
    required this.items,
    required this.grossRevenueBdt,
    required this.contraDiscountsBdt,
    required this.netRevenueBdt,
  });

  factory ProfitLossRevenueDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ProfitLossRevenueDto(
      items: rawItems.map((e) => ProfitLossLineItemDto.fromJson(e as Map<String, dynamic>)).toList(),
      grossRevenueBdt: double.tryParse(json['gross_revenue_bdt']?.toString() ?? '0.00') ?? 0.0,
      contraDiscountsBdt: double.tryParse(json['contra_discounts_bdt']?.toString() ?? '0.00') ?? 0.0,
      netRevenueBdt: double.tryParse(json['net_revenue_bdt']?.toString() ?? '0.00') ?? 0.0,
    );
  }
}

class ProfitLossCogsDto {
  final List<ProfitLossLineItemDto> items;
  final double totalCogsBdt;

  ProfitLossCogsDto({
    required this.items,
    required this.totalCogsBdt,
  });

  factory ProfitLossCogsDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ProfitLossCogsDto(
      items: rawItems.map((e) => ProfitLossLineItemDto.fromJson(e as Map<String, dynamic>)).toList(),
      totalCogsBdt: double.tryParse(json['total_cogs_bdt']?.toString() ?? '0.00') ?? 0.0,
    );
  }
}

class ProfitLossGrossProfitDto {
  final double grossProfitBdt;
  final double grossMarginPct;
  final bool isProfitable;

  ProfitLossGrossProfitDto({
    required this.grossProfitBdt,
    required this.grossMarginPct,
    required this.isProfitable,
  });

  factory ProfitLossGrossProfitDto.fromJson(Map<String, dynamic> json) {
    return ProfitLossGrossProfitDto(
      grossProfitBdt: double.tryParse(json['gross_profit_bdt']?.toString() ?? '0.00') ?? 0.0,
      grossMarginPct: double.tryParse(json['gross_margin_pct']?.toString() ?? '0.00') ?? 0.0,
      isProfitable: json['is_profitable'] as bool? ?? false,
    );
  }
}

class ProfitLossOpExDto {
  final List<ProfitLossLineItemDto> items;
  final double totalOperatingExpensesBdt;

  ProfitLossOpExDto({
    required this.items,
    required this.totalOperatingExpensesBdt,
  });

  factory ProfitLossOpExDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ProfitLossOpExDto(
      items: rawItems.map((e) => ProfitLossLineItemDto.fromJson(e as Map<String, dynamic>)).toList(),
      totalOperatingExpensesBdt: double.tryParse(json['total_operating_expenses_bdt']?.toString() ?? '0.00') ?? 0.0,
    );
  }
}

class ProfitLossNetProfitDto {
  final double netOperatingProfitBdt;
  final double netMarginPct;
  final bool isProfitable;

  ProfitLossNetProfitDto({
    required this.netOperatingProfitBdt,
    required this.netMarginPct,
    required this.isProfitable,
  });

  factory ProfitLossNetProfitDto.fromJson(Map<String, dynamic> json) {
    return ProfitLossNetProfitDto(
      netOperatingProfitBdt: double.tryParse(json['net_operating_profit_bdt']?.toString() ?? '0.00') ?? 0.0,
      netMarginPct: double.tryParse(json['net_margin_pct']?.toString() ?? '0.00') ?? 0.0,
      isProfitable: json['is_profitable'] as bool? ?? false,
    );
  }
}

class BranchProfitabilityDto {
  final String branchId;
  final String branchName;
  final double netRevenueBdt;
  final double totalCogsBdt;
  final double grossProfitBdt;
  final double operatingExpensesBdt;
  final double netProfitBdt;
  final double netMarginPct;

  BranchProfitabilityDto({
    required this.branchId,
    required this.branchName,
    required this.netRevenueBdt,
    required this.totalCogsBdt,
    required this.grossProfitBdt,
    required this.operatingExpensesBdt,
    required this.netProfitBdt,
    required this.netMarginPct,
  });

  factory BranchProfitabilityDto.fromJson(Map<String, dynamic> json) {
    return BranchProfitabilityDto(
      branchId: json['branch_id'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      netRevenueBdt: double.tryParse(json['net_revenue_bdt']?.toString() ?? '0.00') ?? 0.0,
      totalCogsBdt: double.tryParse(json['total_cogs_bdt']?.toString() ?? '0.00') ?? 0.0,
      grossProfitBdt: double.tryParse(json['gross_profit_bdt']?.toString() ?? '0.00') ?? 0.0,
      operatingExpensesBdt: double.tryParse(json['operating_expenses_bdt']?.toString() ?? '0.00') ?? 0.0,
      netProfitBdt: double.tryParse(json['net_profit_bdt']?.toString() ?? '0.00') ?? 0.0,
      netMarginPct: double.tryParse(json['net_margin_pct']?.toString() ?? '0.00') ?? 0.0,
    );
  }
}

class ProfitLossReportDto {
  final String tenantId;
  final String tenantName;
  final String branchId;
  final String branchName;
  final String periodLabel;
  final String? startDate;
  final String? endDate;
  final String generatedAt;
  final ProfitLossRevenueDto revenue;
  final ProfitLossCogsDto cogs;
  final ProfitLossGrossProfitDto grossProfit;
  final ProfitLossOpExDto operatingExpenses;
  final ProfitLossNetProfitDto netOperatingProfit;
  final List<BranchProfitabilityDto> branchBreakdown;

  ProfitLossReportDto({
    required this.tenantId,
    required this.tenantName,
    required this.branchId,
    required this.branchName,
    required this.periodLabel,
    this.startDate,
    this.endDate,
    required this.generatedAt,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.netOperatingProfit,
    required this.branchBreakdown,
  });

  factory ProfitLossReportDto.fromJson(Map<String, dynamic> json) {
    final rawBranches = json['branch_breakdown'] as List<dynamic>? ?? [];
    return ProfitLossReportDto(
      tenantId: json['tenant_id'] as String? ?? '',
      tenantName: json['tenant_name'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      periodLabel: json['period_label'] as String? ?? '',
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      generatedAt: json['generated_at'] as String? ?? '',
      revenue: ProfitLossRevenueDto.fromJson(json['revenue'] as Map<String, dynamic>? ?? {}),
      cogs: ProfitLossCogsDto.fromJson(json['cogs'] as Map<String, dynamic>? ?? {}),
      grossProfit: ProfitLossGrossProfitDto.fromJson(json['gross_profit'] as Map<String, dynamic>? ?? {}),
      operatingExpenses: ProfitLossOpExDto.fromJson(json['operating_expenses'] as Map<String, dynamic>? ?? {}),
      netOperatingProfit: ProfitLossNetProfitDto.fromJson(json['net_operating_profit'] as Map<String, dynamic>? ?? {}),
      branchBreakdown: rawBranches.map((e) => BranchProfitabilityDto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class MobileProfitLossReportClient {
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

  MobileProfitLossReportClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isSuspended = false,
  });

  void _assertAuthorized(String? queryBranchId) {
    if (isSuspended) {
      throw ProfitLossPermissionException(
        errorCode: 'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant account subscription is suspended. Financial reporting blocked.',
        messageBn: 'ফার্মেসি সাবস্ক্রিপশন স্থগিত আছে। লাভ-ক্ষতি রিপোর্ট দেখা সম্ভব নয়।',
      );
    }

    if (!authorizedRoles.contains(userRole)) {
      throw ProfitLossPermissionException(
        errorCode: 'ERR_PL_REPORT_UNAUTHORIZED',
        messageEn: 'Cashier and counter staff are not authorized to access Profit & Loss financial statements.',
        messageBn: 'ক্যাশিয়ার বা কাউন্টার স্টাফদের লাভ-ক্ষতি আর্থিক বিবরণী দেখার অনুমতি নেই।',
      );
    }

    if (userRole == 'BRANCH_MANAGER' && queryBranchId != null && queryBranchId.isNotEmpty) {
      if (queryBranchId != branchId && queryBranchId != 'ALL_BRANCHES') {
        throw ProfitLossPermissionException(
          errorCode: 'ERR_BRANCH_ACCESS_DENIED',
          messageEn: 'Branch Managers can only access their assigned branch Profit & Loss report.',
          messageBn: 'শাখা ব্যবস্থাপক শুধুমাত্র নিজস্ব শাখার লাভ-ক্ষতি রিপোর্ট দেখতে পারবেন।',
        );
      }
    }
  }

  ProfitLossReportDto generateProfitAndLossReport({
    String? queryBranchId,
    String? startDate,
    String? endDate,
    // Optional mocks for testing
    double grossMedicineSales = 150000.00,
    double grossOtcSales = 50000.00,
    double discounts = 5000.00,
    double lotPurchasesCogs = 120000.00,
    double expiryWriteOffs = 2000.00,
    double rentExpense = 15000.00,
    double electricityExpense = 4500.00,
    double salariesExpense = 30000.00,
    double internetExpense = 1500.00,
    double transportExpense = 1000.00,
    double miscExpense = 500.00,
  }) {
    _assertAuthorized(queryBranchId);

    if (startDate != null && endDate != null) {
      final s = DateTime.tryParse(startDate);
      final e = DateTime.tryParse(endDate);
      if (s != null && e != null && s.isAfter(e)) {
        throw ProfitLossValidationException(
          errorCode: 'ERR_INVALID_DATE_RANGE',
          messageEn: 'start_date cannot be after end_date.',
          messageBn: 'শুরুর তারিখ শেষের তারিখের চেয়ে পরের হতে পারে না।',
        );
      }
    }

    final totalGrossRevenue = grossMedicineSales + grossOtcSales;
    final netRevenue = totalGrossRevenue - discounts;
    final totalCogs = lotPurchasesCogs + expiryWriteOffs;
    final grossProfit = netRevenue - totalCogs;
    final grossMarginPct = netRevenue > 0 ? (grossProfit / netRevenue) * 100.0 : 0.0;

    final totalOpEx = rentExpense + electricityExpense + salariesExpense + internetExpense + transportExpense + miscExpense;
    final netOperatingProfit = grossProfit - totalOpEx;
    final netMarginPct = netRevenue > 0 ? (netOperatingProfit / netRevenue) * 100.0 : 0.0;

    final revenueItems = [
      ProfitLossLineItemDto(accountCode: '4010', accountName: 'Medicine Sales Revenue', accountNameBn: 'ওষুধ বিক্রয় আয়', amountBdt: grossMedicineSales),
      ProfitLossLineItemDto(accountCode: '4020', accountName: 'OTC & Healthcare Revenue', accountNameBn: 'ওটিসি পণ্য বিক্রয় আয়', amountBdt: grossOtcSales),
      ProfitLossLineItemDto(accountCode: '4030', accountName: 'Sales Discounts Allowed', accountNameBn: 'বিক্রয় মূল্যছাড়', amountBdt: discounts, isContra: true),
    ];

    final cogsItems = [
      ProfitLossLineItemDto(accountCode: '5010', accountName: 'Cost of Goods Sold - Lot Purchase', accountNameBn: 'পণ্য ক্রয় বাবদ ব্যয় (লট ভিত্তিক)', amountBdt: lotPurchasesCogs),
      ProfitLossLineItemDto(accountCode: '5020', accountName: 'Inventory Expiry & Wastage Loss', accountNameBn: 'মেয়াদোত্তীর্ণ ও নষ্ট পণ্যের ক্ষতি', amountBdt: expiryWriteOffs),
    ];

    final expenseItems = [
      ProfitLossLineItemDto(accountCode: '6010', accountName: 'Branch Rent Expense', accountNameBn: 'দোকান/শাখা ভাড়া ব্যয়', amountBdt: rentExpense),
      ProfitLossLineItemDto(accountCode: '6020', accountName: 'Electricity & Utility Expense', accountNameBn: 'বিদ্যুৎ ও পরিষেবা ব্যয়', amountBdt: electricityExpense),
      ProfitLossLineItemDto(accountCode: '6030', accountName: 'Staff Salary & Wages', accountNameBn: 'কর্মচারীদের বেতন ও পারিশ্রমিক', amountBdt: salariesExpense),
      ProfitLossLineItemDto(accountCode: '6040', accountName: 'Internet & Broadband Expense', accountNameBn: 'ইন্টারনেট ও যোগাযোগ ব্যয়', amountBdt: internetExpense),
      ProfitLossLineItemDto(accountCode: '6050', accountName: 'Transport & Delivery Expense', accountNameBn: 'যাতায়াত ও পরিবহন ব্যয়', amountBdt: transportExpense),
      ProfitLossLineItemDto(accountCode: '6070', accountName: 'Miscellaneous Operating Expense', accountNameBn: 'বিবিধ পরিচালন ব্যয়', amountBdt: miscExpense),
    ];

    final branches = [
      BranchProfitabilityDto(
        branchId: branchId,
        branchName: 'Main Dhanmondi Branch',
        netRevenueBdt: netRevenue,
        totalCogsBdt: totalCogs,
        grossProfitBdt: grossProfit,
        operatingExpensesBdt: totalOpEx,
        netProfitBdt: netOperatingProfit,
        netMarginPct: double.parse(netMarginPct.toStringAsFixed(2)),
      ),
    ];

    return ProfitLossReportDto(
      tenantId: tenantId,
      tenantName: 'Dhaka Care Pharmacy Ltd',
      branchId: queryBranchId ?? branchId,
      branchName: queryBranchId == null || queryBranchId.isEmpty ? 'Consolidated Pharmacy' : 'Selected Branch',
      periodLabel: startDate != null && endDate != null ? '$startDate to $endDate' : 'Cumulative Period',
      startDate: startDate,
      endDate: endDate,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      revenue: ProfitLossRevenueDto(
        items: revenueItems,
        grossRevenueBdt: totalGrossRevenue,
        contraDiscountsBdt: discounts,
        netRevenueBdt: netRevenue,
      ),
      cogs: ProfitLossCogsDto(
        items: cogsItems,
        totalCogsBdt: totalCogs,
      ),
      grossProfit: ProfitLossGrossProfitDto(
        grossProfitBdt: grossProfit,
        grossMarginPct: double.parse(grossMarginPct.toStringAsFixed(2)),
        isProfitable: grossProfit >= 0,
      ),
      operatingExpenses: ProfitLossOpExDto(
        items: expenseItems,
        totalOperatingExpensesBdt: totalOpEx,
      ),
      netOperatingProfit: ProfitLossNetProfitDto(
        netOperatingProfitBdt: netOperatingProfit,
        netMarginPct: double.parse(netMarginPct.toStringAsFixed(2)),
        isProfitable: netOperatingProfit >= 0,
      ),
      branchBreakdown: branches,
    );
  }

  String exportProfitAndLossCsv(ProfitLossReportDto report) {
    final buffer = StringBuffer();
    buffer.writeln('PROFIT & LOSS STATEMENT (INCOME STATEMENT)');
    buffer.writeln('Tenant,${report.tenantName} (${report.tenantId})');
    buffer.writeln('Branch,${report.branchName}');
    buffer.writeln('Period,${report.periodLabel}');
    buffer.writeln('');
    buffer.writeln('Section,Code,Account Name,Amount (BDT)');

    for (final rev in report.revenue.items) {
      buffer.writeln('Revenue,${rev.accountCode},"${rev.accountName}",${rev.amountBdt.toStringAsFixed(2)}');
    }
    buffer.writeln('Revenue,TOTAL_NET,"Net Recognized Revenue",${report.revenue.netRevenueBdt.toStringAsFixed(2)}');

    for (final cogs in report.cogs.items) {
      buffer.writeln('COGS,${cogs.accountCode},"${cogs.accountName}",${cogs.amountBdt.toStringAsFixed(2)}');
    }
    buffer.writeln('COGS,TOTAL_COGS,"Total Cost of Goods Sold",${report.cogs.totalCogsBdt.toStringAsFixed(2)}');
    buffer.writeln('Summary,GROSS_PROFIT,"Gross Profit",${report.grossProfit.grossProfitBdt.toStringAsFixed(2)}');

    for (final exp in report.operatingExpenses.items) {
      buffer.writeln('OpEx,${exp.accountCode},"${exp.accountName}",${exp.amountBdt.toStringAsFixed(2)}');
    }
    buffer.writeln('OpEx,TOTAL_OPEX,"Total Operating Expenses",${report.operatingExpenses.totalOperatingExpensesBdt.toStringAsFixed(2)}');
    buffer.writeln('Summary,NET_PROFIT,"Net Operating Profit",${report.netOperatingProfit.netOperatingProfitBdt.toStringAsFixed(2)}');

    return buffer.toString();
  }
}
