// mobile_payment_method_registry_client.dart
// Architecture Decision: ADR-0275 (P275).
// Phase 14: Customers, Suppliers, Dues & Payments.
//
// Flutter mobile client governing Payment Method Configuration, tender validations,
// surcharge calculation, and zero sensitive secrets enforcement.

class PaymentMethodPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PaymentMethodPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PaymentMethodValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PaymentMethodValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class MobilePaymentMethodConfigDto {
  final String configId;
  final String tenantId;
  final String? branchId;
  final String methodType; // CASH, BKASH, NAGAD, ROCKET, UPAY, CARD, BANK_TRANSFER, DUE
  String displayName;
  int displayOrder;
  bool isEnabled;
  String? clearingAccountId;
  bool requiresReference;
  String referenceLabel;
  String referencePattern;
  double customerSurchargePercentage;
  double customerSurchargeFlatBdt;
  double merchantFeePercentage;
  double minTransactionBdt;
  double maxTransactionBdt;
  bool allowOffline;
  String instructionsEn;
  String instructionsBn;
  String vaultSecretReference;
  String notes;
  final DateTime createdAt;

  MobilePaymentMethodConfigDto({
    required this.configId,
    required this.tenantId,
    this.branchId,
    required this.methodType,
    required this.displayName,
    this.displayOrder = 10,
    this.isEnabled = true,
    this.clearingAccountId,
    this.requiresReference = false,
    this.referenceLabel = '',
    this.referencePattern = '',
    this.customerSurchargePercentage = 0.0,
    this.customerSurchargeFlatBdt = 0.0,
    this.merchantFeePercentage = 0.0,
    this.minTransactionBdt = 0.0,
    this.maxTransactionBdt = 500000.0,
    this.allowOffline = false,
    this.instructionsEn = '',
    this.instructionsBn = '',
    this.vaultSecretReference = '',
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'config_id': configId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'method_type': methodType,
        'display_name': displayName,
        'display_order': displayOrder,
        'is_enabled': isEnabled,
        'clearing_account_id': clearingAccountId,
        'requires_reference': requiresReference,
        'reference_label': referenceLabel,
        'reference_pattern': referencePattern,
        'customer_surcharge_percentage': customerSurchargePercentage.toStringAsFixed(2),
        'customer_surcharge_flat_bdt': customerSurchargeFlatBdt.toStringAsFixed(2),
        'merchant_fee_percentage': merchantFeePercentage.toStringAsFixed(2),
        'min_transaction_bdt': minTransactionBdt.toStringAsFixed(2),
        'max_transaction_bdt': maxTransactionBdt.toStringAsFixed(2),
        'allow_offline': allowOffline,
        'instructions_en': instructionsEn,
        'instructions_bn': instructionsBn,
        'vault_secret_reference': vaultSecretReference,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

class MobilePaymentMethodRegistryClient {
  final String tenantId;
  final String? branchId;
  final String userRole;
  final String userId;

  final Map<String, MobilePaymentMethodConfigDto> _configStore;

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

  static const Set<String> sensitiveKeywords = {
    'secret',
    'api_key',
    'apikey',
    'password',
    'pin',
    'mpin',
    'cvv',
    'cvc',
    'private_key',
  };

  MobilePaymentMethodRegistryClient({
    required this.tenantId,
    this.branchId,
    required this.userRole,
    required this.userId,
    Map<String, MobilePaymentMethodConfigDto>? configStore,
  }) : _configStore = configStore ?? {};

  bool canView() => viewRoles.contains(userRole.toUpperCase());
  bool canManage() => manageRoles.contains(userRole.toUpperCase());

  void checkNoSensitiveSecrets(Map<String, dynamic>? data) {
    if (data == null) return;
    for (final entry in data.entries) {
      final lowerKey = entry.key.toLowerCase().trim();
      if (lowerKey == 'vault_secret_reference') continue;
      for (final kw in sensitiveKeywords) {
        if (lowerKey.contains(kw) && entry.value != null && entry.value.toString().isNotEmpty) {
          throw PaymentMethodValidationException(
            errorCode: 'ERR_SENSITIVE_SECRET_EXPOSURE_BLOCKED',
            messageEn: 'Direct storage of sensitive payment credentials/keys/PINs is prohibited.',
            messageBn: 'সরাসরি পেমেন্ট গেটওয়ে গোপন কোড, পিন বা পাসওয়ার্ড সংরক্ষণ সম্পূর্ণ নিষিদ্ধ।',
          );
        }
      }
    }
  }

  MobilePaymentMethodConfigDto configurePaymentMethod({
    required String methodType,
    String? displayName,
    int displayOrder = 10,
    bool isEnabled = true,
    String? clearingAccountId,
    bool requiresReference = false,
    String referenceLabel = '',
    String referencePattern = '',
    double customerSurchargePercentage = 0.0,
    double customerSurchargeFlatBdt = 0.0,
    double merchantFeePercentage = 0.0,
    double minTransactionBdt = 0.0,
    double maxTransactionBdt = 500000.0,
    bool? allowOffline,
    String instructionsEn = '',
    String instructionsBn = '',
    String vaultSecretReference = '',
    String notes = '',
    Map<String, dynamic>? optionalSecretsCheck,
  }) {
    if (!canManage()) {
      throw PaymentMethodPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to configure payment methods.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট পেমেন্ট মেথড কনফিগার করার অনুমতিপ্রাপ্ত নন।',
      );
    }

    checkNoSensitiveSecrets(optionalSecretsCheck);

    final normType = methodType.trim().toUpperCase();
    if (minTransactionBdt > maxTransactionBdt) {
      throw PaymentMethodValidationException(
        errorCode: 'ERR_INVALID_TRANSACTION_LIMITS',
        messageEn: 'Minimum transaction amount cannot exceed maximum amount.',
        messageBn: 'সর্বনিম্ন লেনদেন পরিমাণ সর্বোচ্চ পরিমাণের চেয়ে বেশি হতে পারে না।',
      );
    }

    MobilePaymentMethodConfigDto? existing;
    for (final cfg in _configStore.values) {
      if (cfg.methodType == normType && cfg.branchId == branchId) {
        existing = cfg;
        break;
      }
    }

    final configId = existing?.configId ?? 'pmcfg-${DateTime.now().microsecondsSinceEpoch}-${_configStore.length + 1}';
    final name = (displayName != null && displayName.trim().isNotEmpty) ? displayName.trim() : normType;
    final isCash = (normType == 'CASH');

    final record = MobilePaymentMethodConfigDto(
      configId: configId,
      tenantId: tenantId,
      branchId: branchId,
      methodType: normType,
      displayName: name,
      displayOrder: displayOrder,
      isEnabled: isEnabled,
      clearingAccountId: clearingAccountId,
      requiresReference: requiresReference,
      referenceLabel: referenceLabel.trim(),
      referencePattern: referencePattern.trim(),
      customerSurchargePercentage: customerSurchargePercentage,
      customerSurchargeFlatBdt: customerSurchargeFlatBdt,
      merchantFeePercentage: merchantFeePercentage,
      minTransactionBdt: minTransactionBdt,
      maxTransactionBdt: maxTransactionBdt,
      allowOffline: allowOffline ?? isCash,
      instructionsEn: instructionsEn.trim(),
      instructionsBn: instructionsBn.trim(),
      vaultSecretReference: vaultSecretReference.trim(),
      notes: notes.trim(),
    );

    _configStore[configId] = record;
    return record;
  }

  MobilePaymentMethodConfigDto togglePaymentMethod(String configId, bool isEnabled) {
    if (!canManage()) {
      throw PaymentMethodPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Unauthorized to toggle payment methods.',
        messageBn: 'পেমেন্ট মেথড চালু বা বন্ধ করার অনুমতি নেই।',
      );
    }
    final cfg = _configStore[configId];
    if (cfg == null) {
      throw PaymentMethodValidationException(
        errorCode: 'ERR_CONFIG_NOT_FOUND',
        messageEn: 'Payment configuration $configId not found.',
        messageBn: 'পেমেন্ট কনফিগারেশন পাওয়া যায়নি।',
      );
    }
    cfg.isEnabled = isEnabled;
    return cfg;
  }

  Map<String, dynamic> validateTender({
    required String configId,
    required double amountBdt,
    String reference = '',
    bool isOffline = false,
  }) {
    if (!canView()) {
      throw PaymentMethodPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Unauthorized to validate tender.',
        messageBn: 'টেন্ডার যাচাই করার অনুমতি নেই।',
      );
    }

    final cfg = _configStore[configId];
    if (cfg == null) {
      throw PaymentMethodValidationException(
        errorCode: 'ERR_CONFIG_NOT_FOUND',
        messageEn: 'Payment configuration not found.',
        messageBn: 'পেমেন্ট কনফিগারেশন পাওয়া যায়নি।',
      );
    }

    if (!cfg.isEnabled) {
      throw PaymentMethodValidationException(
        errorCode: 'ERR_PAYMENT_METHOD_DISABLED',
        messageEn: 'Payment method ${cfg.displayName} is disabled.',
        messageBn: 'পেমেন্ট মেথড ${cfg.displayName} বন্ধ রয়েছে।',
      );
    }

    if (isOffline && !cfg.allowOffline) {
      throw PaymentMethodValidationException(
        errorCode: 'ERR_OFFLINE_PAYMENT_NOT_ALLOWED',
        messageEn: 'Payment method ${cfg.displayName} is not allowed offline.',
        messageBn: 'অফলাইন মোডে এই পেমেন্ট মেথডটি প্রযোজ্য নয়।',
      );
    }

    if (amountBdt < cfg.minTransactionBdt || amountBdt > cfg.maxTransactionBdt) {
      throw PaymentMethodValidationException(
        errorCode: 'ERR_TRANSACTION_AMOUNT_OUT_OF_BOUNDS',
        messageEn: 'Amount $amountBdt is outside permitted bounds.',
        messageBn: 'লেনদেনের অংক অনুমোদিত সীমার বাইরে।',
      );
    }

    final refClean = reference.trim();
    if (cfg.requiresReference && refClean.isEmpty) {
      throw PaymentMethodValidationException(
        errorCode: 'ERR_MISSING_TRANSACTION_REFERENCE',
        messageEn: 'Transaction reference is required for ${cfg.displayName}.',
        messageBn: 'লেনদেন রেফারেন্স নম্বর প্রদান আবশ্যক।',
      );
    }

    if (cfg.requiresReference && cfg.referencePattern.isNotEmpty && refClean.isNotEmpty) {
      final reg = RegExp(cfg.referencePattern);
      if (!reg.hasMatch(refClean)) {
        throw PaymentMethodValidationException(
          errorCode: 'ERR_INVALID_REFERENCE_FORMAT',
          messageEn: 'Transaction reference does not match required format.',
          messageBn: 'রেফারেন্স নম্বরের বিন্যাস সঠিক নয়।',
        );
      }
    }

    double surcharge = 0.0;
    if (cfg.customerSurchargePercentage > 0.0) {
      surcharge = double.parse((amountBdt * cfg.customerSurchargePercentage / 100.0).toStringAsFixed(2));
    }
    surcharge += cfg.customerSurchargeFlatBdt;
    final totalPayable = amountBdt + surcharge;

    return {
      'is_valid': true,
      'method_type': cfg.methodType,
      'display_name': cfg.displayName,
      'amount_bdt': amountBdt,
      'surcharge_bdt': surcharge,
      'total_payable_bdt': totalPayable,
      'reference': refClean,
    };
  }

  List<MobilePaymentMethodConfigDto> listPaymentMethods({
    String? filterBranchId,
    bool onlyEnabled = false,
  }) {
    if (!canView()) {
      throw PaymentMethodPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Unauthorized to view payment methods.',
        messageBn: 'পেমেন্ট মেথড দেখার অনুমতি নেই।',
      );
    }

    return _configStore.values.where((cfg) {
      if (filterBranchId != null && filterBranchId.isNotEmpty && cfg.branchId != null && cfg.branchId != filterBranchId) {
        return false;
      }
      if (onlyEnabled && !cfg.isEnabled) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }
}
