/// ADR-0072: Flutter Mobile Platform Feature Flag Client.
/// Implements server-authoritative evaluation hierarchy:
/// 1. Kill Switch Active -> false
/// 2. Tenant Override -> override value
/// 3. Plan Tier Gate -> check min plan tier
/// 4. Hashed Percentage Rollout -> deterministic bucket check
/// 5. Global Enabled -> true
/// 6. Safe Default -> default_enabled
library mobile_feature_flag_client;

import 'dart:convert';
import 'dart:typed_data';

class EvaluationResult {
  final bool isEnabled;
  final String reason;

  const EvaluationResult({required this.isEnabled, required this.reason});

  @override
  String toString() =>
      'EvaluationResult(isEnabled: $isEnabled, reason: $reason)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaluationResult &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          reason == other.reason;

  @override
  int get hashCode => isEnabled.hashCode ^ reason.hashCode;
}

class MobileFeatureFlagClient {
  static final RegExp _flagKeyPattern = RegExp(r'^[a-z0-9_-]{3,64}$');

  static const Set<String> _privilegedAdminRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static const Map<String, int> _planTierRanks = {
    'BASIC': 1,
    'STANDARD': 2,
    'PRO': 3,
  };

  /// RBAC Invariant: Only SuperAdmin and Platform Operator can mutate flags or toggle kill switch.
  static bool canRoleMutateFlags(String? role) {
    if (role == null) return false;
    return _privilegedAdminRoles.contains(role.toUpperCase().trim());
  }

  /// Evaluates if role can evaluate flags.
  static bool canRoleEvaluateFlags(String? role) {
    return role != null && role.trim().isNotEmpty;
  }

  /// Validates flag key syntax according to ADR-0072.
  static bool isValidFlagKey(String? flagKey) {
    if (flagKey == null) return false;
    return _flagKeyPattern.hasMatch(flagKey.trim());
  }

  /// Deterministic 0-99 rollout bucket using standard MD5 hash.
  static int calculateRolloutBucket(String flagKey, String tenantId) {
    final payload = '${flagKey.trim()}:${tenantId.trim()}';
    final bytes = utf8.encode(payload);
    final digest = _md5(Uint8List.fromList(bytes));

    // Convert first 8 bytes of digest to unsigned 64-bit integer modulo 100
    BigInt val = BigInt.zero;
    for (int i = 0; i < digest.length; i++) {
      val = (val << 8) | BigInt.from(digest[i]);
    }
    return (val % BigInt.from(100)).toInt();
  }

  /// Client-side evaluation helper mirroring ADR-0072 hierarchy.
  static EvaluationResult evaluateLocal({
    required bool isKillSwitchActive,
    bool? tenantOverride,
    String tenantPlanTier = 'BASIC',
    String minPlanTier = 'BASIC',
    int rolloutPercentage = 0,
    bool isEnabledGlobally = false,
    bool defaultEnabled = false,
    String flagKey = '',
    String tenantId = '',
  }) {
    // 1. Kill switch
    if (isKillSwitchActive) {
      return const EvaluationResult(
          isEnabled: false, reason: 'KILL_SWITCH_ACTIVE');
    }

    // 2. Tenant override
    if (tenantOverride != null) {
      return EvaluationResult(
          isEnabled: tenantOverride, reason: 'TENANT_OVERRIDE');
    }

    // 3. Plan tier gate
    final currentRank =
        _planTierRanks[tenantPlanTier.toUpperCase().trim()] ?? 1;
    final requiredRank = _planTierRanks[minPlanTier.toUpperCase().trim()] ?? 1;
    if (currentRank < requiredRank) {
      return const EvaluationResult(
          isEnabled: false, reason: 'PLAN_TIER_INSUFFICIENT');
    }

    // 4. Percentage rollout
    final pct = rolloutPercentage.clamp(0, 100);
    if (pct > 0 && pct < 100) {
      final bucket = calculateRolloutBucket(flagKey, tenantId);
      if (bucket < pct) {
        return const EvaluationResult(
            isEnabled: true, reason: 'ROLLOUT_PERCENTAGE_INCLUDED');
      } else {
        return const EvaluationResult(
            isEnabled: false, reason: 'ROLLOUT_PERCENTAGE_EXCLUDED');
      }
    } else if (pct >= 100) {
      return const EvaluationResult(
          isEnabled: true, reason: 'ROLLOUT_PERCENTAGE_INCLUDED');
    }

    // 5. Global enable
    if (isEnabledGlobally) {
      return const EvaluationResult(isEnabled: true, reason: 'GLOBAL_ENABLED');
    }

    // 6. Safe default
    return EvaluationResult(isEnabled: defaultEnabled, reason: 'SAFE_DEFAULT');
  }

  /// Builds platform flags list URL.
  static String buildPlatformFlagsUrl() {
    return '/api/v2/platform/feature-flags/';
  }

  /// Builds platform flag detail URL.
  static String buildPlatformFlagDetailUrl(String flagKey) {
    final clean = flagKey.trim();
    if (!isValidFlagKey(clean)) {
      throw ArgumentError('Invalid flag key: \'$flagKey\'');
    }
    return '/api/v2/platform/feature-flags/$clean/';
  }

  /// Builds kill switch toggle URL.
  static String buildKillSwitchUrl(String flagKey) {
    final clean = flagKey.trim();
    if (!isValidFlagKey(clean)) {
      throw ArgumentError('Invalid flag key: \'$flagKey\'');
    }
    return '/api/v2/platform/feature-flags/$clean/kill-switch/';
  }

