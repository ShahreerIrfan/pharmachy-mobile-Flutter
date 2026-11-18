// mobile_financial_period_client.dart
// Architecture Decision: ADR-0292 (P292).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class PeriodPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PeriodPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PeriodValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PeriodValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class FinancialPeriodDto {
  final String periodId;
  final String tenantId;
  final String? branchId;
  final String periodCode;
  final String periodName;
  final String periodType;
  final String startDate;
  final String endDate;
  final String status;
  final String? closedAt;
  final String? closingJournalId;
  final double totalRevenuesBdt;
  final double totalExpensesBdt;
  final double netIncomeBdt;
  final int reopenCount;
  final String? reopenReason;

  FinancialPeriodDto({
    required this.periodId,
    required this.tenantId,
    this.branchId,
    required this.periodCode,
    required this.periodName,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.closedAt,
    this.closingJournalId,
    required this.totalRevenuesBdt,
    required this.totalExpensesBdt,
    required this.netIncomeBdt,
    required this.reopenCount,
    this.reopenReason,
  });

  factory FinancialPeriodDto.fromJson(Map<String, dynamic> json) {
    return FinancialPeriodDto(
      periodId: json['period_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'],
      periodCode: json['period_code'] ?? '',
      periodName: json['period_name'] ?? '',
      periodType: json['period_type'] ?? 'MONTHLY',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      status: json['status'] ?? 'OPEN',
      closedAt: json['closed_at'],
      closingJournalId: json['closing_journal_id'],
      totalRevenuesBdt: double.tryParse(json['total_revenues_bdt']?.toString() ?? '0') ?? 0.0,
      totalExpensesBdt: double.tryParse(json['total_expenses_bdt']?.toString() ?? '0') ?? 0.0,
      netIncomeBdt: double.tryParse(json['net_income_bdt']?.toString() ?? '0') ?? 0.0,
      reopenCount: int.tryParse(json['reopen_count']?.toString() ?? '0') ?? 0,
      reopenReason: json['reopen_reason'],
    );
  }
}

class MobileFinancialPeriodClient {
  static const Set<String> viewRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'BRANCH_MANAGER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> closeRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> reopenRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;

  final List<FinancialPeriodDto> _mockPeriods = [];

  MobileFinancialPeriodClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
  });

  bool get isViewAuthorized => viewRoles.contains(userRole.toUpperCase());
  bool get isCloseAuthorized => closeRoles.contains(userRole.toUpperCase());
  bool get isReopenAuthorized => reopenRoles.contains(userRole.toUpperCase());

  FinancialPeriodDto createPeriod({
    required String periodCode,
    required String periodName,
    String periodType = 'MONTHLY',
    required String startDate,
    required String endDate,
  }) {
    if (!isCloseAuthorized) {
      throw PeriodPermissionException(
        errorCode: 'ERR_PERIOD_CLOSE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can create periods.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার পিরিয়ড তৈরি করতে পারেন।',
      );
    }

    if (periodCode.isEmpty || startDate.isEmpty || endDate.isEmpty) {
      throw PeriodValidationException(
        errorCode: 'ERR_MISSING_FIELDS',
        messageEn: 'Period code and dates are required.',
        messageBn: 'পিরিয়ড কোড ও তারিখ আবশ্যক।',
      );
    }

    final p = FinancialPeriodDto(
      periodId: 'fper-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: tenantId,
      branchId: branchId,
      periodCode: periodCode.toUpperCase(),
      periodName: periodName,
      periodType: periodType,
      startDate: startDate,
      endDate: endDate,
      status: 'OPEN',
      totalRevenuesBdt: 0.0,
      totalExpensesBdt: 0.0,
      netIncomeBdt: 0.0,
      reopenCount: 0,
    );

    _mockPeriods.add(p);
    return p;
  }

  Map<String, dynamic> validateIntegrity(String periodId, {bool simulatePendingDrafts = false}) {
    if (!isViewAuthorized) {
      throw PeriodPermissionException(
        errorCode: 'ERR_PERIOD_VIEW_UNAUTHORIZED',
        messageEn: 'Unauthorized to view period integrity.',
        messageBn: 'পিরিয়ড ইন্টিগ্রিটি দেখার অনুমতি নেই।',
      );
    }

    List<String> issues = [];
    if (simulatePendingDrafts) {
      issues.add('There are 3 pending unapproved draft operating expenses.');
    }

    return {
      'period_id': periodId,
      'is_ready_to_close': issues.isEmpty,
      'trial_balance_balanced': true,
      'blocking_issues': issues,
      'financial_summary': {
        'total_revenues_bdt': '500000.00',
        'total_expenses_bdt': '350000.00',
        'net_income_bdt': '150000.00',
      },
    };
  }

  FinancialPeriodDto closePeriod(String periodId, {String closingNotes = ''}) {
    if (!isCloseAuthorized) {
      throw PeriodPermissionException(
        errorCode: 'ERR_PERIOD_CLOSE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can close periods.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার পিরিয়ড বন্ধ করতে পারেন।',
      );
    }

    final index = _mockPeriods.indexWhere((p) => p.periodId == periodId);
    if (index == -1) {
      throw PeriodValidationException(
        errorCode: 'ERR_PERIOD_NOT_FOUND',
        messageEn: 'Financial period not found.',
        messageBn: 'আর্থিক পিরিয়ড পাওয়া যায়নি।',
      );
    }

    final target = _mockPeriods[index];
    if (target.status == 'CLOSED') {
      throw PeriodValidationException(
        errorCode: 'ERR_PERIOD_ALREADY_CLOSED',
        messageEn: 'Financial period is already closed.',
        messageBn: 'আর্থিক পিরিয়ড ইতোমধ্যে বন্ধ করা হয়েছে।',
      );
    }

    final closed = FinancialPeriodDto(
      periodId: target.periodId,
      tenantId: target.tenantId,
      branchId: target.branchId,
      periodCode: target.periodCode,
      periodName: target.periodName,
      periodType: target.periodType,
      startDate: target.startDate,
      endDate: target.endDate,
      status: 'CLOSED',
      closedAt: DateTime.now().toIso8601String(),
      closingJournalId: 'jrnl-close-${DateTime.now().millisecondsSinceEpoch}',
      totalRevenuesBdt: 500000.0,
      totalExpensesBdt: 350000.0,
      netIncomeBdt: 150000.0,
      reopenCount: target.reopenCount,
      reopenReason: target.reopenReason,
    );

    _mockPeriods[index] = closed;
    return closed;
  }

  FinancialPeriodDto reopenPeriod(String periodId, {required String reopenReason}) {
    if (!isReopenAuthorized) {
      throw PeriodPermissionException(
        errorCode: 'ERR_PERIOD_REOPEN_UNAUTHORIZED',
        messageEn: 'Controlled reopening strictly requires Pharmacy Owner authorization.',
        messageBn: 'বন্ধ পিরিয়ড খোলার জন্য ফার্মেসি ওনারের অনুমতি আবশ্যক।',
      );
    }

    if (reopenReason.trim().isEmpty) {
      throw PeriodValidationException(
        errorCode: 'ERR_MISSING_REOPEN_REASON',
        messageEn: 'A formal audit explanation is mandatory.',
        messageBn: 'অডিট কারণ উল্লেখ করা বাধ্যতামূলক।',
      );
    }

    final index = _mockPeriods.indexWhere((p) => p.periodId == periodId);
    if (index == -1) {
      throw PeriodValidationException(
        errorCode: 'ERR_PERIOD_NOT_FOUND',
        messageEn: 'Financial period not found.',
        messageBn: 'আর্থিক পিরিয়ড পাওয়া যায়নি।',
      );
    }

    final target = _mockPeriods[index];
    if (target.status != 'CLOSED') {
      throw PeriodValidationException(
        errorCode: 'ERR_PERIOD_NOT_CLOSED',
        messageEn: 'Only closed periods can be reopened.',
        messageBn: 'শুধুমাত্র বন্ধ পিরিয়ড খোলা সম্ভব।',
      );
    }

    final reopened = FinancialPeriodDto(
      periodId: target.periodId,
      tenantId: target.tenantId,
      branchId: target.branchId,
      periodCode: target.periodCode,
      periodName: target.periodName,
      periodType: target.periodType,
      startDate: target.startDate,
      endDate: target.endDate,
      status: 'REOPENED',
      closedAt: null,
      closingJournalId: null,
      totalRevenuesBdt: target.totalRevenuesBdt,
      totalExpensesBdt: target.totalExpensesBdt,
      netIncomeBdt: target.netIncomeBdt,
      reopenCount: target.reopenCount + 1,
      reopenReason: reopenReason.trim(),
    );

    _mockPeriods[index] = reopened;
    return reopened;
  }

  List<FinancialPeriodDto> getPeriods() => List.unmodifiable(_mockPeriods);
}
