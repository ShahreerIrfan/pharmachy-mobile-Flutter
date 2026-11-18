// mobile_payment_status_reconciliation_client.dart
// Architecture Decision: ADR-0276 (P276).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'dart:convert';

class PaymentStatusPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PaymentStatusPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PaymentStatusValidationException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PaymentStatusValidationException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PaymentStatusNotFoundException implements Exception {
  final String errorCode;
  final String message;

  PaymentStatusNotFoundException({
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() => '$errorCode: $message';
}

enum MobilePaymentLifecycleStatus {
  pending,
  confirmed,
  failed,
  refunded,
  reversed;

  String toApiValue() => name.toUpperCase();

  static MobilePaymentLifecycleStatus fromApiValue(String val) {
    switch (val.toUpperCase()) {
      case 'CONFIRMED':
        return MobilePaymentLifecycleStatus.confirmed;
      case 'FAILED':
        return MobilePaymentLifecycleStatus.failed;
      case 'REFUNDED':
        return MobilePaymentLifecycleStatus.refunded;
      case 'REVERSED':
        return MobilePaymentLifecycleStatus.reversed;
      case 'PENDING':
      default:
        return MobilePaymentLifecycleStatus.pending;
    }
  }
}

class MobilePaymentStatusRecordDto {
  final String recordId;
  final String tenantId;
  final String? branchId;
  final String branchName;
  final String? paymentMethodConfigId;
  final String? financialAccountId;
  final String tenderType;
  final double amountBdt;
  final double surchargeBdt;
  final double totalCollectedBdt;
  MobilePaymentLifecycleStatus status;
  String providerName;
  String providerReference;
  Map<String, dynamic> providerEvidenceJson;
  String evidenceHash;
  DateTime? verifiedAt;
  String? verifiedById;
  String failureCode;
  String failureReason;
  double refundAmountBdt;
  String refundReference;
  String refundReason;
  DateTime? refundedAt;
  String reversalReason;
  DateTime? reversedAt;
  bool isReconciled;
  DateTime? reconciledAt;
  String reconciliationBatchId;
  String idempotencyKey;
  String notes;
  final DateTime createdAt;
  DateTime updatedAt;

  MobilePaymentStatusRecordDto({
    required this.recordId,
    required this.tenantId,
    this.branchId,
    this.branchName = 'Branch',
    this.paymentMethodConfigId,
    this.financialAccountId,
    required this.tenderType,
    required this.amountBdt,
    this.surchargeBdt = 0.0,
    required this.totalCollectedBdt,
    this.status = MobilePaymentLifecycleStatus.pending,
    this.providerName = '',
    this.providerReference = '',
    this.providerEvidenceJson = const {},
    this.evidenceHash = '',
    this.verifiedAt,
    this.verifiedById,
    this.failureCode = '',
    this.failureReason = '',
    this.refundAmountBdt = 0.0,
    this.refundReference = '',
    this.refundReason = '',
    this.refundedAt,
    this.reversalReason = '',
    this.reversedAt,
    this.isReconciled = false,
    this.reconciledAt,
    this.reconciliationBatchId = '',
    this.idempotencyKey = '',
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'record_id': recordId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'branch_name': branchName,
        'payment_method_config_id': paymentMethodConfigId,
        'financial_account_id': financialAccountId,
        'tender_type': tenderType,
        'amount_bdt': amountBdt.toStringAsFixed(4),
        'surcharge_bdt': surchargeBdt.toStringAsFixed(4),
        'total_collected_bdt': totalCollectedBdt.toStringAsFixed(4),
        'status': status.toApiValue(),
        'provider_name': providerName,
        'provider_reference': providerReference,
        'provider_evidence_json': providerEvidenceJson,
        'evidence_hash': evidenceHash,
        'verified_at': verifiedAt?.toIso8601String(),
        'verified_by_id': verifiedById,
        'failure_code': failureCode,
        'failure_reason': failureReason,
        'refund_amount_bdt': refundAmountBdt.toStringAsFixed(4),
        'refund_reference': refundReference,
        'refund_reason': refundReason,
        'refunded_at': refundedAt?.toIso8601String(),
        'reversal_reason': reversalReason,
        'reversed_at': reversedAt?.toIso8601String(),
        'is_reconciled': isReconciled,
        'reconciled_at': reconciledAt?.toIso8601String(),
        'reconciliation_batch_id': reconciliationBatchId,
        'idempotency_key': idempotencyKey,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MobilePaymentStatusRecordDto.fromJson(Map<String, dynamic> json) {
    return MobilePaymentStatusRecordDto(
      recordId: json['record_id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String?,
      branchName: (json['branch_name'] as String?) ?? 'Branch',
      paymentMethodConfigId: json['payment_method_config_id'] as String?,
      financialAccountId: json['financial_account_id'] as String?,
      tenderType: (json['tender_type'] as String?) ?? 'CASH',
      amountBdt: double.tryParse(json['amount_bdt']?.toString() ?? '0') ?? 0.0,
      surchargeBdt: double.tryParse(json['surcharge_bdt']?.toString() ?? '0') ?? 0.0,
      totalCollectedBdt: double.tryParse(json['total_collected_bdt']?.toString() ?? '0') ?? 0.0,
      status: MobilePaymentLifecycleStatus.fromApiValue(json['status']?.toString() ?? 'PENDING'),
      providerName: (json['provider_name'] as String?) ?? '',
      providerReference: (json['provider_reference'] as String?) ?? '',
      providerEvidenceJson: (json['provider_evidence_json'] as Map<String, dynamic>?) ?? {},
      evidenceHash: (json['evidence_hash'] as String?) ?? '',
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'].toString()) : null,
      verifiedById: json['verified_by_id'] as String?,
      failureCode: (json['failure_code'] as String?) ?? '',
      failureReason: (json['failure_reason'] as String?) ?? '',
      refundAmountBdt: double.tryParse(json['refund_amount_bdt']?.toString() ?? '0') ?? 0.0,
      refundReference: (json['refund_reference'] as String?) ?? '',
      refundReason: (json['refund_reason'] as String?) ?? '',
      refundedAt: json['refunded_at'] != null ? DateTime.tryParse(json['refunded_at'].toString()) : null,
      reversalReason: (json['reversal_reason'] as String?) ?? '',
      reversedAt: json['reversed_at'] != null ? DateTime.tryParse(json['reversed_at'].toString()) : null,
      isReconciled: json['is_reconciled'] == true,
      reconciledAt: json['reconciled_at'] != null ? DateTime.tryParse(json['reconciled_at'].toString()) : null,
      reconciliationBatchId: (json['reconciliation_batch_id'] as String?) ?? '',
      idempotencyKey: (json['idempotency_key'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

class MobilePaymentStatusReconciliationClient {
  final String tenantId;
  final String? branchId;
  final String userRole;
  final String userId;

  final Map<String, MobilePaymentStatusRecordDto> _recordStore = {};

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

  MobilePaymentStatusReconciliationClient({
    required this.tenantId,
    this.branchId,
    required String userRole,
    required this.userId,
  }) : userRole = userRole.toUpperCase();

  bool get canView => viewRoles.contains(userRole);
  bool get canManage => manageRoles.contains(userRole);

  void _assertCanView() {
    if (!canView) {
      throw PaymentStatusPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Staff role is not permitted to view payment records.',
        messageBn: 'পেমেন্ট রেকর্ড দেখার অনুমতি নেই।',
      );
    }
  }

  void _assertCanManage() {
    if (!canManage) {
      throw PaymentStatusPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to perform refunds or reversals.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট রিফান্ড বা রিভার্সাল সম্পন্ন করার অনুমতিপ্রাপ্ত নন।',
      );
    }
  }

  String _computeEvidenceSignature(String recordId, String providerRef, double amount, Map<String, dynamic> evidence) {
    final raw = '$recordId|$tenantId|$providerRef|${amount.toStringAsFixed(4)}|${jsonEncode(evidence)}';
    final bytes = utf8.encode(raw);
    int hash = 5381;
    for (var b in bytes) {
      hash = ((hash << 5) + hash) + b;
    }
    return 'SIG-${hash.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  MobilePaymentStatusRecordDto initiatePayment({
    required double amountBdt,
    double surchargeBdt = 0.0,
    required String tenderType,
    String? paymentMethodConfigId,
    String? financialAccountId,
    String providerName = '',
    String idempotencyKey = '',
    String notes = '',
  }) {
    _assertCanView();

    if (amountBdt <= 0) {
      throw PaymentStatusValidationException(
        errorCode: 'ERR_INVALID_PAYMENT_AMOUNT',
        messageEn: 'Payment amount must be greater than zero.',
        messageBn: 'পেমেন্ট পরিমাণ অবশ্যই শূন্যের চেয়ে বেশি হতে হবে।',
      );
    }

    if (idempotencyKey.isNotEmpty) {
      for (final existing in _recordStore.values) {
        if (existing.idempotencyKey == idempotencyKey) {
          return existing;
        }
      }
    }

    final total = amountBdt + surchargeBdt;
    final recordId = 'PAY-${DateTime.now().millisecondsSinceEpoch}-${_recordStore.length + 1}';

    final dto = MobilePaymentStatusRecordDto(
      recordId: recordId,
      tenantId: tenantId,
      branchId: branchId,
      paymentMethodConfigId: paymentMethodConfigId,
      financialAccountId: financialAccountId,
      tenderType: tenderType.toUpperCase(),
      amountBdt: amountBdt,
      surchargeBdt: surchargeBdt,
      totalCollectedBdt: total,
      status: MobilePaymentLifecycleStatus.pending,
      providerName: providerName.isNotEmpty ? providerName : tenderType,
      idempotencyKey: idempotencyKey,
      notes: notes,
    );

    _recordStore[recordId] = dto;
    return dto;
  }

  MobilePaymentStatusRecordDto confirmPayment({
    required String recordId,
    String providerName = '',
    required String providerReference,
    Map<String, dynamic> providerEvidence = const {},
  }) {
    _assertCanView();

    final record = _recordStore[recordId];
    if (record == null) {
      throw PaymentStatusNotFoundException(
        errorCode: 'ERR_PAYMENT_RECORD_NOT_FOUND',
        message: 'Payment record $recordId not found.',
      );
    }

    if (record.status == MobilePaymentLifecycleStatus.confirmed) {
      if (providerReference.isNotEmpty && record.providerReference == providerReference) {
        return record;
      }
    }

    if (record.status != MobilePaymentLifecycleStatus.pending) {
      throw PaymentStatusValidationException(
        errorCode: 'ERR_INVALID_PAYMENT_STATE_TRANSITION',
        messageEn: 'Cannot confirm payment from status ${record.status.toApiValue()}. Must be PENDING.',
        messageBn: 'পেমেন্টটি PENDING অবস্থায় নেই।',
      );
    }

    if (providerReference.trim().isEmpty && record.tenderType != 'CASH') {
      throw PaymentStatusValidationException(
        errorCode: 'ERR_MISSING_PROVIDER_REFERENCE',
        messageEn: 'Provider transaction reference is mandatory.',
        messageBn: 'লেনদেন নিশ্চিতকরণের জন্য প্রোভাইডার রেফারেন্স নম্বর আবশ্যক।',
      );
    }

    final pRef = providerReference.trim().isNotEmpty ? providerReference.trim() : 'CASH-REF';
    final sig = _computeEvidenceSignature(record.recordId, pRef, record.amountBdt, providerEvidence);

    record.status = MobilePaymentLifecycleStatus.confirmed;
    if (providerName.isNotEmpty) record.providerName = providerName;
    record.providerReference = pRef;
    record.providerEvidenceJson = providerEvidence;
    record.evidenceHash = sig;
    record.verifiedAt = DateTime.now();
    record.verifiedById = userId;
    record.updatedAt = DateTime.now();

    return record;
  }

  MobilePaymentStatusRecordDto failPayment({
    required String recordId,
    String failureCode = 'GATEWAY_REJECTED',
    String failureReason = 'Provider rejected or timeout',
  }) {
    _assertCanView();

    final record = _recordStore[recordId];
    if (record == null) {
      throw PaymentStatusNotFoundException(
        errorCode: 'ERR_PAYMENT_RECORD_NOT_FOUND',
        message: 'Payment record $recordId not found.',
      );
    }

    if (record.status != MobilePaymentLifecycleStatus.pending) {
      throw PaymentStatusValidationException(
        errorCode: 'ERR_INVALID_PAYMENT_STATE_TRANSITION',
        messageEn: 'Cannot fail payment in status ${record.status.toApiValue()}.',
        messageBn: 'শুধুমাত্র PENDING পেমেন্ট বাতিল বা ফেইল করা যায়।',
      );
    }

    record.status = MobilePaymentLifecycleStatus.failed;
    record.failureCode = failureCode;
    record.failureReason = failureReason;
    record.updatedAt = DateTime.now();

    return record;
  }

  MobilePaymentStatusRecordDto refundPayment({
    required String recordId,
    double? refundAmountBdt,
    String refundReference = '',
    String refundReason = '',
  }) {
    _assertCanManage();

    final record = _recordStore[recordId];
    if (record == null) {
      throw PaymentStatusNotFoundException(
        errorCode: 'ERR_PAYMENT_RECORD_NOT_FOUND',
        message: 'Payment record $recordId not found.',
      );
    }

    if (record.status != MobilePaymentLifecycleStatus.confirmed) {
      throw PaymentStatusValidationException(
        errorCode: 'ERR_INVALID_PAYMENT_STATE_TRANSITION',
        messageEn: 'Cannot refund payment in status ${record.status.toApiValue()}. Must be CONFIRMED.',
        messageBn: 'শুধুমাত্র নিশ্চিত (CONFIRMED) পেমেন্ট রিফান্ড করা সম্ভব।',
      );
    }

    final refAmt = refundAmountBdt ?? record.totalCollectedBdt;
    if (refAmt <= 0 || refAmt > record.totalCollectedBdt) {
      throw PaymentStatusValidationException(
        errorCode: 'ERR_INVALID_REFUND_AMOUNT',
        messageEn: 'Refund amount must be > 0 and <= ${record.totalCollectedBdt}.',
        messageBn: 'রিফান্ডের পরিমাণ অবশ্যই মোট সংগ্রহের মধ্যে হতে হবে।',
      );
    }

    record.status = MobilePaymentLifecycleStatus.refunded;
    record.refundAmountBdt = refAmt;
    record.refundReference = refundReference;
    record.refundReason = refundReason.isNotEmpty ? refundReason : 'Medicine return';
    record.refundedAt = DateTime.now();
    record.updatedAt = DateTime.now();

    return record;
  }

  MobilePaymentStatusRecordDto reversePayment({
    required String recordId,
    required String reversalReason,
  }) {
    _assertCanManage();

    final record = _recordStore[recordId];
    if (record == null) {
      throw PaymentStatusNotFoundException(
        errorCode: 'ERR_PAYMENT_RECORD_NOT_FOUND',
        message: 'Payment record $recordId not found.',
      );
    }

    if (record.status != MobilePaymentLifecycleStatus.confirmed) {
      throw PaymentStatusValidationException(
        errorCode: 'ERR_INVALID_PAYMENT_STATE_TRANSITION',
        messageEn: 'Cannot reverse payment in status ${record.status.toApiValue()}. Must be CONFIRMED.',
        messageBn: 'শুধুমাত্র CONFIRMED পেমেন্ট রিভার্স করা যায়।',
      );
    }

    if (reversalReason.trim().isEmpty) {
      throw PaymentStatusValidationException(
        errorCode: 'ERR_MISSING_REVERSAL_REASON',
        messageEn: 'Mandatory explanation reason is required for reversal.',
        messageBn: 'পেমেন্ট রিভার্সাল সম্পন্ন করার জন্য সুনির্দিষ্ট কারণ আবশ্যক।',
      );
    }

    record.status = MobilePaymentLifecycleStatus.reversed;
    record.reversalReason = reversalReason.trim();
    record.reversedAt = DateTime.now();
    record.updatedAt = DateTime.now();

    return record;
  }

  MobilePaymentStatusRecordDto reconcilePayment({
    required String recordId,
    String? reconciliationBatchId,
  }) {
    _assertCanManage();

    final record = _recordStore[recordId];
    if (record == null) {
      throw PaymentStatusNotFoundException(
        errorCode: 'ERR_PAYMENT_RECORD_NOT_FOUND',
        message: 'Payment record $recordId not found.',
      );
    }

    if (record.status != MobilePaymentLifecycleStatus.confirmed &&
        record.status != MobilePaymentLifecycleStatus.refunded &&
        record.status != MobilePaymentLifecycleStatus.reversed) {
      throw PaymentStatusValidationException(
        errorCode: 'ERR_UNSETTLED_PAYMENT_RECONCILIATION_BLOCKED',
        messageEn: 'Cannot reconcile payment in status ${record.status.toApiValue()}.',
        messageBn: 'অনিষ্পন্ন পেমেন্ট রিকনসাইল করা সম্ভব নয়।',
      );
    }

    final batch = reconciliationBatchId ?? 'REC-${DateTime.now().millisecondsSinceEpoch}';

    record.isReconciled = true;
    record.reconciledAt = DateTime.now();
    record.reconciliationBatchId = batch;
    record.updatedAt = DateTime.now();

    return record;
  }

  List<MobilePaymentStatusRecordDto> listPayments({
    MobilePaymentLifecycleStatus? statusFilter,
    bool? isReconciledFilter,
  }) {
    _assertCanView();

    return _recordStore.values.where((r) {
      if (statusFilter != null && r.status != statusFilter) return false;
      if (isReconciledFilter != null && r.isReconciled != isReconciledFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  MobilePaymentStatusRecordDto getPayment(String recordId) {
    _assertCanView();

    final record = _recordStore[recordId];
    if (record == null) {
      throw PaymentStatusNotFoundException(
        errorCode: 'ERR_PAYMENT_RECORD_NOT_FOUND',
        message: 'Payment record $recordId not found.',
      );
    }
    return record;
  }
}
