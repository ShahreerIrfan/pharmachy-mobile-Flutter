/// ADR-0071: Mobile Tenant-Specific Medicine Configuration Client.
/// Manages store-level brand aliases, internal SKUs, custom retail MRPs,
/// shelf locations, reorder thresholds, and visibility overrides while
/// strictly enforcing cashier privilege boundaries and DGDA regulatory compliance.
library mobile_tenant_medicine_config_client;

class MobileTenantMedicineConfigClient {
  static final RegExp _productIdPattern = RegExp(r'^[a-z0-9_-]{3,64}$');
  static final RegExp _configIdPattern = RegExp(r'^tmc-[a-z0-9_-]{8,32}$');

  static const Set<String> _allowedMutationRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
    'OWNER',
    'MANAGER',
    'PHARMACIST',
  };

  /// RBAC Invariant: Cashiers cannot mutate tenant configurations.
  static bool canRoleModifyTenantConfig(String? role) {
    if (role == null) return false;
    return _allowedMutationRoles.contains(role.toUpperCase().trim());
  }

  /// Resolves effective brand name for POS / store manager display.
  static String resolveEffectiveBrandName(String? localBrandName, String? masterBrandName) {
    if (localBrandName != null && localBrandName.trim().isNotEmpty) {
      return localBrandName.trim();
    }
    return masterBrandName?.trim() ?? '';
  }

  /// Resolves effective retail price.
  static String resolveEffectivePrice(String? customMrp, String? masterMrp) {
    if (customMrp != null && customMrp.trim().isNotEmpty) {
      return customMrp.trim();
    }
    return masterMrp?.trim() ?? '0.00';
  }

  /// Regulatory Invariant: Tenant can enforce stricter rules, but cannot relax global POM.
  static bool isPrescriptionMandatory({
    bool masterPom = false,
    bool masterNarcotic = false,
    bool masterAntibiotic = false,
    bool? tenantOverride,
  }) {
    if (masterPom || masterNarcotic || masterAntibiotic) {
      return true;
    }
    return tenantOverride ?? false;
  }

  /// Validates custom MRP decimal bounds (>= 0.01 BDT).
  static bool isValidCustomMrp(String? customMrp) {
    if (customMrp == null || customMrp.trim().isEmpty) {
      return true; // null/empty means fall back to master MRP
    }
    final parsed = double.tryParse(customMrp.trim());
    if (parsed == null) return false;
    return parsed >= 0.01;
  }

  /// Builds configuration list query URL.
  static String buildConfigListUrl({
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? isVisible,
  }) {
    final p = page < 1 ? 1 : page;
    final ps = pageSize < 1 ? 20 : (pageSize > 100 ? 100 : pageSize);
    final buffer = StringBuffer('/api/v2/tenants/medicine-configs/?page=$p&page_size=$ps');
    if (search != null && search.trim().isNotEmpty) {
      buffer.write('&search=${Uri.encodeQueryComponent(search.trim())}');
    }
    if (isVisible != null) {
      buffer.write('&is_visible=$isVisible');
    }
    return buffer.toString();
  }

  /// Builds query endpoint URL by master product ID.
  static String buildConfigByProductUrl(String productId) {
    final cleanId = productId.trim();
    if (!_productIdPattern.hasMatch(cleanId)) {
      throw ArgumentError('Invalid product identifier: \'$productId\'');
    }
    return '/api/v2/tenants/medicine-configs/by-product/$cleanId/';
  }

  /// Builds detail endpoint URL by config ID.
  static String buildConfigDetailUrl(String configId) {
    final cleanId = configId.trim();
    if (!_configIdPattern.hasMatch(cleanId)) {
      throw ArgumentError('Invalid config identifier: \'$configId\'');
    }
    return '/api/v2/tenants/medicine-configs/$cleanId/';
  }
}

