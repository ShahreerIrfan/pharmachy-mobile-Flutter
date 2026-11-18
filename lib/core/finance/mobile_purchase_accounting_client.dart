// mobile_purchase_accounting_client.dart
// Architecture Decision: ADR-0284 (P284).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class PurchaseAccountingPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PurchaseAccountingPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PurchaseAccountingValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PurchaseAccountingValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PurchaseAccountingPostingDto {
  final String postingId;
  final String tenantId;
  final String? branchId;
  final String? supplierId;
  final String supplierName;
  final String? grnId;
  final String postingDate;
  final String postingType;
  final String status;
  final bool isReversed;
  final double totalInventoryCostBdt;
  final double liabilityApBdt;
  final double settledCashBdt;
  final double settledBankBdt;
  final bool isOperatingExpense;
  final String? journalId;
  final String? journalNumber;
  final String reversalReason;
  final String idempotencyKey;
  final bool isIdempotentReplay;

  PurchaseAccountingPostingDto({
    required this.postingId,
    required this.tenantId,
    this.branchId,
    this.supplierId,
    required this.supplierName,
    this.grnId,
    required this.postingDate,
    required this.postingType,
    required this.status,
    this.isReversed = false,
    this.totalInventoryCostBdt = 0.0,
    this.liabilityApBdt = 0.0,
    this.settledCashBdt = 0.0,
    this.settledBankBdt = 0.0,
    this.isOperatingExpense = false,
    this.journalId,
    this.journalNumber,
    this.reversalReason = '',
    this.idempotencyKey = '',
    this.isIdempotentReplay = false,
  });

  factory PurchaseAccountingPostingDto.fromJson(Map<String, dynamic> json) {
    return PurchaseAccountingPostingDto(
      postingId: json['posting_id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      supplierId: json['supplier_id']?.toString(),
      supplierName: json['supplier_name']?.toString() ?? '',
      grnId: json['grn_id']?.toString(),
      postingDate: json['posting_date']?.toString() ?? '',
      postingType: json['posting_type']?.toString() ?? 'INVOICE_RECOGNITION',
      status: json['status']?.toString() ?? 'POSTED',
      isReversed: json['is_reversed'] == true,
      totalInventoryCostBdt: double.tryParse(json['total_inventory_cost_bdt']?.toString() ?? '0') ?? 0.0,
      liabilityApBdt: double.tryParse(json['liability_ap_bdt']?.toString() ?? '0') ?? 0.0,
      settledCashBdt: double.tryParse(json['settled_cash_bdt']?.toString() ?? '0') ?? 0.0,
      settledBankBdt: double.tryParse(json['settled_bank_bdt']?.toString() ?? '0') ?? 0.0,
      isOperatingExpense: json['is_operating_expense'] == true,
      journalId: json['journal_id']?.toString(),
      journalNumber: json['journal_number']?.toString(),
      reversalReason: json['reversal_reason']?.toString() ?? '',
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
      isIdempotentReplay: json['is_idempotent_replay'] == true,
    );
  }
}

class PurchaseAccountingSummaryDto {
  final String tenantId;
  final String branchId;
  final int grnPostingsCount;
  final int paymentPostingsCount;
  final double totalInventoryCapitalizedBdt;
  final double totalApRecognizedBdt;
  final double immediateDeliverySettledBdt;
  final double totalSupplierPaymentsDisbursedBdt;
  final double netOutstandingApLiabilityBdt;
  final double totalOperatingExpensesBdt;
  final bool isOperatingExpense;

  PurchaseAccountingSummaryDto({
    required this.tenantId,
    required this.branchId,
    required this.grnPostingsCount,
    required this.paymentPostingsCount,
    required this.totalInventoryCapitalizedBdt,
    required this.totalApRecognizedBdt,
    required this.immediateDeliverySettledBdt,
    required this.totalSupplierPaymentsDisbursedBdt,
    required this.netOutstandingApLiabilityBdt,
    this.totalOperatingExpensesBdt = 0.0,
    this.isOperatingExpense = false,
  });

