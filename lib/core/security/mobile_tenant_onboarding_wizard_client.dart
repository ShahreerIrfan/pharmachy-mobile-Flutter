/// mobile_tenant_onboarding_wizard_client.dart
///
/// Architecture Decision: ADR-0079
/// Mobile Manager Platform Onboarding Wizard Client & Boundary Guard.
/// Ensures platform tenant onboarding operations cannot be initiated by tenant staff
/// while providing validation and endpoint resolution for platform administration.
library mobile_tenant_onboarding_wizard_client;

class MobileTenantOnboardingWizardClient {
  static const Set<String> _authorizedRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static const Set<String> _reservedSubdomains = {
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

  static final RegExp _subdomainPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$');
  static final RegExp _bdPhonePattern = RegExp(r'^\+8801[3-9]\d{8}$');

  /// Invariant: Platform onboarding wizard is NEVER accessible to tenant mobile apps.
  static bool shouldShowOnboardingInMobileApp() => false;

  /// Verifies if user role has platform onboarding privileges.
  static bool isPlatformOnboardingAllowed(String? role) {
    if (role == null) return false;
    return _authorizedRoles.contains(role.toUpperCase().trim());
  }

  /// Checks if subdomain format is valid and unreserved.
  static bool isSubdomainValid(String? rawSubdomain) {
    if (rawSubdomain == null || rawSubdomain.trim().isEmpty) return false;
    final clean = rawSubdomain.trim().toLowerCase();
    if (_reservedSubdomains.contains(clean)) return false;
    return _subdomainPattern.hasMatch(clean);
  }

  /// Enforces DGDA drug license number validity.
  static bool isDrugLicenseValid(String? drugLicense) {
    if (drugLicense == null || drugLicense.trim().isEmpty) return false;
    return drugLicense.trim().length >= 3;
  }

  /// Validates Bangladesh mobile phone numbers.
  static bool isPhoneValid(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) return false;
    return _bdPhonePattern.hasMatch(rawPhone.trim());
  }

  /// Validates complete wizard inputs.
  static bool validateCompletePayload({
    required String? pharmacyName,
    required String? subdomain,
    required String? drugLicense,
    required String? ownerEmail,
    required String? ownerPhone,
    required String? ownerPassword,
    required String? planTier,
  }) {
    if (pharmacyName == null || pharmacyName.trim().length < 3) return false;
    if (!isSubdomainValid(subdomain)) return false;
    if (!isDrugLicenseValid(drugLicense)) return false;
    if (ownerEmail == null || !ownerEmail.contains('@')) return false;
    if (!isPhoneValid(ownerPhone)) return false;
    if (ownerPassword == null || ownerPassword.length < 8) return false;
    final tier = planTier?.toUpperCase().trim();
    if (tier != 'BASIC' && tier != 'STANDARD' && tier != 'PRO') return false;
    return true;
  }

  /// Resolves bilingual step descriptors.
  static Map<String, String> getStepTitles(int stepNumber) {
    switch (stepNumber) {
      case 1:
        return {'en': 'Pharmacy Details', 'bn': 'ফার্মেসির বিবরণ'};
      case 2:
        return {'en': 'Licensing & DGDA Compliance', 'bn': 'ড্রাগ লাইসেন্স ও নিয়মতান্ত্রিক স্বীকৃতি'};
      case 3:
        return {'en': 'Branch & Staff Setup', 'bn': 'শাখা ও প্রাথমিক কর্মী কনফিগারেশন'};
      case 4:
        return {'en': 'Initial Inventory Baseline', 'bn': 'প্রাথমিক স্টক ও ক্যাটালগ নির্ধারণ'};
      case 5:
        return {'en': 'Plan Purchase & Quotas', 'bn': 'সাবস্ক্রিপশন প্ল্যান ও কোটা নির্বাচন'};
      case 6:
        return {'en': 'Review & Finalize', 'bn': 'পর্যালোচনা ও সক্রিয়করণ'};
      default:
        throw ArgumentError('Invalid step number: $stepNumber');
    }
  }

  /// Resolves platform onboarding wizard endpoint.
  static String resolveEndpoint(String action, {String? sessionId}) {
    final cleanAction = action.toLowerCase().trim();
    if (cleanAction == 'list' || cleanAction == 'create') {
      return '/api/v2/platform/onboarding-wizard/';
    }
    if (sessionId == null || sessionId.trim().isEmpty) {
      throw ArgumentError('sessionId is required for session-scoped operations.');
    }
    final cleanId = sessionId.trim();
    if (cleanAction == 'complete') {
      return '/api/v2/platform/onboarding-wizard/$cleanId/complete/';
    }
    if (cleanAction == 'abandon') {
      return '/api/v2/platform/onboarding-wizard/$cleanId/abandon/';
    }
    if (cleanAction == 'update-step') {
      return '/api/v2/platform/onboarding-wizard/$cleanId/update-step/';
    }
    return '/api/v2/platform/onboarding-wizard/$cleanId/';
  }
}
