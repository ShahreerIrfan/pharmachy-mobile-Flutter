/// mobile/lib/core/customers/mobile_customer_receivable_ledger_client.dart
/// Architecture Decision: ADR-0265 (P265).
/// Phase 14: Customers, Suppliers, Dues & Payments.
///
/// Mobile manager client helper for Accounts Receivable (AR) Customer Ledger:
/// - Balance parity calculations.
/// - Adjustment & reversal role authorization.
/// - Running balance tracking.

class MobileCustomerReceivableLedgerClient {
  static const List<String> ledgerAdminRoles = [
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
  ];

  static bool canPostAdjustment(String? role) {
    if (role == null) return false;
    return ledgerAdminRoles.contains(role.trim().toUpperCase());
  }

  static bool canReverseEntry(String? role) {
    if (role == null) return false;
    return ledgerAdminRoles.contains(role.trim().toUpperCase());
  }

  static double calculateRunningBalance(double previousBalance, double debit, double credit) {
    final newBal = previousBalance + debit - credit;
    return newBal < 0.0 ? 0.0 : newBal;
  }

  static bool reconcileParity({
    required double openingBalance,
    required double totalDebits,
    required double totalCredits,
    required double closingBalance,
  }) {
    final expected = openingBalance + totalDebits - totalCredits;
    final clampedExpected = expected < 0.0 ? 0.0 : expected;
    return (clampedExpected - closingBalance).abs() < 0.001;
  }

  static void validateAdjustment({
    required String? direction,
    required double amount,
    required String? reason,
  }) {
    if (direction == null || (direction.toUpperCase() != 'DEBIT' && direction.toUpperCase() != 'CREDIT')) {
      throw ArgumentError("Adjustment direction must be either 'DEBIT' or 'CREDIT'.");
    }
    if (amount <= 0.0) {
      throw ArgumentError('Adjustment amount must be strictly greater than 0.00 BDT.');
    }
    if (reason == null || reason.trim().isEmpty) {
      throw ArgumentError('A documented reason is required for balance adjustment.');
    }
  }
}
