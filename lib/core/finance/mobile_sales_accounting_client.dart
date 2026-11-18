// mobile_sales_accounting_client.dart
// Architecture Decision: ADR-0283 (P283).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class SalesAccountingPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  SalesAccountingPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class SalesAccountingValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  SalesAccountingValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class SaleAccountingPostingDto {
  final String postingId;
  final String tenantId;
  final String? branchId;
  final String invoiceNumber;
  final String? saleInvoiceId;
  final String? posSaleOrderId;
  final String postingDate;
  final String status;
  final bool isReversed;
  final double grossSalesBdt;
  final double discountBdt;
  final double taxVatBdt;
  final double netSettledBdt;
  final double receivableDueBdt;
  final double totalCogsBdt;
  final double grossProfitBdt;
  final double grossMarginPct;
  final String? revenueJournalId;
  final String? cogsJournalId;
  final String reversalReason;
  final String idempotencyKey;
  final bool isIdempotentReplay;

  SaleAccountingPostingDto({
    required this.postingId,
    required this.tenantId,
    this.branchId,
    required this.invoiceNumber,
    this.saleInvoiceId,
    this.posSaleOrderId,
    required this.postingDate,
    required this.status,
    this.isReversed = false,
    this.grossSalesBdt = 0.0,
    this.discountBdt = 0.0,
    this.taxVatBdt = 0.0,
    this.netSettledBdt = 0.0,
    this.receivableDueBdt = 0.0,
    this.totalCogsBdt = 0.0,
    this.grossProfitBdt = 0.0,
    this.grossMarginPct = 0.0,
    this.revenueJournalId,
    this.cogsJournalId,
    this.reversalReason = '',
    this.idempotencyKey = '',
    this.isIdempotentReplay = false,
  });

  factory SaleAccountingPostingDto.fromJson(Map<String, dynamic> json) {
    final gross = double.tryParse(json['gross_sales_bdt']?.toString() ?? '0') ?? 0.0;
    final disc = double.tryParse(json['discount_bdt']?.toString() ?? '0') ?? 0.0;
    final profit = double.tryParse(json['gross_profit_bdt']?.toString() ?? '0') ?? 0.0;
    final net = gross - disc;
    final margin = net > 0 ? (profit / net) * 100.0 : 0.0;

    return SaleAccountingPostingDto(
      postingId: json['posting_id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      saleInvoiceId: json['sale_invoice_id']?.toString(),
      posSaleOrderId: json['pos_sale_order_id']?.toString(),
      postingDate: json['posting_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'POSTED',
      isReversed: json['is_reversed'] == true,
      grossSalesBdt: gross,
      discountBdt: disc,
      taxVatBdt: double.tryParse(json['tax_vat_bdt']?.toString() ?? '0') ?? 0.0,
      netSettledBdt: double.tryParse(json['net_settled_bdt']?.toString() ?? '0') ?? 0.0,
      receivableDueBdt: double.tryParse(json['receivable_due_bdt']?.toString() ?? '0') ?? 0.0,
      totalCogsBdt: double.tryParse(json['total_cogs_bdt']?.toString() ?? '0') ?? 0.0,
      grossProfitBdt: profit,
      grossMarginPct: margin,
      revenueJournalId: json['revenue_journal_id']?.toString(),
      cogsJournalId: json['cogs_journal_id']?.toString(),
      reversalReason: json['reversal_reason']?.toString() ?? '',
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
      isIdempotentReplay: json['is_idempotent_replay'] == true,
    );
  }
}

class SalesProfitabilitySummaryDto {
  final String tenantId;
  final String branchId;
  final int totalSalesCount;
  final double grossSalesBdt;
  final double totalDiscountBdt;
  final double netSalesBdt;
  final double taxVatBdt;
  final double netSettledBdt;
  final double receivableDueBdt;
  final double totalCogsBdt;
  final double grossProfitBdt;
  final double grossMarginPct;
  final bool isProfitable;

  SalesProfitabilitySummaryDto({
    required this.tenantId,
    required this.branchId,
    required this.totalSalesCount,
    required this.grossSalesBdt,
    required this.totalDiscountBdt,
    required this.netSalesBdt,
    required this.taxVatBdt,
    required this.netSettledBdt,
    required this.receivableDueBdt,
    required this.totalCogsBdt,
    required this.grossProfitBdt,
    required this.grossMarginPct,
    required this.isProfitable,
  });

  factory SalesProfitabilitySummaryDto.fromJson(Map<String, dynamic> json) {
    return SalesProfitabilitySummaryDto(
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? 'ALL_BRANCHES',
      totalSalesCount: json['total_sales_count'] is int ? json['total_sales_count'] : 0,
      grossSalesBdt: double.tryParse(json['gross_sales_bdt']?.toString() ?? '0') ?? 0.0,
      totalDiscountBdt: double.tryParse(json['total_discount_bdt']?.toString() ?? '0') ?? 0.0,
      netSalesBdt: double.tryParse(json['net_sales_bdt']?.toString() ?? '0') ?? 0.0,
      taxVatBdt: double.tryParse(json['tax_vat_bdt']?.toString() ?? '0') ?? 0.0,
      netSettledBdt: double.tryParse(json['net_settled_bdt']?.toString() ?? '0') ?? 0.0,
      receivableDueBdt: double.tryParse(json['receivable_due_bdt']?.toString() ?? '0') ?? 0.0,
      totalCogsBdt: double.tryParse(json['total_cogs_bdt']?.toString() ?? '0') ?? 0.0,
      grossProfitBdt: double.tryParse(json['gross_profit_bdt']?.toString() ?? '0') ?? 0.0,
      grossMarginPct: double.tryParse(json['gross_margin_pct']?.toString() ?? '0') ?? 0.0,
      isProfitable: json['is_profitable'] == true,
    );
  }
}

class MobileSalesAccountingClient {
  static const Set<String> viewRoles = {
    'SUPERADMIN', 'PHARMACY_OWNER', 'BRANCH_MANAGER', 'FINANCE_OFFICER', 'AUDITOR', 'OWNER_ADMIN', 'ADMIN'
  };

  static const Set<String> postRoles = {
    'SUPERADMIN', 'PHARMACY_OWNER', 'BRANCH_MANAGER', 'FINANCE_OFFICER', 'CASHIER', 'STAFF_PHARMACIST', 'OWNER_ADMIN', 'ADMIN'
  };

  static const Set<String> reverseRoles = {
    'SUPERADMIN', 'PHARMACY_OWNER', 'FINANCE_OFFICER', 'OWNER_ADMIN', 'ADMIN'
  };

  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;

  final Map<String, SaleAccountingPostingDto> _mockPostings = {};

  MobileSalesAccountingClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
  });

  bool get isViewAuthorized => viewRoles.contains(userRole.toUpperCase());
  bool get isPostAuthorized => postRoles.contains(userRole.toUpperCase());
  bool get isReverseAuthorized => reverseRoles.contains(userRole.toUpperCase());

  void _assertViewAuthorized() {
    if (!isViewAuthorized) {
      throw SalesAccountingPermissionException(
        errorCode: 'ERR_SALES_ACCOUNTING_VIEW_DENIED',
        messageEn: 'User is not authorized to view sales accounting.',
        messageBn: 'সেলস অ্যাকাউন্টিং তথ্য দেখার অনুমতি নেই।',
      );
    }
  }

  void _assertPostAuthorized() {
    if (!isPostAuthorized) {
      throw SalesAccountingPermissionException(
        errorCode: 'ERR_SALES_ACCOUNTING_POST_UNAUTHORIZED',
        messageEn: 'User is not authorized to post sales accounting.',
        messageBn: 'সেলস অ্যাকাউন্টিং পোস্ট করার অনুমতি নেই।',
      );
    }
  }

  void _assertReverseAuthorized() {
    if (!isReverseAuthorized) {
      throw SalesAccountingPermissionException(
        errorCode: 'ERR_SALES_ACCOUNTING_REVERSE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can reverse sales accounting.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার রিভার্স করতে পারেন।',
      );
    }
  }

  SaleAccountingPostingDto postSaleAccounting({
    required String invoiceNumber,
    String? invoiceId,
    required double grossSalesBdt,
    double discountBdt = 0.0,
    double taxVatBdt = 0.0,
    double netSettledBdt = 0.0,
    double receivableDueBdt = 0.0,
    double totalCogsBdt = 0.0,
    String idempotencyKey = '',
  }) {
    _assertPostAuthorized();

    if (invoiceNumber.trim().isEmpty) {
      throw SalesAccountingValidationException(
        errorCode: 'ERR_MISSING_INVOICE_NUMBER',
        messageEn: 'Invoice number is required.',
        messageBn: 'চালান নম্বর প্রদান করা আবশ্যক।',
      );
    }

    if (grossSalesBdt <= 0.0) {
      throw SalesAccountingValidationException(
        errorCode: 'ERR_INVALID_SALE_AMOUNT',
        messageEn: 'Gross sales amount must be strictly positive.',
        messageBn: 'মোট বিক্রয় মূল্য অবশ্যই শূন্যের অধিক হতে হবে।',
      );
    }

    // Idempotency check
    if (idempotencyKey.isNotEmpty) {
      for (final p in _mockPostings.values) {
        if (p.idempotencyKey == idempotencyKey) {
          return SaleAccountingPostingDto(
            postingId: p.postingId,
            tenantId: p.tenantId,
            branchId: p.branchId,
            invoiceNumber: p.invoiceNumber,
            saleInvoiceId: p.saleInvoiceId,
            postingDate: p.postingDate,
            status: p.status,
            isReversed: p.isReversed,
            grossSalesBdt: p.grossSalesBdt,
            discountBdt: p.discountBdt,
            taxVatBdt: p.taxVatBdt,
            netSettledBdt: p.netSettledBdt,
            receivableDueBdt: p.receivableDueBdt,
            totalCogsBdt: p.totalCogsBdt,
            grossProfitBdt: p.grossProfitBdt,
            grossMarginPct: p.grossMarginPct,
            revenueJournalId: p.revenueJournalId,
            cogsJournalId: p.cogsJournalId,
            idempotencyKey: p.idempotencyKey,
            isIdempotentReplay: true,
          );
        }
      }
    }

    final netSales = grossSalesBdt - discountBdt;
    final grossProfit = netSales - totalCogsBdt;
    final marginPct = netSales > 0 ? (grossProfit / netSales) * 100.0 : 0.0;

    final postingId = 'sap_${DateTime.now().millisecondsSinceEpoch}_${invoiceNumber.hashCode}';
    final dto = SaleAccountingPostingDto(
      postingId: postingId,
      tenantId: tenantId,
      branchId: branchId,
      invoiceNumber: invoiceNumber,
      saleInvoiceId: invoiceId,
      postingDate: DateTime.now().toIso8601String().substring(0, 10),
      status: 'POSTED',
      isReversed: false,
      grossSalesBdt: grossSalesBdt,
      discountBdt: discountBdt,
      taxVatBdt: taxVatBdt,
      netSettledBdt: netSettledBdt,
      receivableDueBdt: receivableDueBdt,
      totalCogsBdt: totalCogsBdt,
      grossProfitBdt: grossProfit,
      grossMarginPct: marginPct,
      revenueJournalId: 'jrn_rev_$postingId',
      cogsJournalId: totalCogsBdt > 0 ? 'jrn_cog_$postingId' : null,
      idempotencyKey: idempotencyKey,
      isIdempotentReplay: false,
    );

    _mockPostings[postingId] = dto;
    return dto;
  }

  Map<String, dynamic> reverseSaleAccounting(String postingId, String reason) {
    _assertReverseAuthorized();

    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw SalesAccountingValidationException(
        errorCode: 'ERR_MISSING_REVERSAL_REASON',
        messageEn: 'Mandatory explanation reason required for reversal.',
        messageBn: 'রিভার্সালের জন্য কারণ উল্লেখ করা বাধ্যতামূলক।',
      );
    }

    final posting = _mockPostings[postingId];
    if (posting == null) {
      throw SalesAccountingValidationException(
        errorCode: 'ERR_POSTING_NOT_FOUND',
        messageEn: 'Sales accounting posting not found.',
        messageBn: 'সেলস অ্যাকাউন্টিং পোস্টিং পাওয়া যায়নি।',
      );
    }

    if (posting.isReversed || posting.status == 'REVERSED') {
      throw SalesAccountingValidationException(
        errorCode: 'ERR_ALREADY_REVERSED',
        messageEn: 'Posting is already reversed.',
        messageBn: 'এই পোস্টিংটি পূর্বেই রিভার্স করা হয়েছে।',
      );
    }

    final updated = SaleAccountingPostingDto(
      postingId: posting.postingId,
      tenantId: posting.tenantId,
      branchId: posting.branchId,
      invoiceNumber: posting.invoiceNumber,
      saleInvoiceId: posting.saleInvoiceId,
      postingDate: posting.postingDate,
      status: 'REVERSED',
      isReversed: true,
      grossSalesBdt: posting.grossSalesBdt,
      discountBdt: posting.discountBdt,
      taxVatBdt: posting.taxVatBdt,
      netSettledBdt: posting.netSettledBdt,
      receivableDueBdt: posting.receivableDueBdt,
      totalCogsBdt: posting.totalCogsBdt,
      grossProfitBdt: posting.grossProfitBdt,
      grossMarginPct: posting.grossMarginPct,
      revenueJournalId: posting.revenueJournalId,
      cogsJournalId: posting.cogsJournalId,
      reversalReason: cleanReason,
      idempotencyKey: posting.idempotencyKey,
    );

    _mockPostings[postingId] = updated;

    return {
      'success': true,
      'posting_id': postingId,
      'status': 'REVERSED',
      'reversal_reason': cleanReason,
      'message_en': 'Sales accounting posting reversed successfully.',
      'message_bn': 'সেলস অ্যাকাউন্টিং পোস্টিং সফলভাবে রিভার্স করা হয়েছে।',
    };
  }

  SalesProfitabilitySummaryDto getProfitabilitySummary() {
    _assertViewAuthorized();

    double totalGross = 0.0;
    double totalDiscount = 0.0;
    double totalTax = 0.0;
    double totalSettled = 0.0;
    double totalDue = 0.0;
    double totalCogs = 0.0;
    double totalProfit = 0.0;
    int activeCount = 0;

    for (final p in _mockPostings.values) {
      if (!p.isReversed && p.status == 'POSTED') {
        totalGross += p.grossSalesBdt;
        totalDiscount += p.discountBdt;
        totalTax += p.taxVatBdt;
        totalSettled += p.netSettledBdt;
        totalDue += p.receivableDueBdt;
        totalCogs += p.totalCogsBdt;
        totalProfit += p.grossProfitBdt;
        activeCount++;
      }
    }

    final netSales = totalGross - totalDiscount;
    final marginPct = netSales > 0 ? (totalProfit / netSales) * 100.0 : 0.0;

    return SalesProfitabilitySummaryDto(
      tenantId: tenantId,
      branchId: branchId.isNotEmpty ? branchId : 'ALL_BRANCHES',
      totalSalesCount: activeCount,
      grossSalesBdt: totalGross,
      totalDiscountBdt: totalDiscount,
      netSalesBdt: netSales,
      taxVatBdt: totalTax,
      netSettledBdt: totalSettled,
      receivableDueBdt: totalDue,
      totalCogsBdt: totalCogs,
      grossProfitBdt: totalProfit,
      grossMarginPct: marginPct,
      isProfitable: totalProfit >= 0.0,
    );
  }
}
