// mobile_supplier_payment_schedule_client.dart
// Architecture Decision: ADR-0193 (P193).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing Supplier Payment Schedules & AP Ledger Consistency:
// - Schedules vendor dues, priority queues, and partial installment disbursements.
// - Posts immutable Accounts Payable debits reducing supplier ledger liability.
// - Enforces anti-overpayment guards and audited due date rescheduling.

class MobileSupplierLedgerEntry {
  final String postingId;
  final String supplierId;
  final String postingType;
  final String referenceNumber;
  final double debitAmount;
  final double creditAmount;
  final double balanceAfter;
  final DateTime postedAt;

  MobileSupplierLedgerEntry({
    required this.postingId,
    required this.supplierId,
    required this.postingType,
    required this.referenceNumber,
    required this.debitAmount,
    required this.creditAmount,
    required this.balanceAfter,
    required this.postedAt,
  });
}

class MobilePaymentInstallment {
  final String installmentId;
  final double amountPaid;
  final String paymentMethod;
  final String paymentReference;
  final DateTime transactionDate;
  final String? ledgerEntryId;
  final String notes;
  final String? disbursedBy;
  final DateTime createdAt;

  MobilePaymentInstallment({
    String? installmentId,
    required this.amountPaid,
    this.paymentMethod = 'BANK_TRANSFER',
    required this.paymentReference,
    DateTime? transactionDate,
    this.ledgerEntryId,
    this.notes = '',
    this.disbursedBy,
    DateTime? createdAt,
  })  : installmentId = installmentId ??
            'spi-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}',
        transactionDate = transactionDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'installment_id': installmentId,
        'amount_paid': amountPaid.toStringAsFixed(4),
        'payment_method': paymentMethod,
        'payment_reference': paymentReference,
        'transaction_date': transactionDate.toIso8601String(),
        'ledger_entry_id': ledgerEntryId,
        'notes': notes,
        'disbursed_by': disbursedBy,
        'created_at': createdAt.toIso8601String(),
      };
}

class MobilePaymentSchedule {
  final String scheduleId;
  final String scheduleNumber;
  final String tenantId;
  final String branchId;
  final String supplierId;
  final String supplierName;
  final String? supplierInvoiceId;
  DateTime dueDate;
  final double plannedAmount;
  double settledAmount;
  double remainingAmount;
  String status; // SCHEDULED, PARTIALLY_SETTLED, SETTLED, OVERDUE, CANCELLED
  String priority; // URGENT, HIGH, MEDIUM, LOW
  final String paymentMethodPreference;
  final String chequeReference;
  int rescheduleCount;
  String lastRescheduleReason;
  DateTime? lastRescheduledAt;
  String notes;
  final String createdBy;
  final List<MobilePaymentInstallment> installments;

  MobilePaymentSchedule({
    required this.scheduleId,
    required this.scheduleNumber,
    required this.tenantId,
    required this.branchId,
    required this.supplierId,
    required this.supplierName,
    this.supplierInvoiceId,
    required this.dueDate,
    required this.plannedAmount,
    this.settledAmount = 0.0,
    required this.remainingAmount,
    this.status = 'SCHEDULED',
    this.priority = 'MEDIUM',
    this.paymentMethodPreference = 'BANK_TRANSFER',
    this.chequeReference = '',
    this.rescheduleCount = 0,
    this.lastRescheduleReason = '',
    this.lastRescheduledAt,
    this.notes = '',
    required this.createdBy,
    required this.installments,
  });

  Map<String, dynamic> toJson() => {
        'schedule_id': scheduleId,
        'schedule_number': scheduleNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'supplier_invoice_id': supplierInvoiceId,
        'due_date': dueDate.toIso8601String(),
        'planned_amount': plannedAmount.toStringAsFixed(4),
        'settled_amount': settledAmount.toStringAsFixed(4),
        'remaining_amount': remainingAmount.toStringAsFixed(4),
        'status': status,
        'priority': priority,
        'payment_method_preference': paymentMethodPreference,
        'cheque_reference': chequeReference,
        'reschedule_count': rescheduleCount,
        'last_reschedule_reason': lastRescheduleReason,
        'last_rescheduled_at': lastRescheduledAt?.toIso8601String(),
        'notes': notes,
        'created_by': createdBy,
        'installments': installments.map((i) => i.toJson()).toList(),
      };
}

class MobileSupplierPaymentScheduleClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobilePaymentSchedule> scheduleStore;
  final Map<String, MobileSupplierLedgerEntry> ledgerStore;

  static const Set<String> _allowedRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
    'ACCOUNTANT',
    'AUDITOR',
  };

  MobileSupplierPaymentScheduleClient({
    required this.tenantId,
    required this.branchId,
    this.userRole = 'CASHIER',
    this.userId = 'usr_anon',
    this.isOffline = false,
    Map<String, MobilePaymentSchedule>? scheduleStore,
    Map<String, MobileSupplierLedgerEntry>? ledgerStore,
  })  : scheduleStore = scheduleStore ?? {},
        ledgerStore = ledgerStore ?? {};

  void _assertRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Staff role $userRole cannot manage supplier payment schedules.');
    }
  }

  MobilePaymentSchedule createSchedule({
    required String supplierId,
    required String supplierName,
    String? supplierInvoiceId,
    required DateTime dueDate,
    required double plannedAmount,
    String priority = 'MEDIUM',
    String paymentMethodPreference = 'BANK_TRANSFER',
    String chequeReference = '',
    String notes = '',
  }) {
    _assertRole();

    if (supplierId.trim().isEmpty) {
      throw ArgumentError('ERR_MISSING_SUPPLIER: Supplier ID is required.');
    }

    if (plannedAmount <= 0.0) {
      throw ArgumentError(
          'ERR_INVALID_PLANNED_AMOUNT: Planned amount must be positive.');
    }

    final schedId =
        'sps-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final schedNum = 'SPS-${DateTime.now().millisecondsSinceEpoch}';

    final sps = MobilePaymentSchedule(
      scheduleId: schedId,
      scheduleNumber: schedNum,
      tenantId: tenantId,
      branchId: branchId,
      supplierId: supplierId,
      supplierName: supplierName,
      supplierInvoiceId: supplierInvoiceId,
      dueDate: dueDate,
      plannedAmount: plannedAmount,
      settledAmount: 0.0,
      remainingAmount: plannedAmount,
      status: 'SCHEDULED',
      priority: priority,
      paymentMethodPreference: paymentMethodPreference,
      chequeReference: chequeReference,
      notes: notes,
      createdBy: userId,
      installments: [],
    );

    scheduleStore[schedId] = sps;
    return sps;
  }

  MobilePaymentSchedule recordInstallmentPayment({
    required String scheduleId,
    required double amountPaid,
    String paymentMethod = 'BANK_TRANSFER',
    required String paymentReference,
    String notes = '',
  }) {
    _assertRole();

    final sps = scheduleStore[scheduleId];
    if (sps == null) {
      throw ArgumentError(
          'ERR_SCHEDULE_NOT_FOUND: Schedule $scheduleId not found.');
    }

    if (sps.status == 'SETTLED' || sps.status == 'CANCELLED') {
      throw StateError(
          'ERR_SCHEDULE_NOT_PAYABLE: Cannot disburse payment against schedule in status ${sps.status}');
    }

    if (amountPaid <= 0.0) {
      throw ArgumentError(
          'ERR_INVALID_PAYMENT_AMOUNT: Payment amount must be positive.');
    }

    if (amountPaid > sps.remainingAmount) {
      throw ArgumentError(
          'ERR_EXCEEDS_SCHEDULED_DUE: Payment $amountPaid exceeds remaining due ${sps.remainingAmount}');
    }

    if (paymentReference.trim().isEmpty) {
      throw ArgumentError(
          'ERR_MISSING_PAYMENT_REF: Payment reference voucher is required.');
    }

    // Chronologically latest AP ledger balance
    double prevBalance = 0.0;
    final supplierEntries = ledgerStore.values
        .where((e) => e.supplierId == sps.supplierId)
        .toList()
      ..sort((a, b) => a.postedAt.compareTo(b.postedAt));

    if (supplierEntries.isNotEmpty) {
      prevBalance = supplierEntries.last.balanceAfter;
    }

    double newBalance = prevBalance - amountPaid;
    if (newBalance < 0.0) newBalance = 0.0;

    final postingId =
        'sup-pay-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final entry = MobileSupplierLedgerEntry(
      postingId: postingId,
      supplierId: sps.supplierId,
      postingType: 'PAYMENT',
      referenceNumber: paymentReference,
      debitAmount: amountPaid,
      creditAmount: 0.0,
      balanceAfter: newBalance,
      postedAt: DateTime.now(),
    );
    ledgerStore[postingId] = entry;

    final inst = MobilePaymentInstallment(
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      ledgerEntryId: postingId,
      notes: notes,
      disbursedBy: userId,
    );
    sps.installments.add(inst);

    sps.settledAmount += amountPaid;
    sps.remainingAmount -= amountPaid;
    if (sps.remainingAmount <= 0.0) {
      sps.remainingAmount = 0.0;
      sps.status = 'SETTLED';
    } else {
      sps.status = 'PARTIALLY_SETTLED';
    }

    return sps;
  }

  MobilePaymentSchedule reschedule({
    required String scheduleId,
    required DateTime newDueDate,
    required String reason,
  }) {
    _assertRole();

    if (reason.trim().isEmpty) {
      throw ArgumentError(
          'ERR_RESCHEDULE_REASON_REQUIRED: Reschedule reason is mandatory.');
    }

    final sps = scheduleStore[scheduleId];
    if (sps == null) {
      throw ArgumentError(
          'ERR_SCHEDULE_NOT_FOUND: Schedule $scheduleId not found.');
    }

    if (sps.status == 'SETTLED' || sps.status == 'CANCELLED') {
      throw StateError(
          'ERR_CANNOT_RESCHEDULE_CLOSED: Cannot reschedule in status ${sps.status}');
    }

    sps.dueDate = newDueDate;
    sps.rescheduleCount++;
    sps.lastRescheduleReason = reason;
    sps.lastRescheduledAt = DateTime.now();

    return sps;
  }

  MobilePaymentSchedule cancelSchedule(String scheduleId, String reason) {
    _assertRole();

    final sps = scheduleStore[scheduleId];
    if (sps == null) {
      throw ArgumentError(
          'ERR_SCHEDULE_NOT_FOUND: Schedule $scheduleId not found.');
    }

    if (sps.settledAmount > 0.0) {
      throw StateError(
          'ERR_CANNOT_CANCEL_DISBURSED_SCHEDULE: Cannot cancel schedule with settled funds.');
    }

    sps.status = 'CANCELLED';
    sps.notes = '${sps.notes} | Cancelled: $reason'.trim();
    return sps;
  }

  MobilePaymentSchedule getSchedule(String scheduleId) {
    final sps = scheduleStore[scheduleId];
    if (sps == null) {
      throw ArgumentError(
          'ERR_SCHEDULE_NOT_FOUND: Schedule $scheduleId not found.');
    }
    return sps;
  }

  List<MobilePaymentSchedule> listSchedules({
    String? supplierId,
    String? statusFilter,
    String? priority,
  }) {
    return scheduleStore.values.where((s) {
      if (supplierId != null &&
          supplierId.isNotEmpty &&
          s.supplierId != supplierId) {
        return false;
      }
      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          s.status.toUpperCase() != statusFilter.toUpperCase()) {
        return false;
      }
      if (priority != null &&
          priority.isNotEmpty &&
          s.priority.toUpperCase() != priority.toUpperCase()) {
        return false;
      }
      return true;
    }).toList();
  }
}
