import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_cursor_page.dart';
import 'package:pharmacy_mobile_manager/services/mobile_security_service.dart';

/// Flutter Mobile Manager Safe Pagination & Unicode Search Service.
/// Architecture Decision: ADR-0053 (Deterministic Cursor Pagination, Bounded Page Sizes, and Validated Search).
class MobileSearchPaginationService {
  static const int minPageSize = 1;
  static const int maxPageSize = 100;
  static const int defaultPageSize = 20;

  static const Set<String> prohibitedProbes = {
    'password',
    'secret',
    'token',
    'hash',
    'salt',
    'is_superuser',
    'is_staff',
  };

  /// Strictly bounds requested page size between 1 and 100.
  /// Throws FormatException if requested size <= 0.
  static int boundPageSize(int requestedSize) {
    if (requestedSize < minPageSize) {
      throw const FormatException('Page size must be strictly positive (>= 1)');
    }
    return requestedSize > maxPageSize ? maxPageSize : requestedSize;
  }

  /// Normalizes search text: removes zero-width characters, trims whitespace and converts to lower case.
  static String normalizeSearchQuery(String? text) {
    if (text == null) return '';
    final cleaned = text.replaceAll('\u200C', '').replaceAll('\u200D', '');
    return cleaned.trim().toLowerCase();
  }

  /// Validates filter query parameters against whitelist and blocks ORM lookups and probe keywords.
  static bool validateFilterParameters(
    Map<String, String>? queryParams,
    Set<String>? allowedFields,
  ) {
    if (queryParams == null || queryParams.isEmpty) return true;

    for (final entry in queryParams.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;

      // 1. Block direct ORM lookup probes (__)
      if (key.contains('__')) {
        throw FormatException(
            "Direct ORM lookup probe '$key' is strictly forbidden.");
      }

      // 2. Block sensitive keyword probes
      final lowerKey = key.toLowerCase();
      for (final probe in prohibitedProbes) {
        if (lowerKey.contains(probe)) {
          throw FormatException(
              "Querying sensitive internal attribute '$key' is strictly forbidden.");
        }
      }

      // 3. Enforce declared whitelist if provided
      if (allowedFields != null &&
          allowedFields.isNotEmpty &&
          !allowedFields.contains(key)) {
        throw FormatException(
            "Unrecognized or forbidden filter parameter '$key'.");
      }
    }
    return true;
  }

  /// Strictly validates tenant scope matching trusted active session tenant.
  static bool verifyTenantBoundary({
    required String activeTenantId,
    String? requestedTenantId,
  }) {
    if (requestedTenantId == null || requestedTenantId.trim().isEmpty) {
      return true;
    }
    if (activeTenantId.trim().toLowerCase() !=
        requestedTenantId.trim().toLowerCase()) {
      throw SecurityException(
        'ERR_CROSS_TENANT_VIOLATION: Cross-tenant search query strictly forbidden.',
      );
    }
    return true;
  }

  /// Parses server response envelope into generic MobileCursorPage.
  static MobileCursorPage<T> parseCursorResponse<T>(
    Map<String, dynamic> json,
    T Function(dynamic item) itemParser,
  ) {
    final rawData = json['data'] as List<dynamic>? ?? [];
    final items = rawData.map((e) => itemParser(e)).toList();

    final meta = json['meta'] as Map<String, dynamic>?;
    final paginationJson = meta?['pagination'] as Map<String, dynamic>?;
    final filtersJson = meta?['filters'] as Map<String, dynamic>? ?? {};

    final pagination = paginationJson != null
        ? MobileCursorPaginationMeta.fromJson(paginationJson)
        : MobileCursorPaginationMeta(
            pageSize: boundPageSize(
                items.isNotEmpty ? items.length : defaultPageSize),
            hasNext: false,
            hasPrevious: false,
          );

    return MobileCursorPage<T>(
      items: items,
      pagination: pagination,
      filters: filtersJson,
      requestId: json['request_id'] as String? ?? '',
      messageEn: json['message_en'] as String? ?? '',
      messageBn: json['message_bn'] as String? ?? '',
    );
  }

  /// Resolves localized bilingual error message conforming to ADR-0014, ADR-0047, and ADR-0053.
  static Map<String, String> getBilingualErrorMessage(String errorCode) {
    if (errorCode.toUpperCase() == 'ERR_INVALID_CURSOR') {
      return {
        'en':
            'The provided pagination cursor is invalid, expired, or malformed.',
        'bn': 'প্রদত্ত পেজিনেশন কার্সারটি অবৈধ, মেয়াদোত্তীর্ণ বা বিকৃত।',
      };
    } else if (errorCode.toUpperCase() == 'ERR_VALIDATION_FAILED') {
      return {
        'en':
            'One or more query parameters or filter bounds failed validation.',
        'bn': 'এক বা একাধিক ফিল্টার প্যারামিটার বা পৃষ্ঠার পরিধি সঠিক নয়।',
      };
    } else if (errorCode.toUpperCase() == 'ERR_CROSS_TENANT_VIOLATION') {
      return {
        'en': 'Cross-tenant search query is strictly forbidden.',
        'bn': 'অন্য ফার্মেসির তথ্যে অনুসন্ধান কঠোরভাবে নিষিদ্ধ।',
      };
    }
    return {
      'en':
          'Search and pagination operation failed. Please check network connection.',
      'bn':
          'অনুসন্ধান ও পেজিনেশন পরিচালনায় ত্রুটি দেখা দিয়েছে। নেটওয়ার্ক সংযোগ পরীক্ষা করুন।',
    };
  }

  /// Maps error code to MobileUiState enum for Flutter screens.
  static MobileUiState resolveUiState(String errorCode) {
    final code = errorCode.toUpperCase();
    if (code == 'ERR_CROSS_TENANT_VIOLATION' ||
        code == 'ERR_PERMISSION_DENIED') {
      return MobileUiState.permissionDenied;
    }
    return MobileUiState.error;
  }
}
