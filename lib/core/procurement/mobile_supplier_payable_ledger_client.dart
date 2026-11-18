// mobile_supplier_payable_ledger_client.dart
// Architecture Decision: ADR-0272 (P272).
// Phase 14: Customers, Suppliers, Dues & Payments.
//
// Flutter mobile client governing Accounts Payable (AP) supplier ledger postings,
// double-entry running balance tracking, compensating reversals, and reconciliations.

class LedgerPermissionException implements Exception {
  final String errorCode;
  final String message;

  LedgerPermissionException(this.errorCode, this.message);

  @override
  String toString() => '$errorCode: $message';
}

class LedgerValidationException implements Exception {
  final String errorCode;
  final String message;

  LedgerValidationException(this.errorCode, this.message);

  @override
  String toString() => '$errorCode: $message';
}

class MobileSupplierLedgerEntryDto {
  final String postingId;
  final String tenantId;
  final String supplierId;
  final String supplierName;
  final String? branchId;
  final String postingType;
  final String referenceNumber;
  final double debitAmount;
  final double creditAmount;
  final double balanceAfter;
  final String currency;
  final String notes;
  final String? postedById;
  final DateTime postedAt;

  MobileSupplierLedgerEntryDto({
    required this.postingId,
    required this.tenantId,
    required this.supplierId,
    required this.supplierName,
    this.branchId,
    required this.postingType,
    required this.referenceNumber,
    required this.debitAmount,
    required this.creditAmount,
    required this.balanceAfter,
    this.currency = 'BDT',
    this.notes = '',
    this.postedById,
    DateTime? postedAt,
  }) : postedAt = postedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'posting_id': postingId,
        'tenant_id': tenantId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'branch_id': branchId,
        'posting_type': postingType,
        'reference_number': referenceNumber,
        'debit_amount': debitAmount.toStringAsFixed(4),
        'credit_amount': creditAmount.toStringAsFixed(4),
        'balance_after': balanceAfter.toStringAsFixed(4),
        'currency': currency,
        'notes': notes,
        'posted_by_id': postedById,
        'posted_at': postedAt.toIso8601String(),
      };
}

class MobileReconciliationSummary {
  final String supplierId;
  final String supplierName;
  final String tenantId;
  final double openingBalance;
  final double totalCredits;
  final double totalDebits;
  final double calculatedClosing;
  final double currentBalance;
  final bool isReconciled;
  final int totalPostings;

  MobileReconciliationSummary({
    required this.supplierId,
    required this.supplierName,
    required this.tenantId,
    required this.openingBalance,
    required this.totalCredits,
    required this.totalDebits,
    required this.calculatedClosing,
    required this.currentBalance,
    required this.isReconciled,
    required this.totalPostings,
  });

  Map<String, dynamic> toJson() => {
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'tenant_id': tenantId,
        'opening_balance': openingBalance.toStringAsFixed(4),
        'total_credits': totalCredits.toStringAsFixed(4),
        'total_debits': totalDebits.toStringAsFixed(4),
        'calculated_closing_balance': calculatedClosing.toStringAsFixed(4),
        'supplier_current_balance': currentBalance.toStringAsFixed(4),
        'is_reconciled': isReconciled,
        'total_postings': totalPostings,
      };
}

class MobileSupplierPayableLedgerClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final Map<String, dynamic> supplierStore;
  final List<MobileSupplierLedgerEntryDto> ledgerStore;

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

  static const Set<String> postRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'INVENTORY_CLERK',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
    'PROCUREMENT_OFFICER',
  };

  static const Set<String> adminRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static int _idCounter = 1;

  MobileSupplierPayableLedgerClient({
    required this.tenantId,
    this.branchId = '',
    required String userRole,
    this.userId = 'user_anon',
    Map<String, dynamic>? supplierStore,
    List<MobileSupplierLedgerEntryDto>? ledgerStore,
  })  : userRole = userRole.toUpperCase(),
        supplierStore = supplierStore ?? {},
        ledgerStore = ledgerStore ?? [];

  bool get canView => viewRoles.contains(userRole);
  bool get canPost => postRoles.contains(userRole);
  bool get canAdmin => adminRoles.contains(userRole);

  MobileSupplierLedgerEntryDto postEntry({
    required String supplierId,
    required String postingType,
    required String referenceNumber,
    double debitAmount = 0.0,
    double creditAmount = 0.0,
    String notes = '',
    String? idempotencyKey,
  }) {
    if (!canPost) {
      throw LedgerPermissionException(
        'ERR_STAFF_ROLE_DENIED',
        'Role $userRole is not permitted to post AP ledger entries.',
      );
    }
    if (postingType.trim().isEmpty) {
      throw LedgerValidationException('ERR_INVALID_POSTING_TYPE', 'posting_type is required.');
    }
    if (postingType.toUpperCase() == 'ADJUSTMENT' && !canAdmin) {
      throw LedgerPermissionException('ERR_STAFF_ROLE_DENIED', 'Only owners/managers can post manual audit adjustments.');
    }
    if (referenceNumber.trim().isEmpty) {
      throw LedgerValidationException('ERR_MISSING_REFERENCE_NUMBER', 'reference_number is required.');
    }
    if (debitAmount < 0.0 || creditAmount < 0.0) {
      throw LedgerValidationException('ERR_INVALID_AMOUNT', 'Debit and credit amounts cannot be negative.');
    }
    if (debitAmount == 0.0 && creditAmount == 0.0) {
      throw LedgerValidationException('ERR_ZERO_AMOUNT', 'Either debit or credit must be positive.');
    }

    final supplier = supplierStore[supplierId];
    if (supplier == null) {
      throw LedgerValidationException('ERR_SUPPLIER_NOT_FOUND', 'Supplier $supplierId not found.');
    }
    if (supplier['tenant_id'] != tenantId) {
      throw LedgerPermissionException('ERR_CROSS_TENANT_ACCESS', 'Cross-tenant posting forbidden.');
    }

    // Idempotency check
    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      for (final existing in ledgerStore) {
        if (existing.notes.contains('[IDEMPOTENCY:$idempotencyKey]')) {
          return existing;
        }
      }
    }

    // Credit increases liability; Debit decreases liability
    final double prevBalance = (supplier['current_balance'] as num).toDouble();
    final double newBalance = prevBalance + creditAmount - debitAmount;
    supplier['current_balance'] = newBalance;

    final postingId = 'sup-post-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
    String finalNotes = notes.trim();
    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      finalNotes = '$finalNotes [IDEMPOTENCY:$idempotencyKey]'.trim();
    }

    final entry = MobileSupplierLedgerEntryDto(
      postingId: postingId,
      tenantId: tenantId,
      supplierId: supplierId,
      supplierName: supplier['name'] ?? '',
      branchId: branchId,
      postingType: postingType.toUpperCase(),
      referenceNumber: referenceNumber.trim(),
      debitAmount: debitAmount,
      creditAmount: creditAmount,
      balanceAfter: newBalance,
      currency: 'BDT',
      notes: finalNotes,
      postedById: userId,
    );
    ledgerStore.add(entry);
    return entry;
  }

  MobileSupplierLedgerEntryDto reverseEntry({
    required String supplierId,
    required String postingId,
    required String reason,
  }) {
    if (!canAdmin) {
      throw LedgerPermissionException('ERR_STAFF_ROLE_DENIED', 'Only owners/managers can reverse ledger entries.');
    }
    if (reason.trim().isEmpty) {
      throw LedgerValidationException('ERR_MISSING_REVERSAL_REASON', 'Reason is required for reversal.');
    }

    MobileSupplierLedgerEntryDto? original;
    for (final e in ledgerStore) {
      if (e.postingId == postingId) {
        original = e;
        break;
      }
    }
    if (original == null) {
      throw LedgerValidationException('ERR_LEDGER_ENTRY_NOT_FOUND', 'Posting $postingId not found.');
    }

    final reversalMarker = '[REVERSAL_OF:$postingId]';
    for (final e in ledgerStore) {
      if (e.notes.contains(reversalMarker)) {
        throw LedgerValidationException('ERR_ALREADY_REVERSED', 'Posting already reversed.');
      }
    }

    final supplier = supplierStore[supplierId];
    if (supplier == null) {
      throw LedgerValidationException('ERR_SUPPLIER_NOT_FOUND', 'Supplier not found.');
    }

    final revDebit = original.creditAmount;
    final revCredit = original.debitAmount;
    final prevBalance = (supplier['current_balance'] as num).toDouble();
    final newBalance = prevBalance + revCredit - revDebit;
    supplier['current_balance'] = newBalance;

    final revPostingId = 'sup-rev-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
    String revType = 'ADJUSTMENT';
    if (original.postingType == 'PAYMENT') {
      revType = 'PAYMENT_REVERSAL';
    } else if (original.postingType == 'SUPPLIER_CREDIT_NOTE') {
      revType = 'CREDIT_NOTE_REVERSAL';
    }

    final reversal = MobileSupplierLedgerEntryDto(
      postingId: revPostingId,
      tenantId: tenantId,
      supplierId: supplierId,
      supplierName: supplier['name'] ?? '',
      branchId: branchId,
      postingType: revType,
      referenceNumber: 'REV-${original.referenceNumber}',
      debitAmount: revDebit,
      creditAmount: revCredit,
      balanceAfter: newBalance,
      currency: 'BDT',
      notes: 'Reversal of $postingId: ${reason.trim()} $reversalMarker',
      postedById: userId,
    );
    ledgerStore.add(reversal);
    return reversal;
  }

  List<MobileSupplierLedgerEntryDto> listEntries(String supplierId) {
    if (!canView) {
      throw LedgerPermissionException('ERR_STAFF_ROLE_DENIED', 'Role $userRole cannot view ledger.');
    }
    return ledgerStore.where((e) => e.tenantId == tenantId && e.supplierId == supplierId).toList();
  }

  MobileReconciliationSummary reconcile(String supplierId) {
    if (!canView) {
      throw LedgerPermissionException('ERR_STAFF_ROLE_DENIED', 'Role $userRole cannot reconcile ledger.');
    }
    final supplier = supplierStore[supplierId];
    if (supplier == null) {
      throw LedgerValidationException('ERR_SUPPLIER_NOT_FOUND', 'Supplier not found.');
    }

    final entries = listEntries(supplierId);
    double totalDebits = 0.0;
    double totalCredits = 0.0;
    for (final e in entries) {
      totalDebits += e.debitAmount;
      totalCredits += e.creditAmount;
    }

    final double currentBal = (supplier['current_balance'] as num).toDouble();
    final double opening = entries.isEmpty ? currentBal : entries.first.balanceAfter - entries.first.creditAmount + entries.first.debitAmount;
    final double closing = entries.isEmpty ? currentBal : entries.last.balanceAfter;
    final double calculated = opening + totalCredits - totalDebits;
    final bool isReconciled = (calculated - closing).abs() < 0.0001 && (closing - currentBal).abs() < 0.0001;

    return MobileReconciliationSummary(
      supplierId: supplierId,
      supplierName: supplier['name'] ?? '',
      tenantId: tenantId,
      openingBalance: opening,
      totalCredits: totalCredits,
      totalDebits: totalDebits,
      calculatedClosing: calculated,
      currentBalance: currentBal,
      isReconciled: isReconciled,
      totalPostings: entries.length,
    );
  }
}
