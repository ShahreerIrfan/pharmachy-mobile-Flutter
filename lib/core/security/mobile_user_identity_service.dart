/// Mobile User Identity & Session Service
/// Architecture Decision: ADR-0042
/// Handles mobile authentication session, role capabilities, and phone format normalization.
library mobile_user_identity_service;

class MobileUserIdentity {
  final String userId;
  final String tenantId;
  final String branchId;
  final String email;
  final String phoneNumber;
  final String fullName;
  final String role;
  final String activationStatus;
  final bool isArchived;

  const MobileUserIdentity({
    required this.userId,
    required this.tenantId,
    required this.branchId,
    required this.email,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    required this.activationStatus,
    required this.isArchived,
  });

  bool get canAccessManagementKpis =>
      !isArchived &&
      activationStatus == 'ACTIVE' &&
      (role == 'PHARMACY_OWNER' ||
          role == 'BRANCH_MANAGER' ||
          role == 'SUPERADMIN');

  bool get canApprovePurchases =>
      !isArchived &&
      activationStatus == 'ACTIVE' &&
      (role == 'PHARMACY_OWNER' || role == 'SUPERADMIN');

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'email': email,
        'phone_number': phoneNumber,
        'full_name': fullName,
        'role': role,
        'activation_status': activationStatus,
        'is_archived': isArchived,
      };

  static String normalizeBdPhone(String rawPhone) {
    if (rawPhone.trim().isEmpty) {
      throw const FormatException('Phone number cannot be empty.');
    }
    String cleaned = rawPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    if (cleaned.startsWith('+880')) {
      // standard prefix
    } else if (cleaned.startsWith('880')) {
      cleaned = '+$cleaned';
    } else if (cleaned.startsWith('01')) {
      cleaned = '+88$cleaned';
    } else if (cleaned.startsWith('1')) {
      cleaned = '+880$cleaned';
    } else {
      throw FormatException('Invalid Bangladesh phone prefix: $rawPhone');
    }

    final reg = RegExp(r'^\+8801[3-9]\d{8}$');
    if (!reg.hasMatch(cleaned)) {
      throw FormatException('Invalid Bangladesh mobile format: $cleaned');
    }
    return cleaned;
  }
}
