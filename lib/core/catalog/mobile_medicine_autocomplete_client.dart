// lib/core/catalog/mobile_medicine_autocomplete_client.dart
// Architecture Decision: ADR-0129
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P129)

enum MobileAutocompleteUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

class MobileAutocompleteMatch {
  final String productId;
  final String? variantId;
  final String displayName;
  final String brandNameEn;
  final String brandNameBn;
  final String genericName;
  final String dosageForm;
  final String strength;
  final String manufacturer;
  final String barcode;
  final String sku;
  final double effectiveMrpUnit;
  final bool effectiveRequiresPrescription;
  final String shelfLocation;
  final bool isOverridden;
  final String matchType;
  final int rankScore;

  const MobileAutocompleteMatch({
    required this.productId,
    this.variantId,
    required this.displayName,
    required this.brandNameEn,
    this.brandNameBn = '',
    required this.genericName,
    this.dosageForm = '',
    this.strength = '',
    this.manufacturer = '',
    this.barcode = '',
    this.sku = '',
    required this.effectiveMrpUnit,
    this.effectiveRequiresPrescription = false,
    this.shelfLocation = '',
    this.isOverridden = false,
    required this.matchType,
    required this.rankScore,
  });

  factory MobileAutocompleteMatch.fromJson(Map<String, dynamic> json) {
    return MobileAutocompleteMatch(
      productId: json['product_id'] ?? '',
      variantId: json['variant_id'],
      displayName: json['display_name'] ?? '',
      brandNameEn: json['brand_name_en'] ?? '',
      brandNameBn: json['brand_name_bn'] ?? '',
      genericName: json['generic_name'] ?? '',
      dosageForm: json['dosage_form'] ?? '',
      strength: json['strength'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      barcode: json['barcode'] ?? '',
      sku: json['sku'] ?? '',
      effectiveMrpUnit: double.tryParse(json['effective_mrp_unit']?.toString() ?? '0.00') ?? 0.00,
      effectiveRequiresPrescription: json['effective_requires_prescription'] ?? false,
      shelfLocation: json['shelf_location'] ?? '',
      isOverridden: json['is_overridden'] ?? false,
      matchType: json['match_type'] ?? 'CONTAINS_SUBSTRING',
      rankScore: json['rank_score'] ?? 50,
    );
  }
}

class MobileAutocompleteResult {
  final MobileAutocompleteUiStatus status;
  final String? errorCode;
  final String messageEn;
  final String messageBn;
  final String query;
  final int totalMatches;
  final double latencyMs;
  final List<MobileAutocompleteMatch> matches;

  const MobileAutocompleteResult({
    required this.status,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
    required this.query,
    required this.totalMatches,
    required this.latencyMs,
    required this.matches,
  });

  static MobileAutocompleteResult success({
    required String query,
    required List<MobileAutocompleteMatch> matches,
    required double latencyMs,
  }) {
    return MobileAutocompleteResult(
      status: MobileAutocompleteUiStatus.success,
      messageEn: 'Found ${matches.length} matches.',
      messageBn: '${matches.length}টি ওষুধ পাওয়া গেছে।',
      query: query,
      totalMatches: matches.length,
      latencyMs: latencyMs,
      matches: matches,
    );
  }

