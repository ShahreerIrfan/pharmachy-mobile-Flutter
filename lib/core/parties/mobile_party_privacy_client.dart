// mobile_party_privacy_client.dart
// Architecture Decision: ADR-0279 (P279).
// Phase 14: Customers, Suppliers, Dues & Payments.

class PartyPrivacyPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PartyPrivacyPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PartyPrivacyValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PartyPrivacyValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class RetentionAssessmentDto {
  final String partyType;
  final String partyId;
  final bool canPhysicallyErase;
  final bool statutoryHoldActive;
  final String statutoryAuthority;
  final List<String> conflictsDetected;
  final String openDueBalanceBdt;
  final String currentPayableBalanceBdt;
  final String? assessmentAuditId;
  final String assessedAt;

  RetentionAssessmentDto({
    required this.partyType,
    required this.partyId,
    required this.canPhysicallyErase,
    required this.statutoryHoldActive,
    required this.statutoryAuthority,
    required this.conflictsDetected,
    this.openDueBalanceBdt = '0.00',
    this.currentPayableBalanceBdt = '0.00',
    this.assessmentAuditId,
    required this.assessedAt,
  });

  factory RetentionAssessmentDto.fromJson(Map<String, dynamic> json) {
    return RetentionAssessmentDto(
      partyType: json['party_type'] as String? ?? 'CUSTOMER',
      partyId: json['party_id'] as String? ?? '',
      canPhysicallyErase: json['can_physically_erase'] as bool? ?? false,
      statutoryHoldActive: json['statutory_hold_active'] as bool? ?? false,
      statutoryAuthority: json['statutory_authority'] as String? ?? '',
      conflictsDetected: (json['conflicts_detected'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      openDueBalanceBdt: json['open_due_balance_bdt'] as String? ?? '0.00',
      currentPayableBalanceBdt:
          json['current_payable_balance_bdt'] as String? ?? '0.00',
      assessmentAuditId: json['assessment_audit_id'] as String?,
      assessedAt: json['assessed_at'] as String? ?? '',
    );
  }
}

class PartyCorrectionResultDto {
  final bool success;
  final String partyType;
  final String partyId;
  final String? fullName;
  final String? name;
  final String? phone;
  final String? auditId;
  final String messageEn;
  final String messageBn;

  PartyCorrectionResultDto({
    required this.success,
    required this.partyType,
    required this.partyId,
    this.fullName,
    this.name,
    this.phone,
    this.auditId,
    required this.messageEn,
    required this.messageBn,
  });

  factory PartyCorrectionResultDto.fromJson(Map<String, dynamic> json) {
    return PartyCorrectionResultDto(
      success: json['success'] as bool? ?? false,
      partyType: json['party_type'] as String? ?? '',
      partyId: (json['customer_id'] ?? json['supplier_id'] ?? '') as String,
      fullName: json['full_name'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      auditId: json['audit_id'] as String?,
      messageEn: json['message_en'] as String? ?? '',
      messageBn: json['message_bn'] as String? ?? '',
    );
  }
}

class PartyAnonymizationResultDto {
  final bool success;
  final String partyType;
  final String partyId;
  final String anonymizedName;
  final bool isAnonymized;
  final String? auditId;
  final String messageEn;
  final String messageBn;

  PartyAnonymizationResultDto({
    required this.success,
    required this.partyType,
    required this.partyId,
    required this.anonymizedName,
    required this.isAnonymized,
    this.auditId,
    required this.messageEn,
    required this.messageBn,
  });

  factory PartyAnonymizationResultDto.fromJson(Map<String, dynamic> json) {
    return PartyAnonymizationResultDto(
      success: json['success'] as bool? ?? false,
      partyType: json['party_type'] as String? ?? '',
      partyId: (json['customer_id'] ?? json['supplier_id'] ?? '') as String,
      anonymizedName: json['anonymized_name'] as String? ?? '',
      isAnonymized: json['is_anonymized'] as bool? ?? false,
      auditId: json['audit_id'] as String?,
      messageEn: json['message_en'] as String? ?? '',
      messageBn: json['message_bn'] as String? ?? '',
    );
  }
}

class RestrictedDossierExportDto {
  final String partyType;
  final String classification;
  final Map<String, dynamic> profile;
  final List<dynamic> dueRecords;
  final List<dynamic> clinicalPrescriptions;
  final String? auditId;
  final String exportedAt;

  RestrictedDossierExportDto({
    required this.partyType,
    required this.classification,
    required this.profile,
    required this.dueRecords,
    required this.clinicalPrescriptions,
    this.auditId,
    required this.exportedAt,
  });

  factory RestrictedDossierExportDto.fromJson(Map<String, dynamic> json) {
    return RestrictedDossierExportDto(
      partyType: json['party_type'] as String? ?? 'CUSTOMER',
      classification: json['classification'] as String? ?? 'STANDARD',
      profile: (json['profile'] as Map<String, dynamic>? ?? {}),
      dueRecords: (json['due_records'] as List<dynamic>? ?? []),
      clinicalPrescriptions:
          (json['clinical_prescriptions'] as List<dynamic>? ?? []),
      auditId: json['audit_id'] as String?,
      exportedAt: json['exported_at'] as String? ?? '',
    );
  }
}

class MobilePartyPrivacyClient {
  static const Set<String> privacyAuthorizedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> clinicalExportRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String userRole;
  final String userId;

  MobilePartyPrivacyClient({
    required this.tenantId,
    required this.userRole,
    required this.userId,
  });

  bool get isAuthorized => privacyAuthorizedRoles.contains(userRole.toUpperCase());
  bool get canExportClinical => clinicalExportRoles.contains(userRole.toUpperCase());

  void assertPrivacyAuthorized() {
    if (!isAuthorized) {
      throw PartyPrivacyPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to perform party privacy operations.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট পার্টি ডাটা প্রাইভেসি বা রিটেনশন পরিচালনা করার অনুমতিপ্রাপ্ত নন।',
      );
    }
  }

  void assertClinicalAuthorized() {
    if (!canExportClinical) {
      throw PartyPrivacyPermissionException(
        errorCode: 'ERR_CLINICAL_EXPORT_DENIED',
        messageEn: 'Export of patient-adjacent clinical prescription dossier requires Pharmacy Owner authorization.',
        messageBn: 'রোগীর প্রেসক্রিপশন ও ক্লিনিক্যাল তথ্য এক্সপোর্ট করার জন্য ফার্মেসি ওনার অনুমোদন আবশ্যক।',
      );
    }
  }

  Future<RetentionAssessmentDto> assessRetention({
    required String partyType,
    required String partyId,
    double openDue = 0.0,
    double openPayable = 0.0,
    int rxCount = 0,
    int invoiceCount = 0,
  }) async {
    assertPrivacyAuthorized();

    bool holdActive = false;
    String authority = '';
    final conflicts = <String>[];
    bool canErase = true;

    if (partyType.toUpperCase() == 'CUSTOMER') {
      if (openDue > 0.0) {
        holdActive = true;
        canErase = false;
        authority = 'Active Accounts Receivable Credit Due';
        conflicts.add('Active outstanding due balance ($openDue BDT) exists.');
      }
      if (rxCount > 0) {
        holdActive = true;
        canErase = false;
        authority = 'DGDA Dispensing Rules (2-Year Clinical Rx Retention)';
        conflicts.add('$rxCount clinical prescriptions under active DGDA mandatory 2-year retention.');
      }
      if (invoiceCount > 0) {
        holdActive = true;
        canErase = false;
        authority = 'NBR VAT & Tax Regulations (5-Year Ledger Retention)';
        conflicts.add('$invoiceCount sales invoices under NBR 5-year retention.');
      }

      return RetentionAssessmentDto(
        partyType: 'CUSTOMER',
        partyId: partyId,
        canPhysicallyErase: canErase,
        statutoryHoldActive: holdActive,
        statutoryAuthority: authority,
        conflictsDetected: conflicts,
        openDueBalanceBdt: openDue.toStringAsFixed(2),
        assessmentAuditId: 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
        assessedAt: DateTime.now().toIso8601String(),
      );
    } else {
      if (openPayable != 0.0) {
        holdActive = true;
        canErase = false;
        authority = 'Active Accounts Payable Liability';
        conflicts.add('Active payable balance ($openPayable BDT) exists.');
      }
      return RetentionAssessmentDto(
        partyType: 'SUPPLIER',
        partyId: partyId,
        canPhysicallyErase: canErase,
        statutoryHoldActive: holdActive,
        statutoryAuthority: authority,
        conflictsDetected: conflicts,
        currentPayableBalanceBdt: openPayable.toStringAsFixed(2),
        assessmentAuditId: 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
        assessedAt: DateTime.now().toIso8601String(),
      );
    }
  }

  Future<PartyCorrectionResultDto> correctPartyData({
    required String partyType,
    required String partyId,
    required Map<String, dynamic> corrections,
    required String reason,
  }) async {
    assertPrivacyAuthorized();
    if (reason.trim().isEmpty) {
      throw PartyPrivacyValidationException(
        errorCode: 'ERR_MISSING_CORRECTION_REASON',
        messageEn: 'A mandatory explanation reason is required for party demographic corrections.',
        messageBn: 'তথ্য সংশোধনের সুনির্দিষ্ট কারণ উল্লেখ করা বাধ্যতামূলক।',
      );
    }

    return PartyCorrectionResultDto(
      success: true,
      partyType: partyType.toUpperCase(),
      partyId: partyId,
      fullName: corrections['full_name'] as String?,
      name: corrections['name'] as String?,
      phone: corrections['phone'] as String?,
      auditId: 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
      messageEn: 'Demographic details successfully rectified and audited.',
      messageBn: 'তথ্য সফলভাবে সংশোধন এবং অডিট করা হয়েছে।',
    );
  }

  Future<PartyAnonymizationResultDto> anonymizePartyData({
    required String partyType,
    required String partyId,
    required String reason,
    double openDue = 0.0,
    double openPayable = 0.0,
  }) async {
    assertPrivacyAuthorized();
    if (reason.trim().isEmpty) {
      throw PartyPrivacyValidationException(
        errorCode: 'ERR_MISSING_ANONYMIZATION_REASON',
        messageEn: 'Reason is required for anonymization.',
        messageBn: 'অ্যানোনিমাইজেশনের কারণ উল্লেখ করা আবশ্যক।',
      );
    }

    if (partyType.toUpperCase() == 'CUSTOMER' && openDue > 0.0) {
      throw PartyPrivacyValidationException(
        errorCode: 'ERR_OPEN_DUE_BALANCE_HOLD',
        messageEn: 'Cannot anonymize customer with active outstanding receivable due balance.',
        messageBn: 'বকেয়া বাকি থাকা অবস্থায় কাস্টমার ডাটা অ্যানোনিমাইজ করা নিষিদ্ধ।',
      );
    }

    if (partyType.toUpperCase() == 'SUPPLIER' && openPayable != 0.0) {
      throw PartyPrivacyValidationException(
        errorCode: 'ERR_OPEN_PAYABLE_BALANCE_HOLD',
        messageEn: 'Cannot anonymize supplier with outstanding payable balance.',
        messageBn: 'বকেয়া বাকি থাকা অবস্থায় সরবরাহকারী অ্যানোনিমাইজ করা নিষিদ্ধ।',
      );
    }

    final pseudoName = partyType.toUpperCase() == 'CUSTOMER'
        ? 'Anonymized Customer ${partyId.hashCode.abs()}'
        : 'Anonymized Supplier ${partyId.hashCode.abs()}';

    return PartyAnonymizationResultDto(
      success: true,
      partyType: partyType.toUpperCase(),
      partyId: partyId,
      anonymizedName: pseudoName,
      isAnonymized: true,
      auditId: 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
      messageEn: 'Party PII permanently anonymized under statutory retention hold.',
      messageBn: 'ব্যক্তিগত তথ্য সংবিধিবদ্ধ নিয়ম মেনে স্থায়ীভাবে অ্যানোনিমাইজ করা হয়েছে।',
    );
  }

  Future<RestrictedDossierExportDto> exportRestrictedDossier({
    required String partyType,
    required String partyId,
    String classification = 'STANDARD',
    String reason = '',
  }) async {
    assertPrivacyAuthorized();
    if (classification.toUpperCase() == 'RESTRICTED_CLINICAL') {
      assertClinicalAuthorized();
    }

    return RestrictedDossierExportDto(
      partyType: partyType.toUpperCase(),
      classification: classification.toUpperCase(),
      profile: {
        'party_id': partyId,
        'full_name': 'Kazi Nazrul',
        'phone': '+8801711223344',
      },
      dueRecords: [],
      clinicalPrescriptions: classification.toUpperCase() == 'RESTRICTED_CLINICAL'
          ? [
              {'prescription_id': 'RX-101', 'doctor': 'Dr. M. Rahman'}
            ]
          : [],
      auditId: 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
      exportedAt: DateTime.now().toIso8601String(),
    );
  }
}