  factory PurchaseAccountingSummaryDto.fromJson(Map<String, dynamic> json) {
    return PurchaseAccountingSummaryDto(
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? 'ALL_BRANCHES',
      grnPostingsCount: json['grn_postings_count'] is int ? json['grn_postings_count'] : 0,
      paymentPostingsCount: json['payment_postings_count'] is int ? json['payment_postings_count'] : 0,
      totalInventoryCapitalizedBdt: double.tryParse(json['total_inventory_capitalized_bdt']?.toString() ?? '0') ?? 0.0,
      totalApRecognizedBdt: double.tryParse(json['total_ap_recognized_bdt']?.toString() ?? '0') ?? 0.0,
      immediateDeliverySettledBdt: double.tryParse(json['immediate_delivery_settled_bdt']?.toString() ?? '0') ?? 0.0,
      totalSupplierPaymentsDisbursedBdt: double.tryParse(json['total_supplier_payments_disbursed_bdt']?.toString() ?? '0') ?? 0.0,
      netOutstandingApLiabilityBdt: double.tryParse(json['net_outstanding_ap_liability_bdt']?.toString() ?? '0') ?? 0.0,
      totalOperatingExpensesBdt: double.tryParse(json['total_operating_expenses_bdt']?.toString() ?? '0') ?? 0.0,
      isOperatingExpense: json['is_operating_expense'] == true,
    );
  }
}

class MobilePurchaseAccountingClient {
  static const Set<String> viewRoles = {
    'SUPERADMIN', 'PHARMACY_OWNER', 'BRANCH_MANAGER', 'FINANCE_OFFICER', 'AUDITOR', 'OWNER_ADMIN', 'ADMIN'
  };

  static const Set<String> grnPostRoles = {
    'SUPERADMIN', 'PHARMACY_OWNER', 'BRANCH_MANAGER', 'FINANCE_OFFICER', 'OWNER_ADMIN', 'ADMIN'
  };

  static const Set<String> paymentRoles = {
    'SUPERADMIN', 'PHARMACY_OWNER', 'FINANCE_OFFICER', 'OWNER_ADMIN', 'ADMIN'
  };

  static const Set<String> reverseRoles = {
    'SUPERADMIN', 'PHARMACY_OWNER', 'FINANCE_OFFICER', 'OWNER_ADMIN', 'ADMIN'
  };

  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;

  final Map<String, PurchaseAccountingPostingDto> _mockPostings = {};

  MobilePurchaseAccountingClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
  });

  bool get isViewAuthorized => viewRoles.contains(userRole.toUpperCase());
  bool get isGrnPostAuthorized => grnPostRoles.contains(userRole.toUpperCase());
  bool get isPaymentAuthorized => paymentRoles.contains(userRole.toUpperCase());
  bool get isReverseAuthorized => reverseRoles.contains(userRole.toUpperCase());

  void _assertViewAuthorized() {
    if (!isViewAuthorized) {
      throw PurchaseAccountingPermissionException(
        errorCode: 'ERR_PURCHASE_ACCOUNTING_VIEW_DENIED',
        messageEn: 'User is not authorized to view purchase accounting.',
        messageBn: 'ক্রয় অ্যাকাউন্টিং তথ্য দেখার অনুমতি নেই।',
      );
    }
  }

  void _assertGrnPostAuthorized() {
    if (!isGrnPostAuthorized) {
      throw PurchaseAccountingPermissionException(
        errorCode: 'ERR_PURCHASE_GRN_POST_UNAUTHORIZED',
        messageEn: 'User is not authorized to post GRN purchase accounting.',
        messageBn: 'জিআরএন ক্রয় অ্যাকাউন্টিং পোস্ট করার অনুমতি নেই।',
      );
    }
  }

  void _assertPaymentAuthorized() {
    if (!isPaymentAuthorized) {
      throw PurchaseAccountingPermissionException(
        errorCode: 'ERR_SUPPLIER_PAYMENT_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can disburse supplier payments.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার পেমেন্ট অনুমোদন করতে পারেন।',
      );
    }
  }

  void _assertReverseAuthorized() {
    if (!isReverseAuthorized) {
      throw PurchaseAccountingPermissionException(
        errorCode: 'ERR_PURCHASE_ACCOUNTING_REVERSE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can reverse purchase accounting.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার রিভার্স করতে পারেন।',
      );
    }
  }

  PurchaseAccountingPostingDto postGrnInvoiceRecognition({
    String? grnId,
    String? supplierId,
    required String supplierName,
    required double totalCostBdt,
    double paidCashBdt = 0.0,
    double paidBankBdt = 0.0,
    String idempotencyKey = '',
  }) {
    _assertGrnPostAuthorized();

    if (totalCostBdt <= 0.0) {
      throw PurchaseAccountingValidationException(
        errorCode: 'ERR_INVALID_PURCHASE_AMOUNT',
        messageEn: 'Purchase cost must be strictly positive.',
        messageBn: 'ক্রয় মূল্য অবশ্যই শূন্যের অধিক হতে হবে।',
      );
    }

    final immediatePaid = paidCashBdt + paidBankBdt;
    if (immediatePaid > totalCostBdt) {
      throw PurchaseAccountingValidationException(
        errorCode: 'ERR_OVERPAYMENT_EXCEEDS_COST',
        messageEn: 'Immediate delivery payment exceeds invoice cost.',
        messageBn: 'তাৎক্ষণিক পরিশোধিত অর্থ মোট ক্রয় মূল্যের বেশি হতে পারে না।',
      );
    }

    // Idempotency check
    if (idempotencyKey.isNotEmpty) {
      for (final p in _mockPostings.values) {
        if (p.idempotencyKey == idempotencyKey) {
          return PurchaseAccountingPostingDto(
            postingId: p.postingId,
            tenantId: p.tenantId,
            branchId: p.branchId,
            supplierId: p.supplierId,
            supplierName: p.supplierName,
            grnId: p.grnId,
            postingDate: p.postingDate,
            postingType: p.postingType,
            status: p.status,
            isReversed: p.isReversed,
            totalInventoryCostBdt: p.totalInventoryCostBdt,
            liabilityApBdt: p.liabilityApBdt,
            settledCashBdt: p.settledCashBdt,
            settledBankBdt: p.settledBankBdt,
            isOperatingExpense: false,
            journalId: p.journalId,
            journalNumber: p.journalNumber,
            idempotencyKey: p.idempotencyKey,
            isIdempotentReplay: true,
          );
        }
      }
    }

    final liabilityAp = totalCostBdt - immediatePaid;
    final postingId = 'pap_${DateTime.now().millisecondsSinceEpoch}_${totalCostBdt.toInt()}';
    final dto = PurchaseAccountingPostingDto(
      postingId: postingId,
      tenantId: tenantId,
      branchId: branchId,
      supplierId: supplierId,
      supplierName: supplierName,
      grnId: grnId,
      postingDate: DateTime.now().toIso8601String().substring(0, 10),
      postingType: 'INVOICE_RECOGNITION',
      status: 'POSTED',
      isReversed: false,
      totalInventoryCostBdt: totalCostBdt,
      liabilityApBdt: liabilityAp,
      settledCashBdt: paidCashBdt,
      settledBankBdt: paidBankBdt,
      isOperatingExpense: false, // Critical domain rule
      journalId: 'jrn_grn_$postingId',
      journalNumber: 'JRN-GRN-$postingId',
      idempotencyKey: idempotencyKey,
      isIdempotentReplay: false,
    );

    _mockPostings[postingId] = dto;
    return dto;
  }

  PurchaseAccountingPostingDto postSupplierPayment({
    required String supplierId,
    required String supplierName,
    required double paymentAmountBdt,
    String paymentMode = 'BANK',
    String idempotencyKey = '',
  }) {
    _assertPaymentAuthorized();

    if (paymentAmountBdt <= 0.0) {
      throw PurchaseAccountingValidationException(
        errorCode: 'ERR_INVALID_PAYMENT_AMOUNT',
        messageEn: 'Payment amount must be strictly positive.',
        messageBn: 'পরিশোধিত অর্থ অবশ্যই শূন্যের অধিক হতে হবে।',
      );
    }

    final isCash = paymentMode.toUpperCase() == 'CASH';
    final postingId = 'pap_pmt_${DateTime.now().millisecondsSinceEpoch}';

    final dto = PurchaseAccountingPostingDto(
      postingId: postingId,
      tenantId: tenantId,
      branchId: branchId,
      supplierId: supplierId,
      supplierName: supplierName,
      postingDate: DateTime.now().toIso8601String().substring(0, 10),
      postingType: 'SUPPLIER_PAYMENT',
      status: 'POSTED',
      isReversed: false,
      totalInventoryCostBdt: 0.0,
      liabilityApBdt: 0.0,
      settledCashBdt: isCash ? paymentAmountBdt : 0.0,
      settledBankBdt: !isCash ? paymentAmountBdt : 0.0,
      isOperatingExpense: false,
      journalId: 'jrn_pmt_$postingId',
      journalNumber: 'JRN-PMT-$postingId',
      idempotencyKey: idempotencyKey,
      isIdempotentReplay: false,
    );

    _mockPostings[postingId] = dto;
    return dto;
  }

  Map<String, dynamic> reversePurchaseAccounting(String postingId, String reason) {
    _assertReverseAuthorized();

    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw PurchaseAccountingValidationException(
        errorCode: 'ERR_MISSING_REVERSAL_REASON',
        messageEn: 'Mandatory explanation reason required for reversal.',
        messageBn: 'রিভার্সালের জন্য কারণ উল্লেখ করা বাধ্যতামূলক।',
      );
    }

    final posting = _mockPostings[postingId];
    if (posting == null) {
      throw PurchaseAccountingValidationException(
        errorCode: 'ERR_POSTING_NOT_FOUND',
        messageEn: 'Purchase posting not found.',
        messageBn: 'ক্রয় পোস্টিং পাওয়া যায়নি।',
      );
    }

    if (posting.isReversed || posting.status == 'REVERSED') {
      throw PurchaseAccountingValidationException(
        errorCode: 'ERR_ALREADY_REVERSED',
        messageEn: 'Posting is already reversed.',
        messageBn: 'এই পোস্টিংটি পূর্বেই রিভার্স করা হয়েছে।',
      );
    }

    final updated = PurchaseAccountingPostingDto(
      postingId: posting.postingId,
      tenantId: posting.tenantId,
      branchId: posting.branchId,
      supplierId: posting.supplierId,
      supplierName: posting.supplierName,
      grnId: posting.grnId,
      postingDate: posting.postingDate,
      postingType: posting.postingType,
      status: 'REVERSED',
      isReversed: true,
      totalInventoryCostBdt: posting.totalInventoryCostBdt,
      liabilityApBdt: posting.liabilityApBdt,
      settledCashBdt: posting.settledCashBdt,
      settledBankBdt: posting.settledBankBdt,
      isOperatingExpense: false,
      journalId: posting.journalId,
      journalNumber: posting.journalNumber,
      reversalReason: cleanReason,
      idempotencyKey: posting.idempotencyKey,
    );

    _mockPostings[postingId] = updated;

    return {
      'success': true,
      'posting_id': postingId,
      'status': 'REVERSED',
      'reversal_reason': cleanReason,
      'message_en': 'Purchase accounting posting reversed successfully.',
      'message_bn': 'ক্রয় অ্যাকাউন্টিং পোস্টিং সফলভাবে রিভার্স করা হয়েছে।',
    };
  }

  PurchaseAccountingSummaryDto getPurchaseSummary() {
    _assertViewAuthorized();

    double totalInventory = 0.0;
    double totalApRecognized = 0.0;
    double immediatePaid = 0.0;
    double totalPayments = 0.0;
    int grnCount = 0;
    int pmtCount = 0;

    for (final p in _mockPostings.values) {
      if (!p.isReversed && p.status == 'POSTED') {
        if (p.postingType == 'INVOICE_RECOGNITION') {
          totalInventory += p.totalInventoryCostBdt;
          totalApRecognized += p.liabilityApBdt;
          immediatePaid += (p.settledCashBdt + p.settledBankBdt);
          grnCount++;
        } else if (p.postingType == 'SUPPLIER_PAYMENT') {
          totalPayments += (p.settledCashBdt + p.settledBankBdt);
          pmtCount++;
        }
      }
    }

    final netAp = totalApRecognized - totalPayments;

    return PurchaseAccountingSummaryDto(
      tenantId: tenantId,
      branchId: branchId.isNotEmpty ? branchId : 'ALL_BRANCHES',
      grnPostingsCount: grnCount,
      paymentPostingsCount: pmtCount,
      totalInventoryCapitalizedBdt: totalInventory,
      totalApRecognizedBdt: totalApRecognized,
      immediateDeliverySettledBdt: immediatePaid,
      totalSupplierPaymentsDisbursedBdt: totalPayments,
      netOutstandingApLiabilityBdt: netAp,
      totalOperatingExpensesBdt: 0.0, // Critical rule: 0.00 operating expense
      isOperatingExpense: false,
    );
  }
}
