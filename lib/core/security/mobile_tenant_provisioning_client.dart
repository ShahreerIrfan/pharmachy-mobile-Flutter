/// mobile_tenant_provisioning_client.dart
///
/// Architecture Decision: ADR-0062
/// Mobile Manager Platform Provisioning Client & Invariant Validator.
/// Validates tenant onboarding inputs on Flutter mobile:
///   - Subdomain validity and reserved name blacklist
///   - Bangladesh mobile phone formatting
///   - Password minimum length
///   - Super Admin RBAC guard
library mobile_tenant_provisioning_client;

class MobileTenantProvisioningClient {
  static const Set<String> reservedSubdomains = {
    'admin',
    'api',
    'system',
    'portal',
    'billing',
    'root',
    'app',
    'dev',
    'test',
    'stage',
    'prod',
    'superadmin',
  };

  static final RegExp subdomainPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$');
  static final RegExp bdPhonePattern = RegExp(r'^\+8801[3-9]\d{8}$');

  static bool isSubdomainValid(String? rawSubdomain) {
    if (rawSubdomain == null || rawSubdomain.trim().isEmpty) {
      return false;
    }
    final clean = rawSubdomain.trim().toLowerCase();
    if (reservedSubdomains.contains(clean)) {
      return false;
    }
    return subdomainPattern.hasMatch(clean);
  }

  static bool isOwnerPhoneValid(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      return false;
    }
    return bdPhonePattern.hasMatch(rawPhone.trim());
  }

  static bool isProvisioningAuthorized(String? role) {
    if (role == null) return false;
    final clean = role.toUpperCase().trim();
    return clean == 'SUPERADMIN' || clean == 'PLATFORM_OPERATOR';
  }

  static bool isPasswordSufficient(String? password) {
    return password != null && password.length >= 8;
  }
}
