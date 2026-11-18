// mobile_party_import_export_client.dart
// Architecture Decision: ADR-0278 (P278).
// Phase 14: Customers, Suppliers, Dues & Payments.

class PartyPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PartyPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PartyValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PartyValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PartyImportPreviewItemDto {
  final int rowNumber;
  final String name;
  final String phone;
  final bool isValid;
  final bool isDuplicate;
  final String? duplicateMatchId;
  final List<String> errors;

  PartyImportPreviewItemDto({
    required this.rowNumber,
    required this.name,
    required this.phone,
    required this.isValid,
    required this.isDuplicate,
    this.duplicateMatchId,
    this.errors = const [],
  });

  Map<String, dynamic> toJson() => {
        'row_number': rowNumber,
        'name': name,
        'phone': phone,
        'is_valid': isValid,
        'is_duplicate': isDuplicate,
        'duplicate_match_id': duplicateMatchId,
        'errors': errors,
      };
}

class PartyImportPreviewResultDto {
  final String partyType;
  final int totalRecords;
  final int validCount;
  final int duplicateCount;
  final int invalidCount;
  final List<PartyImportPreviewItemDto> previewItems;

  PartyImportPreviewResultDto({
    required this.partyType,
    required this.totalRecords,
    required this.validCount,
    required this.duplicateCount,
    required this.invalidCount,
    required this.previewItems,
  });

  Map<String, dynamic> toJson() => {
        'party_type': partyType,
        'total_records': totalRecords,
        'valid_count': validCount,
        'duplicate_count': duplicateCount,
        'invalid_count': invalidCount,
        'preview_items': previewItems.map((e) => e.toJson()).toList(),
      };
}

class PartyImportCommitResultDto {
  final bool success;
  final String partyType;
  final int createdCount;
  final int updatedCount;
  final int skippedCount;
  final String duplicateResolution;
  final String messageEn;
  final String messageBn;

  PartyImportCommitResultDto({
    this.success = true,
    required this.partyType,
    required this.createdCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.duplicateResolution,
    required this.messageEn,
    required this.messageBn,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'party_type': partyType,
        'created_count': createdCount,
        'updated_count': updatedCount,
        'skipped_count': skippedCount,
        'duplicate_resolution': duplicateResolution,
        'message_en': messageEn,
        'message_bn': messageBn,
      };
}

class MobilePartyImportExportClient {
  final String tenantId;
  final String? branchId;
  final String userRole;
  final String userId;

  final Map<String, Map<String, dynamic>> _customerStore = {};
  final Map<String, Map<String, dynamic>> _supplierStore = {};

  static const Set<String> authorizedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> unmaskedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  MobilePartyImportExportClient({
    required this.tenantId,
    this.branchId,
    required String userRole,
    required this.userId,
  }) : userRole = userRole.toUpperCase();

  bool get isAuthorized => authorizedRoles.contains(userRole);
  bool get canViewUnmasked => unmaskedRoles.contains(userRole);

  void _assertAuthorized() {
    if (!isAuthorized) {
      throw PartyPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to import or export party records.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট কাস্টমার বা সাপ্লায়ার ইমপোর্ট/এক্সপোর্ট করার অনুমতিপ্রাপ্ত নন।',
      );
    }
  }

  static String maskPhone(String phone) {
    final p = phone.trim();
    if (p.length >= 11) {
      return '${p.substring(0, 3)}****${p.substring(p.length - 4)}';
    }
    return '***';
  }

  static String maskEmail(String email) {
    if (!email.contains('@')) return '***';
    final parts = email.split('@');
    final name = parts[0];
    final masked = name.length > 1 ? '${name[0]}***' : '***';
    return '$masked@${parts[1]}';
  }

  static String maskBankAcc(String acc) {
    final a = acc.trim();
    if (a.length > 4) {
      return '****${a.substring(a.length - 4)}';
    }
    return '****';
  }

  void seedCustomer(Map<String, dynamic> customer) {
    _customerStore[customer['customer_id'] ?? customer['phone']] = customer;
  }

  void seedSupplier(Map<String, dynamic> supplier) {
    _supplierStore[supplier['supplier_id'] ?? supplier['code']] = supplier;
  }

  List<Map<String, dynamic>> exportParties({
    String partyType = 'CUSTOMER',
    bool includeSensitive = false,
  }) {
    _assertAuthorized();

    final allowUnmasked = canViewUnmasked && includeSensitive;
    final type = partyType.trim().toUpperCase();

    if (type == 'CUSTOMER') {
      return _customerStore.values.map((c) {
        final res = Map<String, dynamic>.from(c);
        if (!allowUnmasked) {
          res['phone'] = maskPhone(res['phone']?.toString() ?? '');
          res['email'] = maskEmail(res['email']?.toString() ?? '');
          res['address'] = '[REDACTED]';
          res['credit_limit_bdt'] = '[RESTRICTED]';
        }
        return res;
      }).toList();
    } else {
      return _supplierStore.values.map((s) {
        final res = Map<String, dynamic>.from(s);
        if (!allowUnmasked) {
          res['phone'] = maskPhone(res['phone']?.toString() ?? '');
          res['bank_account_no'] = maskBankAcc(res['bank_account_no']?.toString() ?? '');
        }
        return res;
      }).toList();
    }
  }

