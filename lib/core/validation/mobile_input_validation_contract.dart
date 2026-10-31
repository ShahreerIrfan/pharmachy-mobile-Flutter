/// Flutter Mobile Manager Input Validation Contract & Guardrails.
/// Architecture Decision: ADR-0014 & ADR-0046.
class MobileValidationError {
  final String errorCode;
  final String messageEn;
  final String messageBn;
  final Map<String, List<String>> fieldErrors;
  final bool isRetryable;

  const MobileValidationError({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
    this.fieldErrors = const {},
    this.isRetryable = false,
  });

  factory MobileValidationError.fromJson(Map<String, dynamic> json) {
    final code = json['error_code'] as String? ??
        json['code'] as String? ??
        'ERR_VALIDATION_FAILED';
    final msgEn = json['message_en'] as String? ??
        json['message'] as String? ??
        'Validation failed.';
    final msgBn =
        json['message_bn'] as String? ?? 'তথ্য যাচাইকরণ ব্যর্থ হয়েছে।';
    final retryable =
        json['is_retryable'] as bool? ?? json['retryable'] as bool? ?? false;

    final fieldErrors = <String, List<String>>{};
    final detailsObj = json['field_errors'] ?? json['details'];
    if (detailsObj is Map<String, dynamic>) {
      for (final entry in detailsObj.entries) {
        if (entry.value is List) {
          fieldErrors[entry.key] =
              (entry.value as List).map((e) => e.toString()).toList();
        } else if (entry.value != null) {
          fieldErrors[entry.key] = [entry.value.toString()];
        }
      }
    }

    return MobileValidationError(
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
      fieldErrors: fieldErrors,
      isRetryable: retryable,
    );
  }

  String localizedMessage(String locale) {
    return locale.toLowerCase().startsWith('bn') ? messageBn : messageEn;
  }
}

class MobileInputValidationContract {
  static final RegExp _bdPhonePattern = RegExp(r'^\+8801[3-9]\d{8}$');

  /// Validates that an amount string or num parses to a positive Decimal with <= 2 decimals.
  static double validateMoney(num amount, {String fieldName = 'amount'}) {
    if (amount < 0) {
      throw FormatException('$fieldName cannot be negative: $amount');
    }
    // Check decimal places
    final str = amount.toString();
    if (str.contains('.')) {
      final decimals = str.split('.')[1];
      if (decimals.length > 2) {
        throw FormatException(
            '$fieldName cannot have more than 2 decimal places: $amount');
      }
    }
    return amount.toDouble();
  }

  /// Validates positive integers for prescription or invoice quantities.
  static int validateQuantity(int quantity, {String fieldName = 'quantity'}) {
    if (quantity <= 0) {
      throw FormatException(
          '$fieldName must be strictly positive (>0). Received: $quantity');
    }
    if (quantity > 1000000) {
      throw FormatException('$fieldName exceeds maximum allowable limit.');
    }
    return quantity;
  }

  /// Normalizes and validates Bangladesh mobile numbers (+8801[3-9]\d{8}).
  static String validatePhone(String rawPhone) {
    if (rawPhone.trim().isEmpty) return '';
    var cleaned = rawPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    if (cleaned.startsWith('01')) {
      cleaned = '+88$cleaned';
    } else if (cleaned.startsWith('880')) {
      cleaned = '+$cleaned';
    } else if (cleaned.startsWith('1')) {
      cleaned = '+880$cleaned';
    }

    if (!_bdPhonePattern.hasMatch(cleaned)) {
      throw FormatException(
          "Invalid Bangladesh phone number: '$rawPhone'. Must match +8801[3-9]XXXXXXXX.");
    }
    return cleaned;
  }

  /// Validates discount does not exceed gross total amount.
  static void validateDiscount(double total, double discount) {
    validateMoney(total, fieldName: 'total');
    validateMoney(discount, fieldName: 'discount');
    if (discount > total) {
      throw FormatException(
          'Discount ($discount) cannot exceed gross total ($total).');
    }
  }

  /// Validates batch expiry date is on or after reference date.
  static DateTime validateExpiryDate(DateTime expiry, DateTime reference) {
    final expOnly = DateTime(expiry.year, expiry.month, expiry.day);
    final refOnly = DateTime(reference.year, reference.month, reference.day);
    if (expOnly.isBefore(refOnly)) {
      throw FormatException(
          'Expiry date $expOnly is in the past. Dispensing expired stock is prohibited.');
    }
    return expiry;
  }
}
