// mobile_expense_category_client.dart
// Architecture Decision: ADR-0286 (P286).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class ExpenseCategoryPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  ExpenseCategoryPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class ExpenseCategoryValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  ExpenseCategoryValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class ExpenseCategoryDto {
  final String categoryId;
  final String tenantId;
  final String? branchId;
  final String name;
  final String nameBn;
  final String code;
  final String? glAccountId;
  final String glAccountCode;
  final String glAccountName;
  final String defaultGlCode;
  final String description;
  final double monthlyBudgetBdt;
  final bool taxDeductible;
  final bool isPredefined;
  final bool isActive;
  final String createdAt;

  ExpenseCategoryDto({
    required this.categoryId,
    required this.tenantId,
    this.branchId,
    required this.name,
    required this.nameBn,
    required this.code,
    this.glAccountId,
    required this.glAccountCode,
    required this.glAccountName,
    required this.defaultGlCode,
    required this.description,
    required this.monthlyBudgetBdt,
    required this.taxDeductible,
    required this.isPredefined,
    required this.isActive,
    required this.createdAt,
  });

  factory ExpenseCategoryDto.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryDto(
      categoryId: json['category_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      branchId: json['branch_id'],
      name: json['name'] ?? '',
      nameBn: json['name_bn'] ?? '',
      code: json['code'] ?? '',
      glAccountId: json['gl_account_id'],
      glAccountCode: json['gl_account_code'] ?? json['default_gl_code'] ?? '6060',
      glAccountName: json['gl_account_name'] ?? 'Operating Expense',
      defaultGlCode: json['default_gl_code'] ?? '6060',
      description: json['description'] ?? '',
      monthlyBudgetBdt: double.tryParse(json['monthly_budget_bdt']?.toString() ?? '0') ?? 0.0,
      taxDeductible: json['tax_deductible'] ?? true,
      isPredefined: json['is_predefined'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'name': name,
      'name_bn': nameBn,
      'code': code,
      'gl_account_id': glAccountId,
      'gl_account_code': glAccountCode,
      'gl_account_name': glAccountName,
      'default_gl_code': defaultGlCode,
      'description': description,
      'monthly_budget_bdt': monthlyBudgetBdt.toStringAsFixed(2),
      'tax_deductible': taxDeductible,
      'is_predefined': isPredefined,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}

class MobileExpenseCategoryClient {
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
  final String? branchId;
  final String userRole;
  final String userId;

  final Map<String, ExpenseCategoryDto> _cache = {};

  MobileExpenseCategoryClient({
    required this.tenantId,
    this.branchId,
    required this.userRole,
    required this.userId,
  });

  bool get isViewAuthorized => viewRoles.contains(userRole.toUpperCase());
  bool get isManageAuthorized => manageRoles.contains(userRole.toUpperCase());

  ExpenseCategoryDto createCategory({
    required String name,
    String nameBn = '',
    String? code,
    String defaultGlCode = '6060',
    double monthlyBudgetBdt = 0.0,
    bool taxDeductible = true,
    String description = '',
  }) {
    if (!isManageAuthorized) {
      throw ExpenseCategoryPermissionException(
        errorCode: 'ERR_EXPENSE_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can create expense categories.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার খরচ ক্যাটাগরি তৈরি করতে পারেন।',
      );
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ExpenseCategoryValidationException(
        errorCode: 'ERR_MISSING_CATEGORY_NAME',
        messageEn: 'Expense category name is required.',
        messageBn: 'খরচ ক্যাটাগরির নাম আবশ্যক।',
      );
    }

    if (monthlyBudgetBdt < 0) {
      throw ExpenseCategoryValidationException(
        errorCode: 'ERR_INVALID_BUDGET',
        messageEn: 'Monthly budget must be non-negative.',
        messageBn: 'মাসিক বাজেট ঋণাত্মক হতে পারে না।',
      );
    }

    final resolvedCode = (code != null && code.trim().isNotEmpty)
        ? code.trim().toUpperCase()
        : trimmedName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_').toUpperCase();

    // Check duplicate name or code
    for (final c in _cache.values) {
      if (c.name.toLowerCase() == trimmedName.toLowerCase()) {
        throw ExpenseCategoryValidationException(
          errorCode: 'ERR_DUPLICATE_CATEGORY_NAME',
          messageEn: 'An expense category with this name already exists.',
          messageBn: 'এই নামের একটি খরচ ক্যাটাগরি ইতিমধ্যে বিদ্যমান।',
        );
      }
      if (c.code.toUpperCase() == resolvedCode) {
        throw ExpenseCategoryValidationException(
          errorCode: 'ERR_DUPLICATE_CATEGORY_CODE',
          messageEn: 'An expense category with this code already exists.',
          messageBn: 'এই কোডের একটি খরচ ক্যাটাগরি ইতিমধ্যে বিদ্যমান।',
        );
      }
    }

    final catId = 'EXPCAT-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
    final dto = ExpenseCategoryDto(
      categoryId: catId,
      tenantId: tenantId,
      branchId: branchId,
      name: trimmedName,
      nameBn: nameBn.trim(),
      code: resolvedCode,
      glAccountCode: defaultGlCode,
      glAccountName: 'Operating Expense',
      defaultGlCode: defaultGlCode,
      description: description.trim(),
      monthlyBudgetBdt: monthlyBudgetBdt,
      taxDeductible: taxDeductible,
      isPredefined: false,
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    );

    _cache[catId] = dto;
    return dto;
  }

  ExpenseCategoryDto updateCategory({
    required String categoryId,
    String? name,
    String? nameBn,
    double? monthlyBudgetBdt,
    bool? taxDeductible,
    bool? isActive,
    String? description,
  }) {
    if (!isManageAuthorized) {
      throw ExpenseCategoryPermissionException(
        errorCode: 'ERR_EXPENSE_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can update expense categories.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার খরচ ক্যাটাগরি পরিবর্তন করতে পারেন।',
      );
    }

    final existing = _cache[categoryId];
    if (existing == null) {
      throw ExpenseCategoryValidationException(
        errorCode: 'ERR_CATEGORY_NOT_FOUND',
        messageEn: 'Expense category not found.',
        messageBn: 'খরচ ক্যাটাগরি পাওয়া যায়নি।',
      );
    }

    final updated = ExpenseCategoryDto(
      categoryId: existing.categoryId,
      tenantId: existing.tenantId,
      branchId: existing.branchId,
      name: name?.trim() ?? existing.name,
      nameBn: nameBn?.trim() ?? existing.nameBn,
      code: existing.code,
      glAccountId: existing.glAccountId,
      glAccountCode: existing.glAccountCode,
      glAccountName: existing.glAccountName,
      defaultGlCode: existing.defaultGlCode,
      description: description?.trim() ?? existing.description,
      monthlyBudgetBdt: monthlyBudgetBdt ?? existing.monthlyBudgetBdt,
      taxDeductible: taxDeductible ?? existing.taxDeductible,
      isPredefined: existing.isPredefined,
      isActive: isActive ?? existing.isActive,
      createdAt: existing.createdAt,
    );

    _cache[categoryId] = updated;
    return updated;
  }

  ExpenseCategoryDto archiveCategory(String categoryId) {
    return updateCategory(categoryId: categoryId, isActive: false);
  }

  List<ExpenseCategoryDto> listCategories({bool? isActive}) {
    if (!isViewAuthorized) {
      throw ExpenseCategoryPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to view operating expense categories.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট খরচ ক্যাটাগরি দেখার অনুমতিপ্রাপ্ত নন।',
      );
    }

    return _cache.values.where((c) => isActive == null || c.isActive == isActive).toList();
  }

  List<ExpenseCategoryDto> seedDefaultCategories() {
    if (!isManageAuthorized) {
      throw ExpenseCategoryPermissionException(
        errorCode: 'ERR_EXPENSE_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can seed expense categories.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার খরচ ক্যাটাগরি প্রস্তুত করতে পারেন।',
      );
    }

    final defaults = [
      {'name': 'Branch Rent / Shop Lease', 'name_bn': 'দোকান ভাড়া', 'code': 'RENT', 'gl': '6010', 'budget': 35000.0},
      {'name': 'Electricity & Generator Utilities', 'name_bn': 'বিদ্যুৎ ও ইউটিলিটি বিল', 'code': 'UTILITIES', 'gl': '6020', 'budget': 12000.0},
      {'name': 'Staff Salaries & Pharmacist Allowances', 'name_bn': 'কর্মচারীদের বেতন-ভাতা', 'code': 'SALARIES', 'gl': '6030', 'budget': 65000.0},
      {'name': 'Transport & Logistics Delivery', 'name_bn': 'যাতায়াত ও ডেলিভারি খরচ', 'code': 'TRANSPORT', 'gl': '6040', 'budget': 6000.0},
      {'name': 'Internet & Software Subscriptions', 'name_bn': 'ইন্টারনেট ও সফটওয়্যার ফি', 'code': 'INTERNET', 'gl': '6050', 'budget': 3500.0},
      {'name': 'Asset Repairs & Maintenance', 'name_bn': 'মেরামত ও রক্ষণাবেক্ষণ', 'code': 'MAINTENANCE', 'gl': '6060', 'budget': 5000.0},
      {'name': 'Miscellaneous Office & Admin Costs', 'name_bn': 'বিবিধ সাধারণ খরচ', 'code': 'MISC', 'gl': '6060', 'budget': 4000.0},
    ];

    final result = <ExpenseCategoryDto>[];
    for (final d in defaults) {
      final code = d['code'] as String;
      if (!_cache.values.any((c) => c.code == code)) {
        final cat = createCategory(
          name: d['name'] as String,
          nameBn: d['name_bn'] as String,
          code: code,
          defaultGlCode: d['gl'] as String,
          monthlyBudgetBdt: d['budget'] as double,
          taxDeductible: true,
        );
        result.add(cat);
      }
    }
    return result;
  }
}
