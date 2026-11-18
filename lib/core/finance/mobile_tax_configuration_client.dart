// mobile_tax_configuration_client.dart
// Architecture Decision: ADR-0297 (P297).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class TaxConfigPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  TaxConfigPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });
}

class TaxConfigValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  TaxConfigValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });
}

enum TaxUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class TaxRuleDto {
  final String ruleId;
  final String ruleCode;
  final String name;
  final String nameBn;
  final String appliesToScope;
  final String calculationMode;
  final String taxRatePct;
  final String glAccountCode;
  final String effectiveFrom;
  final String? effectiveTo;
  final String status;
  final String reviewReference;

  TaxRuleDto({
    required this.ruleId,
    required this.ruleCode,
    required this.name,
    required this.nameBn,
    required this.appliesToScope,
    required this.calculationMode,
    required this.taxRatePct,
    required this.glAccountCode,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.status,
    required this.reviewReference,
  });

  factory TaxRuleDto.fromJson(Map<String, dynamic> json) {
    return TaxRuleDto(
      ruleId: json['rule_id']?.toString() ?? '',
      ruleCode: json['rule_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameBn: json['name_bn']?.toString() ?? '',
      appliesToScope: json['applies_to_scope']?.toString() ?? 'ALL_ITEMS',
      calculationMode: json['calculation_mode']?.toString() ?? 'EXCLUSIVE',
      taxRatePct: json['tax_rate_pct']?.toString() ?? '0.000',
      glAccountCode: json['gl_account_code']?.toString() ?? '2030',
      effectiveFrom: json['effective_from']?.toString() ?? '',
      effectiveTo: json['effective_to']?.toString(),
      status: json['status']?.toString() ?? 'DRAFT',
      reviewReference: json['review_reference']?.toString() ?? '',
    );
  }

  Map<String, String> localizedStatusLabel() {
    switch (status.toUpperCase()) {
      case 'REVIEWED_ACTIVE':
        return {'en': 'Reviewed & Active', 'bn': 'পর্যালোচিত ও সক্রিয়'};
      case 'ARCHIVED':
        return {'en': 'Archived', 'bn': 'আর্কাইভকৃত'};
      default:
        return {'en': 'Draft (Pending Review)', 'bn': 'ড্রাফট (পর্যালোচনার অপেক্ষায়)'};
    }
  }
}

class MobileTaxConfigurationClient {
  static const Set<String> _manageRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String branchId;
  final String userRole;

  TaxUiState uiState = TaxUiState.idle;
  List<TaxRuleDto> _offlineRules = [];

  MobileTaxConfigurationClient({
    required this.tenantId,
    required this.branchId,
    required String userRole,
  }) : userRole = userRole.toUpperCase();

  bool canManage() => _manageRoles.contains(userRole);

  void assertManageAuthorized() {
    if (!canManage()) {
      uiState = TaxUiState.permissionDenied;
      throw TaxConfigPermissionException(
        errorCode: 'ERR_TAX_MANAGE_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can configure or review tax rules.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার ট্যাক্স রুল কনফিগার বা অনুমোদন করতে পারেন।',
      );
    }
  }

  Map<String, dynamic> buildDraftRulePayload({
    required String ruleCode,
    required String name,
    String nameBn = '',
    String appliesToScope = 'ALL_ITEMS',
    String calculationMode = 'EXCLUSIVE',
    required String taxRatePct,
    required String effectiveFrom,
  }) {
    assertManageAuthorized();
    final parsed = double.tryParse(taxRatePct);
    if (parsed == null || parsed < 0 || parsed > 100) {
      throw TaxConfigValidationException(
        errorCode: 'ERR_INVALID_TAX_RATE',
        messageEn: 'Tax rate must be between 0.000% and 100.000%.',
        messageBn: 'ট্যাক্স হার ০.০০০% থেকে ১০০.০০০%-এর মধ্যে হতে হবে।',
      );
    }
    return {
      'tenant_id': tenantId,
      'branch_id': branchId,
      'rule_code': ruleCode.trim().toUpperCase(),
      'name': name.trim(),
      'name_bn': nameBn.trim(),
      'applies_to_scope': appliesToScope.trim().toUpperCase(),
      'calculation_mode': calculationMode.trim().toUpperCase(),
      'tax_rate_pct': taxRatePct,
      'effective_from': effectiveFrom,
    };
  }

  List<TaxRuleDto> parseRulesResponse(Map<String, dynamic> json) {
    final raw = (json['rules'] as List<dynamic>? ?? []);
    final items = raw.map((e) => TaxRuleDto.fromJson(e as Map<String, dynamic>)).toList();
    _offlineRules = items;
    uiState = items.isEmpty ? TaxUiState.empty : TaxUiState.loaded;
    return items;
  }

  List<TaxRuleDto> loadOfflineFallback() {
    if (_offlineRules.isEmpty) {
      uiState = TaxUiState.empty;
      return const [];
    }
    uiState = TaxUiState.offlineCache;
    return List.unmodifiable(_offlineRules);
  }
}
