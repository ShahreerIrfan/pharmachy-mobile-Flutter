import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_money_time_standards.dart';

void main() {
  group('ADR-0055: Mobile Time and Money Standards Tests', () {
    test('formats South Asian Lakh/Crore grouping accurately', () {
      final formatted = MobileMoneyTimeStandards.formatSouthAsian(152345.50);
      expect(formatted, equals('1,52,345.50'));

      final bdtEn = MobileMoneyTimeStandards.formatBdt(152345.50, inBengali: false);
      expect(bdtEn, equals('৳ 1,52,345.50'));

      final bdtBn = MobileMoneyTimeStandards.formatBdt(152345.50, inBengali: true);
      expect(bdtBn, equals('৳১,৫২,৩৪৫.৫০'));
    });

    test('converts UTC DateTime to Asia/Dhaka (+06:00)', () {
      // 2026-10-31T06:00:00Z -> 12:00 PM Dhaka
      final utcTime = DateTime.utc(2026, 10, 31, 6, 0, 0);
      final dhakaTime = MobileMoneyTimeStandards.toDhaka(utcTime);

      expect(dhakaTime.hour, equals(12));
      expect(dhakaTime.minute, equals(0));

      final displayEn = MobileMoneyTimeStandards.formatDhakaDisplay(utcTime, inBengali: false);
      expect(displayEn, contains('31/10/2026'));
      expect(displayEn, contains('12:00 PM'));
    });

    test('evaluates medicine batch expiry against Dhaka reference date', () {
      final referenceUtc = DateTime.utc(2026, 10, 31, 10, 0, 0);
      final expiredBatch = DateTime(2026, 10, 30);
      final validBatch = DateTime(2026, 11, 1);

      expect(
        MobileMoneyTimeStandards.isBatchExpired(expiredBatch, referenceUtc: referenceUtc),
        isTrue,
      );
      expect(
        MobileMoneyTimeStandards.isBatchExpired(validBatch, referenceUtc: referenceUtc),
        isFalse,
      );
    });

    test('calculates mobile invoice totals with deterministic precision', () {
      final items = [
        const MobileCartItem(
          medicineId: 'MED-001',
          brandName: 'Napa Extra',
          quantity: 10,
          unitPrice: 2.50,
          vatRate: 0.05,
        ),
        const MobileCartItem(
          medicineId: 'MED-002',
          brandName: 'Seclo 20',
          quantity: 2,
          unitPrice: 80.00,
          vatRate: 0.05,
        ),
      ];

      final summary = MobileMoneyTimeStandards.calculateInvoice(
        items: items,
        discount: 10.00,
        paid: 200.00,
      );

      expect(summary.subtotal, equals(185.00));
      expect(summary.discount, equals(10.00));
      expect(summary.totalVat, equals(9.25));
      expect(summary.grandTotal, equals(184.25));
      expect(summary.paidAmount, equals(200.00));
      expect(summary.dueAmount, equals(0.00));
      expect(summary.changeAmount, equals(15.75));
    });
  });
}
