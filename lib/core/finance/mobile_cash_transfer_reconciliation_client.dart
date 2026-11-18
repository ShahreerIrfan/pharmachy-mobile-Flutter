// mobile_cash_transfer_reconciliation_client.dart
// Architecture Decision: ADR-0290 (P290).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class TreasuryPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  TreasuryPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class TreasuryValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  TreasuryValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class CashBankTransferDto {
  final String transferId;
  final String transferNumber;
  final String tenantId;
  final String branchId;
  final String transferType;
  final String sourceAccountId;
  final String sourceAccountName;
  final String destinationAccountId;
  final String destinationAccountName;
  final double amountBdt;
  final String transferDate;
  final String referenceNumber;
  final String status;
  final String? postedJournalNumber;
  final String createdAt;

  CashBankTransferDto({
    required this.transferId,
    required this.transferNumber,
    required this.tenantId,
    required this.branchId,
    required this.transferType,
    required this.sourceAccountId,
    required this.sourceAccountName,
    required this.destinationAccountId,
    required this.destinationAccountName,
    required this.amountBdt,
    required this.transferDate,
    required this.referenceNumber,
    required this.status,
    this.postedJournalNumber,
    required this.createdAt,
  });

  factory CashBankTransferDto.fromJson(Map<String, dynamic> json) {
    return CashBankTransferDto(
      transferId: json['transfer_id'] ?? '',
      transferNumber: json['transfer_number'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'] ?? '',
      transferType: json['transfer_type'] ?? 'CASH_TO_BANK',
      sourceAccountId: json['source_account_id'] ?? '',
      sourceAccountName: json['source_account_name'] ?? '',
      destinationAccountId: json['destination_account_id'] ?? '',
      destinationAccountName: json['destination_account_name'] ?? '',
      amountBdt: double.tryParse(json['amount_bdt']?.toString() ?? '0') ?? 0.0,
      transferDate: json['transfer_date'] ?? '',
      referenceNumber: json['reference_number'] ?? '',
      status: json['status'] ?? 'COMPLETED',
      postedJournalNumber: json['posted_journal_number'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class BankReconciliationBatchDto {
  final String reconciliationId;
  final String batchNumber;
  final String tenantId;
  final String branchId;
  final String bankAccountId;
  final String bankAccountName;
  final String statementDate;
  final double statementEndingBalance;
  final double bookBalance;
  final double differenceBdt;
  final String status;
  final String? reconciledBy;
  final String? reconciledAt;

  BankReconciliationBatchDto({
    required this.reconciliationId,
    required this.batchNumber,
    required this.tenantId,
    required this.branchId,
    required this.bankAccountId,
    required this.bankAccountName,
    required this.statementDate,
    required this.statementEndingBalance,
    required this.bookBalance,
    required this.differenceBdt,
    required this.status,
    this.reconciledBy,
    this.reconciledAt,
  });

  factory BankReconciliationBatchDto.fromJson(Map<String, dynamic> json) {
    return BankReconciliationBatchDto(
      reconciliationId: json['reconciliation_id'] ?? '',
      batchNumber: json['batch_number'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'] ?? '',
      bankAccountId: json['bank_account_id'] ?? '',
      bankAccountName: json['bank_account_name'] ?? '',
      statementDate: json['statement_date'] ?? '',
      statementEndingBalance: double.tryParse(json['statement_ending_balance']?.toString() ?? '0') ?? 0.0,
      bookBalance: double.tryParse(json['book_balance']?.toString() ?? '0') ?? 0.0,
      differenceBdt: double.tryParse(json['difference_bdt']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'IN_PROGRESS',
      reconciledBy: json['reconciled_by'],
      reconciledAt: json['reconciled_at'],
    );
  }
}

class MobileCashTransferReconciliationClient {
  static const Set<String> viewRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> transferRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> reconcileRoles = {
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

  static final Map<String, double> _balances = {};
  static final List<CashBankTransferDto> _transfers = [];
  static final List<BankReconciliationBatchDto> _reconciliations = [];

  MobileCashTransferReconciliationClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
  });

  bool get isViewAuthorized => viewRoles.contains(userRole.toUpperCase());
  bool get isTransferAuthorized => transferRoles.contains(userRole.toUpperCase());
  bool get isReconcileAuthorized => reconcileRoles.contains(userRole.toUpperCase());

  void setAccountBalance(String accountId, double balance) {
    _balances[accountId] = balance;
  }

  double getAccountBalance(String accountId) {
    return _balances[accountId] ?? 0.0;
  }

  CashBankTransferDto executeTransfer({
    required String sourceAccountId,
    required String sourceAccountName,
    required String destinationAccountId,
    required String destinationAccountName,
    required double amountBdt,
    String referenceNumber = '',
    String transferType = 'CASH_TO_BANK',
  }) {
    if (!isTransferAuthorized) {
      throw TreasuryPermissionException(
        errorCode: 'ERR_TREASURY_MANAGE_UNAUTHORIZED',
        messageEn: 'Unauthorized to execute treasury fund transfer.',
        messageBn: 'ট্রেজারি ফান্ড ট্রান্সফার করার অনুমতি নেই।',
      );
    }

    if (sourceAccountId.trim().toLowerCase() == destinationAccountId.trim().toLowerCase()) {
      throw TreasuryValidationException(
        errorCode: 'ERR_SAME_ACCOUNT_TRANSFER',
        messageEn: 'Source and destination accounts must be different.',
        messageBn: 'উৎস এবং গন্তব্য অ্যাকাউন্ট ভিন্ন হতে হবে।',
      );
    }

    if (amountBdt <= 0) {
      throw TreasuryValidationException(
        errorCode: 'ERR_INVALID_TRANSFER_AMOUNT',
        messageEn: 'Transfer amount must be positive.',
        messageBn: 'ট্রান্সফারের পরিমাণ অবশ্যই ধনাত্মক হতে হবে।',
      );
    }

    final srcBal = _balances[sourceAccountId] ?? 0.0;
    final dstBal = _balances[destinationAccountId] ?? 0.0;
    _balances[sourceAccountId] = srcBal - amountBdt;
    _balances[destinationAccountId] = dstBal + amountBdt;

    final tx = CashBankTransferDto(
      transferId: 'cbtrx-${DateTime.now().millisecondsSinceEpoch}',
      transferNumber: 'TRF-MBL-${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}',
      tenantId: tenantId,
      branchId: branchId,
      transferType: transferType,
      sourceAccountId: sourceAccountId,
      sourceAccountName: sourceAccountName,
      destinationAccountId: destinationAccountId,
      destinationAccountName: destinationAccountName,
      amountBdt: amountBdt,
      transferDate: DateTime.now().toIso8601String().substring(0, 10),
      referenceNumber: referenceNumber.trim(),
      status: 'COMPLETED',
      postedJournalNumber: 'JRN-TRF-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now().toIso8601String(),
    );

    _transfers.add(tx);
    return tx;
  }

  BankReconciliationBatchDto runReconciliation({
    required String bankAccountId,
    required String bankAccountName,
    required double statementEndingBalance,
  }) {
    if (!isReconcileAuthorized) {
      throw TreasuryPermissionException(
        errorCode: 'ERR_RECONCILIATION_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can perform bank reconciliation.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার ব্যাংক রিকনসিলিয়েশন করতে পারেন।',
      );
    }

    final bookBal = _balances[bankAccountId] ?? 0.0;
    final diff = statementEndingBalance - bookBal;
    final status = (diff.abs() < 0.001) ? 'RECONCILED' : 'DISCREPANCY';

    final rec = BankReconciliationBatchDto(
      reconciliationId: 'brec-${DateTime.now().millisecondsSinceEpoch}',
      batchNumber: 'BREC-MBL-${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}',
      tenantId: tenantId,
      branchId: branchId,
      bankAccountId: bankAccountId,
      bankAccountName: bankAccountName,
      statementDate: DateTime.now().toIso8601String().substring(0, 10),
      statementEndingBalance: statementEndingBalance,
      bookBalance: bookBal,
      differenceBdt: diff,
      status: status,
      reconciledBy: status == 'RECONCILED' ? userId : null,
      reconciledAt: status == 'RECONCILED' ? DateTime.now().toIso8601String() : null,
    );

    _reconciliations.add(rec);
    return rec;
  }
}
