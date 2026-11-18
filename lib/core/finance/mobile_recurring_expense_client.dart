// mobile_recurring_expense_client.dart
// Architecture Decision: ADR-0288 (P288).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class RecurringExpensePermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  RecurringExpensePermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class RecurringExpenseValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  RecurringExpenseValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class RecurringExpenseTemplateDto {
  final String templateId;
  final String templateName;
  final String tenantId;
  final String branchId;
  final String categoryId;
  final String categoryName;
  final String payeeName;
  final String payeePhone;
  final double estimatedAmountBdt;
  final String frequency;
  final int dayOfMonth;
  final String startDate;
  final String nextRunDate;
  final String? lastRunDate;
  final String paymentMethod;
  final bool autoApprove;
  final bool isActive;
  final String description;
  final String createdAt;

  RecurringExpenseTemplateDto({
    required this.templateId,
    required this.templateName,
    required this.tenantId,
    required this.branchId,
    required this.categoryId,
    required this.categoryName,
    required this.payeeName,
    required this.payeePhone,
    required this.estimatedAmountBdt,
    required this.frequency,
    required this.dayOfMonth,
    required this.startDate,
    required this.nextRunDate,
    this.lastRunDate,
    required this.paymentMethod,
    required this.autoApprove,
    required this.isActive,
    required this.description,
    required this.createdAt,
  });

  factory RecurringExpenseTemplateDto.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseTemplateDto(
      templateId: json['template_id'] ?? '',
      templateName: json['template_name'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'] ?? '',
      categoryId: json['category_id'] ?? '',
      categoryName: json['category_name'] ?? '',
      payeeName: json['payee_name'] ?? '',
      payeePhone: json['payee_phone'] ?? '',
      estimatedAmountBdt: double.tryParse(json['estimated_amount_bdt']?.toString() ?? '0') ?? 0.0,
      frequency: json['frequency'] ?? 'MONTHLY',
      dayOfMonth: json['day_of_month'] ?? 1,
      startDate: json['start_date'] ?? '',
      nextRunDate: json['next_run_date'] ?? '',
      lastRunDate: json['last_run_date'],
      paymentMethod: json['payment_method'] ?? 'CASH',
      autoApprove: json['auto_approve'] ?? false,
      isActive: json['is_active'] ?? true,
      description: json['description'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'template_id': templateId,
      'template_name': templateName,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'category_id': categoryId,
      'category_name': categoryName,
      'payee_name': payeeName,
      'payee_phone': payeePhone,
      'estimated_amount_bdt': estimatedAmountBdt.toStringAsFixed(2),
      'frequency': frequency,
      'day_of_month': dayOfMonth,
      'start_date': startDate,
      'next_run_date': nextRunDate,
      'last_run_date': lastRunDate,
      'payment_method': paymentMethod,
      'auto_approve': autoApprove,
      'is_active': isActive,
      'description': description,
      'created_at': createdAt,
    };
  }
}

