/// MobileStockAvailabilityClient
/// Architecture Decision: ADR-0171 (P171).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Flutter mobile owner/manager client for multi-tier branch stock availability,
/// real-time cart pre-checks, and packaging unit breakdowns.
library;

import 'dart:math';

class MobileStockAvailabilityRecord {
  final String availabilityId;
  final String tenantId;
  final String branchId;
  final String productId;
  final String productName;
  final String genericName;
  final String baseUnit;
  final int quantityOnHand;
  final int quantityReserved;
  final int quantityQuarantined;
  final int quantityPendingInward;
  final int quantityPhysicallyAvailable;
  final int quantityServerConfirmedAvailable;
  final int reorderLevelBaseUnits;
  final bool isOutOfStock;
  final bool isBelowReorderLevel;
  final String packagingSummary;
  final int version;
  final DateTime? lastRecalculatedAt;

  MobileStockAvailabilityRecord({
    required this.availabilityId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    this.productName = '',
    this.genericName = '',
    this.baseUnit = 'PIECE',
    required this.quantityOnHand,
    this.quantityReserved = 0,
    this.quantityQuarantined = 0,
    this.quantityPendingInward = 0,
    this.reorderLevelBaseUnits = 0,
    this.packagingSummary = '',
    this.version = 1,
    this.lastRecalculatedAt,
  })  : quantityPhysicallyAvailable = max(0, quantityOnHand - quantityQuarantined),
        quantityServerConfirmedAvailable = max(0, max(0, quantityOnHand - quantityQuarantined) - quantityReserved),
        isOutOfStock = max(0, max(0, quantityOnHand - quantityQuarantined) - quantityReserved) == 0,
        isBelowReorderLevel = reorderLevelBaseUnits > 0 &&
            max(0, max(0, quantityOnHand - quantityQuarantined) - quantityReserved) <= reorderLevelBaseUnits;

