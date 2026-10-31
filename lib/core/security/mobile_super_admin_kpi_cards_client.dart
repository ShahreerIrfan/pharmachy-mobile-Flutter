/// ADR-0064: Mobile Platform Super Admin KPI Cards Client & Boundary Guard.
/// Guarantees platform-level KPI cards are never displayed inside the tenant mobile manager app.
library mobile_super_admin_kpi_cards_client;

class PlatformKpiAccessDeniedException implements Exception {
  final String message;
  const PlatformKpiAccessDeniedException(this.message);

  @override
  String toString() => 'PlatformKpiAccessDeniedException: $message';
}

class MobileSuperAdminKpiCardsClient {
  static const Set<String> _authorizedRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static const Set<String> _allowedPeriods = {'current', '30d', 'mtd'};

  /// Invariant: Platform KPI cards are NEVER displayed in tenant mobile owner app.
  static bool shouldDisplayKpiCardsInMobileOwnerApp() => false;

  /// Verifies if user role is authorized to view platform KPIs.
  static bool isPlatformKpiAllowed(String? role) {
    if (role == null) return false;
    return _authorizedRoles.contains(role.toUpperCase().trim());
  }

  /// Builds platform KPI endpoint URL with strict role and parameter validation.
  static String buildKpiEndpointUrl(
    String role, {
    String currency = 'BDT',
    String period = 'current',
  }) {
    if (!isPlatformKpiAllowed(role)) {
      throw PlatformKpiAccessDeniedException(
        'Access denied: Role \'$role\' is not authorized to access platform KPI cards.',
      );
    }

    final cleanCurrency = currency.toUpperCase().trim();
    if (cleanCurrency != 'BDT') {
      throw ArgumentError('Unsupported currency \'$currency\'. Platform KPIs require BDT.');
    }

    final cleanPeriod = period.toLowerCase().trim();
    if (!_allowedPeriods.contains(cleanPeriod)) {
      throw ArgumentError('Unsupported period \'$period\'. Allowed: $_allowedPeriods');
    }

    return '/api/v2/platform/console/kpis/?currency=$cleanCurrency&period=$cleanPeriod';
  }

  /// Localized formatting for BDT revenue strings.
  static String formatBdt(String? amount) {
    if (amount == null || amount.trim().isEmpty) {
      return '৳ 0.00';
    }
    final parsed = double.tryParse(amount.trim());
    if (parsed == null) {
      throw ArgumentError('Invalid monetary amount string: $amount');
    }
    return '৳ ${parsed.toStringAsFixed(2)}';
  }
}
