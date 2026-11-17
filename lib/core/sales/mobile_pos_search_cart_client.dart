// mobile_pos_search_cart_client.dart
// Architecture Decision: ADR-0222 (P222).
// Phase 12: POS, Sales Orders, Checkout & Returns.
//
// Flutter Mobile Client wired to:
// - GET  /api/v2/pos/search/?branch=...&q=...
// - GET  /api/v2/pos/search/barcode-lookup/?branch=...&q=...
// - GET  /api/v2/pos/search/snapshot-cache/?branch=...
// - POST /api/v2/pos/search/refresh-snapshot/
// - POST /api/v2/pos/sales/quick-cart/
// - POST /api/v2/pos/sales/{sale_id}/scan-add/
// - PATCH /api/v2/pos/sales/{sale_id}/cart-line/

import 'package:dio/dio.dart';

import 'mobile_pos_domain_client.dart';

int _asInt(dynamic v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

class MobilePackagingOption {
  final String packagingUnit;
  final String labelEn;
  final String labelBn;
  final int conversionFactor;
  final String unitPriceBdt;
  final String conversionSource;
  final String containerPolicyStatus;
  final bool isAllowed;
  final bool requiresPharmacistApproval;
  final String blockErrorCode;
  final String blockReasonEn;
  final String blockReasonBn;

  const MobilePackagingOption({
    required this.packagingUnit,
    required this.labelEn,
    required this.labelBn,
    required this.conversionFactor,
    required this.unitPriceBdt,
    this.conversionSource = '',
    this.containerPolicyStatus = 'STANDARD',
    this.isAllowed = true,
    this.requiresPharmacistApproval = false,
    this.blockErrorCode = '',
    this.blockReasonEn = '',
    this.blockReasonBn = '',
  });

  factory MobilePackagingOption.fromJson(Map<String, dynamic> json) {
    return MobilePackagingOption(
      packagingUnit: (json['packaging_unit'] ?? 'TABLET').toString(),
      labelEn: (json['label_en'] ?? json['packaging_unit'] ?? 'Tablet').toString(),
      labelBn: (json['label_bn'] ?? json['label_en'] ?? 'ট্যাবলেট').toString(),
      conversionFactor: _asInt(json['conversion_factor'], 1),
      unitPriceBdt: (json['unit_price_bdt'] ?? '0.00').toString(),
      conversionSource: (json['conversion_source'] ?? '').toString(),
      containerPolicyStatus: (json['container_policy_status'] ?? 'STANDARD').toString(),
      isAllowed: json['is_allowed'] == null ? true : (json['is_allowed'] == true),
      requiresPharmacistApproval: json['requires_pharmacist_approval'] == true,
      blockErrorCode: (json['block_error_code'] ?? '').toString(),
      blockReasonEn: (json['block_reason_en'] ?? '').toString(),
      blockReasonBn: (json['block_reason_bn'] ?? '').toString(),
    );
  }
}

class MobileUnitOptionsResponse {
  final String tenantId;
  final String branchId;
  final String? saleId;
  final String? lineId;
  final String? currentPackagingUnit;
  final int currentConversionFactor;
  final int currentQuantityUnits;
  final int currentBaseUnitsTotal;
  final String productId;
  final String? variantId;
  final String brandName;
  final String dosageForm;
  final String normalizedDosageForm;
  final String primaryBaseUnit;
  final int availableBaseUnits;
  final String conversionSource;
  final bool nonDivisibleSealedOnly;
  final List<String> blockedUnits;
  final List<MobilePackagingOption> packagingOptions;

  const MobileUnitOptionsResponse({
    required this.tenantId,
    required this.branchId,
    this.saleId,
    this.lineId,
    this.currentPackagingUnit,
    this.currentConversionFactor = 1,
    this.currentQuantityUnits = 1,
    this.currentBaseUnitsTotal = 1,
    required this.productId,
    this.variantId,
    required this.brandName,
    required this.dosageForm,
    required this.normalizedDosageForm,
    required this.primaryBaseUnit,
    required this.availableBaseUnits,
    required this.conversionSource,
    required this.nonDivisibleSealedOnly,
    required this.blockedUnits,
    required this.packagingOptions,
  });

  factory MobileUnitOptionsResponse.fromJson(Map<String, dynamic> json) {
    final optsRaw = (json['packaging_options'] as List<dynamic>? ?? <dynamic>[]);
    final blkRaw = (json['blocked_units'] as List<dynamic>? ?? <dynamic>[]);
    return MobileUnitOptionsResponse(
      tenantId: (json['tenant_id'] ?? '').toString(),
      branchId: (json['branch_id'] ?? '').toString(),
      saleId: json['sale_id']?.toString(),
      lineId: json['line_id']?.toString(),
      currentPackagingUnit: json['current_packaging_unit']?.toString(),
      currentConversionFactor: _asInt(json['current_conversion_factor'], 1),
      currentQuantityUnits: _asInt(json['current_quantity_units'], 1),
      currentBaseUnitsTotal: _asInt(json['current_base_units_total'], 1),
      productId: (json['product_id'] ?? '').toString(),
      variantId: json['variant_id']?.toString(),
      brandName: (json['brand_name'] ?? '').toString(),
      dosageForm: (json['dosage_form'] ?? '').toString(),
      normalizedDosageForm: (json['normalized_dosage_form'] ?? '').toString(),
      primaryBaseUnit: (json['primary_base_unit'] ?? 'TABLET').toString(),
      availableBaseUnits: _asInt(json['available_base_units'], 0),
      conversionSource: (json['conversion_source'] ?? '').toString(),
      nonDivisibleSealedOnly: json['non_divisible_sealed_only'] == true,
      blockedUnits: blkRaw.map((e) => e.toString()).toList(),
      packagingOptions: optsRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => MobilePackagingOption.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class MobileFastSearchCandidate {
  final String productId;
  final String? variantId;
  final String skuCode;
  final String displayName;
  final String brandName;
  final String brandNameBn;
  final String genericName;
  final String genericNameBn;
  final String strength;
  final String dosageForm;
  final String barcode;
  final String shelfLocation;
  final String resolutionSource;
  final String resolvedPackagingUnit;
  final int resolvedConversionFactor;
  final String unitPriceBdt;
  final String baseUnitPriceBdt;
  final String? unitCostBdt;
  final int sellableBaseUnits;
  final int reservedBaseUnits;
  final int availableBaseUnits;
  final int quarantinedBaseUnits;
  final int expiredBaseUnits;
  final int recalledBaseUnits;
  final String? earliestBatchId;
  final String earliestBatchNumber;
  final String? earliestExpiryDate;
  final bool nearExpiryWarning;
  final bool requiresRxVerification;
  final String regulatoryClassification;
  final bool nonDivisibleSealedOnly;
  final bool isSellable;
  final String blockReason;
  final String? snapshotReadModelId;
  final String snapshotChecksum;
  final String? snapshotAsOf;
  final int rankScore;
  final String conversionSource;
  final List<String> blockedUnits;
  final List<MobilePackagingOption> packagingOptions;

  const MobileFastSearchCandidate({
    required this.productId,
    this.variantId,
    required this.skuCode,
    required this.displayName,
    required this.brandName,
    required this.brandNameBn,
    required this.genericName,
    required this.genericNameBn,
    required this.strength,
    required this.dosageForm,
    required this.barcode,
    required this.shelfLocation,
    required this.resolutionSource,
    required this.resolvedPackagingUnit,
    required this.resolvedConversionFactor,
    required this.unitPriceBdt,
    required this.baseUnitPriceBdt,
    this.unitCostBdt,
    required this.sellableBaseUnits,
    required this.reservedBaseUnits,
    required this.availableBaseUnits,
    required this.quarantinedBaseUnits,
    required this.expiredBaseUnits,
    required this.recalledBaseUnits,
    this.earliestBatchId,
    required this.earliestBatchNumber,
    this.earliestExpiryDate,
    required this.nearExpiryWarning,
    required this.requiresRxVerification,
    this.regulatoryClassification = 'OTC',
    required this.nonDivisibleSealedOnly,
    required this.isSellable,
    required this.blockReason,
    this.snapshotReadModelId,
    required this.snapshotChecksum,
    this.snapshotAsOf,
    required this.rankScore,
    this.conversionSource = '',
    this.blockedUnits = const <String>[],
    required this.packagingOptions,
  });

  factory MobileFastSearchCandidate.fromJson(Map<String, dynamic> json) {
    final optsRaw = (json['packaging_options'] as List<dynamic>? ?? <dynamic>[]);
    final blkRaw = (json['blocked_units'] as List<dynamic>? ?? <dynamic>[]);
    return MobileFastSearchCandidate(
      productId: (json['product_id'] ?? '').toString(),
      variantId: json['variant_id']?.toString(),
      skuCode: (json['sku_code'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['brand_name'] ?? '').toString(),
      brandName: (json['brand_name'] ?? '').toString(),
      brandNameBn: (json['brand_name_bn'] ?? '').toString(),
      genericName: (json['generic_name'] ?? '').toString(),
      genericNameBn: (json['generic_name_bn'] ?? '').toString(),
      strength: (json['strength'] ?? '').toString(),
      dosageForm: (json['dosage_form'] ?? '').toString(),
      barcode: (json['barcode'] ?? '').toString(),
      shelfLocation: (json['shelf_location'] ?? '').toString(),
      resolutionSource: (json['resolution_source'] ?? '').toString(),
      resolvedPackagingUnit: (json['resolved_packaging_unit'] ?? 'TABLET').toString(),
      resolvedConversionFactor: _asInt(json['resolved_conversion_factor'], 1),
      unitPriceBdt: (json['unit_price_bdt'] ?? '0.00').toString(),
      baseUnitPriceBdt: (json['base_unit_price_bdt'] ?? json['unit_price_bdt'] ?? '0.00').toString(),
      unitCostBdt: json['unit_cost_bdt']?.toString(),
      sellableBaseUnits: _asInt(json['sellable_base_units'], 0),
      reservedBaseUnits: _asInt(json['reserved_base_units'], 0),
      availableBaseUnits: _asInt(json['available_base_units'], 0),
      quarantinedBaseUnits: _asInt(json['quarantined_base_units'], 0),
      expiredBaseUnits: _asInt(json['expired_base_units'], 0),
      recalledBaseUnits: _asInt(json['recalled_base_units'], 0),
      earliestBatchId: json['earliest_batch_id']?.toString(),
      earliestBatchNumber: (json['earliest_batch_number'] ?? '').toString(),
      earliestExpiryDate: json['earliest_expiry_date']?.toString(),
      nearExpiryWarning: (json['near_expiry_warning'] ?? false) as bool,
      requiresRxVerification: (json['requires_rx_verification'] ?? false) as bool,
      regulatoryClassification: (json['regulatory_classification'] ?? 'OTC').toString(),
      nonDivisibleSealedOnly: (json['non_divisible_sealed_only'] ?? false) as bool,
      isSellable: (json['is_sellable'] ?? false) as bool,
      blockReason: (json['block_reason'] ?? '').toString(),
      snapshotReadModelId: json['snapshot_read_model_id']?.toString(),
      snapshotChecksum: (json['snapshot_checksum'] ?? '').toString(),
      snapshotAsOf: json['snapshot_as_of']?.toString(),
      rankScore: _asInt(json['rank_score'], 0),
      conversionSource: (json['conversion_source'] ?? '').toString(),
      blockedUnits: blkRaw.map((e) => e.toString()).toList(),
      packagingOptions: optsRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => MobilePackagingOption.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }

  factory MobileFastSearchCandidate.fromSnapshotItemJson(Map<String, dynamic> json) {
    final avail = _asInt(json['available_base_units'], 0);
    final exp = _asInt(json['expired_base_units'], 0);
    final quar = _asInt(json['quarantined_base_units'], 0);
    final rec = _asInt(json['recalled_base_units'], 0);
    final nonDiv = (json['non_divisible_sealed_only'] ?? false) as bool;
    final basePrice = double.tryParse((json['unit_price_bdt'] ?? '0.00').toString()) ?? 0.0;
    final stripF = _asInt(json['strip_conversion_factor'], 10);
    final boxF = _asInt(json['box_conversion_factor'], 100);

    final options = <MobilePackagingOption>[
      MobilePackagingOption(
        packagingUnit: 'TABLET',
        labelEn: 'Tablet / Unit',
        labelBn: 'ট্যাবলেট / পিস',
        conversionFactor: 1,
        unitPriceBdt: basePrice.toStringAsFixed(2),
        conversionSource: 'OFFLINE_SNAPSHOT',
        containerPolicyStatus: nonDiv ? 'RESTRICTED' : 'STANDARD',
        isAllowed: !nonDiv,
        blockErrorCode: nonDiv ? 'ERR_NON_DIVISIBLE_PACK' : '',
        blockReasonEn: nonDiv ? 'Non-divisible sealed pack policy blocks loose tablet sales.' : '',
        blockReasonBn: nonDiv ? 'সিলড প্যাক নীতি অনুযায়ী খোলা ট্যাবলেট বিক্রি নিষিদ্ধ।' : '',
      ),
      MobilePackagingOption(
        packagingUnit: 'STRIP',
        labelEn: 'Strip (${stripF}u)',
        labelBn: 'স্ট্রিপ ($stripFটি)',
        conversionFactor: stripF,
        unitPriceBdt: (basePrice * stripF).toStringAsFixed(2),
        conversionSource: 'OFFLINE_SNAPSHOT',
      ),
      MobilePackagingOption(
        packagingUnit: 'BOX',
        labelEn: 'Box (${boxF}u)',
        labelBn: 'বক্স ($boxFটি)',
        conversionFactor: boxF,
        unitPriceBdt: (basePrice * boxF).toStringAsFixed(2),
        conversionSource: 'OFFLINE_SNAPSHOT',
      ),
    ];

    String block = '';
    if (avail <= 0) {
      if (rec > 0) {
        block = 'RECALLED_STOCK_BLOCKED';
      } else if (quar > 0) {
        block = 'QUARANTINED_STOCK_BLOCKED';
      } else if (exp > 0) {
        block = 'EXPIRED_STOCK_BLOCKED';
      } else {
        block = 'OUT_OF_STOCK';
      }
    }

    final defaultOpt = options.firstWhere(
      (o) => o.isAllowed,
      orElse: () => options.first,
    );
    return MobileFastSearchCandidate(
      productId: (json['product_id'] ?? '').toString(),
      variantId: json['variant_id']?.toString(),
      skuCode: (json['sku_code'] ?? '').toString(),
      displayName: '${json['brand_name'] ?? ''} ${json['strength'] ?? ''}'.trim(),
      brandName: (json['brand_name'] ?? '').toString(),
      brandNameBn: (json['brand_name_bn'] ?? '').toString(),
      genericName: (json['generic_name'] ?? '').toString(),
      genericNameBn: (json['generic_name_bn'] ?? '').toString(),
      strength: (json['strength'] ?? '').toString(),
      dosageForm: (json['dosage_form'] ?? '').toString(),
      barcode: (json['barcode_tokens'] ?? '').toString(),
      shelfLocation: (json['shelf_location'] ?? '').toString(),
      resolutionSource: 'OFFLINE_SNAPSHOT',
      resolvedPackagingUnit: defaultOpt.packagingUnit,
      resolvedConversionFactor: defaultOpt.conversionFactor,
      unitPriceBdt: defaultOpt.unitPriceBdt,
      baseUnitPriceBdt: basePrice.toStringAsFixed(2),
      unitCostBdt: null,
      sellableBaseUnits: _asInt(json['sellable_base_units'], 0),
      reservedBaseUnits: _asInt(json['reserved_base_units'], 0),
      availableBaseUnits: avail,
      quarantinedBaseUnits: quar,
      expiredBaseUnits: exp,
      recalledBaseUnits: rec,
      earliestBatchId: null,
      earliestBatchNumber: 'SNAPSHOT-CACHE',
      earliestExpiryDate: json['nearest_expiry_date']?.toString(),
      nearExpiryWarning: false,
      requiresRxVerification: (json['requires_rx_verification'] ?? false) as bool,
      regulatoryClassification: (json['regulatory_classification'] ?? 'OTC').toString(),
      nonDivisibleSealedOnly: nonDiv,
      isSellable: avail > 0,
      blockReason: block,
      snapshotReadModelId: json['read_model_id']?.toString(),
      snapshotChecksum: (json['sha256_checksum'] ?? '').toString(),
      snapshotAsOf: json['snapshot_as_of']?.toString(),
      rankScore: 90,
      conversionSource: 'OFFLINE_SNAPSHOT',
      blockedUnits: nonDiv ? const <String>['TABLET'] : const <String>[],
      packagingOptions: options,
    );
  }

  MobileFastSearchCandidate copyWithOfflineScore(int score) {
    return MobileFastSearchCandidate(
      productId: productId,
      variantId: variantId,
      skuCode: skuCode,
      displayName: displayName,
      brandName: brandName,
      brandNameBn: brandNameBn,
      genericName: genericName,
      genericNameBn: genericNameBn,
      strength: strength,
      dosageForm: dosageForm,
      barcode: barcode,
      shelfLocation: shelfLocation,
      resolutionSource: 'OFFLINE_SNAPSHOT',
      resolvedPackagingUnit: resolvedPackagingUnit,
      resolvedConversionFactor: resolvedConversionFactor,
      unitPriceBdt: unitPriceBdt,
      baseUnitPriceBdt: baseUnitPriceBdt,
      unitCostBdt: null,
      sellableBaseUnits: sellableBaseUnits,
      reservedBaseUnits: reservedBaseUnits,
      availableBaseUnits: availableBaseUnits,
      quarantinedBaseUnits: quarantinedBaseUnits,
      expiredBaseUnits: expiredBaseUnits,
      recalledBaseUnits: recalledBaseUnits,
      earliestBatchId: earliestBatchId,
      earliestBatchNumber: earliestBatchNumber,
      earliestExpiryDate: earliestExpiryDate,
      nearExpiryWarning: nearExpiryWarning,
      requiresRxVerification: requiresRxVerification,
      regulatoryClassification: regulatoryClassification,
      nonDivisibleSealedOnly: nonDivisibleSealedOnly,
      isSellable: isSellable,
      blockReason: blockReason,
      snapshotReadModelId: snapshotReadModelId,
      snapshotChecksum: snapshotChecksum,
      snapshotAsOf: snapshotAsOf,
      rankScore: score,
      conversionSource: conversionSource,
      blockedUnits: blockedUnits,
      packagingOptions: packagingOptions,
    );
  }
}

class MobileFastSearchResponse {
  final String query;
  final String tenantId;
  final String branchId;
  final int totalMatches;
  final double latencyMs;
  final bool fromOfflineCache;
  final List<MobileFastSearchCandidate> results;

  const MobileFastSearchResponse({
    required this.query,
    required this.tenantId,
    required this.branchId,
    required this.totalMatches,
    required this.latencyMs,
    this.fromOfflineCache = false,
    required this.results,
  });

  factory MobileFastSearchResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['results'] as List<dynamic>? ?? <dynamic>[]);
    return MobileFastSearchResponse(
      query: (json['query'] ?? '').toString(),
      tenantId: (json['tenant_id'] ?? '').toString(),
      branchId: (json['branch_id'] ?? '').toString(),
      totalMatches: _asInt(json['total_matches'], raw.length),
      latencyMs: double.tryParse((json['latency_ms'] ?? '0').toString()) ?? 0.0,
      fromOfflineCache: false,
      results: raw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => MobileFastSearchCandidate.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class MobilePosSearchCartClient {
  static const Set<String> _snapshotAdminRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'STAFF_PHARMACIST',
    'INVENTORY_CLERK',
  };

  final String baseUrl;
  final MobilePosTransport _transport;
  final MobilePosDomainClient _domainGuardClient;
  final Map<String, List<MobileFastSearchCandidate>> _branchSnapshotCache =
      <String, List<MobileFastSearchCandidate>>{};

  MobilePosSearchCartClient({
    required this.baseUrl,
    MobilePosTransport? transport,
    Dio? dio,
  })  : _transport = transport ?? _createDioTransport(baseUrl, dio ?? Dio()),
        _domainGuardClient = MobilePosDomainClient(
          baseUrl: baseUrl,
          transport: transport,
          dio: dio,
        );

  static MobilePosTransport _createDioTransport(String baseUrl, Dio dio) {
    final normalizedBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return (method, path, {body, bearerToken}) async {
      final options = Options(
        method: method,
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (bearerToken != null && bearerToken.isNotEmpty)
            'Authorization': 'Bearer $bearerToken',
        },
        validateStatus: (_) => true,
      );
      final resp = await dio.request<dynamic>(
        '$normalizedBase$path',
        data: body,
        options: options,
      );
      final mapData = resp.data is Map
          ? Map<String, dynamic>.from(resp.data as Map)
          : <String, dynamic>{'results': resp.data};
      return MobilePosHttpResponse(
        statusCode: resp.statusCode ?? 500,
        data: mapData,
      );
    };
  }

  void seedOfflineSnapshot(String branchId, List<MobileFastSearchCandidate> items) {
    _branchSnapshotCache[branchId] = List<MobileFastSearchCandidate>.from(items);
  }

  List<MobileFastSearchCandidate> getCachedSnapshot(String branchId) =>
      List<MobileFastSearchCandidate>.unmodifiable(_branchSnapshotCache[branchId] ?? const <MobileFastSearchCandidate>[]);

  MobileFastSearchResponse searchOfflineSnapshot(String branchId, String query) {
    final qLower = query.trim().toLowerCase();
    final cached = _branchSnapshotCache[branchId] ?? const <MobileFastSearchCandidate>[];
    if (qLower.isEmpty) {
      return MobileFastSearchResponse(
        query: '',
        tenantId: '',
        branchId: branchId,
        totalMatches: 0,
        latencyMs: 0.1,
        fromOfflineCache: true,
        results: const <MobileFastSearchCandidate>[],
      );
    }

    final hits = <MobileFastSearchCandidate>[];
    for (final c in cached) {
      int score = 0;
      final tokens = c.barcode.toLowerCase().split(RegExp(r'\s+'));
      if (tokens.contains(qLower) || c.barcode.toLowerCase() == qLower) {
        score = 120;
      } else if (c.skuCode.toLowerCase() == qLower) {
        score = 110;
      } else if (c.brandName.toLowerCase().startsWith(qLower) ||
          c.brandNameBn.toLowerCase().startsWith(qLower)) {
        score = 95;
      } else if (c.genericName.toLowerCase().startsWith(qLower) ||
          c.genericNameBn.toLowerCase().startsWith(qLower)) {
        score = 85;
      } else if (c.brandName.toLowerCase().contains(qLower) ||
          c.genericName.toLowerCase().contains(qLower) ||
          c.brandNameBn.toLowerCase().contains(qLower) ||
          c.skuCode.toLowerCase().contains(qLower)) {
        score = 65;
      }
      if (score > 0) {
        hits.add(c.copyWithOfflineScore(score));
      }
    }
    hits.sort((a, b) {
      final scoreCmp = b.rankScore.compareTo(a.rankScore);
      if (scoreCmp != 0) return scoreCmp;
      if (a.isSellable != b.isSellable) return b.isSellable ? 1 : -1;
      return a.displayName.compareTo(b.displayName);
    });

    return MobileFastSearchResponse(
      query: query.trim(),
      tenantId: '',
      branchId: branchId,
      totalMatches: hits.length,
      latencyMs: 0.5,
      fromOfflineCache: true,
      results: hits,
    );
  }

  Future<MobilePosOutcome<MobileFastSearchResponse>> fastSearch({
    required String query,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    int limit = 15,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const MobilePosOutcome<MobileFastSearchResponse>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_VALIDATION_FAILED',
        messageEn: 'Search or barcode query cannot be empty.',
        messageBn: 'অনুসন্ধান বা বারকোড ইনপুট খালি রাখা যাবে না।',
      );
    }

    if (subscriptionSuspended || actorRole.isNotEmpty) {
      final guard = _domainGuardClient.authorizeScope(
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: false,
      );
      if (guard.uiState != MobilePosUiState.ready) {
        return MobilePosOutcome<MobileFastSearchResponse>(
          uiState: guard.uiState,
          errorCode: guard.errorCode,
          messageEn: guard.messageEn,
          messageBn: guard.messageBn,
        );
      }
    }

    if (isOffline) {
      final offlineResp = searchOfflineSnapshot(targetBranchId, trimmed);
      return MobilePosOutcome<MobileFastSearchResponse>(
        uiState: offlineResp.results.isEmpty ? MobilePosUiState.empty : MobilePosUiState.offline,
        data: offlineResp,
        errorCode: 'OFFLINE_SNAPSHOT_ESTIMATE',
        messageEn: offlineResp.results.isEmpty
            ? 'No match in offline branch snapshot cache.'
            : 'Offline mode: showing cached SKU snapshot estimates (cloud stock unverified).',
        messageBn: offlineResp.results.isEmpty
            ? 'অফলাইন স্ন্যাপশট ক্যাশে কোনো মিল পাওয়া যায়নি।'
            : 'অফলাইন মোড: লোকাল স্ন্যাপশট ক্যাশ থেকে সম্ভাব্য তথ্য দেখানো হচ্ছে।',
      );
    }

    try {
      final encodedQ = Uri.encodeQueryComponent(trimmed);
      final encodedB = Uri.encodeQueryComponent(targetBranchId);
      final res = await _transport(
        'GET',
        '/api/v2/pos/search/?branch=$encodedB&q=$encodedQ&limit=$limit',
        bearerToken: bearerToken,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final dto = MobileFastSearchResponse.fromJson(res.data);
        if (dto.results.isEmpty) {
          return MobilePosOutcome<MobileFastSearchResponse>(
            uiState: MobilePosUiState.empty,
            data: dto,
            messageEn: "No matching medicine or SKU found for '$trimmed'.",
            messageBn: "'$trimmed' অনুযায়ী কোনো ওষুধ বা SKU পাওয়া যায়নি।",
          );
        }
        return MobilePosOutcome<MobileFastSearchResponse>(
          uiState: MobilePosUiState.ready,
          data: dto,
          messageEn: 'Found ${dto.results.length} match(es) in ${dto.latencyMs}ms.',
          messageBn: '${dto.results.length}টি ফলাফল পাওয়া গেছে (${dto.latencyMs}ms)।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return MobilePosOutcome<MobileFastSearchResponse>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: _extractErrorCode(res.data, 'ERR_PERMISSION_DENIED'),
          messageEn: _extractMessage(res.data, 'Permission denied for POS search.'),
          messageBn: 'এই শাখায় পিওএস সার্চের অনুমতি আপনার নেই।',
        );
      }
      return MobilePosOutcome<MobileFastSearchResponse>(
        uiState: MobilePosUiState.error,
        errorCode: _extractErrorCode(res.data, 'ERR_VALIDATION_FAILED'),
        messageEn: _extractMessage(res.data, 'POS search validation failed.'),
        messageBn: 'সার্চ অনুরোধে ত্রুটি হয়েছে।',
      );
    } catch (_) {
      final offlineResp = searchOfflineSnapshot(targetBranchId, trimmed);
      return MobilePosOutcome<MobileFastSearchResponse>(
        uiState: MobilePosUiState.offline,
        data: offlineResp,
        errorCode: 'OFFLINE_SNAPSHOT_ESTIMATE',
        messageEn: 'Offline mode: showing cached SKU snapshot estimates (cloud stock unverified).',
        messageBn: 'অফলাইন মোড: লোকাল স্ন্যাপশট ক্যাশ থেকে সম্ভাব্য তথ্য দেখানো হচ্ছে।',
      );
    }
  }

  Future<MobilePosOutcome<List<MobileFastSearchCandidate>>> refreshLocalSnapshotCache({
    required String targetBranchId,
    required String bearerToken,
  }) async {
    try {
      final encodedB = Uri.encodeQueryComponent(targetBranchId);
      final res = await _transport(
        'GET',
        '/api/v2/pos/search/snapshot-cache/?branch=$encodedB',
        bearerToken: bearerToken,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final rawItems = (res.data['items'] as List<dynamic>? ?? <dynamic>[]);
        final parsed = rawItems
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => MobileFastSearchCandidate.fromSnapshotItemJson(Map<String, dynamic>.from(m)))
            .toList();
        _branchSnapshotCache[targetBranchId] = parsed;
        return MobilePosOutcome<List<MobileFastSearchCandidate>>(
          uiState: parsed.isEmpty ? MobilePosUiState.empty : MobilePosUiState.ready,
          data: parsed,
          messageEn: 'Synced ${parsed.length} validated branch SKU snapshots.',
          messageBn: '${parsed.length}টি ভ্যালিডেটেড SKU স্ন্যাপশট সিঙ্ক হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return const MobilePosOutcome<List<MobileFastSearchCandidate>>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: 'ERR_PERMISSION_DENIED',
          messageEn: 'Permission denied syncing SKU snapshot cache.',
          messageBn: 'SKU স্ন্যাপশট সিঙ্ক করার অনুমতি নেই।',
        );
      }
      return MobilePosOutcome<List<MobileFastSearchCandidate>>(
        uiState: MobilePosUiState.error,
        errorCode: _extractErrorCode(res.data, 'ERR_SNAPSHOT_SYNC'),
        messageEn: _extractMessage(res.data, 'Failed to sync SKU snapshot cache.'),
        messageBn: 'SKU স্ন্যাপশট সিঙ্ক ব্যর্থ হয়েছে।',
      );
    } catch (_) {
      return MobilePosOutcome<List<MobileFastSearchCandidate>>(
        uiState: MobilePosUiState.offline,
        data: getCachedSnapshot(targetBranchId),
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<Map<String, dynamic>>> triggerServerSnapshotRebuild({
    required String targetBranchId,
    required String actorRole,
    required String bearerToken,
  }) async {
    final role = actorRole.trim().toUpperCase();
    if (!_snapshotAdminRoles.contains(role)) {
      return const MobilePosOutcome<Map<String, dynamic>>(
        uiState: MobilePosUiState.permissionDenied,
        errorCode: 'ERR_PERMISSION_DENIED',
        messageEn: 'Cashiers cannot trigger manual inventory snapshot rebuilds.',
        messageBn: 'ক্যাশিয়ার ম্যানুয়াল ইনভেন্টরি স্ন্যাপশট রিফ্রেশ করতে পারবেন না।',
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/search/refresh-snapshot/',
        body: <String, dynamic>{'branch': targetBranchId},
        bearerToken: bearerToken,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return MobilePosOutcome<Map<String, dynamic>>(
          uiState: MobilePosUiState.ready,
          data: res.data,
          messageEn: 'Branch SKU inventory snapshot rebuilt.',
          messageBn: 'শাখার SKU ইনভেন্টরি স্ন্যাপশট পুনর্গঠিত হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return const MobilePosOutcome<Map<String, dynamic>>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: 'ERR_PERMISSION_DENIED',
          messageEn: 'Server denied manual snapshot rebuild (HTTP 403).',
          messageBn: 'সার্ভার ম্যানুয়াল স্ন্যাপশট রিফ্রেশের অনুমতি দেয়নি।',
        );
      }
      return MobilePosOutcome<Map<String, dynamic>>(
        uiState: MobilePosUiState.error,
        errorCode: _extractErrorCode(res.data, 'ERR_SNAPSHOT_REBUILD'),
        messageEn: _extractMessage(res.data, 'Failed to rebuild SKU snapshot.'),
        messageBn: 'SKU স্ন্যাপশট রিফ্রেশ ব্যর্থ হয়েছে।',
      );
    } catch (_) {
      return MobilePosOutcome<Map<String, dynamic>>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> openQuickCart({
    required String targetBranchId,
    required String bearerToken,
    String offlineDeviceNamespace = 'mobile-pos',
  }) async {
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/quick-cart/',
        body: <String, dynamic>{
          'branch': targetBranchId,
          'offline_device_namespace': offlineDeviceNamespace,
        },
        bearerToken: bearerToken,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final rawSale = res.data['sale'] is Map
            ? Map<String, dynamic>.from(res.data['sale'] as Map)
            : res.data;
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.ready,
          data: MobilePosSaleOrder.fromJson(rawSale),
          messageEn: 'Mobile quick cart ready.',
          messageBn: 'মোবাইল কুইক কার্ট প্রস্তুত।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return const MobilePosOutcome<MobilePosSaleOrder>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: 'ERR_PERMISSION_DENIED',
          messageEn: 'Permission denied opening counter cart.',
          messageBn: 'কার্ট খোলার অনুমতি আপনার নেই।',
        );
      }
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: _extractErrorCode(res.data, 'ERR_CART_OPEN'),
        messageEn: _extractMessage(res.data, 'Unable to open quick cart.'),
        messageBn: 'কুইক কার্ট খোলা যায়নি।',
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> scanAdd({
    required String saleId,
    required String bearerToken,
    String? barcode,
    String? productId,
    String? variantId,
    String packagingUnit = 'TABLET',
    int quantityDelta = 1,
    int? expectedVersion,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (barcode != null && barcode.trim().isNotEmpty) 'barcode': barcode.trim(),
        if (productId != null && productId.trim().isNotEmpty) 'product_id': productId.trim(),
        if (variantId != null && variantId.trim().isNotEmpty) 'variant_id': variantId.trim(),
        'packaging_unit': packagingUnit,
        'quantity_delta': quantityDelta < 1 ? 1 : quantityDelta,
        if (expectedVersion != null) 'expected_version': expectedVersion,
      };
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/scan-add/',
        body: payload,
        bearerToken: bearerToken,
      );
      return _parseCartOrderOutcome(res, successEn: 'Item added to cart.', successBn: 'কার্টে আইটেম যুক্ত হয়েছে।');
    } catch (_) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> mutateCartLine({
    required String saleId,
    required String lineId,
    required String bearerToken,
    int? delta,
    int? quantityUnits,
    String? packagingUnit,
    bool remove = false,
    int? expectedVersion,
  }) async {
    try {
      final payload = <String, dynamic>{
        'line_id': lineId,
        if (delta != null) 'delta': delta,
        if (quantityUnits != null) 'quantity_units': quantityUnits,
        if (packagingUnit != null && packagingUnit.isNotEmpty) 'packaging_unit': packagingUnit,
        if (remove) 'remove': true,
        if (expectedVersion != null) 'expected_version': expectedVersion,
      };
      final res = await _transport(
        'PATCH',
        '/api/v2/pos/sales/$saleId/cart-line/',
        body: payload,
        bearerToken: bearerToken,
      );
      return _parseCartOrderOutcome(res, successEn: 'Cart updated.', successBn: 'কার্ট আপডেট হয়েছে।');
    } catch (_) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobileUnitOptionsResponse>> fetchUnitOptions({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String? saleId,
    String? lineId,
    String? productId,
    String? variantId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileUnitOptionsResponse>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    try {
      String path;
      if (saleId != null && saleId.isNotEmpty) {
        final params = <String>[
          if (lineId != null && lineId.isNotEmpty) 'line_id=${Uri.encodeQueryComponent(lineId)}',
          if (productId != null && productId.isNotEmpty) 'product_id=${Uri.encodeQueryComponent(productId)}',
        ].join('&');
        path = '/api/v2/pos/sales/$saleId/unit-options/${params.isNotEmpty ? '?$params' : ''}';
      } else {
        final params = <String>[
          'branch=${Uri.encodeQueryComponent(targetBranchId)}',
          if (productId != null && productId.isNotEmpty) 'product_id=${Uri.encodeQueryComponent(productId)}',
          if (variantId != null && variantId.isNotEmpty) 'variant_id=${Uri.encodeQueryComponent(variantId)}',
        ].join('&');
        path = '/api/v2/pos/search/unit-options/?$params';
      }

      final res = await _transport('GET', path, bearerToken: bearerToken);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final dto = MobileUnitOptionsResponse.fromJson(res.data);
        return MobilePosOutcome<MobileUnitOptionsResponse>(
          uiState: dto.packagingOptions.isEmpty ? MobilePosUiState.empty : MobilePosUiState.ready,
          data: dto,
          messageEn: 'Loaded packaging unit options.',
          messageBn: 'প্যাকেজিং ইউনিট বিকল্প লোড হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return MobilePosOutcome<MobileUnitOptionsResponse>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: _extractErrorCode(res.data, 'ERR_PERMISSION_DENIED'),
          messageEn: _extractMessage(res.data, 'Permission denied inspecting packaging options.'),
          messageBn: _extractMessageBn(res.data, 'প্যাকেজিং ইউনিট দেখার অনুমতি নেই।'),
        );
      }
      return MobilePosOutcome<MobileUnitOptionsResponse>(
        uiState: MobilePosUiState.error,
        errorCode: _extractErrorCode(res.data, 'ERR_UNIT_OPTIONS_FAILED'),
        messageEn: _extractMessage(res.data, 'Failed to load packaging unit options.'),
        messageBn: _extractMessageBn(res.data, 'প্যাকেজিং ইউনিট অপশন লোড করা যায়নি।'),
      );
    } catch (_) {
      return MobilePosOutcome<MobileUnitOptionsResponse>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> selectCartLineUnit({
    required String saleId,
    required String bearerToken,
    required String packagingUnit,
    String? lineId,
    int? lineNumber,
    int? quantityUnits,
    int? conversionFactor,
    String conversionMode = 'KEEP_QUANTITY',
    int? expectedVersion,
    String? overrideReason,
    String? actorRole,
    String? actorTenantId,
    String? actorBranchId,
    String? targetTenantId,
    String? targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    if (actorRole != null && actorRole.isNotEmpty) {
      final guard = _domainGuardClient.authorizeScope(
        actorRole: actorRole,
        actorTenantId: actorTenantId ?? '',
        actorBranchId: actorBranchId ?? '',
        targetTenantId: targetTenantId ?? '',
        targetBranchId: targetBranchId ?? '',
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );
      if (guard.uiState != MobilePosUiState.ready) {
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: guard.uiState,
          errorCode: guard.errorCode,
          messageEn: guard.messageEn,
          messageBn: guard.messageBn,
        );
      }
    }

    try {
      final payload = <String, dynamic>{
        if (lineId != null && lineId.isNotEmpty) 'line_id': lineId,
        if (lineNumber != null) 'line_number': lineNumber,
        'packaging_unit': packagingUnit.trim().toUpperCase(),
        if (quantityUnits != null) 'quantity_units': quantityUnits,
        if (conversionFactor != null) 'conversion_factor': conversionFactor,
        'conversion_mode': conversionMode.trim().toUpperCase(),
        if (expectedVersion != null) 'expected_version': expectedVersion,
        if (overrideReason != null && overrideReason.trim().isNotEmpty)
          'override_reason': overrideReason.trim(),
      };
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/select-unit/',
        body: payload,
        bearerToken: bearerToken,
      );
      return _parseCartOrderOutcome(
        res,
        successEn: 'Packaging unit updated ($packagingUnit).',
        successBn: 'প্যাকেজিং ইউনিট পরিবর্তন করে $packagingUnit করা হয়েছে।',
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> updateCartPricing({
    required String saleId,
    required Map<String, dynamic> pricingPayload,
    required String bearerToken,
    String? actorRole,
    String? actorTenantId,
    String? actorBranchId,
    String? targetTenantId,
    String? targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    if (actorRole != null && actorRole.isNotEmpty) {
      final guard = _domainGuardClient.authorizeScope(
        actorRole: actorRole,
        actorTenantId: actorTenantId ?? '',
        actorBranchId: actorBranchId ?? '',
        targetTenantId: targetTenantId ?? '',
        targetBranchId: targetBranchId ?? '',
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );
      if (guard.uiState != MobilePosUiState.ready) {
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: guard.uiState,
          errorCode: guard.errorCode,
          messageEn: guard.messageEn,
          messageBn: guard.messageBn,
        );
      }
    }

    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/update-pricing/',
        body: pricingPayload,
        bearerToken: bearerToken,
      );
      return _parseCartOrderOutcome(
        res,
        successEn: 'Cart prices, discount & rounding updated.',
        successBn: 'কার্টের মূল্য, ছাড় ও রাউন্ডিং হালনাগাদ হয়েছে।',
        emptyIfNoLines: false,
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> confirmCartPricing({
    required String saleId,
    required String bearerToken,
    String? expectedGrandTotalBdt,
    String? expectedPricingHash,
    int? expectedVersion,
    String? actorRole,
    String? actorTenantId,
    String? actorBranchId,
    String? targetTenantId,
    String? targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    if (actorRole != null && actorRole.isNotEmpty) {
      final guard = _domainGuardClient.authorizeScope(
        actorRole: actorRole,
        actorTenantId: actorTenantId ?? '',
        actorBranchId: actorBranchId ?? '',
        targetTenantId: targetTenantId ?? '',
        targetBranchId: targetBranchId ?? '',
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );
      if (guard.uiState != MobilePosUiState.ready) {
        return MobilePosOutcome<MobilePosSaleOrder>(
          uiState: guard.uiState,
          errorCode: guard.errorCode,
          messageEn: guard.messageEn,
          messageBn: guard.messageBn,
        );
      }
    }

    try {
      final payload = <String, dynamic>{
        if (expectedGrandTotalBdt != null && expectedGrandTotalBdt.isNotEmpty)
          'expected_grand_total_bdt': expectedGrandTotalBdt,
        if (expectedPricingHash != null && expectedPricingHash.isNotEmpty)
          'expected_pricing_hash': expectedPricingHash,
        if (expectedVersion != null) 'expected_version': expectedVersion,
      };
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/$saleId/confirm-pricing/',
        body: payload,
        bearerToken: bearerToken,
      );
      return _parseCartOrderOutcome(
        res,
        successEn: 'Cart prices confirmed with reproducible server signature.',
        successBn: 'সার্ভার স্বাক্ষরসহ কার্টের মোট মূল্য নিশ্চিত হয়েছে।',
        emptyIfNoLines: false,
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> holdCart({
    required String saleId,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String? holdReference,
    String? holdNote,
    int? holdTtlMinutes,
    bool reserveStock = false,
    int? reservationTtlMinutes,
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    if (saleId.trim().isEmpty) {
      return const MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_EMPTY_CART',
        messageEn: 'Active cart ID is missing before holding.',
        messageBn: 'হোল্ড করার জন্য সক্রিয় কার্ট আইডি পাওয়া যায়নি।',
      );
    }
    if (holdTtlMinutes != null && (holdTtlMinutes < 1 || holdTtlMinutes > 1440)) {
      return const MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_INVALID_HOLD_TTL',
        messageEn: 'hold_ttl_minutes must be between 1 and 1440 minutes.',
        messageBn: 'হোল্ডের মেয়াদ ১ থেকে ১৪৪০ মিনিটের মধ্যে হতে হবে।',
      );
    }
    if (reservationTtlMinutes != null &&
        (reservationTtlMinutes < 1 ||
            reservationTtlMinutes > 1440 ||
            (holdTtlMinutes != null && reservationTtlMinutes > holdTtlMinutes))) {
      return const MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_INVALID_HOLD_TTL',
        messageEn: 'reservation_ttl_minutes must be within 1..1440 and <= hold_ttl_minutes.',
        messageBn: 'রিজার্ভেশন মেয়াদ হোল্ডের মোট সময়ের বেশি হতে পারবে না।',
      );
    }

    try {
      final payload = <String, dynamic>{
        if (holdReference != null && holdReference.trim().isNotEmpty)
          'hold_reference': holdReference.trim(),
        if (holdNote != null && holdNote.trim().isNotEmpty) 'hold_note': holdNote.trim(),
        if (holdTtlMinutes != null) 'hold_ttl_minutes': holdTtlMinutes,
        'reserve_stock': reserveStock,
        if (reserveStock && reservationTtlMinutes != null)
          'reservation_ttl_minutes': reservationTtlMinutes,
        if (expectedVersion != null) 'expected_version': expectedVersion,
      };
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/${saleId.trim()}/hold/',
        body: payload,
        bearerToken: bearerToken,
      );
      return _parseCartOrderOutcome(
        res,
        successEn: 'Cart parked safely on hold. Counter is free for next customer.',
        successBn: 'কার্টটি নিরাপদে হোল্ড করা হয়েছে। পরবর্তী গ্রাহকের জন্য কাউন্টার প্রস্তুত।',
        emptyIfNoLines: false,
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobileHeldCartListResult>> listHeldCarts({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool includeExpired = true,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: false,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileHeldCartListResult>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    try {
      final branchPart = targetBranchId.trim().isNotEmpty
          ? '&branch=${Uri.encodeQueryComponent(targetBranchId.trim())}'
          : '';
      final res = await _transport(
        'GET',
        '/api/v2/pos/sales/held/?include_expired=${includeExpired ? 'true' : 'false'}$branchPart',
        bearerToken: bearerToken,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final dto = MobileHeldCartListResult.fromJson(res.data);
        if (dto.results.isEmpty) {
          return MobilePosOutcome<MobileHeldCartListResult>(
            uiState: MobilePosUiState.empty,
            data: dto,
            messageEn: 'No held carts currently parked in this branch.',
            messageBn: 'এই শাখায় কোনো হোল্ড করা কার্ট নেই।',
          );
        }
        return MobilePosOutcome<MobileHeldCartListResult>(
          uiState: MobilePosUiState.ready,
          data: dto,
          messageEn: 'Loaded ${dto.count} held cart(s) (${dto.staleCount} stale).',
          messageBn: '${dto.count}টি হোল্ড কার্ট লোড হয়েছে (${dto.staleCount}টি সতর্কতা)।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return MobilePosOutcome<MobileHeldCartListResult>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: _extractErrorCode(res.data, 'ERR_PERMISSION_DENIED'),
          messageEn: _extractMessage(res.data, 'Permission denied inspecting held carts.'),
          messageBn: _extractMessageBn(res.data, 'হোল্ড কার্ট তালিকা দেখার অনুমতি নেই।'),
        );
      }
      return MobilePosOutcome<MobileHeldCartListResult>(
        uiState: MobilePosUiState.error,
        errorCode: _extractErrorCode(res.data, 'ERR_HTTP_${res.statusCode}'),
        messageEn: _extractMessage(res.data, 'Failed to load held carts.'),
        messageBn: _extractMessageBn(res.data, 'হোল্ড কার্ট তালিকা লোড করা যায়নি।'),
      );
    } catch (_) {
      return MobilePosOutcome<MobileHeldCartListResult>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobileResumeCartResult>> resumeCart({
    required String saleId,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool acknowledgeStale = false,
    bool repriceToLive = true,
    bool reReserveStock = true,
    bool allowUnreservedShortage = false,
    int? expectedVersion,
    String? note,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileResumeCartResult>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    try {
      final payload = <String, dynamic>{
        'acknowledge_stale': acknowledgeStale,
        'reprice_to_live': repriceToLive,
        're_reserve_stock': reReserveStock,
        'allow_unreserved_shortage': allowUnreservedShortage,
        if (expectedVersion != null) 'expected_version': expectedVersion,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      };
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/${saleId.trim()}/resume/',
        body: payload,
        bearerToken: bearerToken,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final rawSale = res.data['sale'] is Map
            ? Map<String, dynamic>.from(res.data['sale'] as Map)
            : res.data;
        final saleObj = MobilePosSaleOrder.fromJson(rawSale);
        final staleness = res.data['staleness'] is Map
            ? MobileHeldCartStaleness.fromJson(Map<String, dynamic>.from(res.data['staleness'] as Map))
            : (saleObj.staleness ?? const MobileHeldCartStaleness());
        return MobilePosOutcome<MobileResumeCartResult>(
          uiState: MobilePosUiState.ready,
          data: MobileResumeCartResult(
            saleId: saleObj.saleId,
            sale: saleObj,
            staleness: staleness,
            requiresConfirmation: false,
          ),
          messageEn: 'Held cart resumed cleanly to active counter.',
          messageBn: 'হোল্ড করা কার্টটি সক্রিয় কাউন্টারে পুনরুদ্ধার হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return MobilePosOutcome<MobileResumeCartResult>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: _extractErrorCode(res.data, 'ERR_PERMISSION_DENIED'),
          messageEn: _extractMessage(res.data, 'Permission denied resuming held cart.'),
          messageBn: _extractMessageBn(res.data, 'হোল্ড কার্ট পুনরুদ্ধারের অনুমতি নেই।'),
        );
      }
      final errCode = _extractErrorCode(res.data, 'ERR_VALIDATION_FAILED');
      MobileResumeCartResult? confirmData;
      if (errCode == 'ERR_HELD_CART_REQUIRES_CONFIRMATION') {
        final diagRaw = res.data['details'] is Map
            ? Map<String, dynamic>.from(res.data['details'] as Map)
            : res.data;
        confirmData = MobileResumeCartResult(
          saleId: saleId.trim(),
          staleness: MobileHeldCartStaleness.fromJson(diagRaw),
          requiresConfirmation: true,
        );
      }
      return MobilePosOutcome<MobileResumeCartResult>(
        uiState: MobilePosUiState.error,
        data: confirmData,
        errorCode: errCode,
        messageEn: _extractMessage(res.data, 'Held cart requires confirmation before resuming.'),
        messageBn: _extractMessageBn(res.data, 'হোল্ড কার্ট রিজিউম করার আগে নিশ্চিতকরণ প্রয়োজন।'),
      );
    } catch (_) {
      return MobilePosOutcome<MobileResumeCartResult>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobileExpireStaleResult>> expireStaleHolds({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool voidExpiredHolds = false,
    String? reason,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileExpireStaleResult>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    try {
      final payload = <String, dynamic>{
        if (targetBranchId.trim().isNotEmpty) 'branch': targetBranchId.trim(),
        'void_expired_holds': voidExpiredHolds,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      };
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/expire-stale-holds/',
        body: payload,
        bearerToken: bearerToken,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final dto = MobileExpireStaleResult.fromJson(res.data);
        return MobilePosOutcome<MobileExpireStaleResult>(
          uiState: MobilePosUiState.ready,
          data: dto,
          messageEn: dto.messageEn.isNotEmpty
              ? dto.messageEn
              : 'Released ${dto.releasedBaseUnits} reserved base unit(s).',
          messageBn: dto.messageBn.isNotEmpty
              ? dto.messageBn
              : '${dto.releasedBaseUnits}টি রিজার্ভকৃত ইউনিট মুক্ত করা হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return MobilePosOutcome<MobileExpireStaleResult>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: _extractErrorCode(res.data, 'ERR_PERMISSION_DENIED'),
          messageEn: _extractMessage(res.data, 'Permission denied expiring stale holds.'),
          messageBn: _extractMessageBn(res.data, 'মেয়াদোত্তীর্ণ হোল্ড মুক্ত করার অনুমতি নেই।'),
        );
      }
      return MobilePosOutcome<MobileExpireStaleResult>(
        uiState: MobilePosUiState.error,
        errorCode: _extractErrorCode(res.data, 'ERR_EXPIRE_STALE_FAILED'),
        messageEn: _extractMessage(res.data, 'Failed to sweep expired holds.'),
        messageBn: _extractMessageBn(res.data, 'মেয়াদোত্তীর্ণ হোল্ড প্রসেস করা যায়নি।'),
      );
    } catch (_) {
      return MobilePosOutcome<MobileExpireStaleResult>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> expireHold({
    required String saleId,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool voidHold = false,
    String? reason,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    try {
      final payload = <String, dynamic>{
        'void_hold': voidHold,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      };
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/${saleId.trim()}/expire-hold/',
        body: payload,
        bearerToken: bearerToken,
      );
      return _parseCartOrderOutcome(
        res,
        successEn: 'Held cart stock reservation released cleanly.',
        successBn: 'হোল্ড কার্টের স্টক রিজার্ভেশন মুক্ত করা হয়েছে।',
        emptyIfNoLines: false,
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosSaleOrder>> cancelHold({
    required String saleId,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String? reason,
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    try {
      final payload = <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (expectedVersion != null) 'expected_version': expectedVersion,
      };
      final res = await _transport(
        'POST',
        '/api/v2/pos/sales/${saleId.trim()}/cancel-hold/',
        body: payload,
        bearerToken: bearerToken,
      );
      return _parseCartOrderOutcome(
        res,
        successEn: 'Held cart cancelled and any reservations released.',
        successBn: 'হোল্ড করা কার্ট বাতিল ও রিজার্ভেশন মুক্ত করা হয়েছে।',
        emptyIfNoLines: false,
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  MobilePosOutcome<MobilePosSaleOrder> _parseCartOrderOutcome(
    MobilePosHttpResponse res, {
    required String successEn,
    required String successBn,
    bool emptyIfNoLines = true,
  }) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final rawSale = res.data['sale'] is Map
          ? Map<String, dynamic>.from(res.data['sale'] as Map)
          : res.data;
      final order = MobilePosSaleOrder.fromJson(rawSale);
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: (emptyIfNoLines && order.lines.isEmpty) ? MobilePosUiState.empty : MobilePosUiState.ready,
        data: order,
        messageEn: successEn,
        messageBn: successBn,
      );
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      return MobilePosOutcome<MobilePosSaleOrder>(
        uiState: MobilePosUiState.permissionDenied,
        errorCode: _extractErrorCode(res.data, 'ERR_PERMISSION_DENIED'),
        messageEn: _extractMessage(res.data, 'Permission denied updating cart.'),
        messageBn: _extractMessageBn(res.data, 'কার্ট পরিবর্তনের অনুমতি আপনার নেই।'),
      );
    }
    return MobilePosOutcome<MobilePosSaleOrder>(
      uiState: MobilePosUiState.error,
      errorCode: _extractErrorCode(res.data, 'ERR_CART_MUTATION'),
      messageEn: _extractMessage(res.data, 'Failed to update cart item.'),
      messageBn: _extractMessageBn(res.data, 'কার্ট আইটেম আপডেট করা যায়নি।'),
    );
  }

  // ---------------------------------------------------------------------------
  // P226: Preorders, Delivery Fulfillment & Audited Address Privacy Controls
  // ---------------------------------------------------------------------------

  Future<MobilePosOutcome<MobileDeliveryListResult>> listDeliveryOrders({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String stateFilter = '',
    String modeFilter = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileDeliveryListResult>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    try {
      final qp = <String>[
        if (targetBranchId.trim().isNotEmpty) 'branch=${Uri.encodeComponent(targetBranchId.trim())}',
        if (stateFilter.trim().isNotEmpty) 'fulfillment_state=${Uri.encodeComponent(stateFilter.trim())}',
        if (modeFilter.trim().isNotEmpty) 'fulfillment_mode=${Uri.encodeComponent(modeFilter.trim())}',
      ];
      final res = await _transport(
        'GET',
        '/api/v2/pos/deliveries/?${qp.join('&')}',
        bearerToken: bearerToken,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final dto = MobileDeliveryListResult.fromJson(res.data);
        return MobilePosOutcome<MobileDeliveryListResult>(
          uiState: dto.results.isEmpty ? MobilePosUiState.empty : MobilePosUiState.ready,
          data: dto,
          messageEn: 'Loaded ${dto.count} preorder/delivery order(s).',
          messageBn: '${dto.count}টি প্রি-অর্ডার/ডেলিভারি অর্ডার লোড হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return MobilePosOutcome<MobileDeliveryListResult>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: _extractErrorCode(res.data, 'ERR_PERMISSION_DENIED'),
          messageEn: _extractMessage(res.data, 'Permission denied reading delivery orders.'),
          messageBn: _extractMessageBn(res.data, 'ডেলিভারি অর্ডার দেখার অনুমতি নেই।'),
        );
      }
      return MobilePosOutcome<MobileDeliveryListResult>(
        uiState: MobilePosUiState.error,
        errorCode: _extractErrorCode(res.data, 'ERR_DELIVERY_LIST'),
        messageEn: _extractMessage(res.data, 'Failed to load delivery orders.'),
        messageBn: _extractMessageBn(res.data, 'ডেলিভারি অর্ডার লোড করা যায়নি।'),
      );
    } catch (_) {
      return MobilePosOutcome<MobileDeliveryListResult>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosDeliveryOrder>> createDeliveryOrder({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required Map<String, dynamic> payload,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }

    final mode = (payload['fulfillment_mode'] ?? 'HOME_DELIVERY').toString().trim().toUpperCase();
    final name = (payload['recipient_name'] ?? '').toString().trim();
    final phone = (payload['recipient_phone'] ?? '').toString().trim();
    final addr = (payload['delivery_address_line'] ?? '').toString().trim();
    if (name.isEmpty || phone.isEmpty) {
      return const MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_RECIPIENT_REQUIRED',
        messageEn: 'Recipient name and phone are required for preorder/delivery.',
        messageBn: 'প্রাপকের নাম এবং মোবাইল নম্বর দেওয়া আবশ্যক।',
      );
    }
    if (mode == 'HOME_DELIVERY' && addr.isEmpty) {
      return const MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_DELIVERY_ADDRESS_REQUIRED',
        messageEn: 'Street address is required for HOME_DELIVERY orders.',
        messageBn: 'হোম ডেলিভারির জন্য পূর্ণ ঠিকানা দেওয়া আবশ্যক।',
      );
    }

    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/deliveries/',
        body: payload,
        bearerToken: bearerToken,
      );
      return _parseDeliveryOrderOutcome(
        res,
        successEn: 'Preorder/delivery order created with server reservation & privacy policy.',
        successBn: 'প্রি-অর্ডার/ডেলিভারি অর্ডার সফলভাবে তৈরি হয়েছে।',
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosDeliveryOrder>> updateDeliveryOrder({
    required String deliveryId,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required Map<String, dynamic> payload,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport(
        'PATCH',
        '/api/v2/pos/deliveries/${deliveryId.trim()}/',
        body: payload,
        bearerToken: bearerToken,
      );
      return _parseDeliveryOrderOutcome(
        res,
        successEn: 'Delivery order updated cleanly.',
        successBn: 'ডেলিভারি অর্ডার আপডেট হয়েছে।',
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosDeliveryOrder>> archiveDeliveryOrder({
    required String deliveryId,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String reason = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final suffix = reason.trim().isEmpty ? '' : '?reason=${Uri.encodeComponent(reason.trim())}';
      final res = await _transport(
        'DELETE',
        '/api/v2/pos/deliveries/${deliveryId.trim()}/$suffix',
        bearerToken: bearerToken,
      );
      return _parseDeliveryOrderOutcome(
        res,
        successEn: 'Delivery order archived safely.',
        successBn: 'ডেলিভারি অর্ডার নিরাপদে আর্কাইভ করা হয়েছে।',
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobilePosDeliveryOrder>> transitionDelivery({
    required String deliveryId,
    required String actionSlug,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    Map<String, dynamic> payload = const <String, dynamic>{},
    required String successEn,
    required String successBn,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/deliveries/${deliveryId.trim()}/$actionSlug/',
        body: payload,
        bearerToken: bearerToken,
      );
      return _parseDeliveryOrderOutcome(
        res,
        successEn: successEn,
        successBn: successBn,
      );
    } catch (_) {
      return MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  Future<MobilePosOutcome<MobileAddressRevealResult>> revealDeliveryAddress({
    required String deliveryId,
    required String reason,
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) async {
    final guard = _domainGuardClient.authorizeScope(
      actorRole: actorRole,
      actorTenantId: actorTenantId,
      actorBranchId: actorBranchId,
      targetTenantId: targetTenantId,
      targetBranchId: targetBranchId,
      requireWrite: true,
      subscriptionSuspended: subscriptionSuspended,
      isOffline: isOffline,
    );
    if (guard.uiState != MobilePosUiState.ready) {
      return MobilePosOutcome<MobileAddressRevealResult>(
        uiState: guard.uiState,
        errorCode: guard.errorCode,
        messageEn: guard.messageEn,
        messageBn: guard.messageBn,
      );
    }
    if (reason.trim().length < 3) {
      return const MobilePosOutcome<MobileAddressRevealResult>(
        uiState: MobilePosUiState.error,
        errorCode: 'ERR_REVEAL_REASON_REQUIRED',
        messageEn: 'Reason (>= 3 chars) is mandatory to reveal unmasked delivery address.',
        messageBn: 'পূর্ণ ঠিকানা দেখতে কমপক্ষে ৩ অক্ষরের কারণ উল্লেখ করা আবশ্যক।',
      );
    }
    try {
      final res = await _transport(
        'POST',
        '/api/v2/pos/deliveries/${deliveryId.trim()}/reveal-address/',
        body: <String, dynamic>{'reason': reason.trim()},
        bearerToken: bearerToken,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return MobilePosOutcome<MobileAddressRevealResult>(
          uiState: MobilePosUiState.ready,
          data: MobileAddressRevealResult.fromJson(res.data),
          messageEn: 'Unmasked delivery address revealed with privacy audit log.',
          messageBn: 'গোপনীয়তা অডিটসহ ডেলিভারির পূর্ণ ঠিকানা প্রদর্শিত হয়েছে।',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return MobilePosOutcome<MobileAddressRevealResult>(
          uiState: MobilePosUiState.permissionDenied,
          errorCode: _extractErrorCode(res.data, 'ERR_PERMISSION_DENIED'),
          messageEn: _extractMessage(res.data, 'Permission denied revealing delivery address.'),
          messageBn: _extractMessageBn(res.data, 'ডেলিভারির ঠিকানা দেখার অনুমতি নেই।'),
        );
      }
      return MobilePosOutcome<MobileAddressRevealResult>(
        uiState: MobilePosUiState.error,
        errorCode: _extractErrorCode(res.data, 'ERR_ADDRESS_PRIVACY_LOCKED'),
        messageEn: _extractMessage(res.data, 'Delivery address reveal rejected.'),
        messageBn: _extractMessageBn(res.data, 'ডেলিভারির ঠিকানা প্রদর্শন ব্যর্থ হয়েছে।'),
      );
    } catch (_) {
      return MobilePosOutcome<MobileAddressRevealResult>(
        uiState: MobilePosUiState.offline,
        errorCode: 'OFFLINE',
        messageEn: MobilePosUiState.offline.messageEn,
        messageBn: MobilePosUiState.offline.messageBn,
      );
    }
  }

  MobilePosOutcome<MobilePosDeliveryOrder> _parseDeliveryOrderOutcome(
    MobilePosHttpResponse res, {
    required String successEn,
    required String successBn,
  }) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: MobilePosUiState.ready,
        data: MobilePosDeliveryOrder.fromJson(res.data),
        messageEn: successEn,
        messageBn: successBn,
      );
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      return MobilePosOutcome<MobilePosDeliveryOrder>(
        uiState: MobilePosUiState.permissionDenied,
        errorCode: _extractErrorCode(res.data, 'ERR_PERMISSION_DENIED'),
        messageEn: _extractMessage(res.data, 'Permission denied updating delivery.'),
        messageBn: _extractMessageBn(res.data, 'ডেলিভারি অর্ডার পরিবর্তনের অনুমতি নেই।'),
      );
    }
    return MobilePosOutcome<MobilePosDeliveryOrder>(
      uiState: MobilePosUiState.error,
      errorCode: _extractErrorCode(res.data, 'ERR_DELIVERY_OPERATION'),
      messageEn: _extractMessage(res.data, 'Delivery operation failed.'),
      messageBn: _extractMessageBn(res.data, 'ডেলিভারি অপারেশন ব্যর্থ হয়েছে।'),
    );
  }

  static String _extractErrorCode(Map<String, dynamic> data, String fallback) {
    if (data['error_code'] != null && data['error_code'].toString().isNotEmpty) {
      return data['error_code'].toString();
    }
    if (data['details'] is Map && (data['details'] as Map)['error_code'] != null) {
      return (data['details'] as Map)['error_code'].toString();
    }
    return fallback;
  }

  static String _extractMessage(Map<String, dynamic> data, String fallback) {
    final msg = data['message_en'] ?? data['message'] ?? data['packaging_unit'] ?? data['quantity_units'] ?? data['detail'];
    if (msg != null && msg.toString().isNotEmpty) return msg.toString();
    return fallback;
  }

  static String _extractMessageBn(Map<String, dynamic> data, String fallback) {
    final msg = data['message_bn'];
    if (msg != null && msg.toString().isNotEmpty) return msg.toString();
    return fallback;
  }

  Future<MobilePosOutcome<MobileRxGateStatus>> getRxGateStatus({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.getRxGateStatus(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosSaleOrder>> attachPrescription({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String doctorName,
    required String doctorBmdcNo,
    String patientToken = '',
    String rxReferenceCode = '',
    String dosageInstructions = '',
    int durationDays = 7,
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.attachPrescription(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        doctorName: doctorName,
        doctorBmdcNo: doctorBmdcNo,
        patientToken: patientToken,
        rxReferenceCode: rxReferenceCode,
        dosageInstructions: dosageInstructions,
        durationDays: durationDays,
        expectedVersion: expectedVersion,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosSaleOrder>> verifyRxSale({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    String pharmacistPcbNo = '',
    String notes = '',
    String rxReferenceCode = '',
    String doctorName = '',
    String doctorBmdcNo = '',
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.verifyRxSale(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        pharmacistPcbNo: pharmacistPcbNo,
        notes: notes,
        rxReferenceCode: rxReferenceCode,
        doctorName: doctorName,
        doctorBmdcNo: doctorBmdcNo,
        expectedVersion: expectedVersion,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosSaleOrder>> rejectRxSale({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String reason,
    String pharmacistPcbNo = '',
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.rejectRxSale(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        reason: reason,
        pharmacistPcbNo: pharmacistPcbNo,
        expectedVersion: expectedVersion,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobileRxGateStatus>> offlineRxPreflight({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.offlineRxPreflight(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobileAntibioticRegisterListResult>> listAntibioticRegister({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String saleFilter = '',
    String statusFilter = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.listAntibioticRegister(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleFilter: saleFilter,
        statusFilter: statusFilter,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosSaleOrder>> recordPaymentAttempt({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String tenderType,
    required String amountBdt,
    required String idempotencyKey,
    String gatewayReference = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.recordPaymentAttempt(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        tenderType: tenderType,
        amountBdt: amountBdt,
        idempotencyKey: idempotencyKey,
        gatewayReference: gatewayReference,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobileFefoAllocationPlan>> getFefoPlan({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.getFefoPlan(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosSaleOrder>> allocateStockFefo({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    Map<String, String>? batchOverrides,
    String overrideReason = '',
    int? expectedVersion,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.allocateStockFefo(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        batchOverrides: batchOverrides,
        overrideReason: overrideReason,
        expectedVersion: expectedVersion,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosSaleOrder>> finalizeSale({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    bool requiresRxVerification = false,
    String rxGateStatus = 'NOT_REQUIRED',
    bool isOfflineSync = false,
    Map<String, String>? batchOverrides,
    String overrideReason = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.finalizeSale(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        requiresRxVerification: requiresRxVerification,
        rxGateStatus: rxGateStatus,
        isOfflineSync: isOfflineSync,
        batchOverrides: batchOverrides,
        overrideReason: overrideReason,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosSaleOrder>> submitSplitPayments({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required List<MobileSplitPaymentInput> splits,
    String batchIdempotencyKey = '',
    bool requireVerified = true,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.submitSplitPayments(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        splits: splits,
        batchIdempotencyKey: batchIdempotencyKey,
        requireVerified: requireVerified,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosSaleOrder>> verifyPaymentAttempt({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String attemptId,
    required String gatewayReference,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.verifyPaymentAttempt(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        attemptId: attemptId,
        gatewayReference: gatewayReference,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosSaleOrder>> voidPaymentAttempt({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String attemptId,
    required String reason,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.voidPaymentAttempt(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        attemptId: attemptId,
        reason: reason,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobileCashierCloseReconciliation>> getCloseReconciliation({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String registerAssignmentId = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.getCloseReconciliation(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        registerAssignmentId: registerAssignmentId,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobileCashierCloseReconciliation>> submitCloseReconciliation({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String countedCashBdt,
    String registerAssignmentId = '',
    String notes = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.submitCloseReconciliation(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        countedCashBdt: countedCashBdt,
        registerAssignmentId: registerAssignmentId,
        notes: notes,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<List<MobilePosCustomer>>> listCustomers({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.listCustomers(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosCustomer>> approveCustomerCredit({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String customerId,
    required String creditLimitBdt,
    int creditTermsDays = 30,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.approveCustomerCredit(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        customerId: customerId,
        creditLimitBdt: creditLimitBdt,
        creditTermsDays: creditTermsDays,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobilePosSaleOrder>> attachCustomerToSale({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String saleId,
    required String customerId,
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.attachCustomerToSale(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        saleId: saleId,
        customerId: customerId,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<List<MobileCustomerDueRecord>>> listCustomerDues({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    String customerId = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.listCustomerDues(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        customerId: customerId,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );

  Future<MobilePosOutcome<MobileDueCollectionOutcome>> collectCustomerDue({
    required String bearerToken,
    required String actorRole,
    required String actorTenantId,
    required String actorBranchId,
    required String targetTenantId,
    required String targetBranchId,
    required String dueId,
    required String tenderType,
    required String amountBdt,
    String cashTenderedBdt = '',
    String gatewayReference = '',
    String idempotencyKey = '',
    String notes = '',
    bool subscriptionSuspended = false,
    bool isOffline = false,
  }) =>
      _domainGuardClient.collectCustomerDue(
        bearerToken: bearerToken,
        actorRole: actorRole,
        actorTenantId: actorTenantId,
        actorBranchId: actorBranchId,
        targetTenantId: targetTenantId,
        targetBranchId: targetBranchId,
        dueId: dueId,
        tenderType: tenderType,
        amountBdt: amountBdt,
        cashTenderedBdt: cashTenderedBdt,
        gatewayReference: gatewayReference,
        idempotencyKey: idempotencyKey,
        notes: notes,
        subscriptionSuspended: subscriptionSuspended,
        isOffline: isOffline,
      );
}
