// mobile_party_reconciliation_client.dart
// Architecture Decision: ADR-0280 (P280).
// Phase 14: Customers, Suppliers, Dues & Payments.

class PartyReconciliationPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PartyReconciliationPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  @override
  String toString() => '$errorCode: $messageEn';
}

class PartyReconciliationResultDto {
  final bool success;
  final String reconciliationId;
  final String partyType;
  final String partyId;
  final String partyName;
  final String status;
  final bool isBalanced;
  final String totalSourceInvoicesBdt;
  final String totalSettlementsCollectionsBdt;
  final String totalRefundsCreditsBdt;
  final String? totalReversalsAdjustmentsBdt;
  final String calculatedBalanceBdt;
  final String recordedBalanceBdt;
  final String varianceBdt;
  final List<String> discrepancies;
  final String reconciledAt;

  PartyReconciliationResultDto({
    required this.success,
    required this.reconciliationId,
    required this.partyType,
    required this.partyId,
    required this.partyName,
    required this.status,
    required this.isBalanced,
    required this.totalSourceInvoicesBdt,
    required this.totalSettlementsCollectionsBdt,
    required this.totalRefundsCreditsBdt,
    this.totalReversalsAdjustmentsBdt,
    required this.calculatedBalanceBdt,
    required this.recordedBalanceBdt,
    required this.varianceBdt,
    required this.discrepancies,
    required this.reconciledAt,
  });

