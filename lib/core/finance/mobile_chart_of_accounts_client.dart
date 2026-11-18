// mobile_chart_of_accounts_client.dart
// Architecture Decision: ADR-0281 (P281).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class ChartOfAccountsPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  ChartOfAccountsPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class ChartOfAccountsValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  ChartOfAccountsValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class GLAccountDto {
  final String accountId;
  final String accountCode;
  final String accountName;
  final String accountNameBn;
  final String category;
  final String normalBalance;
  final bool isSystemAccount;
  final String currentBalanceBdt;
  final String status;
  final String description;

  GLAccountDto({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountNameBn,
    required this.category,
    required this.normalBalance,
    required this.isSystemAccount,
    required this.currentBalanceBdt,
    required this.status,
    required this.description,
  });

  factory GLAccountDto.fromJson(Map<String, dynamic> json) {
    return GLAccountDto(
      accountId: json['account_id'] as String? ?? '',
      accountCode: json['account_code'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      accountNameBn: json['account_name_bn'] as String? ?? '',
      category: json['category'] as String? ?? 'ASSET',
      normalBalance: json['normal_balance'] as String? ?? 'DEBIT',
      isSystemAccount: json['is_system_account'] as bool? ?? false,
      currentBalanceBdt: json['current_balance_bdt'] as String? ?? '0.00',
      status: json['status'] as String? ?? 'ACTIVE',
      description: json['description'] as String? ?? '',
    );
  }
}

class MobileChartOfAccountsClient {
  static const Set<String> viewAuthorizedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> manageAuthorizedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String userRole;
  final String userId;

  MobileChartOfAccountsClient({
    required this.tenantId,
    required this.userRole,
    required this.userId,
  });

  bool get isViewAuthorized => viewAuthorizedRoles.contains(userRole.toUpperCase());
  bool get isManageAuthorized => manageAuthorizedRoles.contains(userRole.toUpperCase());

  void assertViewAuthorized() {
    if (!isViewAuthorized) {
      throw ChartOfAccountsPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to access Chart of Accounts.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট চার্ট অফ অ্যাকাউন্টস দেখার অনুমতিপ্রাপ্ত নন।',
      );
    }
  }

  void assertManageAuthorized() {
    if (!isManageAuthorized) {
      throw ChartOfAccountsPermissionException(
        errorCode: 'ERR_COA_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can create or modify Chart of Accounts.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার চার্ট অফ অ্যাকাউন্টস তৈরি বা পরিবর্তন করতে পারেন।',
      );
    }
  }

  List<GLAccountDto> getDefaultPharmacyAccounts() {
    assertViewAuthorized();
    return [
      GLAccountDto(
        accountId: 'coa-1010',
        accountCode: '1010',
        accountName: 'Cash on Hand / Till Cash',
        accountNameBn: 'হাতে নগদ ক্যাশ',
        category: 'ASSET',
        normalBalance: 'DEBIT',
        isSystemAccount: true,
        currentBalanceBdt: '0.00',
        status: 'ACTIVE',
        description: 'Physical cash in drawers',
      ),
      GLAccountDto(
        accountId: 'coa-1020',
        accountCode: '1020',
        accountName: 'Bank & MFS Clearing Accounts',
        accountNameBn: 'ব্যাংক হিসাব',
        category: 'ASSET',
        normalBalance: 'DEBIT',
        isSystemAccount: true,
        currentBalanceBdt: '0.00',
        status: 'ACTIVE',
        description: 'Commercial bank accounts',
      ),
      GLAccountDto(
        accountId: 'coa-1030',
        accountCode: '1030',
        accountName: 'Accounts Receivable (Customer Dues)',
        accountNameBn: 'গ্রাহক প্রাপ্য হিসাব',
        category: 'ASSET',
        normalBalance: 'DEBIT',
        isSystemAccount: true,
        currentBalanceBdt: '0.00',
        status: 'ACTIVE',
        description: 'Customer credit dues',
      ),
      GLAccountDto(
        accountId: 'coa-1040',
        accountCode: '1040',
        accountName: 'Merchandise Inventory Asset',
        accountNameBn: 'ফার্মেসি মজুদ ওষুধ সম্পদ',
        category: 'ASSET',
        normalBalance: 'DEBIT',
        isSystemAccount: true,
        currentBalanceBdt: '0.00',
        status: 'ACTIVE',
        description: 'Stock valuation',
      ),
      GLAccountDto(
        accountId: 'coa-2010',
        accountCode: '2010',
        accountName: 'Accounts Payable (Supplier Dues)',
        accountNameBn: 'সরবরাহকারী পাওনা হিসাব',
        category: 'LIABILITY',
        normalBalance: 'CREDIT',
        isSystemAccount: true,
        currentBalanceBdt: '0.00',
        status: 'ACTIVE',
        description: 'Supplier liabilities',
      ),
      GLAccountDto(
        accountId: 'coa-4010',
        accountCode: '4010',
        accountName: 'Medicine Sales Revenue',
        accountNameBn: 'ওষুধ বিক্রয় আয়',
        category: 'REVENUE',
        normalBalance: 'CREDIT',
        isSystemAccount: true,
        currentBalanceBdt: '0.00',
        status: 'ACTIVE',
        description: 'Dispensing revenue',
      ),
      GLAccountDto(
        accountId: 'coa-5010',
        accountCode: '5010',
        accountName: 'Cost of Goods Sold (COGS)',
        accountNameBn: 'বিক্রীত ওষুধের ক্রয় ব্যয়',
        category: 'COGS',
        normalBalance: 'DEBIT',
        isSystemAccount: true,
        currentBalanceBdt: '0.00',
        status: 'ACTIVE',
        description: 'COGS lot cost',
      ),
      GLAccountDto(
        accountId: 'coa-6010',
        accountCode: '6010',
        accountName: 'Branch Rent Expense',
        accountNameBn: 'দোকান ভাড়া খরচ',
        category: 'EXPENSE',
        normalBalance: 'DEBIT',
        isSystemAccount: false,
        currentBalanceBdt: '0.00',
        status: 'ACTIVE',
        description: 'Branch rent',
      ),
    ];
  }

  Future<GLAccountDto> createAccount({
    required String accountCode,
    required String accountName,
    required String category,
    String? normalBalance,
    String description = '',
  }) async {
    assertManageAuthorized();

    if (accountCode.trim().isEmpty) {
      throw ChartOfAccountsValidationException(
        errorCode: 'ERR_MISSING_ACCOUNT_CODE',
        messageEn: 'Account code is required.',
        messageBn: 'হিসাব কোড আবশ্যক।',
      );
    }
    if (accountName.trim().isEmpty) {
      throw ChartOfAccountsValidationException(
        errorCode: 'ERR_MISSING_ACCOUNT_NAME',
        messageEn: 'Account name is required.',
        messageBn: 'হিসাবের নাম আবশ্যক।',
      );
    }

    final cat = category.toUpperCase();
    final norm = normalBalance ??
        (cat == 'ASSET' || cat == 'COGS' || cat == 'EXPENSE' ? 'DEBIT' : 'CREDIT');

    return GLAccountDto(
      accountId: 'coa-${DateTime.now().millisecondsSinceEpoch}',
      accountCode: accountCode.trim(),
      accountName: accountName.trim(),
      accountNameBn: '',
      category: cat,
      normalBalance: norm,
      isSystemAccount: false,
      currentBalanceBdt: '0.00',
      status: 'ACTIVE',
      description: description,
    );
  }
}
