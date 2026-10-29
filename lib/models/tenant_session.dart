// lib/models/tenant_session.dart
// Architecture Decision: ADR-0005, ADR-0022 & ADR-0024

class TenantSession {
  final String tenantId;
  final String branchId;
  final String userId;
  final String userRole;
  final String authToken;

  const TenantSession({
    required this.tenantId,
    required this.branchId,
    required this.userId,
    required this.userRole,
    required this.authToken,
  });

  bool get isOwner => userRole == 'TENANT_OWNER';
  bool get isManager => userRole == 'BRANCH_MANAGER';
  bool get isSuperAdmin => userRole == 'PLATFORM_SUPER_ADMIN';
  bool get isCashier => userRole == 'CASHIER';

  Map<String, dynamic> toJson() {
    return {
      'tenant_id': tenantId,
      'branch_id': branchId,
      'user_id': userId,
      'user_role': userRole,
      'auth_token': authToken,
    };
  }

  factory TenantSession.fromJson(Map<String, dynamic> json) {
    return TenantSession(
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      userId: json['user_id'] as String,
      userRole: json['user_role'] as String,
      authToken: json['auth_token'] as String,
    );
  }
}
