// mobile_supplier_credit_note_client.dart
// Architecture Decision: ADR-0192 (P192).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing Supplier Credit Notes & Audited Reversals:
// - Records supplier credit notes as immutable finance events with traceable origin (Invoice, GRN, Return, PO).
// - Offsets and decrements Accounts Payable balance upon posting.
// - Non-destructive corrections: restores Accounts Payable balance upon audited reversal.

class MobileSupplierLedgerEntry {
  final String postingId;
  final String supplierId;
  final String postingType;
  final String referenceNumber;
  final double debitAmount;
  final double creditAmount;
  final double balanceAfter;
  final DateTime postedAt;

  MobileSupplierLedgerEntry({
    required this.postingId,
    required this.supplierId,
    required this.postingType,
    required this.referenceNumber,
    required this.debitAmount,
    required this.creditAmount,
    required this.balanceAfter,
    required this.postedAt,
  });
}

class MobileSupplierCreditNoteItem {
  final String itemId;
  final String? productId;
  final String productName;
  final int quantity;
  final double unitCreditRate;
  final double taxPercentage;
  final double lineTotal;
  final String description;

  MobileSupplierCreditNoteItem({
    String? itemId,
    this.productId,
    this.productName = '',
    this.quantity = 0,
    this.unitCreditRate = 0.0,
    this.taxPercentage = 0.0,
    double? lineTotal,
    this.description = '',
  })  : itemId = itemId ??
            'scni-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}',
        lineTotal = lineTotal ??
            _calcLineTotal(quantity, unitCreditRate, taxPercentage);

  static double _calcLineTotal(int qty, double rate, double taxPct) {
    final sub = qty > 0 ? (rate * qty) : rate;
    final tax = sub * (taxPct / 100.0);
    return sub + tax;
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit_credit_rate': unitCreditRate.toStringAsFixed(4),
        'tax_percentage': taxPercentage.toStringAsFixed(2),
        'line_total': lineTotal.toStringAsFixed(4),
        'description': description,
      };
}

class MobileSupplierCreditNote {
  final String noteId;
  final String noteNumber;
  final String supplierCreditNoteRef;
  final String tenantId;
  final String branchId;
  final String supplierId;
  final String supplierName;
  String status; // DRAFT, POSTED, REVERSED, CANCELLED
  final String reason;
  final String originType;
  final String originReference;
  final DateTime noteDate;
  final double subtotalAmount;
  final double taxAmount;
  final double totalCreditAmount;
  String? debitLedgerEntryId;
  String? reversalLedgerEntryId;
  String? reversalReason;
  DateTime? reversalPostedAt;
  String? reversedBy;
  String notes;
  DateTime? postedAt;
  final String createdBy;
  String? approvedBy;
  final List<MobileSupplierCreditNoteItem> items;

  MobileSupplierCreditNote({
    required this.noteId,
    required this.noteNumber,
    required this.supplierCreditNoteRef,
    required this.tenantId,
    required this.branchId,
    required this.supplierId,
    required this.supplierName,
    this.status = 'DRAFT',
    this.reason = 'PRICE_DIFFERENCE',
    this.originType = 'INVOICE',
    required this.originReference,
    required this.noteDate,
    required this.subtotalAmount,
    required this.taxAmount,
    required this.totalCreditAmount,
    this.debitLedgerEntryId,
    this.reversalLedgerEntryId,
    this.reversalReason,
    this.reversalPostedAt,
    this.reversedBy,
    this.notes = '',
    this.postedAt,
    required this.createdBy,
    this.approvedBy,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'note_id': noteId,
        'note_number': noteNumber,
        'supplier_credit_note_ref': supplierCreditNoteRef,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'status': status,
        'reason': reason,
        'origin_type': originType,
        'origin_reference': originReference,
        'note_date': noteDate.toIso8601String(),
        'subtotal_amount': subtotalAmount.toStringAsFixed(4),
        'tax_amount': taxAmount.toStringAsFixed(4),
        'total_credit_amount': totalCreditAmount.toStringAsFixed(4),
        'debit_ledger_entry_id': debitLedgerEntryId,
        'reversal_ledger_entry_id': reversalLedgerEntryId,
        'reversal_reason': reversalReason,
        'reversal_posted_at': reversalPostedAt?.toIso8601String(),
        'reversed_by': reversedBy,
        'notes': notes,
        'posted_at': postedAt?.toIso8601String(),
        'created_by': createdBy,
        'approved_by': approvedBy,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class MobileSupplierCreditNoteClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileSupplierCreditNote> noteStore;
  final Map<String, MobileSupplierLedgerEntry> ledgerStore;

  static const Set<String> _allowedProcurementRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
    'AUDITOR',
  };

  static const Set<String> _allowedReversalRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'AUDITOR',
  };