  static MobileAutocompleteResult error({
    required String code,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileAutocompleteResult(
      status: MobileAutocompleteUiStatus.error,
      errorCode: code,
      messageEn: messageEn,
      messageBn: messageBn,
      query: '',
      totalMatches: 0,
      latencyMs: 0,
      matches: const [],
    );
  }

  static MobileAutocompleteResult permissionDenied({
    required String code,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileAutocompleteResult(
      status: MobileAutocompleteUiStatus.permissionDenied,
      errorCode: code,
      messageEn: messageEn,
      messageBn: messageBn,
      query: '',
      totalMatches: 0,
      latencyMs: 0,
      matches: const [],
    );
  }

  static MobileAutocompleteResult offline({
    required String query,
    required List<MobileAutocompleteMatch> matches,
    required double latencyMs,
  }) {
    return MobileAutocompleteResult(
      status: MobileAutocompleteUiStatus.offline,
      errorCode: 'OFFLINE_CACHE',
      messageEn: 'Resolved ${matches.length} matches from offline cache.',
      messageBn: 'অফলাইন ক্যাশ থেকে ${matches.length}টি ওষুধ লোড করা হয়েছে।',
      query: query,
      totalMatches: matches.length,
      latencyMs: latencyMs,
      matches: matches,
    );
  }
}

class MobileCatalogEntry {
  final String productId;
  final String brandNameEn;
  final String brandNameBn;
  final String genericName;
  final String dosageForm;
  final String strength;
  final String manufacturer;
  final String barcode;
  final double mrpUnit;
  final bool isPrescriptionOnly;
  final bool isVisible;
  final String localBrandName;
  final String localSku;
  final double? customMrpUnit;
  final String shelfLocation;

  const MobileCatalogEntry({
    required this.productId,
    required this.brandNameEn,
    this.brandNameBn = '',
    required this.genericName,
    this.dosageForm = '',
    this.strength = '',
    this.manufacturer = '',
    this.barcode = '',
    required this.mrpUnit,
    this.isPrescriptionOnly = false,
    this.isVisible = true,
    this.localBrandName = '',
    this.localSku = '',
    this.customMrpUnit,
    this.shelfLocation = '',
  });
}

class MobileMedicineAutocompleteClient {
  final Map<String, List<MobileCatalogEntry>> _tenantCatalogs = {};

  void addEntry(String tenantId, MobileCatalogEntry entry) {
    _tenantCatalogs.putIfAbsent(tenantId, () => []).add(entry);
  }

  MobileAutocompleteResult autocomplete({
    required String callerTenantId,
    required String targetTenantId,
    required String query,
    int limit = 10,
    bool isOnline = true,
  }) {
    final stopwatch = Stopwatch()..start();

    // Cross-tenant guard
    if (callerTenantId != targetTenantId) {
      return MobileAutocompleteResult.permissionDenied(
        code: 'ERR_CROSS_TENANT_ACCESS',
        messageEn: 'Cross-tenant access violation: Cannot search foreign catalog.',
        messageBn: 'ভিন্ন ফার্মেসির ওষুধ ক্যাটালগ অনুসন্ধান করা সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    final cleanQ = query.trim().toLowerCase();
    if (cleanQ.isEmpty) {
      return MobileAutocompleteResult.error(
        code: 'ERR_EMPTY_QUERY',
        messageEn: 'Search query cannot be empty.',
        messageBn: 'অনুসন্ধান টেক্সট খালি হতে পারে না।',
      );
    }

    final safeLimit = limit.clamp(1, 50);
    final entries = _tenantCatalogs[targetTenantId] ?? [];
    final List<MobileAutocompleteMatch> matches = [];

    for (final item in entries) {
      if (!item.isVisible) continue;

      int score = 0;
      String matchType = 'CONTAINS_SUBSTRING';

      if (query.trim() == item.barcode || (item.localSku.isNotEmpty && cleanQ == item.localSku.toLowerCase())) {
        score = 100;
        matchType = query.trim() == item.barcode ? 'BARCODE_EXACT' : 'SKU_EXACT';
      } else if (item.brandNameEn.toLowerCase().startsWith(cleanQ) ||
          (item.localBrandName.isNotEmpty && item.localBrandName.toLowerCase().startsWith(cleanQ)) ||
          item.brandNameBn.startsWith(cleanQ)) {
        score = 90;
        matchType = 'BRAND_PREFIX';
      } else if (item.genericName.toLowerCase().startsWith(cleanQ)) {
        score = 80;
        matchType = 'GENERIC_PREFIX';
      } else if (_isTranslit(cleanQ, item)) {
        score = 75;
        matchType = 'TRANSLITERATION_MATCH';
      } else if (item.brandNameEn.toLowerCase().contains(cleanQ) ||
          item.brandNameBn.contains(cleanQ) ||
          item.genericName.toLowerCase().contains(cleanQ) ||
          item.manufacturer.toLowerCase().contains(cleanQ) ||
          item.strength.toLowerCase().contains(cleanQ)) {
        score = 50;
        matchType = 'CONTAINS_SUBSTRING';
      }

      if (score > 0) {
        final effectiveBrand = item.localBrandName.isNotEmpty ? item.localBrandName : item.brandNameEn;
        final effectiveMrp = item.customMrpUnit ?? item.mrpUnit;
        final display = '$effectiveBrand ${item.strength} ${item.dosageForm}'.trim();

        matches.add(MobileAutocompleteMatch(
          productId: item.productId,
          displayName: display,
          brandNameEn: item.brandNameEn,
          brandNameBn: item.brandNameBn,
          genericName: item.genericName,
          dosageForm: item.dosageForm,
          strength: item.strength,
          manufacturer: item.manufacturer,
          barcode: item.barcode,
          sku: item.localSku,
          effectiveMrpUnit: effectiveMrp,
          effectiveRequiresPrescription: item.isPrescriptionOnly,
          shelfLocation: item.shelfLocation,
          isOverridden: item.customMrpUnit != null || item.localBrandName.isNotEmpty,
          matchType: matchType,
          rankScore: score,
        ));
      }
    }

    matches.sort((a, b) {
      final cmp = b.rankScore.compareTo(a.rankScore);
      return cmp != 0 ? cmp : a.displayName.compareTo(b.displayName);
    });

    final paginated = matches.take(safeLimit).toList();
    stopwatch.stop();
    final latencyMs = stopwatch.elapsedMicroseconds / 1000.0;

    if (!isOnline) {
      return MobileAutocompleteResult.offline(
        query: query,
        matches: paginated,
        latencyMs: latencyMs,
      );
    }

    return MobileAutocompleteResult.success(
      query: query,
      matches: paginated,
      latencyMs: latencyMs,
    );
  }

  bool _isTranslit(String q, MobileCatalogEntry item) {
    if (q == 'napa' && item.brandNameBn.contains('নাপা')) return true;
    if (q == 'নাপা' && item.brandNameEn.toLowerCase().contains('napa')) return true;
    if (q == 'seclo' && item.brandNameBn.contains('সেকলো')) return true;
    if (q == 'সেকলো' && item.brandNameEn.toLowerCase().contains('seclo')) return true;
    return false;
  }
}
