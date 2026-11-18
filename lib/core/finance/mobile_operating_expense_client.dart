// mobile_operating_expense_client.dart
// Architecture Decision: ADR-0287 (P287) & ADR-0289 (P289).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class OperatingExpensePermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  OperatingExpensePermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class OperatingExpenseValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  OperatingExpenseValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class OperatingExpenseEntryDto {
  final String expenseId;
  final String voucherNumber;
  final String tenantId;
  final String branchId;
  final String categoryId;
  final String categoryName;
  final String categoryCode;
  final String payeeName;
  final String payeePhone;
  final String expenseDate;
  final double amountBdt;
  final String paymentMethod;
  final String paymentReference;
  final String status;
  final String receiptFileUrl;
  final String notes;
  final bool taxDeductible;
  final bool isReimbursable;
  final String claimantName;
  final String? claimantUserId;
  final String reimbursementStatus;
  final String? reimbursedAt;
  final String? reimbursedBy;
  final String reimbursementReference;
  final String reimbursementPaymentMethod;
  final bool isHighValue;
  final String? approvedBy;
  final String? approvedAt;
  final String approvalNotes;
  final String rejectionReason;
  final String? postedJournalNumber;
  final String createdAt;

  OperatingExpenseEntryDto({
    required this.expenseId,
    required this.voucherNumber,
    required this.tenantId,
    required this.branchId,
    required this.categoryId,
    required this.categoryName,
    required this.categoryCode,
    required this.payeeName,
    required this.payeePhone,
    required this.expenseDate,
    required this.amountBdt,
    required this.paymentMethod,
    required this.paymentReference,
    required this.status,
    required this.receiptFileUrl,
    required this.notes,
    required this.taxDeductible,
    this.isReimbursable = false,
    this.claimantName = '',
    this.claimantUserId,
    this.reimbursementStatus = 'NOT_APPLICABLE',
    this.reimbursedAt,
    this.reimbursedBy,
    this.reimbursementReference = '',
    this.reimbursementPaymentMethod = '',
    this.isHighValue = false,
    this.approvedBy,
    this.approvedAt,
    required this.approvalNotes,
    required this.rejectionReason,
    this.postedJournalNumber,
    required this.createdAt,
  });

  factory OperatingExpenseEntryDto.fromJson(Map<String, dynamic> json) {
    return OperatingExpenseEntryDto(
      expenseId: json['expense_id'] ?? '',
      voucherNumber: json['voucher_number'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'] ?? '',
      categoryId: json['category_id'] ?? '',
      categoryName: json['category_name'] ?? '',
      categoryCode: json['category_code'] ?? '',
      payeeName: json['payee_name'] ?? '',
      payeePhone: json['payee_phone'] ?? '',
      expenseDate: json['expense_date'] ?? '',
      amountBdt: double.tryParse(json['amount_bdt']?.toString() ?? '0') ?? 0.0,
      paymentMethod: json['payment_method'] ?? 'CASH',
      paymentReference: json['payment_reference'] ?? '',
      status: json['status'] ?? 'DRAFT',
      receiptFileUrl: json['receipt_file_url'] ?? '',
      notes: json['notes'] ?? '',
      taxDeductible: json['tax_deductible'] ?? true,
      isReimbursable: json['is_reimbursable'] ?? false,
      claimantName: json['claimant_name'] ?? '',
      claimantUserId: json['claimant_user_id'],
      reimbursementStatus: json['reimbursement_status'] ?? 'NOT_APPLICABLE',
      reimbursedAt: json['reimbursed_at'],
      reimbursedBy: json['reimbursed_by'],
      reimbursementReference: json['reimbursement_reference'] ?? '',
      reimbursementPaymentMethod: json['reimbursement_payment_method'] ?? '',
      isHighValue: json['is_high_value'] ?? false,
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at'],
      approvalNotes: json['approval_notes'] ?? '',
      rejectionReason: json['rejection_reason'] ?? '',
      postedJournalNumber: json['posted_journal_number'],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expense_id': expenseId,
      'voucher_number': voucherNumber,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'category_id': categoryId,
      'category_name': categoryName,
      'category_code': categoryCode,
      'payee_name': payeeName,
      'payee_phone': payeePhone,
      'expense_date': expenseDate,
      'amount_bdt': amountBdt.toStringAsFixed(2),
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'status': status,
      'receipt_file_url': receiptFileUrl,
      'notes': notes,
      'tax_deductible': taxDeductible,
      'is_reimbursable': isReimbursable,
      'claimant_name': claimantName,
      'claimant_user_id': claimantUserId,
      'reimbursement_status': reimbursementStatus,
      'reimbursed_at': reimbursedAt,
      'reimbursed_by': reimbursedBy,
      'reimbursement_reference': reimbursementReference,
      'reimbursement_payment_method': reimbursementPaymentMethod,
      'is_high_value': isHighValue,
      'approved_by': approvedBy,
      'approved_at': approvedAt,
      'approval_notes': approvalNotes,
      'rejection_reason': rejectionReason,
      'posted_journal_number': postedJournalNumber,
      'created_at': createdAt,
    };
  }

  OperatingExpenseEntryDto copyWith({
    String? status,
    String? approvedBy,
    String? approvedAt,
    String? approvalNotes,
    String? rejectionReason,
    String? postedJournalNumber,
    String? notes,
    double? amountBdt,
    String? reimbursementStatus,
    String? reimbursedAt,
    String? reimbursedBy,
    String? reimbursementReference,
    String? reimbursementPaymentMethod,
  }) {
    return OperatingExpenseEntryDto(
      expenseId: expenseId,
      voucherNumber: voucherNumber,
      tenantId: tenantId,
      branchId: branchId,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryCode: categoryCode,
      payeeName: payeeName,
      payeePhone: payeePhone,
      expenseDate: expenseDate,
      amountBdt: amountBdt ?? this.amountBdt,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      status: status ?? this.status,
      receiptFileUrl: receiptFileUrl,
      notes: notes ?? this.notes,
      taxDeductible: taxDeductible,
      isReimbursable: isReimbursable,
      claimantName: claimantName,
      claimantUserId: claimantUserId,
      reimbursementStatus: reimbursementStatus ?? this.reimbursementStatus,
      reimbursedAt: reimbursedAt ?? this.reimbursedAt,
      reimbursedBy: reimbursedBy ?? this.reimbursedBy,
      reimbursementReference: reimbursementReference ?? this.reimbursementReference,
      reimbursementPaymentMethod: reimbursementPaymentMethod ?? this.reimbursementPaymentMethod,
      isHighValue: isHighValue,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvalNotes: approvalNotes ?? this.approvalNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      postedJournalNumber: postedJournalNumber ?? this.postedJournalNumber,
      createdAt: createdAt,
    );
  }
}

