/// mobile_permission_matrix.dart
///
/// Architecture Decision: ADR-0005 & ADR-0059
/// Mobile Permission Matrix & Least Privilege Enforcer for Pharmacy Manager App.
/// Guarantees:
///   - Least-privilege role boundaries for mobile users.
///   - Absolute system blocks preventing client-side destructive deletes of posted records.
///   - Sensitive field masking for purchase cost prices and patient PII.
library mobile_permission_matrix;

class MobilePermissionResult {
  final bool isAllowed;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobilePermissionResult({
    required this.isAllowed,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobilePermissionResult.allow() {
    return const MobilePermissionResult(
      isAllowed: true,
      errorCode: null,
      messageEn: 'Action permitted under role policy.',
      messageBn: 'রোল নীতিমালা অনুযায়ী কাজটি অনুমোদিত।',
    );
  }

  factory MobilePermissionResult.deny({
    required String code,
    required String messageEn,
    required String messageBn,
  }) {
    return MobilePermissionResult(
      isAllowed: false,
      errorCode: code,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }
}

class MobilePermissionMatrix {
  static const Set<String> costPriceExemptRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
    'SUPERADMIN',
  };

  static const Set<String> piiExemptRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
    'AUDITOR',
    'SUPERADMIN',
  };

  static const List<String> absoluteBlockPaths = [
    '/api/v2/invoices',
    '/api/v2/batches',
    '/api/v2/prescriptions',
    '/api/v2/audit-logs',
  ];

  static bool isAbsoluteBlocked(String method, String path) {
    if (method.toUpperCase().trim() == 'DELETE') {
      final cleanPath = path.trim().toLowerCase();
      for (final blocked in absoluteBlockPaths) {
        if (cleanPath.contains(blocked.replaceFirst('/api/v2/', ''))) {
          return true;
        }
      }
    }
    return false;
  }

  static MobilePermissionResult evaluateAccess({
    required String role,
    required String method,
    required String path,
    String? userBranchId,
    String? targetBranchId,
    String planTier = 'BASIC',
  }) {
    final cleanRole = role.toUpperCase().trim();
    final cleanMethod = method.toUpperCase().trim();
    final cleanPath = path.trim().toLowerCase();

    // 1. Role presence check
    if (cleanRole.isEmpty) {
      return MobilePermissionResult.deny(
        code: 'UNAUTHENTICATED',
        messageEn: 'Authentication required for mobile request.',
        messageBn: 'মোবাইল রিকোয়েস্টের জন্য প্রবেশাধিকার প্রয়োজন।',
      );
    }

    // 2. Absolute system blocks
    if (isAbsoluteBlocked(cleanMethod, cleanPath)) {
      return MobilePermissionResult.deny(
        code: 'ABSOLUTE_SYSTEM_BLOCK',
        messageEn: 'Absolute Block: Destructive deletion of posted records is prohibited.',
        messageBn: 'চূড়ান্ত নিষেধাজ্ঞা: পোস্ট করা রেকর্ড ডিলিট করা সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    // 3. Cashier least-privilege boundary
    if (cleanRole == 'CASHIER') {
      if (cleanMethod == 'DELETE') {
        return MobilePermissionResult.deny(
          code: 'ROLE_PERMISSION_DENIED',
          messageEn: 'Cashier is not permitted to delete resources.',
          messageBn: 'ক্যাশিয়ারের কোনো রিসোর্স ডিলিট করার অনুমতি নেই।',
        );
      }
      if (cleanPath.contains('audit-logs') ||
          cleanPath.contains('secrets') ||
          cleanPath.contains('subscriptions')) {
        return MobilePermissionResult.deny(
          code: 'ROLE_PERMISSION_DENIED',
          messageEn: 'Administrative endpoints forbidden for Cashier role.',
          messageBn: 'ক্যাশিয়ারের প্রশাসনিক এন্ডপয়েন্টে প্রবেশের অনুমতি নেই।',
        );
      }
    }

    // 4. Branch boundary check
    if (cleanRole == 'CASHIER' || cleanRole == 'STAFF_PHARMACIST') {
      if (userBranchId != null &&
          targetBranchId != null &&
          userBranchId.isNotEmpty &&
          targetBranchId.isNotEmpty &&
          userBranchId.trim() != targetBranchId.trim()) {
        return MobilePermissionResult.deny(
          code: 'FORBIDDEN_BRANCH_BOUNDARY',
          messageEn: 'Cross-branch access violation on mobile client.',
          messageBn: 'মোবাইল ক্লায়েন্টে আন্তঃশাখা প্রবেশাধিকার লঙ্ঘন হয়েছে।',
        );
      }
    }

    // 5. Plan tier check
    if (cleanPath.contains('chain-wide') && planTier.toUpperCase().trim() != 'PRO') {
      return MobilePermissionResult.deny(
        code: 'INSUFFICIENT_PLAN_TIER',
        messageEn: 'Chain-wide multi-branch analytics requires PRO subscription.',
        messageBn: 'চেইন-ওয়াইড মাল্টি-শাখা অ্যানালিটিক্সের জন্য প্রো সাবস্ক্রিপশন প্রয়োজন।',
      );
    }

    return MobilePermissionResult.allow();
  }

  static String maskFieldValue(String fieldName, String rawValue, String role) {
    final cleanField = fieldName.toLowerCase().trim();
    final cleanRole = role.toUpperCase().trim();

    // Purchase cost prices
    if (cleanField.contains('cost_price') ||
        cleanField.contains('purchase_price') ||
        cleanField.contains('lot_cost')) {
      if (costPriceExemptRoles.contains(cleanRole)) {
        return rawValue;
      }
      return '***REDACTED***';
    }

    // Customer phone numbers
    if (cleanField.contains('phone') || cleanField.contains('mobile')) {
      if (piiExemptRoles.contains(cleanRole)) {
        return rawValue;
      }
      if (rawValue.length >= 11) {
        return '${rawValue.substring(0, 6)}****${rawValue.substring(rawValue.length - 4)}';
      }
      return '***REDACTED***';
    }

    // Secrets & tokens
    if (cleanField.contains('secret') ||
        cleanField.contains('token') ||
        cleanField.contains('password')) {
      if (cleanRole == 'SUPERADMIN' || cleanRole == 'PHARMACY_OWNER') {
        return rawValue;
      }
      return '***REDACTED***';
    }

    return rawValue;
  }
}
