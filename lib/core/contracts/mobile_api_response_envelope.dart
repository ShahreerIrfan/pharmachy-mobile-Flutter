import 'package:flutter/foundation.dart';

/// UI State enum for mobile screen lifecycle complying with ADR-0047.
enum MobileUiState {
  loading,
  success,
  empty,
  error,
  offline,
  permissionDenied,
}

/// Standard pagination metadata parsed from ADR-0047 response envelope.
@immutable
class MobilePaginationMeta {
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
  final int? nextPage;
  final int? previousPage;

  const MobilePaginationMeta({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
    this.nextPage,
    this.previousPage,
  });

  factory MobilePaginationMeta.fromJson(Map<String, dynamic> json) {
    return MobilePaginationMeta(
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
      hasNext: json['has_next'] as bool? ?? false,
      hasPrevious: json['has_previous'] as bool? ?? false,
      nextPage: (json['next_page'] as num?)?.toInt(),
      previousPage: (json['previous_page'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'page_size': pageSize,
      'total_count': totalCount,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_previous': hasPrevious,
      'next_page': nextPage,
      'previous_page': previousPage,
    };
  }
}

/// Standardized Mobile Manager API Response Envelope complying with ADR-0047.
@immutable
class MobileApiResponseEnvelope<T> {
  final bool success;
  final String code;
  final String? errorCode;
  final String requestId;
  final String timestamp;
  final T? data;
  final MobilePaginationMeta? pagination;
  final Map<String, dynamic> filters;
  final String messageEn;
  final String messageBn;
  final int httpStatus;
  final bool isRetryable;
  final String? recoveryAction;
  final Map<String, List<String>> fieldErrors;

  const MobileApiResponseEnvelope({
    required this.success,
    required this.code,
    this.errorCode,
    required this.requestId,
    required this.timestamp,
    this.data,
    this.pagination,
    this.filters = const {},
    required this.messageEn,
    required this.messageBn,
    this.httpStatus = 200,
    this.isRetryable = false,
    this.recoveryAction,
    this.fieldErrors = const {},
  });

  factory MobileApiResponseEnvelope.fromSuccessJson(
    Map<String, dynamic> json,
    T Function(dynamic data) dataParser,
  ) {
    final metaObj = json['meta'] as Map<String, dynamic>? ?? {};
    final paginationObj = metaObj['pagination'] as Map<String, dynamic>?;
    final filtersObj = metaObj['filters'] as Map<String, dynamic>? ?? {};

    return MobileApiResponseEnvelope<T>(
      success: true,
      code: json['code'] as String? ?? 'OK',
      requestId: json['request_id'] as String? ?? 'req-unknown',
      timestamp: json['timestamp'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      data: json.containsKey('data') && json['data'] != null
          ? dataParser(json['data'])
          : null,
      pagination: paginationObj != null
          ? MobilePaginationMeta.fromJson(paginationObj)
          : null,
      filters: filtersObj,
      messageEn:
          json['message_en'] as String? ?? 'Operation completed successfully.',
      messageBn:
          json['message_bn'] as String? ?? 'অপারেশনটি সফলভাবে সম্পন্ন হয়েছে।',
      httpStatus: 200,
      isRetryable: false,
    );
  }

  factory MobileApiResponseEnvelope.fromErrorJson(
    Map<String, dynamic> json, {
    int statusCode = 400,
  }) {
    final rawFieldErrors = json['field_errors'] as Map<String, dynamic>? ?? {};
    final parsedFieldErrors = <String, List<String>>{};
    rawFieldErrors.forEach((key, val) {
      if (val is List) {
        parsedFieldErrors[key] = val.map((e) => e.toString()).toList();
      } else {
        parsedFieldErrors[key] = [val.toString()];
      }
    });

    final errCode = json['error_code'] as String? ??
        json['code'] as String? ??
        'ERR_UNKNOWN';
    final resolvedStatus = (json['http_status'] as num?)?.toInt() ?? statusCode;

    return MobileApiResponseEnvelope<T>(
      success: false,
      code: errCode,
      errorCode: errCode,
      requestId: json['request_id'] as String? ??
          json['correlation_id'] as String? ??
          'req-err',
      timestamp: json['timestamp'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      data: null,
      pagination: null,
      filters: const {},
      messageEn: json['message_en'] as String? ??
          json['message'] as String? ??
          'An unexpected error occurred.',
      messageBn:
          json['message_bn'] as String? ?? 'একটি অপ্রত্যাশিত ত্রুটি ঘটেছে।',
      httpStatus: resolvedStatus,
      isRetryable:
          json['is_retryable'] as bool? ?? json['retryable'] as bool? ?? false,
      recoveryAction:
          json['recovery_action'] as String? ?? 'RETRY_AFTER_BACKOFF',
      fieldErrors: parsedFieldErrors,
    );
  }

  String getLocalizedMessage(String languageCode) {
    if (languageCode.toLowerCase() == 'bn' && messageBn.isNotEmpty) {
      return messageBn;
    }
    return messageEn;
  }

  MobileUiState deriveUiState({required bool isOffline}) {
    if (isOffline) {
      return MobileUiState.offline;
    }
    if (!success) {
      if (httpStatus == 403 || errorCode == 'ERR_PERMISSION_DENIED') {
        return MobileUiState.permissionDenied;
      }
      return MobileUiState.error;
    }
    if (pagination != null && pagination!.totalCount == 0) {
      return MobileUiState.empty;
    }
    if (data is List && (data as List).isEmpty) {
      return MobileUiState.empty;
    }
    return MobileUiState.success;
  }
}
