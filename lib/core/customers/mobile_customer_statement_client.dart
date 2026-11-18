/// mobile/lib/core/customers/mobile_customer_statement_client.dart
/// Architecture Decision: ADR-0267 (P267).
/// Phase 14: Customers, Suppliers, Dues & Payments.
///
/// Mobile manager helper for Customer Statements & Due Aging:
/// - Verifies Statement parity (Opening + Charges - Payments == Closing).
/// - 4-tier due aging analysis (Current, 31-60d, 61-90d, 91d+).
/// - Date range validation.

class MobileCustomerStatementClient {
  static const List<String> statementRoles = [
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
    'CASHIER',
    'FINANCE_OFFICER',
    'AUDITOR',
  ];

  static bool canViewStatement(String? role) {
    if (role == null) return false;
    return statementRoles.contains(role.trim().toUpperCase());
  }

  static bool verifyStatementParity({
    required double openingBalance,
    required double totalCharges,
    required double totalPayments,
    required double closingBalance,
  }) {
    final expected = openingBalance + totalCharges - totalPayments;
    final clamped = expected < 0.0 ? 0.0 : expected;
    return (clamped - closingBalance).abs() < 0.001;
  }

  static double sumAgingBuckets({
    required double current,
    required double days31To60,
    required double days61To90,
    required double days91Plus,
  }) {
    final sum = current + days31To60 + days61To90 + days91Plus;
    return double.parse(sum.toStringAsFixed(2));
  }

  static void validateDateRange(String? startDateStr, String? endDateStr) {
    if (startDateStr == null || startDateStr.trim().isEmpty) {
      throw ArgumentError('Start date cannot be empty.');
    }
    if (endDateStr == null || endDateStr.trim().isEmpty) {
      throw ArgumentError('End date cannot be empty.');
    }
    final start = DateTime.tryParse(startDateStr.trim());
    final end = DateTime.tryParse(endDateStr.trim());
    if (start == null || end == null) {
      throw ArgumentError('Invalid date format. Expected YYYY-MM-DD.');
    }
    if (start.isAfter(end)) {
      throw ArgumentError('Start date cannot be later than end date.');
    }
  }
}