  factory MobileStockAvailabilityRecord.fromJson(Map<String, dynamic> json) {
    return MobileStockAvailabilityRecord(
      availabilityId: json['availability_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      genericName: json['generic_name'] as String? ?? '',
      baseUnit: json['base_unit'] as String? ?? 'PIECE',
      quantityOnHand: (json['quantity_on_hand'] as num?)?.toInt() ?? 0,
      quantityReserved: (json['quantity_reserved'] as num?)?.toInt() ?? 0,
      quantityQuarantined: (json['quantity_quarantined'] as num?)?.toInt() ?? 0,
      quantityPendingInward: (json['quantity_pending_inward'] as num?)?.toInt() ?? 0,
      reorderLevelBaseUnits: (json['reorder_level_base_units'] as num?)?.toInt() ?? 0,
      packagingSummary: json['packaging_summary'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      lastRecalculatedAt: json['last_recalculated_at'] != null
          ? DateTime.tryParse(json['last_recalculated_at'] as String)
          : null,
    );
  }
}

class MobilePrecheckItemRequest {
  final String productId;
  final int requestedQuantityBaseUnits;

  MobilePrecheckItemRequest({
    required this.productId,
    required this.requestedQuantityBaseUnits,
  });
}

class MobilePrecheckItemResult {
  final String productId;
  final int requestedQuantity;
  final int serverConfirmedAvailable;
  final int shortageUnits;
  final bool isAvailable;
  final String packagingSummary;

  MobilePrecheckItemResult({
    required this.productId,
    required this.requestedQuantity,
    required this.serverConfirmedAvailable,
    required this.shortageUnits,
    required this.isAvailable,
    this.packagingSummary = '',
  });
}

class MobilePrecheckBatchResult {
  final bool allItemsAvailable;
  final List<MobilePrecheckItemResult> items;

  MobilePrecheckBatchResult({
    required this.allItemsAvailable,
    required this.items,
  });
}

class MobileClientResponse<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  MobileClientResponse._({
    required this.success,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileClientResponse.ok(T data, {String messageEn = 'Success', String messageBn = 'সফল'}) {
    return MobileClientResponse._(
      success: true,
      data: data,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }

  factory MobileClientResponse.failure(
    String errorCode, {
    String messageEn = 'An error occurred.',
    String messageBn = 'একটি ত্রুটি ঘটেছে।',
  }) {
    return MobileClientResponse._(
      success: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }
}

class MobileStockAvailabilityClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final bool isTenantSuspended;
  final Map<String, MobileStockAvailabilityRecord> _localCache = {};

  MobileStockAvailabilityClient({
    required this.tenantId,
    required this.branchId,
    this.userRole = 'BRANCH_MANAGER',
    this.isTenantSuspended = false,
  });

  bool get _isAuthorized {
    switch (userRole.toUpperCase()) {
      case 'CASHIER':
      case 'STAFF_PHARMACIST':
      case 'BRANCH_MANAGER':
      case 'PHARMACY_OWNER':
      case 'INVENTORY_CLERK':
      case 'AUDITOR':
      case 'SUPERADMIN':
        return true;
      default:
        return false;
    }
  }

  static String formatPackaging({
    required String baseUnit,
    String packLabel = 'BOX',
    String interLabel = 'STRIP',
    int packToInter = 10,
    int interToBase = 10,
    required int totalBaseUnits,
  }) {
    if (totalBaseUnits <= 0) {
      return '0 $baseUnit';
    }
    final pToI = max(1, packToInter);
    final iToB = max(1, interToBase);
    final basePerPack = pToI * iToB;

    final packs = totalBaseUnits ~/ basePerPack;
    final rem = totalBaseUnits % basePerPack;
    final inters = rem ~/ iToB;
    final loose = rem % iToB;

    final parts = <String>[];
    if (packs > 0) {
      parts.add('$packs $packLabel${packs > 1 ? "es" : ""}');
    }
    if (inters > 0) {
      parts.add('$inters $interLabel${inters > 1 ? "s" : ""}');
    }
    if (loose > 0 || parts.isEmpty) {
      parts.add('$loose $baseUnit${loose > 1 ? "s" : ""}');
    }
    return parts.join(', ');
  }

  void putRecord(MobileStockAvailabilityRecord record) {
    _localCache[record.productId] = record;
  }

  MobileClientResponse<MobileStockAvailabilityRecord> getAvailability(String productId) {
    if (isTenantSuspended) {
      return MobileClientResponse.failure(
        'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended.',
        messageBn: 'গ্রাহক সাবস্ক্রিপশন স্থগিত রয়েছে।',
      );
    }
    if (!_isAuthorized) {
      return MobileClientResponse.failure(
        'ERR_ROLE_UNAUTHORIZED',
        messageEn: 'Role is not authorized to access inventory availability.',
        messageBn: 'এই রোল ইনভেন্টরি স্টক দেখার জন্য অননুমোদিত।',
      );
    }
    if (productId.trim().isEmpty) {
      return MobileClientResponse.failure(
        'ERR_MISSING_PRODUCT',
        messageEn: 'Product ID is required.',
        messageBn: 'প্রোডাক্ট আইডি প্রয়োজন।',
      );
    }

    final record = _localCache[productId];
    if (record == null) {
      return MobileClientResponse.failure(
        'ERR_PRODUCT_NOT_FOUND',
        messageEn: 'Product availability not found.',
        messageBn: 'পণ্যটির কোনো স্টক রেকর্ড পাওয়া যায়নি।',
      );
    }

    return MobileClientResponse.ok(
      record,
      messageEn: 'Availability retrieved.',
      messageBn: 'স্টক তথ্য সফলভাবে লোড হয়েছে।',
    );
  }

  MobileClientResponse<MobilePrecheckBatchResult> precheckCheckout(List<MobilePrecheckItemRequest> items) {
    if (isTenantSuspended) {
      return MobileClientResponse.failure(
        'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended.',
        messageBn: 'গ্রাহক সাবস্ক্রিপশন স্থগিত রয়েছে।',
      );
    }
    if (!_isAuthorized) {
      return MobileClientResponse.failure(
        'ERR_ROLE_UNAUTHORIZED',
        messageEn: 'Role is not authorized for checkout precheck.',
        messageBn: 'চেকআউট প্রি-চেক করার অনুমতি নেই।',
      );
    }
    if (items.isEmpty) {
      return MobileClientResponse.failure(
        'ERR_EMPTY_ITEMS',
        messageEn: 'Items list cannot be empty.',
        messageBn: 'পণ্যের তালিকা ফাঁকা হতে পারে না।',
      );
    }

    bool allAvailable = true;
    final results = <MobilePrecheckItemResult>[];

    for (final item in items) {
      if (item.requestedQuantityBaseUnits <= 0) {
        return MobileClientResponse.failure(
          'ERR_INVALID_QUANTITY',
          messageEn: 'Requested quantity must be greater than zero.',
          messageBn: 'অনুরোধকৃত পরিমাণ শূন্যের বেশি হতে হবে।',
        );
      }
      final record = _localCache[item.productId];
      final confirmed = record?.quantityServerConfirmedAvailable ?? 0;
      final isAvail = confirmed >= item.requestedQuantityBaseUnits;
      final shortage = max(0, item.requestedQuantityBaseUnits - confirmed);
      if (!isAvail) {
        allAvailable = false;
      }
      results.add(MobilePrecheckItemResult(
        productId: item.productId,
        requestedQuantity: item.requestedQuantityBaseUnits,
        serverConfirmedAvailable: confirmed,
        shortageUnits: shortage,
        isAvailable: isAvail,
        packagingSummary: record?.packagingSummary ?? '',
      ));
    }

    return MobileClientResponse.ok(
      MobilePrecheckBatchResult(
        allItemsAvailable: allAvailable,
        items: results,
      ),
      messageEn: 'Precheck completed successfully.',
      messageBn: 'চেকআউট প্রি-চেক সফলভাবে সম্পন্ন হয়েছে।',
    );
  }
}

