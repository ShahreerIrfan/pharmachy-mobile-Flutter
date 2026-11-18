// mobile_double_entry_journal_client.dart
// Architecture Decision: ADR-0282 (P282).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class JournalPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  JournalPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class JournalValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  JournalValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class JournalLineDto {
  final String accountCode;
  final String accountName;
  final double debitAmountBdt;
  final double creditAmountBdt;
  final String description;

  JournalLineDto({
    required this.accountCode,
    required this.accountName,
    this.debitAmountBdt = 0.0,
    this.creditAmountBdt = 0.0,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'account_code': accountCode,
        'account_name': accountName,
        'debit_amount_bdt': debitAmountBdt,
        'credit_amount_bdt': creditAmountBdt,
        'description': description,
      };
}

class JournalEntryDto {
  final String entryId;
  final String journalNumber;
  final String postingDate;
  final String sourceModule;
  final String narration;
  final String status;
  final String totalDebitBdt;
  final String totalCreditBdt;
  final bool isBalanced;
  final List<JournalLineDto> lines;

  JournalEntryDto({
    required this.entryId,
    required this.journalNumber,
    required this.postingDate,
    required this.sourceModule,
    required this.narration,
    required this.status,
    required this.totalDebitBdt,
    required this.totalCreditBdt,
    required this.isBalanced,
    required this.lines,
  });
}

class MobileDoubleEntryJournalClient {
  static const Set<String> viewAuthorizedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> postAuthorizedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String userRole;
  final String userId;

  MobileDoubleEntryJournalClient({
    required this.tenantId,
    required this.userRole,
    required this.userId,
  });

  bool get isViewAuthorized => viewAuthorizedRoles.contains(userRole.toUpperCase());
  bool get isPostAuthorized => postAuthorizedRoles.contains(userRole.toUpperCase());

  void assertViewAuthorized() {
    if (!isViewAuthorized) {
      throw JournalPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist cannot access General Ledger journals.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট জেনারেল লেজার জার্নাল দেখার অনুমতিপ্রাপ্ত নন।',
      );
    }
  }

  void assertPostAuthorized() {
    if (!isPostAuthorized) {
      throw JournalPermissionException(
        errorCode: 'ERR_JOURNAL_POST_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can post or reverse General Ledger journals.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার জার্নাল পোস্ট বা রিভার্স করতে পারেন।',
      );
    }
  }

  Future<JournalEntryDto> postJournal({
    required List<JournalLineDto> lines,
    required String narration,
    String sourceModule = 'MANUAL',
    String sourceReference = '',
  }) async {
    assertPostAuthorized();

    if (lines.length < 2) {
      throw JournalValidationException(
        errorCode: 'ERR_MINIMUM_LINES_REQUIRED',
        messageEn: 'A double-entry journal entry requires at least two lines.',
        messageBn: 'ডাবল-এন্ট্রি জার্নালের জন্য ন্যূনতম দুটি লাইন আবশ্যক।',
      );
    }

    double totalDebits = 0.0;
    double totalCredits = 0.0;

    for (var l in lines) {
      totalDebits += l.debitAmountBdt;
      totalCredits += l.creditAmountBdt;
    }

    totalDebits = double.parse(totalDebits.toStringAsFixed(2));
    totalCredits = double.parse(totalCredits.toStringAsFixed(2));

    if (totalDebits != totalCredits || totalDebits <= 0.0) {
      throw JournalValidationException(
        errorCode: 'ERR_UNBALANCED_JOURNAL_ENTRY',
        messageEn: 'Total debits ($totalDebits) does not equal total credits ($totalCredits).',
        messageBn: 'মোট ডেবিট ও মোট ক্রেডিট সমান নয়।',
      );
    }

    return JournalEntryDto(
      entryId: 'jrn-${DateTime.now().millisecondsSinceEpoch}',
      journalNumber: 'JRN-${DateTime.now().millisecondsSinceEpoch}',
      postingDate: DateTime.now().toIso8601String().split('T')[0],
      sourceModule: sourceModule,
      narration: narration,
      status: 'POSTED',
      totalDebitBdt: totalDebits.toStringAsFixed(2),
      totalCreditBdt: totalCredits.toStringAsFixed(2),
      isBalanced: true,
      lines: lines,
    );
  }

  Future<Map<String, dynamic>> reverseJournal({
    required String journalId,
    required String reason,
  }) async {
    assertPostAuthorized();

    if (reason.trim().isEmpty) {
      throw JournalValidationException(
        errorCode: 'ERR_MISSING_REVERSAL_REASON',
        messageEn: 'A mandatory explanation reason is required for journal reversal.',
        messageBn: 'জার্নাল রিভার্সালের জন্য সুনির্দিষ্ট কারণ উল্লেখ করা আবশ্যক।',
      );
    }

    return {
      'success': true,
      'original_journal_id': journalId,
      'reversal_journal_id': 'rev-${DateTime.now().millisecondsSinceEpoch}',
      'status': 'REVERSED',
      'reason': reason,
      'message_en': 'Journal successfully reversed.',
    };
  }
}