  factory PartyReconciliationResultDto.fromJson(Map<String, dynamic> json) {
    return PartyReconciliationResultDto(
      success: json['success'] as bool? ?? false,
      reconciliationId: json['reconciliation_id'] as String? ?? '',
      partyType: json['party_type'] as String? ?? '',
      partyId: json['party_id'] as String? ?? '',
      partyName: json['party_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      isBalanced: json['is_balanced'] as bool? ?? false,
      totalSourceInvoicesBdt: json['total_source_invoices_bdt'] as String? ?? '0.00',
      totalSettlementsCollectionsBdt: json['total_settlements_collections_bdt'] as String? ?? '0.00',
      totalRefundsCreditsBdt: json['total_refunds_credits_bdt'] as String? ?? '0.00',
      totalReversalsAdjustmentsBdt: json['total_reversals_adjustments_bdt'] as String?,
      calculatedBalanceBdt: json['calculated_balance_bdt'] as String? ?? '0.00',
      recordedBalanceBdt: json['recorded_balance_bdt'] as String? ?? '0.00',
      varianceBdt: json['variance_bdt'] as String? ?? '0.00',
      discrepancies: (json['discrepancies'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      reconciledAt: json['reconciled_at'] as String? ?? '',
    );
  }
}

class MobilePartyReconciliationClient {
  static const Set<String> viewAuthorizedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  static const Set<String> adjustAuthorizedRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String userRole;
  final String userId;

  MobilePartyReconciliationClient({
    required this.tenantId,
    required this.userRole,
    required this.userId,
  });

  bool get isAuthorized => viewAuthorizedRoles.contains(userRole.toUpperCase());
  bool get canAutoAdjust => adjustAuthorizedRoles.contains(userRole.toUpperCase());

  void assertAuthorized() {
    if (!isAuthorized) {
      throw PartyReconciliationPermissionException(
        errorCode: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashier and staff pharmacist are not authorized to perform party reconciliation.',
        messageBn: 'ক্যাশিয়ার বা স্টাফ ফার্মাসিস্ট পার্টি রিকনসিলিয়েশন পরিচালনা করার অনুমতিপ্রাপ্ত নন।',
      );
    }
  }

  void assertAdjustAuthorized() {
    if (!canAutoAdjust) {
      throw PartyReconciliationPermissionException(
        errorCode: 'ERR_AUTO_ADJUST_UNAUTHORIZED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can authorize compensating reconciliation adjustments.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার ক্ষতিপূরণমূলক রিকনসিলিয়েশন সমন্বয় অনুমোদন করতে পারেন।',
      );
    }
  }

  Future<PartyReconciliationResultDto> reconcileCustomerAr({
    required String customerId,
    required String customerName,
    required double sourceInvoices,
    required double collections,
    required double refunds,
    required double recordedDue,
    bool autoAdjust = false,
    String adjustmentReason = '',
  }) async {
    assertAuthorized();

    final calculated = double.parse((sourceInvoices - collections - refunds).toStringAsFixed(2));
    var variance = double.parse((calculated - recordedDue).toStringAsFixed(2));

    var isBalanced = variance == 0.0;
    var status = isBalanced ? 'BALANCED' : 'DISCREPANCY_DETECTED';
    final discrepancies = <String>[];

    if (!isBalanced) {
      discrepancies.add('Variance of $variance BDT detected between AR ledger and recorded due.');
    }

    if (autoAdjust && !isBalanced) {
      assertAdjustAuthorized();
      status = 'RECONCILED_WITH_ADJUSTMENT';
      discrepancies.add('Auto-adjustment applied: $adjustmentReason');
      variance = 0.0;
      isBalanced = true;
    }

    return PartyReconciliationResultDto(
      success: true,
      reconciliationId: 'prec-${DateTime.now().millisecondsSinceEpoch}',
      partyType: 'CUSTOMER',
      partyId: customerId,
      partyName: customerName,
      status: status,
      isBalanced: isBalanced,
      totalSourceInvoicesBdt: sourceInvoices.toStringAsFixed(2),
      totalSettlementsCollectionsBdt: collections.toStringAsFixed(2),
      totalRefundsCreditsBdt: refunds.toStringAsFixed(2),
      calculatedBalanceBdt: calculated.toStringAsFixed(2),
      recordedBalanceBdt: recordedDue.toStringAsFixed(2),
      varianceBdt: variance.toStringAsFixed(2),
      discrepancies: discrepancies,
      reconciledAt: DateTime.now().toIso8601String(),
    );
  }

  Future<PartyReconciliationResultDto> reconcileSupplierAp({
    required String supplierId,
    required String supplierName,
    required double bills,
    required double payments,
    required double creditNotes,
    required double recordedBalance,
    bool autoAdjust = false,
    String adjustmentReason = '',
  }) async {
    assertAuthorized();

    final calculated = double.parse((bills - payments - creditNotes).toStringAsFixed(2));
    var variance = double.parse((calculated - recordedBalance).toStringAsFixed(2));

    var isBalanced = variance == 0.0;
    var status = isBalanced ? 'BALANCED' : 'DISCREPANCY_DETECTED';
    final discrepancies = <String>[];

    if (!isBalanced) {
      discrepancies.add('Variance of $variance BDT detected between AP ledger and recorded balance.');
    }

    if (autoAdjust && !isBalanced) {
      assertAdjustAuthorized();
      status = 'RECONCILED_WITH_ADJUSTMENT';
      discrepancies.add('Auto-adjustment applied: $adjustmentReason');
      variance = 0.0;
      isBalanced = true;
    }

    return PartyReconciliationResultDto(
      success: true,
      reconciliationId: 'prec-${DateTime.now().millisecondsSinceEpoch}',
      partyType: 'SUPPLIER',
      partyId: supplierId,
      partyName: supplierName,
      status: status,
      isBalanced: isBalanced,
      totalSourceInvoicesBdt: bills.toStringAsFixed(2),
      totalSettlementsCollectionsBdt: payments.toStringAsFixed(2),
      totalRefundsCreditsBdt: creditNotes.toStringAsFixed(2),
      calculatedBalanceBdt: calculated.toStringAsFixed(2),
      recordedBalanceBdt: recordedBalance.toStringAsFixed(2),
      varianceBdt: variance.toStringAsFixed(2),
      discrepancies: discrepancies,
      reconciledAt: DateTime.now().toIso8601String(),
    );
  }
}
