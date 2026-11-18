// mobile_payroll_expense_client.dart
// Architecture Decision: ADR-0291 (P291).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class PayrollPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PayrollPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PayrollValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PayrollValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PayrollSlipDto {
  final String slipId;
  final String staffMemberId;
  final String staffName;
  final String staffRole;
  final double baseSalaryBdt;
  final double allowancesBdt;
  final double bonusBdt;
  final double deductionsBdt;
  final double netSalaryBdt;
  final String bankName;
  final String bankAccountNo;
  final String paymentStatus;

  PayrollSlipDto({
    required this.slipId,
    required this.staffMemberId,
    required this.staffName,
    required this.staffRole,
    required this.baseSalaryBdt,
    required this.allowancesBdt,
    required this.bonusBdt,
    required this.deductionsBdt,
    required this.netSalaryBdt,
    required this.bankName,
    required this.bankAccountNo,
    required this.paymentStatus,
  });

  factory PayrollSlipDto.fromJson(Map<String, dynamic> json) {
    return PayrollSlipDto(
      slipId: json['slip_id'] ?? '',
      staffMemberId: json['staff_member_id'] ?? '',
      staffName: json['staff_name'] ?? '',
      staffRole: json['staff_role'] ?? '',
      baseSalaryBdt: double.tryParse(json['base_salary_bdt']?.toString() ?? '0') ?? 0.0,
      allowancesBdt: double.tryParse(json['allowances_bdt']?.toString() ?? '0') ?? 0.0,
      bonusBdt: double.tryParse(json['bonus_bdt']?.toString() ?? '0') ?? 0.0,
      deductionsBdt: double.tryParse(json['deductions_bdt']?.toString() ?? '0') ?? 0.0,
      netSalaryBdt: double.tryParse(json['net_salary_bdt']?.toString() ?? '0') ?? 0.0,
      bankName: json['bank_name'] ?? '',
      bankAccountNo: json['bank_account_no'] ?? '',
      paymentStatus: json['payment_status'] ?? 'PENDING',
    );
  }
}

class PayrollRunBatchDto {
  final String runId;
  final String tenantId;
  final String? branchId;
  final String runNumber;
  final String periodStart;
  final String periodEnd;
  final String paymentDate;
  final String status;
  final String paymentMethod;
  final double totalGrossBdt;
  final double totalAllowancesBdt;
  final double totalBonusesBdt;
  final double totalDeductionsBdt;
  final double totalNetPayableBdt;
  final String? settlementAccountId;
  final String? postedJournalId;
  final bool isConfidential;
  final List<PayrollSlipDto> slips;

  PayrollRunBatchDto({
    required this.runId,
    required this.tenantId,
    this.branchId,
    required this.runNumber,
    required this.periodStart,
    required this.periodEnd,
    required this.paymentDate,
    required this.status,
    required this.paymentMethod,
    required this.totalGrossBdt,
    required this.totalAllowancesBdt,
    required this.totalBonusesBdt,
    required this.totalDeductionsBdt,
    required this.totalNetPayableBdt,
    this.settlementAccountId,
    this.postedJournalId,
    required this.isConfidential,
    required this.slips,
  });

