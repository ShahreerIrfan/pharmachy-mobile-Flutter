/// mobile/lib/core/customers/mobile_customer_master_client.dart
/// Architecture Decision: ADR-0261 (P261).
/// Phase 14: Customers, Suppliers, Dues & Payments.
///
/// Mobile client helper for Customer Master management:
/// - Credit status authorization gates.
/// - Privacy preferences & consent handling.
/// - Phone duplicate & format validations.

class MobileCustomerMasterClient {
  static const List<String> creditAdminRoles = [
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
  ];

  static const List<String> validCreditStatuses = [
    'UNAPPROVED',
    'PENDING_APPROVAL',
    'APPROVED',
    'SUSPENDED',
  ];

  static bool canManageCreditLimit(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return creditAdminRoles.contains(r);
  }

  static bool canArchiveCustomer(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return creditAdminRoles.contains(r);
  }

  static Map<String, dynamic> defaultPrivacyPreferences() {
    return {
      'sms_receipts': true,
      'marketing_opt_in': false,
      'data_retention_consent': true,
    };
  }

  static void validateCustomerData({
    required String? fullName,
    String? phone,
    String? creditLimitStr,
    int creditTermsDays = 30,
  }) {
    if (fullName == null || fullName.trim().isEmpty) {
      throw ArgumentError('Customer full_name is required.');
    }
    if (creditTermsDays < 1) {
      throw ArgumentError('credit_terms_days must be at least 1.');
    }
    if (creditLimitStr != null && creditLimitStr.trim().isNotEmpty) {
      final limit = double.tryParse(creditLimitStr.trim());
      if (limit == null || limit < 0.0) {
        throw ArgumentError('credit_limit_bdt must be a valid non-negative amount.');
      }
    }
    if (phone != null && phone.trim().isNotEmpty) {
      final clean = phone.trim();
      if (clean.length < 7 || clean.length > 20) {
        throw ArgumentError('Phone number length must be between 7 and 20 digits.');
      }
    }
  }

  static String formatCreditStatusDisplay(String? status, {String lang = 'en'}) {
    if (status == null) return '';
    final isBn = lang.toLowerCase() == 'bn';
    switch (status.trim().toUpperCase()) {
      case 'APPROVED':
        return isBn ? 'অনুমোদিত' : 'Approved';
      case 'PENDING_APPROVAL':
        return isBn ? 'অনুমোদন প্রক্রিয়াধীন' : 'Pending Approval';
      case 'SUSPENDED':
        return isBn ? 'স্থগিত' : 'Suspended';
      case 'UNAPPROVED':
      default:
        return isBn ? 'অননুমোদিত' : 'Unapproved';
    }
  }

  static String formatCustomerSummary({
    required String? customerId,
    required String? fullName,
    String? phone,
    String? creditStatus,
    String? currentDueBdt,
    String lang = 'en',
  }) {
    final isBn = lang.toLowerCase() == 'bn';
    final id = customerId ?? 'NEW';
    final name = fullName ?? 'Customer';
    final ph = (phone != null && phone.trim().isNotEmpty) ? phone : (isBn ? 'ফোন নেই' : 'No Phone');
    final statusDisplay = formatCreditStatusDisplay(creditStatus, lang: lang);
    final due = currentDueBdt ?? '0.00';

    if (isBn) {
      return '[$id] $name ($ph) | ক্রেডিট: $statusDisplay | বকেয়া: $due ৳';
    }
    return '[$id] $name ($ph) | Credit: $statusDisplay | Due: $due BDT';
  }
}

