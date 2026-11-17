// mobile_pos_domain_client.dart
// Architecture Decision: ADR-0221 (P221).
// Phase 12: POS, Sales Orders, Checkout & Returns.
//
// Flutter Mobile Client wired to /api/v2/pos/*:
// - Typed models for PosCustomer, PosSaleOrder, PosSaleLine, PosSaleAllocation, PosPaymentAttempt.
// - Strict role, branch, tenant & subscription guards + explicit UI states (loading, ready, empty,
//   error, offline, permissionDenied) and EN/BN bilingual messages.

import 'package:dio/dio.dart';

enum MobilePosUiState {
  loading('Loading POS orders...', 'পিওএস অর্ডার লোড হচ্ছে...'),
  ready('POS orders loaded.', 'পিওএস অর্ডার লোড হয়েছে।'),
  empty('No POS orders found.', 'কোনো পিওএস অর্ডার পাওয়া যায়নি।'),
  error('POS operation error.', 'পিওএস অপারেশনে ত্রুটি হয়েছে।'),
  offline('Offline mode: POS cloud endpoint unreachable.', 'অফলাইন মোড: ক্লাউড পিওএস সার্ভারে সংযোগ নেই।'),
  permissionDenied('Permission denied for POS action.', 'এই পিওএস কাজ করার অনুমতি নেই।');

  final String messageEn;
  final String messageBn;

  const MobilePosUiState(this.messageEn, this.messageBn);
}

enum MobilePosLifecycleState {
  draft('DRAFT'),
  held('HELD'),
  pendingRxReview('PENDING_RX_REVIEW'),
  confirmed('CONFIRMED'),
  partiallyPaid('PARTIALLY_PAID'),
  finalized('FINALIZED'),
  partiallyReturned('PARTIALLY_RETURNED'),
  fullyReturned('FULLY_RETURNED'),
  voided('VOIDED'),
  reversed('REVERSED'),
  offlinePendingSync('OFFLINE_PENDING_SYNC'),
  syncConflictReview('SYNC_CONFLICT_REVIEW');

  final String apiValue;

  const MobilePosLifecycleState(this.apiValue);

  static MobilePosLifecycleState fromApi(String? raw) {
    final normalized = (raw ?? 'DRAFT').toUpperCase();
    return MobilePosLifecycleState.values.firstWhere(
      (e) => e.apiValue == normalized,
      orElse: () => MobilePosLifecycleState.draft,
    );
  }

  bool get isMutable =>
      this == MobilePosLifecycleState.draft ||
      this == MobilePosLifecycleState.held ||
      this == MobilePosLifecycleState.pendingRxReview;
}

class MobilePosCustomer {
  final String customerId;
  final String tenantId;
  final String? primaryBranchId;
  final String fullName;
  final String phone;
  final String creditLimitBdt;
  final String currentDueBdt;
  final String availableCreditBdt;
  final bool isCreditApproved;
  final String creditStatus;
  final int creditTermsDays;
  final String creditSuspendedReason;
  final bool isArchived;

  const MobilePosCustomer({
    required this.customerId,
    required this.tenantId,
    required this.primaryBranchId,
    required this.fullName,
    required this.phone,
    required this.creditLimitBdt,
    required this.currentDueBdt,
    this.availableCreditBdt = '0.00',
    this.isCreditApproved = false,
    this.creditStatus = 'UNAPPROVED',
    this.creditTermsDays = 30,
    this.creditSuspendedReason = '',
    required this.isArchived,
  });

