// mobile_vendor_payment_allocation_client.dart
// Architecture Decision: ADR-0273 (P273).
// Phase 14: Customers, Suppliers, Dues & Payments.
//
// Flutter mobile client governing Vendor Payment Disbursements & Invoice Allocations,
// anti-overpayment controls, unapplied advance balances, and role authorization.

class VendorPaymentPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  VendorPaymentPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class VendorPaymentValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  VendorPaymentValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class MobileInvoiceBalanceDto {
  final String invoiceId;
  final String invoiceNumber;
  final String supplierId;
  final double totalAmount;
  double allocatedAmount;

  MobileInvoiceBalanceDto({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.supplierId,
    required this.totalAmount,
    this.allocatedAmount = 0.0,
  });

  double get unpaidBalance {
    final rem = totalAmount - allocatedAmount;
    return rem < 0 ? 0.0 : rem;
  }

  String get settlementStatus {
    if (allocatedAmount <= 0.0) return 'UNPAID';
    if (unpaidBalance <= 0.0001) return 'SETTLED';
    return 'PARTIALLY_PAID';
  }

  Map<String, dynamic> toJson() => {
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'supplier_id': supplierId,
        'total_amount': totalAmount.toStringAsFixed(4),
        'allocated_amount': allocatedAmount.toStringAsFixed(4),
        'unpaid_balance': unpaidBalance.toStringAsFixed(4),
        'settlement_status': settlementStatus,
      };
}

class MobilePaymentAllocationItemDto {
  final String allocationId;
  final String invoiceId;
  final String invoiceNumber;
  final double allocatedAmount;
  final double previousUnpaidAmount;
  final double remainingUnpaidAmount;
  final String notes;

  MobilePaymentAllocationItemDto({
    required this.allocationId,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.allocatedAmount,
    required this.previousUnpaidAmount,
    required this.remainingUnpaidAmount,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'allocation_id': allocationId,
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'allocated_amount': allocatedAmount.toStringAsFixed(4),
        'previous_unpaid_amount': previousUnpaidAmount.toStringAsFixed(4),
        'remaining_unpaid_amount': remainingUnpaidAmount.toStringAsFixed(4),
        'notes': notes,
      };
}

class MobileVendorPaymentDto {
  final String paymentId;
  final String paymentNumber;
  final String tenantId;
  final String? branchId;
  final String supplierId;
  final double totalAmount;
  final double allocatedAmount;
  final double unallocatedAmount;
  final String status;
  final String paymentMethod;
  final String referenceNumber;
  final String notes;
  final String idempotencyKey;
  final List<MobilePaymentAllocationItemDto> allocations;
  final DateTime createdAt;

  MobileVendorPaymentDto({
    required this.paymentId,
    required this.paymentNumber,
    required this.tenantId,
    this.branchId,
    required this.supplierId,
    required this.totalAmount,
    required this.allocatedAmount,
    required this.unallocatedAmount,
    required this.status,
    this.paymentMethod = 'BANK_TRANSFER',
    this.referenceNumber = '',
    this.notes = '',
    this.idempotencyKey = '',
    this.allocations = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'payment_id': paymentId,
        'payment_number': paymentNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'supplier_id': supplierId,
        'total_amount': totalAmount.toStringAsFixed(4),
        'allocated_amount': allocatedAmount.toStringAsFixed(4),
        'unallocated_amount': unallocatedAmount.toStringAsFixed(4),
        'status': status,
        'payment_method': paymentMethod,
        'reference_number': referenceNumber,
        'notes': notes,
        'idempotency_key': idempotencyKey,
        'allocations': allocations.map((a) => a.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}

class MobileVendorPaymentAllocationClient {
  final String tenantId;
  final String? branchId;
  final String userRole;
  final String userId;

  final Map<String, MobileInvoiceBalanceDto> _invoices = {};
  final Map<String, MobileVendorPaymentDto> _payments = {};
  final Set<String> _seenIdempotencyKeys = {};

  static const Set<String> viewRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
    'INVENTORY_CLERK',
    'FINANCE_OFFICER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
    'PROCUREMENT_OFFICER',
  };

  static const Set<String> manageRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'INVENTORY_CLERK',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
    'PROCUREMENT_OFFICER',
  };

  MobileVendorPaymentAllocationClient({
    required this.tenantId,
    this.branchId,
    required this.userRole,
    required this.userId,
  });

  bool canView() => viewRoles.contains(userRole.toUpperCase());
  bool canManage() => manageRoles.contains(userRole.toUpperCase());

  void registerInvoice(MobileInvoiceBalanceDto invoice) {
    _invoices[invoice.invoiceId] = invoice;
  }

  List<MobileInvoiceBalanceDto> getUnpaidInvoices(String supplierId) {
    if (!canView()) {
      throw VendorPaymentPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Role $userRole is not authorized to view supplier invoices.',
        messageBn: 'কর্মী পদমর্যাদা $userRole সরবরাহকারী ইনভয়েস দেখার অনুমতিপ্রাপ্ত নয়।',
      );
    }
    return _invoices.values
        .where((inv) => inv.supplierId == supplierId && inv.unpaidBalance > 0.0001)
        .toList();
  }