class MobileOperatingExpenseClient {
  static const double highValueThreshold = 5000.00;

  static const Set<String> viewRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> createRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> approveRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> seniorApproveRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;

  static final Map<String, OperatingExpenseEntryDto> _cache = {};

  MobileOperatingExpenseClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
  });

  bool get isViewAuthorized => viewRoles.contains(userRole.toUpperCase());
  bool get isCreateAuthorized => createRoles.contains(userRole.toUpperCase());
  bool get isApproveAuthorized => approveRoles.contains(userRole.toUpperCase());
  bool get isSeniorApproveAuthorized => seniorApproveRoles.contains(userRole.toUpperCase());

  OperatingExpenseEntryDto createDraft({
    required String categoryId,
    required String categoryName,
    required String categoryCode,
    required String payeeName,
    String payeePhone = '',
    required double amountBdt,
    String paymentMethod = 'CASH',
    String paymentReference = '',
    String receiptFileUrl = '',
    String notes = '',
    bool taxDeductible = true,
    bool isReimbursable = false,
    String claimantName = '',
  }) {
    if (!isCreateAuthorized) {
      throw OperatingExpensePermissionException(
        errorCode: 'ERR_EXPENSE_CREATE_UNAUTHORIZED',
        messageEn: 'Cashier is not authorized to create operating expense entries.',
        messageBn: 'ক্যাশিয়ার অপারেটিং খরচ তৈরি করার অনুমতিপ্রাপ্ত নন।',
      );
    }

    final trimmedPayee = payeeName.trim();
    if (trimmedPayee.isEmpty) {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_MISSING_PAYEE',
        messageEn: 'Payee name is required.',
        messageBn: 'প্রাপকের নাম আবশ্যক।',
      );
    }

    if (amountBdt <= 0) {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_INVALID_EXPENSE_AMOUNT',
        messageEn: 'Expense amount must be greater than zero.',
        messageBn: 'খরচের পরিমাণ অবশ্যই শূন্যের চেয়ে বেশি হতে হবে।',
      );
    }

    final expenseId = 'opexp-${DateTime.now().millisecondsSinceEpoch}';
    final voucherNumber = 'EXP-MBL-${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}';
    final isHighVal = amountBdt >= highValueThreshold;
    final resolvedClaimant = isReimbursable && claimantName.trim().isEmpty ? userId : claimantName.trim();

    final dto = OperatingExpenseEntryDto(
      expenseId: expenseId,
      voucherNumber: voucherNumber,
      tenantId: tenantId,
      branchId: branchId,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryCode: categoryCode,
      payeeName: trimmedPayee,
      payeePhone: payeePhone.trim(),
      expenseDate: DateTime.now().toIso8601String().substring(0, 10),
      amountBdt: amountBdt,
      paymentMethod: paymentMethod.toUpperCase(),
      paymentReference: paymentReference.trim(),
      status: 'DRAFT',
      receiptFileUrl: receiptFileUrl.trim(),
      notes: notes.trim(),
      taxDeductible: taxDeductible,
      isReimbursable: isReimbursable,
      claimantName: resolvedClaimant,
      claimantUserId: isReimbursable ? userId : null,
      reimbursementStatus: isReimbursable ? 'PENDING_REVIEW' : 'NOT_APPLICABLE',
      isHighValue: isHighVal,
      approvalNotes: '',
      rejectionReason: '',
      createdAt: DateTime.now().toIso8601String(),
    );

    _cache[expenseId] = dto;
    return dto;
  }

  OperatingExpenseEntryDto approveExpense(String expenseId, {String approvalNotes = ''}) {
    if (!isApproveAuthorized) {
      throw OperatingExpensePermissionException(
        errorCode: 'ERR_EXPENSE_APPROVE_UNAUTHORIZED',
        messageEn: 'Unauthorized to approve operating expenses.',
        messageBn: 'খরচ অনুমোদন করার অনুমতি নেই।',
      );
    }

    final existing = _cache[expenseId];
    if (existing == null) {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_EXPENSE_NOT_FOUND',
        messageEn: 'Expense voucher not found.',
        messageBn: 'খরচ ভাউচার খুঁজে পাওয়া যায়নি।',
      );
    }

    if (existing.status == 'APPROVED' || existing.status == 'REVERSED') {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_EXPENSE_ALREADY_APPROVED',
        messageEn: 'Expense voucher has already been approved or reversed.',
        messageBn: 'খরচ ভাউচারটি ইতোমধ্যে অনুমোদিত বা বাতিল করা হয়েছে।',
      );
    }

    if ((existing.isHighValue || existing.amountBdt >= highValueThreshold || existing.isReimbursable) &&
        !isSeniorApproveAuthorized) {
      throw OperatingExpensePermissionException(
        errorCode: 'ERR_HIGH_VALUE_APPROVAL_REQUIRED',
        messageEn: 'High-value or reimbursable expenses require Owner or Finance Officer approval.',
        messageBn: 'উচ্চমূল্যের বা রিইম্বার্সমেন্ট খরচ অনুমোদনের জন্য ওনার বা ফিন্যান্স অফিসারের অনুমোদন আবশ্যক।',
      );
    }

    if (existing.isReimbursable && existing.claimantUserId == userId) {
      throw OperatingExpensePermissionException(
        errorCode: 'ERR_SELF_APPROVAL_FORBIDDEN',
        messageEn: 'Claimants cannot approve their own reimbursement claims.',
        messageBn: 'দাবিকারক নিজে নিজের রিইম্বার্সমেন্ট ক্লেইম অনুমোদন করতে পারবেন না।',
      );
    }

    final updated = existing.copyWith(
      status: 'APPROVED',
      approvedBy: userId,
      approvedAt: DateTime.now().toIso8601String(),
      approvalNotes: approvalNotes.trim(),
      postedJournalNumber: 'JRN-OPEX-${DateTime.now().millisecondsSinceEpoch}',
      reimbursementStatus: existing.isReimbursable ? 'APPROVED_PENDING_PAYOUT' : existing.reimbursementStatus,
    );

    _cache[expenseId] = updated;
    return updated;
  }

  OperatingExpenseEntryDto reimburseExpense(String expenseId, {String payoutMethod = 'CASH', String reference = ''}) {
    if (!isApproveAuthorized) {
      throw OperatingExpensePermissionException(
        errorCode: 'ERR_UNAUTHORIZED',
        messageEn: 'Unauthorized to disburse reimbursement.',
        messageBn: 'রিইম্বার্সমেন্ট পরিশোধের অনুমতি নেই।',
      );
    }

    final existing = _cache[expenseId];
    if (existing == null) {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_EXPENSE_NOT_FOUND',
        messageEn: 'Expense voucher not found.',
        messageBn: 'খরচ ভাউচার খুঁজে পাওয়া যায়নি।',
      );
    }

    if (!existing.isReimbursable) {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_NOT_REIMBURSABLE',
        messageEn: 'Expense is not reimbursable.',
        messageBn: 'খরচটি রিইম্বার্সযোগ্য নয়।',
      );
    }

    if (existing.status != 'APPROVED') {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_EXPENSE_NOT_APPROVED',
        messageEn: 'Only approved expenses can be reimbursed.',
        messageBn: 'শুধুমাত্র অনুমোদিত খরচের রিইম্বার্সমেন্ট করা যায়।',
      );
    }

    if (existing.reimbursementStatus == 'PAID_OUT') {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_ALREADY_REIMBURSED',
        messageEn: 'Expense claim already reimbursed.',
        messageBn: 'রিইম্বার্সমেন্ট দাবি ইতোমধ্যে পরিশোধিত হয়েছে।',
      );
    }

    final updated = existing.copyWith(
      reimbursementStatus: 'PAID_OUT',
      reimbursedAt: DateTime.now().toIso8601String(),
      reimbursedBy: userId,
      reimbursementReference: reference.trim(),
      reimbursementPaymentMethod: payoutMethod.toUpperCase(),
    );

    _cache[expenseId] = updated;
    return updated;
  }

  OperatingExpenseEntryDto correctExpense(String expenseId, {required String correctionType, required String reason, double? correctedAmount}) {
    if (!isSeniorApproveAuthorized) {
      throw OperatingExpensePermissionException(
        errorCode: 'ERR_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can execute expense corrections.',
        messageBn: 'শুধুমাত্র ওনার বা ফিন্যান্স অফিসার খরচ সংশোধন করতে পারেন।',
      );
    }

    if (reason.trim().length < 5) {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_MANDATORY_CORRECTION_REASON',
        messageEn: 'Meaningful correction reason of at least 5 characters is required.',
        messageBn: 'সংশোধনের কারণ কমপক্ষে ৫ অক্ষরের হওয়া আবশ্যক।',
      );
    }

    final existing = _cache[expenseId];
    if (existing == null) {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_EXPENSE_NOT_FOUND',
        messageEn: 'Expense voucher not found.',
        messageBn: 'খরচ ভাউচার খুঁজে পাওয়া যায়নি।',
      );
    }

    if (existing.status != 'APPROVED') {
      throw OperatingExpenseValidationException(
        errorCode: 'ERR_EXPENSE_NOT_APPROVED',
        messageEn: 'Only approved expenses can be corrected.',
        messageBn: 'শুধুমাত্র অনুমোদিত খরচ সংশোধন করা যায়।',
      );
    }

    OperatingExpenseEntryDto updated;
    if (correctionType.toUpperCase() == 'FULL_REVERSAL') {
      updated = existing.copyWith(
        status: 'REVERSED',
        notes: '${existing.notes} [REVERSED: $reason]'.trim(),
        reimbursementStatus: existing.isReimbursable && existing.reimbursementStatus != 'PAID_OUT' ? 'REJECTED' : existing.reimbursementStatus,
      );
    } else if (correctionType.toUpperCase() == 'AMOUNT_ADJUSTMENT' && correctedAmount != null && correctedAmount > 0) {
      updated = existing.copyWith(
        amountBdt: correctedAmount,
        notes: '${existing.notes} [ADJUSTED: ${existing.amountBdt} -> $correctedAmount ($reason)]'.trim(),
      );
    } else {
      updated = existing;
    }

    _cache[expenseId] = updated;
    return updated;
  }

  List<OperatingExpenseEntryDto> listExpenses({String? statusFilter}) {
    if (!isViewAuthorized) {
      throw OperatingExpensePermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier is not authorized to access operating expenses.',
        messageBn: 'ক্যাশিয়ার অপারেটিং খরচ অ্যাক্সেস করার অনুমতিপ্রাপ্ত নন।',
      );
    }
    final all = _cache.values.where((e) => e.tenantId == tenantId).toList();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      return all.where((e) => e.status == statusFilter.toUpperCase()).toList();
    }
    return all;
  }
}
