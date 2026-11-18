// mobile_cash_bank_account_registry_client.dart
// Architecture Decision: ADR-0274 (P274).
// Phase 14: Customers, Suppliers, Dues & Payments.
//
// Flutter mobile client governing Cash Registers, Bank Accounts, and Payment Clearing
// Accounts with branch-level access control, freezing, and lifecycle management.

class FinancialAccountPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  FinancialAccountPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class FinancialAccountValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  FinancialAccountValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class MobileFinancialAccountDto {
  final String accountId;
  final String tenantId;
  final String? branchId;
  final String accountType; // CASH_REGISTER, BANK_ACCOUNT, MFS_CLEARING, PAYMENT_GATEWAY_CLEARING
  String accountName;
  final String accountCode;
  String accountNumber;
  String bankName;
  String branchName;
  String routingNumber;
  String swiftBic;
  final String currency;
  final double openingBalance;
  double currentBalance;
  String status; // ACTIVE, INACTIVE, FROZEN, CLOSED
  bool isDefaultForType;
  String assignedRole;
  String? assignedUserId;
  String notes;
  bool isActive;
  final DateTime createdAt;

  MobileFinancialAccountDto({
    required this.accountId,
    required this.tenantId,
    this.branchId,
    required this.accountType,
    required this.accountName,
    required this.accountCode,
    this.accountNumber = '',
    this.bankName = '',
    this.branchName = '',
    this.routingNumber = '',
    this.swiftBic = '',
    this.currency = 'BDT',
    required this.openingBalance,
    required this.currentBalance,
    this.status = 'ACTIVE',
    this.isDefaultForType = false,
    this.assignedRole = '',
    this.assignedUserId,
    this.notes = '',
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'account_id': accountId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'account_type': accountType,
        'account_name': accountName,
        'account_code': accountCode,
        'account_number': accountNumber,
        'bank_name': bankName,
        'branch_name': branchName,
        'routing_number': routingNumber,
        'swift_bic': swiftBic,
        'currency': currency,
        'opening_balance': openingBalance.toStringAsFixed(4),
        'current_balance': currentBalance.toStringAsFixed(4),
        'status': status,
        'is_default_for_type': isDefaultForType,
        'assigned_role': assignedRole,
        'assigned_user_id': assignedUserId,
        'notes': notes,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}

class MobileCashBankAccountRegistryClient {
  final String tenantId;
  final String? branchId;
  final String userRole;
  final String userId;

  final Map<String, MobileFinancialAccountDto> _accountStore;

  static const Set<String> viewRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'STAFF_PHARMACIST',
    'CASHIER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> manageRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  MobileCashBankAccountRegistryClient({
    required this.tenantId,
    this.branchId,
    required this.userRole,
    required this.userId,
    Map<String, MobileFinancialAccountDto>? accountStore,
  }) : _accountStore = accountStore ?? {};

  bool canView() => viewRoles.contains(userRole.toUpperCase());
  bool canManage() => manageRoles.contains(userRole.toUpperCase());

  MobileFinancialAccountDto registerAccount({
    required String accountType,
    required String accountName,
    String? accountCode,
    String accountNumber = '',
    String bankName = '',
    String branchName = '',
    String routingNumber = '',
    String swiftBic = '',
    double openingBalance = 0.0,
    bool isDefaultForType = false,
    String assignedRole = '',
    String? assignedUserId,
    String notes = '',
  }) {
    if (!canManage()) {
      throw FinancialAccountPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to configure financial accounts.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট আর্থিক অ্যাকাউন্ট কনফিগার করার অনুমতিপ্রাপ্ত নন।',
      );
    }

    if (accountName.trim().isEmpty) {
      throw FinancialAccountValidationException(
        errorCode: 'ERR_MISSING_ACCOUNT_NAME',
        messageEn: 'Account name is mandatory.',
        messageBn: 'অ্যাকাউন্টের নাম আবশ্যক।',
      );
    }

    final normalizedType = accountType.trim().toUpperCase();
    if (normalizedType == 'BANK_ACCOUNT') {
      if (accountNumber.trim().isEmpty || bankName.trim().isEmpty) {
        throw FinancialAccountValidationException(
          errorCode: 'ERR_MISSING_BANK_DETAILS',
          messageEn: 'Bank account requires bank name and account number.',
          messageBn: 'ব্যাংক অ্যাকাউন্টের জন্য ব্যাংকের নাম ও অ্যাকাউন্ট নম্বর প্রদান আবশ্যক।',
        );
      }
    }

