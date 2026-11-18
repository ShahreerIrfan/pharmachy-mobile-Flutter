/// mobile/lib/core/customers/mobile_partial_collection_client.dart
/// Architecture Decision: ADR-0266 (P266).
/// Phase 14: Customers, Suppliers, Dues & Payments.
///
/// Mobile manager client helper for applying partial collections against original invoices:
/// - Strict overpayment protection (amount <= remainingDue)
/// - Duplicate settlement prevention
/// - Digital tender validation
/// - Reverse collection RBAC verification

class MobilePartialCollectionClient {
  static const List<String> collectionAdminRoles = [
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
  ];

  static const List<String> digitalTenders = [
    'BKASH',
    'NAGAD',
    'ROCKET',
    'UPAY',
    'CARD',
    'BANK_TRANSFER',
  ];

  static bool canReverseCollection(String? role) {
    if (role == null) return false;
    return collectionAdminRoles.contains(role.trim().toUpperCase());
  }

  static double calculateRemainingDue(double currentRemaining, double amountCollected) {
    final rem = currentRemaining - amountCollected;
    if (rem <= 0.001) return 0.0;
    return double.parse(rem.toStringAsFixed(2));
  }

  static bool isSettled(double currentRemaining, double amountCollected) {
    return calculateRemainingDue(currentRemaining, amountCollected) <= 0.001;
  }

  static void validatePartialCollection({
    required double amount,
    required double remainingDue,
    String? tenderType,
    String? gatewayRef,
  }) {
    if (remainingDue <= 0.0) {
      throw StateError('Invoice is already fully settled or has 0.00 BDT remaining due.');
    }
    if (amount <= 0.0) {
      throw ArgumentError('Collection amount must be strictly greater than 0.00 BDT.');
    }
    if (amount > remainingDue + 0.0001) {
      throw ArgumentError(
        'Collection amount (${amount.toStringAsFixed(2)} BDT) exceeds remaining invoice due (${remainingDue.toStringAsFixed(2)} BDT). Overpayments are prohibited.',
      );
    }
    final cleanTender = (tenderType ?? 'CASH').trim().toUpperCase();
    if (cleanTender == 'DUE') {
      throw ArgumentError('Cannot collect customer due balance using DUE tender.');
    }
    if (digitalTenders.contains(cleanTender)) {
      if (gatewayRef == null || gatewayRef.trim().length < 4) {
        throw ArgumentError('$cleanTender collection requires a valid gateway reference (min 4 chars).');
      }
    }
  }
}