  MobileVendorPaymentDto disburseAndAllocate({
    required String supplierId,
    required double totalAmount,
    String paymentMethod = 'BANK_TRANSFER',
    String referenceNumber = '',
    String notes = '',
    String idempotencyKey = '',
    List<Map<String, dynamic>> allocations = const [],
  }) {
    if (!canManage()) {
      throw VendorPaymentPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not permitted to disburse or allocate vendor payments.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট সরবরাহকারী পেমেন্ট বরাদ্দ করার অনুমতিপ্রাপ্ত নন।',
      );
    }

    if (idempotencyKey.isNotEmpty && _seenIdempotencyKeys.contains(idempotencyKey)) {
      final existing = _payments.values.firstWhere(
        (p) => p.idempotencyKey == idempotencyKey,
        orElse: () => throw StateError('Inconsistent idempotency state'),
      );
      return existing;
    }

    if (totalAmount <= 0.0) {
      throw VendorPaymentValidationException(
        errorCode: 'ERR_INVALID_PAYMENT_AMOUNT',
        messageEn: 'Total disbursement amount must be greater than zero.',
        messageBn: 'মোট পেমেন্ট অংক অবশ্যই শূন্যের চেয়ে বেশি হতে হবে।',
      );
    }

    double totalAllocated = 0.0;
    final List<MobilePaymentAllocationItemDto> allocationRecords = [];

    for (final item in allocations) {
      final invoiceId = item['invoice_id'] as String?;
      final allocatedAmt = (item['allocated_amount'] as num?)?.toDouble() ?? 0.0;
      final itemNotes = (item['notes'] as String?) ?? '';

      if (invoiceId == null || !_invoices.containsKey(invoiceId)) {
        throw VendorPaymentValidationException(
          errorCode: 'ERR_INVOICE_NOT_FOUND',
          messageEn: 'Invoice $invoiceId not found.',
          messageBn: 'ইনভয়েস $invoiceId পাওয়া যায়নি।',
        );
      }

      final invoice = _invoices[invoiceId]!;
      if (invoice.supplierId != supplierId) {
        throw VendorPaymentValidationException(
          errorCode: 'ERR_INVOICE_SUPPLIER_MISMATCH',
          messageEn: 'Invoice does not belong to supplier $supplierId.',
          messageBn: 'ইনভয়েসটি সংশ্লিষ্ট সরবরাহকারীর নয়।',
        );
      }

      if (allocatedAmt <= 0.0) {
        throw VendorPaymentValidationException(
          errorCode: 'ERR_INVALID_ALLOCATION_AMOUNT',
          messageEn: 'Allocation amount must be greater than zero.',
          messageBn: 'বরাদ্দকৃত টাকার অংক অবশ্যই শূন্যের চেয়ে বেশি হতে হবে।',
        );
      }

      final currentUnpaid = invoice.unpaidBalance;
      if (allocatedAmt > currentUnpaid) {
        throw VendorPaymentValidationException(
          errorCode: 'ERR_ALLOCATION_EXCEEDS_INVOICE_BALANCE',
          messageEn: 'Allocation amount $allocatedAmt exceeds invoice unpaid balance $currentUnpaid.',
          messageBn: 'বরাদ্দকৃত অংক ইনভয়েসের বাকি বকেয়া থেকে বেশি হতে পারে না।',
        );
      }

      final remainingUnpaid = currentUnpaid - allocatedAmt;
      invoice.allocatedAmount += allocatedAmt;

      allocationRecords.add(
        MobilePaymentAllocationItemDto(
          allocationId: 'vpalloc-${DateTime.now().microsecondsSinceEpoch}',
          invoiceId: invoiceId,
          invoiceNumber: invoice.invoiceNumber,
          allocatedAmount: allocatedAmt,
          previousUnpaidAmount: currentUnpaid,
          remainingUnpaidAmount: remainingUnpaid,
          notes: itemNotes,
        ),
      );

      totalAllocated += allocatedAmt;
    }

    if (totalAllocated > totalAmount) {
      throw VendorPaymentValidationException(
        errorCode: 'ERR_TOTAL_ALLOCATION_EXCEEDS_PAYMENT',
        messageEn: 'Sum of invoice allocations ($totalAllocated) cannot exceed total payment amount ($totalAmount).',
        messageBn: 'ইনভয়েস বরাদ্দের যোগফল মোট পেমেন্ট অংক অতিক্রম করতে পারে না।',
      );
    }

    final unappliedAdvance = totalAmount - totalAllocated;
    String status = 'POSTED';
    if (totalAllocated > 0.0) {
      status = (totalAllocated >= totalAmount) ? 'FULLY_ALLOCATED' : 'PARTIALLY_ALLOCATED';
    }

    final payment = MobileVendorPaymentDto(
      paymentId: 'vpay-${DateTime.now().microsecondsSinceEpoch}',
      paymentNumber: 'VPAY-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: tenantId,
      branchId: branchId,
      supplierId: supplierId,
      totalAmount: totalAmount,
      allocatedAmount: totalAllocated,
      unallocatedAmount: unappliedAdvance,
      status: status,
      paymentMethod: paymentMethod,
      referenceNumber: referenceNumber,
      notes: notes,
      idempotencyKey: idempotencyKey,
      allocations: allocationRecords,
    );

    _payments[payment.paymentId] = payment;
    if (idempotencyKey.isNotEmpty) {
      _seenIdempotencyKeys.add(idempotencyKey);
    }

    return payment;
  }
}