    final finalCode = (accountCode != null && accountCode.trim().isNotEmpty)
        ? accountCode.trim()
        : 'ACC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    for (final acc in _accountStore.values) {
      if (acc.accountCode.toUpperCase() == finalCode.toUpperCase()) {
        throw FinancialAccountValidationException(
          errorCode: 'ERR_DUPLICATE_ACCOUNT_CODE',
          messageEn: 'Account code $finalCode already exists.',
          messageBn: 'অ্যাকাউন্ট কোড $finalCode ইতোমধ্যে বিদ্যমান।',
        );
      }
    }

    if (isDefaultForType) {
      for (final acc in _accountStore.values) {
        if (acc.accountType == normalizedType && acc.branchId == branchId) {
          acc.isDefaultForType = false;
        }
      }
    }

    final accountId = 'finacc-${DateTime.now().microsecondsSinceEpoch}-${_accountStore.length + 1}';
    final account = MobileFinancialAccountDto(
      accountId: accountId,
      tenantId: tenantId,
      branchId: branchId,
      accountType: normalizedType,
      accountName: accountName.trim(),
      accountCode: finalCode,
      accountNumber: accountNumber.trim(),
      bankName: bankName.trim(),
      branchName: branchName.trim(),
      routingNumber: routingNumber.trim(),
      swiftBic: swiftBic.trim(),
      openingBalance: openingBalance,
      currentBalance: openingBalance,
      status: 'ACTIVE',
      isDefaultForType: isDefaultForType,
      assignedRole: assignedRole.trim(),
      assignedUserId: assignedUserId,
      notes: notes.trim(),
    );

    _accountStore[accountId] = account;
    return account;
  }

  MobileFinancialAccountDto freezeAccount(String accountId, {String reason = ''}) {
    if (!canManage()) {
      throw FinancialAccountPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Unauthorized to freeze account.',
        messageBn: 'অ্যাকাউন্ট স্থগিত করার অনুমতি নেই।',
      );
    }
    final acc = _accountStore[accountId];
    if (acc == null) {
      throw FinancialAccountValidationException(
        errorCode: 'ERR_ACCOUNT_NOT_FOUND',
        messageEn: 'Account $accountId not found.',
        messageBn: 'অ্যাকাউন্ট $accountId পাওয়া যায়নি।',
      );
    }
    if (acc.status == 'CLOSED') {
      throw FinancialAccountValidationException(
        errorCode: 'ERR_ACCOUNT_CLOSED',
        messageEn: 'Cannot freeze a closed account.',
        messageBn: 'বন্ধ অ্যাকাউন্ট স্থগিত করা সম্ভব নয়।',
      );
    }
    acc.status = 'FROZEN';
    return acc;
  }

  MobileFinancialAccountDto unfreezeAccount(String accountId, {String reason = ''}) {
    if (!canManage()) {
      throw FinancialAccountPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Unauthorized to unfreeze account.',
        messageBn: 'অ্যাকাউন্ট সক্রিয় করার অনুমতি নেই।',
      );
    }
    final acc = _accountStore[accountId];
    if (acc == null) {
      throw FinancialAccountValidationException(
        errorCode: 'ERR_ACCOUNT_NOT_FOUND',
        messageEn: 'Account $accountId not found.',
        messageBn: 'অ্যাকাউন্ট $accountId পাওয়া যায়নি।',
      );
    }
    if (acc.status == 'CLOSED') {
      throw FinancialAccountValidationException(
        errorCode: 'ERR_ACCOUNT_CLOSED',
        messageEn: 'Cannot unfreeze a closed account.',
        messageBn: 'বন্ধ অ্যাকাউন্ট সক্রিয় করা সম্ভব নয়।',
      );
    }
    acc.status = 'ACTIVE';
    return acc;
  }

  MobileFinancialAccountDto closeAccount(String accountId, {String reason = ''}) {
    if (!canManage()) {
      throw FinancialAccountPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Unauthorized to close account.',
        messageBn: 'অ্যাকাউন্ট বন্ধ করার অনুমতি নেই।',
      );
    }
    final acc = _accountStore[accountId];
    if (acc == null) {
      throw FinancialAccountValidationException(
        errorCode: 'ERR_ACCOUNT_NOT_FOUND',
        messageEn: 'Account $accountId not found.',
        messageBn: 'অ্যাকাউন্ট $accountId পাওয়া যায়নি।',
      );
    }
    acc.status = 'CLOSED';
    acc.isActive = false;
    acc.isDefaultForType = false;
    return acc;
  }

  List<MobileFinancialAccountDto> listAccounts({
    String? filterBranchId,
    String? filterType,
    String? filterStatus,
  }) {
    if (!canView()) {
      throw FinancialAccountPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Unauthorized to view financial accounts.',
        messageBn: 'অ্যাকাউন্ট তালিকা দেখার অনুমতি নেই।',
      );
    }

    return _accountStore.values.where((acc) {
      if (userRole.toUpperCase() == 'CASHIER') {
        if (acc.accountType != 'CASH_REGISTER') return false;
        if (branchId != null && branchId!.isNotEmpty && acc.branchId != branchId) return false;
      }
      if (filterBranchId != null && filterBranchId.isNotEmpty && acc.branchId != filterBranchId) return false;
      if (filterType != null && filterType.isNotEmpty && acc.accountType != filterType.toUpperCase()) return false;
      if (filterStatus != null && filterStatus.isNotEmpty && acc.status != filterStatus.toUpperCase()) return false;
      return true;
    }).toList();
  }
}
