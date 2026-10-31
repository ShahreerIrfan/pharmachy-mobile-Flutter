import 'package:flutter/foundation.dart';
import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';

/// Architecture Decision: ADR-0014, ADR-0047, ADR-0054
/// Flutter Mobile Global Exception Handler:
/// Centralizes exception decoding, mapping canonical machine error codes into
/// MobileUiStates, preserving trace IDs, and rendering safe localized English and Bengali feedback.
@immutable
class MobileResolvedError {
  final MobileUiState uiState;
  final String errorCode;
  final String requestId;
  final int httpStatus;
  final bool isRetryable;
  final String recoveryAction;
  final String localizedMessage;
  final Map<String, List<String>> fieldErrors;

  const MobileResolvedError({
    required this.uiState,
    required this.errorCode,
    required this.requestId,
    required this.httpStatus,
    required this.isRetryable,
    required this.recoveryAction,
    required this.localizedMessage,
    this.fieldErrors = const {},
  });
}

class MobileGlobalExceptionHandler {
  /// Resolves an ADR-0047 / ADR-0054 envelope into a clean mobile UI presentation state.
  static MobileResolvedError resolveEnvelope(
    MobileApiResponseEnvelope envelope, {
    String language = 'bn',
  }) {
    final lang = language.toLowerCase() == 'en' ? 'en' : 'bn';
    String code = envelope.errorCode ?? envelope.code;
    if (code.isEmpty || code == 'OK') {
      code = mapHttpStatusToCode(envelope.httpStatus);
    }

    final uiState = mapCodeToUiState(code, envelope.httpStatus);
    String msg = envelope.getLocalizedMessage(lang);
    if (msg.isEmpty) {
      msg = getDefaultLocalizedMessage(code, lang);
    }

    final reqId =
        envelope.requestId.isNotEmpty ? envelope.requestId : 'req-unknown';

    return MobileResolvedError(
      uiState: uiState,
      errorCode: code,
      requestId: reqId,
      httpStatus: envelope.httpStatus,
      isRetryable: envelope.isRetryable,
      recoveryAction: envelope.recoveryAction ?? 'RETRY_AFTER_BACKOFF',
      localizedMessage: msg,
      fieldErrors: envelope.fieldErrors,
    );
  }

  /// Resolves raw HTTP status and optional JSON body when full envelope is unavailable.
  static MobileResolvedError resolveRawHttp(
    int statusCode, {
    Map<String, dynamic>? rawJson,
    String language = 'bn',
    String? requestId,
  }) {
    final lang = language.toLowerCase() == 'en' ? 'en' : 'bn';
    final code = rawJson?['code'] as String? ??
        rawJson?['error_code'] as String? ??
        mapHttpStatusToCode(statusCode);

    final uiState = mapCodeToUiState(code, statusCode);
    final isRetryable = rawJson?['retryable'] as bool? ??
        rawJson?['is_retryable'] as bool? ??
        (statusCode == 503 || statusCode == 429);

    final recovery = rawJson?['recovery_action'] as String? ??
        (isRetryable ? 'RETRY_AFTER_BACKOFF' : 'CORRECT_INPUT_FIELDS');

    String msg = '';
    if (lang == 'bn') {
      msg = rawJson?['message_bn'] as String? ?? '';
    } else {
      msg = rawJson?['message_en'] as String? ??
          rawJson?['message'] as String? ??
          '';
    }

    if (msg.isEmpty) {
      msg = getDefaultLocalizedMessage(code, lang);
    }

    final reqId = requestId ??
        rawJson?['request_id'] as String? ??
        rawJson?['correlation_id'] as String? ??
        'req-unknown';

    return MobileResolvedError(
      uiState: uiState,
      errorCode: code,
      requestId: reqId,
      httpStatus: statusCode,
      isRetryable: isRetryable,
      recoveryAction: recovery,
      localizedMessage: msg,
      fieldErrors: const {},
    );
  }

  /// Maps canonical error codes to MobileUiState lifecycle states.
  static MobileUiState mapCodeToUiState(String errorCode, int httpStatus) {
    switch (errorCode) {
      case 'ERR_UNAUTHORIZED':
      case 'ERR_AUTH_EXPIRED':
      case 'ERR_PERMISSION_DENIED':
      case 'ERR_CROSS_TENANT_VIOLATION':
      case 'ERR_TENANT_INACTIVE':
      case 'ERR_SUBSCRIPTION_EXPIRED':
      case 'ERR_OFFLINE_LEASE_EXPIRED':
        return MobileUiState.permissionDenied;
      case 'ERR_DATABASE_UNAVAILABLE':
      case 'ERR_SYNC_NETWORK_TIMEOUT':
      case 'ERR_DB_LOCK_TIMEOUT':
        return MobileUiState.offline;
      default:
        return MobileUiState.error;
    }
  }