  PartyImportPreviewResultDto previewImport({
    String partyType = 'CUSTOMER',
    required List<Map<String, dynamic>> records,
  }) {
    _assertAuthorized();

    if (records.isEmpty) {
      throw PartyValidationException(
        errorCode: 'ERR_EMPTY_IMPORT_PAYLOAD',
        messageEn: 'Import batch records list is required.',
        messageBn: 'ইমপোর্ট ব্যাচ রেকর্ড তালিকা আবশ্যক।',
      );
    }

    final type = partyType.trim().toUpperCase();
    int valid = 0, dups = 0, invalid = 0;
    final previewItems = <PartyImportPreviewItemDto>[];

    if (type == 'CUSTOMER') {
      final existingPhones = _customerStore.values
          .map((c) => c['phone']?.toString().replaceAll(RegExp(r'\D'), '') ?? '')
          .toSet();

      int row = 1;
      for (final r in records) {
        final name = (r['full_name'] ?? r['name'])?.toString().trim() ?? '';
        final phone = r['phone']?.toString().trim() ?? '';
        final errors = <String>[];

        if (name.isEmpty) errors.add('Customer name is required.');
        if (phone.isEmpty) {
          errors.add('Phone is required.');
        } else if (phone.replaceAll(RegExp(r'\D'), '').length < 7) {
          errors.add('Invalid phone number.');
        }

        bool isDup = false;
        String? dupId;
        if (errors.isEmpty) {
          final digits = phone.replaceAll(RegExp(r'\D'), '');
          if (existingPhones.contains(digits)) {
            isDup = true;
            dupId = 'MATCH-EXISTING';
          }
        }

        if (errors.isNotEmpty) {
          invalid++;
        } else if (isDup) {
          dups++;
        } else {
          valid++;
        }

        previewItems.add(PartyImportPreviewItemDto(
          rowNumber: row++,
          name: name,
          phone: phone,
          isValid: errors.isEmpty,
          isDuplicate: isDup,
          duplicateMatchId: dupId,
          errors: errors,
        ));
      }
    } else {
      final existingCodes = _supplierStore.values
          .map((s) => s['code']?.toString().toLowerCase().trim() ?? '')
          .toSet();

      int row = 1;
      for (final r in records) {
        final name = r['name']?.toString().trim() ?? '';
        final code = r['code']?.toString().trim() ?? '';
        final errors = <String>[];

        if (name.isEmpty) errors.add('Supplier name is required.');

        bool isDup = false;
        String? dupId;
        if (errors.isEmpty && code.isNotEmpty && existingCodes.contains(code.toLowerCase())) {
          isDup = true;
          dupId = 'MATCH-CODE';
        }

        if (errors.isNotEmpty) {
          invalid++;
        } else if (isDup) {
          dups++;
        } else {
          valid++;
        }

        previewItems.add(PartyImportPreviewItemDto(
          rowNumber: row++,
          name: name,
          phone: r['phone']?.toString().trim() ?? '',
          isValid: errors.isEmpty,
          isDuplicate: isDup,
          duplicateMatchId: dupId,
          errors: errors,
        ));
      }
    }

    return PartyImportPreviewResultDto(
      partyType: type,
      totalRecords: records.length,
      validCount: valid,
      duplicateCount: dups,
      invalidCount: invalid,
      previewItems: previewItems,
    );
  }

  PartyImportCommitResultDto commitImport({
    String partyType = 'CUSTOMER',
    required List<Map<String, dynamic>> records,
    String duplicateResolution = 'SKIP',
  }) {
    _assertAuthorized();

    final preview = previewImport(partyType: partyType, records: records);
    final resolution = duplicateResolution.toUpperCase();

    int created = 0, updated = 0, skipped = 0;

    for (final item in preview.previewItems) {
      if (!item.isValid) {
        skipped++;
        continue;
      }
      if (item.isDuplicate) {
        if (resolution == 'UPDATE') {
          updated++;
        } else {
          skipped++;
        }
      } else {
        created++;
      }
    }

    return PartyImportCommitResultDto(
      partyType: partyType.toUpperCase(),
      createdCount: created,
      updatedCount: updated,
      skippedCount: skipped,
      duplicateResolution: resolution,
      messageEn: 'Import completed: $created created, $updated updated, $skipped skipped.',
      messageBn: 'ইমপোর্ট সম্পন্ন: $created তৈরি, $updated হালনাগাদ, $skipped স্কিপ।',
    );
  }
}
