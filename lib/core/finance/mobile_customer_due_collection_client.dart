// mobile_customer_due_collection_client.dart
// Architecture Decision: ADR-0277 (P277).
// Phase 14: Customers, Suppliers, Dues & Payments.

class MobileDuePermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  MobileDuePermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class MobileDueValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  MobileDueValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class MobileDueOfflineException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  MobileDueOfflineException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class MobileDueNotFoundException implements Exception {
  final String errorCode;
  final String message;

  MobileDueNotFoundException({
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() => '$errorCode: $message';
}

class MobileOutstandingDueDto {
  final String dueId;
  final String tenantId;
  final String branchId;
  final String branchName;
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String? invoiceId;
  final String invoiceNumber;
  final double totalDueBdt;
  double paidAmountBdt;
  double remainingDueBdt;
  String status;
  final DateTime? dueDate;
  final bool isOverdue;
  final int overdueDays;
  final String notes;
  final DateTime createdAt;

  MobileOutstandingDueDto({
    required this.dueId,
    required this.tenantId,
    required this.branchId,
    this.branchName = 'Branch',
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.invoiceId,
    required this.invoiceNumber,
    required this.totalDueBdt,
    this.paidAmountBdt = 0.0,
    required this.remainingDueBdt,
    this.status = 'OUTSTANDING',
    this.dueDate,
    this.isOverdue = false,
    this.overdueDays = 0,
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'due_id': dueId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'branch_name': branchName,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'total_due_bdt': totalDueBdt.toStringAsFixed(2),
        'paid_amount_bdt': paidAmountBdt.toStringAsFixed(2),
        'remaining_due_bdt': remainingDueBdt.toStringAsFixed(2),
        'status': status,
        'due_date': dueDate?.toIso8601String(),
        'is_overdue': isOverdue,
        'overdue_days': overdueDays,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory MobileOutstandingDueDto.fromJson(Map<String, dynamic> json) {
    return MobileOutstandingDueDto(
      dueId: json['due_id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      branchName: (json['branch_name'] as String?) ?? 'Branch',
      customerId: json['customer_id'] as String?,
      customerName: (json['customer_name'] as String?) ?? '',
      customerPhone: (json['customer_phone'] as String?) ?? '',
      invoiceId: json['invoice_id'] as String?,
      invoiceNumber: (json['invoice_number'] as String?) ?? '',
      totalDueBdt: double.tryParse(json['total_due_bdt']?.toString() ?? '0') ?? 0.0,
      paidAmountBdt: double.tryParse(json['paid_amount_bdt']?.toString() ?? '0') ?? 0.0,
      remainingDueBdt: double.tryParse(json['remaining_due_bdt']?.toString() ?? '0') ?? 0.0,
      status: (json['status'] as String?) ?? 'OUTSTANDING',
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      isOverdue: json['is_overdue'] == true,
      overdueDays: int.tryParse(json['overdue_days']?.toString() ?? '0') ?? 0,
      notes: (json['notes'] as String?) ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class MobileDueCollectionSummaryDto {
  final String tenantId;
  final String? branchId;
  final String currency;
  final double totalOutstandingDueBdt;
  final double totalOverdueDueBdt;
  final int totalDueAccountsCount;
  final int overdueAccountsCount;
  final double todayCollectedDueBdt;
  final DateTime asOf;

  MobileDueCollectionSummaryDto({
    required this.tenantId,
    this.branchId,
    this.currency = 'BDT',
    required this.totalOutstandingDueBdt,
    required this.totalOverdueDueBdt,
    required this.totalDueAccountsCount,
    required this.overdueAccountsCount,
    required this.todayCollectedDueBdt,
    DateTime? asOf,
  }) : asOf = asOf ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'branch_id': branchId,
        'currency': currency,
        'total_outstanding_due_bdt': totalOutstandingDueBdt.toStringAsFixed(2),
        'total_overdue_due_bdt': totalOverdueDueBdt.toStringAsFixed(2),
        'total_due_accounts_count': totalDueAccountsCount,
        'overdue_accounts_count': overdueAccountsCount,
        'today_collected_due_bdt': todayCollectedDueBdt.toStringAsFixed(2),
        'as_of': asOf.toIso8601String(),
      };
}

class MobileDigitalReceiptDto {
  final bool success;
  final String collectionId;
  final String receiptNumber;
  final String tenantId;
  final String branchId;
  final String branchName;
  final String dueId;
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String invoiceNumber;
  final String tenderType;
  final double amountCollectedBdt;
  final double remainingDueBdt;
  final String dueStatus;
  final String gatewayReference;
  final String collectedByName;
  final DateTime collectedAt;
  final String notes;
  final String messageEn;
  final String messageBn;

  MobileDigitalReceiptDto({
    this.success = true,
    required this.collectionId,
    required this.receiptNumber,
    required this.tenantId,
    required this.branchId,
    this.branchName = 'Branch',
    required this.dueId,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.invoiceNumber,
    required this.tenderType,
    required this.amountCollectedBdt,
    required this.remainingDueBdt,
    required this.dueStatus,
    this.gatewayReference = '',
    required this.collectedByName,
    DateTime? collectedAt,
    this.notes = '',
    this.messageEn = '',
    this.messageBn = '',
  }) : collectedAt = collectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'success': success,
        'collection_id': collectionId,
        'receipt_number': receiptNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'branch_name': branchName,
        'due_id': dueId,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'invoice_number': invoiceNumber,
        'tender_type': tenderType,
        'amount_collected_bdt': amountCollectedBdt.toStringAsFixed(2),
        'remaining_due_bdt': remainingDueBdt.toStringAsFixed(2),
        'due_status': dueStatus,
        'gateway_reference': gatewayReference,
        'collected_by_name': collectedByName,
        'collected_at': collectedAt.toIso8601String(),
        'notes': notes,
        'message_en': messageEn,
        'message_bn': messageBn,
      };

  factory MobileDigitalReceiptDto.fromJson(Map<String, dynamic> json) {
    return MobileDigitalReceiptDto(
      success: json['success'] == true,
      collectionId: json['collection_id'] as String,
      receiptNumber: json['receipt_number'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      branchName: (json['branch_name'] as String?) ?? 'Branch',
      dueId: json['due_id'] as String,
      customerId: json['customer_id'] as String?,
      customerName: (json['customer_name'] as String?) ?? '',
      customerPhone: (json['customer_phone'] as String?) ?? '',
      invoiceNumber: (json['invoice_number'] as String?) ?? '',
      tenderType: (json['tender_type'] as String?) ?? 'CASH',
      amountCollectedBdt: double.tryParse(json['amount_collected_bdt']?.toString() ?? '0') ?? 0.0,
      remainingDueBdt: double.tryParse(json['remaining_due_bdt']?.toString() ?? '0') ?? 0.0,
      dueStatus: (json['due_status'] as String?) ?? 'SETTLED',
      gatewayReference: (json['gateway_reference'] as String?) ?? '',
      collectedByName: (json['collected_by_name'] as String?) ?? 'Authorized Owner',
      collectedAt: json['collected_at'] != null ? DateTime.tryParse(json['collected_at'].toString()) : null,
      notes: (json['notes'] as String?) ?? '',
      messageEn: (json['message_en'] as String?) ?? '',
      messageBn: (json['message_bn'] as String?) ?? '',
    );
  }
}

class MobileCustomerDueCollectionClient {
  final String tenantId;
  final String? branchId;
  final String userRole;
  final String userId;

  final Map<String, MobileOutstandingDueDto> _dueStore = {};
  final Map<String, MobileDigitalReceiptDto> _receiptStore = {};

  static const Set<String> authorizedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  MobileCustomerDueCollectionClient({
    required this.tenantId,
    this.branchId,
    required String userRole,
    required this.userId,
  }) : userRole = userRole.toUpperCase();

  bool get isAuthorized => authorizedRoles.contains(userRole);

  void _assertAuthorized() {
    if (!isAuthorized) {
      throw MobileDuePermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to access mobile owner due collections.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট মোবাইল ওনার ডিউ কালেকশন পরিচালনার অনুমতিপ্রাপ্ত নন।',
      );
    }
  }

  void seedDueRecord(MobileOutstandingDueDto due) {
    _dueStore[due.dueId] = due;
  }

  List<MobileOutstandingDueDto> listOutstandingDues({
    String? search,
    bool? isOverdue,
  }) {
    _assertAuthorized();

    final now = DateTime.now();
    return _dueStore.values.where((d) {
      if (d.tenantId != tenantId) return false;
      if (d.remainingDueBdt <= 0.001) return false;
      if (search != null && search.trim().isNotEmpty) {
        final s = search.trim().toLowerCase();
        final match = d.customerName.toLowerCase().contains(s) ||
            d.customerPhone.toLowerCase().contains(s) ||
            d.dueId.toLowerCase().contains(s) ||
            d.invoiceNumber.toLowerCase().contains(s);
        if (!match) return false;
      }
      if (isOverdue != null) {
        final od = d.dueDate != null && d.dueDate!.isBefore(now);
        if (od != isOverdue) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.dueDate != null && b.dueDate != null
          ? a.dueDate!.compareTo(b.dueDate!)
          : b.createdAt.compareTo(a.createdAt));
  }

  MobileDueCollectionSummaryDto getDueSummary() {
    _assertAuthorized();

    double totalOutstanding = 0.0;
    double totalOverdue = 0.0;
    int totalAccounts = 0;
    int overdueAccounts = 0;
    final now = DateTime.now();

    for (final d in _dueStore.values) {
      if (d.tenantId == tenantId && d.remainingDueBdt > 0.001) {
        totalOutstanding += d.remainingDueBdt;
        totalAccounts++;
        if (d.dueDate != null && d.dueDate!.isBefore(now)) {
          totalOverdue += d.remainingDueBdt;
          overdueAccounts++;
        }
      }
    }

    double todayCollected = 0.0;
    for (final r in _receiptStore.values) {
      if (r.tenantId == tenantId) {
        todayCollected += r.amountCollectedBdt;
      }
    }

    return MobileDueCollectionSummaryDto(
      tenantId: tenantId,
      branchId: branchId,
      totalOutstandingDueBdt: double.parse(totalOutstanding.toStringAsFixed(2)),
      totalOverdueDueBdt: double.parse(totalOverdue.toStringAsFixed(2)),
      totalDueAccountsCount: totalAccounts,
      overdueAccountsCount: overdueAccounts,
      todayCollectedDueBdt: double.parse(todayCollected.toStringAsFixed(2)),
    );
  }

  MobileDigitalReceiptDto recordDueCollection({
    required String dueId,
    required double amountBdt,
    String tenderType = 'CASH',
    String? gatewayReference,
    String? financialAccountId,
    bool isOffline = false,
    String idempotencyKey = '',
    String notes = '',
  }) {
    _assertAuthorized();

    if (isOffline) {
      throw MobileDueOfflineException(
        errorCode: 'ERR_OFFLINE_UNAVAILABLE',
        messageEn: 'Mobile due collection requires online connectivity to verify live AR ledger state.',
        messageBn: 'লাইভ লেজার সমন্বয়ের জন্য মোবাইল ডিউ কালেকশনে অনলাইন ইন্টারনেট সংযোগ আবশ্যক।',
      );
    }

    if (amountBdt <= 0) {
      throw MobileDueValidationException(
        errorCode: 'ERR_INVALID_PAYMENT_AMOUNT',
        messageEn: 'Collection amount must be strictly greater than 0.00 BDT.',
        messageBn: 'আদায়ের পরিমাণ অবশ্যই শূন্যের চেয়ে বেশি হতে হবে।',
      );
    }

    final due = _dueStore[dueId];
    if (due == null || due.tenantId != tenantId) {
      throw MobileDueNotFoundException(
        errorCode: 'ERR_DUE_RECORD_NOT_FOUND',
        message: 'Customer due record $dueId not found.',
      );
    }

    if (due.status == 'SETTLED' || due.remainingDueBdt <= 0.001) {
      throw MobileDueValidationException(
        errorCode: 'ERR_DUE_ALREADY_SETTLED',
        messageEn: 'Customer due is already settled.',
        messageBn: 'এই কাস্টমার বাকিটি ইতিমধ্যে সম্পূর্ণ পরিশোধিত।',
      );
    }

    if (amountBdt > due.remainingDueBdt + 0.001) {
      throw MobileDueValidationException(
        errorCode: 'ERR_DUE_OVERPAYMENT',
        messageEn: 'Collection amount exceeds remaining due. Overpayments are strictly prohibited.',
        messageBn: 'আদায়ের পরিমাণ অবশিষ্ট বাকির চেয়ে বেশি। ওভারপেমেন্ট গ্রহণযোগ্য নয়।',
      );
    }

    final cleanTender = tenderType.trim().toUpperCase();
    if (cleanTender == 'DUE') {
      throw MobileDueValidationException(
        errorCode: 'ERR_INVALID_TENDER_TYPE',
        messageEn: 'Cannot settle customer due using DUE tender.',
        messageBn: 'বাকি দিয়ে বাকি পরিশোধ করা যাবে না।',
      );
    }

    if (const {'BKASH', 'NAGAD', 'ROCKET', 'UPAY', 'CARD', 'BANK_TRANSFER'}.contains(cleanTender)) {
      if (gatewayReference == null || gatewayReference.trim().length < 4) {
        throw MobileDueValidationException(
          errorCode: 'ERR_MISSING_GATEWAY_REFERENCE',
          messageEn: 'Valid gateway transaction reference is required.',
          messageBn: 'ডিজিটাল লেনদেনের জন্য সঠিক রেফারেন্স নম্বর আবশ্যক।',
        );
      }
    }

    // Apply reduction
    final newRemaining = double.parse((due.remainingDueBdt - amountBdt).toStringAsFixed(2));
    due.paidAmountBdt = double.parse((due.paidAmountBdt + amountBdt).toStringAsFixed(2));
    due.remainingDueBdt = newRemaining <= 0.001 ? 0.0 : newRemaining;
    due.status = due.remainingDueBdt <= 0.0 ? 'SETTLED' : 'PARTIAL';

    final collectionId = 'MCOL-${DateTime.now().millisecondsSinceEpoch}';
    final receiptNumber = 'REC-DUE-${collectionId.substring(collectionId.length - 6)}';

    final receipt = MobileDigitalReceiptDto(
      collectionId: collectionId,
      receiptNumber: receiptNumber,
      tenantId: tenantId,
      branchId: due.branchId,
      branchName: due.branchName,
      dueId: due.dueId,
      customerId: due.customerId,
      customerName: due.customerName,
      customerPhone: due.customerPhone,
      invoiceNumber: due.invoiceNumber,
      tenderType: cleanTender,
      amountCollectedBdt: amountBdt,
      remainingDueBdt: due.remainingDueBdt,
      dueStatus: due.status,
      gatewayReference: gatewayReference ?? '',
      collectedByName: 'Pharmacy Owner',
      notes: notes,
      messageEn: 'Successfully collected ${amountBdt.toStringAsFixed(2)} BDT. Digital receipt #$receiptNumber generated.',
      messageBn: '${amountBdt.toStringAsFixed(2)} টাকা সফলভাবে আদায় হয়েছে। ডিজিটাল রসিদ #$receiptNumber তৈরি করা হয়েছে।',
    );

    _receiptStore[collectionId] = receipt;
    return receipt;
  }

  MobileDigitalReceiptDto getReceipt(String collectionId) {
    _assertAuthorized();

    final receipt = _receiptStore[collectionId];
    if (receipt == null || receipt.tenantId != tenantId) {
      throw MobileDueNotFoundException(
        errorCode: 'ERR_COLLECTION_NOT_FOUND',
        message: 'Collection $collectionId not found.',
      );
    }
    return receipt;
  }
}
