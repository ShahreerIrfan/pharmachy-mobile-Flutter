/// mobile/lib/core/customers/mobile_customer_purchase_history_client.dart
/// Architecture Decision: ADR-0263 (P263).
/// Phase 14: Customers, Suppliers, Dues & Payments.
///
/// Mobile owner/manager client helper for Customer Purchase History:
/// - Timeline event filtering (ALL, SALE, RETURN, COLLECTION).
/// - Role-based PHI / PII privacy masking (cashier vs licensed pharmacist/manager).
/// - Strict Decimal/Double net spend calculations and due reconciliations.

class MobileCustomerPurchaseHistoryClient {
  static const List<String> privilegedRoles = [
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
  ];

  static const List<String> validEventTypes = [
    'ALL',
    'SALE',
    'RETURN',
    'COLLECTION',
  ];

  static bool isPrivilegedRole(String? role) {
    if (role == null) return false;
    return privilegedRoles.contains(role.trim().toUpperCase());
  }

  static String buildHistoryUri({
    required String customerId,
    int page = 1,
    int pageSize = 20,
    String eventType = 'ALL',
    String? startDate,
    String? endDate,
    String? branchId,
  }) {
    if (customerId.trim().isEmpty) {
      throw ArgumentError('Customer ID is required.');
    }
    if (page < 1) {
      throw ArgumentError('Page must be >= 1.');
    }
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Page size must be between 1 and 100.');
    }

    final resolvedType = eventType.trim().toUpperCase();
    if (!validEventTypes.contains(resolvedType)) {
      throw ArgumentError('Invalid event_type: $eventType');
    }

    final queryParams = <String>[
      'page=$page',
      'page_size=$pageSize',
      'event_type=$resolvedType',
    ];

    if (startDate != null && startDate.trim().isNotEmpty) {
      _validateDateFormat(startDate.trim());
      queryParams.add('start_date=${startDate.trim()}');
    }

    if (endDate != null && endDate.trim().isNotEmpty) {
      _validateDateFormat(endDate.trim());
      queryParams.add('end_date=${endDate.trim()}');
    }

    if (branchId != null && branchId.trim().isNotEmpty) {
      queryParams.add('branch=${branchId.trim()}');
    }

    return '/api/v2/pos/customers/${customerId.trim()}/purchase-history/?${queryParams.join('&')}';
  }

  static void _validateDateFormat(String dateStr) {
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(dateStr)) {
      throw ArgumentError('Invalid date format. Expected YYYY-MM-DD: $dateStr');
    }
    try {
      DateTime.parse(dateStr);
    } catch (_) {
      throw ArgumentError('Invalid date values: $dateStr');
    }
  }

  static String maskPhoneNumber(String? phone, {String? role}) {
    if (isPrivilegedRole(role)) {
      return phone ?? '';
    }
    if (phone == null || phone.trim().isEmpty) {
      return '';
    }
    final clean = phone.trim();
    if (clean.length <= 6) {
      return '******';
    }
    if (clean.startsWith('+880')) {
      final middleCount = (clean.length - 10).clamp(2, 20);
      final stars = '*' * middleCount;
      return '${clean.substring(0, 6)}$stars${clean.substring(clean.length - 4)}';
    } else if (clean.startsWith('01')) {
      final middleCount = (clean.length - 7).clamp(2, 20);
      final stars = '*' * middleCount;
      return '${clean.substring(0, 3)}$stars${clean.substring(clean.length - 4)}';
    } else {
      return '${clean.substring(0, 2)}****${clean.substring(clean.length - 2)}';
    }
  }

  static double calculateNetSpend(double totalPurchases, double totalReturns) {
    final net = totalPurchases - totalReturns;
    return net < 0.0 ? 0.0 : net;
  }
}

