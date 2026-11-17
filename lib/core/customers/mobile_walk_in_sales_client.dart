/// mobile/lib/core/customers/mobile_walk_in_sales_client.dart
/// Architecture Decision: ADR-0262 (P262).
/// Phase 14: Customers, Suppliers, Dues & Payments.
///
/// Mobile helper for privacy-preserving walk-in anonymous counter sales:
/// - Anonymous sale detection.
/// - Immediate blocking of credit/due tender for walk-in customers.
/// - Clean privacy-preserved receipt banners.

class MobileWalkInSalesClient {
  static const String defaultWalkInName = 'Walk-in Customer';
  static const String defaultWalkInNameBn = 'ওয়াক-ইন ক্রেতা';

  static bool isWalkInCustomer(String? customerId) {
    if (customerId == null) return true;
    final clean = customerId.trim();
    return clean.isEmpty || clean.toUpperCase() == 'WALK_IN';
  }

  static bool canTenderCredit(String? customerId) {
    return !isWalkInCustomer(customerId);
  }

  static void validateWalkInTender(String? customerId, String? paymentMethod) {
    if (paymentMethod != null && paymentMethod.trim().toUpperCase() == 'DUE') {
      if (isWalkInCustomer(customerId)) {
        throw ArgumentError(
          'Credit/due sales are strictly prohibited for anonymous walk-in customers.',
        );
      }
    }
  }

  static String getCustomerDisplayName(String? customerName, {String lang = 'en'}) {
    final isBn = lang.toLowerCase() == 'bn';
    if (customerName == null || customerName.trim().isEmpty) {
      return isBn ? defaultWalkInNameBn : defaultWalkInName;
    }
    return customerName.trim();
  }

  static String formatReceiptBanner({
    required String? orderNumber,
    String? customerName,
    bool isAnonymous = true,
    String lang = 'en',
  }) {
    final isBn = lang.toLowerCase() == 'bn';
    final ord = orderNumber ?? 'SO-COUNTER';
    final name = getCustomerDisplayName(customerName, lang: lang);

    if (isBn) {
      return isAnonymous
          ? 'ক্যাশ মেমো [$ord] | সাধারণ ওয়াক-ইন বিক্রয় (তথ্য সংরক্ষিত)'
          : 'ক্যাশ মেমো [$ord] | গ্রাহক: $name';
    }
    return isAnonymous
        ? 'CASH MEMO [$ord] | Anonymous Counter Sale (Privacy Preserved)'
        : 'CASH MEMO [$ord] | Customer: $name';
  }
}

