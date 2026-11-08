// mobile_purchase_document_client.dart
// Architecture Decision: ADR-0198 (P198).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client for Purchase Document Generation:
// - Generates versioned PO, GRN, Return, and Statement documents.
// - Computes immutable SHA-256 cryptographic hashes for tamper verification.
// - Enforces role-based permissions and version history tracking.

import 'dart:convert';
import 'package:crypto/crypto.dart';

class MobileDocumentLineItem {
  final String itemId;
  final String productName;
  final String batchOrReference;
  final int quantity;
  final double unitCost;
  final double lineTotal;

  MobileDocumentLineItem({
    required this.itemId,
    required this.productName,
    this.batchOrReference = '',
    this.quantity = 1,
    this.unitCost = 0.0,
    this.lineTotal = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'product_name': productName,
        'batch_or_reference': batchOrReference,
        'quantity': quantity,
        'unit_cost': unitCost,
        'line_total': lineTotal,
      };

  factory MobileDocumentLineItem.fromJson(Map<String, dynamic> json) {
    return MobileDocumentLineItem(
      itemId: json['item_id'] ?? '',
      productName: json['product_name'] ?? '',
      batchOrReference: json['batch_or_reference'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MobilePurchaseDocument {
  final String documentId;
  final String documentNumber;
  final String documentType;
  final int version;
  bool isLatest;
  final String sourceId;
  final String sourceReference;
  final String supplierId;
  final String supplierName;
  final String format;
  final double totalAmount;
  final String currency;
  final List<MobileDocumentLineItem> lineItems;
  final String immutableVerificationHash;
  String status;
  final String notes;
  final String generatedBy;
  final DateTime generatedAt;

  MobilePurchaseDocument({
    required this.documentId,
    required this.documentNumber,
    required this.documentType,
    required this.version,
    required this.isLatest,
    required this.sourceId,
    required this.sourceReference,
    this.supplierId = '',
    this.supplierName = '',
    this.format = 'A4_PDF',
    this.totalAmount = 0.0,
    this.currency = 'BDT',
    this.lineItems = const [],
    required this.immutableVerificationHash,
    this.status = 'FINAL',
    this.notes = '',
    required this.generatedBy,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'document_id': documentId,
        'document_number': documentNumber,
        'document_type': documentType,
        'version': version,
        'is_latest': isLatest,
        'source_id': sourceId,
        'source_reference': sourceReference,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'format': format,
        'total_amount': totalAmount,
        'currency': currency,
        'line_items': lineItems.map((e) => e.toJson()).toList(),
        'immutable_verification_hash': immutableVerificationHash,
        'status': status,
        'notes': notes,
        'generated_by': generatedBy,
        'generated_at': generatedAt.toIso8601String(),
      };
}

class MobilePurchaseDocumentClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobilePurchaseDocument> documentStore;

  static const Set<String> _allowedRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
    'AUDITOR',
  };

  MobilePurchaseDocumentClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobilePurchaseDocument>? documentStore,
  }) : documentStore = documentStore ?? {};

  void _assertRolePermission() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedRoles.contains(userRole.toUpperCase())) {
      throw Exception(
          'ERR_STAFF_ROLE_DENIED: Staff role $userRole cannot generate purchase documents.');
    }
  }

  static String computeVerificationHash({
    required String documentId,
    required String tenantId,
    required String docType,
    required String sourceId,
    required int version,
    required double totalAmount,
    required int lineItemCount,
  }) {
    final raw =
        '$documentId|$tenantId|$docType|$sourceId|$version|${totalAmount.toStringAsFixed(4)}|$lineItemCount';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  MobilePurchaseDocument generateDocument({
    required String documentType,
    required String sourceId,
    String? sourceReference,
    String supplierId = '',
    String supplierName = '',
    double totalAmount = 0.0,
    List<MobileDocumentLineItem> lineItems = const [],
    String notes = '',
    String format = 'A4_PDF',
  }) {
    _assertRolePermission();

    final docTypeUpper = documentType.toUpperCase();

    // 1. Check existing versions
    int latestVersion = 0;
    for (final existing in documentStore.values) {
      if (existing.documentType == docTypeUpper &&
          existing.sourceId.toLowerCase() == sourceId.toLowerCase()) {
        if (existing.version > latestVersion) {
          latestVersion = existing.version;
        }
        if (existing.isLatest) {
          existing.isLatest = false;
          existing.status = 'SUPERSEDED';
        }
      }
    }

    final nextVersion = latestVersion + 1;
    final docId =
        'pdoc-${documentStore.length + 1}-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';

    String prefix = 'DOC-PUR';
    if (docTypeUpper == 'PURCHASE_ORDER') prefix = 'DOC-PO';
    if (docTypeUpper == 'GOODS_RECEIPT_NOTE') prefix = 'DOC-GRN';
    if (docTypeUpper == 'PURCHASE_RETURN') prefix = 'DOC-RET';
    if (docTypeUpper == 'SUPPLIER_STATEMENT') prefix = 'DOC-STMT';

    final docNum =
        '$prefix-${documentStore.length + 1}-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final hash = computeVerificationHash(
      documentId: docId,
      tenantId: tenantId,
      docType: docTypeUpper,
      sourceId: sourceId,
      version: nextVersion,
      totalAmount: totalAmount,
      lineItemCount: lineItems.length,
    );

    final doc = MobilePurchaseDocument(
      documentId: docId,
      documentNumber: docNum,
      documentType: docTypeUpper,
      version: nextVersion,
      isLatest: true,
      sourceId: sourceId,
      sourceReference: sourceReference ?? sourceId,
      supplierId: supplierId,
      supplierName: supplierName,
      format: format,
      totalAmount: totalAmount,
      currency: 'BDT',
      lineItems: lineItems,
      immutableVerificationHash: hash,
      status: 'FINAL',
      notes: notes,
      generatedBy: userId,
      generatedAt: now,
    );

    documentStore[docId] = doc;
    return doc;
  }

  MobilePurchaseDocument getDocument(String documentId) {
    final doc = documentStore[documentId];
    if (doc == null) {
      throw Exception('ERR_DOCUMENT_NOT_FOUND: Document $documentId not found.');
    }
    return doc;
  }

  List<MobilePurchaseDocument> listDocuments({
    String? filterType,
    String? filterSourceId,
    bool onlyLatest = true,
  }) {
    final list = <MobilePurchaseDocument>[];
    for (final doc in documentStore.values) {
      if (filterType != null &&
          filterType.isNotEmpty &&
          doc.documentType != filterType.toUpperCase()) {
        continue;
      }
      if (filterSourceId != null &&
          filterSourceId.isNotEmpty &&
          doc.sourceId.toLowerCase() != filterSourceId.toLowerCase()) {
        continue;
      }
      if (onlyLatest && !doc.isLatest) {
        continue;
      }
      list.add(doc);
    }
    list.sort((a, b) => b.version.compareTo(a.version));
    return list;
  }

  bool verifyDocumentIntegrity(String documentId) {
    final doc = getDocument(documentId);
    final recomputed = computeVerificationHash(
      documentId: doc.documentId,
      tenantId: tenantId,
      docType: doc.documentType,
      sourceId: doc.sourceId,
      version: doc.version,
      totalAmount: doc.totalAmount,
      lineItemCount: doc.lineItems.length,
    );
    return recomputed == doc.immutableVerificationHash;
  }
}

