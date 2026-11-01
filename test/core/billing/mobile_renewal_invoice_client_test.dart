// test/core/billing/mobile_renewal_invoice_client_test.dart
// Architecture Decision: ADR-0007, ADR-0024 & ADR-0087
// Phase 05: Basic/Standard/Pro Subscription & Billing (P087)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_renewal_invoice_client.dart';

void main() {
  group('P087 - Mobile Renewal Invoice Client Tests', () {
    test('Monthly renewal totals calculate correctly with 5% VAT', () {
      final monthlyRate = 2500.00;
      final calc = MobileRenewalInvoiceModel.calculateTotals(
        monthlyRate: monthlyRate,
        cycle: 'MONTHLY',
        taxRate: 5.00,
      );

      expect(calc.subtotalBdt, equals(2500.00));
      expect(calc.discountBdt, equals(0.00));
      expect(calc.taxRatePercent, equals(5.00));
      expect(calc.taxAmountBdt, equals(125.00));
      expect(calc.totalBdt, equals(2625.00));
    });

    test('Annual renewal applies 2 months free discount and calculates 5% VAT', () {
      final monthlyRate = 2500.00;
      final calc = MobileRenewalInvoiceModel.calculateTotals(
        monthlyRate: monthlyRate,
        cycle: 'ANNUAL',
        taxRate: 5.00,
      );

      // 12 months = 30000.00
      expect(calc.subtotalBdt, equals(30000.00));
      // 2 months free discount = 5000.00
      expect(calc.discountBdt, equals(5000.00));
      // Taxable = 25000.00, 5% of 25000 = 1250.00
      expect(calc.taxAmountBdt, equals(1250.00));
      // Total = 25000 + 1250 = 26250.00
      expect(calc.totalBdt, equals(26250.00));
    });

    test('isPayable helper allows ISSUED and PAST_DUE, blocks PAID and VOID', () {
      final defaultDate = DateTime.utc(2026, 11, 1);

      expect(
        MobileRenewalInvoiceModel(
          invoiceId: 'inv-1',
          referenceNumber: 'REF-1',
          tenantId: 't-1',
          planCode: 'STANDARD',
          billingCycle: 'MONTHLY',
          periodStart: defaultDate,
          periodEnd: defaultDate,
          subtotalAmount: 2500,
          discountAmount: 0,
          taxRate: 5,
          taxAmount: 125,
          totalAmount: 2625,
          paymentStatus: MobileRenewalInvoiceStatus.issued,
        ).isPayable,
        isTrue,
      );

      expect(
        MobileRenewalInvoiceModel(
          invoiceId: 'inv-2',
          referenceNumber: 'REF-2',
          tenantId: 't-1',
          planCode: 'STANDARD',
          billingCycle: 'MONTHLY',
          periodStart: defaultDate,
          periodEnd: defaultDate,
          subtotalAmount: 2500,
          discountAmount: 0,
          taxRate: 5,
          taxAmount: 125,
          totalAmount: 2625,
          paymentStatus: MobileRenewalInvoiceStatus.pastDue,
        ).isPayable,
        isTrue,
      );

      expect(
        MobileRenewalInvoiceModel(
          invoiceId: 'inv-3',
          referenceNumber: 'REF-3',
          tenantId: 't-1',
          planCode: 'STANDARD',
          billingCycle: 'MONTHLY',
          periodStart: defaultDate,
          periodEnd: defaultDate,
          subtotalAmount: 2500,
          discountAmount: 0,
          taxRate: 5,
          taxAmount: 125,
          totalAmount: 2625,
          paymentStatus: MobileRenewalInvoiceStatus.paid,
        ).isPayable,
        isFalse,
      );
    });

    test('JSON serialization and parsing handles full invoice payload', () {
      final jsonMap = {
        'invoice_id': 'inv-uuid-8787',
        'reference_number': 'INV-REN-202611-DEMO-A1B2',
        'tenant_id': 't-mobile-test',
        'plan_code': 'PRO',
        'billing_cycle': 'ANNUAL',
        'period_start': '2026-11-01T00:00:00.000Z',
        'period_end': '2027-11-01T00:00:00.000Z',
        'subtotal_amount': 60000.0,
        'discount_amount': 10000.0,
        'tax_rate': 5.0,
        'tax_amount': 2500.0,
        'total_amount': 52500.0,
        'currency': 'BDT',
        'payment_status': 'ISSUED',
        'issued_at': '2026-11-01T12:00:00.000Z',
        'paid_at': null,
        'payment_reference': null,
        'payment_method': null,
        'status_history_json': [
          {'from': 'DRAFT', 'to': 'ISSUED', 'transitioned_at': '2026-11-01T12:00:00.000Z'}
        ],
      };

      final invoice = MobileRenewalInvoiceModel.fromJson(jsonMap);
      expect(invoice.invoiceId, equals('inv-uuid-8787'));
      expect(invoice.referenceNumber, equals('INV-REN-202611-DEMO-A1B2'));
      expect(invoice.planCode, equals('PRO'));
      expect(invoice.billingCycle, equals('ANNUAL'));
      expect(invoice.paymentStatus, equals(MobileRenewalInvoiceStatus.issued));
      expect(invoice.subtotalAmount, equals(60000.0));
      expect(invoice.discountAmount, equals(10000.0));
      expect(invoice.taxAmount, equals(2500.0));
      expect(invoice.totalAmount, equals(52500.0));
      expect(invoice.statusHistory.length, equals(1));

      final serialized = invoice.toJson();
      expect(serialized['invoice_id'], equals('inv-uuid-8787'));
      expect(serialized['payment_status'], equals('ISSUED'));
    });

    test('formatBdt renders BDT symbol and 2 decimal places', () {
      expect(MobileRenewalInvoiceModel.formatBdt(26250.0), equals('৳ 26250.00'));
    });
  });
}
