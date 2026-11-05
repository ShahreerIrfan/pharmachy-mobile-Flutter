/// MobileBranchBatchOwnershipClient
/// Architecture Decision: ADR-0175 (P175).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Flutter mobile client ensuring batch inventory and POS checkouts remain
/// strictly branch-scoped, preventing cross-branch stock mixing.
library;

class MobileBranchBatch {
  final String batchId;
  final String tenantId;
  final String branchId;
  final String branchName;
  final String productId;
  final String productName;
  final String batchNumber;
  int quantityBaseUnits;
  int reservedQuantityBaseUnits;
  final DateTime expiryDate;
  final double costPerUnit;
  String status;
  bool isDispensable;

  MobileBranchBatch({
    required this.batchId,
    required this.tenantId,
    required this.branchId,
    required this.branchName,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.quantityBaseUnits,
    required this.reservedQuantityBaseUnits,
    required this.expiryDate,
    required this.costPerUnit,
    this.status = 'ACTIVE',
    this.isDispensable = true,
  });

  int get availableQuantityBaseUnits =>
      (quantityBaseUnits - reservedQuantityBaseUnits) > 0
          ? quantityBaseUnits - reservedQuantityBaseUnits
          : 0;

  Map<String, dynamic> toJson() {
    return {
      'batch_id': batchId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'branch_name': branchName,
      'product_id': productId,
      'product_name': productName,
      'batch_number': batchNumber,
      'quantity_base_units': quantityBaseUnits,
      'reserved_quantity_base_units': reservedQuantityBaseUnits,
      'available_quantity_base_units': availableQuantityBaseUnits,
      'expiry_date': expiryDate.toIso8601String().split('T').first,
      'cost_per_unit': costPerUnit.toStringAsFixed(4),
      'status': status,
      'is_dispensable': isDispensable,
    };
  }
}

class MobileDispenseItem {
  final String batchId;
  final int quantity;

  const MobileDispenseItem({
    required this.batchId,
    required this.quantity,
  });
}

class MobileBranchStockSummary {
  final String branchId;
  final String branchName;
  final int quantityOnHand;
  final int quantityReserved;
  final int quantityAvailable;
  final List<MobileBranchBatch> batches;