  /// Maps HTTP status code to default machine error code.
  static String mapHttpStatusToCode(int httpStatus) {
    switch (httpStatus) {
      case 400:
        return 'ERR_BAD_REQUEST';
      case 401:
        return 'ERR_UNAUTHORIZED';
      case 403:
        return 'ERR_PERMISSION_DENIED';
      case 404:
        return 'ERR_RESOURCE_NOT_FOUND';
      case 405:
        return 'ERR_METHOD_NOT_ALLOWED';
      case 409:
        return 'ERR_DATABASE_INTEGRITY';
      case 422:
        return 'ERR_VALIDATION_FAILED';
      case 429:
        return 'ERR_RATE_LIMIT_EXCEEDED';
      case 503:
        return 'ERR_DATABASE_UNAVAILABLE';
      default:
        return 'ERR_INTERNAL_SERVER_ERROR';
    }
  }

  /// Default localized user descriptions in Bengali and English.
  static String getDefaultLocalizedMessage(String errorCode, String language) {
    final isBn = language.toLowerCase() == 'bn';

    switch (errorCode) {
      case 'ERR_AUTH_EXPIRED':
      case 'ERR_UNAUTHORIZED':
        return isBn
            ? 'আপনার লগইন সেশনের মেয়াদ শেষ হয়েছে। পুনরায় লগইন করুন।'
            : 'Your authentication session has expired. Please log in again.';
      case 'ERR_PERMISSION_DENIED':
        return isBn
            ? 'এই কাজটি সম্পাদন করার অনুমতি আপনার নেই।'
            : 'You do not have permission to perform this action.';
      case 'ERR_CROSS_TENANT_VIOLATION':
        return isBn
            ? 'অন্য ফার্মেসির তথ্যে প্রবেশাধিকার কঠোরভাবে নিষিদ্ধ।'
            : 'Access to foreign pharmacy tenant resources is strictly forbidden.';
      case 'ERR_SUBSCRIPTION_EXPIRED':
        return isBn
            ? 'ফার্মেসির সাবস্ক্রিপশনের মেয়াদ শেষ হয়েছে। অনুগ্রহ করে আপনার প্ল্যান নবায়ন করুন।'
            : 'Pharmacy tenant subscription has expired. Please renew your plan.';
      case 'ERR_VALIDATION_FAILED':
        return isBn
            ? 'এক বা একাধিক তথ্যের মান সঠিক নয়।'
            : 'One or more input fields failed validation.';
      case 'ERR_DATABASE_INTEGRITY':
        return isBn
            ? 'একটি ডেটাবেজ ইন্টিগ্রিটি বা ডুপ্লিকেট রেকর্ড দ্বন্দ্ব তৈরি হয়েছে।'
            : 'A database integrity constraint or duplicate record conflict occurred.';
      case 'ERR_DATABASE_UNAVAILABLE':
        return isBn
            ? 'ডেটাবেজ সেবা সাময়িকভাবে অনুপলব্ধ বা লক করা আছে। কিছুক্ষণ পর পুনরায় চেষ্টা করুন।'
            : 'Database service is temporarily unavailable or locked. Safe to retry.';
      case 'ERR_SYNC_NETWORK_TIMEOUT':
        return isBn
            ? 'ক্লাউড সিঙ্কের সময় সংযোগ বিচ্ছিন্ন হয়েছে। স্বয়ংক্রিয়ভাবে পুনরায় চেষ্টা করা হচ্ছে।'
            : 'Network connection timed out during cloud sync. Retrying with exponential backoff.';
      case 'ERR_BATCH_EXPIRED':
        return isBn
            ? 'নির্বাচিত ওষুধের ব্যাচের মেয়াদ উত্তীর্ণ হয়েছে এবং এটি বিক্রি করা নিষিদ্ধ।'
            : 'The selected medicine batch has expired and cannot be dispensed.';
      case 'ERR_INSUFFICIENT_STOCK':
        return isBn
            ? 'অনুরোধকৃত পরিমাণ বিদ্যমান ব্যাচ স্টকের চেয়ে বেশি।'
            : 'Requested quantity exceeds available batch stock.';
      case 'ERR_RESOURCE_NOT_FOUND':
        return isBn
            ? 'অনুরোধকৃত রিসোর্সটি খুঁজে পাওয়া যায়নি।'
            : 'The requested resource was not found.';
      case 'ERR_RATE_LIMIT_EXCEEDED':
        return isBn
            ? 'অনুরোধের সীমা অতিক্রম করেছে। অনুগ্রহ করে কিছুক্ষণ পর পুনরায় চেষ্টা করুন।'
            : 'Request rate limit exceeded. Please retry shortly.';
      default:
        return isBn
            ? 'একটি অভ্যন্তরীণ সমস্যা দেখা দিয়েছে। অনুগ্রহ করে রিকোয়েস্ট আইডি সহ সাপোর্ট টিমের সাথে যোগাযোগ করুন।'
            : 'An internal server error occurred. Please contact support with the request ID.';
    }
  }
}