  /// Builds tenant override URL.
  static String buildTenantOverrideUrl(String flagKey) {
    final clean = flagKey.trim();
    if (!isValidFlagKey(clean)) {
      throw ArgumentError('Invalid flag key: \'$flagKey\'');
    }
    return '/api/v2/platform/feature-flags/$clean/tenant-override/';
  }

  /// Builds tenant eval URL.
  static String buildTenantEvalUrl({String? flagKey}) {
    if (flagKey == null || flagKey.trim().isEmpty) {
      return '/api/v2/tenants/feature-flags/eval/';
    }
    final clean = flagKey.trim();
    if (!isValidFlagKey(clean)) {
      throw ArgumentError('Invalid flag key: \'$flagKey\'');
    }
    return '/api/v2/tenants/feature-flags/eval/?flag_key=$clean';
  }

  // Pure Dart RFC 1321 MD5 Implementation
  static Uint8List _md5(Uint8List message) {
    final s = <int>[
      7,
      12,
      17,
      22,
      7,
      12,
      17,
      22,
      7,
      12,
      17,
      22,
      7,
      12,
      17,
      22,
      5,
      9,
      14,
      20,
      5,
      9,
      14,
      20,
      5,
      9,
      14,
      20,
      5,
      9,
      14,
      20,
      4,
      11,
      16,
      23,
      4,
      11,
      16,
      23,
      4,
      11,
      16,
      23,
      4,
      11,
      16,
      23,
      6,
      10,
      15,
      21,
      6,
      10,
      15,
      21,
      6,
      10,
      15,
      21,
      6,
      10,
      15,
      21,
    ];

    final k = <int>[
      0xd76aa478,
      0xe8c7b756,
      0x242070db,
      0xc1bdceee,
      0xf57c0faf,
      0x4787c62a,
      0xa8304613,
      0xfd469501,
      0x698098d8,
      0x8b44f7af,
      0xffff5bb1,
      0x895cd7be,
      0x6b901122,
      0xfd987193,
      0xa679438e,
      0x49b40821,
      0xf61e2562,
      0xc040b340,
      0x265e5a51,
      0xe9b6c7aa,
      0xd62f105d,
      0x02441453,
      0xd8a1e681,
      0xe7d3fbc8,
      0x21e1cde6,
      0xc33707d6,
      0xf4d50d87,
      0x455a14ed,
      0xa9e3e905,
      0xfcefa3f8,
      0x676f02d9,
      0x8d2a4c8a,
      0xfffa3942,
      0x8771f681,
      0x6d9d6122,
      0xfde5380c,
      0xa4beea44,
      0x4bdecfa9,
      0xf6bb4b60,
      0xbebfbc70,
      0x289b7ec6,
      0xeaa127fa,
      0xd4ef3085,
      0x04881d05,
      0xd9d4d039,
      0xe6db99e5,
      0x1fa27cf8,
      0xc4ac5665,
      0xf4292244,
      0x432aff97,
      0xab9423a7,
      0xfc93a039,
      0x655b59c3,
      0x8f0ccc92,
      0xffeff47d,
      0x85845dd1,
      0x6fa87e4f,
      0xfe2ce6e0,
      0xa3014314,
      0x4e0811a1,
      0xf7537e82,
      0xbd3af235,
      0x2ad7d2bb,
      0xeb86d391,
    ];

    int a0 = 0x67452301;
    int b0 = 0xefcdab89;
    int c0 = 0x98badcfe;
    int d0 = 0x10325476;

    final origLen = message.length;
    final bitLen = origLen * 8;
    int newLen = origLen + 1;
    while ((newLen % 64) != 56) {
      newLen++;
    }
    final padded = Uint8List(newLen + 8);
    padded.setRange(0, origLen, message);
    padded[origLen] = 0x80;

    for (int i = 0; i < 8; i++) {
      padded[newLen + i] = (bitLen >> (i * 8)) & 0xff;
    }

    final data = ByteData.sublistView(padded);

    for (int chunk = 0; chunk < padded.length; chunk += 64) {
      final m = List<int>.generate(
          16, (i) => data.getUint32(chunk + (i * 4), Endian.little));

      int a = a0;
      int b = b0;
      int c = c0;
      int d = d0;

      for (int i = 0; i < 64; i++) {
        int f = 0;
        int g = 0;
        if (i < 16) {
          f = (b & c) | ((~b) & d);
          g = i;
        } else if (i < 32) {
          f = (d & b) | ((~d) & c);
          g = (5 * i + 1) % 16;
        } else if (i < 48) {
          f = b ^ c ^ d;
          g = (3 * i + 5) % 16;
        } else {
          f = c ^ (b | (~d));
          g = (7 * i) % 16;
        }

        f = (f + a + k[i] + m[g]) & 0xffffffff;
        a = d;
        d = c;
        c = b;
        final shift = s[i];
        final rotated = ((f << shift) | (f >>> (32 - shift))) & 0xffffffff;
        b = (b + rotated) & 0xffffffff;
      }

      a0 = (a0 + a) & 0xffffffff;
      b0 = (b0 + b) & 0xffffffff;
      c0 = (c0 + c) & 0xffffffff;
      d0 = (d0 + d) & 0xffffffff;
    }

    final out = ByteData(16);
    out.setUint32(0, a0, Endian.little);
    out.setUint32(4, b0, Endian.little);
    out.setUint32(8, c0, Endian.little);
    out.setUint32(12, d0, Endian.little);
    return out.buffer.asUint8List();
  }
}
