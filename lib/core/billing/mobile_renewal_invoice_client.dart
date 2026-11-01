// lib/core/billing/mobile_renewal_invoice_client.dart
// Architecture Decision: ADR-0007, ADR-0024 & ADR-0087
// Phase 05: Basic/Standard/Pro Subscription & Billing (P087)

enum MobileRenewalInvoiceStatus {
  draft,
  issued,
  paid,
  voided,
  pastDue,
}

class InvoiceTotalsCalculation {
  final double subtotalBdt;
  final double discountBdt;
  final double taxRatePercent;
  final double taxAmountBdt;
  final double totalBdt;

  const InvoiceTotalsCalculation({
    required this.subtotalBdt,
    required this.discountBdt,
    required this.taxRatePercent,
    required this.taxAmountBdt,
    required this.totalBdt,
  });
}

class MobileRenewalInvoiceModel {
  final String invoiceId;
  final String referenceNumber;
  final String tenantId;
  final String planCode;
  final String billingCycle;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double subtotalAmount;
  final double discountAmount;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;
  final String currency;
  final MobileRenewalInvoiceStatus paymentStatus;
  final DateTime? issuedAt;
  final DateTime? paidAt;
  final String? paymentReference;
  final String? paymentMethod;
  final List<Map<String, dynamic>> statusHistory;

  const MobileRenewalInvoiceModel({
    required this.invoiceId,
    required this.referenceNumber,
    required this.tenantId,
    required this.planCode,
    required this.billingCycle,
    required this.periodStart,
    required this.periodEnd,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.totalAmount,
    this.currency = 'BDT',
    required this.paymentStatus,
    this.issuedAt,
    this.paidAt,
    this.paymentReference,
    this.paymentMethod,
    this.statusHistory = const [],
  });

  bool get isPayable =>
      paymentStatus == MobileRenewalInvoiceStatus.issued ||
      paymentStatus == MobileRenewalInvoiceStatus.pastDue;

  bool get isPaid => paymentStatus == MobileRenewalInvoiceStatus.paid;

  static MobileRenewalInvoiceStatus parseStatus(String? statusStr) {
    final clean = (statusStr ?? '').toUpperCase().trim();
    switch (clean) {
      case 'ISSUED':
        return MobileRenewalInvoiceStatus.issued;
      case 'PAID':
        return MobileRenewalInvoiceStatus.paid;
      case 'VOID':
      case 'VOIDED':
        return MobileRenewalInvoiceStatus.voided;
      case 'PAST_DUE':
        return MobileRenewalInvoiceStatus.pastDue;
      case 'DRAFT':
      default:
        return MobileRenewalInvoiceStatus.draft;
    }
  }

  static String statusToString(MobileRenewalInvoiceStatus status) {
    switch (status) {
      case MobileRenewalInvoiceStatus.issued:
        return 'ISSUED';
      case MobileRenewalInvoiceStatus.paid:
        return 'PAID';
      case MobileRenewalInvoiceStatus.voided:
        return 'VOID';
      case MobileRenewalInvoiceStatus.pastDue:
        return 'PAST_DUE';
      case MobileRenewalInvoiceStatus.draft:
      default:
        return 'DRAFT';
    }
  }

  static InvoiceTotalsCalculation calculateTotals({
    required double monthlyRate,
    required String cycle,
    double taxRate = 5.0,
  }) {
    final cleanCycle = cycle.toUpperCase().trim();
    final double subtotal;
    final double discount;

    if (cleanCycle == 'ANNUAL') {
      subtotal = double.parse((monthlyRate * 12.0).toStringAsFixed(2));
      // 2 months free prepay discount
      discount = double.parse((monthlyRate * 2.0).toStringAsFixed(2));
    } else {
      subtotal = double.parse(monthlyRate.toStringAsFixed(2));
      discount = 0.0;
    }

    final taxable = (subtotal - discount) > 0 ? (subtotal - discount) : 0.0;
    final tax = double.parse(((taxable * taxRate) / 100.0).toStringAsFixed(2));
    final total = double.parse((taxable + tax).toStringAsFixed(2));

    return InvoiceTotalsCalculation(
      subtotalBdt: subtotal,
      discountBdt: discount,
      taxRatePercent: taxRate,
      taxAmountBdt: tax,
      totalBdt: total,
    );
  }

  static String formatBdt(double amount) {
    return '৳ ${amount.toStringAsFixed(2)}';
  }

  factory MobileRenewalInvoiceModel.fromJson(Map<String, dynamic> json) {
    return MobileRenewalInvoiceModel(
      invoiceId: json['invoice_id'] ?? '',
      referenceNumber: json['invoice_number'] ?? json['reference_number'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      planCode: json['plan_tier'] ?? json['plan_code'] ?? '',
      billingCycle: json['billing_cycle'] ?? 'MONTHLY',
      periodStart: DateTime.parse(json['period_start'] ?? '1970-01-01T00:00:00Z'),
      periodEnd: DateTime.parse(json['period_end'] ?? '1970-01-01T00:00:00Z'),
      subtotalAmount: double.parse((json['subtotal_bdt'] ?? json['subtotal_amount'] ?? 0.0).toString()),
      discountAmount: double.parse((json['discount_bdt'] ?? json['discount_amount'] ?? 0.0).toString()),
      taxRate: double.parse((json['tax_rate_percent'] ?? json['tax_rate'] ?? 5.0).toString()),
      taxAmount: double.parse((json['tax_amount_bdt'] ?? json['tax_amount'] ?? 0.0).toString()),
      totalAmount: double.parse((json['total_bdt'] ?? json['total_amount'] ?? 0.0).toString()),
      currency: json['currency'] ?? 'BDT',
      paymentStatus: parseStatus((json['status'] ?? json['payment_status'])?.toString()),
      issuedAt: json['issued_at'] != null ? DateTime.parse(json['issued_at']) : null,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      paymentReference: json['payment_reference'],
      paymentMethod: json['payment_method'],
      statusHistory: ((json['status_history'] ?? json['status_history_json']) as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'reference_number': referenceNumber,
      'tenant_id': tenantId,
      'plan_code': planCode,
      'billing_cycle': billingCycle,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'subtotal_amount': subtotalAmount,
      'discount_amount': discountAmount,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'currency': currency,
      'payment_status': statusToString(paymentStatus),
      'issued_at': issuedAt?.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'payment_reference': paymentReference,
      'payment_method': paymentMethod,
      'status_history_json': statusHistory,
    };
  }
}