  MobileSupplierCreditNoteClient({
    required this.tenantId,
    required this.branchId,
    this.userRole = 'CASHIER',
    this.userId = 'usr_anon',
    this.isOffline = false,
    Map<String, MobileSupplierCreditNote>? noteStore,
    Map<String, MobileSupplierLedgerEntry>? ledgerStore,
  })  : noteStore = noteStore ?? {},
        ledgerStore = ledgerStore ?? {};

  void _assertProcurementRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedProcurementRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Staff role $userRole cannot manage supplier credit notes.');
    }
  }

  void _assertReversalRole() {
    if (!_allowedReversalRoles.contains(userRole.toUpperCase())) {
      throw StateError(
          'ERR_STAFF_ROLE_DENIED: Managerial or Auditor role required for credit note reversal.');
    }
  }

  MobileSupplierCreditNote createCreditNote({
    required String supplierId,
    required String supplierName,
    required String vendorRef,
    String reason = 'PRICE_DIFFERENCE',
    String originType = 'INVOICE',
    String? originReference,
    DateTime? noteDate,
    double? explicitTotal,
    List<MobileSupplierCreditNoteItem>? items,
    bool autoPost = false,
  }) {
    _assertProcurementRole();

    if (supplierId.trim().isEmpty) {
      throw ArgumentError('ERR_MISSING_SUPPLIER: Supplier ID is required.');
    }

    if (vendorRef.trim().isEmpty) {
      throw ArgumentError(
          'ERR_MISSING_VENDOR_REF: Vendor credit note reference is required.');
    }

    // Check duplicate vendor reference
    for (final existing in noteStore.values) {
      if (existing.supplierId == supplierId &&
          existing.supplierCreditNoteRef.toLowerCase() ==
              vendorRef.toLowerCase()) {
        throw ArgumentError(
            'ERR_DUPLICATE_CREDIT_NOTE_REF: Vendor reference $vendorRef already recorded.');
      }
    }

    double subtotal = 0.0;
    double tax = 0.0;
    double total = 0.0;
    final validated = <MobileSupplierCreditNoteItem>[];

    if (items != null && items.isNotEmpty) {
      for (final item in items) {
        final lineSub = item.quantity > 0
            ? (item.unitCreditRate * item.quantity)
            : item.lineTotal;
        final lineTax = lineSub * (item.taxPercentage / 100.0);
        final lineTot = lineSub + lineTax;

        subtotal += lineSub;
        tax += lineTax;
        total += lineTot;

        validated.add(MobileSupplierCreditNoteItem(
          itemId: item.itemId,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitCreditRate: item.unitCreditRate,
          taxPercentage: item.taxPercentage,
          lineTotal: lineTot,
          description: item.description,
        ));
      }
    } else {
      if (explicitTotal == null || explicitTotal <= 0.0) {
        throw ArgumentError(
            'ERR_INVALID_CREDIT_AMOUNT: Positive total credit amount or items required.');
      }
      subtotal = explicitTotal;
      total = explicitTotal;
    }

    final noteId =
        'scn-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final noteNum = 'SCN-${DateTime.now().millisecondsSinceEpoch}';

    final scn = MobileSupplierCreditNote(
      noteId: noteId,
      noteNumber: noteNum,
      supplierCreditNoteRef: vendorRef,
      tenantId: tenantId,
      branchId: branchId,
      supplierId: supplierId,
      supplierName: supplierName,
      status: 'DRAFT',
      reason: reason,
      originType: originType,
      originReference: originReference ?? vendorRef,
      noteDate: noteDate ?? DateTime.now(),
      subtotalAmount: subtotal,
      taxAmount: tax,
      totalCreditAmount: total,
      createdBy: userId,
      items: validated,
    );

    noteStore[noteId] = scn;

    if (autoPost) {
      return postCreditNote(noteId);
    }

    return scn;
  }

  MobileSupplierCreditNote postCreditNote(String noteId) {
    _assertProcurementRole();

    final scn = noteStore[noteId];
    if (scn == null) {
      throw ArgumentError(
          'ERR_CREDIT_NOTE_NOT_FOUND: Credit note $noteId not found.');
    }

    if (scn.status == 'POSTED') {
      throw StateError(
          'ERR_ALREADY_POSTED: Credit note is already posted to AP.');
    }

    if (scn.status == 'CANCELLED' || scn.status == 'REVERSED') {
      throw StateError(
          'ERR_INVALID_STATUS: Cannot post credit note in status ${scn.status}');
    }

    // Find latest ledger entry chronologically
    double prevBalance = 0.0;
    final supplierEntries = ledgerStore.values
        .where((e) => e.supplierId == scn.supplierId)
        .toList()
      ..sort((a, b) => a.postedAt.compareTo(b.postedAt));

    if (supplierEntries.isNotEmpty) {
      prevBalance = supplierEntries.last.balanceAfter;
    }

    double newBalance = prevBalance - scn.totalCreditAmount;
    if (newBalance < 0.0) newBalance = 0.0;

    final postingId =
        'sup-post-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final entry = MobileSupplierLedgerEntry(
      postingId: postingId,
      supplierId: scn.supplierId,
      postingType: 'SUPPLIER_CREDIT_NOTE',
      referenceNumber: scn.supplierCreditNoteRef,
      debitAmount: scn.totalCreditAmount,
      creditAmount: 0.0,
      balanceAfter: newBalance,
      postedAt: DateTime.now(),
    );
    ledgerStore[postingId] = entry;

    scn.status = 'POSTED';
    scn.debitLedgerEntryId = postingId;
    scn.postedAt = DateTime.now();
    scn.approvedBy = userId;

    return scn;
  }

  MobileSupplierCreditNote reverseCreditNote(
      String noteId, String reversalReason) {
    _assertReversalRole();

    if (reversalReason.trim().isEmpty) {
      throw ArgumentError(
          'ERR_REVERSAL_REASON_REQUIRED: Reversal reason is mandatory for financial audit.');
    }

    final scn = noteStore[noteId];
    if (scn == null) {
      throw ArgumentError(
          'ERR_CREDIT_NOTE_NOT_FOUND: Credit note $noteId not found.');
    }

    if (scn.status == 'REVERSED') {
      throw StateError(
          'ERR_ALREADY_REVERSED: Credit note has already been reversed.');
    }

    if (scn.status != 'POSTED') {
      throw StateError(
          'ERR_CANNOT_REVERSE_UNPOSTED: Only POSTED credit notes can be reversed.');
    }

    // Find latest ledger entry chronologically
    double prevBalance = 0.0;
    final supplierEntries = ledgerStore.values
        .where((e) => e.supplierId == scn.supplierId)
        .toList()
      ..sort((a, b) => a.postedAt.compareTo(b.postedAt));

    if (supplierEntries.isNotEmpty) {
      prevBalance = supplierEntries.last.balanceAfter;
    }

    double newBalance = prevBalance + scn.totalCreditAmount;

    final revPostingId =
        'sup-rev-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final revEntry = MobileSupplierLedgerEntry(
      postingId: revPostingId,
      supplierId: scn.supplierId,
      postingType: 'CREDIT_NOTE_REVERSAL',
      referenceNumber: 'REV-${scn.noteNumber}',
      debitAmount: 0.0,
      creditAmount: scn.totalCreditAmount,
      balanceAfter: newBalance,
      postedAt: DateTime.now(),
    );
    ledgerStore[revPostingId] = revEntry;

    scn.status = 'REVERSED';
    scn.reversalLedgerEntryId = revPostingId;
    scn.reversalReason = reversalReason;
    scn.reversalPostedAt = DateTime.now();
    scn.reversedBy = userId;

    return scn;
  }

  MobileSupplierCreditNote cancelCreditNote(String noteId, String reason) {
    _assertProcurementRole();

    final scn = noteStore[noteId];
    if (scn == null) {
      throw ArgumentError(
          'ERR_CREDIT_NOTE_NOT_FOUND: Credit note $noteId not found.');
    }

    if (scn.status != 'DRAFT') {
      throw StateError(
          'ERR_CANNOT_CANCEL_POSTED_CREDIT_NOTE: Cannot cancel credit note in status ${scn.status}');
    }

    scn.status = 'CANCELLED';
    scn.notes = '${scn.notes} | Cancelled: $reason'.trim();
    return scn;
  }

  MobileSupplierCreditNote getCreditNote(String noteId) {
    final scn = noteStore[noteId];
    if (scn == null) {
      throw ArgumentError(
          'ERR_CREDIT_NOTE_NOT_FOUND: Credit note $noteId not found.');
    }
    return scn;
  }

  List<MobileSupplierCreditNote> listCreditNotes({
    String? supplierId,
    String? statusFilter,
    String? originType,
  }) {
    return noteStore.values.where((n) {
      if (supplierId != null &&
          supplierId.isNotEmpty &&
          n.supplierId != supplierId) {
        return false;
      }
      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          n.status.toUpperCase() != statusFilter.toUpperCase()) {
        return false;
      }
      if (originType != null &&
          originType.isNotEmpty &&
          n.originType.toUpperCase() != originType.toUpperCase()) {
        return false;
      }
      return true;
    }).toList();
  }
}

