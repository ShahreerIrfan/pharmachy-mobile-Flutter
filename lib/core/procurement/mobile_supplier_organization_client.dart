// mobile_supplier_organization_client.dart
// Architecture Decision: ADR-0181 (P181) & ADR-0182 (P182).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing tenant-scoped supplier organizations,
// legal identity, NBR TIN/BIN credentials, contact persons, AP ledger tracking,
// and proof of authentic origin verification.

class MobileSupplierOrganization {
  final String supplierId;
  final String tenantId;
  final String name;
  final String nameBn;
  final String legalName;
  final String code;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String region;
  final String district;
  final String dlNumber;
  final String tinNumber;
  final String binNumber;
  final String tradeLicenseNumber;
  String status;
  final int paymentTermsDays;
  final double creditLimit;
  double currentBalance;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNo;
  final String bankRoutingNumber;
  final int leadTimeDays;
  bool proofOfOriginVerified;
  String proofOfOriginNotes;
  bool isActive;
  final DateTime createdAt;

  MobileSupplierOrganization({
    required this.supplierId,
    required this.tenantId,
    required this.name,
    this.nameBn = '',
    required this.legalName,
    this.code = '',
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    required this.region,
    this.district = '',
    this.dlNumber = '',
    this.tinNumber = '',
    this.binNumber = '',
    this.tradeLicenseNumber = '',
    this.status = 'ACTIVE',
    this.paymentTermsDays = 30,
    this.creditLimit = 0.0,
    this.currentBalance = 0.0,
    this.bankName = '',
    this.bankAccountName = '',
    this.bankAccountNo = '',
    this.bankRoutingNumber = '',
    this.leadTimeDays = 2,
    this.proofOfOriginVerified = false,
    this.proofOfOriginNotes = '',
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'supplier_id': supplierId,
        'tenant_id': tenantId,
        'name': name,
        'name_bn': nameBn,
        'legal_name': legalName,
        'code': code,
        'contact_person': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'region': region,
        'district': district,
        'dl_number': dlNumber,
        'tin_number': tinNumber,
        'bin_number': binNumber,
        'trade_license_number': tradeLicenseNumber,
        'status': status,
        'payment_terms_days': paymentTermsDays,
        'credit_limit': creditLimit.toStringAsFixed(4),
        'current_balance': currentBalance.toStringAsFixed(4),
        'bank_name': bankName,
        'bank_account_name': bankAccountName,
        'bank_account_no': bankAccountNo,
        'bank_routing_number': bankRoutingNumber,
        'lead_time_days': leadTimeDays,
        'proof_of_origin_verified': proofOfOriginVerified,
        'proof_of_origin_notes': proofOfOriginNotes,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}

class MobileSupplierContactPerson {
  final String contactId;
  final String tenantId;
  final String supplierId;
  String name;
  String nameBn;
  String designation;
  String role;
  String phone;
  String alternatePhone;
  String email;
  String preferredCommunicationMethod;
  bool isPrimary;
  bool isActive;
  String notes;
  final DateTime createdAt;

  MobileSupplierContactPerson({
    required this.contactId,
    required this.tenantId,
    required this.supplierId,
    required this.name,
    this.nameBn = '',
    this.designation = '',
    this.role = 'SALES_REPRESENTATIVE',
    required this.phone,
    this.alternatePhone = '',
    this.email = '',
    this.preferredCommunicationMethod = 'PHONE',
    this.isPrimary = false,
    this.isActive = true,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'contact_id': contactId,
        'tenant_id': tenantId,
        'supplier_id': supplierId,
        'name': name,
        'name_bn': nameBn,
        'designation': designation,
        'role': role,
        'phone': phone,
        'alternate_phone': alternatePhone,
        'email': email,
        'preferred_communication_method': preferredCommunicationMethod,
        'is_primary': isPrimary,
        'is_active': isActive,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

class MobileSupplierLedgerEntry {
  final String postingId;
  final String tenantId;
  final String supplierId;
  final String? branchId;
  final String postingType;
  final String referenceNumber;
  final double debitAmount;
  final double creditAmount;
  final double balanceAfter;
  final String currency;
  final String notes;
  final DateTime postedAt;

  const MobileSupplierLedgerEntry({
    required this.postingId,
    required this.tenantId,
    required this.supplierId,
    this.branchId,
    required this.postingType,
    required this.referenceNumber,
    required this.debitAmount,
    required this.creditAmount,
    required this.balanceAfter,
    this.currency = 'BDT',
    this.notes = '',
    required this.postedAt,
  });

  Map<String, dynamic> toJson() => {
        'posting_id': postingId,
        'tenant_id': tenantId,
        'supplier_id': supplierId,
        'branch_id': branchId,
        'posting_type': postingType,
        'reference_number': referenceNumber,
        'debit_amount': debitAmount.toStringAsFixed(4),
        'credit_amount': creditAmount.toStringAsFixed(4),
        'balance_after': balanceAfter.toStringAsFixed(4),
        'currency': currency,
        'notes': notes,
        'posted_at': postedAt.toIso8601String(),
      };
}

class MobileSupplierOrganizationClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileSupplierOrganization> _supplierStore;
  final List<MobileSupplierLedgerEntry> _ledgerStore;
  final Map<String, MobileSupplierContactPerson> _contactStore;

  static const Set<String> _allowedProcurementRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'AUDITOR',
  };

  MobileSupplierOrganizationClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileSupplierOrganization>? initialSuppliers,
    List<MobileSupplierLedgerEntry>? initialLedger,
    Map<String, MobileSupplierContactPerson>? initialContacts,
  })  : _supplierStore = initialSuppliers ?? {},
        _ledgerStore = initialLedger ?? [],
        _contactStore = initialContacts ?? {};

  void _assertProcurementRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedProcurementRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Cashiers cannot manage supplier organizations.');
    }
  }

  MobileSupplierOrganization createSupplier({
    required String name,
    required String legalName,
    String phone = '',
    String email = '',
    String region = 'DHAKA',
    String dlNumber = '',
    String binNumber = '',
    String tinNumber = '',
    String tradeLicenseNumber = '',
    int paymentTermsDays = 30,
    double creditLimit = 0.0,
  }) {
    _assertProcurementRole();

    final trimmedName = name.trim();
    if (trimmedName.length < 2) {
      throw ArgumentError(
          'ERR_MISSING_SUPPLIER_NAME: Supplier name must be at least 2 characters.');
    }

    if (creditLimit < 0) {
      throw ArgumentError(
          'ERR_INVALID_CREDIT_LIMIT: Credit limit cannot be negative.');
    }

    for (final s in _supplierStore.values) {
      if (s.tenantId == tenantId &&
          s.isActive &&
          s.name.toLowerCase() == trimmedName.toLowerCase()) {
        throw StateError(
            'ERR_DUPLICATE_SUPPLIER_NAME: Active supplier with this name already exists.');
      }
    }

    final supplierId =
        'sup-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final org = MobileSupplierOrganization(
      supplierId: supplierId,
      tenantId: tenantId,
      name: trimmedName,
      legalName: legalName.trim().isNotEmpty ? legalName.trim() : trimmedName,
      phone: phone.trim(),
      email: email.trim(),
      region: region.toUpperCase(),
      dlNumber: dlNumber.trim(),
      binNumber: binNumber.trim(),
      tinNumber: tinNumber.trim(),
      tradeLicenseNumber: tradeLicenseNumber.trim(),
      paymentTermsDays: paymentTermsDays >= 0 ? paymentTermsDays : 30,
      creditLimit: creditLimit,
      currentBalance: 0.0,
      createdAt: DateTime.now(),
    );

    _supplierStore[supplierId] = org;
    return org;
  }

  MobileSupplierOrganization getSupplier(String supplierId) {
    final s = _supplierStore[supplierId];
    if (s == null) {
      throw StateError('ERR_SUPPLIER_NOT_FOUND: Supplier not found: $supplierId');
    }
    if (s.tenantId != tenantId) {
      throw StateError(
          'ERR_CROSS_TENANT_ACCESS: Cross-tenant supplier access forbidden.');
    }
    return s;
  }

  List<MobileSupplierOrganization> listSuppliers() {
    final list = _supplierStore.values
        .where((s) => s.tenantId == tenantId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  // =========================================================================
  // SUPPLIER CONTACT PERSONS (P182)
  // =========================================================================

  MobileSupplierContactPerson createSupplierContact({
    required String supplierId,
    required String name,
    String designation = '',
    String role = 'SALES_REPRESENTATIVE',
    required String phone,
    String alternatePhone = '',
    String email = '',
    String preferredCommunicationMethod = 'PHONE',
    bool isPrimary = false,
    String notes = '',
  }) {
    _assertProcurementRole();
    getSupplier(supplierId); // Assert tenant and supplier exist

    final trimmedName = name.trim();
    if (trimmedName.length < 2) {
      throw ArgumentError(
          'ERR_MISSING_CONTACT_NAME: Contact name must be at least 2 characters.');
    }

    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      throw ArgumentError(
          'ERR_MISSING_CONTACT_PHONE: Contact phone number is required.');
    }

    if (isPrimary) {
      for (final c in _contactStore.values) {
        if (c.tenantId == tenantId &&
            c.supplierId == supplierId &&
            c.isPrimary) {
          c.isPrimary = false;
        }
      }
    }

    final contactId =
        'sup-cnt-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final contact = MobileSupplierContactPerson(
      contactId: contactId,
      tenantId: tenantId,
      supplierId: supplierId,
      name: trimmedName,
      designation: designation.trim(),
      role: role.toUpperCase(),
      phone: trimmedPhone,
      alternatePhone: alternatePhone.trim(),
      email: email.trim(),
      preferredCommunicationMethod: preferredCommunicationMethod.toUpperCase(),
      isPrimary: isPrimary,
      isActive: true,
      notes: notes.trim(),
      createdAt: DateTime.now(),
    );

    _contactStore[contactId] = contact;
    return contact;
  }

  MobileSupplierContactPerson getSupplierContact(String contactId) {
    final c = _contactStore[contactId];
    if (c == null) {
      throw StateError('ERR_CONTACT_NOT_FOUND: Contact not found: $contactId');
    }
    if (c.tenantId != tenantId) {
      throw StateError(
          'ERR_CROSS_TENANT_ACCESS: Cross-tenant contact access forbidden.');
    }
    return c;
  }

  List<MobileSupplierContactPerson> listSupplierContacts(
    String supplierId, {
    String? role,
  }) {
    getSupplier(supplierId);
    final list = _contactStore.values
        .where((c) =>
            c.tenantId == tenantId &&
            c.supplierId == supplierId &&
            (role == null || role.toUpperCase() == c.role.toUpperCase()))
        .toList()
      ..sort((a, b) {
        if (a.isPrimary != b.isPrimary) {
          return a.isPrimary ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });
    return list;
  }

  MobileSupplierContactPerson updateSupplierContact({
    required String contactId,
    String? phone,
    String? role,
    bool? setPrimary,
  }) {
    _assertProcurementRole();
    final c = getSupplierContact(contactId);

    if (phone != null) {
      if (phone.trim().isEmpty) {
        throw ArgumentError('ERR_MISSING_CONTACT_PHONE: Phone cannot be empty.');
      }
      c.phone = phone.trim();
    }

    if (role != null) {
      c.role = role.toUpperCase();
    }

    if (setPrimary == true && !c.isPrimary) {
      for (final other in _contactStore.values) {
        if (other.tenantId == tenantId &&
            other.supplierId == c.supplierId &&
            other.isPrimary) {
          other.isPrimary = false;
        }
      }
      c.isPrimary = true;
    }

    return c;
  }

  MobileSupplierContactPerson archiveSupplierContact(String contactId) {
    _assertProcurementRole();
    final c = getSupplierContact(contactId);
    c.isActive = false;
    c.isPrimary = false;
    return c;
  }

  MobileSupplierLedgerEntry postApLedgerEntry({
    required String supplierId,
    required String postingType,
    required String referenceNumber,
    double debitAmount = 0.0,
    double creditAmount = 0.0,
    String notes = '',
  }) {
    _assertProcurementRole();

    final supplier = getSupplier(supplierId);
    if (supplier.status == 'BLACKLISTED') {
      throw StateError(
          'ERR_SUPPLIER_BLACKLISTED: Transactions barred for blacklisted suppliers.');
    }

    if (debitAmount < 0 || creditAmount < 0) {
      throw ArgumentError(
          'ERR_INVALID_AMOUNT: Debit and credit amounts must be non-negative.');
    }

    // Credit increases payable (GRN), Debit decreases payable (Payment / Return)
    final delta = creditAmount - debitAmount;
    final newBalance = supplier.currentBalance + delta;

    final postingId =
        'sup-post-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final entry = MobileSupplierLedgerEntry(
      postingId: postingId,
      tenantId: tenantId,
      supplierId: supplierId,
      branchId: branchId,
      postingType: postingType.toUpperCase(),
      referenceNumber: referenceNumber.trim(),
      debitAmount: debitAmount,
      creditAmount: creditAmount,
      balanceAfter: newBalance,
      currency: 'BDT',
      notes: notes.trim(),
      postedAt: DateTime.now(),
    );

    supplier.currentBalance = newBalance;
    _ledgerStore.add(entry);
    return entry;
  }

  MobileSupplierOrganization verifyProofOfOrigin({
    required String supplierId,
    String verificationNotes = 'Verified authentic manufacturer depot',
  }) {
    _assertProcurementRole();
    final supplier = getSupplier(supplierId);
    supplier.proofOfOriginVerified = true;
    supplier.proofOfOriginNotes = verificationNotes.trim();
    return supplier;
  }
}