  const MobileBranchStockSummary({
    required this.branchId,
    required this.branchName,
    required this.quantityOnHand,
    required this.quantityReserved,
    required this.quantityAvailable,
    required this.batches,
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

  factory MobileClientResponse.ok(
    T data, {
    String messageEn = 'Success',
    String messageBn = 'সফল',
  }) {
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

class MobileBranchBatchOwnershipClient {
  final String tenantId;
  final String activeBranchId;
  final String activeBranchName;
  final String userRole;
  final String username;
  final bool isTenantSuspended;
  final Map<String, MobileBranchBatch> batchStore;

  MobileBranchBatchOwnershipClient({
    required this.tenantId,
    required this.activeBranchId,
    required this.activeBranchName,
    this.userRole = 'CASHIER',
    this.username = 'cashier1',
    this.isTenantSuspended = false,
    Map<String, MobileBranchBatch>? sharedStore,
  }) : batchStore = sharedStore ?? {};

  bool get isMultiBranchUser {
    switch (userRole.toUpperCase()) {
      case 'PHARMACY_OWNER':
      case 'SUPERADMIN':
      case 'AUDITOR':
      case 'OWNER_ADMIN':
      case 'ADMIN':
        return true;
      default:
        return false;
    }
  }

  void registerBatch(MobileBranchBatch batch) {
    batchStore[batch.batchId] = batch;
  }

  MobileClientResponse<List<MobileBranchBatch>> listBatchesForActiveTerminal({
    String? requestedBranchId,
  }) {
    if (isTenantSuspended) {
      return MobileClientResponse.failure(
        'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended.',
        messageBn: 'গ্রাহক সাবস্ক্রিপশন স্থগিত রয়েছে।',
      );
    }

    String targetBranchId = activeBranchId;
    if (requestedBranchId != null && requestedBranchId.isNotEmpty) {
      if (!isMultiBranchUser && requestedBranchId != activeBranchId) {
        return MobileClientResponse.failure(
          'ERR_CROSS_BRANCH_ACCESS',
          messageEn: 'Cross-branch access forbidden. Cashier is restricted to active terminal branch.',
          messageBn: 'অন্য ব্রাঞ্চের স্টক দেখার অনুমতি নেই। ক্যাশিয়ার কেবল নির্ধারিত ব্রাঞ্চের স্টক দেখতে পারবেন।',
        );
      }
      targetBranchId = requestedBranchId;
    }

    final results = batchStore.values
        .where((b) => b.tenantId == tenantId && b.branchId == targetBranchId)
        .toList()
      ..sort((a, b) {
        final cmp = a.expiryDate.compareTo(b.expiryDate);
        return cmp != 0 ? cmp : a.batchNumber.compareTo(b.batchNumber);
      });

    return MobileClientResponse.ok(
      results,
      messageEn: 'Batches retrieved for branch: $targetBranchId',
      messageBn: 'ব্রাঞ্চের ব্যাচ তালিকা সফলভাবে লোড হয়েছে।',
    );
  }

  MobileClientResponse<List<MobileBranchBatch>> validateDispenseCart(
    List<MobileDispenseItem> items,
  ) {
    if (isTenantSuspended) {
      return MobileClientResponse.failure(
        'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended.',
        messageBn: 'গ্রাহক সাবস্ক্রিপশন স্থগিত রয়েছে।',
      );
    }

    if (items.isEmpty) {
      return MobileClientResponse.failure(
        'ERR_EMPTY_DISPENSE_ITEMS',
        messageEn: 'Cart items list cannot be empty.',
        messageBn: 'কার্টের আইটেম তালিকা খালি হতে পারে না।',
      );
    }

    final validated = <MobileBranchBatch>[];
    for (final item in items) {
      final batch = batchStore[item.batchId];
      if (batch == null || batch.tenantId != tenantId) {
        return MobileClientResponse.failure(
          'ERR_BATCH_NOT_FOUND',
          messageEn: "Batch '${item.batchId}' not found.",
          messageBn: 'ব্যাচটি পাওয়া যায়নি।',
        );
      }

      // Cross-branch stock mixing block
      if (batch.branchId != activeBranchId) {
        return MobileClientResponse.failure(
          'ERR_CROSS_BRANCH_DISPENSE_BLOCKED',
          messageEn: "Batch '${batch.batchId}' belongs to branch '${batch.branchName}' "
              '(${batch.branchId}), not active checkout branch \'$activeBranchName\'. '
              'Cross-branch stock mixing is strictly barred.',
          messageBn: 'এই ব্যাচটি অন্য ব্রাঞ্চের অন্তর্ভুক্ত। বিক্রির সময় অন্য ব্রাঞ্চের স্টক মেশানো সম্পূর্ণ নিষিদ্ধ।',
        );
      }

      if (!batch.isDispensable) {
        return MobileClientResponse.failure(
          'ERR_BATCH_NOT_DISPENSABLE',
          messageEn: "Batch '${batch.batchId}' is not dispensable (expired, quarantined, or recalled).",
          messageBn: 'ব্যাচটি বিক্রির অনুপযুক্ত (মেয়াদোত্তীর্ণ, কোয়ারেন্টাইন বা প্রত্যাহৃত)।',
        );
      }

      if (batch.availableQuantityBaseUnits < item.quantity) {
        return MobileClientResponse.failure(
          'ERR_INSUFFICIENT_UNRESERVED_STOCK',
          messageEn: "Insufficient unreserved stock for batch '${batch.batchId}'. "
              'Available: ${batch.availableQuantityBaseUnits}, requested: ${item.quantity}',
          messageBn: 'পর্যাপ্ত অনির্ধারিত স্টক মজুদ নেই।',
        );
      }

      validated.add(batch);
    }

    return MobileClientResponse.ok(
      validated,
      messageEn: 'All items verified for branch checkout: $activeBranchName',
      messageBn: 'ব্রাঞ্চের সমস্ত আইটেম বিক্রয়ের জন্য অনুমোদিত ও যাচাইকৃত।',
    );
  }

  MobileClientResponse<List<MobileBranchStockSummary>> getMedicineMultiBranchSummary(
    String productId, {
    List<String>? authorizedBranches,
  }) {
    if (isTenantSuspended) {
      return MobileClientResponse.failure(
        'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended.',
        messageBn: 'গ্রাহক সাবস্ক্রিপশন স্থগিত রয়েছে।',
      );
    }

    if (!isMultiBranchUser) {
      return MobileClientResponse.failure(
        'ERR_PERMISSION_DENIED',
        messageEn: 'Only Pharmacy Owners or Administrators can view multi-branch inventory summaries.',
        messageBn: 'শুধুমাত্র ফার্মেসি মালিক বা অ্যাডমিন একাধিক ব্রাঞ্চের স্টক সারসংক্ষেপ দেখতে পারেন।',
      );
    }

    final branchFilter = (authorizedBranches != null && authorizedBranches.isNotEmpty)
        ? authorizedBranches
        : [activeBranchId];

    final summaries = <MobileBranchStockSummary>[];
    for (final brId in branchFilter) {
      final brBatches = batchStore.values
          .where((b) => b.tenantId == tenantId && b.branchId == brId && b.productId == productId)
          .toList();

      final onHand = brBatches.fold<int>(0, (sum, b) => sum + b.quantityBaseUnits);
      final reserved = brBatches.fold<int>(0, (sum, b) => sum + b.reservedQuantityBaseUnits);
      final brName = brBatches.isNotEmpty ? brBatches.first.branchName : brId;

      summaries.add(
        MobileBranchStockSummary(
          branchId: brId,
          branchName: brName,
          quantityOnHand: onHand,
          quantityReserved: reserved,
          quantityAvailable: (onHand - reserved) > 0 ? onHand - reserved : 0,
          batches: brBatches,
        ),
      );
    }

    return MobileClientResponse.ok(
      summaries,
      messageEn: 'Multi-branch segregated summary generated.',
      messageBn: 'প্রতিটি ব্রাঞ্চের স্টক সারসংক্ষেপ সফলভাবে তৈরি হয়েছে।',
    );
  }
}
