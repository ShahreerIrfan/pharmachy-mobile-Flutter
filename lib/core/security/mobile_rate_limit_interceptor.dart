import 'package:flutter/foundation.dart';

/// Immutable tracking record for an active endpoint backoff window.
@immutable
class MobileRateLimitRecord {
  final String routeKey;
  final int waitSeconds;
  final DateTime throttledAt;

  const MobileRateLimitRecord({
    required this.routeKey,
    required this.waitSeconds,
    required this.throttledAt,
  });

  bool get isCooldownActive {
    final elapsed = DateTime.now().toUtc().difference(throttledAt).inSeconds;
    return elapsed < waitSeconds;
  }

  int get remainingSeconds {
    final elapsed = DateTime.now().toUtc().difference(throttledAt).inSeconds;
    final remaining = waitSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }
}

/// Mobile Manager Rate Limiting & Cooldown Interceptor complying with ADR-0048.
class MobileRateLimitManager {
  final Map<String, MobileRateLimitRecord> _throttles = {};

  void recordThrottle(String routeKey, int waitSeconds) {
    if (routeKey.isEmpty) {
      throw ArgumentError('routeKey cannot be empty');
    }
    _throttles[routeKey] = MobileRateLimitRecord(
      routeKey: routeKey,
      waitSeconds: waitSeconds > 0 ? waitSeconds : 1,
      throttledAt: DateTime.now().toUtc(),
    );
  }

  bool isThrottled(String routeKey) {
    final record = _throttles[routeKey];
    if (record == null) {
      return false;
    }
    if (!record.isCooldownActive) {
      _throttles.remove(routeKey);
      return false;
    }
    return true;
  }

  int getRemainingWaitSeconds(String routeKey) {
    final record = _throttles[routeKey];
    if (record == null) {
      return 0;
    }
    final remaining = record.remainingSeconds;
    if (remaining == 0) {
      _throttles.remove(routeKey);
    }
    return remaining;
  }

  String getLocalizedWarning(String routeKey, String languageCode) {
    final rem = getRemainingWaitSeconds(routeKey);
    if (languageCode.toLowerCase() == 'bn') {
      return 'অনুরোধের সীমা অতিক্রম করেছে। অনুগ্রহ করে $rem সেকেন্ড পর পুনরায় চেষ্টা করুন।';
    }
    return 'Request rate limit exceeded. Please retry after $rem seconds.';
  }

  void clearThrottle(String routeKey) {
    _throttles.remove(routeKey);
  }

  void clearAll() {
    _throttles.clear();
  }
}