class MobileRecurringExpenseClient {
  static const Set<String> viewRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> manageRoles = {
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

  static final Map<String, RecurringExpenseTemplateDto> _cache = {};

  MobileRecurringExpenseClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
  });

  bool get isViewAuthorized => viewRoles.contains(userRole.toUpperCase());
  bool get isManageAuthorized => manageRoles.contains(userRole.toUpperCase());

  RecurringExpenseTemplateDto createTemplate({
    required String templateName,
    required String categoryId,
    required String categoryName,
    required String payeeName,
    String payeePhone = '',
    required double estimatedAmountBdt,
    String frequency = 'MONTHLY',
    int dayOfMonth = 1,
    String paymentMethod = 'CASH',
    bool autoApprove = false,
    String description = '',
  }) {
    if (!isManageAuthorized) {
      throw RecurringExpensePermissionException(
        errorCode: 'ERR_RECURRING_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can create recurring expense templates.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার রিকারিং খরচ টেমপ্লেট তৈরি করতে পারেন।',
      );
    }

    final trimmedName = templateName.trim();
    if (trimmedName.isEmpty) {
      throw RecurringExpenseValidationException(
        errorCode: 'ERR_MISSING_TEMPLATE_NAME',
        messageEn: 'Template name is required.',
        messageBn: 'টেমপ্লেটের নাম আবশ্যক।',
      );
    }

    if (estimatedAmountBdt <= 0) {
      throw RecurringExpenseValidationException(
        errorCode: 'ERR_INVALID_EXPENSE_AMOUNT',
        messageEn: 'Estimated amount must be greater than zero.',
        messageBn: 'আনুমানিক খরচের পরিমাণ শূন্যের চেয়ে বেশি হতে হবে।',
      );
    }

    // Check duplicate
    for (final t in _cache.values) {
      if (t.templateName.toLowerCase() == trimmedName.toLowerCase()) {
        throw RecurringExpenseValidationException(
          errorCode: 'ERR_DUPLICATE_TEMPLATE_NAME',
          messageEn: 'A recurring expense template with this name already exists.',
          messageBn: 'এই নামের একটি রিকারিং খরচ টেমপ্লেট ইতিমধ্যে বিদ্যমান।',
        );
      }
    }

    final tplId = 'RECTPL-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
    final now = DateTime.now();
    final nextRun = DateTime(now.year, now.month + 1, dayOfMonth);

    final dto = RecurringExpenseTemplateDto(
      templateId: tplId,
      templateName: trimmedName,
      tenantId: tenantId,
      branchId: branchId,
      categoryId: categoryId,
      categoryName: categoryName,
      payeeName: payeeName.trim(),
      payeePhone: payeePhone.trim(),
      estimatedAmountBdt: estimatedAmountBdt,
      frequency: frequency.toUpperCase(),
      dayOfMonth: dayOfMonth,
      startDate: now.toIso8601String().substring(0, 10),
      nextRunDate: nextRun.toIso8601String().substring(0, 10),
      paymentMethod: paymentMethod.toUpperCase(),
      autoApprove: autoApprove,
      isActive: true,
      description: description.trim(),
      createdAt: now.toIso8601String(),
    );

    _cache[tplId] = dto;
    return dto;
  }

  Map<String, dynamic> triggerGeneration(String templateId) {
    if (!isManageAuthorized) {
      throw RecurringExpensePermissionException(
        errorCode: 'ERR_RECURRING_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can trigger recurring expenses.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার রিকারিং খরচ প্রস্তুত করতে পারেন।',
      );
    }

    final tpl = _cache[templateId];
    if (tpl == null) {
      throw RecurringExpenseValidationException(
        errorCode: 'ERR_TEMPLATE_NOT_FOUND',
        messageEn: 'Template not found.',
        messageBn: 'টেমপ্লেট পাওয়া যায়নি।',
      );
    }

    final voucher = 'EXP-REC-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
    return {
      'status': 'SUCCESS',
      'template_id': templateId,
      'voucher_number': voucher,
      'amount_bdt': tpl.estimatedAmountBdt,
    };
  }

  RecurringExpenseTemplateDto archiveTemplate(String templateId) {
    if (!isManageAuthorized) {
      throw RecurringExpensePermissionException(
        errorCode: 'ERR_RECURRING_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can archive recurring templates.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার রিকারিং টেমপ্লেট আর্কাইভ করতে পারেন।',
      );
    }

    final existing = _cache[templateId];
    if (existing == null) {
      throw RecurringExpenseValidationException(
        errorCode: 'ERR_TEMPLATE_NOT_FOUND',
        messageEn: 'Template not found.',
        messageBn: 'টেমপ্লেট পাওয়া যায়নি।',
      );
    }

    final archived = RecurringExpenseTemplateDto(
      templateId: existing.templateId,
      templateName: existing.templateName,
      tenantId: existing.tenantId,
      branchId: existing.branchId,
      categoryId: existing.categoryId,
      categoryName: existing.categoryName,
      payeeName: existing.payeeName,
      payeePhone: existing.payeePhone,
      estimatedAmountBdt: existing.estimatedAmountBdt,
      frequency: existing.frequency,
      dayOfMonth: existing.dayOfMonth,
      startDate: existing.startDate,
      nextRunDate: existing.nextRunDate,
      paymentMethod: existing.paymentMethod,
      autoApprove: existing.autoApprove,
      isActive: false,
      description: existing.description,
      createdAt: existing.createdAt,
    );

    _cache[templateId] = archived;
    return archived;
  }

  List<RecurringExpenseTemplateDto> listTemplates({bool? isActive}) {
    if (!isViewAuthorized) {
      throw RecurringExpensePermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and counter staff are not authorized to view recurring expenses.',
        messageBn: 'ক্যাশিয়ার বা কাউন্টার স্টাফ রিকারিং খরচ দেখার অনুমতিপ্রাপ্ত নন।',
      );
    }

    return _cache.values.where((t) => isActive == null || t.isActive == isActive).toList();
  }
}
