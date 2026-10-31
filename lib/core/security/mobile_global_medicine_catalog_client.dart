/// ADR-0070: Mobile Global Medicine Master Catalogue Client.
/// Enforces central catalog ownership, bars store-level master mutations,
/// detects DGDA product recalls, and coordinates prescription requirement checks.
library mobile_global_medicine_catalog_client;

class MobileGlobalMedicineCatalogClient {
  static final RegExp _productIdPattern = RegExp(r'^[a-z0-9_-]{3,64}$');
  static final RegExp _darPattern = RegExp(r'^DAR-[A-Za-z0-9_-]{3,32}$');

  static const Set<String> _platformCurationRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  /// Invariant: Store personas can NEVER mutate, delete, or author global master medicine records.
  static bool canRoleModifyGlobalCatalog(String? role) {
    if (role == null) return false;
    return _platformCurationRoles.contains(role.toUpperCase().trim());
  }

  /// Safety Invariant: Recalled products are strictly barred from sales.
  static bool isProductRecalled(String? curationStatus) {
    if (curationStatus == null) return false;
    return curationStatus.toUpperCase().trim() == 'RECALLED';
  }

  /// Regulatory Invariant: Checks if a product requires prescription record.
  static bool isPrescriptionMandatory({
    bool isPrescriptionOnly = false,
    bool isNarcotic = false,
    bool isAntibiotic = false,
  }) {
    return isPrescriptionOnly || isNarcotic || isAntibiotic;
  }

  /// Resolves curation status tone conforming to Apple-inspired restrained design system.
  static String resolveStatusTone(String? curationStatus) {
    if (curationStatus == null) return 'neutral';
    switch (curationStatus.toUpperCase().trim()) {
      case 'APPROVED':
        return 'success';
      case 'UNDER_REVIEW':
        return 'warning';
      case 'RECALLED':
        return 'danger';
      case 'DRAFT':
        return 'info';
      case 'DEPRECATED':
      default:
        return 'neutral';
    }
  }

  /// Validates DGDA Drug Administration Registration (DAR/DLR) number format.
  static bool isValidDarNumber(String? darNumber) {
    if (darNumber == null || darNumber.trim().isEmpty) return false;
    return _darPattern.hasMatch(darNumber.trim());
  }

  /// Builds master catalog browse URL.
  static String buildCatalogQueryUrl({int page = 1, int pageSize = 20, String? search}) {
    final p = page < 1 ? 1 : page;
    final ps = pageSize < 1 ? 20 : (pageSize > 100 ? 100 : pageSize);
    final buffer = StringBuffer('/api/v2/products/?page=$p&page_size=$ps');
    if (search != null && search.trim().isNotEmpty) {
      buffer.write('&search=${Uri.encodeQueryComponent(search.trim())}');
    }
    return buffer.toString();
  }

  /// Builds product detail endpoint URL.
  static String buildProductDetailUrl(String productId) {
    final cleanId = productId.trim();
    if (!_productIdPattern.hasMatch(cleanId)) {
      throw ArgumentError('Invalid product identifier: \'$productId\'');
    }
    return '/api/v2/products/$cleanId/';
  }
}