  factory PayrollRunBatchDto.fromJson(Map<String, dynamic> json) {
    var rawSlips = json['slips'] as List<dynamic>? ?? [];
    return PayrollRunBatchDto(
      runId: json['run_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'],
      runNumber: json['run_number'] ?? '',
      periodStart: json['period_start'] ?? '',
      periodEnd: json['period_end'] ?? '',
      paymentDate: json['payment_date'] ?? '',
      status: json['status'] ?? 'DRAFT',
      paymentMethod: json['payment_method'] ?? 'BANK_TRANSFER',
      totalGrossBdt: double.tryParse(json['total_gross_bdt']?.toString() ?? '0') ?? 0.0,
      totalAllowancesBdt: double.tryParse(json['total_allowances_bdt']?.toString() ?? '0') ?? 0.0,
      totalBonusesBdt: double.tryParse(json['total_bonuses_bdt']?.toString() ?? '0') ?? 0.0,
      totalDeductionsBdt: double.tryParse(json['total_deductions_bdt']?.toString() ?? '0') ?? 0.0,
      totalNetPayableBdt: double.tryParse(json['total_net_payable_bdt']?.toString() ?? '0') ?? 0.0,
      settlementAccountId: json['settlement_account_id'],
      postedJournalId: json['posted_journal_id'],
      isConfidential: json['is_confidential'] ?? true,
      slips: rawSlips.map((s) => PayrollSlipDto.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class MobilePayrollExpenseClient {
  static const Set<String> seniorRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> staffDeniedRoles = {
    'CASHIER',
    'STAFF_PHARMACIST',
    'INVENTORY_CLERK',
    'DISPENSER',
  };

  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;

  final List<PayrollRunBatchDto> _mockRuns = [];

  MobilePayrollExpenseClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
  });

  bool get isManageAuthorized => seniorRoles.contains(userRole.toUpperCase());
  bool get isStaffDenied => staffDeniedRoles.contains(userRole.toUpperCase());

  /// Checks ordinary expense category to prevent payroll entry as regular expenses
  void validateOrdinaryExpenseCategory(String categoryCode) {
    if (categoryCode.toUpperCase() == 'SALARIES') {
      throw PayrollValidationException(
        errorCode: 'ERR_PAYROLL_EXPENSE_BOUNDARY_ENFORCED',
        messageEn: 'Individual employee payroll cannot be entered as ordinary operational expenses.',
        messageBn: 'কর্মচারীদের বেতন সাধারণ পরিচালন ব্যয় হিসেবে এন্ট্রি করা যাবে না।',
      );
    }
  }

  /// Creates draft payroll batch with individual confidential slips
  PayrollRunBatchDto createPayrollRun({
    required String periodStart,
    required String periodEnd,
    String paymentMethod = 'BANK_TRANSFER',
    String? settlementAccountId,
    required List<Map<String, dynamic>> slips,
    String? notes,
  }) {
    if (!isManageAuthorized) {
      throw PayrollPermissionException(
        errorCode: 'ERR_PAYROLL_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can create payroll runs.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার পেরোল প্রস্তুত করতে পারেন।',
      );
    }

    if (periodStart.isEmpty || periodEnd.isEmpty) {
      throw PayrollValidationException(
        errorCode: 'ERR_MISSING_PERIOD',
        messageEn: 'Period start and end dates are required.',
        messageBn: 'পেরোল পিরিয়ডের শুরুর ও শেষের তারিখ আবশ্যক।',
      );
    }

    if (slips.isEmpty) {
      throw PayrollValidationException(
        errorCode: 'ERR_EMPTY_PAYROLL_SLIPS',
        messageEn: 'Payroll run requires at least one staff salary slip.',
        messageBn: 'পেরোল রানে অন্তত একজন কর্মচারীর বেতন স্লিপ আবশ্যক।',
      );
    }

    double totalGross = 0.0;
    double totalAllowances = 0.0;
    double totalBonuses = 0.0;
    double totalDeductions = 0.0;
    double totalNet = 0.0;

    List<PayrollSlipDto> processedSlips = [];
    int idx = 1;

    for (var s in slips) {
      double base = double.tryParse(s['base_salary_bdt']?.toString() ?? '0') ?? 0.0;
      double allow = double.tryParse(s['allowances_bdt']?.toString() ?? '0') ?? 0.0;
      double bonus = double.tryParse(s['bonus_bdt']?.toString() ?? '0') ?? 0.0;
      double ded = double.tryParse(s['deductions_bdt']?.toString() ?? '0') ?? 0.0;

      if (base <= 0.0) {
        throw PayrollValidationException(
          errorCode: 'ERR_INVALID_BASE_SALARY',
          messageEn: 'Base salary must be positive.',
          messageBn: 'মূল বেতন ধনাত্মক হতে হবে।',
        );
      }

      double net = base + allow + bonus - ded;
      if (net < 0.0) {
        throw PayrollValidationException(
          errorCode: 'ERR_NEGATIVE_NET_SALARY',
          messageEn: 'Net salary cannot be negative.',
          messageBn: 'নিট বেতন ঋণাত্মক হতে পারে না।',
        );
      }

      totalGross += base;
      totalAllowances += allow;
      totalBonuses += bonus;
      totalDeductions += ded;
      totalNet += net;

      processedSlips.add(
        PayrollSlipDto(
          slipId: 'pslip-$idx',
          staffMemberId: s['staff_member_id'] ?? 'staff-$idx',
          staffName: s['staff_name'] ?? 'Staff $idx',
          staffRole: s['staff_role'] ?? 'PHARMACIST',
          baseSalaryBdt: base,
          allowancesBdt: allow,
          bonusBdt: bonus,
          deductionsBdt: ded,
          netSalaryBdt: net,
          bankName: s['bank_name'] ?? 'City Bank',
          bankAccountNo: s['bank_account_no'] ?? '1234567890',
          paymentStatus: 'PENDING',
        ),
      );
      idx++;
    }

    final run = PayrollRunBatchDto(
      runId: 'payrun-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: tenantId,
      branchId: branchId,
      runNumber: 'PAY-${periodStart.replaceAll("-", "").substring(0, 6)}-001',
      periodStart: periodStart,
      periodEnd: periodEnd,
      paymentDate: DateTime.now().toIso8601String().substring(0, 10),
      status: 'DRAFT',
      paymentMethod: paymentMethod,
      totalGrossBdt: totalGross,
      totalAllowancesBdt: totalAllowances,
      totalBonusesBdt: totalBonuses,
      totalDeductionsBdt: totalDeductions,
      totalNetPayableBdt: totalNet,
      settlementAccountId: settlementAccountId,
      isConfidential: true,
      slips: processedSlips,
    );

    _mockRuns.add(run);
    return run;
  }

  /// Approves and posts payroll to General Ledger
  PayrollRunBatchDto approveAndPostPayroll(String runId) {
    if (!isManageAuthorized) {
      throw PayrollPermissionException(
        errorCode: 'ERR_PAYROLL_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can approve payroll.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার পেরোল অনুমোদন করতে পারেন।',
      );
    }

    final index = _mockRuns.indexWhere((r) => r.runId == runId);
    if (index == -1) {
      throw PayrollValidationException(
        errorCode: 'ERR_PAYROLL_RUN_NOT_FOUND',
        messageEn: 'Payroll run not found.',
        messageBn: 'পেরোল রান পাওয়া যায়নি।',
      );
    }

    final target = _mockRuns[index];
    if (target.status == 'POSTED') {
      throw PayrollValidationException(
        errorCode: 'ERR_PAYROLL_ALREADY_POSTED',
        messageEn: 'Payroll run has already been approved and posted.',
        messageBn: 'পেরোল রান ইতোমধ্যে অনুমোদিত এবং পোস্ট করা হয়েছে।',
      );
    }

    final updated = PayrollRunBatchDto(
      runId: target.runId,
      tenantId: target.tenantId,
      branchId: target.branchId,
      runNumber: target.runNumber,
      periodStart: target.periodStart,
      periodEnd: target.periodEnd,
      paymentDate: target.paymentDate,
      status: 'POSTED',
      paymentMethod: target.paymentMethod,
      totalGrossBdt: target.totalGrossBdt,
      totalAllowancesBdt: target.totalAllowancesBdt,
      totalBonusesBdt: target.totalBonusesBdt,
      totalDeductionsBdt: target.totalDeductionsBdt,
      totalNetPayableBdt: target.totalNetPayableBdt,
      settlementAccountId: target.settlementAccountId,
      postedJournalId: 'jrnl-posted-${DateTime.now().millisecondsSinceEpoch}',
      isConfidential: target.isConfidential,
      slips: target.slips.map((s) => PayrollSlipDto(
        slipId: s.slipId,
        staffMemberId: s.staffMemberId,
        staffName: s.staffName,
        staffRole: s.staffRole,
        baseSalaryBdt: s.baseSalaryBdt,
        allowancesBdt: s.allowancesBdt,
        bonusBdt: s.bonusBdt,
        deductionsBdt: s.deductionsBdt,
        netSalaryBdt: s.netSalaryBdt,
        bankName: s.bankName,
        bankAccountNo: s.bankAccountNo,
        paymentStatus: 'PAID',
      )).toList(),
    );

    _mockRuns[index] = updated;
    return updated;
  }

  List<PayrollRunBatchDto> getRuns() => List.unmodifiable(_mockRuns);
}