  factory MobilePosCustomer.fromJson(Map<String, dynamic> json) {
    final limitStr = (json['credit_limit_bdt'] ?? '0.00').toString();
    final dueStr = (json['current_due_bdt'] ?? '0.00').toString();
    final approved = (json['is_credit_approved'] ?? false) as bool;
    final status = (json['credit_status'] ?? (approved ? 'APPROVED' : 'UNAPPROVED')).toString();
    var availStr = json['available_credit_bdt']?.toString();
    if (availStr == null || availStr.isEmpty) {
      if (approved && status.toUpperCase() == 'APPROVED') {
        final lim = double.tryParse(limitStr) ?? 0.0;
        final due = double.tryParse(dueStr) ?? 0.0;
        availStr = (lim > due ? (lim - due) : 0.0).toStringAsFixed(2);
      } else {
        availStr = '0.00';
      }
    }
    return MobilePosCustomer(
      customerId: (json['customer_id'] ?? '') as String,
      tenantId: (json['tenant_id'] ?? '') as String,
      primaryBranchId: json['primary_branch'] as String?,
      fullName: (json['full_name'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      creditLimitBdt: limitStr,
      currentDueBdt: dueStr,
      availableCreditBdt: availStr,
      isCreditApproved: approved,
      creditStatus: status,
      creditTermsDays: json['credit_terms_days'] is int
          ? json['credit_terms_days'] as int
          : int.tryParse(json['credit_terms_days']?.toString() ?? '30') ?? 30,
      creditSuspendedReason: (json['credit_suspended_reason'] ?? '').toString(),
      isArchived: (json['is_archived'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'customer_id': customerId,
        'tenant_id': tenantId,
        'primary_branch': primaryBranchId,
        'full_name': fullName,
        'phone': phone,
        'credit_limit_bdt': creditLimitBdt,
        'current_due_bdt': currentDueBdt,
        'available_credit_bdt': availableCreditBdt,
        'is_credit_approved': isCreditApproved,
        'credit_status': creditStatus,
        'credit_terms_days': creditTermsDays,
        'is_archived': isArchived,
      };
}

class MobilePosSaleLine {
  final String lineId;
  final int lineNumber;
  final String productId;
  final String productBrandName;
  final String packagingUnit;
  final int quantityUnits;
  final int conversionFactor;
  final int baseUnitsTotal;
  final String dosageFormSnapshot;
  final String containerPolicyApplied;
  final String unitConversionSource;
  final String containerOverrideApprovedByEmail;
  final String containerOverrideReason;
  final String unitPriceBdt;
  final String priceSource;
  final String priceOverrideApprovedByEmail;
  final String priceOverrideReason;
  final String discountType;
  final String discountRatePct;
  final String discountAmountBdt;
  final String taxMode;
  final String taxRatePct;
  final String netBeforeTaxBdt;
  final String lineSubtotalBdt;
  final String lineTaxAmountBdt;
  final String lineTotalBdt;
  final String? unitCostBdt;
  final bool requiresRxVerification;
  final String regulatoryClassification;
  final bool rxVerified;
  final int rxVerifiedBaseUnits;

  const MobilePosSaleLine({
    required this.lineId,
    required this.lineNumber,
    required this.productId,
    required this.productBrandName,
    required this.packagingUnit,
    required this.quantityUnits,
    required this.conversionFactor,
    required this.baseUnitsTotal,
    this.dosageFormSnapshot = '',
    this.containerPolicyApplied = 'STANDARD',
    this.unitConversionSource = '',
    this.containerOverrideApprovedByEmail = '',
    this.containerOverrideReason = '',
    required this.unitPriceBdt,
    this.priceSource = 'CANONICAL_MRP',
    this.priceOverrideApprovedByEmail = '',
    this.priceOverrideReason = '',
    this.discountType = 'NONE',
    this.discountRatePct = '0.00',
    this.discountAmountBdt = '0.00',
    this.taxMode = 'EXCLUSIVE',
    this.taxRatePct = '0.00',
    this.netBeforeTaxBdt = '0.00',
    required this.lineSubtotalBdt,
    required this.lineTaxAmountBdt,
    required this.lineTotalBdt,
    required this.unitCostBdt,
    required this.requiresRxVerification,
    this.regulatoryClassification = 'OTC',
    this.rxVerified = false,
    this.rxVerifiedBaseUnits = 0,
  });

  factory MobilePosSaleLine.fromJson(Map<String, dynamic> json) {
    return MobilePosSaleLine(
      lineId: (json['line_id'] ?? '') as String,
      lineNumber: (json['line_number'] ?? 1) as int,
      productId: (json['product_id'] ?? json['product'] ?? '') as String,
      productBrandName: (json['product_brand_name'] ?? '') as String,
      packagingUnit: (json['packaging_unit'] ?? 'TABLET') as String,
      quantityUnits: (json['quantity_units'] ?? 1) as int,
      conversionFactor: (json['conversion_factor'] ?? 1) as int,
      baseUnitsTotal: (json['base_units_total'] ?? 1) as int,
      dosageFormSnapshot: (json['dosage_form_snapshot'] ?? '').toString(),
      containerPolicyApplied: (json['container_policy_applied'] ?? 'STANDARD').toString(),
      unitConversionSource: (json['unit_conversion_source'] ?? '').toString(),
      containerOverrideApprovedByEmail: (json['container_override_approved_by_email'] ?? '').toString(),
      containerOverrideReason: (json['container_override_reason'] ?? '').toString(),
      unitPriceBdt: (json['unit_price_bdt'] ?? '0.00').toString(),
      priceSource: (json['price_source'] ?? 'CANONICAL_MRP').toString(),
      priceOverrideApprovedByEmail: (json['price_override_approved_by_email'] ?? '').toString(),
      priceOverrideReason: (json['price_override_reason'] ?? '').toString(),
      discountType: (json['discount_type'] ?? 'NONE').toString(),
      discountRatePct: (json['discount_rate_pct'] ?? '0.00').toString(),
      discountAmountBdt: (json['discount_amount_bdt'] ?? '0.00').toString(),
      taxMode: (json['tax_mode'] ?? 'EXCLUSIVE').toString(),
      taxRatePct: (json['tax_rate_pct'] ?? '0.00').toString(),
      netBeforeTaxBdt: (json['net_before_tax_bdt'] ?? '0.00').toString(),
      lineSubtotalBdt: (json['line_subtotal_bdt'] ?? '0.00').toString(),
      lineTaxAmountBdt: (json['line_tax_amount_bdt'] ?? '0.00').toString(),
      lineTotalBdt: (json['line_total_bdt'] ?? '0.00').toString(),
      unitCostBdt: json['unit_cost_bdt']?.toString(),
      requiresRxVerification: (json['requires_rx_verification'] ?? false) as bool,
      regulatoryClassification: (json['regulatory_classification'] ?? 'OTC').toString(),
      rxVerified: json['rx_verified'] == true,
      rxVerifiedBaseUnits: (json['rx_verified_base_units'] is int)
          ? json['rx_verified_base_units'] as int
          : int.tryParse(json['rx_verified_base_units']?.toString() ?? '0') ?? 0,
    );
  }
}

class MobilePosPaymentAttempt {
  final String attemptId;
  final int attemptNumber;
  final String tenderType;
  final String amountBdt;
  final String changeGivenBdt;
  final String netSettledAmountBdt;
  final String status;
  final String verificationStatus;
  final String verificationChannel;
  final String gatewayReference;
  final String payerReference;
  final String cardLast4;
  final String splitBatchKey;
  final String voidReason;
  final String idempotencyKey;

  const MobilePosPaymentAttempt({
    required this.attemptId,
    required this.attemptNumber,
    required this.tenderType,
    required this.amountBdt,
    this.changeGivenBdt = '0.00',
    this.netSettledAmountBdt = '',
    required this.status,
    this.verificationStatus = 'NOT_REQUIRED',
    this.verificationChannel = '',
    this.gatewayReference = '',
    this.payerReference = '',
    this.cardLast4 = '',
    this.splitBatchKey = '',
    this.voidReason = '',
    required this.idempotencyKey,
  });

  String get effectiveNetSettledBdt =>
      netSettledAmountBdt.isNotEmpty ? netSettledAmountBdt : amountBdt;

  factory MobilePosPaymentAttempt.fromJson(Map<String, dynamic> json) {
    final amt = (json['amount_bdt'] ?? '0.00').toString();
    return MobilePosPaymentAttempt(
      attemptId: (json['attempt_id'] ?? '') as String,
      attemptNumber: (json['attempt_number'] ?? 1) as int,
      tenderType: (json['tender_type'] ?? 'CASH') as String,
      amountBdt: amt,
      changeGivenBdt: (json['change_given_bdt'] ?? '0.00').toString(),
      netSettledAmountBdt: (json['net_settled_amount_bdt'] ?? amt).toString(),
      status: (json['status'] ?? 'CAPTURED') as String,
      verificationStatus: (json['verification_status'] ?? 'NOT_REQUIRED').toString(),
      verificationChannel: (json['verification_channel'] ?? '').toString(),
      gatewayReference: (json['gateway_reference'] ?? '').toString(),
      payerReference: (json['payer_reference'] ?? '').toString(),
      cardLast4: (json['card_last4'] ?? '').toString(),
      splitBatchKey: (json['split_batch_key'] ?? '').toString(),
      voidReason: (json['void_reason'] ?? '').toString(),
      idempotencyKey: (json['idempotency_key'] ?? '') as String,
    );
  }
}

class MobilePosSaleAllocation {
  final String allocationId;
  final String saleLineId;
  final String productId;
  final String batchId;
  final String batchNumber;
  final String expiryDate;
  final int fefoSequence;
  final String allocationMode;
  final String overrideReason;
  final String overrideApprovedByEmail;
  final int allocatedBaseUnits;
  final int returnedBaseUnits;
  final String? unitCostBdt;
  final String? totalCostBdt;
  final String status;

  const MobilePosSaleAllocation({
    required this.allocationId,
    this.saleLineId = '',
    this.productId = '',
    this.batchId = '',
    this.batchNumber = '',
    this.expiryDate = '',
    this.fefoSequence = 1,
    this.allocationMode = 'FEFO_AUTO',
    this.overrideReason = '',
    this.overrideApprovedByEmail = '',
    this.allocatedBaseUnits = 0,
    this.returnedBaseUnits = 0,
    this.unitCostBdt,
    this.totalCostBdt,
    this.status = 'RESERVED',
  });

  factory MobilePosSaleAllocation.fromJson(Map<String, dynamic> json) {
    return MobilePosSaleAllocation(
      allocationId: (json['allocation_id'] ?? '').toString(),
      saleLineId: (json['sale_line_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      batchId: (json['batch_id'] ?? '').toString(),
      batchNumber: (json['batch_number'] ?? '').toString(),
      expiryDate: (json['expiry_date_snapshot'] ?? json['expiry_date'] ?? '').toString(),
      fefoSequence: json['fefo_sequence'] is int
          ? json['fefo_sequence'] as int
          : int.tryParse(json['fefo_sequence']?.toString() ?? '1') ?? 1,
      allocationMode: (json['allocation_mode'] ?? 'FEFO_AUTO').toString(),
      overrideReason: (json['override_reason'] ?? '').toString(),
      overrideApprovedByEmail: (json['override_approved_by_email'] ?? '').toString(),
      allocatedBaseUnits: json['allocated_base_units'] is int
          ? json['allocated_base_units'] as int
          : int.tryParse(json['allocated_base_units']?.toString() ?? '0') ?? 0,
      returnedBaseUnits: json['returned_base_units'] is int
          ? json['returned_base_units'] as int
          : int.tryParse(json['returned_base_units']?.toString() ?? '0') ?? 0,
      unitCostBdt: json['unit_cost_bdt']?.toString(),
      totalCostBdt: json['total_cost_bdt']?.toString(),
      status: (json['status'] ?? 'RESERVED').toString(),
    );
  }
}

class MobilePosSaleOrder {
  final String saleId;
  final String tenantId;
  final String branchId;
  final String orderNumber;
  final String idempotencyKey;
  final String customerName;
  final String customerPhone;
  final MobilePosLifecycleState lifecycleState;
  final String syncStatus;
  final String subtotalBdt;
  final String discountType;
  final String discountRatePct;
  final String lineDiscountTotalBdt;
  final String headerDiscountAmountBdt;
  final String discountAmountBdt;
  final String netBeforeTaxBdt;
  final String taxMode;
  final String taxRatePct;
  final String taxAmountBdt;
  final String roundingMode;
  final String roundingAdjustmentBdt;
  final String fulfillmentMode;
  final String deliveryFeeBdt;
  final String grandTotalBdt;
  final String paidAmountBdt;
  final String dueAmountBdt;
  final String changeReturnedBdt;
  final String? linkedInvoiceId;
  final bool requiresRxVerification;
  final String rxGateStatus;
  final String rxDecisionReason;
  final String rxReferenceCode;
  final String pharmacistPcbNoSnapshot;
  final String rxOfflineBlockedReason;
  final String rxSafetyPolicyVersion;
  final String rxVerifiedByEmail;
  final String? rxVerifiedAt;
  final String? prescriptionId;
  final bool hasBlockedRecallOrBan;
  final bool requiresAntibioticRegister;
  final String fefoAllocationStatus;
  final String? pricingConfirmedAt;
  final String pricingConfirmationHash;
  final bool isPricingConfirmed;
  final String currentPricingHash;
  final String holdReference;
  final String holdNote;
  final String? heldAt;
  final String heldByEmail;
  final String? holdExpiresAt;
  final bool holdStockReserved;
  final String? holdReservationExpiresAt;
  final String holdSnapshotPricingHash;
  final String holdSnapshotGrandTotalBdt;
  final String? resumedAt;
  final String resumedByEmail;
  final MobileHeldCartStaleness? staleness;
  final int version;
  final List<MobilePosSaleLine> lines;
  final List<MobilePosSaleAllocation> allocations;
  final List<MobilePosPaymentAttempt> paymentAttempts;

  const MobilePosSaleOrder({
    required this.saleId,
    required this.tenantId,
    required this.branchId,
    required this.orderNumber,
    required this.idempotencyKey,
    required this.customerName,
    required this.customerPhone,
    required this.lifecycleState,
    required this.syncStatus,
    required this.subtotalBdt,
    this.discountType = 'NONE',
    this.discountRatePct = '0.00',
    this.lineDiscountTotalBdt = '0.00',
    this.headerDiscountAmountBdt = '0.00',
    required this.discountAmountBdt,
    this.netBeforeTaxBdt = '0.00',
    this.taxMode = 'EXCLUSIVE',
    this.taxRatePct = '0.00',
    required this.taxAmountBdt,
    this.roundingMode = 'NONE',
    this.roundingAdjustmentBdt = '0.00',
    this.fulfillmentMode = 'COUNTER_WALKIN',
    this.deliveryFeeBdt = '0.00',
    required this.grandTotalBdt,
    required this.paidAmountBdt,
    required this.dueAmountBdt,
    this.changeReturnedBdt = '0.00',
    required this.linkedInvoiceId,
    required this.requiresRxVerification,
    this.rxGateStatus = 'NOT_REQUIRED',
    this.rxDecisionReason = '',
    this.rxReferenceCode = '',
    this.pharmacistPcbNoSnapshot = '',
    this.rxOfflineBlockedReason = '',
    this.rxSafetyPolicyVersion = 'DGDA-POLICY-v2026.1',
    this.rxVerifiedByEmail = '',
    this.rxVerifiedAt,
    this.prescriptionId,
    this.hasBlockedRecallOrBan = false,
    this.requiresAntibioticRegister = false,
    this.fefoAllocationStatus = 'PENDING',
    this.pricingConfirmedAt,
    this.pricingConfirmationHash = '',
    this.isPricingConfirmed = false,
    this.currentPricingHash = '',
    this.holdReference = '',
    this.holdNote = '',
    this.heldAt,
    this.heldByEmail = '',
    this.holdExpiresAt,
    this.holdStockReserved = false,
    this.holdReservationExpiresAt,
    this.holdSnapshotPricingHash = '',
    this.holdSnapshotGrandTotalBdt = '0.00',
    this.resumedAt,
    this.resumedByEmail = '',
    this.staleness,
    this.version = 1,
    required this.lines,
    this.allocations = const <MobilePosSaleAllocation>[],
    required this.paymentAttempts,
  });

  factory MobilePosSaleOrder.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as List<dynamic>? ?? <dynamic>[]);
    final rawAllocs = (json['allocations'] as List<dynamic>? ?? <dynamic>[]);
    final rawPays = (json['payment_attempts'] as List<dynamic>? ?? <dynamic>[]);
    final rawVer = json['version'];
    final parsedVer = rawVer is int ? rawVer : int.tryParse(rawVer?.toString() ?? '') ?? 1;
    final rawStale = json['staleness'];
    final grandStr = (json['grand_total_bdt'] ?? '0.00').toString();
    return MobilePosSaleOrder(
      saleId: (json['sale_id'] ?? '') as String,
      tenantId: (json['tenant_id'] ?? '') as String,
      branchId: (json['branch_id'] ?? '') as String,
      orderNumber: (json['order_number'] ?? '') as String,
      idempotencyKey: (json['idempotency_key'] ?? '') as String,
      customerName: (json['customer_name'] ?? 'Walk-in Customer') as String,
      customerPhone: (json['customer_phone'] ?? '') as String,
      lifecycleState: MobilePosLifecycleState.fromApi(json['lifecycle_state'] as String?),
      syncStatus: (json['sync_status'] ?? 'CLOUD_CONFIRMED') as String,
      subtotalBdt: (json['subtotal_bdt'] ?? '0.00').toString(),
      discountType: (json['discount_type'] ?? 'NONE').toString(),
      discountRatePct: (json['discount_rate_pct'] ?? '0.00').toString(),
      lineDiscountTotalBdt: (json['line_discount_total_bdt'] ?? '0.00').toString(),
      headerDiscountAmountBdt: (json['header_discount_amount_bdt'] ?? '0.00').toString(),
      discountAmountBdt: (json['discount_amount_bdt'] ?? '0.00').toString(),
      netBeforeTaxBdt: (json['net_before_tax_bdt'] ?? '0.00').toString(),
      taxMode: (json['tax_mode'] ?? 'EXCLUSIVE').toString(),
      taxRatePct: (json['tax_rate_pct'] ?? '0.00').toString(),
      taxAmountBdt: (json['tax_amount_bdt'] ?? '0.00').toString(),
      roundingMode: (json['rounding_mode'] ?? 'NONE').toString(),
      roundingAdjustmentBdt: (json['rounding_adjustment_bdt'] ?? '0.00').toString(),
      fulfillmentMode: (json['fulfillment_mode'] ?? 'COUNTER_WALKIN').toString(),
      deliveryFeeBdt: (json['delivery_fee_bdt'] ?? '0.00').toString(),
      grandTotalBdt: grandStr,
      paidAmountBdt: (json['paid_amount_bdt'] ?? '0.00').toString(),
      dueAmountBdt: (json['due_amount_bdt'] ?? '0.00').toString(),
      changeReturnedBdt: (json['change_returned_bdt'] ?? '0.00').toString(),
      linkedInvoiceId: json['linked_invoice_id'] as String?,
      requiresRxVerification: (json['requires_rx_verification'] ?? false) as bool,
      rxGateStatus: (json['rx_gate_status'] ?? 'NOT_REQUIRED').toString(),
      rxDecisionReason: (json['rx_decision_reason'] ?? '').toString(),
      rxReferenceCode: (json['rx_reference_code'] ?? '').toString(),
      pharmacistPcbNoSnapshot: (json['pharmacist_pcb_no_snapshot'] ?? '').toString(),
      rxOfflineBlockedReason: (json['rx_offline_blocked_reason'] ?? '').toString(),
      rxSafetyPolicyVersion: (json['rx_safety_policy_version'] ?? 'DGDA-POLICY-v2026.1').toString(),
      rxVerifiedByEmail: (json['rx_verified_by_email'] ?? '').toString(),
      rxVerifiedAt: json['rx_verified_at']?.toString(),
      prescriptionId: json['prescription_id']?.toString(),
      hasBlockedRecallOrBan: json['has_blocked_recall_or_ban'] == true,
      requiresAntibioticRegister: json['requires_antibiotic_register'] == true,
      fefoAllocationStatus: (json['fefo_allocation_status'] ?? 'PENDING').toString(),
      pricingConfirmedAt: json['pricing_confirmed_at']?.toString(),
      pricingConfirmationHash: (json['pricing_confirmation_hash'] ?? '').toString(),
      isPricingConfirmed: (json['is_pricing_confirmed'] ?? false) as bool,
      currentPricingHash: (json['current_pricing_hash'] ?? '').toString(),
      holdReference: (json['hold_reference'] ?? '').toString(),
      holdNote: (json['hold_note'] ?? '').toString(),
      heldAt: json['held_at']?.toString(),
      heldByEmail: (json['held_by_email'] ?? '').toString(),
      holdExpiresAt: json['hold_expires_at']?.toString(),
      holdStockReserved: json['hold_stock_reserved'] == true,
      holdReservationExpiresAt: json['hold_reservation_expires_at']?.toString(),
      holdSnapshotPricingHash: (json['hold_snapshot_pricing_hash'] ?? '').toString(),
      holdSnapshotGrandTotalBdt: json['hold_snapshot_grand_total_bdt'] != null
          ? json['hold_snapshot_grand_total_bdt'].toString()
          : grandStr,
      resumedAt: json['resumed_at']?.toString(),
      resumedByEmail: (json['resumed_by_email'] ?? '').toString(),
      staleness: rawStale is Map
          ? MobileHeldCartStaleness.fromJson(Map<String, dynamic>.from(rawStale))
          : null,
      version: parsedVer,
      lines: rawLines
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => MobilePosSaleLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      allocations: rawAllocs
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => MobilePosSaleAllocation.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      paymentAttempts: rawPays
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => MobilePosPaymentAttempt.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sale_id': saleId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'order_number': orderNumber,
        'idempotency_key': idempotencyKey,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'lifecycle_state': lifecycleState.apiValue,
        'sync_status': syncStatus,
        'subtotal_bdt': subtotalBdt,
        'discount_type': discountType,
        'discount_rate_pct': discountRatePct,
        'line_discount_total_bdt': lineDiscountTotalBdt,
        'header_discount_amount_bdt': headerDiscountAmountBdt,
        'discount_amount_bdt': discountAmountBdt,
        'net_before_tax_bdt': netBeforeTaxBdt,
        'tax_mode': taxMode,
        'tax_rate_pct': taxRatePct,
        'tax_amount_bdt': taxAmountBdt,
        'rounding_mode': roundingMode,
        'rounding_adjustment_bdt': roundingAdjustmentBdt,
        'grand_total_bdt': grandTotalBdt,
        'paid_amount_bdt': paidAmountBdt,
        'due_amount_bdt': dueAmountBdt,
        'linked_invoice_id': linkedInvoiceId,
        'requires_rx_verification': requiresRxVerification,
        'rx_gate_status': rxGateStatus,
        'rx_decision_reason': rxDecisionReason,
        'rx_reference_code': rxReferenceCode,
        'pharmacist_pcb_no_snapshot': pharmacistPcbNoSnapshot,
        'rx_offline_blocked_reason': rxOfflineBlockedReason,
        'rx_safety_policy_version': rxSafetyPolicyVersion,
        'rx_verified_by_email': rxVerifiedByEmail,
        'rx_verified_at': rxVerifiedAt,
        'prescription_id': prescriptionId,
        'has_blocked_recall_or_ban': hasBlockedRecallOrBan,
        'requires_antibiotic_register': requiresAntibioticRegister,
        'pricing_confirmed_at': pricingConfirmedAt,
        'pricing_confirmation_hash': pricingConfirmationHash,
        'is_pricing_confirmed': isPricingConfirmed,
        'current_pricing_hash': currentPricingHash,
        'hold_reference': holdReference,
        'hold_note': holdNote,
        'held_at': heldAt,
        'held_by_email': heldByEmail,
        'hold_expires_at': holdExpiresAt,
        'hold_stock_reserved': holdStockReserved,
        'hold_reservation_expires_at': holdReservationExpiresAt,
        'hold_snapshot_pricing_hash': holdSnapshotPricingHash,
        'hold_snapshot_grand_total_bdt': holdSnapshotGrandTotalBdt,
        'resumed_at': resumedAt,
        'resumed_by_email': resumedByEmail,
      };
}

class MobilePriceDriftItem {
  final String lineId;
  final String productId;
  final String productBrandName;
  final String packagingUnit;
  final String heldUnitPriceBdt;
  final String liveUnitPriceBdt;

  const MobilePriceDriftItem({
    required this.lineId,
    required this.productId,
    required this.productBrandName,
    required this.packagingUnit,
    required this.heldUnitPriceBdt,
    required this.liveUnitPriceBdt,
  });

  factory MobilePriceDriftItem.fromJson(Map<String, dynamic> json) {
    return MobilePriceDriftItem(
      lineId: (json['line_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productBrandName: (json['product_brand_name'] ?? '').toString(),
      packagingUnit: (json['packaging_unit'] ?? '').toString(),
      heldUnitPriceBdt: (json['held_unit_price_bdt'] ?? '0.00').toString(),
      liveUnitPriceBdt: (json['live_unit_price_bdt'] ?? '0.00').toString(),
    );
  }
}

class MobileShortfallItem {
  final String lineId;
  final String productId;
  final String productBrandName;
  final int requiredBaseUnits;
  final int sellableAvailableBaseUnits;
  final int shortfallBaseUnits;
  final bool unsafeBatchDetected;

  const MobileShortfallItem({
    required this.lineId,
    required this.productId,
    required this.productBrandName,
    required this.requiredBaseUnits,
    required this.sellableAvailableBaseUnits,
    required this.shortfallBaseUnits,
    required this.unsafeBatchDetected,
  });

  factory MobileShortfallItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return MobileShortfallItem(
      lineId: (json['line_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productBrandName: (json['product_brand_name'] ?? '').toString(),
      requiredBaseUnits: parseInt(json['required_base_units']),
      sellableAvailableBaseUnits: parseInt(json['sellable_available_base_units']),
      shortfallBaseUnits: parseInt(json['shortfall_base_units']),
      unsafeBatchDetected: json['unsafe_batch_detected'] == true,
    );
  }
}

class MobileHeldCartStaleness {
  final bool isStale;
  final bool isHoldExpired;
  final bool isReservationExpired;
  final bool hasPriceChange;
  final bool hasStockShortage;
  final bool hasUnsafeBatch;
  final List<String> staleReasons;
  final String heldGrandTotalBdt;
  final String liveGrandTotalBdt;
  final String priceDeltaBdt;
  final String heldPricingHash;
  final String livePricingHash;
  final List<MobilePriceDriftItem> priceDriftItems;
  final List<MobileShortfallItem> shortfallItems;
  final String userPromptEn;
  final String userPromptBn;

  const MobileHeldCartStaleness({
    this.isStale = false,
    this.isHoldExpired = false,
    this.isReservationExpired = false,
    this.hasPriceChange = false,
    this.hasStockShortage = false,
    this.hasUnsafeBatch = false,
    this.staleReasons = const <String>[],
    this.heldGrandTotalBdt = '0.00',
    this.liveGrandTotalBdt = '0.00',
    this.priceDeltaBdt = '0.00',
    this.heldPricingHash = '',
    this.livePricingHash = '',
    this.priceDriftItems = const <MobilePriceDriftItem>[],
    this.shortfallItems = const <MobileShortfallItem>[],
    this.userPromptEn = '',
    this.userPromptBn = '',
  });

  factory MobileHeldCartStaleness.fromJson(Map<String, dynamic> json) {
    final reasons = (json['stale_reasons'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final drifts = (json['price_drift_items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => MobilePriceDriftItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final shorts = (json['shortfall_items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => MobileShortfallItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return MobileHeldCartStaleness(
      isStale: json['is_stale'] == true,
      isHoldExpired: json['is_hold_expired'] == true,
      isReservationExpired: json['is_reservation_expired'] == true,
      hasPriceChange: json['has_price_change'] == true,
      hasStockShortage: json['has_stock_shortage'] == true,
      hasUnsafeBatch: json['has_unsafe_batch'] == true,
      staleReasons: reasons,
      heldGrandTotalBdt: (json['held_grand_total_bdt'] ?? '0.00').toString(),
      liveGrandTotalBdt: (json['live_grand_total_bdt'] ?? '0.00').toString(),
      priceDeltaBdt: (json['price_delta_bdt'] ?? '0.00').toString(),
      heldPricingHash: (json['held_pricing_hash'] ?? '').toString(),
      livePricingHash: (json['live_pricing_hash'] ?? '').toString(),
      priceDriftItems: drifts,
      shortfallItems: shorts,
      userPromptEn: (json['user_prompt_en'] ?? '').toString(),
      userPromptBn: (json['user_prompt_bn'] ?? '').toString(),
    );
  }
}

class MobileHeldCartEntry {
  final String saleId;
  final String orderNumber;
  final String branchId;
  final String branchName;
  final String customerName;
  final String customerPhone;
  final MobilePosLifecycleState lifecycleState;
  final String holdReference;
  final String holdNote;
  final String heldByEmail;
  final String? heldAt;
  final String? holdExpiresAt;
  final bool holdStockReserved;
  final String? holdReservationExpiresAt;
  final int lineCount;
  final String heldGrandTotalBdt;
  final String liveGrandTotalBdt;
  final MobileHeldCartStaleness staleness;
  final int version;
  final MobilePosSaleOrder? sale;
  final bool offlineLocalOnly;

  const MobileHeldCartEntry({
    required this.saleId,
    this.orderNumber = '',
    this.branchId = '',
    this.branchName = '',
    this.customerName = 'Walk-in Customer',
    this.customerPhone = '',
    this.lifecycleState = MobilePosLifecycleState.held,
    this.holdReference = '',
    this.holdNote = '',
    this.heldByEmail = '',
    this.heldAt,
    this.holdExpiresAt,
    this.holdStockReserved = false,
    this.holdReservationExpiresAt,
    this.lineCount = 0,
    this.heldGrandTotalBdt = '0.00',
    this.liveGrandTotalBdt = '0.00',
    this.staleness = const MobileHeldCartStaleness(),
    this.version = 1,
    this.sale,
    this.offlineLocalOnly = false,
  });

  factory MobileHeldCartEntry.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, [int dflt = 0]) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? dflt;
    final rawSale = json['sale'];
    final saleObj = rawSale is Map ? MobilePosSaleOrder.fromJson(Map<String, dynamic>.from(rawSale)) : null;
    final rawStale = json['staleness'];
    final linesNum = parseInt(json['line_count'], saleObj?.lines.length ?? 0);
    return MobileHeldCartEntry(
      saleId: (json['sale_id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? '').toString(),
      branchId: (json['branch_id'] ?? '').toString(),
      branchName: (json['branch_name'] ?? '').toString(),
      customerName: (json['customer_name'] ?? 'Walk-in Customer').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      lifecycleState: MobilePosLifecycleState.fromApi(json['lifecycle_state']?.toString()),
      holdReference: (json['hold_reference'] ?? '').toString(),
      holdNote: (json['hold_note'] ?? '').toString(),
      heldByEmail: (json['held_by_email'] ?? '').toString(),
      heldAt: json['held_at']?.toString(),
      holdExpiresAt: json['hold_expires_at']?.toString(),
      holdStockReserved: json['hold_stock_reserved'] == true,
      holdReservationExpiresAt: json['hold_reservation_expires_at']?.toString(),
      lineCount: linesNum,
      heldGrandTotalBdt: (json['held_grand_total_bdt'] ?? '0.00').toString(),
      liveGrandTotalBdt: (json['live_grand_total_bdt'] ?? '0.00').toString(),
      staleness: rawStale is Map
          ? MobileHeldCartStaleness.fromJson(Map<String, dynamic>.from(rawStale))
          : const MobileHeldCartStaleness(),
      version: parseInt(json['version'], 1),
      sale: saleObj,
    );
  }
}

class MobileHeldCartListResult {
  final int count;
  final int staleCount;
  final int expiredCount;
  final List<MobileHeldCartEntry> results;

  const MobileHeldCartListResult({
    this.count = 0,
    this.staleCount = 0,
    this.expiredCount = 0,
    this.results = const <MobileHeldCartEntry>[],
  });

  factory MobileHeldCartListResult.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    final list = (json['results'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => MobileHeldCartEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final c = parseInt(json['count']);
    return MobileHeldCartListResult(
      count: c == 0 && list.isNotEmpty ? list.length : c,
      staleCount: parseInt(json['stale_count']),
      expiredCount: parseInt(json['expired_count']),
      results: list,
    );
  }
}

class MobileResumeCartResult {
  final String saleId;
  final MobilePosSaleOrder? sale;
  final MobileHeldCartStaleness staleness;
  final bool requiresConfirmation;

  const MobileResumeCartResult({
    required this.saleId,
    this.sale,
    this.staleness = const MobileHeldCartStaleness(),
    this.requiresConfirmation = false,
  });
}

class MobileExpireStaleResult {
  final int expiredCount;
  final int releasedBaseUnits;
  final int voidedCount;
  final List<String> affectedSaleIds;
  final String messageEn;
  final String messageBn;

  const MobileExpireStaleResult({
    this.expiredCount = 0,
    this.releasedBaseUnits = 0,
    this.voidedCount = 0,
    this.affectedSaleIds = const <String>[],
    this.messageEn = '',
    this.messageBn = '',
  });

  factory MobileExpireStaleResult.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return MobileExpireStaleResult(
      expiredCount: parseInt(json['expired_count']),
      releasedBaseUnits: parseInt(json['released_base_units']),
      voidedCount: parseInt(json['voided_count']),
      affectedSaleIds: (json['affected_sale_ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      messageEn: (json['message_en'] ?? '').toString(),
      messageBn: (json['message_bn'] ?? '').toString(),
    );
  }
}

class MobilePosHttpResponse {
  final int statusCode;
  final Map<String, dynamic> data;

  const MobilePosHttpResponse({required this.statusCode, required this.data});
}

typedef MobilePosTransport = Future<MobilePosHttpResponse> Function(
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? bearerToken,
});

class MobilePosOutcome<T> {
  final MobilePosUiState uiState;
  final T? data;
  final String errorCode;
  final String messageEn;
  final String messageBn;

  const MobilePosOutcome({
    required this.uiState,
    this.data,
    this.errorCode = '',
    required this.messageEn,
    required this.messageBn,
  });
}

class MobilePosDeliveryOrder {
  final String deliveryId;
  final String tenantId;
  final String branchId;
  final String branchName;
  final String saleId;
  final String orderNumber;
  final String saleLifecycleState;
  final String saleGrandTotalBdt;
  final String linkedInvoiceId;
  final bool requiresRxVerification;
  final String deliveryNumber;
  final String trackingCode;
  final String fulfillmentMode;
  final String deliveryMethod;
  final String fulfillmentState;
  final String scheduledWindowStart;
  final String scheduledWindowEnd;
  final bool stockReserved;
  final String reservationExpiresAt;
  final String recipientName;
  final String recipientPhone;
  final String deliveryAddressLine;
  final String deliveryArea;
  final String deliveryCity;
  final String deliveryLandmarkNotes;
  final bool addressPrivacyMasked;
  final String addressRedactedAt;
  final String deliveryFeeBdt;
  final String codExpectedBdt;
  final String codCollectedBdt;
  final String courierPartnerName;
  final String riderName;
  final String riderPhone;
  final String proofOfDeliveryRef;
  final int failedAttemptCount;
  final String lastFailureReason;
  final int version;
  final bool isArchived;
  final bool offlineLocalOnly;

  const MobilePosDeliveryOrder({
    required this.deliveryId,
    this.tenantId = '',
    this.branchId = '',
    this.branchName = '',
    this.saleId = '',
    this.orderNumber = '',
    this.saleLifecycleState = 'DRAFT',
    this.saleGrandTotalBdt = '0.00',
    this.linkedInvoiceId = '',
    this.requiresRxVerification = false,
    this.deliveryNumber = '',
    this.trackingCode = '',
    this.fulfillmentMode = 'HOME_DELIVERY',
    this.deliveryMethod = 'OWN_RIDER',
    this.fulfillmentState = 'PREORDER_PENDING',
    this.scheduledWindowStart = '',
    this.scheduledWindowEnd = '',
    this.stockReserved = false,
    this.reservationExpiresAt = '',
    this.recipientName = '',
    this.recipientPhone = '',
    this.deliveryAddressLine = '',
    this.deliveryArea = '',
    this.deliveryCity = 'Dhaka',
    this.deliveryLandmarkNotes = '',
    this.addressPrivacyMasked = true,
    this.addressRedactedAt = '',
    this.deliveryFeeBdt = '0.00',
    this.codExpectedBdt = '0.00',
    this.codCollectedBdt = '0.00',
    this.courierPartnerName = '',
    this.riderName = '',
    this.riderPhone = '',
    this.proofOfDeliveryRef = '',
    this.failedAttemptCount = 0,
    this.lastFailureReason = '',
    this.version = 1,
    this.isArchived = false,
    this.offlineLocalOnly = false,
  });

  MobilePosDeliveryOrder copyWith({
    String? fulfillmentState,
    String? saleLifecycleState,
    String? recipientName,
    String? recipientPhone,
    String? deliveryAddressLine,
    String? deliveryArea,
    String? deliveryCity,
    String? deliveryLandmarkNotes,
    bool? addressPrivacyMasked,
    String? addressRedactedAt,
    String? codExpectedBdt,
    String? codCollectedBdt,
    String? riderName,
    String? proofOfDeliveryRef,
    int? version,
  }) {
    return MobilePosDeliveryOrder(
      deliveryId: deliveryId,
      tenantId: tenantId,
      branchId: branchId,
      branchName: branchName,
      saleId: saleId,
      orderNumber: orderNumber,
      saleLifecycleState: saleLifecycleState ?? this.saleLifecycleState,
      saleGrandTotalBdt: saleGrandTotalBdt,
      linkedInvoiceId: linkedInvoiceId,
      requiresRxVerification: requiresRxVerification,
      deliveryNumber: deliveryNumber,
      trackingCode: trackingCode,
      fulfillmentMode: fulfillmentMode,
      deliveryMethod: deliveryMethod,
      fulfillmentState: fulfillmentState ?? this.fulfillmentState,
      scheduledWindowStart: scheduledWindowStart,
      scheduledWindowEnd: scheduledWindowEnd,
      stockReserved: stockReserved,
      reservationExpiresAt: reservationExpiresAt,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      deliveryAddressLine: deliveryAddressLine ?? this.deliveryAddressLine,
      deliveryArea: deliveryArea ?? this.deliveryArea,
      deliveryCity: deliveryCity ?? this.deliveryCity,
      deliveryLandmarkNotes: deliveryLandmarkNotes ?? this.deliveryLandmarkNotes,
      addressPrivacyMasked: addressPrivacyMasked ?? this.addressPrivacyMasked,
      addressRedactedAt: addressRedactedAt ?? this.addressRedactedAt,
      deliveryFeeBdt: deliveryFeeBdt,
      codExpectedBdt: codExpectedBdt ?? this.codExpectedBdt,
      codCollectedBdt: codCollectedBdt ?? this.codCollectedBdt,
      courierPartnerName: courierPartnerName,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone,
      proofOfDeliveryRef: proofOfDeliveryRef ?? this.proofOfDeliveryRef,
      failedAttemptCount: failedAttemptCount,
      lastFailureReason: lastFailureReason,
      version: version ?? this.version,
      isArchived: isArchived,
      offlineLocalOnly: offlineLocalOnly,
    );
  }

  factory MobilePosDeliveryOrder.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return MobilePosDeliveryOrder(
      deliveryId: (json['delivery_id'] ?? '').toString(),
      tenantId: (json['tenant_id'] ?? '').toString(),
      branchId: (json['branch_id'] ?? '').toString(),
      branchName: (json['branch_name'] ?? '').toString(),
      saleId: (json['sale_id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? '').toString(),
      saleLifecycleState: (json['sale_lifecycle_state'] ?? 'DRAFT').toString(),
      saleGrandTotalBdt: (json['sale_grand_total_bdt'] ?? '0.00').toString(),
      linkedInvoiceId: (json['linked_invoice_id'] ?? '').toString(),
      requiresRxVerification: json['requires_rx_verification'] == true,
      deliveryNumber: (json['delivery_number'] ?? '').toString(),
      trackingCode: (json['tracking_code'] ?? '').toString(),
      fulfillmentMode: (json['fulfillment_mode'] ?? 'HOME_DELIVERY').toString(),
      deliveryMethod: (json['delivery_method'] ?? 'OWN_RIDER').toString(),
      fulfillmentState: (json['fulfillment_state'] ?? 'PREORDER_PENDING').toString(),
      scheduledWindowStart: (json['scheduled_window_start'] ?? '').toString(),
      scheduledWindowEnd: (json['scheduled_window_end'] ?? '').toString(),
      stockReserved: json['stock_reserved'] == true,
      reservationExpiresAt: (json['reservation_expires_at'] ?? '').toString(),
      recipientName: (json['recipient_name'] ?? '').toString(),
      recipientPhone: (json['recipient_phone'] ?? '').toString(),
      deliveryAddressLine: (json['delivery_address_line'] ?? '').toString(),
      deliveryArea: (json['delivery_area'] ?? '').toString(),
      deliveryCity: (json['delivery_city'] ?? 'Dhaka').toString(),
      deliveryLandmarkNotes: (json['delivery_landmark_notes'] ?? '').toString(),
      addressPrivacyMasked: json['_address_privacy_masked'] != false,
      addressRedactedAt: (json['address_redacted_at'] ?? '').toString(),
      deliveryFeeBdt: (json['delivery_fee_bdt'] ?? '0.00').toString(),
      codExpectedBdt: (json['cod_expected_bdt'] ?? '0.00').toString(),
      codCollectedBdt: (json['cod_collected_bdt'] ?? '0.00').toString(),
      courierPartnerName: (json['courier_partner_name'] ?? '').toString(),
      riderName: (json['rider_name'] ?? '').toString(),
      riderPhone: (json['rider_phone'] ?? '').toString(),
      proofOfDeliveryRef: (json['proof_of_delivery_ref'] ?? '').toString(),
      failedAttemptCount: parseInt(json['failed_attempt_count'], fallback: 0),
      lastFailureReason: (json['last_failure_reason'] ?? '').toString(),
      version: parseInt(json['version'], fallback: 1),
      isArchived: json['is_archived'] == true,
    );
  }
}

class MobileDeliveryListResult {
  final int count;
  final List<MobilePosDeliveryOrder> results;

  const MobileDeliveryListResult({required this.count, required this.results});

  factory MobileDeliveryListResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['results'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => MobilePosDeliveryOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final cnt = json['count'] is int ? json['count'] as int : raw.length;
    return MobileDeliveryListResult(count: cnt, results: raw);
  }
}

class MobileAddressRevealResult {
  final String deliveryId;
  final String deliveryNumber;
  final String recipientName;
  final String recipientPhone;
  final String deliveryAddressLine;
  final String deliveryArea;
  final String deliveryCity;
  final String deliveryLandmarkNotes;
  final String auditId;

  const MobileAddressRevealResult({
    required this.deliveryId,
    this.deliveryNumber = '',
    this.recipientName = '',
    this.recipientPhone = '',
    this.deliveryAddressLine = '',
    this.deliveryArea = '',
    this.deliveryCity = '',
    this.deliveryLandmarkNotes = '',
    this.auditId = '',
  });

  factory MobileAddressRevealResult.fromJson(Map<String, dynamic> json) {
    return MobileAddressRevealResult(
      deliveryId: (json['delivery_id'] ?? '').toString(),
      deliveryNumber: (json['delivery_number'] ?? '').toString(),
      recipientName: (json['recipient_name'] ?? '').toString(),
      recipientPhone: (json['recipient_phone'] ?? '').toString(),
      deliveryAddressLine: (json['delivery_address_line'] ?? '').toString(),
      deliveryArea: (json['delivery_area'] ?? '').toString(),
      deliveryCity: (json['delivery_city'] ?? '').toString(),
      deliveryLandmarkNotes: (json['delivery_landmark_notes'] ?? '').toString(),
      auditId: (json['audit_id'] ?? '').toString(),
    );
  }
}

class MobileRxGateStatus {
  final String saleId;
  final String orderNumber;
  final String lifecycleState;
  final bool requiresRxVerification;
  final String rxGateStatus;
  final String prescriptionId;
  final String doctorName;
  final String doctorBmdcNo;
  final String patientToken;
  final String prescriptionStatus;
  final String rxReferenceCode;
  final String pharmacistPcbNoSnapshot;
  final String rxVerifiedByEmail;
  final String? rxVerifiedAt;
  final String rxDecisionReason;
  final bool requiresAntibioticRegister;
  final bool hasNarcotic;
  final bool hasBlockedRecallOrBan;
  final bool canFinalizeOnline;
  final bool canFinalizeOffline;
  final String offlineBlockReasonEn;
  final String offlineBlockReasonBn;
  final int version;

  const MobileRxGateStatus({
    required this.saleId,
    this.orderNumber = '',
    this.lifecycleState = 'DRAFT',
    this.requiresRxVerification = false,
    this.rxGateStatus = 'NOT_REQUIRED',
    this.prescriptionId = '',
    this.doctorName = '',
    this.doctorBmdcNo = '',
    this.patientToken = '',
    this.prescriptionStatus = '',
    this.rxReferenceCode = '',
    this.pharmacistPcbNoSnapshot = '',
    this.rxVerifiedByEmail = '',
    this.rxVerifiedAt,
    this.rxDecisionReason = '',
    this.requiresAntibioticRegister = false,
    this.hasNarcotic = false,
    this.hasBlockedRecallOrBan = false,
    this.canFinalizeOnline = true,
    this.canFinalizeOffline = true,
    this.offlineBlockReasonEn = '',
    this.offlineBlockReasonBn = '',
    this.version = 1,
  });

  factory MobileRxGateStatus.fromJson(Map<String, dynamic> json) {
    final rawVer = json['version'];
    return MobileRxGateStatus(
      saleId: (json['sale_id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? '').toString(),
      lifecycleState: (json['lifecycle_state'] ?? 'DRAFT').toString(),
      requiresRxVerification: json['requires_rx_verification'] == true,
      rxGateStatus: (json['rx_gate_status'] ?? 'NOT_REQUIRED').toString(),
      prescriptionId: (json['prescription_id'] ?? '').toString(),
      doctorName: (json['doctor_name'] ?? '').toString(),
      doctorBmdcNo: (json['doctor_bmdc_no'] ?? '').toString(),
      patientToken: (json['patient_token'] ?? '').toString(),
      prescriptionStatus: (json['prescription_status'] ?? '').toString(),
      rxReferenceCode: (json['rx_reference_code'] ?? '').toString(),
      pharmacistPcbNoSnapshot: (json['pharmacist_pcb_no_snapshot'] ?? '').toString(),
      rxVerifiedByEmail: (json['rx_verified_by_email'] ?? '').toString(),
      rxVerifiedAt: json['rx_verified_at']?.toString(),
      rxDecisionReason: (json['rx_decision_reason'] ?? '').toString(),
      requiresAntibioticRegister: json['requires_antibiotic_register'] == true,
      hasNarcotic: json['has_narcotic'] == true,
      hasBlockedRecallOrBan: json['has_blocked_recall_or_ban'] == true,
      canFinalizeOnline: json.containsKey('can_finalize_online') ? json['can_finalize_online'] == true : true,
      canFinalizeOffline: json.containsKey('can_finalize_offline') ? json['can_finalize_offline'] == true : true,
      offlineBlockReasonEn: (json['offline_block_reason_en'] ?? '').toString(),
      offlineBlockReasonBn: (json['offline_block_reason_bn'] ?? '').toString(),
      version: rawVer is int ? rawVer : int.tryParse(rawVer?.toString() ?? '1') ?? 1,
    );
  }
}

class MobileAntibioticRegisterEntry {
  final String registerEntryId;
  final String saleId;
  final String orderNumber;
  final String brandName;
  final String genericName;
  final String classificationTier;
  final int dispensedBaseUnits;
  final String doctorBmdcNo;
  final String patientToken;
  final String approvingPharmacistPcbNo;
  final String status;

  const MobileAntibioticRegisterEntry({
    required this.registerEntryId,
    this.saleId = '',
    this.orderNumber = '',
    this.brandName = '',
    this.genericName = '',
    this.classificationTier = 'ANTIMICROBIAL_ACCESS',
    this.dispensedBaseUnits = 0,
    this.doctorBmdcNo = '',
    this.patientToken = '',
    this.approvingPharmacistPcbNo = '',
    this.status = 'ACTIVE',
  });

  factory MobileAntibioticRegisterEntry.fromJson(Map<String, dynamic> json) {
    final rawQty = json['dispensed_base_units'];
    return MobileAntibioticRegisterEntry(
      registerEntryId: (json['register_entry_id'] ?? '').toString(),
      saleId: (json['sale_id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? '').toString(),
      brandName: (json['brand_name'] ?? '').toString(),
      genericName: (json['generic_name'] ?? '').toString(),
      classificationTier: (json['classification_tier'] ?? 'ANTIMICROBIAL_ACCESS').toString(),
      dispensedBaseUnits: rawQty is int ? rawQty : int.tryParse(rawQty?.toString() ?? '0') ?? 0,
      doctorBmdcNo: (json['doctor_bmdc_no'] ?? '').toString(),
      patientToken: (json['patient_token'] ?? '').toString(),
      approvingPharmacistPcbNo: (json['approving_pharmacist_pcb_no'] ?? '').toString(),
      status: (json['status'] ?? 'ACTIVE').toString(),
    );
  }
}

class MobileAntibioticRegisterListResult {
  final int count;
  final List<MobileAntibioticRegisterEntry> results;

  const MobileAntibioticRegisterListResult({
    this.count = 0,
    this.results = const <MobileAntibioticRegisterEntry>[],
  });

  factory MobileAntibioticRegisterListResult.fromJson(Map<String, dynamic> json) {
    final rawList = (json['results'] as List<dynamic>? ?? <dynamic>[]);
    final entries = rawList
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => MobileAntibioticRegisterEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final rawCnt = json['count'];
    final cnt = rawCnt is int ? rawCnt : int.tryParse(rawCnt?.toString() ?? '') ?? entries.length;
    return MobileAntibioticRegisterListResult(count: cnt, results: entries);
  }
}

class MobilePosReceipt {
  final String saleId;
  final String orderNumber;
  final String invoiceNumber;
  final String lifecycleState;
  final String rxGateStatus;
  final String pharmacistPcbNo;
  final String doctorBmdcNo;
  final String grandTotalBdt;
  final String paidAmountBdt;
  final String dueAmountBdt;
  final String complianceFooterEn;
  final String complianceFooterBn;

  const MobilePosReceipt({
    required this.saleId,
    this.orderNumber = '',
    this.invoiceNumber = '',
    this.lifecycleState = 'FINALIZED',
    this.rxGateStatus = 'NOT_REQUIRED',
    this.pharmacistPcbNo = '',
    this.doctorBmdcNo = '',
    this.grandTotalBdt = '0.00',
    this.paidAmountBdt = '0.00',
    this.dueAmountBdt = '0.00',
    this.complianceFooterEn = '',
    this.complianceFooterBn = '',
  });

  factory MobilePosReceipt.fromJson(Map<String, dynamic> json) {
    return MobilePosReceipt(
      saleId: (json['sale_id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? '').toString(),
      invoiceNumber: (json['invoice_number'] ?? '').toString(),
      lifecycleState: (json['lifecycle_state'] ?? 'FINALIZED').toString(),
      rxGateStatus: (json['rx_gate_status'] ?? 'NOT_REQUIRED').toString(),
      pharmacistPcbNo: (json['pharmacist_pcb_no_snapshot'] ?? json['pharmacist_pcb_no'] ?? '').toString(),
      doctorBmdcNo: (json['doctor_bmdc_no'] ?? '').toString(),
      grandTotalBdt: (json['grand_total_bdt'] ?? '0.00').toString(),
      paidAmountBdt: (json['paid_amount_bdt'] ?? '0.00').toString(),
      dueAmountBdt: (json['due_amount_bdt'] ?? '0.00').toString(),
      complianceFooterEn: (json['compliance_footer_en'] ?? '').toString(),
      complianceFooterBn: (json['compliance_footer_bn'] ?? '').toString(),
    );
  }
}

class MobileFefoPlannedLot {
  final int fefoSequence;
  final String batchId;
  final String batchNumber;
  final String expiryDate;
  final String purchaseDate;
  final String costLotId;
  final int allocatedBaseUnits;
  final String allocationMode;
  final String? unitCostBdt;
  final String? totalCostBdt;

  const MobileFefoPlannedLot({
    this.fefoSequence = 1,
    required this.batchId,
    this.batchNumber = '',
    this.expiryDate = '',
    this.purchaseDate = '',
    this.costLotId = '',
    this.allocatedBaseUnits = 0,
    this.allocationMode = 'FEFO_AUTO',
    this.unitCostBdt,
    this.totalCostBdt,
  });

  factory MobileFefoPlannedLot.fromJson(Map<String, dynamic> json) {
    return MobileFefoPlannedLot(
      fefoSequence: json['fefo_sequence'] is int
          ? json['fefo_sequence'] as int
          : int.tryParse(json['fefo_sequence']?.toString() ?? '1') ?? 1,
      batchId: (json['batch_id'] ?? '').toString(),
      batchNumber: (json['batch_number'] ?? '').toString(),
      expiryDate: (json['expiry_date'] ?? '').toString(),
      purchaseDate: (json['purchase_date'] ?? '').toString(),
      costLotId: (json['cost_lot_id'] ?? '').toString(),
      allocatedBaseUnits: json['allocated_base_units'] is int
          ? json['allocated_base_units'] as int
          : int.tryParse(json['allocated_base_units']?.toString() ?? '0') ?? 0,
      allocationMode: (json['allocation_mode'] ?? 'FEFO_AUTO').toString(),
      unitCostBdt: json['unit_cost_bdt']?.toString(),
      totalCostBdt: json['total_cost_bdt']?.toString(),
    );
  }
}

class MobileFefoBlockedLot {
  final String batchId;
  final String batchNumber;
  final String expiryDate;
  final String blockCategory;
  final int quantityBaseUnits;
  final String reason;

  const MobileFefoBlockedLot({
    required this.batchId,
    this.batchNumber = '',
    this.expiryDate = '',
    this.blockCategory = '',
    this.quantityBaseUnits = 0,
    this.reason = '',
  });

  factory MobileFefoBlockedLot.fromJson(Map<String, dynamic> json) {
    return MobileFefoBlockedLot(
      batchId: (json['batch_id'] ?? '').toString(),
      batchNumber: (json['batch_number'] ?? '').toString(),
      expiryDate: (json['expiry_date'] ?? '').toString(),
      blockCategory: (json['block_category'] ?? '').toString(),
      quantityBaseUnits: json['quantity_base_units'] is int
          ? json['quantity_base_units'] as int
          : int.tryParse(json['quantity_base_units']?.toString() ?? '0') ?? 0,
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class MobileFefoPlanLine {
  final String lineId;
  final int lineNumber;
  final String productId;
  final String brandName;
  final String packagingUnit;
  final int requestedBaseUnits;
  final int plannedBaseUnits;
  final int shortBaseUnits;
  final bool isFulfilled;
  final String allocationMode;
  final String blockingErrorCode;
  final String blockingReasonEn;
  final String blockingReasonBn;
  final List<MobileFefoPlannedLot> plannedLots;
  final List<MobileFefoBlockedLot> blockedLots;

  const MobileFefoPlanLine({
    required this.lineId,
    this.lineNumber = 1,
    required this.productId,
    this.brandName = '',
    this.packagingUnit = 'TABLET',
    this.requestedBaseUnits = 0,
    this.plannedBaseUnits = 0,
    this.shortBaseUnits = 0,
    this.isFulfilled = true,
    this.allocationMode = 'FEFO_AUTO',
    this.blockingErrorCode = '',
    this.blockingReasonEn = '',
    this.blockingReasonBn = '',
    this.plannedLots = const <MobileFefoPlannedLot>[],
    this.blockedLots = const <MobileFefoBlockedLot>[],
  });

  factory MobileFefoPlanLine.fromJson(Map<String, dynamic> json) {
    final rawPlanned = (json['planned_lots'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => MobileFefoPlannedLot.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final rawBlocked = (json['blocked_lots'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => MobileFefoBlockedLot.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return MobileFefoPlanLine(
      lineId: (json['line_id'] ?? '').toString(),
      lineNumber: json['line_number'] is int
          ? json['line_number'] as int
          : int.tryParse(json['line_number']?.toString() ?? '1') ?? 1,
      productId: (json['product_id'] ?? '').toString(),
      brandName: (json['brand_name'] ?? '').toString(),
      packagingUnit: (json['packaging_unit'] ?? 'TABLET').toString(),
      requestedBaseUnits: json['requested_base_units'] is int
          ? json['requested_base_units'] as int
          : int.tryParse(json['requested_base_units']?.toString() ?? '0') ?? 0,
      plannedBaseUnits: json['planned_base_units'] is int
          ? json['planned_base_units'] as int
          : int.tryParse(json['planned_base_units']?.toString() ?? '0') ?? 0,
      shortBaseUnits: json['short_base_units'] is int
          ? json['short_base_units'] as int
          : int.tryParse(json['short_base_units']?.toString() ?? '0') ?? 0,
      isFulfilled: json['is_fulfilled'] == null ? true : json['is_fulfilled'] == true,
      allocationMode: (json['allocation_mode'] ?? 'FEFO_AUTO').toString(),
      blockingErrorCode: (json['blocking_error_code'] ?? '').toString(),
      blockingReasonEn: (json['blocking_reason_en'] ?? '').toString(),
      blockingReasonBn: (json['blocking_reason_bn'] ?? '').toString(),
      plannedLots: rawPlanned,
      blockedLots: rawBlocked,
    );
  }
}

class MobileFefoAllocationPlan {
  final String saleId;
  final String orderNumber;
  final String fefoAllocationStatus;
  final bool fefoReady;
  final String blockingErrorCode;
  final String blockingReasonEn;
  final String blockingReasonBn;
  final bool hasExpiredBlock;
  final bool hasRecalledBlock;
  final bool hasQuarantinedBlock;
  final int totalRequestedBaseUnits;
  final int totalPlannedBaseUnits;
  final String? totalEstimatedCostBdt;
  final int version;
  final List<MobileFefoPlanLine> lines;

  const MobileFefoAllocationPlan({
    required this.saleId,
    this.orderNumber = '',
    this.fefoAllocationStatus = 'PENDING',
    this.fefoReady = true,
    this.blockingErrorCode = '',
    this.blockingReasonEn = '',
    this.blockingReasonBn = '',
    this.hasExpiredBlock = false,
    this.hasRecalledBlock = false,
    this.hasQuarantinedBlock = false,
    this.totalRequestedBaseUnits = 0,
    this.totalPlannedBaseUnits = 0,
    this.totalEstimatedCostBdt,
    this.version = 1,
    this.lines = const <MobileFefoPlanLine>[],
  });

  factory MobileFefoAllocationPlan.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => MobileFefoPlanLine.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return MobileFefoAllocationPlan(
      saleId: (json['sale_id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? '').toString(),
      fefoAllocationStatus: (json['fefo_allocation_status'] ?? 'PENDING').toString(),
      fefoReady: json.containsKey('fefo_ready') ? json['fefo_ready'] == true : true,
      blockingErrorCode: (json['blocking_error_code'] ?? '').toString(),
      blockingReasonEn: (json['blocking_reason_en'] ?? '').toString(),
      blockingReasonBn: (json['blocking_reason_bn'] ?? '').toString(),
      hasExpiredBlock: json['has_expired_block'] == true,
      hasRecalledBlock: json['has_recalled_block'] == true,
      hasQuarantinedBlock: json['has_quarantined_block'] == true,
      totalRequestedBaseUnits: json['total_requested_base_units'] is int
          ? json['total_requested_base_units'] as int
          : int.tryParse(json['total_requested_base_units']?.toString() ?? '0') ?? 0,
      totalPlannedBaseUnits: json['total_planned_base_units'] is int
          ? json['total_planned_base_units'] as int
          : int.tryParse(json['total_planned_base_units']?.toString() ?? '0') ?? 0,
      totalEstimatedCostBdt: json['total_estimated_cost_bdt']?.toString(),
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '1') ?? 1,
      lines: rawLines,
    );
  }
}

class MobileSplitPaymentInput {
  final String tenderType;
  final String amountBdt;
  final String gatewayReference;
  final String payerReference;
  final String cardLast4;
  final String verificationStatus;
  final String idempotencyKey;

  const MobileSplitPaymentInput({
    required this.tenderType,
    required this.amountBdt,
    this.gatewayReference = '',
    this.payerReference = '',
    this.cardLast4 = '',
    this.verificationStatus = '',
    this.idempotencyKey = '',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tender_type': tenderType.trim().toUpperCase(),
        'amount_bdt': amountBdt.trim(),
        if (gatewayReference.trim().isNotEmpty) 'gateway_reference': gatewayReference.trim(),
        if (payerReference.trim().isNotEmpty) 'payer_reference': payerReference.trim(),
        if (cardLast4.trim().isNotEmpty) 'card_last4': cardLast4.trim(),
        if (verificationStatus.trim().isNotEmpty)
          'verification_status': verificationStatus.trim().toUpperCase(),
        if (idempotencyKey.trim().isNotEmpty) 'idempotency_key': idempotencyKey.trim(),
      };
}

class MobileCashierCloseReconciliation {
  final String reconciliationId;
  final String branchId;
  final String branchName;
  final String registerAssignmentId;
  final String openingFloatBdt;
  final String grossCashTenderedBdt;
  final String cashChangeReturnedBdt;
  final String netCashCollectedBdt;
  final String cashRefundedBdt;
  final String expectedDrawerCashBdt;
  final String countedCashBdt;
  final String varianceBdt;
  final String digitalTotalBdt;
  final String dueIssuedBdt;
  final String dueCollectedCashBdt;
  final String dueCollectedDigitalBdt;
  final int salesCount;
  final int reversedSalesCount;
  final bool journalBalanced;
  final String status;
  final Map<String, String> netByTender;

  const MobileCashierCloseReconciliation({
    this.reconciliationId = '',
    this.branchId = '',
    this.branchName = '',
    this.registerAssignmentId = '',
    this.openingFloatBdt = '0.00',
    this.grossCashTenderedBdt = '0.00',
    this.cashChangeReturnedBdt = '0.00',
    this.netCashCollectedBdt = '0.00',
    this.cashRefundedBdt = '0.00',
    this.expectedDrawerCashBdt = '0.00',
    this.countedCashBdt = '0.00',
    this.varianceBdt = '0.00',
    this.digitalTotalBdt = '0.00',
    this.dueIssuedBdt = '0.00',
    this.dueCollectedCashBdt = '0.00',
    this.dueCollectedDigitalBdt = '0.00',
    this.salesCount = 0,
    this.reversedSalesCount = 0,
    this.journalBalanced = true,
    this.status = 'BALANCED',
    this.netByTender = const <String, String>{},
  });

  factory MobileCashierCloseReconciliation.fromJson(Map<String, dynamic> json) {
    final rawTotals = json['tender_totals'] is Map
        ? json['tender_totals'] as Map
        : (json['tender_totals_json'] is Map ? json['tender_totals_json'] as Map : const <dynamic, dynamic>{});
    final netMap = <String, String>{};
    for (final entry in rawTotals.entries) {
      if (entry.value is Map) {
        netMap[entry.key.toString()] = ((entry.value as Map)['net_bdt'] ?? '0.00').toString();
      }
    }
    return MobileCashierCloseReconciliation(
      reconciliationId: (json['reconciliation_id'] ?? '').toString(),
      branchId: (json['branch_id'] ?? '').toString(),
      branchName: (json['branch_name'] ?? '').toString(),
      registerAssignmentId: (json['register_assignment_id'] ?? '').toString(),
      openingFloatBdt: (json['opening_float_bdt'] ?? '0.00').toString(),
      grossCashTenderedBdt: (json['gross_cash_tendered_bdt'] ?? '0.00').toString(),
      cashChangeReturnedBdt: (json['cash_change_returned_bdt'] ?? '0.00').toString(),
      netCashCollectedBdt: (json['net_cash_collected_bdt'] ?? '0.00').toString(),
      cashRefundedBdt: (json['cash_refunded_bdt'] ?? '0.00').toString(),
      expectedDrawerCashBdt: (json['expected_drawer_cash_bdt'] ?? '0.00').toString(),
      countedCashBdt: (json['counted_cash_bdt'] ?? '0.00').toString(),
      varianceBdt: (json['variance_bdt'] ?? '0.00').toString(),
      digitalTotalBdt: (json['digital_total_bdt'] ?? '0.00').toString(),
      dueIssuedBdt: (json['due_issued_bdt'] ?? '0.00').toString(),
      dueCollectedCashBdt: (json['due_collected_cash_bdt'] ?? '0.00').toString(),
      dueCollectedDigitalBdt: (json['due_collected_digital_bdt'] ?? '0.00').toString(),
      salesCount: json['sales_count'] is int
          ? json['sales_count'] as int
          : int.tryParse(json['sales_count']?.toString() ?? '0') ?? 0,
      reversedSalesCount: json['reversed_sales_count'] is int
          ? json['reversed_sales_count'] as int
          : int.tryParse(json['reversed_sales_count']?.toString() ?? '0') ?? 0,
      journalBalanced: (json['journal_balanced'] ?? true) as bool,
      status: (json['status'] ?? 'BALANCED').toString(),
      netByTender: netMap,
    );
  }
}

class MobileCustomerDueCollection {
  final String collectionId;
  final String dueRecordId;
  final String customerId;
  final String debitAccount;
  final String creditAccount;
  final String revenueImpactBdt;
  final String tenderType;
  final String amountBdt;
  final String cashTenderedBdt;
  final String changeGivenBdt;
  final String gatewayReference;
  final String status;

  const MobileCustomerDueCollection({
    this.collectionId = '',
    this.dueRecordId = '',
    this.customerId = '',
    this.debitAccount = '',
    this.creditAccount = 'AR_CUSTOMER_DUE',
    this.revenueImpactBdt = '0.00',
    this.tenderType = 'CASH',
    this.amountBdt = '0.00',
    this.cashTenderedBdt = '0.00',
    this.changeGivenBdt = '0.00',
    this.gatewayReference = '',
    this.status = 'CAPTURED',
  });

  factory MobileCustomerDueCollection.fromJson(Map<String, dynamic> json) {
    return MobileCustomerDueCollection(
      collectionId: (json['collection_id'] ?? '').toString(),
      dueRecordId: (json['due_record_id'] ?? '').toString(),
      customerId: (json['customer_id'] ?? '').toString(),
      debitAccount: (json['debit_account'] ?? '').toString(),
      creditAccount: (json['credit_account'] ?? 'AR_CUSTOMER_DUE').toString(),
      revenueImpactBdt: (json['revenue_impact_bdt'] ?? '0.00').toString(),
      tenderType: (json['tender_type'] ?? 'CASH').toString(),
      amountBdt: (json['amount_bdt'] ?? '0.00').toString(),
      cashTenderedBdt: (json['cash_tendered_bdt'] ?? '0.00').toString(),
      changeGivenBdt: (json['change_given_bdt'] ?? '0.00').toString(),
      gatewayReference: (json['gateway_reference'] ?? '').toString(),
      status: (json['status'] ?? 'CAPTURED').toString(),
    );
  }
}

class MobileCustomerDueRecord {
  final String dueId;
  final String tenantId;
  final String branchId;
  final String customerId;
  final String saleId;
  final String invoiceId;
  final String customerName;
  final String customerPhone;
  final String totalDueBdt;
  final String paidAmountBdt;
  final String remainingDueBdt;
  final String status;
  final String dueDate;

  const MobileCustomerDueRecord({
    this.dueId = '',
    this.tenantId = '',
    this.branchId = '',
    this.customerId = '',
    this.saleId = '',
    this.invoiceId = '',
    this.customerName = '',
    this.customerPhone = '',
    this.totalDueBdt = '0.00',
    this.paidAmountBdt = '0.00',
    this.remainingDueBdt = '0.00',
    this.status = 'OUTSTANDING',
    this.dueDate = '',
  });

  factory MobileCustomerDueRecord.fromJson(Map<String, dynamic> json) {
    return MobileCustomerDueRecord(
      dueId: (json['due_id'] ?? '').toString(),
      tenantId: (json['tenant_id'] ?? '').toString(),
      branchId: (json['branch_id'] ?? '').toString(),
      customerId: (json['customer_id'] ?? '').toString(),
      saleId: (json['sale_id'] ?? '').toString(),
      invoiceId: (json['invoice_id'] ?? '').toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      totalDueBdt: (json['total_due_bdt'] ?? '0.00').toString(),
      paidAmountBdt: (json['paid_amount_bdt'] ?? '0.00').toString(),
      remainingDueBdt: (json['remaining_due_bdt'] ?? '0.00').toString(),
      status: (json['status'] ?? 'OUTSTANDING').toString(),
      dueDate: (json['due_date'] ?? '').toString(),
    );
  }
}

class MobileDueCollectionOutcome {
  final bool idempotentReplay;
  final MobileCustomerDueCollection collection;
  final MobileCustomerDueRecord dueRecord;
  final String revenueImpactBdt;

  const MobileDueCollectionOutcome({
    this.idempotentReplay = false,
    this.collection = const MobileCustomerDueCollection(),
    this.dueRecord = const MobileCustomerDueRecord(),
    this.revenueImpactBdt = '0.00',
  });

  factory MobileDueCollectionOutcome.fromJson(Map<String, dynamic> json) {
    return MobileDueCollectionOutcome(
      idempotentReplay: (json['idempotent_replay'] ?? false) as bool,
      collection: MobileCustomerDueCollection.fromJson(
        json['collection'] is Map ? Map<String, dynamic>.from(json['collection'] as Map) : const <String, dynamic>{},
      ),
      dueRecord: MobileCustomerDueRecord.fromJson(
        json['due_record'] is Map ? Map<String, dynamic>.from(json['due_record'] as Map) : const <String, dynamic>{},
      ),
      revenueImpactBdt: (json['revenue_impact_bdt'] ?? '0.00').toString(),
    );
  }
}

class MobilePosDomainClient {
  static const Set<String> _posCustomerAdminRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
  };
  static const Set<String> digitalTenders = {
    'BKASH',
    'NAGAD',
    'ROCKET',
    'UPAY',
    'CARD',
    'BANK_TRANSFER',
  };

  static const Set<String> _posWriteRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
    'CASHIER',
  };

  static const Set<String> _posReadRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
    'CASHIER',
    'FINANCE_OFFICER',
    'AUDITOR',
  };

  static const Set<String> _posElevatedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
  };

  static const Set<String> _tenantWideRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'AUDITOR',
  };

  final String baseUrl;
  final MobilePosTransport _transport;
  MobilePosUiState currentState = MobilePosUiState.empty;

  MobilePosDomainClient({
    required this.baseUrl,
    MobilePosTransport? transport,
    Dio? dio,
  }) : _transport = transport ?? _createDioTransport(baseUrl, dio ?? Dio());

  static MobilePosTransport _createDioTransport(String baseUrl, Dio dio) {
    final normalizedBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return (method, path, {body, bearerToken}) async {
      final options = Options(
        method: method,
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (bearerToken != null && bearerToken.isNotEmpty)
            'Authorization': 'Bearer $bearerToken',
        },
        validateStatus: (_) => true,
      );
      final resp = await dio.request<dynamic>(
        '$normalizedBase$path',
        data: body,
        options: options,
      );
      final mapData = resp.data is Map
          ? Map<String, dynamic>.from(resp.data as Map)
          : <String, dynamic>{'results': resp.data};
      return MobilePosHttpResponse(
        statusCode: resp.statusCode ?? 500,
        data: mapData,
      );
    };
  }

  MobilePosOutcome<void> authorizeScope({
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool requireElevated = false,
    bool requireWrite = false,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) {
    if (isOffline) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<void>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_OFFLINE_UNAVAILABLE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
    if (subscriptionSuspended) {
      currentState = MobilePosUiState.permissionDenied;
      return const MobilePosOutcome<void>(
        uiState: MobilePosUiState.permissionDenied,
        errorCode: 'ERR_SUBSCRIPTION_SUSPENDED',
        messageEn: 'Subscription suspended. POS actions locked.',
        messageBn: 'সাবস্ক্রিপশন স্থগিত। পিওএস কার্যক্রম লক করা হয়েছে।',
      );
    }
    final role = actorRole.trim().toUpperCase();
    final allowed = requireElevated
        ? _posElevatedRoles
        : (requireWrite ? _posWriteRoles : _posReadRoles);
    if (!allowed.contains(role)) {
      currentState = MobilePosUiState.permissionDenied;
      return MobilePosOutcome<void>(
        uiState: MobilePosUiState.permissionDenied,
        errorCode: 'ERR_PERMISSION_DENIED',
        messageEn: 'Role $role is not permitted for this POS action.',
        messageBn: '$role রোল-এর এই পিওএস কাজ করার অনুমতি নেই।',
      );
    }
    if (role != 'SUPERADMIN' && actorTenantId != targetTenantId) {
      currentState = MobilePosUiState.error;
      return const MobilePosOutcome<void>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_CROSS_TENANT_VIOLATION',
        messageEn: 'Cross-tenant POS access denied.',
        messageBn: 'অন্য টেন্যান্টের পিওএস তথ্যে প্রবেশাধিকার নেই।',
      );
    }
    if (!_tenantWideRoles.contains(role) && actorBranchId != targetBranchId) {
      currentState = MobilePosUiState.permissionDenied;
      return const MobilePosOutcome<void>(
        uiState: MobilePosUiState.permissionDenied,
        errorCode: 'ERR_CROSS_BRANCH_ACCESS_DENIED',
        messageEn: 'Cross-branch POS operation blocked.',
        messageBn: 'অন্য শাখায় পিওএস অপারেশন অনুমোদিত নয়।',
      );
    }
    return const MobilePosOutcome<void>(
      uiState: MobilePosUiState.ready,
      messageEn: 'Authorized',
      messageBn: 'অনুমোদিত',
    );
  }

  Future<MobilePosOutcome<List<MobilePosSaleOrder>>> listSales({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<List<MobilePosSaleOrder>>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    currentState = MobilePosUiState.loading;
    try {
      final res = await _transport(
        'GET',
        '/api/v2/pos/sales/?branch=$targetBranchId',
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        final rawList = (res.data['results'] as List<dynamic>? ?? <dynamic>[]);
        final parsed = rawList
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => MobilePosSaleOrder.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (parsed.isEmpty) {
          currentState = MobilePosUiState.empty;
          return MobilePosOutcome<List<MobilePosSaleOrder>>(
            uiState: MobilePosUiState.empty,
            data: parsed,
            messageEn: MobilePosUiState.empty.messageEn,
            messageBn: MobilePosUiState.empty.messageBn,
          );
        }
        currentState = MobilePosUiState.ready;
        return MobilePosOutcome<List<MobilePosSaleOrder>>(
          uiState: MobilePosUiState.ready,
          data: parsed,
          messageEn: 'Loaded ${parsed.length} POS sale orders.',
          messageBn: '${parsed.length}টি পিওএস সেলস অর্ডার লোড হয়েছে।',
        );
      }
      if (res.statusCode == 403) {
        currentState = MobilePosUiState.permissionDenied;
        return const MobilePosOutcome<List<MobilePosSaleOrder>>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: 'ERR_PERMISSION_DENIED',
          messageEn: 'Server denied POS list access (HTTP 403).',
          messageBn: 'সার্ভার তালিকা দেখার অনুমতি দেয়নি (HTTP 403)।',
        );
      }
      currentState = MobilePosUiState.error;
      return MobilePosOutcome<List<MobilePosSaleOrder>>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_HTTP_${res.statusCode}',
        messageEn: 'Unexpected HTTP ${res.statusCode}.',
        messageBn: 'অপ্রত্যাশিত সার্ভার ত্রুটি HTTP ${res.statusCode}।',
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<List<MobilePosSaleOrder>>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> reverseSale({
    required String saleId,
    required String reason,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireElevated: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    if (reason.trim().isEmpty) {
      currentState = MobilePosUiState.error;
      return const MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_REASON_REQUIRED',
        messageEn: 'Reversal reason is mandatory.',
        messageBn: 'রিভার্সাল কারণ উল্লেখ করা বাধ্যতামূলক।',
      );
    }

    currentState = MobilePosUiState.loading;
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/reverse/',
        body: <String, dynamic>{'reason': reason.trim()},
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final dto = MobilePosSaleOrder.fromJson(res.data);
        currentState = MobilePosUiState.ready;
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.ready,
          data: dto,
          messageEn: 'Sale reversed cleanly.',
          messageBn: 'সেলস সফলভাবে রিভার্স করা হয়েছে।',
        );
      }
      if (res.statusCode == 403) {
        currentState = MobilePosUiState.permissionDenied;
        return const MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: 'ERR_PERMISSION_DENIED',
          messageEn: 'Server denied sale reversal (HTTP 403).',
          messageBn: 'সার্ভার রিভার্সাল অনুমতি প্রত্যাখ্যান করেছে (HTTP 403)।',
        );
      }
      currentState = MobilePosUiState.error;
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_HTTP_${res.statusCode}',
        messageEn: 'Failed with HTTP ${res.statusCode}.',
        messageBn: 'সার্ভার ত্রুটি HTTP ${res.statusCode}।',
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> updateCartPricing({
    required String saleId,
    required Map<String, dynamic> pricingPayload,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    currentState = MobilePosUiState.loading;
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/update-pricing/',
        body: pricingPayload,
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final rawSale = res.data['sale'] is Map
            ? Map<String, dynamic>.from(res.data['sale'] as Map)
            : res.data;
        final dto = MobilePosSaleOrder.fromJson(rawSale);
        currentState = MobilePosUiState.ready;
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.ready,
          data: dto,
          messageEn: 'Cart prices, discount & rounding updated.',
          messageBn: 'কার্টের মূল্য, ছাড় ও রাউন্ডিং হালনাগাদ হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        currentState = MobilePosUiState.permissionDenied;
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
          messageEn: (res.data['message_en'] ?? res.data['detail'] ?? 'Permission denied modifying pricing.').toString(),
          messageBn: (res.data['message_bn'] ?? 'মূল্য বা ছাড় পরিবর্তনের অনুমতি নেই।').toString(),
        );
      }
      currentState = MobilePosUiState.error;
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
        messageEn: (res.data['message_en'] ?? res.data['detail'] ?? 'Pricing update failed (HTTP ${res.statusCode}).').toString(),
        messageBn: (res.data['message_bn'] ?? 'মূল্য হিসাব হালনাগাদ ব্যর্থ হয়েছে।').toString(),
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> confirmCartPricing({
    required String saleId,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String? expectedGrandTotalBdt,
    String? expectedPricingHash,
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    currentState = MobilePosUiState.loading;
    try {
      final payload = <String, dynamic>{
        if (expectedGrandTotalBdt != null && expectedGrandTotalBdt.isNotEmpty)
          'expected_grand_total_bdt': expectedGrandTotalBdt,
        if (expectedPricingHash != null && expectedPricingHash.isNotEmpty)
          'expected_pricing_hash': expectedPricingHash,
        if (expectedVersion != null) 'expected_version': expectedVersion,
      };
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/confirm-pricing/',
        body: payload,
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final rawSale = res.data['sale'] is Map
            ? Map<String, dynamic>.from(res.data['sale'] as Map)
            : res.data;
        final dto = MobilePosSaleOrder.fromJson(rawSale);
        currentState = MobilePosUiState.ready;
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.ready,
          data: dto,
          messageEn: 'Cart prices confirmed with server signature.',
          messageBn: 'সার্ভার স্বাক্ষরসহ কার্টের মোট মূল্য নিশ্চিত হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        currentState = MobilePosUiState.permissionDenied;
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
          messageEn: (res.data['message_en'] ?? 'Permission denied confirming pricing.').toString(),
          messageBn: (res.data['message_bn'] ?? 'মূল্য নিশ্চিত করার অনুমতি নেই।').toString(),
        );
      }
      currentState = MobilePosUiState.error;
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
        messageEn: (res.data['message_en'] ?? 'Pricing confirmation rejected.').toString(),
        messageBn: (res.data['message_bn'] ?? 'মূল্য নিশ্চিতকরণ ব্যর্থ হয়েছে।').toString(),
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  MobilePosOutcome<void> authorizePharmacistApprovalScope({
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String pharmacistPcbNo = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) {
    final base = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (base.uiState != MobilePosUiState.ready) {
      return base;
    }
    final normRole = actorRole.trim().toUpperCase();
    final isPrimaryPharm = normRole == 'STAFF_PHARMACIST' || normRole == 'SUPERADMIN';
    final isOwnerWithPcb = normRole == 'PHARMACY_OWNER' && pharmacistPcbNo.trim().isNotEmpty;
    if (!isPrimaryPharm && !isOwnerWithPcb) {
      currentState = MobilePosUiState.permissionDenied;
      return const MobilePosOutcome<void>(
        uiState: MobilePosUiState.permissionDenied,
        errorCode: 'ERR_PHARMACIST_APPROVAL_REQUIRED',
        messageEn: 'Only a registered Pharmacist (or Owner with verified PCB registration) may verify or reject Rx orders.',
        messageBn: 'কেবল নিবন্ধিত ফার্মাসিস্ট (বা PCB সনদসহ মালিক) প্রেসক্রিপশন অনুমোদন বা প্রত্যাখ্যান করতে পারবেন।',
      );
    }
    return base;
  }

  Future<MobilePosOutcome<MobileRxGateStatus>> getRxGateStatus({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileRxGateStatus>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport('GET', '/api/v2/pos/sales/$saleId/rx-gate/', bearerToken: bearerToken);
      if (res.statusCode == 200) {
        return MobilePosOutcome<MobileRxGateStatus>(
          uiState: MobilePosUiState.ready,
          data: MobileRxGateStatus.fromJson(res.data),
          messageEn: 'Rx gate status synced.',
          messageBn: 'Rx গেট অবস্থা সিঙ্ক হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return MobilePosOutcome<MobileRxGateStatus>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
          messageEn: (res.data['message_en'] ?? 'Permission denied inspecting Rx gate.').toString(),
          messageBn: (res.data['message_bn'] ?? 'Rx গেট দেখার অনুমতি নেই।').toString(),
        );
      }
      return MobilePosOutcome<MobileRxGateStatus>(
        uiState: MobilePosUiState.error,
        errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
        messageEn: (res.data['message_en'] ?? 'Failed to load Rx gate status.').toString(),
        messageBn: (res.data['message_bn'] ?? 'Rx গেট লোড ব্যর্থ হয়েছে।').toString(),
      );
    } catch (e) {
      return MobilePosOutcome<MobileRxGateStatus>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> attachPrescription({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String doctorName,
    required String doctorBmdcNo,
    String patientToken = '',
    String rxReferenceCode = '',
    String dosageInstructions = '',
    int durationDays = 7,
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/attach-prescription/',
        body: <String, dynamic>{
          'doctor_name': doctorName.trim(),
          'doctor_bmdc_no': doctorBmdcNo.trim(),
          if (patientToken.trim().isNotEmpty) 'patient_token': patientToken.trim(),
          if (rxReferenceCode.trim().isNotEmpty) 'rx_reference_code': rxReferenceCode.trim(),
          if (dosageInstructions.trim().isNotEmpty) 'dosage_instructions': dosageInstructions.trim(),
          'duration_days': durationDays > 0 ? durationDays : 7,
          if (expectedVersion != null) 'expected_version': expectedVersion,
        },
        bearerToken: bearerToken,
      );
      return _parseSaleOutcome(
        res,
        successEn: 'Prescription metadata linked to sale.',
        successBn: 'বিক্রয়ের সাথে প্রেসক্রিপশন তথ্য সংযুক্ত হয়েছে।',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> verifyRxSale({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    String pharmacistPcbNo = '',
    String notes = '',
    String rxReferenceCode = '',
    String doctorName = '',
    String doctorBmdcNo = '',
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizePharmacistApprovalScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      pharmacistPcbNo: pharmacistPcbNo,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/verify-rx/',
        body: <String, dynamic>{
          if (pharmacistPcbNo.trim().isNotEmpty) 'pharmacist_pcb_no': pharmacistPcbNo.trim(),
          if (notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (rxReferenceCode.trim().isNotEmpty) 'rx_reference_code': rxReferenceCode.trim(),
          if (doctorName.trim().isNotEmpty) 'doctor_name': doctorName.trim(),
          if (doctorBmdcNo.trim().isNotEmpty) 'doctor_bmdc_no': doctorBmdcNo.trim(),
          if (expectedVersion != null) 'expected_version': expectedVersion,
        },
        bearerToken: bearerToken,
      );
      return _parseSaleOutcome(
        res,
        successEn: 'Prescription gate APPROVED by registered Pharmacist.',
        successBn: 'নিবন্ধিত ফার্মাসিস্ট কর্তৃক Rx অনুমোদন সম্পন্ন হয়েছে।',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> rejectRxSale({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String reason,
    String pharmacistPcbNo = '',
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizePharmacistApprovalScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      pharmacistPcbNo: pharmacistPcbNo,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    if (reason.trim().length < 3) {
      return const MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_RX_REJECTION_REASON_REQUIRED',
        messageEn: 'Reason (>= 3 chars) is mandatory to reject Rx dispensing.',
        messageBn: 'প্রেসক্রিপশন প্রত্যাখ্যানের জন্য অন্তত ৩ অক্ষরের কারণ উল্লেখ করা আবশ্যক।',
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/reject-rx/',
        body: <String, dynamic>{
          'reason': reason.trim(),
          if (pharmacistPcbNo.trim().isNotEmpty) 'pharmacist_pcb_no': pharmacistPcbNo.trim(),
          if (expectedVersion != null) 'expected_version': expectedVersion,
        },
        bearerToken: bearerToken,
      );
      return _parseSaleOutcome(
        res,
        successEn: 'Prescription dispensing REJECTED by Pharmacist.',
        successBn: 'ফার্মাসিস্ট কর্তৃক প্রেসক্রিপশন বিক্রি প্রত্যাখ্যাত হয়েছে।',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobileRxGateStatus>> offlineRxPreflight({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileRxGateStatus>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/rx-gate/offline-preflight/',
        body: const <String, dynamic>{},
        bearerToken: bearerToken,
      );
      final rawSummary = res.data['summary'] is Map
          ? Map<String, dynamic>.from(res.data['summary'] as Map)
          : res.data;
      final summary = MobileRxGateStatus.fromJson(rawSummary);
      if (res.statusCode == 200) {
        return MobilePosOutcome<MobileRxGateStatus>(
          uiState: MobilePosUiState.ready,
          data: summary,
          messageEn: (res.data['message_en'] ?? 'OTC basket cleared for offline checkout.').toString(),
          messageBn: (res.data['message_bn'] ?? 'কার্টটি অফলাইন চেকআউটের জন্য উপযোগী।').toString(),
        );
      }
      return MobilePosOutcome<MobileRxGateStatus>(
        uiState: MobilePosUiState.error,
        data: summary,
        errorCode: (res.data['error_code'] ?? 'ERR_OFFLINE_RX_BLOCKED').toString(),
        messageEn: (res.data['message_en'] ?? 'Offline limitation: unverified Rx cannot finalize offline.').toString(),
        messageBn: (res.data['message_bn'] ?? 'অফলাইন সীমাবদ্ধতা: অনুমোদনহীন প্রেসক্রিপশন অফলাইনে সম্পন্ন করা যাবে না।').toString(),
      );
    } catch (e) {
      return MobilePosOutcome<MobileRxGateStatus>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobileAntibioticRegisterListResult>> listAntibioticRegister({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String saleFilter = '',
    String statusFilter = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileAntibioticRegisterListResult>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    final qp = <String>[];
    if (targetBranchId.trim().isNotEmpty) qp.add('branch=${Uri.encodeQueryComponent(targetBranchId.trim())}');
    if (saleFilter.trim().isNotEmpty) qp.add('sale_id=${Uri.encodeQueryComponent(saleFilter.trim())}');
    if (statusFilter.trim().isNotEmpty) qp.add('status=${Uri.encodeQueryComponent(statusFilter.trim())}');
    final query = qp.isEmpty ? '' : '?${qp.join('&')}';
    try {
      final res = await _transport('GET', '/api/v2/pos/antibiotic-register/$query', bearerToken: bearerToken);
      if (res.statusCode == 200) {
        final parsed = MobileAntibioticRegisterListResult.fromJson(res.data);
        return MobilePosOutcome<MobileAntibioticRegisterListResult>(
          uiState: parsed.results.isEmpty ? MobilePosUiState.empty : MobilePosUiState.ready,
          data: parsed,
          messageEn: parsed.results.isEmpty
              ? 'No antibiotic dispense entries recorded.'
              : 'Loaded ${parsed.results.length} antibiotic register entry(s).',
          messageBn: parsed.results.isEmpty
              ? 'কোনো অ্যান্টিবায়োটিক ডিস্পেন্স এন্ট্রি পাওয়া যায়নি।'
              : '${parsed.results.length}টি অ্যান্টিবায়োটিক রেজিস্টার এন্ট্রি পাওয়া গেছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return MobilePosOutcome<MobileAntibioticRegisterListResult>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
          messageEn: (res.data['message_en'] ?? 'Permission denied reading antibiotic register.').toString(),
          messageBn: (res.data['message_bn'] ?? 'অ্যান্টিবায়োটিক রেজিস্টার দেখার অনুমতি নেই।').toString(),
        );
      }
      return MobilePosOutcome<MobileAntibioticRegisterListResult>(
        uiState: MobilePosUiState.error,
        errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
        messageEn: (res.data['message_en'] ?? 'Failed loading antibiotic register.').toString(),
        messageBn: (res.data['message_bn'] ?? 'অ্যান্টিবায়োটিক রেজিস্টার লোড ব্যর্থ হয়েছে।').toString(),
      );
    } catch (e) {
      return MobilePosOutcome<MobileAntibioticRegisterListResult>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> recordPaymentAttempt({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String tenderType,
    required String amountBdt,
    required String idempotencyKey,
    String gatewayReference = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/record-payment/',
        body: <String, dynamic>{
          'tender_type': tenderType,
          'amount_bdt': amountBdt,
          'idempotency_key': idempotencyKey,
          if (gatewayReference.trim().isNotEmpty) 'gateway_reference': gatewayReference.trim(),
        },
        bearerToken: bearerToken,
      );
      return _parseSaleOutcome(
        res,
        successEn: 'Payment recorded.',
        successBn: 'পেমেন্ট গৃহীত হয়েছে।',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobileFefoAllocationPlan>> getFefoPlan({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileFefoAllocationPlan>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport(
        'GET',
        '/api/v2/pos/sales/$saleId/fefo-plan/',
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        final plan = MobileFefoAllocationPlan.fromJson(res.data);
        final ui = plan.lines.isEmpty ? MobilePosUiState.empty : MobilePosUiState.ready;
        currentState = ui;
        return MobilePosOutcome<MobileFefoAllocationPlan>(
          uiState: ui,
          data: plan,
          errorCode: plan.blockingErrorCode,
          messageEn: plan.fefoReady
              ? 'FEFO lot allocation plan ready.'
              : (plan.blockingReasonEn.isNotEmpty ? plan.blockingReasonEn : 'FEFO lot block detected.'),
          messageBn: plan.fefoReady
              ? 'FEFO লট বরাদ্দ পরিকল্পনা প্রস্তুত।'
              : (plan.blockingReasonBn.isNotEmpty ? plan.blockingReasonBn : 'FEFO স্টক ব্লক শনাক্ত হয়েছে।'),
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        currentState = MobilePosUiState.permissionDenied;
        return MobilePosOutcome<MobileFefoAllocationPlan>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
          messageEn: (res.data['message_en'] ?? res.data['detail'] ?? 'Permission denied inspecting FEFO plan.').toString(),
          messageBn: (res.data['message_bn'] ?? 'FEFO পরিকল্পনা দেখার অনুমতি নেই।').toString(),
        );
      }
      currentState = MobilePosUiState.error;
      return MobilePosOutcome<MobileFefoAllocationPlan>(
        uiState: MobilePosUiState.error,
        errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
        messageEn: (res.data['message_en'] ?? res.data['detail'] ?? 'Failed loading FEFO plan.').toString(),
        messageBn: (res.data['message_bn'] ?? 'FEFO পরিকল্পনা লোড ব্যর্থ হয়েছে।').toString(),
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<MobileFefoAllocationPlan>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> allocateStockFefo({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    Map<String, String>? batchOverrides,
    String overrideReason = '',
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final hasOverrides = batchOverrides != null && batchOverrides.isNotEmpty;
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    final cleanReason = overrideReason.trim();
    if (hasOverrides && cleanReason.isNotEmpty && cleanReason.length < 3) {
      currentState = MobilePosUiState.error;
      return const MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_FEFO_OVERRIDE_REASON_REQUIRED',
        messageEn: 'Override reason (>= 3 chars) is mandatory when bypassing FEFO order.',
        messageBn: 'FEFO ক্রম পরিবর্তনের জন্য কমপক্ষে ৩ অক্ষরের কারণ উল্লেখ করা আবশ্যক।',
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/allocate/',
        body: <String, dynamic>{
          if (hasOverrides) 'batch_overrides': batchOverrides,
          if (cleanReason.isNotEmpty) 'override_reason': cleanReason,
          if (expectedVersion != null) 'expected_version': expectedVersion,
        },
        bearerToken: bearerToken,
      );
      return _parseSaleOutcome(
        res,
        successEn: 'FEFO lots reserved atomically.',
        successBn: 'FEFO লটগুলো সফলভাবে রিজার্ভ হয়েছে।',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> finalizeSale({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    bool requiresRxVerification = false,
    String rxGateStatus = 'NOT_REQUIRED',
    bool isOfflineSync = false,
    Map<String, String>? batchOverrides,
    String overrideReason = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    if (isOffline && requiresRxVerification && rxGateStatus.toUpperCase() != 'APPROVED') {
      currentState = MobilePosUiState.offline;
      return const MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_OFFLINE_RX_BLOCKED',
        messageEn: 'Offline limitation: unverified Rx/antibiotic medicines cannot finalize offline.',
        messageBn: 'অফলাইন সীমাবদ্ধতা: অনুমোদনহীন প্রেসক্রিপশন বা অ্যান্টিবায়োটিক অফলাইনে সম্পন্ন করা যাবে না।',
      );
    }
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final hasOverrides = batchOverrides != null && batchOverrides.isNotEmpty;
      final cleanReason = overrideReason.trim();
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/finalize/',
        body: <String, dynamic>{
          'is_offline_sync': isOfflineSync,
          if (hasOverrides) 'batch_overrides': batchOverrides,
          if (cleanReason.isNotEmpty) 'override_reason': cleanReason,
        },
        bearerToken: bearerToken,
      );
      return _parseSaleOutcome(
        res,
        successEn: 'Sale finalized cleanly.',
        successBn: 'বিক্রয় সম্পন্ন হয়েছে।',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  /// Submits multi-tender split payments (`CASH`, `BKASH`, `NAGAD`, `ROCKET`, `UPAY`, `CARD`,
  /// `BANK_TRANSFER`, `DUE`) with strict verification & offline digital limitations.
  Future<MobilePosOutcome<MobilePosSaleOrder>> submitSplitPayments({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required List<MobileSplitPaymentInput> splits,
    String batchIdempotencyKey = '',
    bool requireVerified = true,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    if (splits.isEmpty) {
      currentState = MobilePosUiState.error;
      return const MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_EMPTY_SPLIT_PAYMENTS',
        messageEn: 'Add at least one tender split leg before posting payments.',
        messageBn: 'পেমেন্ট সম্পন্ন করার আগে অন্তত একটি টেন্ডার লাইন যোগ করুন।',
      );
    }
    for (final leg in splits) {
      final parsedAmt = double.tryParse(leg.amountBdt.trim());
      if (parsedAmt == null || parsedAmt <= 0.0) {
        currentState = MobilePosUiState.error;
        return const MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.error,
          errorCode: 'ERR_INVALID_PAYMENT_AMOUNT',
          messageEn: 'Each split payment amount must be greater than 0.00 BDT.',
          messageBn: 'প্রতিটি স্প্লিট পেমেন্টের পরিমাণ ০.০০ টাকার বেশি হতে হবে।',
        );
      }
      final tender = leg.tenderType.trim().toUpperCase();
      final gwRef = leg.gatewayReference.trim();
      final ver = leg.verificationStatus.trim().toUpperCase();
      if (tender == 'DUE' && isOffline) {
        currentState = MobilePosUiState.offline;
        return const MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.offline,
          errorCode: 'ERR_OFFLINE_CREDIT_UNAVAILABLE',
          messageEn:
              'Offline limitation: customer credit/DUE sales require online approval & credit limit verification.',
          messageBn:
              'অফলাইন সীমাবদ্ধতা: বাকি বিক্রয়ের জন্য অনলাইন ক্রেডিট অনুমোদন ও লিমিট যাচাই আবশ্যক।',
        );
      }
      if (tender == 'CARD' &&
          leg.cardLast4.trim().isNotEmpty &&
          !RegExp(r'^\d{4}$').hasMatch(leg.cardLast4.trim())) {
        currentState = MobilePosUiState.error;
        return const MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.error,
          errorCode: 'ERR_INVALID_CARD_LAST4',
          messageEn: 'Card last 4 digits must be exactly 4 numeric digits.',
          messageBn: 'কার্ডের শেষ ৪ অঙ্ক অবশ্যই ৪টি সংখ্যা হতে হবে।',
        );
      }
      if (digitalTenders.contains(tender)) {
        if (isOffline && (gwRef.length < 4 || ver == 'PENDING_GATEWAY')) {
          currentState = MobilePosUiState.offline;
          return const MobilePosOutcome<MobilePosSaleOrder>(
            uiState: MobilePosUiState.offline,
            errorCode: 'ERR_OFFLINE_DIGITAL_PAYMENT_REQUIRES_REF',
            messageEn:
                'Offline limitation: MFS/Card payments require live gateway or verified terminal TrxID (>= 4 chars).',
            messageBn:
                'অফলাইন সীমাবদ্ধতা: বিকাশ/নগদ/কার্ডের জন্য ন্যূনতম ৪ অক্ষরের ভেরিফায়েড রেফারেন্স আবশ্যক বা ক্যাশ ব্যবহার করুন।',
          );
        }
        if (!isOffline && requireVerified && ver != 'PENDING_GATEWAY' && gwRef.length < 4) {
          currentState = MobilePosUiState.error;
          return MobilePosOutcome<MobilePosSaleOrder>(
            uiState: MobilePosUiState.error,
            errorCode: 'ERR_DIGITAL_TENDER_REFERENCE_REQUIRED',
            messageEn:
                'Verified $tender payment requires gateway TrxID / auth reference (>= 4 chars).',
            messageBn:
                'ভেরিফায়েড $tender পেমেন্টের জন্য ন্যূনতম ৪ অক্ষরের TrxID বা কার্ড রেফারেন্স আবশ্যক।',
          );
        }
      }
    }
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/split-payments/',
        body: <String, dynamic>{
          'splits': splits.map((e) => e.toJson()).toList(),
          'require_verified': requireVerified,
          if (batchIdempotencyKey.trim().isNotEmpty)
            'batch_idempotency_key': batchIdempotencyKey.trim(),
        },
        bearerToken: bearerToken,
      );
      return _parseSaleOutcome(
        res,
        successEn: 'Split payments posted and reconciled cleanly.',
        successBn: 'স্প্লিট পেমেন্ট সফলভাবে সংরক্ষিত ও সমন্বয় হয়েছে।',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  /// Verifies a previously PENDING_GATEWAY digital payment attempt with a TrxID/Auth code.
  Future<MobilePosOutcome<MobilePosSaleOrder>> verifyPaymentAttempt({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String attemptId,
    required String gatewayReference,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/verify-payment-attempt/',
        body: <String, dynamic>{
          'attempt_id': attemptId.trim(),
          'gateway_reference': gatewayReference.trim(),
        },
        bearerToken: bearerToken,
      );
      return _parseSaleOutcome(
        res,
        successEn: 'Digital payment reference verified.',
        successBn: 'ডিজিটাল পেমেন্ট রেফারেন্স ভেরিফাই হয়েছে।',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  /// Voids a pre-finalized payment attempt with mandatory audit reason (>= 3 chars).
  Future<MobilePosOutcome<MobilePosSaleOrder>> voidPaymentAttempt({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String attemptId,
    required String reason,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    final cleanReason = reason.trim();
    if (cleanReason.length < 3) {
      currentState = MobilePosUiState.error;
      return const MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_VOID_REASON_REQUIRED',
        messageEn: 'Reason (>= 3 chars) is mandatory to void a payment attempt.',
        messageBn: 'পেমেন্ট এন্ট্রি বাতিলের জন্য কমপক্ষে ৩ অক্ষরের কারণ উল্লেখ করা আবশ্যক।',
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/void-payment-attempt/',
        body: <String, dynamic>{
          'attempt_id': attemptId.trim(),
          'reason': cleanReason,
        },
        bearerToken: bearerToken,
      );
      return _parseSaleOutcome(
        res,
        successEn: 'Payment attempt voided.',
        successBn: 'পেমেন্ট এন্ট্রি বাতিল করা হয়েছে।',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  /// Fetches live shift & drawer tender summary before closing a register assignment.
  Future<MobilePosOutcome<MobileCashierCloseReconciliation>> getCloseReconciliation({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String registerAssignmentId = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileCashierCloseReconciliation>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    final qp = <String>['branch=${Uri.encodeQueryComponent(targetBranchId.trim())}'];
    if (registerAssignmentId.trim().isNotEmpty) {
      qp.add('register_assignment=${Uri.encodeQueryComponent(registerAssignmentId.trim())}');
    }
    try {
      final res = await _transport(
        'GET',
        '/api/v2/pos/sales/close-reconciliation/?${qp.join('&')}',
        bearerToken: bearerToken,
      );
      return _parseCloseReconciliationOutcome(
        res,
        successEn: 'Cashier shift tender totals loaded cleanly.',
        successBn: 'শিফট ও ক্যাশ ড্রয়ার রিকনসিলিয়েশন লোড হয়েছে।',
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<MobileCashierCloseReconciliation>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  /// Submits counted drawer cash to close the cashier shift & post variance reconciliation.
  Future<MobilePosOutcome<MobileCashierCloseReconciliation>> submitCloseReconciliation({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String countedCashBdt,
    String registerAssignmentId = '',
    String notes = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileCashierCloseReconciliation>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    final parsedCounted = double.tryParse(countedCashBdt.trim());
    if (parsedCounted == null || parsedCounted < 0.0) {
      currentState = MobilePosUiState.error;
      return const MobilePosOutcome<MobileCashierCloseReconciliation>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_NEGATIVE_COUNTED_CASH',
        messageEn: 'Counted cash amount must be >= 0.00 BDT.',
        messageBn: 'গননাকৃত নগদ অর্থ ০.০০ টাকা বা তার বেশি হতে হবে।',
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/close-reconciliation/',
        body: <String, dynamic>{
          'branch': targetBranchId.trim(),
          if (registerAssignmentId.trim().isNotEmpty)
            'register_assignment': registerAssignmentId.trim(),
          'counted_cash_bdt': parsedCounted.toStringAsFixed(2),
          if (notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
        bearerToken: bearerToken,
      );
      return _parseCloseReconciliationOutcome(
        res,
        successEn: 'Cashier shift close reconciliation recorded.',
        successBn: 'ক্যাশিয়ার শিফট ক্লোজ রিকনসিলিয়েশন সংরক্ষিত হয়েছে।',
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<MobileCashierCloseReconciliation>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  MobilePosOutcome<MobileCashierCloseReconciliation> _parseCloseReconciliationOutcome(
    MobilePosHttpResponse res, {
    required String successEn,
    required String successBn,
  }) {
    if (res.statusCode == 200 || res.statusCode == 201) {
      final dto = MobileCashierCloseReconciliation.fromJson(res.data);
      currentState = MobilePosUiState.ready;
      return MobilePosOutcome<MobileCashierCloseReconciliation>(
        uiState: MobilePosUiState.ready,
        data: dto,
        messageEn: successEn,
        messageBn: successBn,
      );
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      currentState = MobilePosUiState.permissionDenied;
      return MobilePosOutcome<MobileCashierCloseReconciliation>(
        uiState: MobilePosUiState.permissionDenied,
        errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
        messageEn: (res.data['message_en'] ?? res.data['detail'] ?? 'Permission denied.')
            .toString(),
        messageBn: (res.data['message_bn'] ?? 'এই কাজের অনুমতি নেই।').toString(),
      );
    }
    currentState = MobilePosUiState.error;
    return MobilePosOutcome<MobileCashierCloseReconciliation>(
      uiState: MobilePosUiState.error,
      errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
      messageEn: (res.data['message_en'] ?? res.data['detail'] ?? 'Reconciliation failed.')
          .toString(),
      messageBn: (res.data['message_bn'] ?? 'রিকনসিলিয়েশন ব্যর্থ হয়েছে।').toString(),
    );
  }

  /// Fetches branch customers including credit approval & available credit limit.
  Future<MobilePosOutcome<List<MobilePosCustomer>>> listCustomers({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<List<MobilePosCustomer>>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final query = targetBranchId.trim().isNotEmpty
          ? '?branch=${Uri.encodeQueryComponent(targetBranchId.trim())}'
          : '';
      final res = await _transport('GET', '/api/v2/pos/customers/$query', bearerToken: bearerToken);
      if (res.statusCode == 200) {
        final rawList = res.data['results'] is List ? res.data['results'] as List : const <dynamic>[];
        final items = rawList
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => MobilePosCustomer.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        currentState = items.isEmpty ? MobilePosUiState.empty : MobilePosUiState.ready;
        return MobilePosOutcome<List<MobilePosCustomer>>(
          uiState: currentState,
          data: items,
          messageEn: items.isEmpty ? 'No customers found.' : 'Loaded ${items.length} customer(s).',
          messageBn: items.isEmpty ? 'কোনো গ্রাহক পাওয়া যায়নি।' : '${items.length} জন গ্রাহক লোড হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        currentState = MobilePosUiState.permissionDenied;
        return MobilePosOutcome<List<MobilePosCustomer>>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
          messageEn: (res.data['message_en'] ?? 'Permission denied loading customers.').toString(),
          messageBn: (res.data['message_bn'] ?? 'গ্রাহক তালিকা দেখার অনুমতি নেই।').toString(),
        );
      }
      currentState = MobilePosUiState.error;
      return MobilePosOutcome<List<MobilePosCustomer>>(
        uiState: MobilePosUiState.error,
        errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
        messageEn: (res.data['message_en'] ?? 'Failed loading customers.').toString(),
        messageBn: (res.data['message_bn'] ?? 'গ্রাহক তালিকা লোড ব্যর্থ হয়েছে।').toString(),
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<List<MobilePosCustomer>>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  /// Approves customer credit facility & limit (Owner / Branch Manager / Finance Officer only).
  Future<MobilePosOutcome<MobilePosCustomer>> approveCustomerCredit({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String customerId,
    required String creditLimitBdt,
    int creditTermsDays = 30,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosCustomer>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    if (!_posCustomerAdminRoles.contains(actorRole.trim().toUpperCase())) {
      currentState = MobilePosUiState.permissionDenied;
      return const MobilePosOutcome<MobilePosCustomer>(
        uiState: MobilePosUiState.permissionDenied,
        errorCode: 'ERR_PERMISSION_DENIED',
        messageEn: 'Only Owner, Branch Manager, or Finance Officer may approve customer credit.',
        messageBn: 'শুধুমাত্র মালিক, শাখা ব্যবস্থাপক বা ফাইন্যান্স অফিসার ক্রেডিট অনুমোদন করতে পারেন।',
      );
    }
    final parsedLimit = double.tryParse(creditLimitBdt.trim());
    if (parsedLimit == null || parsedLimit <= 0.0) {
      currentState = MobilePosUiState.error;
      return const MobilePosOutcome<MobilePosCustomer>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_CREDIT_LIMIT_MUST_BE_POSITIVE',
        messageEn: 'Approved credit_limit_bdt must be strictly greater than 0.00 BDT.',
        messageBn: 'অনুমোদিত ক্রেডিট লিমিট ০.০০ টাকার বেশি হতে হবে।',
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/customers/$customerId/approve-credit/',
        body: <String, dynamic>{
          'credit_limit_bdt': parsedLimit.toStringAsFixed(2),
          'credit_terms_days': creditTermsDays < 1 ? 30 : creditTermsDays,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        currentState = MobilePosUiState.ready;
        return MobilePosOutcome<MobilePosCustomer>(
          uiState: MobilePosUiState.ready,
          data: MobilePosCustomer.fromJson(res.data),
          messageEn: 'Customer credit approved cleanly.',
          messageBn: 'গ্রাহকের ক্রেডিট লিমিট অনুমোদিত হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        currentState = MobilePosUiState.permissionDenied;
        return MobilePosOutcome<MobilePosCustomer>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
          messageEn: (res.data['message_en'] ?? 'Permission denied approving customer credit.').toString(),
          messageBn: (res.data['message_bn'] ?? 'ক্রেডিট অনুমোদনের অনুমতি নেই।').toString(),
        );
      }
      currentState = MobilePosUiState.error;
      return MobilePosOutcome<MobilePosCustomer>(
        uiState: MobilePosUiState.error,
        errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
        messageEn: (res.data['message_en'] ?? 'Failed approving credit.').toString(),
        messageBn: (res.data['message_bn'] ?? 'ক্রেডিট অনুমোদন ব্যর্থ হয়েছে।').toString(),
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<MobilePosCustomer>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  /// Attaches a PosCustomer to an active mutable POS sale before DUE checkout.
  Future<MobilePosOutcome<MobilePosSaleOrder>> attachCustomerToSale({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String customerId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/attach-customer/',
        body: <String, dynamic>{'customer_id': customerId.trim()},
        bearerToken: bearerToken,
      );
      return _parseSaleOutcome(
        res,
        successEn: 'Customer attached to POS sale cleanly.',
        successBn: 'বিক্রয়ে গ্রাহক যুক্ত করা হয়েছে।',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  /// Lists open or historical customer due receivables (`/api/v2/pos/customer-dues/`).
  Future<MobilePosOutcome<List<MobileCustomerDueRecord>>> listCustomerDues({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String customerId = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<List<MobileCustomerDueRecord>>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    final qp = <String>[];
    if (targetBranchId.trim().isNotEmpty) qp.add('branch=${Uri.encodeQueryComponent(targetBranchId.trim())}');
    if (customerId.trim().isNotEmpty) qp.add('customer=${Uri.encodeQueryComponent(customerId.trim())}');
    final query = qp.isEmpty ? '' : '?${qp.join('&')}';
    try {
      final res = await _transport('GET', '/api/v2/pos/customer-dues/$query', bearerToken: bearerToken);
      if (res.statusCode == 200) {
        final rawList = res.data['results'] is List ? res.data['results'] as List : const <dynamic>[];
        final dues = rawList
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => MobileCustomerDueRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        currentState = dues.isEmpty ? MobilePosUiState.empty : MobilePosUiState.ready;
        return MobilePosOutcome<List<MobileCustomerDueRecord>>(
          uiState: currentState,
          data: dues,
          messageEn: dues.isEmpty ? 'No open customer dues.' : 'Loaded ${dues.length} customer due record(s).',
          messageBn: dues.isEmpty ? 'কোনো বকেয়া পাওনা নেই।' : '${dues.length}টি বাকি রেকর্ড লোড হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        currentState = MobilePosUiState.permissionDenied;
        return MobilePosOutcome<List<MobileCustomerDueRecord>>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
          messageEn: (res.data['message_en'] ?? 'Permission denied inspecting dues.').toString(),
          messageBn: (res.data['message_bn'] ?? 'বাকি তালিকা দেখার অনুমতি নেই।').toString(),
        );
      }
      currentState = MobilePosUiState.error;
      return MobilePosOutcome<List<MobileCustomerDueRecord>>(
        uiState: MobilePosUiState.error,
        errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
        messageEn: (res.data['message_en'] ?? 'Failed loading dues.').toString(),
        messageBn: (res.data['message_bn'] ?? 'বাকি তালিকা লোড ব্যর্থ হয়েছে।').toString(),
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<List<MobileCustomerDueRecord>>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  /// Collects repayment against a CustomerDueRecord posting AR_CUSTOMER_DUE credit (zero double revenue).
  Future<MobilePosOutcome<MobileDueCollectionOutcome>> collectCustomerDue({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String dueId,
    required String tenderType,
    required String amountBdt,
    String cashTenderedBdt = '',
    String gatewayReference = '',
    String idempotencyKey = '',
    String notes = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileDueCollectionOutcome>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    final tender = tenderType.trim().toUpperCase();
    if (tender == 'DUE') {
      currentState = MobilePosUiState.error;
      return const MobilePosOutcome<MobileDueCollectionOutcome>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_CANNOT_COLLECT_DUE_WITH_DUE',
        messageEn: 'Cannot settle a customer due using DUE tender.',
        messageBn: 'বাকি পরিশোধে DUE মাধ্যম ব্যবহার করা যাবে না।',
      );
    }
    final parsedAmt = double.tryParse(amountBdt.trim());
    if (parsedAmt == null || parsedAmt <= 0.0) {
      currentState = MobilePosUiState.error;
      return const MobilePosOutcome<MobileDueCollectionOutcome>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_INVALID_PAYMENT_AMOUNT',
        messageEn: 'Collection amount_bdt must be greater than 0.00 BDT.',
        messageBn: 'আদায়ের পরিমাণ ০.০০ টাকার বেশি হতে হবে।',
      );
    }
    final gwRef = gatewayReference.trim();
    if (digitalTenders.contains(tender) && gwRef.length < 4) {
      currentState = MobilePosUiState.error;
      return MobilePosOutcome<MobileDueCollectionOutcome>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_DIGITAL_TENDER_REFERENCE_REQUIRED',
        messageEn: '$tender due collection requires TrxID / auth reference (>= 4 chars).',
        messageBn: '$tender বাকি আদায়ে ন্যূনতম ৪ অক্ষরের TrxID বা কার্ড রেফারেন্স আবশ্যক।',
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/customer-dues/$dueId/collect/',
        body: <String, dynamic>{
          'tender_type': tender,
          'amount_bdt': parsedAmt.toStringAsFixed(2),
          if (tender == 'CASH' && cashTenderedBdt.trim().isNotEmpty)
            'cash_tendered_bdt': cashTenderedBdt.trim(),
          if (gwRef.isNotEmpty) 'gateway_reference': gwRef,
          if (idempotencyKey.trim().isNotEmpty) 'idempotency_key': idempotencyKey.trim(),
          if (notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final dto = MobileDueCollectionOutcome.fromJson(res.data);
        currentState = MobilePosUiState.ready;
        return MobilePosOutcome<MobileDueCollectionOutcome>(
          uiState: MobilePosUiState.ready,
          data: dto,
          messageEn:
              'Collected ৳${dto.collection.amountBdt} (${dto.collection.creditAccount}, Revenue impact: ৳${dto.revenueImpactBdt}).',
          messageBn:
              'বাকি আদায় ৳${dto.collection.amountBdt} সম্পন্ন (${dto.collection.creditAccount}, ডাবল রেভিনিউ ০.০০)।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        currentState = MobilePosUiState.permissionDenied;
        return MobilePosOutcome<MobileDueCollectionOutcome>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
          messageEn: (res.data['message_en'] ?? 'Permission denied collecting customer due.').toString(),
          messageBn: (res.data['message_bn'] ?? 'বাকি আদায়ের অনুমতি নেই।').toString(),
        );
      }
      currentState = MobilePosUiState.error;
      return MobilePosOutcome<MobileDueCollectionOutcome>(
        uiState: MobilePosUiState.error,
        errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
        messageEn: (res.data['message_en'] ?? res.data['detail'] ?? 'Customer due collection failed.').toString(),
        messageBn: (res.data['message_bn'] ?? 'বাকি আদায় ব্যর্থ হয়েছে।').toString(),
      );
    } catch (e) {
      currentState = MobilePosUiState.offline;
      return MobilePosOutcome<MobileDueCollectionOutcome>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  MobilePosOutcome<MobilePosSaleOrder> _parseSaleOutcome(
    MobilePosHttpResponse res, {
    required String successEn,
    required String successBn,
  }) {
    if (res.statusCode == 200 || res.statusCode == 201) {
      final rawSale = res.data['sale'] is Map
          ? Map<String, dynamic>.from(res.data['sale'] as Map)
          : res.data;
      final dto = MobilePosSaleOrder.fromJson(rawSale);
      currentState = MobilePosUiState.ready;
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.ready,
        data: dto,
        messageEn: successEn,
        messageBn: successBn,
      );
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      currentState = MobilePosUiState.permissionDenied;
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.permissionDenied,
        errorCode: (res.data['error_code'] ?? 'ERR_PERMISSION_DENIED').toString(),
        messageEn: (res.data['message_en'] ?? res.data['detail'] ?? 'Permission denied for POS action.').toString(),
        messageBn: (res.data['message_bn'] ?? 'এই কাজের অনুমতি নেই।').toString(),
      );
    }
    currentState = MobilePosUiState.error;
    return MobilePosOutcome<MobilePosSaleOrder>(
      uiState: MobilePosUiState.error,
      errorCode: (res.data['error_code'] ?? 'ERR_HTTP_${res.statusCode}').toString(),
      messageEn: (res.data['message_en'] ?? res.data['detail'] ?? 'POS Rx operation failed.').toString(),
      messageBn: (res.data['message_bn'] ?? 'Rx অপারেশন ব্যর্থ হয়েছে।').toString(),
    );
  }

  // =========================================================================
  // P231: Invoice Number Policy Preview
  // =========================================================================

  Future<MobilePosOutcome<MobileInvoiceNumberPreview>> previewNextInvoiceNumber({
    String? branchId,
    String? deviceNs,
    String? bearerToken,
  }) async {
    try {
      final query = '?device=${deviceNs ?? 'ONLINE'}${branchId != null ? '&branch_id=$branchId' : ''}';
      final res = await _transport(
        'GET',
        '/api/v2/pos/invoice-policies/preview-next/$query',
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobileInvoiceNumberPreview>(
          uiState: MobilePosUiState.ready,
          data: MobileInvoiceNumberPreview.fromJson(data),
          messageEn: 'Loaded next invoice preview',
          messageBn: 'পরবর্তী ইনভয়েস প্রিভিউ লোড হয়েছে',
        );
      }
      return MobilePosOutcome<MobileInvoiceNumberPreview>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? 'Failed to preview next invoice number',
        messageBn: res.data['message_bn']?.toString() ?? 'ইনভয়েস নম্বর প্রিভিউ ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileInvoiceNumberPreview>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  // =========================================================================
  // P232: Print and Reprint Receipts
  // =========================================================================

  Future<MobilePosOutcome<MobileReceiptPrintResponse>> previewReceipt({
    required String saleId,
    String format = '80MM',
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'GET',
        '/api/v2/pos/sales/$saleId/receipt-preview/?format=$format',
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobileReceiptPrintResponse>(
          uiState: MobilePosUiState.ready,
          data: MobileReceiptPrintResponse.fromJson(data),
          messageEn: 'Loaded receipt preview',
          messageBn: 'রসিদ প্রিভিউ লোড হয়েছে',
        );
      }
      return MobilePosOutcome<MobileReceiptPrintResponse>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? 'Failed to preview receipt',
        messageBn: res.data['message_bn']?.toString() ?? 'রসিদ প্রিভিউ ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileReceiptPrintResponse>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobileReceiptPrintResponse>> printReceipt({
    required String saleId,
    String format = '80MM',
    String printerStatus = 'READY',
    String? reprintReason,
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/print-receipt/',
        body: {
          'format': format,
          'printer_status': printerStatus,
          'reprint_reason': reprintReason ?? '',
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobileReceiptPrintResponse>(
          uiState: MobilePosUiState.ready,
          data: MobileReceiptPrintResponse.fromJson(data),
          messageEn: 'Receipt print recorded successfully',
          messageBn: 'রসিদ প্রিন্ট সফলভাবে সম্পন্ন হয়েছে',
        );
      }
      return MobilePosOutcome<MobileReceiptPrintResponse>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? 'Receipt print recording failed',
        messageBn: res.data['message_bn']?.toString() ?? 'রসিদ প্রিন্ট ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileReceiptPrintResponse>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  // =========================================================================
  // P233: Cashier Shift Open-Close, Cash Drawer & Variance Approval
  // =========================================================================

  Future<MobilePosOutcome<MobileCashierShiftDto>> openShift({
    String? branchId,
    String? deviceCode,
    String openingFloatBdt = '0.00',
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/shifts/open/',
        body: {
          if (branchId != null) 'branch_id': branchId,
          'device_code': deviceCode ?? 'DEFAULT',
          'opening_float_bdt': openingFloatBdt,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobileCashierShiftDto>(
          uiState: MobilePosUiState.ready,
          data: MobileCashierShiftDto.fromJson(data),
          messageEn: 'Shift opened successfully',
          messageBn: 'ক্যাশিয়ার শিফট সফলভাবে শুরু হয়েছে',
        );
      }
      return MobilePosOutcome<MobileCashierShiftDto>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? 'Failed to open shift',
        messageBn: res.data['message_bn']?.toString() ?? 'শিফট শুরু ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileCashierShiftDto>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobileCashierShiftDto>> getActiveShift({String? bearerToken}) async {
    try {
      final res = await _transport(
        'GET',
        '/api/v2/pos/shifts/active/',
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobileCashierShiftDto>(
          uiState: MobilePosUiState.ready,
          data: MobileCashierShiftDto.fromJson(data),
          messageEn: 'Active shift loaded',
          messageBn: 'চলমান শিফট লোড হয়েছে',
        );
      }
      if (res.statusCode == 404) {
        return const MobilePosOutcome<MobileCashierShiftDto>(
          uiState: MobilePosUiState.empty,
          errorCode: 'ERR_NO_ACTIVE_SHIFT',
          messageEn: 'No active shift found',
          messageBn: 'কোনো চলমান শিফট নেই',
        );
      }
      return MobilePosOutcome<MobileCashierShiftDto>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? 'Failed to load active shift',
        messageBn: res.data['message_bn']?.toString() ?? 'চলমান শিফট লোড ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileCashierShiftDto>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobileShiftCashMovementDto>> recordCashMovement({
    required String shiftId,
    required String movementType,
    required String amountBdt,
    required String reason,
    String? recipientOrSource,
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/shifts/$shiftId/cash-movement/',
        body: {
          'movement_type': movementType,
          'amount_bdt': amountBdt,
          'reason': reason,
          if (recipientOrSource != null) 'recipient_or_source': recipientOrSource,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobileShiftCashMovementDto>(
          uiState: MobilePosUiState.ready,
          data: MobileShiftCashMovementDto.fromJson(data),
          messageEn: 'Cash movement recorded',
          messageBn: 'ক্যাশ মুভমেন্ট রেকর্ড হয়েছে',
        );
      }
      return MobilePosOutcome<MobileShiftCashMovementDto>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? 'Cash movement failed',
        messageBn: res.data['message_bn']?.toString() ?? 'ক্যাশ মুভমেন্ট ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileShiftCashMovementDto>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobileCashierShiftDto>> closeShift({
    required String shiftId,
    required String closingCashCountedBdt,
    String? varianceReason,
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/shifts/$shiftId/close/',
        body: {
          'closing_cash_counted_bdt': closingCashCountedBdt,
          if (varianceReason != null) 'variance_reason': varianceReason,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobileCashierShiftDto>(
          uiState: MobilePosUiState.ready,
          data: MobileCashierShiftDto.fromJson(data),
          messageEn: 'Shift closed successfully',
          messageBn: 'শিফট সম্পন্ন হয়েছে',
        );
      }
      return MobilePosOutcome<MobileCashierShiftDto>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? 'Failed to close shift',
        messageBn: res.data['message_bn']?.toString() ?? 'শিফট সমাপ্তি ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileCashierShiftDto>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobileCashierShiftDto>> approveVariance({
    required String shiftId,
    String? managerNotes,
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/shifts/$shiftId/approve-variance/',
        body: {
          if (managerNotes != null) 'manager_approval_notes': managerNotes,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobileCashierShiftDto>(
          uiState: MobilePosUiState.ready,
          data: MobileCashierShiftDto.fromJson(data),
          messageEn: 'Variance approved',
          messageBn: 'ভ্যারিয়েন্স অনুমোদিত হয়েছে',
        );
      }
      return MobilePosOutcome<MobileCashierShiftDto>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? 'Variance approval failed',
        messageBn: res.data['message_bn']?.toString() ?? 'ভ্যারিয়েন্স অনুমোদন ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileCashierShiftDto>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  // =========================================================================
  // P234: Sales Refund, Item Return, Lot Traceability & Safety Disposition
  // =========================================================================

  Future<MobilePosOutcome<MobileSaleReturnDto>> processReturn({
    required String saleId,
    required List<Map<String, dynamic>> lines,
    String refundMethod = 'CASH',
    String reason = '',
    String? customerName,
    String? customerPhone,
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/returns/',
        body: {
          'sale_id': saleId,
          'lines': lines,
          'refund_method': refundMethod,
          'reason': reason,
          if (customerName != null) 'customer_name': customerName,
          if (customerPhone != null) 'customer_phone': customerPhone,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobileSaleReturnDto>(
          uiState: MobilePosUiState.ready,
          data: MobileSaleReturnDto.fromJson(data),
          messageEn: 'Return processed successfully',
          messageBn: 'পণ্য ফেরত এবং রিফান্ড সফলভাবে সম্পন্ন হয়েছে',
        );
      }
      return MobilePosOutcome<MobileSaleReturnDto>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? res.data['detail']?.toString() ?? 'Return processing failed',
        messageBn: res.data['message_bn']?.toString() ?? 'পণ্য ফেরত প্রক্রিয়া ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileSaleReturnDto>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  // =========================================================================
  // P235: Voids, Cart Corrections & Deletion Prohibition
  // =========================================================================

  Future<MobilePosOutcome<MobilePosSaleOrder>> voidSale({
    required String saleId,
    required String reason,
    String? bearerToken,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_REASON_REQUIRED',
        messageEn: 'A documented reason is required to void a sale.',
        messageBn: 'সেলস অর্ডার বাতিল করতে সুনির্দিষ্ট কারণ প্রয়োজন।',
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/void/',
        body: {'reason': cleanReason},
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.ready,
          data: MobilePosSaleOrder.fromJson(data),
          messageEn: 'POS sale voided successfully',
          messageBn: 'পিওএস সেলস অর্ডার সফলভাবে বাতিল করা হয়েছে',
        );
      }
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? res.data['detail']?.toString() ?? 'Failed to void sale',
        messageBn: res.data['message_bn']?.toString() ?? 'সেলস অর্ডার বাতিল ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> correctSale({
    required String saleId,
    required String reason,
    String correctionType = 'CART_CORRECTION',
    String? lineId,
    int? quantityUnits,
    String? bearerToken,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_REASON_REQUIRED',
        messageEn: 'A documented reason is required to correct a sale.',
        messageBn: 'সেলস অর্ডার সংশোধন করতে সুনির্দিষ্ট কারণ প্রয়োজন।',
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/correct/',
        body: {
          'reason': cleanReason,
          'correction_type': correctionType,
          if (lineId != null) 'line_id': lineId,
          if (quantityUnits != null) 'quantity_units': quantityUnits,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.ready,
          data: MobilePosSaleOrder.fromJson(data),
          messageEn: 'POS sale corrected successfully',
          messageBn: 'পিওএস সেলস অর্ডার সফলভাবে সংশোধন করা হয়েছে',
        );
      }
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? res.data['detail']?.toString() ?? 'Failed to correct sale',
        messageBn: res.data['message_bn']?.toString() ?? 'সেলস অর্ডার সংশোধন ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  // =========================================================================
  // P236: Discount Approval & Offline Boundaries
  // =========================================================================

  Future<MobilePosOutcome<MobilePosSaleOrder>> approveDiscount({
    required String saleId,
    required String discountReason,
    String? discountRatePct,
    String? discountAmountBdt,
    List<Map<String, dynamic>>? lineOverrides,
    bool isOffline = false,
    String? managerPin,
    String? bearerToken,
  }) async {
    final cleanReason = discountReason.trim();
    if (cleanReason.length < 3) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_REASON_REQUIRED',
        messageEn: 'A documented reason (>= 3 chars) is mandatory for discount/price approval.',
        messageBn: 'ছাড় বা মূল্য অনুমোদনের জন্য কমপক্ষে ৩ অক্ষরের কারণ উল্লেখ করুন।',
      );
    }
    if (isOffline) {
      if (discountRatePct != null && discountRatePct.isNotEmpty) {
        final rate = double.tryParse(discountRatePct.trim()) ?? 0.0;
        if (rate > 20.0) {
          return MobilePosOutcome<MobilePosSaleOrder>(
            uiState: MobilePosUiState.error,
            errorCode: 'ERR_OFFLINE_DISCOUNT_CEILING_EXCEEDED',
            messageEn: 'Discounts exceeding 20% cannot be approved offline. Cloud verification required.',
            messageBn: 'অফলাইনে ২০%-এর বেশি ছাড় অনুমোদন করা যায় না। ক্লাউড সংযোগ প্রয়োজন।',
          );
        }
      }
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/approve-discount/',
        body: {
          'discount_reason': cleanReason,
          if (discountRatePct != null) 'discount_rate_pct': discountRatePct.trim(),
          if (discountAmountBdt != null) 'discount_amount_bdt': discountAmountBdt.trim(),
          if (lineOverrides != null && lineOverrides.isNotEmpty) 'line_overrides': lineOverrides,
          'is_offline': isOffline,
          if (managerPin != null) 'manager_pin': managerPin,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        final saleData = data['sale'] is Map ? Map<String, dynamic>.from(data['sale']) : data;
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.ready,
          data: MobilePosSaleOrder.fromJson(saleData),
          messageEn: 'Discount approved successfully',
          messageBn: 'ছাড় সফলভাবে অনুমোদন করা হয়েছে',
        );
      }
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? res.data['detail']?.toString() ?? 'Failed to approve discount',
        messageBn: res.data['message_bn']?.toString() ?? 'ছাড় অনুমোদন ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobileDailySalesCloseDto>> submitDailyClose({
    String? closingDate,
    required String actualDrawerCashBdt,
    String notes = '',
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/daily-close/submit/',
        body: {
          if (closingDate != null) 'closing_date': closingDate,
          'actual_drawer_cash_bdt': actualDrawerCashBdt,
          'notes': notes,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 201) {
        return MobilePosOutcome<MobileDailySalesCloseDto>(
          uiState: MobilePosUiState.ready,
          data: MobileDailySalesCloseDto.fromJson(Map<String, dynamic>.from(res.data)),
          messageEn: 'Daily sales close submitted successfully',
          messageBn: 'দৈনিক সেলস ক্লোজ সফলভাবে দাখিল করা হয়েছে',
        );
      }
      return MobilePosOutcome<MobileDailySalesCloseDto>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? res.data['detail']?.toString() ?? 'Failed to submit daily close',
        messageBn: res.data['message_bn']?.toString() ?? 'দৈনিক ক্লোজ দাখিল ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileDailySalesCloseDto>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }

  Future<MobilePosOutcome<MobileDailySalesCloseDto>> approveDailyClose({
    required String closeId,
    String managerNotes = '',
    String? bearerToken,
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/daily-close/$closeId/approve/',
        body: {
          'manager_notes': managerNotes,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode == 200) {
        return MobilePosOutcome<MobileDailySalesCloseDto>(
          uiState: MobilePosUiState.ready,
          data: MobileDailySalesCloseDto.fromJson(Map<String, dynamic>.from(res.data)),
          messageEn: 'Daily sales close approved and sealed successfully',
          messageBn: 'দৈনিক সেলস ক্লোজ সফলভাবে অনুমোদিত ও সিল করা হয়েছে',
        );
      }
      return MobilePosOutcome<MobileDailySalesCloseDto>(
        uiState: res.statusCode == 403 ? MobilePosUiState.permissionDenied : MobilePosUiState.error,
        errorCode: res.data['error_code']?.toString() ?? 'ERR_HTTP_${res.statusCode}',
        messageEn: res.data['message_en']?.toString() ?? res.data['detail']?.toString() ?? 'Failed to approve daily close',
        messageBn: res.data['message_bn']?.toString() ?? 'দৈনিক ক্লোজ অনুমোদন ব্যর্থ হয়েছে',
      );
    } catch (e) {
      return MobilePosOutcome<MobileDailySalesCloseDto>(
        uiState: MobilePosUiState.offline,
        errorCode: 'ERR_NETWORK_UNREACHABLE',
        messageEn: 'Network failure: $e',
        messageBn: 'নেটওয়ার্ক সংযোগ বিচ্ছিন্ন।',
      );
    }
  }
}

class MobileDailySalesCloseDto {
  final String closeId;
  final String closeNumber;
  final String tenantId;
  final String branchId;
  final String closingDate;
  final String status;
  final int salesCount;
  final String grossSalesBdt;
  final String discountTotalBdt;
  final String taxTotalBdt;
  final String netSalesBdt;
  final String cashSalesBdt;
  final String digitalSalesBdt;
  final String dueSalesBdt;
  final int returnsCount;
  final String returnsTotalBdt;
  final String cashRefundsBdt;
  final String digitalRefundsBdt;
  final String dueCollectionsCashBdt;
  final String dueCollectionsDigitalBdt;
  final int shiftsClosedCount;
  final int unclosedShiftsCount;
  final String openingFloatTotalBdt;
  final String cashPayoutsBdt;
  final String expectedDrawerCashBdt;
  final String actualDrawerCashBdt;
  final String cashVarianceBdt;
  final int ledgerEntriesCount;
  final String ledgerDebitTotalBdt;
  final String ledgerCreditTotalBdt;
  final bool isLedgerBalanced;
  final String sha256Hash;
  final String notes;

  const MobileDailySalesCloseDto({
    required this.closeId,
    required this.closeNumber,
    required this.tenantId,
    required this.branchId,
    required this.closingDate,
    required this.status,
    required this.salesCount,
    required this.grossSalesBdt,
    required this.discountTotalBdt,
    required this.taxTotalBdt,
    required this.netSalesBdt,
    required this.cashSalesBdt,
    required this.digitalSalesBdt,
    required this.dueSalesBdt,
    required this.returnsCount,
    required this.returnsTotalBdt,
    required this.cashRefundsBdt,
    required this.digitalRefundsBdt,
    required this.dueCollectionsCashBdt,
    required this.dueCollectionsDigitalBdt,
    required this.shiftsClosedCount,
    required this.unclosedShiftsCount,
    required this.openingFloatTotalBdt,
    required this.cashPayoutsBdt,
    required this.expectedDrawerCashBdt,
    required this.actualDrawerCashBdt,
    required this.cashVarianceBdt,
    required this.ledgerEntriesCount,
    required this.ledgerDebitTotalBdt,
    required this.ledgerCreditTotalBdt,
    required this.isLedgerBalanced,
    required this.sha256Hash,
    this.notes = '',
  });

  factory MobileDailySalesCloseDto.fromJson(Map<String, dynamic> json) {
    return MobileDailySalesCloseDto(
      closeId: json['close_id']?.toString() ?? '',
      closeNumber: json['close_number']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      closingDate: json['closing_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      salesCount: (json['sales_count'] is num) ? (json['sales_count'] as num).toInt() : 0,
      grossSalesBdt: json['gross_sales_bdt']?.toString() ?? '0.00',
      discountTotalBdt: json['discount_total_bdt']?.toString() ?? '0.00',
      taxTotalBdt: json['tax_total_bdt']?.toString() ?? '0.00',
      netSalesBdt: json['net_sales_bdt']?.toString() ?? '0.00',
      cashSalesBdt: json['cash_sales_bdt']?.toString() ?? '0.00',
      digitalSalesBdt: json['digital_sales_bdt']?.toString() ?? '0.00',
      dueSalesBdt: json['due_sales_bdt']?.toString() ?? '0.00',
      returnsCount: (json['returns_count'] is num) ? (json['returns_count'] as num).toInt() : 0,
      returnsTotalBdt: json['returns_total_bdt']?.toString() ?? '0.00',
      cashRefundsBdt: json['cash_refunds_bdt']?.toString() ?? '0.00',
      digitalRefundsBdt: json['digital_refunds_bdt']?.toString() ?? '0.00',
      dueCollectionsCashBdt: json['due_collections_cash_bdt']?.toString() ?? '0.00',
      dueCollectionsDigitalBdt: json['due_collections_digital_bdt']?.toString() ?? '0.00',
      shiftsClosedCount: (json['shifts_closed_count'] is num) ? (json['shifts_closed_count'] as num).toInt() : 0,
      unclosedShiftsCount: (json['unclosed_shifts_count'] is num) ? (json['unclosed_shifts_count'] as num).toInt() : 0,
      openingFloatTotalBdt: json['opening_float_total_bdt']?.toString() ?? '0.00',
      cashPayoutsBdt: json['cash_payouts_bdt']?.toString() ?? '0.00',
      expectedDrawerCashBdt: json['expected_drawer_cash_bdt']?.toString() ?? '0.00',
      actualDrawerCashBdt: json['actual_drawer_cash_bdt']?.toString() ?? '0.00',
      cashVarianceBdt: json['cash_variance_bdt']?.toString() ?? '0.00',
      ledgerEntriesCount: (json['ledger_entries_count'] is num) ? (json['ledger_entries_count'] as num).toInt() : 0,
      ledgerDebitTotalBdt: json['ledger_debit_total_bdt']?.toString() ?? '0.00',
      ledgerCreditTotalBdt: json['ledger_credit_total_bdt']?.toString() ?? '0.00',
      isLedgerBalanced: json['is_ledger_balanced'] == true,
      sha256Hash: json['sha256_hash']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class MobileShiftCashMovementDto {
  final String movementId;
  final String shiftId;
  final String movementType;
  final String amountBdt;
  final String reason;
  final String recipientOrSource;
  final String createdAt;

  const MobileShiftCashMovementDto({
    required this.movementId,
    required this.shiftId,
    required this.movementType,
    required this.amountBdt,
    required this.reason,
    this.recipientOrSource = '',
    required this.createdAt,
  });

  factory MobileShiftCashMovementDto.fromJson(Map<String, dynamic> json) {
    return MobileShiftCashMovementDto(
      movementId: json['movement_id']?.toString() ?? '',
      shiftId: json['shift_id']?.toString() ?? '',
      movementType: json['movement_type']?.toString() ?? 'PAYOUT_EXPENSE',
      amountBdt: json['amount_bdt']?.toString() ?? '0.00',
      reason: json['reason']?.toString() ?? '',
      recipientOrSource: json['recipient_or_source']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class MobileCashierShiftDto {
  final String shiftId;
  final String shiftNumber;
  final String deviceCode;
  final String status;
  final String openingFloatBdt;
  final String totalCashSalesBdt;
  final String totalPayoutsBdt;
  final String expectedDrawerCashBdt;
  final String? closingCashCountedBdt;
  final String? varianceBdt;
  final String varianceReason;
  final bool requiresManagerApproval;
  final String? approvedByEmail;
  final String managerApprovalNotes;
  final String openedAt;
  final String? closedAt;
  final List<MobileShiftCashMovementDto> cashMovements;

  const MobileCashierShiftDto({
    required this.shiftId,
    required this.shiftNumber,
    required this.deviceCode,
    required this.status,
    required this.openingFloatBdt,
    required this.totalCashSalesBdt,
    required this.totalPayoutsBdt,
    required this.expectedDrawerCashBdt,
    this.closingCashCountedBdt,
    this.varianceBdt,
    this.varianceReason = '',
    this.requiresManagerApproval = false,
    this.approvedByEmail,
    this.managerApprovalNotes = '',
    required this.openedAt,
    this.closedAt,
    this.cashMovements = const [],
  });

  factory MobileCashierShiftDto.fromJson(Map<String, dynamic> json) {
    final rawMovements = json['cash_movements'] as List<dynamic>? ?? [];
    return MobileCashierShiftDto(
      shiftId: json['shift_id']?.toString() ?? '',
      shiftNumber: json['shift_number']?.toString() ?? '',
      deviceCode: json['device_code']?.toString() ?? 'DEFAULT',
      status: json['status']?.toString() ?? 'OPEN',
      openingFloatBdt: json['opening_float_bdt']?.toString() ?? '0.00',
      totalCashSalesBdt: json['total_cash_sales_bdt']?.toString() ?? '0.00',
      totalPayoutsBdt: json['total_payouts_bdt']?.toString() ?? '0.00',
      expectedDrawerCashBdt: json['expected_drawer_cash_bdt']?.toString() ?? '0.00',
      closingCashCountedBdt: json['closing_cash_counted_bdt']?.toString(),
      varianceBdt: json['variance_bdt']?.toString(),
      varianceReason: json['variance_reason']?.toString() ?? '',
      requiresManagerApproval: json['requires_manager_approval'] == true,
      approvedByEmail: json['approved_by_email']?.toString(),
      managerApprovalNotes: json['manager_approval_notes']?.toString() ?? '',
      openedAt: json['opened_at']?.toString() ?? '',
      closedAt: json['closed_at']?.toString(),
      cashMovements: rawMovements.map((e) => MobileShiftCashMovementDto.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

class MobileReceiptPrintResponse {
  final String printLogId;
  final String saleId;
  final String invoiceNumber;
  final String jobType;
  final String format;
  final int reprintSequence;
  final String? reprintReason;
  final String? watermarkText;
  final String printerStatus;
  final String rawText;
  final String printedAt;
  final Map<String, dynamic> payload;

  const MobileReceiptPrintResponse({
    required this.printLogId,
    required this.saleId,
    required this.invoiceNumber,
    required this.jobType,
    required this.format,
    required this.reprintSequence,
    this.reprintReason,
    this.watermarkText,
    required this.printerStatus,
    required this.rawText,
    required this.printedAt,
    this.payload = const {},
  });

  factory MobileReceiptPrintResponse.fromJson(Map<String, dynamic> json) {
    return MobileReceiptPrintResponse(
      printLogId: json['print_log_id']?.toString() ?? '',
      saleId: json['sale_id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      jobType: json['job_type']?.toString() ?? 'ORIGINAL_PRINT',
      format: json['format']?.toString() ?? '80MM',
      reprintSequence: (json['reprint_sequence'] is num) ? (json['reprint_sequence'] as num).toInt() : 0,
      reprintReason: json['reprint_reason']?.toString(),
      watermarkText: json['watermark_text']?.toString(),
      printerStatus: json['printer_status']?.toString() ?? 'READY',
      rawText: json['raw_text']?.toString() ?? '',
      printedAt: json['printed_at']?.toString() ?? '',
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload']) : const {},
    );
  }
}

class MobileInvoiceNumberPreview {
  final String invoiceNumber;
  final String policyId;
  final int sequence;
  final String periodKey;
  final String branchCode;
  final String deviceCode;
  final bool isReserved;

  const MobileInvoiceNumberPreview({
    required this.invoiceNumber,
    required this.policyId,
    required this.sequence,
    required this.periodKey,
    required this.branchCode,
    required this.deviceCode,
    this.isReserved = false,
  });

  factory MobileInvoiceNumberPreview.fromJson(Map<String, dynamic> json) {
    return MobileInvoiceNumberPreview(
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      policyId: json['policy_id']?.toString() ?? '',
      sequence: (json['sequence'] is num) ? (json['sequence'] as num).toInt() : 1,
      periodKey: json['period_key']?.toString() ?? '',
      branchCode: json['branch_code']?.toString() ?? '',
      deviceCode: json['device_code']?.toString() ?? '',
      isReserved: json['is_reserved'] == true,
    );
  }
}

class MobileSaleReturnLineDto {
  final String returnLineId;
  final String saleLineId;
  final String productId;
  final String productBrandName;
  final String genericName;
  final String? originalBatchId;
  final String batchNumber;
  final String packagingUnit;
  final int conversionFactor;
  final int quantityUnits;
  final int baseUnitsReturned;
  final String unitPriceBdt;
  final String refundAmountBdt;
  final String safetyDisposition;
  final String dispositionNotes;
  final bool restockedToInventory;

  const MobileSaleReturnLineDto({
    required this.returnLineId,
    required this.saleLineId,
    required this.productId,
    required this.productBrandName,
    required this.genericName,
    this.originalBatchId,
    required this.batchNumber,
    required this.packagingUnit,
    required this.conversionFactor,
    required this.quantityUnits,
    required this.baseUnitsReturned,
    required this.unitPriceBdt,
    required this.refundAmountBdt,
    required this.safetyDisposition,
    this.dispositionNotes = '',
    this.restockedToInventory = false,
  });

  factory MobileSaleReturnLineDto.fromJson(Map<String, dynamic> json) {
    return MobileSaleReturnLineDto(
      returnLineId: json['return_line_id']?.toString() ?? '',
      saleLineId: json['sale_line_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productBrandName: json['product_brand_name']?.toString() ?? '',
      genericName: json['generic_name']?.toString() ?? '',
      originalBatchId: json['original_batch_id']?.toString(),
      batchNumber: json['batch_number']?.toString() ?? '',
      packagingUnit: json['packaging_unit']?.toString() ?? 'TABLET',
      conversionFactor: (json['conversion_factor'] is num) ? (json['conversion_factor'] as num).toInt() : 1,
      quantityUnits: (json['quantity_units'] is num) ? (json['quantity_units'] as num).toInt() : 1,
      baseUnitsReturned: (json['base_units_returned'] is num) ? (json['base_units_returned'] as num).toInt() : 1,
      unitPriceBdt: json['unit_price_bdt']?.toString() ?? '0.00',
      refundAmountBdt: json['refund_amount_bdt']?.toString() ?? '0.00',
      safetyDisposition: json['safety_disposition']?.toString() ?? 'RESTOCKABLE',
      dispositionNotes: json['disposition_notes']?.toString() ?? '',
      restockedToInventory: json['restocked_to_inventory'] == true,
    );
  }
}

class MobileSaleReturnDto {
  final String returnId;
  final String returnNumber;
  final String originalSaleId;
  final String originalOrderNumber;
  final String? shiftId;
  final String status;
  final String refundMethod;
  final String totalRefundAmountBdt;
  final String reason;
  final String customerName;
  final String customerPhone;
  final String processedByName;
  final String createdAt;
  final List<MobileSaleReturnLineDto> lines;

  const MobileSaleReturnDto({
    required this.returnId,
    required this.returnNumber,
    required this.originalSaleId,
    required this.originalOrderNumber,
    this.shiftId,
    required this.status,
    required this.refundMethod,
    required this.totalRefundAmountBdt,
    this.reason = '',
    this.customerName = '',
    this.customerPhone = '',
    this.processedByName = '',
    required this.createdAt,
    this.lines = const [],
  });

  factory MobileSaleReturnDto.fromJson(Map<String, dynamic> json) {
    var rawLines = json['lines'];
    List<MobileSaleReturnLineDto> parsedLines = [];
    if (rawLines is List) {
      parsedLines = rawLines.map((l) => MobileSaleReturnLineDto.fromJson(Map<String, dynamic>.from(l))).toList();
    }
    return MobileSaleReturnDto(
      returnId: json['return_id']?.toString() ?? '',
      returnNumber: json['return_number']?.toString() ?? '',
      originalSaleId: json['original_sale_id']?.toString() ?? '',
      originalOrderNumber: json['original_order_number']?.toString() ?? '',
      shiftId: json['shift_id']?.toString(),
      status: json['status']?.toString() ?? 'COMPLETED',
      refundMethod: json['refund_method']?.toString() ?? 'CASH',
      totalRefundAmountBdt: json['total_refund_amount_bdt']?.toString() ?? '0.00',
      reason: json['reason']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      processedByName: json['processed_by_name']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      lines: parsedLines,
    );
  }
}



