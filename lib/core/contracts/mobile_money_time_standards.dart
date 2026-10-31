/// Architecture Decision: ADR-0055
/// Mobile Client implementation of Time and Money Standards:
/// - 2-decimal scale precision and half-up rounding
/// - Asia/Dhaka (UTC+6) time conversion and formatting
/// - South Asian number grouping (1,52,345.50) and Bengali numeral translation
library;

class MobileMoneyTimeStandards {
  static const String currencyCode = 'BDT';
  static const String currencySymbol = '৳';
  static const int monetaryScale = 2;
  static const Duration dhakaOffset = Duration(hours: 6);

  static const List<String> bnDigits = [
    '০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'
  ];

  static String toBengaliDigits(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final codeUnit = char.codeUnitAt(0);
      if (codeUnit >= 48 && codeUnit <= 57) {
        buffer.write(bnDigits[codeUnit - 48]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static String formatSouthAsian(double amount) {
    final sign = amount < 0 ? '-' : '';
    final absAmount = amount.abs();
    final fixedStr = absAmount.toStringAsFixed(monetaryScale);
    final parts = fixedStr.split('.');
    final integerPart = parts[0];
    final fractionPart = parts[1];

    String groupedInteger;
    if (integerPart.length <= 3) {
      groupedInteger = integerPart;
    } else {
      final lastThree = integerPart.substring(integerPart.length - 3);
      var remaining = integerPart.substring(0, integerPart.length - 3);
      final groups = <String>[];
      while (remaining.length > 2) {
        groups.insert(0, remaining.substring(remaining.length - 2));
        remaining = remaining.substring(0, remaining.length - 2);
      }
      if (remaining.isNotEmpty) {
        groups.insert(0, remaining);
      }
      groups.add(lastThree);
      groupedInteger = groups.join(',');
    }

    return '$sign$groupedInteger.$fractionPart';
  }

  static String formatBdt(double amount, {bool inBengali = false}) {
    final formatted = formatSouthAsian(amount);
    if (inBengali) {
      return '$currencySymbol${toBengaliDigits(formatted)}';
    }
    return '$currencySymbol $formatted';
  }

  static DateTime toDhaka(DateTime utcDateTime) {
    final utc = utcDateTime.isUtc ? utcDateTime : utcDateTime.toUtc();
    return utc.add(dhakaOffset);
  }

  static String formatDhakaDisplay(
    DateTime utcDateTime, {
    bool includeTime = true,
    bool inBengali = false,
  }) {
    final dhaka = toDhaka(utcDateTime);
    final day = dhaka.day.toString().padLeft(2, '0');
    final month = dhaka.month.toString().padLeft(2, '0');
    final year = dhaka.year.toString();

    if (!includeTime) {
      final dateStr = '$day/$month/$year';
      return inBengali ? toBengaliDigits(dateStr) : dateStr;
    }

    final hour24 = dhaka.hour;
    final minute = dhaka.minute.toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    final periodBn = hour24 < 12 ? 'পূর্বাহ্ণ' : 'অপরাহ্ণ';
    final hour12 = (hour24 % 12 == 0 ? 12 : hour24 % 12).toString().padLeft(2, '0');

    if (inBengali) {
      final timeStr =
          '${toBengaliDigits(day)}/${toBengaliDigits(month)}/${toBengaliDigits(year)} '
          '${toBengaliDigits(hour12)}:${toBengaliDigits(minute)} $periodBn';
      return timeStr;
    }

    return '$day/$month/$year $hour12:$minute $period';
  }

  static bool isBatchExpired(DateTime expiryDate, {DateTime? referenceUtc}) {
    final ref = referenceUtc != null ? toDhaka(referenceUtc) : toDhaka(DateTime.now().toUtc());
    final refDateOnly = DateTime(ref.year, ref.month, ref.day);
    final expDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expDateOnly.isBefore(refDateOnly);
  }

  static MobileInvoiceSummary calculateInvoice({
    required List<MobileCartItem> items,
    double discount = 0.0,
    double paid = 0.0,
  }) {
    if (items.isEmpty) {
      throw ArgumentError('Cart items cannot be empty.');
    }

    double subtotal = 0.0;
    double totalVat = 0.0;

    for (final item in items) {
      subtotal += item.lineSubtotal;
      totalVat += item.lineVat;
    }

    final netTaxable = (subtotal - discount) > 0 ? (subtotal - discount) : 0.0;
    final grandTotal = netTaxable + totalVat;
    final due = (grandTotal - paid) > 0 ? (grandTotal - paid) : 0.0;
    final change = (paid - grandTotal) > 0 ? (paid - grandTotal) : 0.0;

    return MobileInvoiceSummary(
      itemCount: items.length,
      subtotal: double.parse(subtotal.toStringAsFixed(2)),
      discount: double.parse(discount.toStringAsFixed(2)),
      totalVat: double.parse(totalVat.toStringAsFixed(2)),
      grandTotal: double.parse(grandTotal.toStringAsFixed(2)),
      paidAmount: double.parse(paid.toStringAsFixed(2)),
      dueAmount: double.parse(due.toStringAsFixed(2)),
      changeAmount: double.parse(change.toStringAsFixed(2)),
      createdAtUtc: DateTime.now().toUtc(),
    );
  }
}

class MobileCartItem {
  final String medicineId;
  final String brandName;
  final int quantity;
  final double unitPrice;
  final double vatRate;

  const MobileCartItem({
    required this.medicineId,
    required this.brandName,
    required this.quantity,
    required this.unitPrice,
    this.vatRate = 0.0,
  });

  double get lineSubtotal =>
      double.parse((unitPrice * quantity).toStringAsFixed(2));

  double get lineVat =>
      double.parse((lineSubtotal * vatRate).toStringAsFixed(2));

  double get lineTotal =>
      double.parse((lineSubtotal + lineVat).toStringAsFixed(2));
}

class MobileInvoiceSummary {
  final int itemCount;
  final double subtotal;
  final double discount;
  final double totalVat;
  final double grandTotal;
  final double paidAmount;
  final double dueAmount;
  final double changeAmount;
  final DateTime createdAtUtc;

  const MobileInvoiceSummary({
    required this.itemCount,
    required this.subtotal,
    required this.discount,
    required this.totalVat,
    required this.grandTotal,
    required this.paidAmount,
    required this.dueAmount,
    required this.changeAmount,
    required this.createdAtUtc,
  });

  String get formattedGrandTotalEn =>
      MobileMoneyTimeStandards.formatBdt(grandTotal, inBengali: false);

  String get formattedGrandTotalBn =>
      MobileMoneyTimeStandards.formatBdt(grandTotal, inBengali: true);

  String get dhakaDisplayEn =>
      MobileMoneyTimeStandards.formatDhakaDisplay(createdAtUtc, inBengali: false);

  String get dhakaDisplayBn =>
      MobileMoneyTimeStandards.formatDhakaDisplay(createdAtUtc, inBengali: true);
}
