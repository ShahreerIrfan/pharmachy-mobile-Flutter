// lib/core/billing/mobile_manual_payment_client.dart
// Architecture Decision: ADR-0007, ADR-0024 & ADR-0088
// Phase 05: Basic/Standard/Pro Subscription & Billing (P088)

enum MobileManualPaymentStatus {
  pendingVerification,
  approved,
  rejected,
  cancelled,
}

class MobileManualPaymentClaimModel {
  final String claimId;
  final String claimNumber;
  final String tenantId;
  final String invoiceId;
  final String? invoiceNumber;
  final String paymentMethod;
  final String transactionReference;
  final String senderAccountNumber;
  final double claimedAmountBdt;
  final String evidenceFileUrl;
  final String? evidenceNotes;
  final MobileManualPaymentStatus status;
  final String makerUserId;
  final String makerUserEmail;
  final String? checkerUserId;
  final String? checkerUserEmail;
  final String? checkerNotes;
  final String? rejectionReason;
  final DateTime submittedAt;
  final DateTime? verifiedAt;
  final Map<String, dynamic>? activationOutcomes;

  const MobileManualPaymentClaimModel({
    required this.claimId,
    required this.claimNumber,
    required this.tenantId,
    required this.invoiceId,
    this.invoiceNumber,
    required this.paymentMethod,
    required this.transactionReference,
    required this.senderAccountNumber,
    required this.claimedAmountBdt,
    required this.evidenceFileUrl,
    this.evidenceNotes,
    required this.status,
    required this.makerUserId,
    required this.makerUserEmail,
    this.checkerUserId,
    this.checkerUserEmail,
    this.checkerNotes,
    this.rejectionReason,
    required this.submittedAt,
    this.verifiedAt,
    this.activationOutcomes,
  });

  bool get isPending => status == MobileManualPaymentStatus.pendingVerification;
  bool get isApproved => status == MobileManualPaymentStatus.approved;
  bool get isRejected => status == MobileManualPaymentStatus.rejected;
  bool get isCancelled => status == MobileManualPaymentStatus.cancelled;

  /// Enforces Maker-Checker separation invariant: A user cannot self-approve their own claim.
  bool canApprove(String potentialCheckerUserId) {
    if (potentialCheckerUserId.trim().isEmpty) return false;
    return makerUserId.trim() != potentialCheckerUserId.trim();
  }

  static MobileManualPaymentStatus parseStatus(String? statusStr) {
    final clean = (statusStr ?? '').toUpperCase().trim();
    switch (clean) {
      case 'APPROVED':
        return MobileManualPaymentStatus.approved;
      case 'REJECTED':
        return MobileManualPaymentStatus.rejected;
      case 'CANCELLED':
        return MobileManualPaymentStatus.cancelled;
      case 'PENDING_VERIFICATION':
      default:
        return MobileManualPaymentStatus.pendingVerification;
    }
  }

  static String statusToString(MobileManualPaymentStatus status) {
    switch (status) {
      case MobileManualPaymentStatus.approved:
        return 'APPROVED';
      case MobileManualPaymentStatus.rejected:
        return 'REJECTED';
      case MobileManualPaymentStatus.cancelled:
        return 'CANCELLED';
      case MobileManualPaymentStatus.pendingVerification:
      default:
        return 'PENDING_VERIFICATION';
    }
  }

  static String formatBdt(double amount) {
    return '৳ ${amount.toStringAsFixed(2)}';
  }

  factory MobileManualPaymentClaimModel.fromJson(Map<String, dynamic> json) {
    return MobileManualPaymentClaimModel(
      claimId: json['claim_id'] ?? '',
      claimNumber: json['claim_number'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      invoiceId: json['invoice_id'] ?? '',
      invoiceNumber: json['invoice_number'],
      paymentMethod: json['payment_method'] ?? 'BKASH',
      transactionReference: json['transaction_reference'] ?? '',
      senderAccountNumber: json['sender_account_number'] ?? '',
      claimedAmountBdt: double.parse((json['claimed_amount_bdt'] ?? 0.0).toString()),
      evidenceFileUrl: json['evidence_file_url'] ?? '',
      evidenceNotes: json['evidence_notes'],
      status: parseStatus(json['status']?.toString()),
      makerUserId: json['maker_user_id'] ?? '',
      makerUserEmail: json['maker_user_email'] ?? '',
      checkerUserId: json['checker_user_id'],
      checkerUserEmail: json['checker_user_email'],
      checkerNotes: json['checker_notes'],
      rejectionReason: json['rejection_reason'],
      submittedAt: DateTime.parse(json['submitted_at'] ?? '1970-01-01T00:00:00Z'),
      verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at']) : null,
      activationOutcomes: json['activation_outcomes'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'claim_id': claimId,
      'claim_number': claimNumber,
      'tenant_id': tenantId,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'payment_method': paymentMethod,
      'transaction_reference': transactionReference,
      'sender_account_number': senderAccountNumber,
      'claimed_amount_bdt': claimedAmountBdt.toStringAsFixed(2),
      'evidence_file_url': evidenceFileUrl,
      'evidence_notes': evidenceNotes,
      'status': statusToString(status),
      'maker_user_id': makerUserId,
      'maker_user_email': makerUserEmail,
      'checker_user_id': checkerUserId,
      'checker_user_email': checkerUserEmail,
      'checker_notes': checkerNotes,
      'rejection_reason': rejectionReason,
      'submitted_at': submittedAt.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
      'activation_outcomes': activationOutcomes,
    };
  }
}

